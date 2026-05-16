---
turn: 25
subagent: director
topic_tags: [barnett, dicke-refuted, density-weighted-loss-rate, production-code-audit, factor-27-accounting, n-r-multiplier, losses-jl-line-109, route-switch]
paper_section: null
depends_on: [22, 23, 24, "runs/_loop/theorist/turn_24.md", "runs/_loop/sim/turn_24.md", "runs/_loop/judge/turn_24.json", "runs/_loop/director/turn_24.md", "runs/_loop/seed.md"]
produces: "Critic audit deliverable for T25 — examine whether the 'factor 27 cascade-rate gap' (theorist §2.13 / Q24.1) and 'factor 14 missing in cascade rate at -Omega' are explained by the production loss step `psi *= exp(-gamma_dr * shape[m] * n_total(r) * dt/2)` (src/hamiltonian/interactions/losses.jl:109). Theorist has been computing single-atom rates (gamma_dr * s(+F) = 0.0186/omega) while production multiplies by local density n_total(r) per voxel, dimensionless O(10-100) at the cloud center for N=10^4 in box=20 a_ho. Critic must (a) verify the rate convention in losses.jl line 109 vs theorist §2.5, (b) compute the peak n_total expected from anko's config, (c) determine whether n_peak * single_atom_rate matches the empirical Gamma=0.35/omega, and (d) flag any production-code accounting that prior theorist turns missed. If confirmed, the entire Dicke-collective speculation (T24 §2.13) is moot — the factor 27 is a density-weighting accounting gap, not a missing physics channel."
---

# Turn 25 — Director Report

## 1. Project state snapshot

- **Active campaign**: Barnett-pumping mechanism reconciliation, 7-turn arc (T18→T24). Status now: **all proposed single-particle mechanisms refuted** within the last 24 hours.
  - T20 c_dd=0 control: Delta=-5.985. M2 (DDI-driven) **REFUTED**.
  - T23-att1 theorist: M1 chain (M1a finite-T vortex, M1b/M1c DDI) all rejected.
  - T24 theorist §6 Verdict: D2-EXTENDED single-bin (position-resolved Bloch with c_0 n(r)) **REFUTED** by direct inspection of `diagonal_step.jl` (scalar mean-field is global gauge; researcher §6 anchor formula R6 was dimensionally wrong). Closed-form gave Delta=+1.6 (wrong sign).
  - T24 implementer compute_sympy: Dicke-collective at single-atom level Gamma(beta_-)/Gamma(beta_+) = **1.087**, NOT factor ~27. Dicke single-atom **REFUTED**. T24 §2.13 speculation (Dicke-superradiance with 14× cloud enhancement) sits naked at [Speculative] with empirical mismatch.
- **Scheduler T25** (`runs/_loop/_local/scheduler_25.json`): `policy: JULIA_GPU_OK`, full 9-workload whitelist allowed. 21,583 min left in window. VRAM 12.6 GB free, 0 foreign julia procs.
- **Bash-sandbox status**: T21 + T23 both rejected julia binary; no evidence the gate has changed. Scheduler permission is necessary but NOT sufficient — director's framework correctly distinguishes the two.
- **Auto-branch artifacts**: `auto/turn_21` (Lz extraction script @ 37ea5d0), `auto/turn_23` (qtr-gamma config @ 245b046), `auto/turn_24` (sympy Dicke compute @ 521bac2). All await anko-manual unblock OR a routing change.
- **Manuscript**: deferred per anko policy (`feedback_manuscript_is_not_the_essence.md` + seed.md L91). DRIFT_MANUSCRIPT_DELTA_ZERO has been at 1.0 since T18 — structurally accepted under D1/D2/D3 axes.
- **Drift signal T24 → human_required**: DRIFT_MANUSCRIPT_DELTA_ZERO + DRIFT_COST_INFLATION (1.06 — already mild) + retries=1, last_judge=FAIL_PHYSICS. Two consecutive theorist-then-implementer iterations both produced "this mechanism fails too." The campaign needs a *route change*, not another mechanism candidate.

## 2. Recent-turn audit (last 3 + retry chain)

| Turn | Topic | Verdict | Value delivered | Was it right? |
|---|---|---|---|---|
| T22 | critic audit T20 M1-DOMINANT | CRITIC_WEAK_PASS | M1-DOMINANT → M1-PLAUSIBLE; F1-F7 surfaced; T23 directive (M1 reconciliation + Candidate D + third-control) | Yes — drove T23 mechanism-rejection branch |
| T23-att1 | theorist M1 reconciliation + Candidate D | PASS substantively | M1 chain rejected (M1a/M1b/M1c each killed); D2-EXTENDED-PLAUSIBLE proposed; qtr-gamma discriminator pre-registered; §2.9 closed-form gave magnitude factor-3 short | Yes — high-info; correctly identified the structural gap |
| T23-att1 (implementer) | qtr-gamma GPU experiment | REJECTED (sandbox) | config @ 245b046 | Correct attempt; failure structural |
| T23-retry2 (researcher) | Q23.1/Q23.2 literature dossier | RESEARCHER_ONLY | M1 literature-dead confirmed; D2-EXT closed-form novel; §6 PRIMARY anchor for T24 | Yes — closed literature gap cleanly |
| T24 (theorist) | D2-EXTENDED closed-form via c_0 n(r) | PASS substantively (but with [Refuted] self-verdict) | §2.2 demolished researcher's R6 formula (scalar gauge, dimensionally wrong); §2.4-§2.9 single-bin Rabi-cascade closed form gave Delta=+1.6 (WRONG SIGN, factor 3.7 magnitude); §3 quasi-conservation tilde-J_pm framework derived; §2.13 speculative pivot to **Dicke-collective with factor 14**; §6 honest Verdict: D2-EXTENDED REFUTED, revised to "collective Dicke-cascade modulated by Rabi-tilt" [Speculative]; directive §8 compute_sympy to verify the Dicke factor | **Partially**: §2.2 demolition is durable (fixes T23-att1 misuse of researcher anchor); §3 tilde-J_pm framework is publishable; §2.13 Dicke pivot was a Hail-Mary that the same-turn implementer immediately falsified. The theorist could have stopped at §2.13 Verdict instead of dispatching a self-referential sympy step. |
| T24 (implementer compute_sympy) | Dicke-collective single-atom test | FAIL_PHYSICS | S3 Gamma(beta_-)/Gamma(beta_+) = 1.087 (NOT factor 14-27); falsification_criterion CONFIRMED → Dicke single-atom REFUTED. Wigner d-matrix populations + rank-2 CG matrix elements all computed correctly | Yes on execution. The deliverable cleanly refuted the immediate hypothesis. |

