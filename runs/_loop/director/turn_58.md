---
turn: 58
subagent: director
investigation_id: klaus-magnetostir-bch-leak-2026-05-13
stage_advancing_from: Execute (T57 PASS; analyze_existing fused Execute+Analyze produced overall CONFIRM verdict — primary max_norm_drift_global=3.33e-9 with 1.033x phi-growth, secondary max_sigma_deviation=1.95)
stage_advancing_to: Update
topic_tags: [klaus-magnetostir, option-gamma, bch-leak, critic-update, independent-eval, verify-claim-update, tier2-7-to-tier3, reflexion-pattern, lats-reflect-backprop]
paper_section: null
depends_on: [10, 55, 56, 57, "runs/_loop/director/turn_57.md", "runs/_loop/theorist/turn_56.md", "runs/_loop/sim/turn_57.md", "runs/_loop/judge/turn_57.json", "runs/_loop/research/turn_55.md", "runs/_loop/state.json", "runs/_loop/seed.md", "runs/_loop/_local/scheduler_58.json", "src/rotating_basis/propagators.jl", "memory:option_gamma_rotating_basis"]
produces: "critic report at runs/_loop/critic/turn_58.md with independent re-evaluation of T57 verdict; verdict in {CORROBORATE, REFUTE, NEEDS-FURTHER-DISCRIMINATION, NEEDS-DOCUMENT-NOTE}; tier recommendation; specific named confounders examined (Y4 floor estimate validity, steady-window selection, chi-square sigma_baseline choice, m+F drop sign-convention, mixed-frame Jz proxy adequacy, larmor_phase metadata interpretation); recommended next stage (Document → close at 3.0 / re-Hypothesize / fresh cpu_heavy fallback)"
---

# Turn 58 — Director Report

## 1. Investigation state snapshot

- **Active investigation (continuing)**: `klaus-magnetostir-bch-leak-2026-05-13` (priority 3, flow_template `verify-claim`, tier_current 2 → target 3). T57 closed Execute+Analyze cleanly with overall CONFIRM.
- **Note on state.json bookkeeping**: state.json `active_investigation_id` still shows `yan-li-saito-2026-reproduction` (stale from T49 Document closure). T55→T56→T57 worked klaus-bch-leak; the orchestrator's state-update at end-of-turn will refresh this field. Bookkeeping issue, not investigation-routing issue.
- **Stage transition**: Execute → **Update** per §F1. Update stage role = critic (mandatory; independent context). Rationale below in §3.
- **Tier**: 2.7 (post T57 PASS+CONFIRM) → target 3. T58 Update lands tier at 3.0 if critic CORROBORATEs, 1.5 if REFUTEs, or stays at 2.7 if NEEDS-FURTHER-DISCRIMINATION.
- **Falsifier this turn evaluated**: `klaus-bch-leak-option-gamma-p2-plus-pop-discriminator` (T56-defined, T57-measured). Critic re-examines whether the CONFIRM verdict is justified, or whether T56's CONFIRM/REFUTE band derivation contains hidden confounders.
- **Other in-flight investigations summary**:
  - `barnett-mechanism-2026-05-16` (priority 1): CLOSED tier 3.0. No action.
  - `yan-li-saito-2026-reproduction` (priority 1): dormant tier 0.4. R4 analytical revival not anko-prioritized this session.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3): **THIS TURN** — Execute → Update.
  - `meta-internal-b-unification-2026-05-18` (priority 5): CLOSED tier 1.
  - `audit-class-scan-2026-05-18-T50` (priority 20): CLOSED. Next due ~T62 per ~10-turn cadence (current gap = 58-50 = 8).
  - `meta-stage-routing-2026-05-18` (priority 25): held at Observe per T54 confounder_advisory; checkpoint T58. Post-T53 streak (T54 PASS, T55 RESEARCHER_ONLY, T56 NOOP-theorist, T57 PASS) is 0 FAIL/INCONCLUSIVE in 4 turns — meta-stage-routing hypothesis is moving toward REFUTED-BY-CONFOUNDER. **NOT advancing this turn**; let one more clean cycle pass and route to terminal close at T59-T60 if pattern holds.
  - `meta-critic-placement-2026-05-17` (priority 50): defer.
  - `judge-in-operator-bug-2026-05-18` (priority 2): CLOSED.
  - `fullbdg-f6-polar-3000x` (priority 99): contained, skip.
- **Scheduler** (`scheduler_58.json`): policy=JULIA_GPU_OK, allowed_workloads includes `critic`. Window 1,181,581s left (~13.7 days). VRAM 12,967 MB free, foreign_julia=0, RAM 25.07 GB avail, GPU util 1%. Critic is text-only — fits trivially.
- **Last judge verdict**: T57 = PASS (18/18 criteria pass, no triggered failure modes, overall_verdict CONFIRM). Routing per `investigation_update.if_success_advance_to_stage` = "Analyze (T58 sim... T59 critic Update...)". However, since T57 fused Execute+Analyze (analyze_existing dispatch class produced the full Analyze interpretation in sim/turn_57.md §3 + §5), the **§F1 next stage is Update** directly. The judge JSON's `if_success_advance_to_stage` text mentioning T58=Analyze and T59=critic was a director-T57 prediction that didn't account for the Execute+Analyze fusion; the flow-template-correct interpretation is Update at T58.
- **Drift signals (T57 footer)**: not surfaced in scheduler_58.json (T57 PASS at trivial cost — 2.87s wall, 14.3M tokens, well within the 6M per-turn cap relative to recent T55 28M overrun). No advisory escalation pending. AUDIT_DUE pattern (gap=8) is below the ~10-turn cadence trigger.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T55 | Research | RESEARCHER_ONLY | Researcher inventoried 8 JLD2 files, verified schema (`dynamics/norms`, `Fz`, `Lz`, `per_m_history`, `times`, `integrator_meta/larmor_phase_per_step`, `integrator_meta/dt_used`); ~740 snapshots/phi, ~629 steady; cited Hairer-Lubich-Wanner §III.4 + Bao-Cai 2018; raised 4 open questions (P2 threshold, tilde vs lab Fz, BCH-vs-Y4 discriminator, larmor_phase metadata). |
| T56 | Hypothesize | NOOP (text-only) | Theorist verified line-37 memory claim against current `src/rotating_basis/propagators.jl:160-231` (eigen-exact single matrix exp; no internal Strang). Derived Y4 truncation floor 3.14e-10 from C_Y4≈0.0247. Resolved T55 4 open questions. Produced formal falsifier `klaus-bch-leak-option-gamma-p2-plus-pop-discriminator` with CONFIRM(<1e-8 norm) / REFUTE(>1e-5 norm OR >5σ chi-sq) / INCONCLUSIVE bands. T57 Julia pseudocode (~80 LOC, JLD2/Statistics/Printf/Polynomials). |
| T57 | Execute (+ Analyze fused) | PASS, overall verdict CONFIRM | Implementer wrote `scripts/diagnostic/klaus_bch_leak_verification.jl` (337 LOC, used CodecZstd pre-load to dodge phi=1.0 world-age error). 8/8 phi points complete data. PRIMARY: max_norm_drift_global=3.33e-9 (<1e-8 CONFIRM threshold), growth ratio phi=18/phi=1=1.033 (<5x). SECONDARY: drops uniformly negative ~40-1250ppb, max_sigma_deviation=1.95 (<5σ). larmor_phase=160.2 exactly invariant across 8 phi. Jz_proxy_mean≈6.0-6.1, Jz_proxy_drift 1.4e-2 to 3.3e-1. Wall 2.87s. Both observables CONFIRM. judge PASS 18/18. |

