# W4: the cache's fail-safes warned and did not count.
#
# `_warn_no_artifact_id_once` (`run_step_ground_state.jl`) is keyed per REASON,
# which is better than the design's "warns once" — but it is `@warn` only. It
# reaches no `Record`, no `_exit_summary.json`, no `run_summary`. Roughly 40
# runnable configs currently resolve to no artifact id and nothing on disk said
# so. Same for `_warn_unmarked_once`: a payload served WITHOUT a verified marker
# left a stderr line and no artifact.
#
# ccache's posture is a PERSISTED PER-REASON COUNTER — 28 named uncacheable
# counters surfaced by `--show-stats -v`. sccache's documented real-world failure
# is the silent one: workspaces that stopped caching entirely because
# `CARGO_INCREMENTAL` was set, discoverable only via `--show-stats`.
#
# So the gate is: THE NUMBERS ARE IN A FILE. Every assertion below reads
# `_exit_summary.json` back off the disk and parses it; none of them inspects the
# in-memory counter it was derived from, because "the counter exists" was already
# true and is not the defect.

using Test
using JSON
using SpinorBEC
using SpinorBEC: admit_payload, write_complete_marker, write_incomplete_marker,
    admission_counts, no_artifact_id_reasons, _reset_admission_counts!,
    _reset_unmarked_warnings!, _reset_no_artifact_id_warnings!,
    _warn_no_artifact_id_once, _write_exit_summary, _cache_stats_payload

sfixture(dir, name, nbytes=64) = begin
    p = joinpath(dir, name)
    write(p, rand(UInt8, nbytes))
    p
end
# 2023-11-14 — before the marker cutover, so an unmarked fixture is arm (b) and
# not a W3 date rejection.
predate!(p) = (run(pipeline(`touch -d @1700000000 $p`; stdout=devnull)); p)

read_summary(path) = JSON.parsefile(path)

