# Every driver that re-reads a stored run is CLASSIFIED — migrated, or named with
# a reason.
#
# WHY THIS EXISTS. `reanalyze` (#483) is a new single source of truth for "read a
# stored run a new way": the observable is defined first (window / reduction /
# boundary), the vintage of the points read is carried in the result, and the
# result says in machine-readable form that it has not been through the ancestor
# gate. One driver was migrated with it.
#
# CLAUDE.md commitment 11 is that a new SSoT ships with the gate outlawing the old
# form, or the migration becomes permanent and the tree carries two live
# definitions of the same thing — measured over 411 fix commits, and the
# difference between the SSoTs that held and the ones that rotted was exactly
# whether the old spelling stayed legal. Stating the coverage gap in a PR body is
# not a gate. This is.
#
# THE DUPLICATION IS ALREADY REAL, which is why the list has to be named rather
# than assumed empty. `lt64_endpoint_verdict.jl` re-derives the in-hold window
# from the suite's own dt / save_every constants and says so in its own header:
#
#     THE WINDOW CONSTANTS ARE THIS SUITE'S, AND GETTING THEM WRONG IS SILENT.
#
# That is a second independent statement of the observable `97ec124e` had to fix,
# and it is exactly what `ObservableDefinition` exists to hold once.
#
# WHAT THIS GATE DOES NOT CLAIM. It does not say the un-migrated drivers are
# wrong — two of them have good reasons, recorded below. It says a FOURTH one
# cannot appear without someone deciding which bucket it is in.

using Test
using SpinorBEC

include(joinpath(@__DIR__, "helpers", "calibrated_scan.jl"))

const _RDC_REPO = normpath(joinpath(@__DIR__, ".."))

# Reading a STORED artifact — a point file, a frames file, or a result file. The
# marker of a re-analysis: the physics is not being re-run.
const _READS_STORED = r"point_0\d|point_\*|_frames\.jld2|result\.jld2"

# Already routed through the entry point.
const _MIGRATED = ["validation/klaus_weff_extract.jl"]

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
# distinguishable from an oversight. Every entry here is a known cost.
const _UNMIGRATED = Dict(
    "klaus2022_reanalyse.jl" =>
        "reduces SEVEN quantities per pass (axis_order, null ratio, baseline " *
        "ratio, prominence, misalignment, stripe count, frame count) over one " *
        "read of the frames. `reanalyze` is one-observable-per-call, so this " *
        "needs either seven passes over the same file or a multi-observable " *
        "API. Not extending the API speculatively for one caller.",
    "validation/klaus_weff_cloud_size.jl" =>
        "reads `psi_snapshots_streamed` and reduces a SPATIAL quantity (radial " *
        "RMS) per frame, not a saved per-frame scalar. It would fit the " *
        "`series` contract, and it is the next migration — listed rather than " *
        "done because it also carries the two-grid comparison this PR did not " *
        "touch.",
    "validation/lt64_endpoint_verdict.jl" =>
        "THE ONE THAT MATTERS. Re-derives the in-hold window from the suite's " *
        "dt / save_every constants — a second independent statement of the " *
        "observable 97ec124e fixed, and its own header says getting the " *
        "constants wrong is SILENT. Migrating it means moving a pre-registered " *
        "rejection criterion, which must not ride along in a refactor.",
)

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
            vcat(_MIGRATED, collect(keys(_NOT_REANALYSIS)),
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

    @testset "the migrated driver really goes through the entry point" begin
        # Membership in `_MIGRATED` is a claim about the file, so check the file.
        for s in _MIGRATED
            src = read(joinpath(_RDC_REPO, "scripts", s), String)
            @test occursin("reanalyze(", src)
            @test occursin("ObservableDefinition(", src)
            @test occursin("REANALYSIS_DECLARATION", src)
        end
    end

    @testset "every deferral carries a reason" begin
        # An empty reason is the shape this whole ledger-and-gate discipline
        # exists to outlaw: absent must never read as benign.
        for (k, v) in merge(_NOT_REANALYSIS, _UNMIGRATED)
            @test !isempty(strip(v))
            @test length(strip(v)) > 40      # a word is not a reason
        end
    end
end
