# Gate: a document may not cite a `runs/` path that does not exist.
#
# Measured 2026-07-31: of 70 distinct top-level `runs/` directories cited across
# `docs/**.md`, 43 are absent, and 27 of those were NEVER COMMITTED at any point
# in history — they lived in someone's working tree, a document cited them, and
# the citation is all that survives. `manuscript/shared/figures.md`, the thesis
# figure registry, names five of them. See
# `docs/campaign/doc_run_citation_inventory.md`.
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

# Cited, absent, and known. Each is a claim whose evidence cannot be followed.
# Shrinking this list is the campaign's job; growing it is what this gate stops.
const KNOWN_UNRESOLVED = Set([
    # never committed — no config, no output, no history
    "Cr_eps0.15_", "Dy_eps1.39_", "Er_eps0.88_", "Eu_eps0.55_", "Eu151_GS_64g",
    "ddi_convention_factorial", "ensemble_traces_round5", "eu151_",
    "eu_k3_", "eu_shape_optimization", "fig2_k3zero_v2", "fig2_k3zero_v3",
    "fortress_compare", "klaus_", "lhy_ablation_v2", "lhy_mode_ablation",
    "lyapunov_diagnostic_round6", "paper4_meanfield", "sigma_mu_scan_",
    "sigma_mu_scan_round5", "species_scan_round6", "sprint5_M1_",
    "sprint5_M1_multistart_groundstate", "twa_sinatra", "eu151_klaus_lab_units",
    "eu151_phi_omega", "12174e883326ecac",
    # once tracked, since removed. `_loop` was retired 2026-06-08 and moved to
    # BEC-simulation-archive/ deliberately; the rest simply went.
    "_loop", "eu151_edh_ext", "eu151_mz_scan", "eu151_phase_pq",
    "klaus_eu151_v2_full", "option_gamma_micro",
])

"""Top-level `runs/<dir>` names cited by each doc, with the citing file."""
function _cited_run_dirs()
    out = Dict{String, Vector{String}}()
    isdir(_DOCS) || return out
    pat = r"runs/([A-Za-z0-9_][A-Za-z0-9_.*-]*)"
    for (root, _, names) in walkdir(_DOCS), n in names
        endswith(n, ".md") || continue
        path = joinpath(root, n)
        rel = relpath(path, _DOCS)
        # `docs/archive/` is out of scope, deliberately. An archive is a RECORD of
        # what was thought at a date, not a live claim, so requiring its citations
        # to resolve contradicts what archiving it means — and the alternative,
        # pinning them in KNOWN_UNRESOLVED, grows the very list this gate exists to
        # stop growing.
        #
        # Not hypothetical: #221 imported research notes into docs/archive/ AFTER
        # #220 measured this gate's baseline, which put main red on 7 names
        # (eu151_b1_c1_sweep_template, klaus_eu151_mechanism_,
        # klaus_eu151_spin_excitation, klaus_option_gamma, klaus_option_gamma_full,
        # option_gamma_smoke, validation_level) cited from exactly two archived
        # files and from nothing live. Nobody saw it because the required checks do
        # not cover the ci or oracles tiers.
        startswith(rel, "archive/") && continue
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

    unresolved = sort([
        d for d in keys(cited)
              if !(d in PLACEHOLDERS) && !isdir(joinpath(_RUNS_DIR, d))
    ])

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
        resolved_again = sort([d for d in KNOWN_UNRESOLVED
                                     if isdir(joinpath(_RUNS_DIR, d))])
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
