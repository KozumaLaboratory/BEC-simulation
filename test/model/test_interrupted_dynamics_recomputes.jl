# The DYNAMICS half of cutover step 2's interrupt fix. Sibling of
# `test_interrupted_run_recomputes.jl`, which covers the ITP half.
#
# Why a separate file rather than another testset there: the canary pass of
# 2026-08-01 forced `interrupted[] = false` in BOTH RTP loops
# (`solvers/simulation/run_loops.jl`) and every suite stayed GREEN (canary B6).
# The existing 2-step testset cannot reach them — its interrupt lands in the
# GS and rides the `|` accumulation in `_step_dispatch!`, so the dynamics arm
# contributes `false` and is never read. A dynamics-only kill was still
# certified and served, which is the exact defect class step 2 exists to close,
# surviving on the other loop.
#
# Two levels, because one cannot do both jobs:
#
#   1. THE LOOPS, called directly and deterministically. Both `catch` blocks
#      are entered by a callback that raises `InterruptException` at a chosen
#      step — no scheduler, no wall clock, no race. This is what names the
#      corruption: forcing either `interrupted[] = false` turns exactly one of
#      these two testsets red.
#   2. THE RUN, end to end. `run_yaml` → GS → dynamics, interrupted mid-
#      evolution, asserting no marker, a tombstone, and a recomputation. Uses
#      the harness `test_interrupted_run_recomputes.jl` proved functional
#      (`@async` + `schedule(task, InterruptException(); error=true)`), with the
#      wait signal moved from `itp_checkpoint.jld2` to `_live_status.json` —
#      only the dynamics step writes that file (`_step_dispatch!` passes
#      `live_status_path` to `DynamicsStep` and to nothing else), so seeing it
#      is proof the GS is already finished and the RTP loop is running.

using Test
using JLD2
using JSON
using YAML
using SpinorBEC
using SpinorBEC: marker_path, incomplete_marker_path, admit_payload, _has_result,
    _run_simulation_standard!, _run_simulation_leapfrog!, _reset_unmarked_warnings!
include(joinpath(@__DIR__, "..", "helpers", "interrupt_harness.jl"))
include(joinpath(@__DIR__, "..", "helpers", "cacheable_tree.jl"))

# 1-D, 64 points, F=1, no DDI: the cheapest workspace that still exercises the
# real V/K/V chain both loops run.
function dyn_probe_ws(; n_steps::Int, save_every::Int)
    grid = make_grid(GridConfig(64, 12.0))
    make_workspace(;
        grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.0)),
        potential=HarmonicTrap(1.0),
        sim_params=SimParams(; dt=1.0e-4, n_steps, save_every),
        psi_init=init_psi(grid, SpinSystem(1); state=:polar),
    )
end

# `_record_snapshot!` pushes times FIRST. Pushing one before raising reproduces,
# deterministically, the state a scheduler-delivered interrupt leaves behind —
# measured on the leapfrog loop 2026-08-01: times=6, energies=norms=mags=5.
half_record_then_raise(k) = (ws, step, times, energies) -> begin
    step == k || return nothing
    push!(times, ws.state.t)
    throw(InterruptException())
end

raise_at(k) = (ws, step, times, energies) -> begin
    step == k && throw(InterruptException())
    nothing
end

# Both loops take the same 9 positional arguments; only the keyword tail differs
# (`stepper` on the standard one), and its default is the production `split_step!`.
function drive_loop(loop, ws, cb; interrupted)
    times, energies, norms, mags = Float64[], Float64[], Float64[], Float64[]
    snaps = Array{ComplexF64}[]
    loop(ws, ws.sim_params, ws.spin_matrices.system,
        times, energies, norms, mags, snaps, cb; interrupted)
    (; times, energies, norms, mags, snaps)
end

const RTP_LOOPS = (
    ("leapfrog — the production default (`integrator:` absent)",
        _run_simulation_leapfrog!),
    ("standard — the `integrator: midpoint` / explicit-stepper path",
        _run_simulation_standard!),
)