## 3. Flow template recall

- **Template**: `verify-claim` (§F1): Research → Hypothesize → Design → Execute → Analyze → **Update** → Document → closed.
- **Why Update now (not Document)**:
  - §F1 makes Update **mandatory and independent-context** ("Update: critic (mandatory; independent context); independent eval against the data"). Even when Execute+Analyze produces unambiguous CONFIRM, the critic re-evaluation is the tier-3 gate. Director.md §A "judge mechanical, failures pre-routed" + §G LATS reflect-backprop pattern: the Update stage IS the Reflect+Backprop step.
  - Per `feedback_manuscript_is_not_the_essence` (anko 2026-05-15): verification depth = tier 3. The verify-claim flow defines tier 3 as `published-reference benchmarked` OR (operationally) `cross-implementation verified + critic-CORROBORATE`. We're on the cross-implementation path; critic CORROBORATE closes it.
  - The barnett-mechanism-2026-05-16 precedent (T28): post-Analyze, critic Heisenberg-Slichter independent re-derivation → CORROBORATE → tier 2.5 → 3.0. Same pattern applies here. That investigation is the project's only Tier-3, and the critic stage was the load-bearing tier-bump turn.
  - Skipping critic → straight to Document would land tier at 2.7 (Execute+Analyze done) but NOT 3.0 (Update missing) — would defeat the entire purpose of the verify-claim flow's structural commitment to independent re-eval before tier-3 promotion.
- **Why NOT Document this turn**:
  - Per §F1 stage ordering: Document AFTER Update.
  - Per `feedback_manuscript_is_not_the_essence`: Document is the cheap-tail step (memory entry, docstring advisory if applicable). Closing the investigation without the critic eval would set a bad precedent for the next verify-claim cycle.
- **Why NOT switching investigations**:
  - klaus-bch-leak is the only physics investigation in active stages (Execute completed; Update pending).
  - barnett (closed), yan-li-saito (dormant tier 0.4), audit-class-scan-T50 (closed), judge-bug (closed), meta-internal-b (closed), meta-stage-routing (held to T59-60 reassess), meta-critic-placement (priority 50 defer), fullbdg-f6 (contained), R4 yan-li-saito (low-priority revival path, not anko-prioritized).
  - This investigation is on tier-bump trajectory; lock in the gain.
- **Role for Update**: `critic` (independent context, text-only, no julia execution). Single dispatch.

## 4. Research grounding (§A6)

External / prior references this dispatch grounds against:

