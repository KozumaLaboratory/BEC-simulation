# W2: a non-converged ground state used to get a completion marker and be served.
#
# Before this file: `run_step_ground_state.jl` wrote the marker under
# `if cache_path !== nothing && !gs_interrupted`, wrote `gs.converged` INTO the
# payload, and `grep converged src/model/complete.jl` found ONE occurrence — in a
# comment. Admission never read it. `_finish_point!` checked `:interrupted` and
# `isfinite`, not convergence, not norm drift, not energy drift.
#
# That is Bazel issue 16179: the action succeeded, the blobs uploaded, the
# action-cache entry was written, and the quality check failed afterwards.
#
# The fix asserted here is NOT "refuse to mark a non-converged solve" — this
# repo measured that the default `tol = 1e-8` is below the ~5e-7 gradient floor,
# so `converged = false, floor_limited = true` is the best achievable answer, not
# a failure. The fix is that the marker CARRIES the verdict and admission can be
# asked to REQUIRE it. Hence the two halves below:
#
#   A. the verdict round-trips, all four fields, and a partial one is an error;
#   B. `require_converged` refuses what it should and — the canary that matters —
#      the DEFAULT still admits every one of those cases unchanged.
#
# (B)'s default arm is the positive control for the whole knob: without it,
# "require_converged rejects" would pass equally against an `admit_payload` that
# rejected everything.

using Test
using TOML
using SpinorBEC
using SpinorBEC: marker_path, incomplete_marker_path, write_complete_marker,
    write_incomplete_marker, read_complete_marker, admit_payload,
    CompletionMarker, MarkerVerdict, gs_verdict, COMPLETE_MARKER_FORMAT,
    _reset_unmarked_warnings!

vfixture(dir, name, nbytes=64) = begin
    p = joinpath(dir, name)
    write(p, rand(UInt8, nbytes))
    p
end

# The two verdicts the campaign distinguishes, spelled out once.
const V_CONVERGED = MarkerVerdict(true, "tol", false, 3.1e-9)
const V_FLOOR = MarkerVerdict(false, "line_search_stalled", true, 5.0e-7)
const V_FAILED = MarkerVerdict(false, "max_steps", false, 2.4e-3)