@testset "an interrupted RTP loop says so (canary B6)" begin
    for (name, loop) in RTP_LOOPS
        @testset "$name" begin
            # POSITIVE CONTROL FIRST. Without it, "the Ref is true" would also
            # pass against a loop that sets it unconditionally, and the whole
            # testset would be measuring nothing.
            ws = dyn_probe_ws(; n_steps=500, save_every=100)
            ref = Ref(false)
            r = drive_loop(loop, ws, SimulationCallbacks(); interrupted=ref)
            @test ref[] === false
            @test length(r.times) == 5          # 500 steps / save_every 100

            # THE assertion the canary forced false.
            ws = dyn_probe_ws(; n_steps=500, save_every=100)
            ref = Ref(false)
            r = drive_loop(loop, ws, SimulationCallbacks(; on_step=raise_at(120));
                interrupted=ref)
            @test ref[] === true
            # ...and the loop really stopped early rather than running on: the
            # step-100 save plus the interrupt's own final record, not 5.
            @test length(r.times) == 2
            # The interrupt is SWALLOWED — `drive_loop` returned. That is the
            # dangerous case (a killed run that looks finished), and it is the
            # premise of everything below.
            @test length(r.norms) == 2

            # The half-written row. `_trim_interrupted_traces!` must drop it:
            # every consumer indexes the four traces together, and the ragged
            # tail raised a BoundsError inside the pipeline's dynamics
            # auto-save, so an interrupted run wrote no `result.jld2` at all.
            ws = dyn_probe_ws(; n_steps=500, save_every=100)
            ref = Ref(false)
            r = drive_loop(loop, ws,
                SimulationCallbacks(; on_step=half_record_then_raise(120));
                interrupted=ref)
            @test ref[] === true
            @test length(r.times) == length(r.energies) == length(r.norms) ==
                length(r.mags)
            @test length(r.times) == 2          # the partial row dropped, not padded
            @test length(r.snaps) == 2
            @test all(isfinite, r.times)
        end
    end

    @testset "`run_simulation!` forwards the Ref to whichever loop it picks" begin
        # entry.jl chooses the loop from `imaginary_time || stepper !== nothing`.
        # Deleting `interrupted` from either forwarding call would leave the two
        # testsets above green, since they bypass this entry point entirely.
        for stepper in (nothing, split_step!)
            ws = dyn_probe_ws(; n_steps=500, save_every=100)
            ref = Ref(false)
            res = run_simulation!(ws;
                callbacks=SimulationCallbacks(; on_step=raise_at(120)),
                stepper, interrupted=ref)
            @test ref[] === true
            @test res isa SimulationResult
            @test length(res.times) == length(res.norms)
        end
    end
end

# ---------------------------------------------------------------------------
# End to end: a run killed DURING the dynamics phase
# ---------------------------------------------------------------------------

# GS: small and quick — it must be finished before the interrupt is armed.
# Dynamics: 1e6 steps, so the kill lands in single-digit percent of the budget
# on any machine; the recomputation of the whole thing takes ~8 s.
dyn_interrupt_config() = Dict{String, Any}(
    "pipeline" => Any[
        Dict{String, Any}(
            "ground_state" => Dict{String, Any}(
                "atom" => "Rb87", "method" => "itp",
                "grid" => Dict{String, Any}("n" => [64], "box" => [12.0]),
                "interactions" => Dict{String, Any}(
                    "N_atoms" => 100, "omega_ref" => 100.0, "c0" => 1.0, "c1" => 0.0
                ),
                "potential" => Dict{String, Any}("type" => "harmonic", "omega" => [1.0]),
                "initial_state" => "polar",
                "n_steps" => 400, "dt" => 1.0e-3, "tol" => 1.0e-8),
        ),
        Dict{String, Any}(
            "dynamics" => Dict{String, Any}(
                "duration" => 100.0, "dt" => 1.0e-4,
                "save" => Dict{String, Any}("every" => 5000),
                "live_monitor" => Dict{String, Any}("every" => 50)),
        ),
    ],
)

const DYN_DURATION = 100.0