1. **`runs/_loop/critic/turn_28.md`** — the barnett-mechanism-2026-05-16 Update-stage critic precedent. The Heisenberg-Slichter independent re-derivation lands on a CORROBORATE verdict + flags one residual misattribution (Bloch-Siegert) as errata. This is the template for T58 critic — independent re-derivation path, named confounders, explicit verdict tokens, errata flagging.
2. **`runs/_loop/theorist/turn_56.md` §2.1** — the Y4 truncation floor derivation (3.14e-10 from `dt^4·T = (1e-3)^4·314.16`, with C_Y4_spinor ∈ [1, 100] uncertainty band). T57 observed values 2-4e-9 fall in the C_Y4_spinor≈10 regime; critic should independently re-check this derivation or supply an alternative bound.
3. **`runs/_loop/theorist/turn_56.md` §2.3** — the chi-square BCH-residual signature derivation: expected residual at phi=18 is ~1.6e-5 in m+F fraction drop (with absorption factor `(phi_dot/p)^2 ~3e-8`). T57 observed drops uniformly ~40-1250 ppb (= 4e-8 to 1.25e-6) with no phi-quadratic structure. Critic should verify: are the observed magnitudes consistent with `0` BCH residual (i.e., zero plus Y4 truncation noise), or do they constitute a low-amplitude BCH signature that the chi-square test missed?
4. **`runs/_loop/sim/turn_57.md` §5** — implementer's own honest discrepancy log: m+F "drops" are NEGATIVE (fraction INCREASES); CodecZstd world-age issue for phi=1.0 (data integrity not affected). Critic must engage with these flags explicitly.
5. **`runs/_loop/judge/turn_57.json`** — judge contract_evaluation table (18/18 PASS). Critic operates above this layer — even with judge PASS, scientific verdict may need refinement.
6. **`runs/_loop/sim/turn_57_results.jld2`** — full per-phi results for re-analysis if critic wants to compute alternate statistics (e.g., quadratic-in-phi fit instead of linear, alternate sigma_baseline using full-phi residual std).
7. **Memory `option_gamma_rotating_basis.md` line 36-37** — the load-bearing claim under verification. Critic confirms the verification target is correctly framed.
8. **Anthropic context engineering "Isolate" pattern (Director.md §G)** — critic dispatched with focused brief reading T57 metrics + T56 derivations + line-37 claim, NOT full state. Fresh context for independent eval.
9. **Reflexion (Shinn et al. 2023, arXiv:2303.11366)** — the reflect-and-update-task-trajectory pattern. The critic stage is the project's institutionalized Reflexion step.
10. **LATS (Zhou et al. ICML 2024, arXiv:2310.04406) §3.3 Reflect+Backprop** — independent eval feeding tier-update. Director.md §G calls this out as the matching pattern.
11. **AI Scientist v2 (Sakana 2024)** — Experiment Manager Agent's verification-before-claim discipline. The "evidence ≠ conclusion" gap that Update closes.
12. **Hairer-Lubich-Wanner 2006 §III.4** — BCH convergence radius ln 2 ≈ 0.693. T56 used this; critic should sanity-check the radius application (the rotating-basis BCH parameter 0.108 at phi=18 is well within; T56 §7.1 cross-checked at 0.062 via the off-diagonal-only norm).
13. **Yoshida 1990 *Phys. Lett. A* 150, 262** — original Y4 composition + truncation constant. T56 cited C_Y4≈0.0247.
14. **anko 2026-05-15 "Manuscript NOT the essence"** — D1 verification depth: this is the cross-implementation tier-3 promotion candidate (after barnett-mechanism). Critic eval is the gate.
15. **anko 2026-05-18 "Fix the class not the instance"** — critic considers whether the verify-claim flow itself produced a valid tier-3 verdict, or whether the chi-square test's specific design (linear-in-phi fit + low-phi-4 sigma_baseline) hides class-level confounders that should be exposed before tier promotion.
16. **Grounded autonomous research (arXiv:2604.12198 per Director.md §G)** — "gold standard for Update stage: REFUTED is a science success when documented". Critic must be willing to land REFUTE if the data demand it, not pre-commit to CORROBORATE.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1** (verify existing physics). The Option γ subsystem's load-bearing line-37 claim is on the cross-implementation Tier-3 path. T57 supplied the raw evidence; T58 critic Update is the independent eval that closes the loop. NOT D2 (optimize) — no performance work. NOT D3 (build new theory) — theory was T10 + T56; this is the verification arc.
- **Tier ladder position**: tier_current=2.7 (Execute+Analyze done per T57 update); tier_target=3. T58 Update determines tier movement:
  - critic CORROBORATE → tier 3.0 (project's 2nd Tier-3 claim after barnett-mechanism). T59 Document → close at 3.0.
  - critic REFUTE → tier 1.5 (hypothesis revisited; re-Hypothesize stage if anko prioritizes).
  - critic NEEDS-FURTHER-DISCRIMINATION → tier stays 2.7; T59 ALL be Execute again at finer phi grid OR cpu_heavy lab-frame snapshot post-rotation per T56 §2.2 fallback.
  - critic NEEDS-DOCUMENT-NOTE → tier 3.0 with a documented caveat/erratum (precedent: T28 Bloch-Siegert misattribution flag while still landing CORROBORATE).
- **Manuscript NOT in scope** (per `feedback_manuscript_is_not_the_essence`).
- **Cost frame**: critic dispatch baseline ~1.3-1.8M effective per Director.md §H worked example + recent critic turns (T28: 1.33M, T45: 1.51M, T47: 1.72M, T52: 1.39M). Text-only, no julia. Wall 5-12 min typical.
- **Drift signal forecast post-T58**: code_delta_zero=1 (critic produces text-only deliverable), manuscript_delta_zero=1, verdict CRITIC_PASS expected. Drift score should improve (no cost_inflation; topic_repetition modest since this is the 4th turn on klaus-bch-leak in a row but each turn is a different stage).

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "klaus-magnetostir-bch-leak-2026-05-13",
  "stage_advancing_to": "Update",
  "subagent_type": "critic",
  "rationale": "T57 Execute+Analyze PASS with overall verdict CONFIRM (primary max_norm_drift_global=3.33e-9 with phi-growth ratio 1.033, secondary max_sigma_deviation=1.95). Per §F1 verify-claim flow, Update stage is MANDATORY independent-context critic re-evaluation before tier-3 promotion. Precedent: barnett-mechanism-2026-05-16 T28 critic Heisenberg-Slichter re-derivation produced CORROBORATE + flagged a Bloch-Siegert misattribution errata, landing the project's first Tier-3 at T29. T58 critic re-examines: (a) the Y4 truncation floor derivation (T56 §2.1) — is 3e-10 with C_Y4_spinor uncertainty [1,100] a valid bound, or does it explain away the observed 2-4e-9? (b) the chi-square SECONDARY observable's sigma_baseline choice (low-phi-4 residual std) — is this self-justifying / circular when low-phi residuals are expected to BE the noise floor? (c) the m+F drop sign-convention (NEGATIVE drops mean fraction INCREASES — what is the coherent physics that produces this? is it consistent with non-adiabatic Larmor lag, or is there a sign error somewhere?) (d) the mixed-frame Jz_proxy adequacy at theta=0.611 rad — T56 §2.2 averaging argument validity; (e) whether the larmor_phase=160.2 invariance is a sanity check or a tautology (since p,F,dt do not vary in the scan). Critic emits verdict in {CORROBORATE, REFUTE, NEEDS-FURTHER-DISCRIMINATION, NEEDS-DOCUMENT-NOTE} with tier recommendation and named errata if any.",
  "brief": "## ROLE\n\nYou are critic. T58 §F1 Update stage of klaus-magnetostir-bch-leak-2026-05-13 (verify-claim flow). Independent context re-eval of T57 PASS+CONFIRM verdict. Your output is the Tier-3-promotion gate decision.\n\n## REQUIRED READING (READ FIRST, BEFORE FORMING VERDICT)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_57.md` end-to-end — the measurement report.\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_57.json` — the 18/18 PASS contract evaluation (this is the operational gate; your job is the SCIENTIFIC gate above it).\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_56.md` §2.1, §2.3, §3, §8 — the hypothesis spec, Y4 floor derivation, chi-square discriminator derivation, calibrated claims.\n4. `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_55.md` §1-§5 — the data inventory + open questions that T56 resolved.\n5. `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_10.md` §2.4, §2.5, §2.7, §2.9, §3.5 — the original P1/P2/P3 BCH derivation that T56 refined.\n6. `/home/suzume/workspace/BEC-simulation/runs/_loop/critic/turn_28.md` end-to-end — the barnett-mechanism critic Update precedent. STUDY the structure (§1-§3 independent re-derivation, §4 verdict, §5 errata flags).\n7. `/home/suzume/workspace/BEC-simulation/src/rotating_basis/propagators.jl` lines 146-231 — the production code under verification. Verify T56 §1.2 code-read is current.\n8. The line-37 claim in memory `option_gamma_rotating_basis.md` (see lines 36-37 of the memory file: \"Diagonal Zeeman ... must be combined into ONE D×D matrix exponential per local spin step. Strang-splitting them produces O(p·F·|Â|·dt²) errors that scale with the LARGE Larmor — exactly what Option γ should eliminate. The eigen-exact local spin step is the load-bearing piece of the implementation.\").\n\n## OPTIONAL READING (use if confounders raise specific questions)\n\n- `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_57_results.jld2` — the per-phi raw results dict. Use Julia `JLD2.jldopen` to load if you want to recompute statistics with alternate fits.\n- `/home/suzume/workspace/BEC-simulation/scripts/diagnostic/klaus_bch_leak_verification.jl` — the analysis script (337 LOC).\n- `/home/suzume/workspace/BEC-simulation/runs/eu151_klaus_phi_phys/config.yaml` — config (dt=0.001, T_steady=314.16, theta=0.611, p=26700, gauge_fix=false).\n- `/home/suzume/workspace/BEC-simulation/docs/design/option_gamma_rotating_basis.md` — the design doc (per Glob result this turn).\n\n## YOUR JOB\n\nProduce `/home/suzume/workspace/BEC-simulation/runs/_loop/critic/turn_58.md` with the structure below. Your verdict is independent of judge.py's PASS verdict and independent of T57's overall_verdict=CONFIRM. You may CORROBORATE, REFUTE, request more discrimination, or CORROBORATE-WITH-ERRATA. You may NOT pre-commit to any verdict; the data must drive the decision.\n\n### §1 Independent re-derivation\n\nWrite your OWN derivation of the predicted norm-drift floor for the Option γ rotating-basis run at dt=10^-3, T=314.16, theta=0.611, p=26700, F=6, phi_dot ∈ {1,...,18}, with whatever level of approximation you choose. Cite the textbook constants you use. Compare to T56 §2.1's 3e-10 figure. State whether your derivation lands within T56's [3e-11, 3e-8] band, or whether you derive a sharper / different bound.\n\nWrite your OWN derivation of the expected BCH residual signature in the m+F fraction drop. Cite the absorption factor `(phi_dot/p)^2` argument (or derive an alternative). Compare to T56 §2.3's 1.6e-5-at-phi=18 estimate. Compare to T57's observed drops ~40-1250 ppb (4e-8 to 1.25e-6).\n\n### §2 Confounder examination (each must produce a CORROBORATE / FLAG / REFUTE classification)\n\n**C1. Y4 floor uncertainty band.** T56 §2.1 derived `floor ∈ [3e-11, 3e-8]` (C_Y4_spinor ∈ [1,100]). T57 observed 2-4e-9. Does this fall \"inside\" the band (CORROBORATE — the Y4 floor explains the observed) or does the breadth of the band make the CONFIRM verdict only weakly discriminating (FLAG)? Explicitly assess whether the analysis is essentially `<bound>` testing rather than testing a structured physical prediction.\n\n**C2. Chi-square sigma_baseline circularity.** T57 uses `std(residuals[1:4])` (low-phi=1.0, 2.0, 3.0, 4.524) as sigma_baseline to compute max_sigma_deviation = max(|residuals|) / sigma_baseline = 1.95. If the low-phi-4 residuals are themselves the noise floor (and they are: at low phi the BCH residual is expected `(phi/18)^2 = 0.0031` of the phi=18 signature → far below detection), then this estimator is tautological: it normalises the high-phi residuals against a baseline that includes them only if the residuals are uniformly noise. Is the 1.95 sigma value a real discriminator, or is the test self-justifying? Consider an alternative: use all 8 residuals' MAD or the full-residual std; recompute max_sigma_deviation; classify whether the secondary verdict CONFIRM holds under both metrics.\n\n**C3. Sign of m+F drop.** T57 §5 honestly flags: m+F drops are NEGATIVE (fraction INCREASES over steady-stir window). T56 §4 pseudocode named this `m_plus_F_drop = steady_pmh[1, 1] - steady_pmh[1, end]` — so the negative sign means `steady_pmh[1, end] > steady_pmh[1, 1]`. Memory `option_gamma_rotating_basis.md` line 34 reports m=+F fraction `0.94 → 0.55` for Dy164 — a DECREASE (positive drop in T57's sign convention). Why does the eu151 Klaus run show the OPPOSITE: a small slow INCREASE in the steady window? Three candidates: (i) the snapshots are AFTER the system has already lagged into a high-leakage transient at SPINUP_END=21.99, and the steady-stir then partially re-aligns (recovery); (ii) the steady-window selection is mis-aligned with the actual coherent phase (the first \"steady\" snapshot is still mid-transient); (iii) a sign convention inconsistency between the script and the data. Identify which is true; this affects the discriminator's interpretation.\n\n**C4. Mixed-frame Jz_proxy adequacy.** T56 §2.2 argued the mixed-frame proxy `Fz_tilde + Lz` time-averages to a Tier-2.x sufficient EdH-conservation indicator. T57 observed Jz_proxy_mean ≈ 6.0-6.1 across all phi, drift 1.4e-2 to 3.3e-1 (one to two decades range). Is the drift bounded enough to claim conservation, or is the spread itself a sign of EdH non-conservation that would require the full lab-frame reconstruction (cpu_heavy, ~30 min/phi)? Recommend whether this is sufficient or whether a follow-up cpu_heavy turn is warranted.\n\n**C5. Larmor_phase invariance — sanity check vs tautology.** T57 confirms larmor_phase=160.2 for all 8 phi. T56 §2.4(d) explicitly notes this is BOOKKEEPING (p,F,dt do not vary in the scan). Director T57 §6 promoted this to a success_criterion. Was this a meaningful sanity check, or is it a true tautology that adds no scientific information? Classify; does NOT affect main verdict.\n\n**C6. Y4 commutator-norm assumption (T56 §2.1 bound type ii).** T56's \"effective bound\" replaces the conservative `(pF)^3 * c_dd<n>^2` with `(phi_dot F + c_dd<n>)^3 * c_dd<n>^2`. The replacement argues that the eigen-exact spin step removes the pF amplification factor. INDEPENDENT QUESTION: is this replacement rigorous, or is it the very claim being tested (i.e., circular reasoning)? Specifically: the Y4 truncation involves nested commutators like `[H_spin^rot, [H_spin^rot, H_DDI]]`; if `H_spin^rot` has a diagonal piece of norm pF that does NOT commute with H_DDI (off-diagonal in m), the nested commutator pulls in pF amplification. T56 §2.1 claims the eigendecomposition handles the diagonal piece exactly per local spin step but does NOT explicitly justify that the MACRO Y4 commutator bound is reduced. Is the Y4 floor estimate 3e-10 valid, or is the true Y4 floor closer to the conservative 10^1 (i.e., the run would diverge if Y4 truncation were tight against pF nested commutators)? Test: at phi=0 (no stir, gauge connection = 0), the spin step is exact and DDI commutes only with the diagonal part. T57 didn't run phi=0; can you bound the question using only the 8 phi values? Specifically: if Y4 truncation were pF-amplified, the norm drift would saturate at the Y4 truncation per step, NOT at the round-off floor — the constancy of norm_drift ≈ 3e-9 across phi (no phi-ordering at all) is evidence that Y4 truncation is BELOW the round-off floor, not that the bound is well-controlled. Re-examine and reach a verdict.\n\n**C7. Production-code current-state.** T56 §1.2 read `propagators.jl:146-231` and confirmed eigen-exact structure. Cross-check by reading lines 146-231 of the CURRENT file (today) and verify nothing has changed since T56. If a refactor has landed, this changes the verdict.\n\n### §3 Errata flag list\n\nList any errata, sign-convention issues, threshold-derivation issues, or interpretation issues you find in T56, T57, or T57 director. Each errata gets:\n- Source file + section\n- Claim as stated\n- Correction\n- Severity: {load-bearing-fix-required, advisory-note, cosmetic}\n\n### §4 Verdict\n\nOne of:\n- `CORROBORATE`: tier 2.7 → 3.0; recommend Document close at T59.\n- `CORROBORATE-WITH-ERRATA`: tier 2.7 → 3.0 minus errata flags; recommend Document close at T59 with errata propagated to memory.\n- `NEEDS-FURTHER-DISCRIMINATION`: tier stays 2.7; recommend specific next Execute (cpu_heavy lab-frame reconstruction at theta=0.611, or phi=0 control, or finer phi grid near a suspected anomaly).\n- `REFUTE`: tier drops to 1.5; recommend re-Hypothesize at T59 with the refuted-hypothesis as known-bad anchor.\n\nState the recommended next stage explicitly.\n\n### §5 Recommended next-falsifier-to-test (if not CORROBORATE)\n\nIf REFUTE or NEEDS-FURTHER-DISCRIMINATION: name the next falsifier with explicit observable + threshold. If CORROBORATE: list deferred falsifiers (T55 Falsifier 4 P3 p-scaling at 3 p values; cpu_heavy lab-frame snapshot post-rotation) and assign priority for post-closure follow-up.\n\n### §6 Metrics (machine-evaluable, single fenced JSON block)\n\n```json\n{\n  \"experiment_kind\": \"text_only\",\n  \"src_files_modified\": 0,\n  \"new_analysis_scripts_written\": 0,\n  \"investigation_id\": \"klaus-magnetostir-bch-leak-2026-05-13\",\n  \"stage_advancing_to\": \"Update\",\n  \"flow_template\": \"verify-claim\",\n  \"falsifier_id\": \"klaus-bch-leak-option-gamma-p2-plus-pop-discriminator\",\n  \"verdict\": \"CORROBORATE | CORROBORATE-WITH-ERRATA | NEEDS-FURTHER-DISCRIMINATION | REFUTE\",\n  \"tier_recommendation\": <float, one of 1.5, 2.7, 3.0>,\n  \"next_stage_recommended\": \"Document | re-Hypothesize | Execute (cpu_heavy fallback) | Execute (finer phi grid)\",\n  \"independent_y4_floor_derivation\": <float — your own derived value>,\n  \"independent_y4_floor_band_lo\": <float>,\n  \"independent_y4_floor_band_hi\": <float>,\n  \"observed_norm_drift_falls_in_independent_band\": <bool>,\n  \"independent_bch_residual_at_phi_18\": <float — your own derived expected m+F residual>,\n  \"observed_m_plus_F_drops_consistent_with_zero_residual\": <bool>,\n  \"chi_square_sigma_baseline_circular\": <bool>,\n  \"alternate_max_sigma_deviation_using_full_residual_std\": <float>,\n  \"alternate_max_sigma_deviation_using_MAD\": <float>,\n  \"m_plus_F_sign_explanation\": \"recovery-from-transient | mis-aligned-steady-window | sign-convention-inconsistency | unknown\",\n  \"jz_proxy_adequate\": <bool>,\n  \"larmor_phase_invariance_is_meaningful\": <bool>,\n  \"y4_commutator_norm_argument_rigorous\": <bool>,\n  \"propagators_jl_unchanged_since_t56\": <bool>,\n  \"confounder_C1_verdict\": \"CORROBORATE | FLAG | REFUTE\",\n  \"confounder_C2_verdict\": \"CORROBORATE | FLAG | REFUTE\",\n  \"confounder_C3_verdict\": \"CORROBORATE | FLAG | REFUTE\",\n  \"confounder_C4_verdict\": \"CORROBORATE | FLAG | REFUTE\",\n  \"confounder_C5_verdict\": \"CORROBORATE | FLAG | REFUTE\",\n  \"confounder_C6_verdict\": \"CORROBORATE | FLAG | REFUTE\",\n  \"confounder_C7_verdict\": \"CORROBORATE | FLAG | REFUTE\",\n  \"errata_count\": <int 0+>,\n  \"errata_load_bearing_count\": <int 0+>,\n  \"errata_advisory_count\": <int 0+>,\n  \"references_cited\": [\"hairer-lubich-wanner-2006-section-III.4\", \"yoshida-1990-PLA-150-262\", \"...\"],\n  \"n_references_cited\": <int, must be >= 3>,\n  \"line_37_memory_claim_verified_current\": <bool>,\n  \"deferred_falsifiers\": [\"P3-p-scaling-fresh-run-3-p-values\", \"cpu-heavy-lab-frame-snapshot-post-rotation\", \"...\"]\n}\n```\n\nMUST be a single fenced ```json``` block.\n\n## CONSTRAINTS\n\n- **Files allowed to create**: `runs/_loop/critic/turn_58.md` (your report). That's it.\n- **Files allowed to modify**: none.\n- **Do NOT modify**: `src/`, `runs/eu151_klaus_phi_phys/*`, any other `runs/_loop/` file, `.claude/*`, any memory file, the analysis script.\n- **No julia execution required**: you may invoke Julia only to inspect `runs/_loop/sim/turn_57_results.jld2` for alternate statistics (e.g., MAD computation). If you do, the script must be ≤ 30 lines and ≤ 30 s wall.\n- **English only. No emojis.**\n- **Absolute paths in all tool calls.**\n- **Cost budget**: stay within ~2M effective tokens, ~15 min wall hard cap.\n- **Independence**: do NOT pre-commit to any verdict. Read the data + theorist derivations + production code FIRST; form verdict from evidence.\n- **No fabrication**: if you cannot derive an independent Y4 floor, say so and rely on T56's bound while flagging the dependence. Do NOT invent textbook citations.\n- **Verdict must be one of the 4 tokens. Tier must be one of {1.5, 2.7, 3.0}.**\n\n## SUCCESS CRITERIA (machine-evaluable in §4 Metrics block)\n\nSee §6 Metrics in the brief. judge.py will mechanically check the verdict token, tier value, and required fields.\n\nReport HONESTLY. The CORROBORATE-WITH-ERRATA path (precedent: T28 Bloch-Siegert) is fine — the science is served by named errata, not by polishing them away.",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "src_files_modified",
      "new_analysis_scripts_written",
      "investigation_id",
      "stage_advancing_to",
      "flow_template",
      "falsifier_id",
      "verdict",
      "tier_recommendation",
      "next_stage_recommended",
      "independent_y4_floor_derivation",
      "independent_y4_floor_band_lo",
      "independent_y4_floor_band_hi",
      "observed_norm_drift_falls_in_independent_band",
      "independent_bch_residual_at_phi_18",
      "observed_m_plus_F_drops_consistent_with_zero_residual",
      "chi_square_sigma_baseline_circular",
      "alternate_max_sigma_deviation_using_full_residual_std",
      "alternate_max_sigma_deviation_using_MAD",
      "m_plus_F_sign_explanation",
      "jz_proxy_adequate",
      "larmor_phase_invariance_is_meaningful",
      "y4_commutator_norm_argument_rigorous",
      "propagators_jl_unchanged_since_t56",
      "confounder_C1_verdict",
      "confounder_C2_verdict",
      "confounder_C3_verdict",
      "confounder_C4_verdict",
      "confounder_C5_verdict",
      "confounder_C6_verdict",
      "confounder_C7_verdict",
      "errata_count",
      "errata_load_bearing_count",
      "errata_advisory_count",
      "references_cited",
      "n_references_cited",
      "line_37_memory_claim_verified_current",
      "deferred_falsifiers"
    ],
    "optional": [],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_57.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_57.json && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_56.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/critic/turn_28.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_57_results.jld2 && test -f /home/suzume/workspace/BEC-simulation/src/rotating_basis/propagators.jl && test -d /home/suzume/workspace/BEC-simulation/runs/_loop/critic && echo 'precondition OK: T57 sim+judge, T56 theorist, T28 critic precedent, T57 results.jld2, propagators.jl, critic dir all present; ready for T58 critic Update'"
  },
  "success_criteria": [
    {
      "id": "experiment_kind_correct",
      "metric": "experiment_kind",
      "operator": "==",
      "value": "text_only",
      "tolerance": null,
      "rationale": "Critic is text-only; no julia execution required."
    },
    {
      "id": "src_unchanged",
      "metric": "src_files_modified",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Critic must not modify src/."
    },
    {
      "id": "no_scripts_added",
      "metric": "new_analysis_scripts_written",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Critic produces text report only; optional julia-snippets to inspect results.jld2 are in-line not new files."
    },
    {
      "id": "investigation_consistent",
      "metric": "investigation_id",
      "operator": "==",
      "value": "klaus-magnetostir-bch-leak-2026-05-13",
      "tolerance": null,
      "rationale": "Investigation continuity."
    },
    {
      "id": "stage_consistent",
      "metric": "stage_advancing_to",
      "operator": "==",
      "value": "Update",
      "tolerance": null,
      "rationale": "§F1 Update stage."
    },
    {
      "id": "template_consistent",
      "metric": "flow_template",
      "operator": "==",
      "value": "verify-claim",
      "tolerance": null,
      "rationale": "verify-claim template per state.json."
    },
    {
      "id": "falsifier_carried",
      "metric": "falsifier_id",
      "operator": "==",
      "value": "klaus-bch-leak-option-gamma-p2-plus-pop-discriminator",
      "tolerance": null,
      "rationale": "Carry T56-T57 falsifier name through Update."
    },
    {
      "id": "verdict_in_4_token_set",
      "metric": "verdict",
      "operator": "in",
      "value": ["CORROBORATE", "CORROBORATE-WITH-ERRATA", "NEEDS-FURTHER-DISCRIMINATION", "REFUTE"],
      "tolerance": null,
      "rationale": "One of four explicit verdict tokens."
    },
    {
      "id": "tier_in_3_value_set",
      "metric": "tier_recommendation",
      "operator": "in",
      "value": [1.5, 2.7, 3.0],
      "tolerance": null,
      "rationale": "Tier must map to one of REFUTE(1.5), NEEDS-DISCRIMINATION(2.7-stay), or CORROBORATE(3.0)."
    },
    {
      "id": "next_stage_in_set",
      "metric": "next_stage_recommended",
      "operator": "in",
      "value": ["Document", "re-Hypothesize", "Execute (cpu_heavy fallback)", "Execute (finer phi grid)"],
      "tolerance": null,
      "rationale": "Next stage must be one of four explicit options."
    },
    {
      "id": "n_references_minimum",
      "metric": "n_references_cited",
      "operator": ">=",
      "value": 3,
      "tolerance": null,
      "rationale": "Critic must cite ≥3 external references (textbook + papers + prior loop turns). Independence requires grounded reasoning, not vibes."
    },
    {
      "id": "all_7_confounders_evaluated_C1",
      "metric": "confounder_C1_verdict",
      "operator": "in",
      "value": ["CORROBORATE", "FLAG", "REFUTE"],
      "tolerance": null,
      "rationale": "Each named confounder (C1-C7) gets explicit verdict; missing any = incomplete critic."
    },
    {
      "id": "all_7_confounders_evaluated_C2",
      "metric": "confounder_C2_verdict",
      "operator": "in",
      "value": ["CORROBORATE", "FLAG", "REFUTE"],
      "tolerance": null,
      "rationale": "C2 chi-square sigma_baseline circularity examined."
    },
    {
      "id": "all_7_confounders_evaluated_C3",
      "metric": "confounder_C3_verdict",
      "operator": "in",
      "value": ["CORROBORATE", "FLAG", "REFUTE"],
      "tolerance": null,
      "rationale": "C3 m+F drop sign explained."
    },
    {
      "id": "all_7_confounders_evaluated_C4",
      "metric": "confounder_C4_verdict",
      "operator": "in",
      "value": ["CORROBORATE", "FLAG", "REFUTE"],
      "tolerance": null,
      "rationale": "C4 Jz_proxy adequacy examined."
    },
    {
      "id": "all_7_confounders_evaluated_C5",
      "metric": "confounder_C5_verdict",
      "operator": "in",
      "value": ["CORROBORATE", "FLAG", "REFUTE"],
      "tolerance": null,
      "rationale": "C5 larmor_phase invariance examined (likely FLAG-as-tautology but explicit verdict needed)."
    },
    {
      "id": "all_7_confounders_evaluated_C6",
      "metric": "confounder_C6_verdict",
      "operator": "in",
      "value": ["CORROBORATE", "FLAG", "REFUTE"],
      "tolerance": null,
      "rationale": "C6 Y4 commutator-norm replacement rigor — the most theoretically load-bearing confounder."
    },
    {
      "id": "all_7_confounders_evaluated_C7",
      "metric": "confounder_C7_verdict",
      "operator": "in",
      "value": ["CORROBORATE", "FLAG", "REFUTE"],
      "tolerance": null,
      "rationale": "C7 production code current-state — propagators.jl unchanged since T56."
    },
    {
      "id": "line_37_claim_verified",
      "metric": "line_37_memory_claim_verified_current",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Critic must directly verify (or re-verify) the load-bearing memory claim against current code. If false, the entire verification stack collapses."
    },
    {
      "id": "errata_count_non_negative",
      "metric": "errata_count",
      "operator": ">=",
      "value": 0,
      "tolerance": null,
      "rationale": "Errata count is non-negative. Zero is fine — critic may find no errata."
    },
    {
      "id": "errata_load_bearing_blocks_corroborate",
      "metric": "errata_load_bearing_count",
      "operator": "<=",
      "value": 99,
      "tolerance": null,
      "rationale": "No upper limit; but if errata_load_bearing_count > 0 then verdict should NOT be plain CORROBORATE. Director will route accordingly at T59."
    }
  ],
  "failure_modes": [
    {
      "if": "verdict == 'CORROBORATE' AND errata_load_bearing_count > 0",
      "category": "scientific_inconsistency",
      "next_action": "T59 director re-dispatches critic with explicit instruction: if errata_load_bearing_count > 0, verdict must be CORROBORATE-WITH-ERRATA or NEEDS-FURTHER-DISCRIMINATION, not plain CORROBORATE. Most likely scenario: critic dispatch ended with CORROBORATE but also raised a load-bearing error — operational re-route, not scientific failure."
    },
    {
      "if": "verdict == 'CORROBORATE' OR verdict == 'CORROBORATE-WITH-ERRATA'",
      "category": "scientific_success",
      "next_action": "T59 dispatches implementer_text Document stage: memory entry update (option_gamma_rotating_basis.md or new dedicated entry), state.json closure to current_stage=closed with tier_current=3.0 (project's 2nd Tier-3). If errata exist, propagate them into the memory entry as named-and-dated advisories. T60 cycle starts on a different investigation (likely meta-stage-routing terminal-close or audit-class-scan-T62)."
    },
    {
      "if": "verdict == 'NEEDS-FURTHER-DISCRIMINATION'",
      "category": "scientific_inconclusive",
      "next_action": "T59 director decides on the specific next Execute: (a) cpu_heavy lab-frame snapshot post-rotation at one phi point (T56 §2.2 Tier-3 fallback, ~30 min) — uses a phi=18 representative; (b) cpu_light phi=0 control run (sanity that Option γ at zero stir gives zero residual baseline); (c) finer phi grid (cpu_heavy fresh runs). Choose based on critic's specific named concern in §5."
    },
    {
      "if": "verdict == 'REFUTE'",
      "category": "scientific_refuted",
      "next_action": "T59 director routes to re-Hypothesize. Tier drops to 1.5. The Option γ load-bearing claim is partially or fully refuted; theorist examines critic's named issue and produces a revised hypothesis. This is a serious outcome (Option γ subsystem is ~700 LOC, 106+ tests) — anko awareness flag MUST appear in T59 director report. Memory `option_gamma_rotating_basis.md` line 37 gets an `[ERRATA-2026-05-18]` advisory header."
    },
    {
      "if": "line_37_memory_claim_verified_current == false",
      "category": "framework_error",
      "next_action": "Production code at src/rotating_basis/propagators.jl has been modified since T56 in a way that affects the load-bearing claim. T59 dispatches researcher to git-blame the affected lines + critic to re-derive against the new code. The T57 verification is invalidated; tier reverts to whatever was pre-T55 (2.0). Memory line-37 claim updated with new code anchor."
    },
    {
      "if": "propagators_jl_unchanged_since_t56 == false (different signal from line_37_verification)",
      "category": "framework_error",
      "next_action": "Refactor landed between T56 and T58 — may or may not affect the load-bearing claim. Subset of above; investigated at T59."
    },
    {
      "if": "n_references_cited < 3",
      "category": "operational",
      "next_action": "T59 director re-dispatches critic with explicit instruction to ground in ≥3 references. Indicates the critic dispatch produced a vibes-based verdict, violating §A6 research-first."
    },
    {
      "if": "src_files_modified > 0",
      "category": "scope_violation",
      "next_action": "T59 director reverts via git restore; critic was text-only by spec."
    },
    {
      "if": "verdict NOT IN 4-token-set OR tier NOT IN 3-value-set OR next_stage NOT IN 4-option-set",
      "category": "operational",
      "next_action": "T59 director re-dispatches critic with the explicit verdict-token / tier-value / next-stage-option grammar. Indicates a contract-following failure, not a science failure."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 2500000,
    "wall_time_hard_cap_sec": 900
  },
  "budget": {
    "expected_cost_eff": 1700000,
    "expected_wall_time_sec": 600,
    "split_by_subtask": {
      "read_required_8_files": 400000,
      "read_propagators_jl_for_C7": 150000,
      "optional_julia_inspect_results_jld2": 100000,
      "independent_derivations_section_1": 400000,
      "confounders_C1_to_C7_section_2": 400000,
      "errata_list_section_3": 100000,
      "verdict_section_4_5": 100000,
      "metrics_json_section_6": 50000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Document (T59 implementer_text adds memory entry + state.json closure; klaus-bch-leak goes to tier 3.0 closed, project's 2nd Tier-3 claim after barnett-mechanism-2026-05-16)",
    "if_success_tier_becomes": 3.0,
    "if_refuted_advance_to_stage": "re-Hypothesize (theorist examines critic's named issue; tier drops to 1.5; anko awareness flag in T59 director report; option_gamma memory line 37 gets ERRATA advisory header)",
    "if_refuted_tier_becomes": 1.5,
    "if_inconclusive_advance_to_stage": "Execute (cpu_heavy lab-frame snapshot post-rotation at phi=18 representative, OR cpu_light phi=0 control run, OR finer phi grid — chosen per critic §5)",
    "if_inconclusive_tier_becomes": 2.7,
    "next_falsifier_to_test_after": "If CORROBORATE: deferred P3 p-scaling (T55 Falsifier 4, 3 p values, cpu_heavy ~30 min/p) becomes optional post-closure follow-up. If REFUTE or INCONCLUSIVE: per critic §5."
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read `runs/_loop/_local/scheduler_58.json` (policy=JULIA_GPU_OK; critic in allowed_workloads; window 1,181,581s left; VRAM 12,967 MB free; foreign_julia=0; RAM 25.07 GB avail).
- [x] Read `runs/_loop/state.json` partial (history T28-T57; investigations dict full; active_investigation_id = stale yan-li-saito but klaus-bch-leak is the right active per T55-T57 chain).
- [x] Read `runs/_loop/seed.md` end-to-end (priority order; klaus-bch-leak priority 3 active).
- [x] Read `runs/_loop/director/turn_57.md` end-to-end (T57 dispatch + Execute fusion rationale).
- [x] Read `runs/_loop/sim/turn_57.md` end-to-end (measurements + honest discrepancy log).
- [x] Read `runs/_loop/judge/turn_57.json` (18/18 PASS contract).
- [x] Read `runs/_loop/theorist/turn_56.md` end-to-end (full formal hypothesis spec — derivation, falsifier bands, T57 pseudocode, calibrated claims).
- [x] Read memory `option_gamma_rotating_basis.md` lines 1-60 (line 37 load-bearing claim).
- [x] Verified template directory contents via Glob (3 templates available; none apply to text-only critic).
- [x] Verified critic-precedent at `runs/_loop/critic/turn_28.md` (barnett-mechanism Update — referenced as model).
- [x] investigation_id `klaus-magnetostir-bch-leak-2026-05-13` valid in state.json investigations dict.
- [x] stage_advancing_to `Update` is the §F1 next stage after Execute (Analyze fused with Execute per T57 director rationale).
- [x] subagent_type `critic` matches §F1 role_per_stage[Update] = critic (mandatory).
- [x] success_criteria 21 criteria, all machine-evaluable (==, >=, in, <= operators on strings/booleans/integers/floats/lists). Uses the post-T53-fix `in` operator with multi-element lists.
- [x] failure_modes cover 9 outcomes including scientific success/refute/inconclusive paths, framework_error for code-drift, scope_violation, operational verdict-grammar failures.
- [x] observable_manifest precondition_check verifies 7 required files + critic dir exist.
- [x] budget 1.7M expected, 2.5M tolerance; wall 600s expected, 900s hard cap.
- [x] §A6 research-first citation present (16 references: T28 critic precedent + T56 theorist sections + T57 sim + T55 research + T10 theorist + memory line 37 + Reflexion + LATS + AI Scientist v2 + Hairer-Lubich-Wanner + Yoshida 1990 + Grounded autonomous research + anko 2026-05-15/2026-05-18 + Anthropic Isolate).
- [x] §A5 D1-justified: this is the verify-claim Update gate for the load-bearing line-37 Option γ claim. Tier 2.7 → 3.0 promotion = project's 2nd Tier-3 candidate.
- [x] Considered alternative dispatches:
  - Skip Update, go straight to Document: rejected — violates §F1 mandatory-independent-context critic; would land tier at 2.7 not 3.0.
  - Run a fresh phi=0 control or finer phi grid: rejected pre-emptively — that's the NEEDS-FURTHER-DISCRIMINATION path which the critic itself should recommend if warranted; doing it first robs the critic of agency.
  - Switch to meta-stage-routing terminal close: rejected — defer to T59-60 after a couple more clean cycles to make the REFUTED-BY-CONFOUNDER call cleanly.
  - Switch to yan-li-saito R4: rejected — dormant tier 0.4, not anko-prioritized.
  - Switch to audit-class-scan T62: rejected — gap=8, below ~10-turn cadence trigger; defer to T62.
  - **klaus-bch-leak Update is highest leverage**: locks in or refutes a tier-3 promotion; mandatory per flow template.
- [x] All file paths in brief are absolute.
- [x] Brief explicitly forbids src/ touch, jld2 modification, additional julia runs beyond optional results.jld2 inspect, fabricated citations.
- [x] critic/turn_58.md §6 Metrics JSON block requirement specified with exact 39-field list.
- [x] No conventional commits drafted this turn (loop auto-commit handles it post-judge).
- [x] T59 routing pre-planned per outcome branch (CORROBORATE/WITH-ERRATA → Document; NEEDS-DISCRIMINATION → specific Execute; REFUTE → re-Hypothesize + anko flag).
- [x] §F1 Update stage role correctly assigned to critic per workload-class match.
- [x] No meta-meta investigation spawned (physics-class investigation).
- [x] Per `feedback_decision_style`: single commitment per turn = one critic dispatch.
- [x] Per `feedback_mathematical_elegance_bias`: critic checks 7 named confounders (C1-C7) rather than one unifying meta-confounder; named-confounder discipline is the established structure.
- [x] Per `feedback_mechanical_vs_investigation_threshold`: critic Update is the explicit non-mechanical investigation gate; not collapsible.
- [x] Per `feedback_fix_the_class_not_the_instance`: critic explicitly examines C2 (chi-square sigma_baseline circularity) as a class-level pattern: is the test self-justifying due to noise-floor self-anchoring? This is a methodology class, not an instance.
- [x] Per `feedback_no_improvised_terminology`: brief uses established terms (CORROBORATE/REFUTE/FLAG, errata, confounder, Y4 truncation, BCH commutator, Reflexion-Backprop) — no coined metaphors.
- [x] Per `feedback_manuscript_is_not_the_essence`: this is D1 verification depth, not manuscript polish; tier-3 promotion is the actual scientific output.
- [x] Per Director.md §H worked example: barnett T28 critic Update is the precise template; matches budget (~1.3M T28 vs 1.7M expected T58), structure (independent re-derivation + named-errata flagging), and outcome path (CORROBORATE-WITH-ERRATA precedent).
- [x] Drift advisories: AUDIT_DUE gap=8 (below 10-turn trigger); no DRIFT_COST_INFLATION expected this turn (critic baseline cost).
