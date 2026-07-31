# Which cited run directories are missing, and which of them back a claim

Closes the gap `docs/campaign/CAMPAIGN.md` §1 leaves open — "a guard written to
scan only `runs/` on main would miss ~251 files. Worth pinning down before S-G0
writes the pre-flight check."

> ## Correction, same day
>
> The first version of this page (PR #220) reported **43 absent of 70 cited, 27
> never committed**. Re-measured on the same commit with a corrected pattern the
> numbers are **26 absent of 66**. The over-count was 40 %, and it was mine:
>
> 1. `runs/` matched the **tail of a longer token**, so
>    `spinorbec-runs/fig2_k3zero_v2` — a TSUBAME path, one of them annotated
>    *"(862 MB, off-repo)"* — read as a broken in-repo citation. Those documents
>    had recorded their storage location honestly and I marked them delinquent.
>    4 hits.
> 2. A family citation `runs/eu_k3_*` was resolved as a **literal directory
>    named `eu_k3_`**, which does not exist, while `runs/eu_k3_lhy` sits right
>    there. 3 hits.
>
> Both were visible in the hit list and invisible in the count. The lesson is the
> same one that produced two false alarms in the memory index the same day: **read
> the matches, not the total.**

## The census

Measured on current `main`, which is moving — several sessions add documents that
name runs not yet produced, so the absolute number drifts by a few per day.

| | on `f2352c7f` (as first reported) | corrected |
|---|---:|---:|
| distinct top-level `runs/` names cited | 70 | **66** |
| absent, excluding tutorial placeholders | 43 | **26** |
| never committed at any point in history | 27 | **23** |
| cited by manuscript / validation / research docs | 24 | **21** |

The headline finding survives the correction: **most of the absent directories
were never in git at all.** They existed in a working tree, a document cited
them, and the citation is what remains. That is not staleness — a stale run can
be located, dated and disqualified, which is exactly what
[`stored_results_vintage_audit.md`](../validation/stored_results_vintage_audit.md)
does.

## The part that actually matters: only four back a live claim

The first version implied 24 wounded claims. Reading the citing context rather
than counting the citations gives a very different split.

### Planned, not claimed — 6

Five rows in `manuscript/shared/figures.md` (`paper4_meanfield`,
`sigma_mu_scan_round5`, `species_scan_round6`, `lyapunov_diagnostic_round6`,
`ensemble_traces_round5`) plus `sigma_mu_scan_*` in
`paper4_chaotic_dynamics/main.md`. **Every one of those figure rows carries status
`placeholder`** — 22 of the file's ~33 rows do. They name the data source a figure
is *intended* to use. Nothing is claimed, nothing needs retracting; the run has to
exist by the time the figure does.

*(The first version called this file "the worst single file". It is not. It is a
plan, and reading its status column would have said so.)*

### Recoverable, wrong path — 1

`runs/_loop/{theorist,sim}/turn_115.md`, the derivation provenance for Lemma 1 in
`paper3_universal_theorem`. The loop was retired 2026-06-08 and moved
**deliberately** to `BEC-simulation-archive/loop_record_2026_06_08/`, where
`sim/turn_115.md` and `judge/turn_115.json` are present — verified. Nothing is
lost; the citation points at the pre-move path. Repointing it is a doc fix.

### Index and example rows — 15

`AppendixB_spinorbec_api.md`'s run-directory table (`Cr_eps0.15_*`, `Dy_eps1.39_*`,
`Er_eps0.88_*`, `Eu_eps0.55_*`, `Eu151_GS_64g`, `eu151_klaus_lab_units`,
`lhy_mode_ablation/*` subdirs), and command examples in `guides/` and
`design/scan_group_redesign.md` (`eu151_edh_ext`, `eu151_mz_scan`,
`eu151_phase_pq`, `eu151_phi_omega`, `klaus_eu151_v2_full`, `option_gamma_micro`,
`12174e883326ecac`). These describe a tree the reader does not have. They mislead,
but they assert no result.

### Live claims with a stated result — 4

**This is the regenerate-or-retract list.**

| run | claim | where |
|---|---|---|
| `lhy_mode_ablation` | LHY-insufficiency | `Ch5_TWA_chaotic_dynamics_integrated.md` §5.2 gives the config inline (Eu F=6, a_s=110a_B, N=10⁴, 32³ box=10) and the summary table records the verdict "LHY-insufficient"; indexed from `Ch2_framework.md` |
| `twa_sinatra` | GS-resolution artifact | `Ch5` §5.7 table row, and `figures_update_2026-05-11.md` sources `thesis_FIG-5.6` from it (32³ vs 2×16³) |
| `sprint5_M1_multistart_groundstate` | multistart ground-state audit (B × Ω, Eu F=6, 24³) | `research_notes/m1_groundstate_audit_2026-06-08.md` |
| `ddi_convention_factorial` | the DDI convention factorial | `self_contained_validation_report.md`: "Output: `runs/ddi_convention_factorial/results.jld2`" |

`fortress_compare` is a fifth citation but the document is a **scope** doc naming
an output path for work not yet done, so it is a plan like the figure rows.

For these four there is no config to re-run and no output to compare, so the
decision cannot be made by looking at the run. Each needs a judgement: is the
claim load-bearing enough to regenerate the run from its inline parameters — §5.2
does state them — or should the claim be marked as resting on evidence the
repository does not hold?

## The vintage pointer covers 5 documents, not 7

The audit states that each document citing stored runs "now carries a one-line
pointer here". Of the seven it lists, five do; `manuscript/shared/figures.md` and
`manuscript/klaus_quench_protocol_spec_2026_05_26.md` never got it.

## The gate, and what is wrong with its shape

`test/oracles/test_doc_run_citations_resolve.jl` fails when a document cites a
`runs/` path that does not resolve, as a ratchet: existing breakage is pinned in
`KNOWN_UNRESOLVED`, and what is asserted is that the set does not grow. It is
checked in both directions so the list cannot rot.

**A name list is the wrong shape and should be replaced.** Every session that adds
a document naming a run it has not produced yet must edit a central list in a test
file — churn, and an invitation to append rather than think. The right shape is a
marker at the citation site (`(planned)`, `(off-repo)`, `(archived)`), so the
knowledge lives where the author is and the list shrinks to the genuinely
unexplained. Not done here: it means editing ~30 citation sites in documents
several sessions are actively rewriting, and it would collide.
