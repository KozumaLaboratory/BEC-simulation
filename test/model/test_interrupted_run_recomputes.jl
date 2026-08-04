# THE gate cutover step 2 exists for. Do not delete it, do not weaken it.
#
# Before this step, admission was `isfile(payload)` and `_run_itp_loop!` swallowed
# `InterruptException` (`solvers/ground_state/itp_loop.jl:223-233`): it set a
# local flag, printed, and returned an ORDINARY NamedTuple. The pipeline then ran
# on with a half-relaxed ψ, wrote a full-looking `point_001.jld2`, wrote
# `_exit_summary.json` with `completed = true`, deleted the interrupt checkpoint
# under the comment "point completed successfully", and exited 0. The next run
# served that file. Measured on the pre-cutover tree: an ITP killed at step
# 5323/100000 came back in 0.01 s with an energy 0.64 % off.
#
# `converged = false` was recorded and could not have saved it: its readers are a
# summary printer, an HTML report and two dashboard endpoints. Nothing admits on
# it, and a dynamics-only pipeline records `converged = true` unconditionally
# (`run_registry.jl:729`).
#
# ## Why this test uses an in-process interrupt and not `kill -INT`
#
# A real SIGINT was tried and MEASURED first. Julia 1.12 in script mode has
# `exit_on_sigint == true`, so `kill -INT` aborts the process at the next
# safepoint — `[pid] signal 2: Interrupt`, exit 130 — and the catch at
# `itp_loop.jl:223` never runs. Nothing is written, so the next run recomputes
# BECAUSE THERE IS NOTHING TO SERVE. That test is green before and after this
# step: a broken gate. (`grep -rn exit_on_sigint` over the repo returns nothing,
# so the swallow path is unreachable in batch production and live only in a REPL
# or under deliberate injection.)
#
# `schedule(task, InterruptException(); error=true)` on an `@async` task delivers
# exactly one exception at the task's next yield point, which is inside the ITP
# loop — the dangerous case, where the payload IS written. Two mechanisms that
# do NOT work and must not be substituted, both measured:
#   * `Base.throwto` deadlocks the process (it is `yieldto`-based and never
#     reschedules the caller; reduced to a 20-line non-SpinorBEC case).
#   * the same `schedule` against a `Threads.@spawn` task aborts the process
#     (`signal 6, jl_finish_task at task.c:348`). `@async` is sticky; keep it.
#
# ## Why the run is interrupted at the ITP's own checkpoint and not after a sleep
#
# A wall-clock sleep is a race against convergence: at 64 points this ITP
# converges around step 1.06e6 of 2e6. `itp_checkpoint.jld2` is written at
# `save_every = n_steps ÷ 100` (`itp_loop.jl:144`), i.e. after 20 000 steps —
# 1 % of the budget and a 50× margin below the convergence point. Waiting for
# that file is a deterministic "the ITP has really taken steps and is still
# running" signal that does not depend on machine speed.

using Test
using JLD2
using YAML
using SpinorBEC
using SpinorBEC: marker_path, incomplete_marker_path, admit_payload,
    _reset_unmarked_warnings!

# 1-D, 64 points, CPU. The step budget is large so that the interrupt lands far
# from convergence; the recomputation still finishes in a few seconds.
interrupt_probe_config() = Dict{String, Any}(
    "pipeline" => Any[Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "atom" => "Rb87", "method" => "itp",
            "grid" => Dict{String, Any}("n" => [64], "box" => [12.0]),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 100, "omega_ref" => 100.0, "c0" => 1.0, "c1" => 0.0),
            "potential" => Dict{String, Any}("type" => "harmonic", "omega" => [1.0]),
            "initial_state" => "polar",
            "n_steps" => 2_000_000, "dt" => 1.0e-5, "tol" => 1.0e-16))],
)

