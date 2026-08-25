# `reanalyze` — the entry point for reading stored output a new way (#483).
#
# THE POSITIVE CONTROL IS THE POINT OF THIS FILE. #483's acceptance asks for the
# `97ec124e` re-extraction reproduced through the new path with the same numbers,
# because a re-analysis framework that reads something *slightly else* than the
# driver it replaces is worse than the driver: it produces plausible numbers
# nobody can tie back.
#
# `scripts/validation/klaus_weff_extract.jl::peak_padj` IS that re-extraction
# (`P_adj = P[:,2] + P[:,3]`, maximum taken over the last
# `floor(hold / (dt·save_every))` frames). It is included here and differenced
# against `reanalyze`, on a fixture built to carry the defect the correction was
# about — the whole-trajectory maximum sitting in the PRE-HOLD transient. The
# fixture's own control is asserted: if `whole ≈ hold` the comparison would pass
# for both a correct and a broken window, so the test demands they differ.

using Test
using JLD2
using JSON
using SpinorBEC

const _RA_HERE = @__DIR__
const _RA_REPO = normpath(joinpath(_RA_HERE, "..", ".."))

include(joinpath(_RA_REPO, "test", "helpers", "calibrated_scan.jl"))

# The driver under differential test. `include`d rather than reimplemented — a
# hand-copy of the reference would drift and the differential would compare two
# copies of the same mistake.
module _KlausExtract
include(
    joinpath(normpath(joinpath(@__DIR__, "..", "..")),
        "scripts", "validation", "klaus_weff_extract.jl"),
)
end

# --- fixture -----------------------------------------------------------------
#
# 42 frames, hold from frame 32 (the numbers §12.1 of the EdH decision doc
# states independently: 5.5292 / (0.005 · 100) = 11.06 → 11 hold frames,
# 42 − 11 = 31). The transient peaks at frame 29 — inside the pre-hold stretch —
# and the hold rises to a lower second maximum.
function _padj_series()
    n = 42
    s = zeros(Float64, n)
    for i in 1:31
        # Transient: rises to a maximum at 29, then decays into the hold.
        s[i] = 0.26050 * exp(-((i - 29)^2) / 60)
    end
    for i in 32:n
        # Hold: a smaller, genuinely interior maximum at frame 37.
        s[i] = 0.19000 + 0.02000 * exp(-((i - 37)^2) / 6)
    end
    s
end

function _write_point(dir, name, adj; git_hash="15a9f1ee", git_dirty=true,
    stamp=true, D=13)
    mkpath(dir)
    P = zeros(Float64, length(adj), D)
    # `P_adj` is components 2 and 3 (the two rungs below an `m_plus_F` seed).
    # Split the series across both so a reader that takes only one column fails.
    P[:, 2] .= 0.6 .* adj
    P[:, 3] .= 0.4 .* adj
    P[:, 1] .= 1.0 .- adj
    path = joinpath(dir, name)
    JLD2.jldopen(path, "w") do f
        f["dynamics/component_populations"] = P
        if stamp
            f["env/git_hash"] = git_hash
            f["env/git_dirty"] = git_dirty
        end
    end
    path
end

# The `series` extractor, written once and shared by every testset below.
function _padj_reader(path)
    JLD2.jldopen(path, "r") do g
        haskey(g, "dynamics") || return nothing
        d = g["dynamics"]
        haskey(d, "component_populations") || return nothing
        P = d["component_populations"]
        [P[i, 2] + P[i, 3] for i in axes(P, 1)]
    end
end

const _HOLD_FRAMES = 11      # floor(5.5292 / (0.005 * 100))

