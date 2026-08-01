# WAS `test_admission_unchanged.jl` (cutover step 1). Step 1's promise was "the
# NEW id is recorded, the OLD key still decides"; step 2 CHANGES admission, so
# the old name asserted a property the tree no longer has. Renamed rather than
# deleted: its four-arm shape — record / hit / null / positive control — is what
# keeps the claim from passing for the wrong reason, and step 2 needs the same
# discipline over a different predicate.
#
# What still holds from step 1, and is still gated below:
#
#   * WHICH artifact is looked at is still decided by `_gs_cache_key`, not by
#     `artifact_id`. Step 3 is what moves that, and until it does, moving
#     `code_tree_hash` must not invalidate the GS store.
#   * The artifact still carries both ids.
#
# What step 2 changes, and is gated below:
#
#   * WHETHER the artifact at that path is served is no longer `isfile`. It is
#     `admit_payload`: a valid marker, or (arm b) no marker at all. A marker
#     that disagrees with the bytes is a MISS.
#   * A real solve now writes the marker; the store holds two files per cell.
#   * An interrupted solve writes NOTHING into the shared store — a partial ψ in
#     a content-addressed cache is not data with a caveat, it is a wrong answer
#     waiting for a different config to resolve to the same physics.
#
# The key is taken from the step's own `:gs_stage_ref` rather than recomputed
# here. Restating `_gs_cache_key`'s 18 inputs in a test is a second declaration
# of the thing under test, and it drifts: the step mutates its params dict
# (`_resolve_derived_params!`) and derives its DDI tuple before hashing.

using Test
using JLD2
using SpinorBEC
using SpinorBEC: _gs_cache_key, _gs_stage_dir, _run_step, GroundStateStep,
    code_tree_hash, _code_rev_or_nothing, _package_root, _CODE_TREE_HASH_MEMO,
    make_grid, GridConfig, InteractionParams, resolve_atom,
    marker_path, incomplete_marker_path, admit_payload, read_complete_marker,
    write_complete_marker, _reset_unmarked_warnings!

probe_gs_params(; tol=1.0e-6) = Dict{String, Any}(
    "atom" => "Rb87",
    "method" => "itp",
    "grid" => Dict{String, Any}("n" => [16], "box" => [8.0]),
    "interactions" => Dict{String, Any}("N_atoms" => 100, "omega_ref" => 100.0,
        "c0" => 1.0, "c1" => 0.0),
    "potential" => Dict{String, Any}("type" => "harmonic", "omega" => [1.0]),
    "initial_state" => "polar",
    "n_steps" => 20,
    "dt" => 1.0e-3,
    "tol" => tol,
)

probe_with_code_rev(f, value) = begin
    k = abspath(_package_root())
    saved = get(_CODE_TREE_HASH_MEMO, k, nothing)
    try
        _CODE_TREE_HASH_MEMO[k] = value
        f()
    finally
        saved === nothing ? delete!(_CODE_TREE_HASH_MEMO, k) :
        (_CODE_TREE_HASH_MEMO[k] = saved)
    end
end

const PROBE_SENTINEL_E = -12345.678

stage_files(dir) = sort(filter(f -> endswith(f, ".jld2"), readdir(dir)))

# Rewrite the artifact's payload with a value no solver produces. From the point
# it is called, a returned energy of PROBE_SENTINEL_E means "admission served
# this file". `remark` controls the step-2 half: whether the completion marker is
# refreshed to match the bytes just written.
function plant_sentinel!(path, stage_ref; remark::Bool=true)
    psi_fake = JLD2.load(path)["psi"]
    jldopen(path, "w") do f
        f["psi"] = psi_fake
        f["energy"] = PROBE_SENTINEL_E
        f["converged"] = true
        f["gs_cache_key"] = stage_ref
        f["code_rev"] = code_tree_hash()
    end
    rm(marker_path(path); force=true)
    remark && write_complete_marker(path, [path]; kind="ground_state", artifact_id=stage_ref)
    path
end

