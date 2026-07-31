# Gate: a document may not cite a `runs/` path that does not exist.
#
# CORRECTED 2026-07-31 (same day): the first version of this file over-counted by
# 40 %. Its pattern had two defects, both found by reading the hits rather than
# the count.
#
#   1. `runs/` matched the TAIL of a longer token, so `spinorbec-runs/fig2_k3zero_v2`
#      — a TSUBAME path a document was recording honestly, one of them annotated
#      "(862 MB, off-repo)" — was read as a broken in-repo citation. 4 of them.
#   2. A glob citation like `runs/eu_k3_*` was resolved as a literal directory
#      named `eu_k3_`, which of course does not exist, while `runs/eu_k3_lhy` sits
#      right there. 3 of them.
#
# At the commit the inventory measured, absent goes 43 -> 26 once both are fixed.
# See `docs/campaign/doc_run_citation_inventory.md` for the corrected census and
# for which of the survivors actually back a claim — most do not.
#
# That is a different failure from the one `stored_results_vintage_audit.md`
# tracks. A stale run can be located, dated and disqualified; these cannot be
# compared against anything, because there is nothing to compare to.
#
# This gate is a RATCHET, not a cliff. Failing on all 33 today would put main red
# and teach nothing, so the existing breakage is pinned in `KNOWN_UNRESOLVED` and
# what is asserted is that the set does not GROW. It is also checked in the other
# direction: an entry that starts resolving must be removed from the list, or the
# list rots into a permanent excuse the way a stale KNOWN-LIMIT does.

using Test

const _DOCS = joinpath(@__DIR__, "..", "..", "docs")
const _RUNS_DIR = joinpath(@__DIR__, "..", "..", "runs")

# Names that are illustrative by construction — tutorials and cookbooks invent a
# run to show a command. They are not evidence and must never be.
const PLACEHOLDERS = Set([
    "foo", "today", "samples", "baseline", "perturbed", "N", "lab", "shared",
    "tsubame_scan", "_dashboard_cache",
])

# Cited, absent, and known. Regenerated 2026-07-31 with the corrected pattern.
#
# A NAME list churns: every session that adds a document naming a run it has not
# produced yet has to edit this file. The better shape is a marker at the citation
# site — `(planned)`, `(off-repo)`, `(archived)` — so the knowledge lives where the
# author is, and this list shrinks to the genuinely unexplained. That redesign is
# deliberately NOT done here, because it means editing ~30 citation sites across
# documents several sessions are actively rewriting, and it would collide.
const KNOWN_UNRESOLVED = Set([
    "12174e883326ecac", "Cr_eps0.15_", "Dy_eps1.39_", "Er_eps0.88_",
    "Eu151_GS_64g", "Eu_eps0.55_", "_loop", "ddi_convention_factorial",
    "ensemble_traces_round5", "eu151_edh_ext",
    "eu151_klaus_lab_units", "eu151_mz_scan", "eu151_phase_pq",
    "eu151_phi_omega", "fortress_compare",
    "klaus_eu151_v2_full",
    "lhy_mode_ablation", "lyapunov_diagnostic_round6",
    "option_gamma_micro", "paper4_meanfield",
    "sigma_mu_scan_", "sigma_mu_scan_round5", "species_scan_round6",
    "sprint5_M1_", "sprint5_M1_multistart_groundstate", "twa_sinatra",
])

"""A citation resolves if the directory exists, or — for a family written
`runs/foo_*` — if anything matches the prefix. Treating the stem as a literal
directory name is what made `runs/eu_k3_*` look broken next to `runs/eu_k3_lhy`."""
function _resolves(d)
    isdir(joinpath(_RUNS_DIR, d)) && return true
    # Prefix-match ONLY for a family stem — the `*` is stripped above, so the
    # trailing underscore is what is left of `runs/foo_*`. Applying the prefix
    # rule to every name would let `runs/eu151_edh_ext` resolve against any
    # directory that merely starts with it, which is a different claim.
    endswith(d, '_') || return false
    isdir(_RUNS_DIR) || return false
    any(startswith(n, d) for n in readdir(_RUNS_DIR))
end

"""Top-level `runs/<dir>` names cited by each doc, with the citing file."""
function _cited_run_dirs()
    out = Dict{String, Vector{String}}()
    isdir(_DOCS) || return out
    # `(?<![\w/-])` keeps `spinorbec-runs/x` and `some/runs/x` out. Without it
    # the tail of any longer token reads as an in-repo citation.
    pat = r"(?<![\w/-])runs/([A-Za-z0-9_][A-Za-z0-9_.*-]*)"
    for (root, _, names) in walkdir(_DOCS), n in names
        endswith(n, ".md") || continue
        path = joinpath(root, n)
        rel = relpath(path, _DOCS)
        for m in eachmatch(pat, read(path, String))
            # Trim trailing punctuation and the glob star a doc writes for a family.
            d = rstrip(m.captures[1], ['*', '.', ',', ')', ';', ':', '`'])
            isempty(d) && continue
            push!(get!(out, d, String[]), rel)
        end
    end
    out
end

@testset "documents cite runs/ paths that resolve" begin
    cited = _cited_run_dirs()

    @testset "the sweep found citations" begin
        # A zero here makes every assertion below vacuous — the same shape this
        # file exists to catch elsewhere.
        @test length(cited) > 20
    end

    unresolved = sort([d for d in keys(cited)
                             if !(d in PLACEHOLDERS) && !_resolves(d)])

    @testset "no NEW unresolved citation" begin
        fresh = [d for d in unresolved if !(d in KNOWN_UNRESOLVED)]
        for d in fresh
            @info "Document cites runs/$d, which does not exist" citers=cited[d]
        end
        # Naming them rather than asserting a count: a bare number tells the next
        # reader nothing about which citation they just broke.
        @test fresh == String[]
    end

    @testset "the known-unresolved list does not rot" begin
        # An entry that now resolves, or that nothing cites any more, is an
        # excuse outliving its reason. Both directions, so the list tracks
        # reality instead of accumulating.
        resolved_again = sort([d for d in KNOWN_UNRESOLVED if _resolves(d)])
        @test resolved_again == String[]
        uncited = sort([d for d in KNOWN_UNRESOLVED if !haskey(cited, d)])
        @test uncited == String[]
    end

    @testset "placeholders stay placeholders" begin
        # If a tutorial name ever becomes a real directory, the allowlist starts
        # hiding a real citation instead of an invented one.
        for d in PLACEHOLDERS
            @test !isdir(joinpath(_RUNS_DIR, d))
        end
    end
end