@testset "W2: the completion marker carries the solve's verdict" begin
    @testset "A1: all four fields round-trip through TOML" begin
        mktempdir() do dir
            p = vfixture(dir, "gs.jld2")
            mp = write_complete_marker(p, [p]; kind="ground_state", verdict=V_FLOOR)
            m = read_complete_marker(mp)
            @test m isa CompletionMarker
            @test m.verdict isa MarkerVerdict
            @test m.verdict.converged === false
            @test m.verdict.stop_reason == "line_search_stalled"
            @test m.verdict.floor_limited === true
            @test m.verdict.grad_norm == 5.0e-7
            # The field a person greps for is literally in the file, in a
            # `[verdict]` table — not encoded, not inside the JLD2.
            txt = read(mp, String)
            @test occursin("[verdict]", txt)
            @test occursin("converged = false", txt)
            @test occursin("floor_limited = true", txt)
        end
    end

    @testset "A2: NaN grad_norm survives (the ITP reports none)" begin
        mktempdir() do dir
            p = vfixture(dir, "gs.jld2")
            mp = write_complete_marker(p, [p]; kind="ground_state",
                verdict=MarkerVerdict(true, "unknown", false, NaN))
            m = read_complete_marker(mp)
            @test isnan(m.verdict.grad_norm)
            @test m.verdict.stop_reason == "unknown"
            # CANARY for the codec: TOML must spell it `nan`, not drop the key.
            @test occursin("grad_norm = nan", read(mp, String))
        end
    end

    @testset "A3: no verdict is `nothing`, not a default-valued one" begin
        mktempdir() do dir
            p = vfixture(dir, "dyn.jld2")
            mp = write_complete_marker(p, [p]; kind="dynamics")
            m = read_complete_marker(mp)
            @test m.verdict === nothing
            @test !occursin("verdict", read(mp, String))
        end
    end

    @testset "A4: a PARTIAL verdict is an error, not a guessed default" begin
        mktempdir() do dir
            p = vfixture(dir, "gs.jld2")
            mp = write_complete_marker(p, [p]; kind="ground_state", verdict=V_CONVERGED)
            d = TOML.parsefile(mp)
            # Control: it parses as written.
            @test read_complete_marker(mp).verdict.converged
            for missing_key in ("converged", "stop_reason", "floor_limited", "grad_norm")
                bad = deepcopy(d)
                delete!(bad["verdict"], missing_key)
                open(io -> TOML.print(io, bad; sorted=true), mp, "w")
                @test_throws ArgumentError read_complete_marker(mp)
            end
            # …and an unknown key inside the table is closed too.
            bad = deepcopy(d)
            bad["verdict"]["quality"] = "good"
            open(io -> TOML.print(io, bad; sorted=true), mp, "w")
            @test_throws ArgumentError read_complete_marker(mp)
        end
    end

    @testset "A5: `gs_verdict` reads the pipeline's four keys, or `nothing`" begin
        r = Dict{Symbol, Any}(
            :ground_state_converged => false,
            :ground_state_stop_reason => "line_search_stalled",
            :ground_state_floor_limited => true,
            :ground_state_grad_norm => 5.0e-7,
        )
        @test gs_verdict(r) == V_FLOOR
        # A dynamics-only pipeline: no verdict is invented for a solve that did
        # not happen.
        @test gs_verdict(Dict{Symbol, Any}(:dynamics_history => [1])) === nothing
        # ITP shape: only `converged` is published, the rest default.
        v = gs_verdict(Dict{Symbol, Any}(:ground_state_converged => true))
        @test v.converged && v.stop_reason == "unknown" && !v.floor_limited
        @test isnan(v.grad_norm)
    end

    @testset "B: admission — `require_converged` refuses, the DEFAULT does not" begin
        # Every case is asserted BOTH ways. The default arm is the positive
        # control: it proves the fixture reaches admission at all and that this
        # pass did not silently change what today's runs admit.
        mktempdir() do dir
            _reset_unmarked_warnings!()

            @testset "converged: admitted either way" begin
                p = vfixture(dir, "ok.jld2")
                write_complete_marker(p, [p]; kind="ground_state", verdict=V_CONVERGED)
                @test admit_payload(p).provenance === :marked
                @test admit_payload(p; require_converged=true).provenance === :marked
                @test admit_payload(p; require_converged=true).hit
            end

            @testset "floor-limited: served by default, refused when required" begin
                p = vfixture(dir, "floor.jld2")
                write_complete_marker(p, [p]; kind="ground_state", verdict=V_FLOOR)
                # DEFAULT — unchanged, and this is the case the design says must
                # stay servable: it is the best answer the method can produce.
                a = admit_payload(p)
                @test a.hit && a.provenance === :marked
                @test a.marker.verdict.floor_limited
                # The richer decision needs no second knob: it is on the marker.
                r = admit_payload(p; require_converged=true)
                @test !r.hit && r.provenance === :rejected
                @test occursin("converged = false", r.reason)
                @test occursin("floor_limited = true", r.reason)
            end

            @testset "outright failure: served by default, refused when required" begin
                p = vfixture(dir, "failed.jld2")
                write_complete_marker(p, [p]; kind="ground_state", verdict=V_FAILED)
                @test admit_payload(p).hit
                r = admit_payload(p; require_converged=true)
                @test !r.hit && r.provenance === :rejected
                @test occursin("max_steps", r.reason)
            end

            @testset "no verdict at all: served by default, refused when required" begin
                p = vfixture(dir, "noverdict.jld2")
                write_complete_marker(p, [p]; kind="dynamics")
                @test admit_payload(p).provenance === :marked
                r = admit_payload(p; require_converged=true)
                @test !r.hit && r.provenance === :rejected
                @test occursin("no [verdict]", r.reason)
            end

            @testset "UNMARKED cannot bypass the knob" begin
                # The whole legacy population is unmarked. If arm (b) satisfied
                # `require_converged`, the knob would be bypassable by most of
                # the tree — which is the defect, not the fix.
                sub = mkpath(joinpath(dir, "legacy"))
                p = vfixture(sub, "old.jld2")
                # 2023-11-14, comfortably before the marker cutover, so this is
                # arm (b) proper rather than a W3 date rejection. A literal and
                # not `MARKER_CUTOVER_UNIX`: this file gates W2 and must stay
                # green if W3 is reverted on its own.
                run(pipeline(`touch -d @1700000000 $p`; stdout=devnull))
                @test admit_payload(p).provenance === :unmarked   # control
                r = admit_payload(p; require_converged=true)
                @test !r.hit && r.provenance === :rejected
                @test occursin("no verdict", r.reason)
            end

            @testset "a tombstone still out-votes, verdict or not" begin
                p = vfixture(dir, "tomb.jld2")
                write_complete_marker(p, [p]; kind="ground_state", verdict=V_CONVERGED)
                @test admit_payload(p; require_converged=true).provenance === :marked
                write_incomplete_marker(p, [p]; kind="point", reason="killed")
                @test admit_payload(p).provenance === :rejected
                @test admit_payload(p; require_converged=true).provenance === :rejected
            end

            @testset "truncation still wins over a converged verdict" begin
                # ORDER matters: a truncated payload with `converged = true` must
                # be rejected for its BYTES, not admitted for its opinion.
                p = vfixture(dir, "short.jld2", 512)
                write_complete_marker(p, [p]; kind="ground_state", verdict=V_CONVERGED)
                @test admit_payload(p; require_converged=true).provenance === :marked
                open(io -> truncate(io, 200), p, "r+")
                r = admit_payload(p; require_converged=true)
                @test r.provenance === :rejected
                @test occursin("bytes", r.reason)
            end
        end
    end

    @testset "C: the writers pass a verdict, not a placeholder" begin
        # Grep-level gate on the two production writers. It is here because the
        # end-to-end arms (`test_admission_requires_marker.jl`,
        # `test_scan_path_admission.jl`) run a real solve and are the expensive
        # instrument; this catches the cheap regression of someone dropping the
        # kwarg back off a call site.
        root = pkgdir(SpinorBEC)
        gs_src = read(
            joinpath(root, "src", "workflow", "experiments", "pipeline",
                "run_step_ground_state.jl"), String)
        @test occursin("verdict=gs_v", gs_src)
        # The verdict feeding the marker and the one feeding `step_result` are
        # the SAME object — two `get(gs, :floor_limited, …)` sites would be two
        # places to drift.
        @test occursin(":ground_state_floor_limited => gs_v.floor_limited", gs_src)
        @test occursin(":ground_state_grad_norm => gs_v.grad_norm", gs_src)

        pt_src = read(
            joinpath(root, "src", "workflow", "experiments", "pipeline",
                "run_registry.jl"), String)
        @test occursin("verdict=gs_verdict(result)", pt_src)
        dyn_src = read(joinpath(root, "src", "workflow", "io",
                "save_rotating_result.jl"), String)
        @test occursin("verdict=gs_verdict(result)", dyn_src)
    end
end
