# Every driver that re-reads a stored run is CLASSIFIED — migrated, or named with
# a reason.
#
# WHY THIS EXISTS. `reanalyze` (#483) is a new single source of truth for "read a
# stored run a new way": the observable is defined first (window / reduction /
# boundary), the vintage of the points read is carried in the result, and the
# result says in machine-readable form that it has not been through the ancestor
# gate.
#
# CLAUDE.md commitment 11 is that a new SSoT ships with the gate outlawing the old
# form, or the migration becomes permanent and the tree carries two live
# definitions of the same thing — measured over 411 fix commits, and the
# difference between the SSoTs that held and the ones that rotted was exactly
# whether the old spelling stayed legal. Stating the coverage gap in a PR body is
# not a gate. This is.
#
# ALL FOUR ARE NOW MIGRATED (2026-08-26). Three were deferred when the entry point
# landed, and TWO OF THE THREE CARRIED THE SAME REASON — one pass over an
# expensive file yields many numbers, and a one-observable-per-call API would have
# meant re-reading streamed ψ snapshots once per number. A deferral whose reason
# two callers share is a missing API, not a deferral; `observables = [...]` is
# that API. The third, `lt64_endpoint_verdict.jl`, was the one that mattered: it
# re-derived the in-hold window from the suite's own constants and said so in its
# own header —
#
#     THE WINDOW CONSTANTS ARE THIS SUITE'S, AND GETTING THEM WRONG IS SILENT.
#
# — a second independent statement of the observable `97ec124e` had to fix. Both
# halves of it are now single statements: `hold_window_frames` computes the frame
# count, and `reanalyze` REFUSES a window longer than the array instead of
# clamping it to the whole trajectory. The entry point itself had the clamp until
# this migration, so migrating the driver is what found it.
#
# WHAT THIS GATE CHECKS. Every script that reads a stored run artifact is in
# exactly one bucket: migrated, or named as not-a-re-analysis with a reason. A
# migrated driver must go through the entry point AND keep its old reduction as a
# reference it is differenced against — these arms cannot be re-run, so "the
# numbers still look right" is not available and the differential is the only
# thing standing between a routing change and a silently different observable.
#
# WHAT IT DOES NOT CLAIM. It does not verify a driver against its real data; no
# such data is in the tree. It says a FIFTH reader cannot appear without someone
# deciding which bucket it is in.

using Test
using SpinorBEC

include(joinpath(@__DIR__, "helpers", "calibrated_scan.jl"))

const _RDC_REPO = normpath(joinpath(@__DIR__, ".."))

# Reading a STORED artifact — a point file, a frames file, or a result file. The
# marker of a re-analysis: the physics is not being re-run.
const _READS_STORED = r"point_0\d|point_\*|_frames\.jld2|result\.jld2"

# Already routed through the entry point, each with the reference it is
# differenced against. The value is not decoration: a migrated driver that stops
# differencing its old reduction is a routing change nobody can check, and the
# note is what says which reference the gate should find.
const _MIGRATED = Dict(
    "validation/klaus_weff_extract.jl" => "reference: `peak_padj` re-opens the point and re-states the window",
    "validation/lt64_endpoint_verdict.jl" =>
        "reference: `arm_values` re-opens the point and re-states the window, " *
        "keeping its historical `max(1, …)` clamp so a short arm makes the two " *
        "definitions disagree loudly instead of both widening",
    "validation/klaus_weff_cloud_size.jl" =>
        "reference: `reference_reduction` re-states the window and the nine " *
        "reductions over the SAME arrays — it gates the reduction, not the read",
    "klaus2022_reanalyse.jl" =>
        "reference: `summarise` re-states the window and the seven reductions " *
        "over the same extracted frames",
)

# Reads a stored artifact but is NOT a re-analysis, with the reason. A named list,
# because a rule wide enough to excuse these would excuse a real driver too.
const _NOT_REANALYSIS = Dict(
    # The PRODUCER of the frames the re-analysis reads. It runs the dynamics.
    "klaus2022_reproduce.jl" => "produces the frames rather than reducing them — it runs the physics",
    # A storage operation: rewrites oversized result.jld2 in place via the gated
    # reducer. Reads no observable and reports no number.
    "reduce_result_backlog.jl" =>
        "storage sweep, not an observable read — calls the gated reducer and " *
        "reports bytes",
)

# Re-analysis drivers NOT migrated, each with the reason, so a deferral is
# distinguishable from an oversight. EMPTY as of 2026-08-26 — the three entries
# that stood here were migrated rather than re-justified, and the two that shared
# a reason are what produced the multi-observable form of `reanalyze`. The Dict
# stays, because the next deferral needs somewhere to be written down.
const _UNMIGRATED = Dict{String, String}()