@testset "a run killed mid-DYNAMICS is not served (cutover step 2, invariant 4)" begin
    _reset_unmarked_warnings!()
    mktempdir() do dir
        run_dir = joinpath(dir, "run")
        mkpath(run_dir)
        cfg = joinpath(run_dir, "config.yaml")
        YAML.write_file(cfg, dyn_interrupt_config())
        psi_file = joinpath(run_dir, "point_001.jld2")
        res_file = joinpath(run_dir, "result.jld2")
        live = joinpath(run_dir, "_live_status.json")

        task = @async run_yaml(cfg; verbose=true)
        deadline = time() + 900
        while !isfile(live) && !istaskdone(task) && time() < deadline
            sleep(0.005)
        end

        # The preconditions that stop this gate passing for the wrong reason.
        # `_live_status.json` is written ONLY by the dynamics step, so its
        # existence is proof that the GS finished and the RTP loop is running —
        # i.e. the interrupt below lands in the dynamics, not in the GS.
        @test isfile(live)
        # A lost race must be a clean FAILURE that names itself, never an
        # ErrorException("schedule: Task not runnable") that aborts the whole FILE
        # and takes its sibling gates with it. The delivery IS the check — see
        # test/helpers/interrupt_harness.jl. Delivered here rather than after the
        # `live_step` assertions below, which only widened the window; the status
        # file is already on disk, so reading it after the interrupt is fine.
        won_race = warn_lost_race(deliver_interrupt!(task))
        @test won_race
        live_step = JSON.parse(read(live, String))["step"]
        @test live_step >= 1

        task_returned_normally = try
            wait(task)
            true
        catch
            false
        end

        # THE defect, asserted directly: the interrupt was SWALLOWED, `run_yaml`
        # returned as if nothing had happened, and a full-looking payload is on
        # disk. If this goes false the interrupt escaped and the rest of the
        # testset would be measuring the harmless case.
        @test task_returned_normally
        @test isfile(psi_file)

        interrupted_gs_E = JLD2.load(psi_file)["energy"]
        @test isfinite(interrupted_gs_E)

        # (i) NO completion marker, and the killed run said so itself.
        @test !isfile(marker_path(psi_file))
        @test isfile(incomplete_marker_path(psi_file))
        adm = admit_payload(psi_file)
        @test !adm.hit
        @test adm.provenance === :rejected
        @test occursin("INTERRUPTED", adm.reason)
        # `result.jld2` is the other name `Experiment` admits on. It must not be
        # certified either — whether or not the auto-save produced one.
        @test !isfile(marker_path(res_file))
        # ...so the run directory as a whole does not admit.
        @test !_has_result(run_dir)

        # The dynamics really was cut short, and the GS really was not: the
        # trajectory stops well before its duration while the GS energy is
        # BIT-IDENTICAL to the one the full recomputation produces below. That
        # pair is what separates "interrupted in the dynamics" from
        # "interrupted in the GS", which is the arm the sibling file covers.
        interrupted_t_end = isfile(res_file) ?
                            JLD2.load(res_file)["dynamics/times"][end] : nothing
        interrupted_t_end === nothing || @test interrupted_t_end < DYN_DURATION

        # (ii) the next run RECOMPUTES rather than serving the partial output.
        # `with_cacheable_tree`: a re-run that must HIT the cache. `_assert_point_provenance`
        # refuses a reuse when the tree is dirty, i.e. in any working checkout — but the
        # point was written by this process seconds earlier, so the code cannot differ,
        # and the admission counting happens in `admit_payload`, before the check.
        # See test/helpers/cacheable_tree.jl.
        with_cacheable_tree() do
            run_yaml(cfg; verbose=false)
        end
        @test JLD2.load(psi_file)["energy"] == interrupted_gs_E   # GS phase unchanged
        @test isfile(res_file)
        @test JLD2.load(res_file)["dynamics/times"][end] ≈ DYN_DURATION rtol = 1.0e-6
        @test isfile(marker_path(psi_file))
        @test !isfile(incomplete_marker_path(psi_file))
        @test admit_payload(psi_file).provenance === :marked
        @test admit_payload(res_file).provenance === :marked
        @test _has_result(run_dir)

        # POSITIVE CONTROL for the recomputation: admission must still SERVE a
        # dynamics run that finished, or "it recomputed" would be consistent
        # with an admission that recomputes everything.
        t_hit = @elapsed with_cacheable_tree() do
            run_yaml(cfg; verbose=false)
        end
        @test JLD2.load(res_file)["dynamics/times"][end] ≈ DYN_DURATION rtol = 1.0e-6
        @test t_hit < 1.0     # a cache hit is milliseconds; the run is seconds
    end
end
