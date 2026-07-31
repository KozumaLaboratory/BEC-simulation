# Live claims cite evidence that was never in the repository

**Measured 2026-07-31 on `f2352c7f`.** Closes the gap
`docs/campaign/CAMPAIGN.md` §1 leaves open — "a guard written to scan only
`runs/` on main would miss ~251 files. Worth pinning down before S-G0 writes the
pre-flight check."

Pinning it down changed the question. The vintage audit
([`stored_results_vintage_audit.md`](../validation/stored_results_vintage_audit.md))
asks whether the 481 stored summaries are current. It presumes the evidence for a
claim can be found and compared. For a large share of live claims it cannot,
because the directory the claim cites has never existed in git.

## The measurement

| | |
|---|---|
| distinct top-level `runs/` dirs cited across `docs/**.md` | 70 |
| …that do not exist in the tree | **43** |
| …of those, tutorial placeholders (`runs/foo`, `runs/today`, …) | 10 |
| **real missing directories** | **33** |
| of which **never committed at any point in history** | **27** |
| of which once tracked and since removed | 6 |
| real missing dirs cited by manuscript / validation / research docs | **24** |

The 6 that were once tracked are `_loop` (retired 2026-06-08 and moved outside
the repo), `eu151_edh_ext`, `eu151_mz_scan`, `eu151_phase_pq`,
`klaus_eu151_v2_full`, `option_gamma_micro`.

The other **27 were never committed**. They existed in someone's working tree,
were cited by a document, and the citation is all that remains. A fresh clone has
never had them. That is not staleness — a stale run can at least be located,
dated and disqualified. These cannot be compared against anything.

## Where it bites hardest

`manuscript/shared/figures.md` — the thesis figure registry — cites **five**
missing directories (`lyapunov_diagnostic_round6`, `sigma_mu_scan_round5`,
`species_scan_round6`, `paper4_meanfield`, `ensemble_traces_round5`) and carries
no vintage pointer. Each row names a figure and the run its data came from; none
of those runs is in the repo.

Other evidence citations resolving to nothing:

| cited path | claimed by |
|---|---|
| `runs/lhy_mode_ablation/` (+5 mode subdirs) | `Ch2_framework.md`, `Ch5_TWA_chaotic_dynamics_integrated.md`, `AppendixB_spinorbec_api.md` — the LHY-insufficiency result (Ch.5 §5.2, T3.1) |
| `runs/fig2_k3zero_v2`, `runs/fig2_k3zero_v3` | `four_figure_spec_2026_05_26.md` — Figure 2, whose premise a re-derivation already found gone |
| `runs/twa_sinatra/` | `figures_update_2026-05-11.md`, `AppendixB`, `Ch5_TWA` |
| `runs/lhy_ablation_v2` | `research_notes/eu_collapse_lhy_insufficient.md` |
| `runs/ddi_convention_factorial/results.jld2` | `self_contained_validation_report.md` |
| `runs/fortress_compare/spinorbec_side/` | `fortress_cross_check_scope.md` |
| `runs/sprint5_M1_multistart_groundstate/` | `m1_groundstate_audit_2026-06-08.md` |
| `runs/_loop/{theorist,sim}/turn_115.md` | `paper3_universal_theorem/sign_pattern_lemma1_general_S.md` — the derivation provenance for Lemma 1, in a tree deliberately moved outside this repo |
| `runs/{Cr,Er,Eu,Dy}_eps*_*/`, `runs/Eu151_GS_64g` | `AppendixB_spinorbec_api.md` |

## The vintage pointer covers 5 documents, not 7

The audit states that each of the documents citing stored runs "now carries a
one-line pointer here". Of the seven it lists, **five do**. Two never got it:
`manuscript/shared/figures.md` and
`manuscript/klaus_quench_protocol_spec_2026_05_26.md`. Across all 27 documents
that cite `runs/` paths, 5 carry the pointer.

## What this means for the campaign

The charter's framing — *"not to re-run 230 suites; to make every live claim
re-derivable"* — still holds, but the work splits in two, and only one half is
re-derivation:

1. **Claims whose run exists somewhere** (the 481, in five worktrees). Locate,
   check ancestry against the fix-list, re-run what a live document claims.
   `project_stored_results_inventory_2026_07_30` in memory has the locations.
2. **Claims whose run never existed in the repo** (27 directories, 24 of them
   cited by manuscript/validation/research docs). Nothing to compare to and no
   config to re-run from. Each is a regenerate-or-retract decision, and it cannot
   be made by looking at the run — the run is gone. This is the half nobody has
   scoped.

Neither half is started here. What is installed is the gate that stops the
population growing: `test/oracles/test_doc_run_citations_resolve.jl` fails when a
document cites a `runs/` path that does not resolve, unless the path is an
allowlisted tutorial placeholder or an explicitly recorded external/retired tree.
A citation that cannot be followed is not evidence, and the cheapest moment to
say so is before it merges.