"Every `.jl` under `scripts/` that reads a stored run artifact."
function _artifact_reading_scripts()
    out = String[]
    root = joinpath(_RDC_REPO, "scripts")
    for (dir, _, files) in walkdir(root), f in files
        endswith(f, ".jl") || continue
        p = joinpath(dir, f)
        occursin(_READS_STORED, read(p, String)) || continue
        push!(out, relpath(p, root))
    end
    sort(out)
end

@testset "every stored-run reader is migrated or named (#483 coverage)" begin
    scripts = _artifact_reading_scripts()

    @testset "the scan can see what it is looking for" begin
        # CALIBRATION. A corpus of zero and "no unclassified drivers" print the
        # same result, and this gate's whole point is that a FOURTH driver must
        # be visible.
        hits = calibrated_scan(scripts;
            match=s -> occursin(_READS_STORED, read(
                joinpath(_RDC_REPO, "scripts", s), String)),
            present="klaus2022_reanalyse.jl",
            absent="cli.jl")
        @test length(hits) == length(scripts)
        @test length(scripts) >= 4
        # The positive control is a driver that IS one, spelled as it is on disk.
        @test "klaus2022_reanalyse.jl" in scripts
        # ...and the negative control is a script that reads no stored artifact.
        @test !("cli.jl" in scripts)
    end

    @testset "each reader is in exactly one bucket" begin
        classified = Set(
            vcat(collect(keys(_MIGRATED)), collect(keys(_NOT_REANALYSIS)),
                collect(keys(_UNMIGRATED))),
        )
        unclassified = setdiff(Set(scripts), classified)
        isempty(unclassified) || @info """
            A script under scripts/ reads a stored run artifact and is not
            classified. Decide which it is and say so in
            test/test_reanalysis_driver_coverage.jl:

              * a re-analysis → route it through `reanalyze` and add it to
                _MIGRATED (see validation/klaus_weff_extract.jl, which keeps
                `peak_padj` as the reference it is differenced against);
              * not a re-analysis → _NOT_REANALYSIS, with the reason;
              * a re-analysis you are deferring → _UNMIGRATED, with the reason.

            Do NOT re-implement a window or a reduction inline. That is the
            duplication `ObservableDefinition` exists to hold once, and
            lt64_endpoint_verdict.jl is the instance already in the tree.
            """ unclassified
        @test isempty(unclassified)

        # And the lists do not name files that are gone — a stale exemption is an
        # exemption nobody can evaluate.
        for s in classified
            @test isfile(joinpath(_RDC_REPO, "scripts", s))
        end
    end

    @testset "the migrated drivers really go through the entry point" begin
        # Membership in `_MIGRATED` is a claim about the file, so check the file.
        for (s, note) in _MIGRATED
            src = read(joinpath(_RDC_REPO, "scripts", s), String)
            @test occursin("reanalyze(", src)
            @test occursin("ObservableDefinition(", src)
            @test occursin("REANALYSIS_DECLARATION", src)
            # AND KEEPS ITS REFERENCE. These arms cannot be re-run, so the old
            # reduction differenced against the new path is the only check that a
            # routing change did not quietly become a different observable. A
            # driver that drops it must say so by editing its note here.
            if startswith(note, "reference:")
                @test occursin("REFERENCE DISAGREES", src)
            end
        end
        # THE FRAME COUNT IS DERIVED, NOT RE-TYPED — for the window that is
        # actually handed to `reanalyze`. The inline `floor(hold / (dt *
        # save_every))` still appears in the REFERENCES, deliberately: a
        # reference that delegates to the thing it is checking is not one. So the
        # rule binds the declared window only.
        with_frames = [
            s for (s, _) in _MIGRATED
            if occursin("window_frames",
                read(joinpath(_RDC_REPO, "scripts", s), String))
        ]
        # ...and the corpus is asserted, because "no file declares a frame
        # window" and "the check never ran" print the same nothing.
        @test length(with_frames) >= 3
        for s in with_frames
            @test occursin("hold_window_frames",
                read(joinpath(_RDC_REPO, "scripts", s), String))
        end
    end

    @testset "every deferral carries a reason" begin
        # An empty reason is the shape this whole ledger-and-gate discipline
        # exists to outlaw: absent must never read as benign.
        for (k, v) in merge(_NOT_REANALYSIS, _UNMIGRATED, _MIGRATED)
            @test !isempty(strip(v))
            @test length(strip(v)) > 40      # a word is not a reason
        end
    end
end