@testset "admission requires a marker; the OLD key still picks the file" begin
    @testset "the old key does not read the new id" begin
        # An arbitrary but FIXED argument set — the claim is about the key
        # function's inputs, not about this particular cell.
        args = (:itp, resolve_atom(:Rb87), make_grid(GridConfig((16,), (8.0,))),
            InteractionParams(Dict(0 => 1.0, 1 => 0.0)),
            (false, NaN, false, false, 0.0, NaN, false, 2.0),
            1.0e-6, 20, 1.0e-3, probe_gs_params())
        k0 = _gs_cache_key(args...)
        k1 = probe_with_code_rev("0"^64) do
            _gs_cache_key(args...)
        end
        # If the code revision had leaked into `_gs_cache_key`, every commit
        # would invalidate the GS store — step 3's decision, not step 1's, and
        # exactly what "admit on the old one" forbids.
        @test k1 == k0
        # Positive control on the key function itself: it is not a constant.
        @test _gs_cache_key(args[1:5]..., 1.0e-7, args[7:end]...) != k0
    end

    mktempdir() do dir
        probe_run_gs(pp) = withenv("SPINORBEC_STAGE_CACHE" => "1", "SPINORBEC_STAGE_DIR" => dir) do
            _run_step(GroundStateStep(pp), nothing, nothing, nothing, nothing; verbose=false)
        end

        local stage_ref, real_E, path
        @testset "RECORD: a solved artifact carries BOTH ids AND a marker" begin
            (_, _, _, _, res) = probe_run_gs(probe_gs_params())
            stage_ref = res[:gs_stage_ref]
            real_E = res[:ground_state_energy]
            path = joinpath(dir, stage_ref * ".jld2")
            @test stage_ref isa AbstractString
            @test isfile(path)
            d = JLD2.load(path)
            @test d["gs_cache_key"] == stage_ref            # the id that admits
            @test d["code_rev"] == code_tree_hash()          # the new one, recorded only
            @test length(d["code_rev"]) == 64
            # ... beside the payload the loader reads, unchanged.
            @test haskey(d, "psi") && haskey(d, "energy") && haskey(d, "converged")
            @test d["energy"] == real_E

            # Step 2: the artifact now certifies its own bytes, written last.
            @test isfile(marker_path(path))
            m = read_complete_marker(marker_path(path))
            @test m.kind == "ground_state"
            @test m.artifact_id == stage_ref     # the id that DECIDES, recorded in the marker
            @test m.code_rev == code_tree_hash()
            @test m.payload == [SpinorBEC.PayloadEntry(basename(path), filesize(path))]
            @test admit_payload(path).provenance === :marked
            @test !isfile(incomplete_marker_path(path))
        end

        @testset "HIT: the file the old key names is what gets served" begin
            plant_sentinel!(path, stage_ref)
            (_, _, _, _, res) = probe_run_gs(probe_gs_params())
            @test res[:ground_state_energy] == PROBE_SENTINEL_E
            @test res[:gs_stage_ref] == stage_ref
            @test String(res[:ground_state_provenance]) == "marked"
            @test stage_files(dir) == [basename(path)]
        end

        @testset "NULL: moving the new id does not change admission" begin
            (_, _, _, _, res) = probe_with_code_rev("0"^64) do
                probe_run_gs(probe_gs_params())
            end
            @test res[:ground_state_energy] == PROBE_SENTINEL_E
            @test res[:gs_stage_ref] == stage_ref
            @test stage_files(dir) == [basename(path)]   # no second artifact was written
        end

        # --- what cutover step 2 changed, at this exact site ---

        @testset "STEP 2: a marker that DISAGREES with the bytes is a MISS" begin
            # The marker is corrupted rather than the payload, deliberately: if
            # admission wrongly served it, the sentinel would come back and this
            # is a clean `@test` failure. Truncating the jld2 instead would make
            # a wrong admission throw inside JLD2, i.e. an ERROR whose message
            # points at the loader rather than at the predicate under test.
            m = read_complete_marker(marker_path(path))
            write(marker_path(path),
                "artifact_id = \"$(stage_ref)\"\nformat = 1\nkind = \"ground_state\"\n" *
                "written_at = \"$(m.written_at)\"\n\n[[payload]]\n" *
                "bytes = $(filesize(path) + 1)\npath = \"$(basename(path))\"\n")
            @test !admit_payload(path).hit

            (_, _, _, _, res) = probe_run_gs(probe_gs_params())
            @test res[:gs_stage_ref] == stage_ref             # SAME file, still
            @test res[:ground_state_energy] != PROBE_SENTINEL_E  # ...but recomputed
            @test res[:ground_state_energy] ≈ real_E
            # ...and the recomputation left the artifact certified again.
            @test admit_payload(path).provenance === :marked
            @test read_complete_marker(marker_path(path)).payload[1].bytes == filesize(path)
        end

        @testset "STEP 2 arm (b): an UNMARKED legacy artifact is still served" begin
            # The 671 pre-cutover `.jld2` under `runs/` have no marker and must
            # not all be recomputed. Same fixture as the HIT arm, marker removed.
            _reset_unmarked_warnings!()
            plant_sentinel!(path, stage_ref; remark=false)
            @test !isfile(marker_path(path))
            (_, _, _, _, res) = probe_run_gs(probe_gs_params())
            @test res[:ground_state_energy] == PROBE_SENTINEL_E
            @test String(res[:ground_state_provenance]) == "unmarked"
        end

        @testset "POSITIVE CONTROL: moving an input the old key reads DOES miss" begin
            (_, _, _, _, res) = probe_run_gs(probe_gs_params(; tol=1.0e-7))
            @test res[:gs_stage_ref] != stage_ref
            @test res[:ground_state_energy] != PROBE_SENTINEL_E
            @test isfile(joinpath(dir, res[:gs_stage_ref] * ".jld2"))
            @test length(stage_files(dir)) == 2
            d = JLD2.load(joinpath(dir, res[:gs_stage_ref] * ".jld2"))
            @test d["gs_cache_key"] == res[:gs_stage_ref]
            @test d["code_rev"] == code_tree_hash()
            @test admit_payload(joinpath(dir, res[:gs_stage_ref] * ".jld2")).provenance === :marked
        end

        @testset "the extra datasets do not disturb the loader" begin
            # The load branch reads three keys by name; nothing enumerates.
            d = JLD2.load(path)
            @test get(d, "energy", NaN) == PROBE_SENTINEL_E
            @test get(d, "converged", true) === true
            @test d["psi"] isa AbstractArray
        end
    end

    @testset "STEP 2: an INTERRUPTED solve writes NOTHING into the shared store" begin
        # The third claim in this file's header, gated. Deleting
        # `&& !gs_interrupted` from `run_step_ground_state.jl:585` left both the
        # admission suite and the interrupt control GREEN in the 2026-08-01
        # canary pass (C4) — a claim that said it was gated and was not.
        #
        # It is the highest-blast-radius write in the tree: the key is content-
        # addressed over resolved physics precisely so that ANY other config
        # reuses the artifact, so a half-relaxed ψ landing here is not a
        # poisoned directory, it is a wrong answer waiting for a different
        # config to ask the same question.
        #
        # Interrupt mechanism and wait signal are the sibling file's, unchanged:
        # `schedule(task, InterruptException(); error=true)` on an `@async` task
        # (a real SIGINT aborts the process before the swallow path runs), and
        # `itp_checkpoint.jld2`, written at `n_steps ÷ 100`, as the machine-
        # speed-independent "the ITP really took steps and is still running".
        mktempdir() do sdir
            mktempdir() do cdir
                run_in_store(pp; kwargs...) = withenv(
                    "SPINORBEC_STAGE_CACHE" => "1", "SPINORBEC_STAGE_DIR" => sdir) do
                    _run_step(GroundStateStep(pp), nothing, nothing, nothing, nothing;
                        kwargs...)
                end

                # POSITIVE CONTROL, and it goes FIRST: the env, the store and the
                # writer all work. Without it "nothing was written" would also
                # pass against a stage cache that was never enabled.
                (_, _, _, _, ok) = run_in_store(probe_gs_params(); verbose=false)
                @test length(stage_files(sdir)) == 1
                before = sort!(readdir(sdir))
                @test any(f -> endswith(f, ".complete.toml"), before)

                # A step budget the ITP cannot finish inside this test.
                pp = probe_gs_params()
                pp["grid"] = Dict{String, Any}("n" => [64], "box" => [12.0])
                pp["n_steps"] = 2_000_000
                pp["dt"] = 1.0e-5
                pp["tol"] = 1.0e-16
                itp_ckpt = joinpath(cdir, "itp_checkpoint.jld2")

                res = withenv("SPINORBEC_STAGE_CACHE" => "1",
                    "SPINORBEC_STAGE_DIR" => sdir) do
                    task = @async _run_step(GroundStateStep(pp),
                        nothing, nothing, nothing, nothing;
                        verbose=true, checkpoint_dir=cdir)
                    deadline = time() + 900
                    while !isfile(itp_ckpt) && !istaskdone(task) && time() < deadline
                        sleep(0.02)
                    end
                    @test isfile(itp_ckpt)
                    # A lost race must be a clean FAILURE that names itself, never an
                    # ErrorException("schedule: Task not runnable") that aborts the whole FILE
                    # and takes its sibling gates with it.
                    won_race = !istaskdone(task)
                    won_race || @warn "interrupt harness LOST THE RACE: the run finished before " *
                        "the interrupt landed; this gate measured nothing"
                    @test won_race
                    won_race && schedule(task, InterruptException(); error=true)
                    try
                        wait(task)
                        fetch(task)
                    catch
                        nothing
                    end
                end

                # The interrupt was SWALLOWED — `_run_step` returned an ordinary
                # 5-tuple. That is the dangerous case and the premise of the
                # assertion below; if it ever goes false the exception escaped
                # and nothing would have been written for a different reason.
                @test res !== nothing
                @test res[5][:interrupted] === true
                # A key WAS resolved, and it is not the control's — so the
                # interrupted cell would have written a NEW file had it written
                # at all, and "the store did not grow" is not an artifact of the
                # two runs sharing one name.
                @test res[5][:gs_stage_ref] isa AbstractString
                @test res[5][:gs_stage_ref] != ok[:gs_stage_ref]

                # THE claim: nothing entered the shared store. Not the artifact,
                # not a marker, and not a tombstone either — a tombstone on a
                # content-addressed key would reject the cell for every OTHER
                # config, and there is no payload here to tombstone.
                @test sort!(readdir(sdir)) == before
                @test !isfile(joinpath(sdir, res[5][:gs_stage_ref] * ".jld2"))
            end
        end
    end

    @testset "a record writer cannot acquire a new way to fail" begin
        # `code_tree_hash` reads the disk, and TSUBAME re-syncs `src/` under
        # running jobs. A record write must degrade, not throw — and must not
        # substitute a plausible-looking wrong revision.
        @test _code_rev_or_nothing() == code_tree_hash()
        @test _code_rev_or_nothing() !== nothing
    end
end