@testset "W4: the cache's counters survive into a file" begin
    @testset "A: every admission provenance is counted, on disk" begin
        mktempdir() do dir
            _reset_admission_counts!()
            _reset_unmarked_warnings!()
            _reset_no_artifact_id_warnings!()

            # 2 marked, 3 unmarked, 1 rejected, 4 absent — deliberately distinct
            # counts, so a payload that reported the same number for every bucket
            # (or swapped two) fails instead of passing by coincidence.
            for i in 1:2
                p = sfixture(dir, "marked_$i.jld2")
                write_complete_marker(p, [p]; kind="point")
                @test admit_payload(p).provenance === :marked
            end
            for i in 1:3
                sub = mkpath(joinpath(dir, "store_$i"))
                @test admit_payload(predate!(sfixture(sub, "old.jld2"))).provenance === :unmarked
            end
            let p = sfixture(dir, "tombed.jld2")
                write_incomplete_marker(p, [p]; kind="point", reason="killed")
                @test admit_payload(p).provenance === :rejected
            end
            for i in 1:4
                @test admit_payload(joinpath(dir, "nope_$i.jld2")).provenance === :absent
            end

            out = joinpath(dir, "_exit_summary.json")
            _write_exit_summary(out; completed=true, exception_type=nothing,
                last_step=1, runtime_seconds=0.5,
                nan_encountered=false, oom_killed=false)

            d = read_summary(out)                       # FROM DISK, parsed
            @test haskey(d, "cache")
            adm = d["cache"]["admission"]
            @test adm["marked"] == 2
            @test adm["unmarked"] == 3
            @test adm["rejected"] == 1
            @test adm["absent"] == 4
            # The scope is stated, because both counters are process-cumulative
            # and a reader who assumes per-point would misread a scan.
            @test d["cache"]["scope"] == "process-cumulative"
        end
    end

    @testset "B: the no-artifact-id reasons reach the file, per reason" begin
        mktempdir() do dir
            _reset_admission_counts!()
            _reset_no_artifact_id_warnings!()

            out = joinpath(dir, "_exit_summary.json")
            # CONTROL: nothing has failed to resolve yet, so the list is empty —
            # not missing, and not a placeholder string.
            _write_exit_summary(out; completed=true, exception_type=nothing,
                last_step=1, runtime_seconds=0.1,
                nan_encountered=false, oom_killed=false)
            @test read_summary(out)["cache"]["no_id_reasons"] == Any[]

            # Two distinct reasons, one of them raised twice: the file must carry
            # the REASONS, deduplicated, not a count of warnings. That is the
            # ccache shape — a named reason is actionable, a total is not.
            @test_logs (:warn,) _warn_no_artifact_id_once("potential kind :sombrero has no spec")
            @test_logs _warn_no_artifact_id_once("potential kind :sombrero has no spec")  # silent
            @test_logs (:warn,) _warn_no_artifact_id_once("lhy kind :handmade has no spec")

            _write_exit_summary(out; completed=true, exception_type=nothing,
                last_step=1, runtime_seconds=0.1,
                nan_encountered=false, oom_killed=false)
            reasons = read_summary(out)["cache"]["no_id_reasons"]
            @test length(reasons) == 2
            @test any(r -> occursin("sombrero", r), reasons)
            @test any(r -> occursin("handmade", r), reasons)
        end
    end

    @testset "C: the FAILURE path stamps them too" begin
        # A run that threw is exactly the one whose cache behaviour someone will
        # want to reconstruct, so the stats cannot live only on the success path.
        mktempdir() do dir
            _reset_admission_counts!()
            _reset_unmarked_warnings!()
            @test admit_payload(joinpath(dir, "gone.jld2")).provenance === :absent

            out = joinpath(dir, "_exit_summary.json")
            _write_exit_summary(out; completed=false,
                exception_type="OutOfMemoryError", last_step=2,
                runtime_seconds=3.0, nan_encountered=false, oom_killed=true)
            d = read_summary(out)
            @test d["completed"] == false
            @test d["oom_killed"] == true
            @test d["cache"]["admission"]["absent"] == 1
        end
    end

    @testset "D: END TO END — a real `run_yaml` leaves the counts on disk" begin
        # The arms above call `_write_exit_summary` directly, which proves the
        # payload and not the WIRING. This one runs a two-point scan twice: the
        # second pass must be served from cache, and the file must say so.
        mktempdir() do dir
            y = joinpath(dir, "scan.yaml")
            write(
                y,
                """
       scan:
         zip:
           pipeline.0.interactions.N_atoms: [100, 2000]

       defaults: {kind: spinor, backend: cpu}
       pipeline:
         - ground_state:
             atom: Rb87
             grid: {n: [16], box: [8.0]}
             potential: {type: harmonic, omega: [1.0]}
             interactions: {N_atoms: 100, omega_ref: 100.0}
             ddi: {enabled: false}
             lhy: {kind: none}
             initial_state: polar
             method: itp
             n_steps: 40
             dt: 1.0e-3
             tol: 1.0e-6
       """,
            )
            _reset_admission_counts!()
            _reset_unmarked_warnings!()

            run_dir = run_yaml(y; base_dir=joinpath(dir, "out"), verbose=false)
            summary = joinpath(run_dir, "_exit_summary.json")
            @test isfile(summary)
            first_pass = read_summary(summary)["cache"]["admission"]
            # First pass: both points were absent before they were written.
            @test first_pass["absent"] >= 2
            @test first_pass["marked"] == 0

            # Second pass, fresh counters: the same two points are now MARKED
            # hits. This is the positive control for the whole file — it proves
            # the numbers move with what actually happened rather than being a
            # constant that any implementation would emit.
            _reset_admission_counts!()
            run_yaml(y; base_dir=joinpath(dir, "out"), verbose=false)
            second_pass = read_summary(summary)["cache"]["admission"]
            @test second_pass["marked"] >= 2
            @test second_pass["unmarked"] == 0
        end
    end
end
