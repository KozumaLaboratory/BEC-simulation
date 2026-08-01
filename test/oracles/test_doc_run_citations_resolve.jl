# Gate: a document may not cite a `runs/` path that does not exist, unless the
# citation says so on the spot.
#
# The first two versions kept a central `KNOWN_UNRESOLVED` name list. It needed
# three resyncs in a single day (2026-07-31) — twice by me, once by #232 —
# because every session that adds a document naming a run it has not produced yet
# had to edit a list in a test file. A list in one place cannot track documents
# several sessions are rewriting in parallel, and it cannot say WHY a citation is
# unresolved, which is the part a reader actually needs.
#
# So the knowledge moved to where the author is. An unresolved citation is
# allowed when its line carries one of:
#
#   (example)   invented for a tutorial — `runs/foo`, `runs/today`. Not evidence.
#   (planned)   intended, not yet produced. The `placeholder` rows of
#               manuscript/shared/figures.md are the bulk of these.
#   (archived)  it exists outside this repository. `runs/_loop/**` lives in
#               BEC-simulation-archive/loop_record_2026_06_08/, moved on purpose.
#   (gone)      never committed, or removed. The citation cannot be followed and
#               the claim on it needs regenerating or retracting — see
#               docs/campaign/doc_run_citation_inventory.md.
#
# Fenced code blocks are out of scope: a path inside a shell example is a command
# to type, not a claim that evidence exists. Measured when this was written — 27
# unresolved citations sat inside fences and 8 names appeared ONLY there, which is
# precisely the population the old PLACEHOLDERS list existed to excuse.
# `docs/archive/` stays out of scope for the reason #235 gave.
#
# What this cannot do: tell a truthful marker from a lazy one. `(gone)` is cheap
# to type. It makes the state visible and local; the inventory document is what
# tracks whether the underlying claim was dealt with.

using SpinorBEC
using Test

const _DOCS = joinpath(@__DIR__, "..", "..", "docs")
const _RUNS_DIR = joinpath(@__DIR__, "..", "..", "runs")
const _SEP = Base.Filesystem.path_separator

const MARKERS = ("example", "planned", "archived", "gone")
const _MARKER_RE = Regex("\\((" * join(MARKERS, "|") * ")\\)")

# `(?<![\w/-])` keeps `spinorbec-runs/x` and `some/runs/x` out. Without it the
# tail of any longer token reads as an in-repo citation — that defect put a 40 %
# over-count into a merged PR (#220, corrected in #227).
const _CITE_RE = r"(?<![\w/-])runs/([A-Za-z0-9_][A-Za-z0-9_.*-]*)"

"""A citation resolves if the directory exists, or — for a family written
`runs/foo_*` — if anything matches the prefix. Treating the stem as a literal
directory name is what made `runs/eu_k3_*` look broken next to `runs/eu_k3_lhy`."""
function _resolves(d)
    isdir(joinpath(_RUNS_DIR, d)) && return true
    endswith(d, '_') || return false
    isdir(_RUNS_DIR) || return false
    any(startswith(n, d) for n in readdir(_RUNS_DIR))
end

"""Walk live docs, yielding `(doc, line, name, resolves, marked, fenced)` for
every `runs/` citation. One pass so the four testsets cannot disagree about what
the tree contains."""
function _citations()
    out = NamedTuple{(:doc, :line, :name, :ok, :marked, :fenced),
        Tuple{String, Int, String, Bool, Bool, Bool}}[]
    isdir(_DOCS) || return out
    for (root, _, names) in walkdir(_DOCS), n in names
        endswith(n, ".md") || continue
        rel = relpath(joinpath(root, n), _DOCS)
        # Archived documents are a record of what was done, not a pointer a
        # reader is meant to follow today (#235).
        startswith(rel, "archive" * _SEP) && continue
        fenced = false
        for (i, line) in enumerate(eachline(joinpath(root, n)))
            if startswith(lstrip(line), "```")
                fenced = !fenced
                continue
            end
            marked = occursin(_MARKER_RE, line)
            for m in eachmatch(_CITE_RE, line)
                d = rstrip(m.captures[1], ['*', '.', ',', ')', ';', ':', '`'])
                isempty(d) && continue
                push!(out, (doc=rel, line=i, name=d, ok=_resolves(d),
                    marked=marked, fenced=fenced))
            end
        end
    end
    out
end

@testset "documents cite runs/ paths that resolve, or say why not" begin
    cites = _citations()

    @testset "the sweep is not vacuous" begin
        # If the walk, the regex or the fence tracking breaks, everything below
        # passes for the wrong reason. There ARE unresolved citations in the tree
        # — 45 outside fences when this was written — so an empty result is a bug
        # in the gate, not a clean repository.
        @test count(c -> !c.ok && !c.fenced, cites) > 0
    end

    @testset "every unresolved citation declares itself" begin
        undeclared = sort([
            "$(c.doc):$(c.line) runs/$(c.name)"
            for c in cites if !c.ok && !c.fenced && !c.marked
        ])
        for u in undeclared
            @info "Unresolved runs/ citation with no marker" location = u markers = MARKERS
        end
        # Named, not counted: a bare number tells the next reader nothing about
        # which citation they just broke.
        @test undeclared == String[]
    end

    @testset "a marker may not outlive its citation" begin
        # Otherwise `(gone)` accumulates on paths that came back and the marker
        # stops meaning anything — the rot the old name list was prone to.
        #
        # Per LINE, not per citation: a marker applies to its line, and a line can
        # legitimately name one path that resolves and one that does not. Two do
        # today (`guides/pipeline_cookbook.md:3`,
        # `research_notes/twa_pinned_16g_result.md:63`). Only a marked line with
        # NO unresolved citation on it is stale.
        live = Set((c.doc, c.line) for c in cites if !c.ok && !c.fenced)
        stale = sort(
            unique([
                "$(c.doc):$(c.line)" for c in cites
                if c.marked && !c.fenced && !((c.doc, c.line) in live)
            ]),
        )
        @test stale == String[]
    end

    @testset "fenced blocks are out of scope, and that exclusion is load-bearing" begin
        # Delete the fence tracking and these reappear as failures, so this is
        # scope rather than a hole nobody looks at.
        @test count(c -> !c.ok && c.fenced, cites) > 0
    end
end