@testset "reanalyze — the reanalysis entry point (#483)" begin
    @testset "positive control: reproduces the 97ec124e re-extraction" begin
        mktempdir() do root
            dir = joinpath(root, "klaus_weff0p714_B10p4nT_deadbeef")
            adj = _padj_series()
            _write_point(dir, "point_001.jld2", adj)

            ref = _KlausExtract.peak_padj(dir; hold_duration=5.5292,
                dt=0.005, save_every=100)
            @test ref !== nothing

            # THE FIXTURE'S OWN CONTROL. If the whole-trajectory maximum equalled
            # the in-hold one, this differential would be satisfied by a window
            # that does nothing, which is exactly the bug 97ec124e fixed.
            @test ref.whole > ref.peak
            @test ref.whole_frame == 29
            @test ref.hold_from == 32

            obs = ObservableDefinition("peak P_adj in hold";
                window=:last, window_frames=_HOLD_FRAMES,
                reduction=:max, boundary="reject")
            ra = reanalyze(_padj_reader, dir;
                observable=obs, declare=SpinorBEC.REANALYSIS_DECLARATION,
                verbose=false)

            got = ra.values["point_001.jld2"]
            @test got !== nothing
            @test got == ref.peak                      # bit-identical, not ≈
            @test ra.windows["point_001.jld2"] == 32:42
            @test ra.readings["point_001.jld2"].argmax == ref.frame
            # The other two readings the driver keeps, from the same pass.
            @test ra.readings["point_001.jld2"].mean ≈ ref.mean
            @test ra.readings["point_001.jld2"].final == ref.final
        end
    end

    @testset "the whole-trajectory window reproduces the DEFECT" begin
        # A framework that cannot express the wrong window cannot demonstrate the
        # right one. `:all` must return the contaminated number, exactly.
        mktempdir() do root
            dir = joinpath(root, "arm")
            _write_point(dir, "point_001.jld2", _padj_series())
            ref = _KlausExtract.peak_padj(dir)
            obs = ObservableDefinition("peak P_adj over whole trajectory";
                window=:all, reduction=:max, boundary="accept")
            ra = reanalyze(_padj_reader, dir; observable=obs,
                declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)
            @test ra.values["point_001.jld2"] == ref.whole
            @test ra.readings["point_001.jld2"].argmax == ref.whole_frame
        end
    end

    @testset "vintage is aggregated and carried" begin
        mktempdir() do root
            dir = joinpath(root, "arm")
            adj = _padj_series()
            _write_point(dir, "point_001.jld2", adj; git_hash="15a9f1ee")
            _write_point(dir, "point_002.jld2", adj; git_hash="15a9f1ee")
            _write_point(dir, "point_003.jld2", adj; git_hash="306ef71a")
            _write_point(dir, "point_004.jld2", adj; stamp=false)

            obs = ObservableDefinition("peak P_adj in hold";
                window=:last, window_frames=_HOLD_FRAMES,
                reduction=:max, boundary="reject")
            ra = reanalyze(_padj_reader, dir; observable=obs,
                declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)

            @test ra.vintage.n_points == 4
            @test ra.vintage.commits == ["15a9f1ee", "306ef71a"]
            @test ra.vintage.counts["15a9f1ee"] == 2
            @test ra.vintage.counts["306ef71a"] == 1
            @test ra.vintage.n_unstamped == 1
            # `git_dirty = true` on the stamped ones, and an unstamped point
            # cannot claim to be clean.
            @test ra.vintage.n_dirty == 4
        end
    end

    @testset "a clean single-vintage read is still inadmissible" begin
        # The reasons must not collapse to "it was dirty". A re-read of a
        # perfectly-stamped clean point has NOT been through the ancestor gate,
        # and that reason has to survive on its own or the field becomes a proxy
        # for tree hygiene.
        mktempdir() do root
            dir = joinpath(root, "arm")
            _write_point(dir, "point_001.jld2", _padj_series();
                git_hash="cafebabe", git_dirty=false)
            obs = ObservableDefinition("peak P_adj in hold";
                window=:last, window_frames=_HOLD_FRAMES,
                reduction=:max, boundary="reject")
            ra = reanalyze(_padj_reader, dir; observable=obs,
                declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)
            @test ra.vintage.n_dirty == 0
            @test ra.vintage.n_unstamped == 0
            @test length(ra.vintage.commits) == 1
            @test ra.admissible === false
            @test length(ra.inadmissible_because) == 1
            @test occursin("not_ancestor_gated", only(ra.inadmissible_because))
        end
    end

    @testset "boundary: reject withholds a truncated maximum" begin
        mktempdir() do root
            dir = joinpath(root, "arm")
            # Monotone decay: the maximum of ANY trailing window is its first
            # frame, which is the truncation case — there is data beyond it.
            _write_point(dir, "point_001.jld2", [1.0 / i for i in 1:42])

            rej = ObservableDefinition("peak in hold"; window=:last,
                window_frames=_HOLD_FRAMES, reduction=:max, boundary="reject")
            ra = reanalyze(_padj_reader, dir; observable=rej,
                declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)
            @test ra.boundary_hits == ["point_001.jld2"]
            @test ra.values["point_001.jld2"] === nothing

            # `accept` is the other real historical answer (`edh-two-branches-5p2nt`)
            # and must still FLAG while returning the value.
            acc = ObservableDefinition("peak in hold"; window=:last,
                window_frames=_HOLD_FRAMES, reduction=:max, boundary="accept")
            ra2 = reanalyze(_padj_reader, dir; observable=acc,
                declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)
            @test ra2.boundary_hits == ["point_001.jld2"]
            @test ra2.values["point_001.jld2"] == 1.0 / 32

            # NEGATIVE CONTROL for the boundary detector: the interior maximum of
            # the real fixture must NOT be flagged, or "reject" would withhold
            # every peak and the rule would be switched off within a week.
            dir2 = joinpath(root, "arm2")
            _write_point(dir2, "point_001.jld2", _padj_series())
            ra3 = reanalyze(_padj_reader, dir2; observable=rej,
                declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)
            @test isempty(ra3.boundary_hits)
            @test ra3.values["point_001.jld2"] !== nothing
        end
    end

    @testset "the last frame of the run is not a truncation" begin
        # A maximum at the final frame has no data beyond it. Flagging it would
        # make `boundary = reject` refuse every monotonically-rising trajectory.
        mktempdir() do root
            dir = joinpath(root, "arm")
            _write_point(dir, "point_001.jld2", collect(1.0:42.0))
            obs = ObservableDefinition("peak in hold"; window=:last,
                window_frames=_HOLD_FRAMES, reduction=:max, boundary="reject")
            ra = reanalyze(_padj_reader, dir; observable=obs,
                declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)
            @test isempty(ra.boundary_hits)
            @test ra.values["point_001.jld2"] == 42.0
        end
    end

    @testset "the observable must be defined before a number exists" begin
        @test_throws ArgumentError ObservableDefinition("x";
            window=:last, window_frames=11, reduction=:max, boundary="whatever")
        @test_throws ArgumentError ObservableDefinition("x";
            window=:hold, reduction=:max, boundary="reject")
        @test_throws ArgumentError ObservableDefinition("x";
            window=:last, window_frames=11, reduction=:peak, boundary="reject")
        # A frame-counted window with no count is the "peak with no window" shape.
        @test_throws ArgumentError ObservableDefinition("x";
            window=:last, reduction=:max, boundary="reject")
        @test_throws ArgumentError ObservableDefinition("x";
            window=:range, window_frames=32, reduction=:max, boundary="reject")
        @test_throws ArgumentError ObservableDefinition("";
            window=:all, reduction=:max, boundary="n/a")
        # `unchecked` is LEGAL. It says nobody looked, which is information.
        @test ObservableDefinition("x"; window=:all, reduction=:mean,
            boundary="unchecked").boundary == "unchecked"
    end

    @testset "the boundary set is the ledger's, not a second list" begin
        # A retyped copy of `CLAIM_BOUNDARY_RULES` here would be the duplicated
        # statement this repo keeps paying for; the constructor must reject
        # anything the ledger rejects, derived from the ledger's own tuple.
        for b in SpinorBEC.CLAIM_BOUNDARY_RULES
            @test ObservableDefinition("x"; window=:all, reduction=:mean,
                boundary=b).boundary == b
        end
    end

    @testset "declaration is required and lands in the output" begin
        mktempdir() do root
            dir = joinpath(root, "arm")
            _write_point(dir, "point_001.jld2", _padj_series())
            obs = ObservableDefinition("peak"; window=:all, reduction=:max,
                boundary="accept")
            @test_throws ArgumentError reanalyze(_padj_reader, dir;
                observable=obs, declare="", verbose=false)
            @test_throws ArgumentError reanalyze(_padj_reader, dir;
                observable=obs, declare="yes I know", verbose=false)
            ra = reanalyze(_padj_reader, dir; observable=obs,
                declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)
            @test ra.declared == SpinorBEC.REANALYSIS_DECLARATION
            @test reanalysis_record(ra)["declared"] == SpinorBEC.REANALYSIS_DECLARATION
        end
    end

    @testset "SPINORBEC_ALLOW_STALE_POINTS is never set implicitly" begin
        mktempdir() do root
            dir = joinpath(root, "arm")
            _write_point(dir, "point_001.jld2", _padj_series())
            obs = ObservableDefinition("peak"; window=:all, reduction=:max,
                boundary="accept")

            # 1. The variable is not set, and reanalyze leaves it that way.
            withenv("SPINORBEC_ALLOW_STALE_POINTS" => nothing) do
                ra = reanalyze(_padj_reader, dir; observable=obs,
                    declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)
                @test !haskey(ENV, "SPINORBEC_ALLOW_STALE_POINTS")
                @test ra.stale_env === false
                @test reanalysis_record(ra)["allow_stale_points_ambient"] === false
                # And the recompute gate is still armed afterwards — the real
                # consequence of a leaked opt-out is that a DIFFERENT path starts
                # accepting stale points, so assert on that path, not on the var.
                @test_throws ErrorException SpinorBEC._assert_point_provenance(
                    joinpath(dir, "point_001.jld2"),
                    Dict{String, Any}("git_hash" => "deadbeef", "git_dirty" => false);
                    verbose=false)
            end

            # 2. An ambient opt-out is REPORTED, not silently inherited.
            withenv("SPINORBEC_ALLOW_STALE_POINTS" => "1") do
                ra = reanalyze(_padj_reader, dir; observable=obs,
                    declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)
                @test ra.stale_env === true
                @test reanalysis_record(ra)["allow_stale_points_ambient"] === true
            end
        end

        # 3. The source itself contains no assignment to the variable. The
        #    behavioural test above passes for a function that sets it and
        #    restores it, which would still leak inside a `do` block.
        src = read(joinpath(_RA_REPO, "src", "workflow", "validation",
                "reanalysis.jl"), String)
        hits = calibrated_scan([src];
            match=t -> count_matches(
                r"ENV\[\"SPINORBEC_ALLOW_STALE_POINTS\"\]\s*=[^=]", t) > 0,
            present="ENV[\"SPINORBEC_ALLOW_STALE_POINTS\"] = \"1\"",
            absent="get(ENV, \"SPINORBEC_ALLOW_STALE_POINTS\", \"0\") == \"1\"",
            describe=t -> first(t, 60))
        @test isempty(hits)
    end

    @testset "an absent block is missing, not skipped" begin
        mktempdir() do root
            dir = joinpath(root, "arm")
            _write_point(dir, "point_001.jld2", _padj_series())
            # A point with no dynamics block at all.
            JLD2.jldopen(joinpath(dir, "point_002.jld2"), "w") do f
                f["env/git_hash"] = "15a9f1ee"
                f["env/git_dirty"] = true
            end
            obs = ObservableDefinition("peak"; window=:all, reduction=:max,
                boundary="accept")
            ra = reanalyze(_padj_reader, dir; observable=obs,
                declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)
            @test haskey(ra.values, "point_002.jld2")
            @test ra.values["point_002.jld2"] === nothing
            # A point that yielded no series was not READ, so it must not be
            # counted in the vintage — a census that includes files it could not
            # open is the "0 of 219" mistake in miniature.
            @test ra.vintage.n_points == 1
            @test ra.sources == [joinpath(dir, "point_001.jld2")]
            # The record names the ARM as well as the point: across a scan every
            # point is `point_001.jld2` and a list of basenames is a list of
            # nothing.
            @test only(reanalysis_record(ra)["sources"]) ==
                joinpath("arm", "point_001.jld2")
        end
    end

    @testset "empty reads and impossible windows fail rather than return" begin
        mktempdir() do root
            obs = ObservableDefinition("peak"; window=:all, reduction=:max,
                boundary="accept")
            empty_dir = joinpath(root, "nothing_here")
            mkpath(empty_dir)
            @test_throws ArgumentError reanalyze(_padj_reader, empty_dir;
                observable=obs, declare=SpinorBEC.REANALYSIS_DECLARATION,
                verbose=false)
            @test_throws ArgumentError reanalyze(_padj_reader,
                joinpath(root, "no_such_dir"); observable=obs,
                declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)

            dir = joinpath(root, "arm")
            _write_point(dir, "point_001.jld2", _padj_series())
            # A window past the end of the data must throw, not clip: a clipped
            # window silently measures a different observable than the declared one.
            oob = ObservableDefinition("peak"; window=:range,
                window_frames=40:60, reduction=:max, boundary="accept")
            @test_throws ArgumentError reanalyze(_padj_reader, dir;
                observable=oob, declare=SpinorBEC.REANALYSIS_DECLARATION,
                verbose=false)
            # An empty predicate window is a failed selection, not a NaN.
            none = ObservableDefinition("peak"; window=:predicate,
                window_predicate=(i, aux) -> false, reduction=:max,
                boundary="accept")
            @test_throws ArgumentError reanalyze(_padj_reader, dir;
                observable=none, declare=SpinorBEC.REANALYSIS_DECLARATION,
                verbose=false)
        end
    end

    @testset "a predicate window can carry a physical condition" begin
        # `klaus2022_reanalyse.jl`'s real need: "the frames where θ has reached 0",
        # which no frame count expresses. The extractor returns `(series, aux)`
        # and the predicate reads `aux`.
        mktempdir() do root
            dir = joinpath(root, "arm")
            adj = _padj_series()
            _write_point(dir, "point_001.jld2", adj)
            reader = p -> begin
                s = _padj_reader(p)
                theta = [i <= 35 ? 0.6 : 0.0 for i in eachindex(s)]
                (s, theta)
            end
            obs = ObservableDefinition("mean P_adj where theta == 0";
                window=:predicate,
                window_predicate=(i, aux) -> aux[i] == 0.0,
                reduction=:mean, boundary="n/a")
            ra = reanalyze(reader, dir; observable=obs,
                declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)
            @test ra.windows["point_001.jld2"] == 36:42
            @test ra.values["point_001.jld2"] ≈ sum(adj[36:42]) / 7
        end
    end

    @testset "the record is machine-readable and says it is not evidence" begin
        mktempdir() do root
            dir = joinpath(root, "arm")
            _write_point(dir, "point_001.jld2", _padj_series())
            obs = ObservableDefinition("peak P_adj in hold"; window=:last,
                window_frames=_HOLD_FRAMES, reduction=:max, boundary="reject")
            ra = reanalyze(_padj_reader, dir; observable=obs,
                declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)
            rec = reanalysis_record(ra)

            @test rec["admissible"] === false
            @test any(r -> occursin("not_ancestor_gated", r),
                rec["inadmissible_because"])
            # The three ledger fields come out under the ledger's own names, so a
            # transcriber does not re-decide them.
            @test rec["reduction"] == "max"
            @test rec["boundary"] == "reject"
            @test occursin("last", rec["window"]) && occursin("11", rec["window"])
            # And the fields the ledger REQUIRES on a row are pre-filled with what
            # a re-read can honestly claim.
            @test rec["evidence_status"] in SpinorBEC.CLAIM_EVIDENCE_STATUSES
            @test rec["uncertainty_basis"] in SpinorBEC.CLAIM_UNCERTAINTY_BASES
            @test !isempty(rec["uncertainty"])
            @test rec["vintage_commits"] == ["15a9f1ee"]
            # JSON round-trip: the record is for writing beside an output.
            @test JSON.parse(JSON.json(rec))["admissible"] === false
        end
    end
end