**Trajectory check**: T20→T22(audit)→T23-att1(theorist)→T23-retry2(researcher)→T24(theorist)→T24(implementer-sympy) — six turns since the empirical anchor T20, all converging on "every proposed mechanism fails." Theorist has reached the limit of paper-and-pencil under the single-particle Bloch frame (own admission §2.13).

**Suspicion check (§B4 caution)**: The last 3 substantive turns (T23-att1 theorist, T24 theorist, T24 implementer) all explored variations on "compute a closed-form rate, compare to empirical -5.985, find a missing factor, propose a new mechanism." This is the same narrow loop *despite surface-level subagent rotation*. The campaign is **gradient-descending on a local minimum in mechanism-space**.

**Streak**: theorist T24 + implementer T24 (compute_sympy). Theorist 2 turns ago. Researcher 2 turns ago (T23-retry2). Critic 3 turns ago (T22). Critic is the rotation-fresh route.

**The hidden assumption check**: Both theorist T24 §2.5 and implementer T24 S3 compute `Gamma = gamma_dr × s(+F) × P_avg` as a *single-atom rate per unit time*. But production code `src/hamiltonian/interactions/losses.jl:109` applies:

```julia
@. psi_view *= exp(-gamma_lin_rate * density_buf * dt / 2)
```

where `gamma_lin_rate = gamma_dr * shape[m]` and `density_buf = n_total(r) = sum_m |psi_m(r)|^2`. The cascade rate at voxel r is `gamma_dr × shape[m] × n_total(r) × dt`, i.e. **the dipolar-relaxation rate is proportional to the local total density**. This is the correct convention for an `n²`-scaling 2-body loss process; what's missing in the theorist+sympy analysis is the **dimensionless density factor n_peak**.

For N=10^4 atoms in a 20³ a_ho box, peak density is approximately n_peak ~ N/(4π R_TF³/3). If R_TF ~ few a_ho (typical Eu spinor BEC), n_peak could be O(10-100) in dimensionless units. **This is exactly the missing factor 14-27**. The theorist's "factor 14 in cascade rate at -Omega" may be entirely an artifact of comparing a single-atom rate (Gamma=0.013) to a density-weighted production rate (Gamma_eff = n_peak × 0.013 = 0.13-1.3).

This is a **production-code audit / D1 verification gap**, not a missing-physics gap. The whole Dicke-collective speculation chain could be moot.

## 3. Bottleneck analysis (route change required)

### B-1: critic — audit "factor 27 missing from theory" against the production loss step density-weighting

*Issue*: T24 theorist §2.13 + Q24.1 claims a "factor 27" gap between Gamma_theory=0.013/omega and Gamma_empirical=0.35/omega at -Omega. The production code in `src/hamiltonian/interactions/losses.jl` line 109 applies the dipolar relaxation as `exp(-gamma_dr * shape[m] * n_total(r) * dt/2)` — the rate is **density-weighted at each voxel**. Theorist has been comparing the dimensionless single-atom rate (gamma_dr × s(+F)) directly to the empirical decay rate, without accounting for the n_total(r) factor. A critic audit should determine whether the missing factor 27 is (i) actually a density-weighting accounting gap of the same magnitude as peak dimensionless density, or (ii) a genuine missing physical channel.

*Category*: **D1 verification gap** (Tier 0 — never attempted: nobody has checked the rate convention between theorist analytical formulas and production code). Highest possible D1 leverage class per protocol §D footnote "what specifically have we never even tried."