@testset "an interrupted ITP is NOT served (cutover step 2, invariant 4)" begin
    _reset_unmarked_warnings!()
    mktempdir() do dir
        run_dir = joinpath(dir, "run")
        mkpath(run_dir)
        cfg = joinpath(run_dir, "config.yaml")
        YAML.write_file(cfg, interrupt_probe_config())
        psi_file = joinpath(run_dir, "point_001.jld2")
        itp_ckpt = joinpath(run_dir, ".checkpoints", "point_001.jld2", "itp_checkpoint.jld2")

        task = @async run_yaml(cfg; verbose=true)
        deadline = time() + 900
        while !isfile(itp_ckpt) && !istaskdone(task) && time() < deadline
            sleep(0.02)
        end

        # The two preconditions that stop this gate passing for the wrong
        # reason: the ITP really ran, and it is still running when we hit it.
        @test isfile(itp_ckpt)
        # If the solve already finished we have not measured the property, and
        # `schedule` on a finished task throws ErrorException("schedule: Task not
        # runnable"), which aborts the whole FILE and takes the sibling gates with
        # it. Observed once under load, when this file ran after the dynamics
        # interrupt file. A lost race must be a clean FAILURE that names itself,
        # never an error that hides its siblings.
        won_race = !istaskdone(task)
        won_race || @warn "interrupt harness LOST THE RACE: the run finished before the " *
            "interrupt was delivered, so this gate measured nothing"
        @test won_race
        won_race && schedule(task, InterruptException(); error=true)
        task_returned_normally = try
            wait(task)
            true
        catch
            false
        end

        # THE defect, asserted directly. The interrupt was SWALLOWED: `run_yaml`
        # returned as if nothing had happened and a complete-looking payload is
        # on disk. If this ever goes false the interrupt escaped instead of
        # being caught, and the rest of the testset would be measuring the
        # harmless case.
        @test task_returned_normally
        @test isfile(psi_file)

        interrupted_E = JLD2.load(psi_file)["energy"]
        @test isfinite(interrupted_E)

        # (i) NO completion marker was written.
        @test !isfile(marker_path(psi_file))
        # ...and the killed run said so itself, which is what stops arm (b) of
        # `admit_payload` from grandfathering it as a pre-cutover artifact.
        @test isfile(incomplete_marker_path(psi_file))

        adm = admit_payload(psi_file)
        @test !adm.hit
        @test adm.provenance === :rejected
        @test occursin("INTERRUPTED", adm.reason)

        # The forensic record survives: before this step the same pass deleted
        # the interrupt checkpoint under the comment "point completed
        # successfully", leaving nothing on disk that knew the run was killed.
        @test isfile(itp_ckpt)

        # (ii) the next run RECOMPUTES rather than serving the partial output.
        run_yaml(cfg; verbose=false)
        recomputed_E = JLD2.load(psi_file)["energy"]
        @test recomputed_E != interrupted_E
        # ITP decreases the energy monotonically, so "it really carried on" is a
        # physics statement, not just an inequality on a float.
        @test recomputed_E < interrupted_E
        @test JLD2.load(psi_file)["converged"] === true
        @test isfile(marker_path(psi_file))
        @test !isfile(incomplete_marker_path(psi_file))
        @test admit_payload(psi_file).provenance === :marked

        # POSITIVE CONTROL for the recomputation above. Admission must still
        # SERVE a run that finished — otherwise "it recomputed" would be
        # consistent with an admission that recomputes everything, which is a
        # different bug wearing this gate as a disguise.
        t_hit = @elapsed run_yaml(cfg; verbose=false)
        @test JLD2.load(psi_file)["energy"] == recomputed_E
        @test t_hit < 1.0     # a cache hit is milliseconds; the solve is seconds
    end
end

# `merge!(results, step_result)` in `_step_dispatch!` is last-writer-wins, so a
# LATER step reporting `:interrupted => false` would overwrite an earlier step's
# `true` and the run would be certified on a half-relaxed ψ. The single-step
# testset above cannot see that: it has nothing after the ITP.
@testset "an interrupt in step 1 survives a step 2 that completes" begin
    mktempdir() do dir
        run_dir = joinpath(dir, "run")
        mkpath(run_dir)
        cfg = joinpath(run_dir, "config.yaml")
        spec = interrupt_probe_config()
        # A dynamics step short enough to finish in milliseconds — the point is
        # that it finishes, and reports `:interrupted => false` while doing so.
        push!(
            spec["pipeline"],
            Dict{String, Any}(
                "dynamics" => Dict{String, Any}(
                    "duration" => 0.002, "dt" => 0.001,
                    "save" => Dict{String, Any}("every" => 1)),
            ),
        )
        YAML.write_file(cfg, spec)
        psi_file = joinpath(run_dir, "point_001.jld2")
        itp_ckpt = joinpath(run_dir, ".checkpoints", "point_001.jld2", "itp_checkpoint.jld2")

        task = @async run_yaml(cfg; verbose=true)
        deadline = time() + 900
        while !isfile(itp_ckpt) && !istaskdone(task) && time() < deadline
            sleep(0.02)
        end
        @test isfile(itp_ckpt)
        # If the solve already finished we have not measured the property, and
        # `schedule` on a finished task throws ErrorException("schedule: Task not
        # runnable"), which aborts the whole FILE and takes the sibling gates with
        # it. Observed once under load, when this file ran after the dynamics
        # interrupt file. A lost race must be a clean FAILURE that names itself,
        # never an error that hides its siblings.
        won_race = !istaskdone(task)
        won_race || @warn "interrupt harness LOST THE RACE: the run finished before the " *
            "interrupt was delivered, so this gate measured nothing"
        @test won_race
        won_race && schedule(task, InterruptException(); error=true)
        @test try
            wait(task)
            true
        catch
            false
        end

        # The dynamics step ran to completion after the interrupted GS...
        @test isfile(psi_file)
        # ...and the run is STILL not certified.
        @test !isfile(marker_path(psi_file))
        @test isfile(incomplete_marker_path(psi_file))
        @test admit_payload(psi_file).provenance === :rejected
        # `result.jld2` is written by the dynamics auto-save inside
        # `run_pipeline`, and it must not be certified either.
        res = joinpath(run_dir, "result.jld2")
        !isfile(res) || @test !isfile(marker_path(res))
    end
end