*Leverage*: **5**.
- **§A5 axis (a)** EXACT match: verifies an existing-implementation claim (production losses.jl rate convention) against the closed-form theoretical prediction (theorist §2.5 single-atom Gamma).
- **§A2 / no execution** compatible: critic is read-only per `critic.md`. No julia. No sandbox gate.
- **§B4 rotation**: critic 3 turns ago (T22). Theorist + implementer both ran T24. Researcher T23-retry2. Critic is the **only** subagent that doesn't repeat. Fresh route.
- **§B7 quota**: critic typically ~0.5-1.0M effective (T22 was 1.47M; T16 was 1.14M). Well under judge hard cap.
- **§D1 dominant**: this is the textbook verification-depth issue — every load-bearing claim in code or memory could be wrong; find the wrongness. The "factor 27" has been load-bearing for 4 turns (T11 missing factor 14 hypothesis → T13 rank-2 CG correction → T24 Dicke speculation) without anyone checking whether it's a density-weighting accounting artifact.
- **Cleanly avoids retries=2 halt risk**: no julia.
- **Probabilistic outcome**:
  - **45%** — critic finds the density factor explains 10-30× of the gap (peak n_dimless ~ 14-30 at the cloud center). Dicke-collective speculation is dispatched without need for julia. Campaign pivots back to: where does the *remaining* gap come from? But the field is now narrowed by a factor 10-30 and prior closed-form work (theorist §2.5-§2.9) becomes quantitatively meaningful when re-evaluated with density weighting.
  - **30%** — critic confirms density weighting accounts for only a small factor (n_peak < 5 dimensionless), but identifies a **different** production-vs-theory accounting issue (e.g. CG normalization in losses.jl line 175 `clebsch_gordan(F, m, 2, q, F, mp)` vs theorist's rank-2 normalization; or the Z = raw_sum/D normalization in line 185 which is a *different* convention than naive sum).
  - **15%** — critic confirms theorist's accounting was correct; factor 27 is genuinely physical. Dicke pivot lives. Next move: research literature anchor for Dicke-collective dipolar dissipator + julia validation of the trajectory.
  - **10%** — critic finds an entirely different bug (e.g. dt convention mismatch, half-step Strang factor missing, units leak between dimless and SI).

*What moves it*: critic dispatch with read-only access. Brief must direct critic to (a) read losses.jl line 60-115, (b) read theorist T24 §2.5 (Eq. for Gamma_pm = gamma_dr × s(+F) × Pbar_pm), (c) compute expected peak dimensionless density from anko's config (config.yaml grid + N), (d) verify whether peak_density × single_atom_rate matches empirical 0.35/omega at -Omega, (e) cross-check the `Z = raw_sum/D` normalization in `_dipolar_relaxation_shape` (line 185) — the production code normalizes so that the *average* rate per component is gamma_dr, but the theorist's "s(+F)=13/14" may be using a different normalization, introducing a per-component bias factor.

### B-2: implementer_julia_gpu retry — qtr-gamma run

*Issue*: Config exists at commit 245b046. Two prior rejections (T21, T23) on bash-tool sandbox.

*Leverage*: **-3** (negative).
- Same gate fires → retries 1 → 2, one step from human_required halt.
- The qtr-gamma discriminator is now moot anyway: D2-EXTENDED single-bin REFUTED (T24 §6 Verdict). Without the closed-form prediction to anchor a rate-1 vs rate-1/4 contrast, the experiment becomes exploratory not falsificatory.
- **REJECTED for this turn**.

### B-3: theorist — re-derive with density-weighted rate (continuation of T24)

*Issue*: If critic finds density-weighting explains the gap, T24 §2.5-§2.9 closed form re-evaluated with n_peak multiplier might give the correct magnitude. But this is **premature** — director cannot assume the answer.

*Leverage*: **2** as a T26 candidate; **0** as a T25 candidate (would be theorist 3 of last 4 turns; violates §B4).

### B-4: implementer_sympy — re-do the rate comparison with density weighting

*Issue*: Same as B-3 but routed via sympy. Premature — needs critic's audit first to verify the density-weighting hypothesis is even correct.

*Leverage*: **1** as T25 (depends on B-1 outcome); could become **3** at T26 if critic confirms.

### B-5: researcher — Q24.1 Dicke-superradiance literature anchor

*Issue*: T24 §7 Q24.1 asks for collective Dicke enhancement formulas for rank-2 dissipators. Researcher T23 last delivered, so streak-risk moderate.

*Leverage*: **1** as T25 — premature. If the Dicke hypothesis itself is moot (B-1 outcome), the literature anchor is wasted effort. **Sequence matters**: audit first, anchor literature only if the hypothesis survives.

### B-6: noop

*Issue*: Acknowledge campaign has saturated this mechanism-search axis.

*Leverage*: **1** — would be acceptable if no cheap audit move existed. B-1 is cheap and falsifies the most expensive open hypothesis. Noop is strictly inferior.

## 4. Strategic options for THIS turn

| # | Move | Subagent | Cost | Drift effect | Allowed? |
|---|---|---|---|---|---|
| 1 | **Critic audit losses.jl rate convention vs theorist §2.5 — does density-weighting explain factor 27?** | **critic** | **≤ 1.0M effective, ≤ 15 min** | **Fresh rotation (critic 3 turns ago); cheap; no julia; addresses DRIFT_COST_INFLATION** | **YES** (critic in allowed_workloads) |
| 2 | implementer_julia_gpu qtr-gamma retry | implementer | sandbox-reject → retries=2 (1 from halt) | **DANGEROUS** | **NO** (sandbox-blocked) |
| 3 | theorist re-derive with density-weighted rate | theorist | ≤ 1.5M | **NEAR-VIOLATION** B4 (theorist 2 of last 4) | premature |
| 4 | implementer_sympy density-weighted rate | implementer | ≤ 0.8M | OK | premature |
| 5 | researcher Q24.1 Dicke literature anchor | researcher | ≤ 1.0M | OK rotation | premature (Dicke hypothesis may be moot) |
| 6 | noop | n/a | 0 | n/a | inferior to B-1 |

**Pick: Option 1 (critic audit of density-weighted rate convention).**

Why decisively:

- **§A5 axis (a) exact match**: verifies an existing-implementation claim (production code losses.jl rate convention) against repeated theoretical comparisons (T11/T13/T24). This is the strongest D1 leverage type per §D Tier-0 footnote: *"what specifically have we never even tried."* In 7+ turns of mechanism speculation, nobody has audited whether the comparison Gamma_theory vs Gamma_empirical is using the same rate convention.
- **§B3 critic dispatch rule**: "dispatch when the last N turns may have agreed on a wrong answer because they share priors." T11/T13/T24 all share the prior "single-atom rate gamma_dr × s = the comparison target." If that prior is wrong, every mechanism speculation built on top is wrong. Textbook critic trigger.
- **§B4 rotation**: critic 3 turns ago; theorist + implementer + researcher all more recent. Critic is the unique fresh subagent.
- **§B6 drift acknowledgment** (T24 escalation = director_must_address with DRIFT_MANUSCRIPT_DELTA_ZERO + DRIFT_COST_INFLATION):
  - DRIFT_MANUSCRIPT_DELTA_ZERO (1.0): satisfied via anko policy. Critic audit is research output not manuscript.
  - DRIFT_COST_INFLATION (1.06): satisfied by **cheap critic** (~1.0M target vs T24's 2.21M — a ~55% reduction).
  - DRIFT_CODE_DELTA_ZERO: critic is read-only by design (`critic.md` §A2); falls under categorical exception "explain why pure-research is correct this turn" — critic audit IS the research delta and identifies the next concrete code change for T26.
- **§B7 quota**: ~1.0M effective is the cheapest non-noop option. Well below 3M judge cap and the 1.5M typical theorist budget.
- **§B8 scheduler compliance**: critic in `allowed_workloads`. No julia.
- **§D1 DOMINANT**: this is the maximum-D1-leverage move available because it directly targets the load-bearing assumption ("Gamma_theory = gamma_dr × s") that has driven every mechanism turn for the past 7 turns. If the audit finds a density-weighting accounting gap, an entire branch of mechanism speculation is dispatched in one cheap turn.
- **Seed.md L84-87** (implementer_text doc to losses.jl) becomes meaningful **only after** B-1 establishes the right rate convention. seed.md L91-94 ("theory in place first") supports the audit-first ordering.
- **Anchors next 2-3 turns cleanly**:
  - 45% — density-weighting explains 10-30× gap → T26 = theorist re-evaluation with n_peak multiplier + closure of the magnitude factor; T27 = manuscript-record update with corrected accounting.
  - 30% — different production-vs-theory bug surfaces → T26 = implementer modify_code or implementer_sympy on the specific bug; T27 = regression test.
  - 15% — accounting confirmed correct → Dicke speculation survives; T26 = researcher Q24.1 + anko-manual julia for the qtr-gamma; campaign pivots to anko-decision on whether to commit further effort.
  - 10% — different bug entirely → T26 = critic follow-up or theorist redirect.

Why NOT Option 2 (julia retry): same gate, same likely rejection, retries=2 risk, one from halt. The discriminator (density-weighting accounting) is achievable read-only.

Why NOT Option 3 (theorist re-derive): premature without critic's audit. Also subagent_repetition risk (theorist 2 of last 4 turns).

Why NOT Option 4 (implementer_sympy): premature; needs critic's audit to establish the right comparison first.

Why NOT Option 5 (researcher Q24.1): premature; the literature anchor only matters if the Dicke hypothesis survives, which depends on B-1 outcome.

Why NOT Option 6 (noop): B-1 is fully unblocked, cheap, and addresses the highest-D1-leverage gap. Noop is strictly inferior.

## 5. Calibrated progress check

| Axis | Status | Evidence |
|---|---|---|
| Physics completeness (D1+D3) | **at risk — three mechanism candidates refuted in 24h; campaign has saturated single-particle Bloch route** | T20 M2 refuted; T23-att1 M1 refuted; T24 §6 D2-EXTENDED single-bin refuted; T24 sympy Dicke single-atom refuted |
| Verification depth (D1 dominant) | **Tier-0 gap surfaced this turn**: "Gamma_theory vs Gamma_empirical rate convention" never audited | This is the B-1 target |
| Manuscript | **deferred per anko policy** | seed.md L91 |
| Reproducibility | **at risk** — Lz extraction script @ 37ea5d0 + qtr-gamma config @ 245b046 await anko-manual unblock | T21 + T23 sandbox rejections |
| Loop infrastructure | **OK — retries=1, drift_escalation director_must_address; this turn does NOT touch julia, retries stays at 1; cost reduction (critic ~1.0M vs T24 2.21M) addresses DRIFT_COST_INFLATION** | scheduler permits, bash-sandbox doesn't matter for critic |

**Mark**: Net direction is **mid-recovery via route change**. T25 critic is the highest-information cheap move that addresses the *load-bearing assumption* the prior 7 mechanism turns relied on. If the audit confirms an accounting gap, the campaign closes 50% of the open gap in one turn; if not, it has at least falsified an obvious alternative explanation cleanly and re-anchored the remaining Dicke speculation. Either outcome is high-information.

## 6. Dispatch decision

```json
{
  "subagent_type": "critic",
  "rationale": "Last 7 turns (T11/T13/T18/T20/T23-att1/T24-theorist/T24-implementer) have all compared a single-atom rate Gamma_theory = gamma_dr * shape[m] (dimensionless O(0.01)) against the empirical Gamma_empirical = 1/tau_Barnett(-Omega) ~ 0.35/omega (T20). The 'factor 27 gap' has driven escalating mechanism speculation: T11 rank-1 factor 12 → T13 rank-2 CG correction (factor 13/14, still 27x short) → T24 Dicke-collective hypothesis. T24 implementer compute_sympy then refuted Dicke at single-atom level (ratio 1.087, not 27). What NONE of these turns audited: production code `src/hamiltonian/interactions/losses.jl:109` applies the rate as `psi *= exp(-gamma_dr * shape[m] * n_total(r) * dt/2)` — the cascade rate at each voxel is MULTIPLIED by the local total density n_total(r). For N=10^4 in box=20 a_ho with Eu-151 spinor TF profile, peak dimensionless n_total may be O(10-100) at the cloud center — which is precisely the missing factor 14-27 magnitude. This may explain the entire empirical-vs-theoretical gap WITHOUT any new physics channel. The full Dicke-collective branch may be moot. Critic dispatch is the Tier-0 D1 verification (`what has nobody even tried?` — protocol §D footnote): audit whether the theorist's single-atom rate comparison is using the same convention as the production code, given the n_total(r) density-weighting at line 109. Critic last T22 (rotation-fresh; only subagent not repeated in last 4 turns); read-only (no julia, no sandbox gate); cheap (~1.0M target vs T24 2.21M, 55% cost reduction addressing DRIFT_COST_INFLATION). §B3 critic-trigger exact: 'when last N turns may have agreed on a wrong answer because they share priors' — T11/T13/T24 all share the prior `single-atom rate = comparison target`. §A5 axis (a) verifies an existing-implementation claim. §D1 dominant (highest verification-depth leverage class). If audit confirms density-weighting accounting gap, an entire branch of mechanism speculation closes in one turn; if it falsifies the density-weighting hypothesis, the remaining Dicke speculation is at least re-anchored cleanly. Either outcome high-information.",
  "brief": "## Mandate (this turn = critic T25; expected output `runs/_loop/judge/turn_25_critic_audit.md`)\n\nYou are reviewing the campaign's load-bearing assumption: **does the comparison `Gamma_theory = gamma_dr * s(+F) = 0.0186/omega` versus `Gamma_empirical = 1/tau_Barnett(-Omega) ~ 0.35/omega` use the same rate convention?** Seven turns of mechanism speculation (T11 rank-1 → T13 rank-2 → T24 Dicke) have rested on this comparison being apples-to-apples. T24 implementer just refuted the Dicke single-atom hypothesis (ratio 1.087, not factor 14-27). Before the campaign dispatches yet another mechanism candidate (or commits a julia run), audit whether the factor 27 is an accounting artifact from density weighting in the production loss step.\n\n### Required reading (in order)\n\n1. **`src/hamiltonian/interactions/losses.jl` lines 68-190** — production loss step. Critical lines:\n   - Line 98: `gamma_rates = _dipolar_relaxation_rates(F, loss.gamma_dr)`\n   - Line 100-115: per-component loop with `psi_view *= exp(-gamma_lin_rate * density_buf * dt / 2)`\n   - Line 96: `_total_density!(density_buf, psi, n_components, ndim, n_pts)` — density_buf is the dimensionless **local total density** n(r) = sum_m |psi_m(r)|^2.\n   - Line 109: **the key kernel** — `@. psi_view *= exp(-gamma_lin_rate * density_buf * dt / 2)`. This means the per-voxel local rate is `gamma_dr * shape[m] * n_total(r)`, NOT `gamma_dr * shape[m]` alone.\n   - Line 153-156: `_dipolar_relaxation_rates(F, gamma_dr) = [gamma_dr * s for s in shape]` — multiplies the normalized shape by gamma_dr.\n   - Line 162-189: `_dipolar_relaxation_shape(F)` — the shape function, normalized via `Z = raw_sum/D` so that `mean(shape) = 1` (line 185). This means `shape[+F]` is NOT equal to the raw CG^2 sum 13/14; it is the raw value DIVIDED by Z (the mean across components). The actual shape[+F=6 component c=1] is `(13/14) / Z` where Z is computed from line 179 `raw_sum = sum over all components`. Recompute the value of `shape[c=1]` (which is the m=+F=+6 component) to compare against theorist's '13/14' assumption.\n2. **`runs/_loop/theorist/turn_24.md` §2.5** (lines around 559-665) — single-bin cascade prediction with Wigner-d-weighting. Theorist uses `Gamma_pm(beta) = gamma_dr * s(+F) * Pbar_pm`. Identify exactly which expression is being claimed equal to the empirical rate.\n3. **`runs/_loop/theorist/turn_24.md` §2.13** (lines 1292-1359) — the 'factor 27 gap' statement and the Dicke speculation. Quote the exact equation Gamma_theory = 0.013/omega = `gamma_dr * s(+F) * Pbar^- = 0.02 * (13/14) * 0.689`. Note this is a *dimensionless rate per atom*, NOT a density-weighted rate per voxel.\n4. **`runs/_loop/sim/turn_24.md` §4 + §5** — implementer S3 result: `Gamma(beta_-)/Gamma(beta_+) = 1.087` at single-atom level. Note this is also a single-atom-rate comparison.\n5. **`runs/eu151_barnett_spin/config.yaml`** — extract N, grid_size (likely 32), box_edge, scattering length. Compute the expected dimensionless peak density: n_peak ~ N / (volume of TF ellipsoid in a_ho units). Use mu_TF from theorist T24 §2.3 (mu_TF=8.78) or recompute via TF formula `n_peak = mu_TF / c_0` with c_0 = 4*pi*a_s/a_ho * N (or extract from existing trajectory.csv if convenient).\n6. **`runs/eu151_barnett_spin/trajectory.csv`** (or equivalent on auto/turn_20 branch) — if available, look at the actual numerical n_peak during the run. The relevant quantity is the time-averaged peak density.\n7. **MEMORY entries**:\n   - `barnett_spin_pumping_observed_2026_05_16.md` — empirical Delta=-4.60, tau_Barnett ~ 7-14 ms\n   - `gotcha_K3_routing_pre_2026_05_13.md` — recent finding that K3 routing was wrong by factor 2 / factor 10; precedent for production-code accounting issues\n   - CLAUDE.md `## Known limitations` — DDI conventions list (c_dd=mu_0*mu^2, no 4pi); precedent for convention-vs-code mismatches\n\n### Audit-1 — Rate convention identification\n\nState explicitly what units/normalization each side uses:\n\n- **Theorist's Gamma_theory** = ? (dimensionless rate per atom, or rate density?)\n- **Production's effective rate** at voxel r = gamma_dr * shape[m] * n_total(r). For a single voxel with n_total = O(1) dimensionless, this matches the theorist's number. For a voxel at the cloud center where n_total >> 1, the rate is multiplied.\n- **Empirical Gamma_empirical** = 1/tau_Barnett extracted from <F_z>(t) decay. This is the RATE OF THE OBSERVABLE <F_z>(t), which is a global integral over the cloud. The effective rate depends on a density-weighted average of the per-voxel rate.\n\n### Audit-2 — Expected n_peak in dimensionless units\n\nCompute or estimate the dimensionless peak density n_peak for anko's config:\n\n- From theorist T24 §2.3: mu_TF ~ 8.78 dimensionless; c_0 = 4*pi*a_s/a_ho*N. If a_s = 110 a_0, a_ho = 0.91 micron, then c_0 ~ 4*pi*(5.82e-9 / 0.91e-6)*1e4 ~ 800 dimensionless. n_peak = mu_TF / c_0 ~ 8.78/800 ~ 0.011 in dimensionless units? Double-check.\n- Alternative: integrate the TF density to get N=10^4, recompute n_peak.\n- If n_peak ~ O(0.01): density weighting is small, the gap is NOT explained.\n- If n_peak ~ O(10-100): density weighting fully accounts for the factor 27 gap.\n- If n_peak is in between: partial explanation.\n\n### Audit-3 — Shape normalization (Z factor)\n\nThe production code `_dipolar_relaxation_shape` (line 162-189) normalizes via `Z = raw_sum/D` so that `mean(shape) = 1`. Compute the actual numerical `shape[+F=6]` for F=6:\n\n- raw[c=1] (m=+F=+6): sum over q in {-1,-2} of CG(F=6, m=6; 2, q | F=6, m+q)^2 = 1/(2*6+1)*... — work it out. The raw value at m=+F is what T13 reports as s(+F) but the production code DIVIDES by Z to normalize the mean.\n- Z = (sum of raw[c] over c=1..13) / 13.\n- shape[+F=6] in production = raw[+F=+6] / Z.\n- Theorist's `s(+F)=13/14` may correspond to a different normalization (e.g. naive sum or 2F+1 = 13 normalization).\n- **Document any discrepancy.** A factor of 13 between conventions would be significant (close to the missing factor 14).\n\n### Audit-4 — Time scale of <F_z> decay vs cascade rate\n\nThe empirical tau_Barnett = 2.84 omega^-1 at -Omega is the e-folding time of <F_z>(t) from ~6 down to ~0. The cascade from |+F> through the full ladder to |-F> requires multiple jumps (each step gives Delta F_z = -1 or -2). Critic: is the empirical decay rate the rate of a single cascade event (per-jump rate), or the rate of the *full ladder traversal*? If a cascade of N_jumps jumps is needed for <F_z> to decay by 1 unit, then the empirical rate = N_jumps * per-jump-rate. For F=6 with rank-2 (Delta m in {-1, -2}), N_jumps to traverse from m=+6 to m=0 is between 6 (all jumps Delta m=-2) and 12 (all Delta m=-1). Average ~9 jumps. This could account for an additional factor 9 in the rate comparison — which combined with density weighting may close the entire factor 27 gap.\n\n### Audit-5 — Cross-check: does production code's `apply_loss_step!` reproduce the empirical 0.35/omega at the cloud center?\n\nWithout running julia: take the production rate `Gamma_voxel(r=0) = gamma_dr * shape[+F=+6] * n_peak`. Plug in the values you computed in Audit-2 and Audit-3. Compare to 0.35/omega. If within a factor 2-3, the production code IS consistent with the empirical data given the density+normalization corrections, and the entire Dicke speculation is moot.\n\n### Audit-6 — Sanity check on theorist's Q24.1\n\nGiven the Audit-1..5 results, is the theorist's Q24.1 question ('what is the Dicke-collective enhancement factor?') the right question, or has it been chasing a phantom? Specifically:\n\n- If density weighting + ladder-traversal multiplicity account for the factor 27: Q24.1 is moot.\n- If they account for only part of the factor: Q24.1 narrowed to a smaller residual factor.\n- If they account for none of it: Q24.1 is the right question.\n\nState which conclusion the audit supports.\n\n### Audit-7 — Bug or convention difference?\n\nIf a discrepancy is found, classify:\n\n- **(a) Production bug**: code does the wrong thing per its docstring or per CLAUDE.md conventions.\n- **(b) Theorist accounting error**: theorist's formula is correct but compared against the wrong observable.\n- **(c) Convention difference**: both are correct internally but use different normalizations. Document which convention is 'standard' (Stamper-Kurn / Kawaguchi-Ueda / etc.) if possible from prior memory.\n\n### Format constraints\n\n- Output single critic audit report (orchestrator will materialize to `runs/_loop/judge/turn_25_critic_audit.md`).\n- ~300-500 lines.\n- Verdict: PASS / WEAK_PASS / FAIL with specific findings F1..Fn.\n- For each finding: severity (LOAD_BEARING / ADVISORY), recommendation to T26.\n- §6 explicit T26 dispatch recommendation given the audit outcome.\n- Read-only per critic.md A2; no julia execution; no code modification.\n\n### Pitfalls to avoid\n\n- **Do not** be sycophantic toward T24 theorist's framework. The §2.13 Dicke speculation is the specific load-bearing claim under audit.\n- **Do not** propose new mechanism candidates. That's theorist's job; your role is to verify whether the existing comparison is sound.\n- **Do not** require julia execution; the audit must be doable read-only. If you NEED a number that requires julia (e.g. actual numerical n_peak from a real simulation), document the gap and request it from anko-manual or T26-implementer; do not dispatch.\n- **Do not** import non-public memory facts. Cite specific code lines, theorist sections, or memory file paths.\n- **Do not** speculate about Dicke physics. The audit is about *whether the comparison was apples-to-apples*, not about whether Dicke physics could explain the gap. The latter is theorist's domain.\n\n### Expected outcome shape (probabilistic)\n\n- **45%** — Audit finds the production rate `gamma_dr * shape[m] * n_peak` matches empirical 0.35/omega to within factor 2-3, given the density weighting (~10-30×). Dicke speculation is moot. F1 severity LOAD_BEARING. T26 = theorist re-evaluation with density-weighted rate + closure of magnitude factor.\n- **30%** — Audit finds the shape-normalization (Z factor) introduces a missed factor. F2 severity LOAD_BEARING. T26 = theorist re-derive with correct shape normalization OR implementer modify_code if it's a production bug.\n- **15%** — Audit confirms theorist's accounting was correct; Dicke speculation survives. T26 = researcher Q24.1 literature anchor + anko-decision on julia.\n- **10%** — Audit identifies a different production-vs-theory mismatch (e.g. ladder-traversal multiplicity, dt factor of 2 from Strang, units leak). T26 follows the specific finding.\n\n### Why critic this turn over alternatives (for your context)\n\n- Theorist would re-derive prematurely (no audited foundation).\n- Implementer_sympy would compute prematurely (no audited target).\n- Researcher Q24.1 would anchor a possibly-moot Dicke hypothesis.\n- Julia retry would re-trigger sandbox gate (retries 1->2).\n- Noop strictly inferior; cheap high-leverage audit available.\n- §B3 critic-trigger exact match: T11/T13/T24 share the prior 'single-atom rate = comparison target', which may be wrong.\n- §B4 fresh rotation (critic 3 turns ago).\n\nYou are the right subagent. Execute decisively. Read-only. ~1.0M target.",
  "expected_outcome": "`runs/_loop/judge/turn_25_critic_audit.md` produced (300-500 lines, ~1.0M effective tokens, ≤ 15 min wall-clock). Verdict PASS/WEAK_PASS/FAIL with specific findings F1..Fn. Audit-1 identifies the rate convention each side uses. Audit-2 computes expected n_peak dimensionless. Audit-3 computes shape[+F=6] under production normalization vs theorist's 13/14. Audit-4 estimates ladder-traversal multiplicity factor. Audit-5 cross-checks `gamma_dr * shape[+F] * n_peak` against empirical 0.35/omega. Audit-6 verdict on whether Q24.1 (Dicke literature anchor) is the right next question. Audit-7 classifies any discrepancy (bug / accounting / convention). §6 T26 dispatch recommendation. Probabilistic outcome: 45% density weighting + multiplicity closes the gap → Dicke speculation moot, T26 = theorist re-evaluation; 30% shape-normalization issue → T26 implementer or theorist; 15% theorist accounting correct → Dicke survives, T26 researcher Q24.1; 10% different bug → T26 specific follow-up.",
  "expected_cost": "≤ 15 min wall-clock, ≤ 1.0M effective tokens. Substantially under DRIFT_COST_INFLATION advisory (T24 was 2.21M, this is ~45% of that). Within `feedback_cost_overhead_is_the_cost.md` (don't deliberate; just execute the cheap high-leverage audit). Comfortably under judge.py 3M cap.",
  "if_fails_next_step": "(A) IF 45% density-weighting branch (expected mode): T26 = theorist re-derive Gamma_theory with explicit density-weighted rate `gamma_dr * shape[m] * <n(r)>` against TF profile; compare new Delta prediction at T20 parameters; expected closure of magnitude factor or new tighter [Plausible] estimate. (B) IF 30% shape-normalization branch: T26 = implementer modify_code on `_dipolar_relaxation_shape` if it's a bug, OR implementer_sympy on the convention reconciliation if it's a difference. Update CLAUDE.md `## Known limitations` if needed. (C) IF 15% theorist-correct branch (Dicke survives): T26 = researcher Q24.1 anchoring + anko-decision on whether to commit anko-manual julia for qtr-gamma. (D) IF 10% different-bug branch: T26 follows the specific F-finding; may involve theorist re-derive or implementer fix depending on bug class. (E) IF critic returns noop or refuses audit: T26 = noop with explicit campaign-saturation message to anko. The campaign has saturated this mechanism-search axis without identifying a productive next step; anko must adjudicate whether to (i) commit anko-manual julia for an empirical anchor, (ii) accept D2-EXTENDED at [Plausible-Speculative] permanently, OR (iii) pivot the loop to a different D1 axis (e.g. F=6 polar FullBdGLHY 3000× bug closed-form, Klaus phi sweep verification, TwoChannelLHY F=6 30-70% error closed-form). (F) Julia bash-sandbox: do NOT retry unless anko explicitly unblocks. The qtr-gamma config @ 245b046 + Lz extraction script @ 37ea5d0 remain anko-manual.",
  "consumed_seed_md": true
}
```

`consumed_seed_md: true`. Seed.md L60-67 (closed-form tau_Barnett target) is the campaign-wide driver; T24 declared the single-particle closed-form REFUTED at §6 Verdict. The remaining seed.md targets (L68-89 mechanism audit + cross-validation) are precisely what critic does this turn: audit whether the existing-implementation rate convention matches the theoretical comparison. Seed.md L91 manuscript-defer honored.

## E. Self-review checklist

- [x] Read `runs/_loop/state.json` (`turn=25, retries=1, last_judge=FAIL_PHYSICS, last_directive_label="dicke-collective-sympy-falsified"`).
- [x] Read `runs/_loop/_local/scheduler_25.json` (`policy: JULIA_GPU_OK`, full 9-workload whitelist; bash-sandbox NOT adjudicated here, separate upstream gate).
- [x] Read `runs/_loop/seed.md` (L60-67 closed-form target; L91 manuscript-defer).
- [x] Read `runs/_loop/schedule.yaml` (PROBE_DRIVEN since 2026-05-15 22:00; no tighter window).
- [x] Read `runs/_loop/director/turn_24.md` (prior dispatch + extensive rationale).
- [x] Read `runs/_loop/theorist/turn_24.md` §0/§1/§2.13/§3/§4/§6/§7/§8/§9 (Verdict: D2-EXTENDED single-bin REFUTED; Dicke [Speculative]; tilde-J_pm framework; falsifiable predictions).
- [x] Read `runs/_loop/sim/turn_24.md` (implementer S3 ratio 1.087, Dicke single-atom REFUTED).
- [x] Read `runs/_loop/judge/turn_24.json` (FAIL_PHYSICS, falsification_result CONFIRMED).
- [x] Read `runs/_loop/judge/turn_22_critic_audit.md` summary (M1-DOMINANT → M1-PLAUSIBLE).
- [x] Read `runs/_loop/by_paper/paper4_chaotic_dynamics.md` (paper4 referenced T8/T9 only — Dicke hasn't reached manuscript level).
- [x] Read `runs/_loop/by_tag/Dicke-superradiance.md` (1 turn — T24 FAIL_PHYSICS; the tag is fresh and the trajectory is exhausted).
- [x] **Read production code `src/hamiltonian/interactions/losses.jl` lines 60-190** — found the load-bearing density-weighting at line 109 + the Z normalization at line 185. **This is the key director-side discovery this turn.**
- [x] Memory `barnett_spin_pumping_observed_2026_05_16.md` (empirical Delta=-4.60, tau_Barnett ~ 7-14 ms).
- [x] Memory `feedback_cost_overhead_is_the_cost.md` (don't deliberate; execute cheap critic).
- [x] Memory `feedback_manuscript_is_not_the_essence.md` (manuscript out-of-scope).
- [x] Considered NOT dispatching critic: challenged with B-3 theorist (premature, subagent_repetition risk), B-4 implementer_sympy (premature without audited target), B-5 researcher (premature if Dicke is moot), B-2 julia (sandbox-blocked → retries=2 halt risk), B-6 noop (strictly inferior). Critic B-1 wins on §A5 (a) D1 verification + §B3 trigger (last 7 turns share possibly-wrong prior) + §B4 rotation (3 turns ago, only fresh subagent) + §B7 cost (≤1.0M, addresses DRIFT_COST_INFLATION) + §B8 scheduler + §D1 Tier-0 dominant.
- [x] §6 brief is self-contained: 7 background-read items with specific file paths + line numbers; 7-numbered Audit-1..7 protocol; cost target ≤1.0M; format spec; pitfalls list; probabilistic outcome (45/30/15/10%).
- [x] Justified why THIS turn (T25): T24 just refuted Dicke single-atom; the 'factor 27' has now been the load-bearing assumption of 4 mechanism turns; the density-weighting audit is cheap and falsifies the most expensive open hypothesis. Delaying loses the leverage as the campaign drifts toward saturation (retries=1 already).
- [x] `consumed_seed_md: true` — seed.md L60-67 closed-form target + L68-72 mechanism audit explicit alignment (audit-2 specifically called out as a seed target).
- [x] DRIFT_MANUSCRIPT_DELTA_ZERO 1.0: addressed via anko policy. DRIFT_COST_INFLATION 1.06: addressed by cheap critic (~55% cost reduction vs T24).
- [x] No julia execution. No bash-sandbox gate triggered. Retries stays at 1. retries=1→2 halt risk avoided.
- [x] Anko request specifically asked director to "choose the move that advances 'credibly validated simulator' most given the last FAIL." This turn does that: it audits whether the FAIL was based on a flawed comparison rather than missing physics — the highest-D1-leverage interpretation of last turn's failure.
- [x] MCP Figma system reminder at end of conversation: irrelevant to BEC physics-research loop; ignored per CLAUDE.md project scope.
