---
turn: 59
subagent: director
investigation_id: klaus-magnetostir-bch-leak-2026-05-13
stage_advancing_from: Update (T58 critic CORROBORATE-WITH-ERRATA → tier 2.7 → 3.0; 3 advisory errata; 0 load-bearing)
stage_advancing_to: Document
topic_tags: [klaus-magnetostir, option-gamma, bch-leak, tier3-closure, verify-claim-document, memory-update, state-closure, errata-propagation, second-tier3-claim]
paper_section: null
depends_on: [10, 55, 56, 57, 58, "runs/_loop/director/turn_58.md", "runs/_loop/critic/turn_58.md", "runs/_loop/sim/turn_57.md", "runs/_loop/theorist/turn_56.md", "runs/_loop/research/turn_55.md", "runs/_loop/theorist/turn_10.md", "runs/_loop/state.json", "runs/_loop/seed.md", "memory:option_gamma_rotating_basis"]
produces: "Document closure of klaus-magnetostir-bch-leak-2026-05-13 at tier 3.0: (1) updated memory `option_gamma_rotating_basis.md` with verified-2026-05-18 (T57+T58) note + 3 errata advisories; (2) new dedicated memory entry `klaus_bch_leak_verification_2026_05_18.md` capturing the Tier-3 promotion record (sweep parameters, primary/secondary observables, independent critic re-derivations, deferred follow-ups); (3) state.json investigation closure (current_stage=closed, tier_current=3.0, blocked_on cleared); (4) by_tag index `klaus-magnetostir.md` appended with T58/T59 row."
---

# Turn 59 — Director Report

## 1. Investigation state snapshot

- **Active investigation (continuing)**: `klaus-magnetostir-bch-leak-2026-05-13` (priority 3, flow_template `verify-claim`, tier_current 3.0 per T58 critic verdict, tier_target 3). T58 closed Update cleanly with CORROBORATE-WITH-ERRATA.
- **Stage transition**: Update → **Document** per §F1. Document role = implementer_text. Rationale below in §3.
- **Tier**: 3.0 (already promoted in state.json at T58 closure). T59 Document does NOT change tier; it propagates errata to memory and writes terminal closure. The Tier-3 promotion IS already in state.json — Document is the bookkeeping + lesson-capture turn that completes §F1.
- **Falsifier this turn evaluated**: none. Document is post-verdict bookkeeping. Falsifier `klaus-bch-leak-option-gamma-p2-plus-pop-discriminator` already resolved CORROBORATE-WITH-ERRATA in T58.
- **Other in-flight investigations summary**:
  - `barnett-mechanism-2026-05-16` (priority 1): CLOSED tier 3.0. No action.
  - `yan-li-saito-2026-reproduction` (priority 1): dormant tier 0.4. R4 analytical revival path not anko-prioritized this session.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3): **THIS TURN** — Update → Document → closed at tier 3.0 (project's 2nd Tier-3 claim).
  - `meta-internal-b-unification-2026-05-18` (priority 5): CLOSED tier 1.
  - `audit-class-scan-2026-05-18-T50` (priority 20): CLOSED. Next audit cycle due ~T62 (current gap = 59-50 = 9; ~10-turn cadence triggers at T60-T62).
  - `meta-stage-routing-2026-05-18` (priority 25): held at Observe per T54 confounder_advisory; post-T53 streak through T58 is 0 FAIL/INCONCLUSIVE in 5 turns (T54 PASS, T55 RESEARCHER_ONLY, T56 NOOP-theorist, T57 PASS, T58 CRITIC_PASS) — hypothesis is firmly REFUTED-BY-CONFOUNDER trajectory. **NOT advancing this turn**; route to terminal close at T60-T61 after one more clean turn (klaus-bch-leak Document closure here means T60 starts on a different investigation — natural moment to fold meta-stage-routing closure into T60 if anko prioritizes).
  - `meta-critic-placement-2026-05-17` (priority 50): defer.
  - `judge-in-operator-bug-2026-05-18` (priority 2): CLOSED.
  - `fullbdg-f6-polar-3000x` (priority 99): contained, skip.
- **Scheduler** (`scheduler_59.json`): policy=JULIA_GPU_OK, allowed_workloads includes `implementer_text`. Window 1,180,626s left (~13.66 days). VRAM 12,950 MB free, foreign_julia=0, RAM 25.06 GB avail, GPU util 1%. Document is text-only — fits trivially.
- **Last judge verdict**: T58 = CRITIC_PASS, verdict CORROBORATE-WITH-ERRATA, tier_recommendation 3.0, next_stage_recommended Document. Routing per `investigation_update.if_success_advance_to_stage` = Document. State.json already reflects tier_current=3.0, current_stage=Update (will become closed after T59).
- **Drift signals (T58 footer)**: not yet surfaced in scheduler_59.json. T58 was 9.76M tokens (1.69M effective, within critic baseline). Pattern: 4-turn klaus-bch-leak run (T55-T58) has accumulated 28M + ~10M + 8M + 9.8M ≈ 56M effective — within rolling 5h cap. Document is the cheap closer.
- **State.json bookkeeping note**: `active_investigation_id` is correctly `klaus-magnetostir-bch-leak-2026-05-13` (T58 orchestrator fixed the T49 staleness).

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T56 | Hypothesize | NOOP (text-only) | Theorist formalized falsifier `klaus-bch-leak-option-gamma-p2-plus-pop-discriminator` with CONFIRM/REFUTE/INCONCLUSIVE bands. Y4 floor [3e-11, 3e-8] derived. T57 Julia pseudocode ~80 LOC. |
| T57 | Execute (+ Analyze fused) | PASS, overall CONFIRM | Implementer ran 337-LOC analysis script. 8/8 phi points complete data. Primary max_norm_drift_global=3.33e-9 (<1e-8 CONFIRM), growth ratio 1.033. Secondary max_sigma_deviation=1.95. m+F drops uniformly negative ~40-1250 ppb. Wall 2.87s. judge PASS 18/18. |
| T58 | Update | CRITIC_PASS, CORROBORATE-WITH-ERRATA | Critic independent re-derivation lands Y4 floor band [3e-11, 2e-8] (matches T56 within factor 2 by independent argument). Independent BCH residual estimate [1e-5, 5e-3] — observed 1e-6 is 1-3 orders below, fully consistent with zero BCH residual. 3 advisory errata: (E1) T56 §2.1 analytical gap in diag-vs-DDI commutator bound (empirical closure works); (E2) T56 §2.3 absorption-factor structure ambiguity (±2-order estimate spread); (E3) T57 m+F "drop" sign label cosmetic (should be "change"). 7 confounders evaluated: C1/C4/C5/C7 CORROBORATE, C2/C3/C6 FLAG. propagators.jl unchanged since T56. Line-37 memory claim verified current. Tier 2.7 → 3.0. |

## 3. Flow template recall

- **Template**: `verify-claim` (§F1): Research → Hypothesize → Design → Execute → Analyze → Update → **Document** → closed.
- **Why Document now**:
  - §F1 Document stage role = implementer_text. Single dispatch. Closes the verify-claim arc with memory entry + (only if anko-authorized) manuscript paragraph. Per `feedback_manuscript_is_not_the_essence` (anko 2026-05-15), no manuscript paragraph; just memory + state closure.
  - The T58 critic CORROBORATE-WITH-ERRATA explicitly recommends `next_stage = Document` and itemizes the 3 errata payload for the memory propagation step.
  - Precedent: barnett-mechanism-2026-05-16 T29 Document stage (the project's FIRST Tier-3 closure) — created `barnett-mechanism-confirmed.md` memory entry, appended `barnett.md` by_tag index, updated state.json. This T59 follows the same shape for the 2nd Tier-3.
  - Skipping Document = leaving the verify-claim arc structurally incomplete. The memory file `option_gamma_rotating_basis.md` lines 36-37 carry the load-bearing claim under verification; without a "verified 2026-05-18" annotation + errata propagation, future readers (including future loop turns) re-read the claim without the verification context and may re-litigate the same questions.
- **Why NOT skipping straight to next investigation**:
  - 0 LOC code change risk; ≤ 2M effective tokens; ≤ 10 min wall.
  - The cost of NOT documenting is asymmetric: the Y4-analytical-gap (errata 1) is a real flag that needs to surface in the memory so future investigations of the rotating_basis path see it without re-doing the critic work. Lost institutional memory has high downstream cost.
  - Per anko 2026-05-18 "Fix the class not the instance": this is the Update → Document hand-off that institutionalizes the lesson at class level (the rotating_basis verification framework now includes the Y4 analytical gap as a known caveat).
- **Why NOT switching investigations**:
  - klaus-bch-leak Document is one dispatch away from terminal closure at tier 3.0. Locking in the Tier-3 promotion record is the highest-leverage move this turn.
  - barnett (closed), yan-li-saito (dormant tier 0.4), audit-class-scan-T50 (closed), judge-bug (closed), meta-internal-b (closed), meta-stage-routing (1-2 more clean turns then terminal close), meta-critic-placement (priority 50 defer), fullbdg-f6 (contained).
  - meta-stage-routing terminal close is the natural T60 move once klaus-bch-leak closes here.
- **Role for Document**: `implementer_text` (text-only, no julia, no src/ modification). Single dispatch.

## 4. Research grounding (§A6)

External / prior references this dispatch grounds against:

1. **`runs/_loop/critic/turn_28.md`** — barnett-mechanism Update precedent (CORROBORATE → Document at T29).
2. **`/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/barnett_mechanism_confirmed.md`** — the template for a Tier-3 promotion memory entry: structured ID/date/result/verification-chain/errata/follow-ups blocks. T59 produces an analogous file for klaus-bch-leak.
3. **`runs/_loop/critic/turn_58.md` §3 errata flag list** — the 3 errata items to propagate verbatim with anchor citations.
4. **`runs/_loop/critic/turn_58.md` §6 Metrics block** — the canonical fact set for the closure record (tier_recommendation=3.0, observed_norm_drift_falls_in_independent_band=true, 7 confounder verdicts).
5. **Memory `option_gamma_rotating_basis.md` lines 36-37** — the load-bearing claim that now gains a "verified 2026-05-18 (T57+T58)" stamp.
6. **Memory `feedback_manuscript_is_not_the_essence.md`** — Document scope: memory entry only, NOT manuscript paragraph. Lesson capture is the value; polishing prose is not.
7. **Memory `feedback_fix_the_class_not_the_instance.md`** — Document institutionalizes lessons at class level (the Y4-analytical-gap caveat applies to ALL future rotating_basis verifications, not just this one).
8. **Memory `feedback_decision_style.md`** — single dispatch, no clarifying questions. Pick defaults and move.
9. **Anthropic Effective Harnesses pattern (Director.md §G)**: Initializer writes durable spec; Coder executes incrementally. Document IS the durable-spec write step that closes the loop on this investigation.
10. **Anthropic context engineering "Write" pattern (Director.md §G)** — the memory file IS the externalized context. Future-loop-turns reading the memory file get the verified-Tier-3 status without re-deriving.
11. **Reflexion (Shinn et al. 2023, arXiv:2303.11366)** — closure-of-task-trajectory step that exposes lessons for future tasks. The errata flags ARE the Reflexion lessons.
12. **Grounded autonomous research (arXiv:2604.12198, Director.md §G)** — "REFUTED is a science success when documented". Inverted form: "CORROBORATE-WITH-ERRATA is a tier-3 success when the errata are documented". The errata are not failures; they are honest caveats that strengthen the verification.
13. **Director.md §H worked example** — barnett Update → Document at T29 is the precise template.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1** (verify existing physics) — terminal closure. The Option γ subsystem's load-bearing line-37 claim is now Tier-3 verified (cross-implementation + independent critic CORROBORATE). The Document turn institutionalizes the verification + 3 advisory errata so future work building on Option γ inherits the verified-with-caveats status, not bare verification claims.
- **Tier ladder position**: tier_current already at 3.0 per T58 closure. Document does NOT change tier; it writes the closure record. After T59:
  - investigation `current_stage` = closed, tier_current = 3.0.
  - Project now has **2 Tier-3 investigations**: barnett-mechanism-2026-05-16 (T28+T29) and klaus-magnetostir-bch-leak-2026-05-13 (T57+T58+T59).
  - This doubles the project's Tier-3 verification depth, materially shifting the D1 axis status.
- **Manuscript NOT in scope** (per `feedback_manuscript_is_not_the_essence`). Document writes to memory + state.json + by_tag index ONLY.
- **Cost frame**: implementer_text Document baseline ~600k-1.5M effective per recent Document turns (T29: 1.53M, T49: ~1M, T54: ~700k). Text-only, no julia.
- **Drift signal forecast post-T59**: code_delta_zero=1 (no src/), manuscript_delta_zero=1, verdict PASS expected. Drift score should stay low; AUDIT_DUE gap will be 9 (still below the ~10-turn trigger).

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "klaus-magnetostir-bch-leak-2026-05-13",
  "stage_advancing_to": "Document",
  "subagent_type": "implementer_text",
  "rationale": "T58 critic CORROBORATE-WITH-ERRATA promoted tier_current 2.7 → 3.0 with 3 advisory errata (E1 Y4 analytical gap; E2 BCH residual estimate uncertainty bars; E3 m+F drop label cosmetic). §F1 verify-claim flow makes Document mandatory next stage to: (a) propagate the 3 errata to memory `option_gamma_rotating_basis.md` so future work inherits verified-with-caveats status not bare claim; (b) create dedicated Tier-3 promotion record `klaus_bch_leak_verification_2026_05_18.md` (mirrors `barnett_mechanism_confirmed.md` shape from T29 precedent); (c) close state.json investigation at current_stage=closed, tier_current=3.0, blocked_on cleared (the prior 'needs julia P3 validation' blocker is dissolved — the validation HAS been done, T55-T58); (d) append by_tag index `klaus-magnetostir.md` with the T58/T59 closure row. Single implementer_text dispatch. No julia, no src/ modification. Project gains its 2nd Tier-3 claim (after barnett-mechanism), doubling D1 verification depth.",
  "brief": "## ROLE\n\nYou are implementer_text. T59 §F1 Document stage of klaus-magnetostir-bch-leak-2026-05-13 (verify-claim flow). Terminal closure at tier 3.0 with 3 advisory errata propagation. Single dispatch; text-only; no julia execution; no src/ modification.\n\n## REQUIRED READING (READ FIRST, BEFORE WRITING ANYTHING)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/critic/turn_58.md` end-to-end — the verdict + 3 errata payload. This is the authoritative content source for what to propagate.\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_58.md` §1-§3 — investigation snapshot + flow recall.\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_57.md` end-to-end — the measurement report (numbers go into the dedicated memory entry).\n4. `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_56.md` §2, §3 — the hypothesis spec being verified.\n5. `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_10.md` §2.4-§3.5 — the original P1/P2/P3 BCH derivation.\n6. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/option_gamma_rotating_basis.md` end-to-end — the memory file to UPDATE with verification + errata stamps.\n7. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/barnett_mechanism_confirmed.md` if present, else `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/` Glob for similar — the TEMPLATE shape for a dedicated Tier-3 promotion memory record. If barnett_mechanism_confirmed.md does not exist, fall back to using `barnett.md` by_tag index as structural reference and write the new file de novo with the shape: ID/date/atom/regime/sweep/observables/independent-derivations/errata/follow-ups/citations.\n8. `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/klaus-magnetostir.md` — the by_tag index to APPEND a T58/T59 closure row to.\n9. `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` lines ~1513-1540 (the klaus-magnetostir-bch-leak-2026-05-13 investigation block) — to UPDATE: current_stage='closed', stages_done append 'Document', tier_current=3.0, next_stage=null, blocked_on=null, last_turn=59, last_stage='Document', closing_note added. (Use Edit tool with absolute paths — do NOT use Write on state.json which is large; targeted Edit only.)\n\n## YOUR JOB — 4 ARTIFACTS\n\n### Artifact 1: UPDATE `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/option_gamma_rotating_basis.md`\n\nAppend a new section at the END of the file (after the existing Session 3 / Phase 2 content, do NOT modify lines 1-100 which carry the original load-bearing claim):\n\n```\n## Verification 2026-05-18 (loop T55-T59) — Tier 3 promotion of line 37 load-bearing claim\n\nThe line-37 claim (eigen-exact local spin step is the load-bearing piece) was\nformally verified through the autonomous research loop, achieving Tier 3\n(cross-implementation + independent critic corroboration). See dedicated\nrecord `klaus_bch_leak_verification_2026_05_18.md` for full sweep parameters,\nobservables, independent derivations, and deferred falsifiers.\n\n**Verdict**: CORROBORATE-WITH-ERRATA (verify-claim flow Update stage, critic T58).\n\n**Primary observable**: max_norm_drift_global = 3.33e-9 across 8-point phi sweep\n(phi_dot ∈ {1, ..., 18}), well below CONFIRM threshold 1e-8. Phi-growth ratio\n1.033× (flat in phi to 4 decimal places), confirming the Option γ absorption\nfactor `(phi_dot/p)^2` mechanism: BCH leak is NOT amplified by the large\nLarmor parameter p = 26700.\n\n**Secondary observable**: m=+F fraction chi-square trend deviation\nmax_sigma_deviation = 1.95 (< 5σ CONFIRM band). Observed m+F changes are 40\nto 1250 ppb (4e-8 to 1.25e-6), 2-5 orders below the lowest BCH-residual\nestimate (1.6e-5 at phi=18), fully consistent with zero BCH residual + Y4\ntruncation phase floor + numerical round-off.\n\n**3 advisory errata** (loop T58 critic §3):\n\n1. **[ADVISORY E1] Y4 commutator-norm analytical gap.** T56 theorist's argument\n   that the eigen-exact spin step removes the pF amplification from macro-Y4\n   nested commutators (T56 §2.1 bound type ii) is correct for the off-diagonal\n   part of H_spin^rot, but the diagonal part -p·F_z's contribution to\n   [diag, H_DDI] is hand-waved. The analytical bound has a gap; empirical\n   closure (norm-drift constancy across 18× phi range, growth ratio 1.033)\n   provides falsification-resistant evidence that the pF amplification does\n   NOT happen in practice. Future work should either tighten the analytical\n   argument or rely on the empirical falsifier.\n\n2. **[ADVISORY E2] BCH residual estimate uncertainty bars.** T56's estimate\n   (1.6e-5 at phi=18) and critic T58's independent re-derivation (5e-3 at\n   phi=18) span ~2 orders due to ambiguity in whether (phi_dot/p) factors\n   are pre-absorbed into the bare amplitude. Both estimates are above the\n   observed ~1e-6, so the discriminator passes under either; but residual-amplitude\n   physics should be quoted with explicit ±2-order error bars in future work.\n\n3. **[COSMETIC E3] m+F \"drop\" label.** T56 §4 pseudocode and T57 analysis\n   script label the discriminator output as `m_plus_F_drop`, but observed\n   values are negative (fraction increases). Cause is recovery from the\n   spinup transient — Eu151 ε_dd_eff ≈ 0.02 is far below Dy164's 1.42, so\n   the steady-stir window shows mild recovery rather than continued droop.\n   Rename to `m_plus_F_change` in future scripts to avoid sign-convention\n   confusion. No scientific impact.\n\n**Production code**: src/rotating_basis/propagators.jl:146-231 unchanged since\nT56 verification; the eigen-exact `eigen!(Hermitian(H_dense))` + phase-multiplied\nreconstruction at lines 204-225 is the load-bearing eigen-exact local spin step.\n\n**Deferred (post-closure) falsifiers**:\n- P3 p-scaling at p ∈ {2670, 26700, 267000}, phi=4.524 fixed (cpu_heavy ~30 min)\n  — independent axis cross-check of the absorption mechanism.\n- cpu_heavy lab-frame Fz reconstruction post-rotation at phi=4.524 / 18 — true\n  EdH conservation observable (tier 3.5 polish; not tier 3 blocker).\n\n**Verification chain**: T55 (researcher data inventory) → T56 (theorist falsifier\nspec + Y4 floor derivation) → T57 (implementer 337-LOC analysis script, 8 phi\npoints, primary + secondary observables) → T58 (critic independent re-derivation,\n3 advisory errata, CORROBORATE-WITH-ERRATA verdict) → T59 (Document, this entry).\n```\n\nDo NOT modify the existing line 37 directly — leave it as the original claim, and let the new section above add the \"verified\" context. This preserves the institutional reading: load-bearing claim WITH verification stamp + caveats.\n\n### Artifact 2: CREATE `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/klaus_bch_leak_verification_2026_05_18.md`\n\nNew dedicated memory entry. Structural shape (model after barnett_mechanism_confirmed.md if it exists; otherwise use this shape):\n\n```\n---\nname: Klaus BCH leak — Option γ Tier-3 verification (T55-T59 2026-05-18)\ndescription: Cross-implementation + independent-critic-corroborated verification of the line-37 load-bearing claim in option_gamma_rotating_basis.md\ntype: project\n---\n\n## Status\n\n**Tier 3** (cross-implementation + critic CORROBORATE-WITH-ERRATA) as of 2026-05-18 T59.\n\nProject's 2nd Tier-3 claim (after barnett-mechanism-2026-05-16 T29 closure).\n\n## Hypothesis verified\n\nLab-frame spinor split-step has δÛ ~ dt² · p · F · sinθ · c_dd⟨n⟩ Larmor-linear\nBCH leak. Option γ (rotating-basis with eigen-exact local spin step) drops the\nBCH parameter from p·F·dt ≈ 26.7 to φ̇·F·dt ≈ 0.027 (4-decade reduction). The\nload-bearing piece is the single D×D matrix exponential combining diagonal\nZeeman with off-diagonal gauge connection (src/rotating_basis/propagators.jl:204-225).\n\n## Sweep parameters\n\n- Configuration: runs/eu151_klaus_phi_phys/\n- atom: ¹⁵¹Eu, F=6, D=13\n- dt: 1e-3 (dimless)\n- T_steady: 314.16 (dimless = 1.0 s in ω_ref = π × 100 Hz units)\n- theta: 0.611 rad (35°)\n- p: 26700 (Klaus magnetostir physical Larmor)\n- gauge_fix: false\n- phi_dot sweep: 8 points ∈ {1, 2, 3, 4.524, 6, 9, 12, 18}\n- integrator: Yoshida-4 macro + Strang substeps with eigen-exact local spin\n\n## Observables\n\n**Primary**: max_norm_drift_global = 3.33e-9 (across all 8 phi).\n- CONFIRM band: < 1e-8.\n- Growth ratio phi=18 / phi=1 = 1.033 (flat).\n- Independent critic Y4 floor band [3e-11, 2e-8] (LAPACK heevr backward error\n  + random/coherent round-off accumulation, Anderson et al. 2002, Demmel-Veselić\n  1992); observed value falls geometric-mean inside the band.\n\n**Secondary**: m=+F fraction chi-square trend deviation max_sigma_deviation = 1.95.\n- CONFIRM band: < 5σ.\n- Alternate critic-computed: full-residual std → 1.59σ (CONFIRM); MAD-scaled → 5.2σ\n  (borderline, sensitive to phi=12 outlier under non-Gaussian estimator).\n- Critic concluded: std estimator is correct under physics-motivated Gaussian-noise\n  null hypothesis; CONFIRM verdict robust.\n\n**Auxiliary**: m+F fraction change (sign-corrected from \"drop\" → \"change\")\nuniformly NEGATIVE 40-1250 ppb (fraction increases). Cause: recovery from\nspinup transient at SPINUP_END=21.99 (Eu151 low-ε_dd recovery, contrast with\nDy164 high-ε_dd droop in line 34).\n\n**Auxiliary**: larmor_phase = p·F·dt = 160.2 invariant across all phi (sanity\nregression that scan did not accidentally vary p/F/dt — not a scientific signal).\n\n**Auxiliary**: Jz_proxy_mean ≈ 6.0-6.1, drift 0.014-0.33 (mixed-frame proxy,\nlab-frame reconstruction deferred as tier-3.5 polish).\n\n## Verification chain\n\nT55 researcher (data inventory) → T56 theorist (falsifier spec + Y4 floor\n[3e-11, 3e-8]) → T57 implementer (337-LOC analysis script, 8 phi points,\nwall 2.87 s, judge 18/18 PASS) → T58 critic (independent re-derivation, 7\nconfounders evaluated: C1/C4/C5/C7 CORROBORATE, C2/C3/C6 FLAG; verdict\nCORROBORATE-WITH-ERRATA, tier 2.7 → 3.0; 3 advisory errata + 0 load-bearing).\n\n## Errata (3 advisory, 0 load-bearing)\n\n1. **[E1] Y4 commutator-norm analytical gap** — T56 §2.1 bound type ii. The\n   diag-vs-DDI off-diagonal-element argument is hand-waved; empirical falsifier\n   (norm-drift phi-constancy 1.033×) provides closure. Future analytical work\n   should tighten the diag-piece bound or formalize the empirical argument.\n\n2. **[E2] BCH residual estimate uncertainty bars** — T56 §2.3 vs critic §1.2\n   span 2 orders (1.6e-5 vs 5e-3 at phi=18) due to whether (φ̇/p) factors are\n   pre-absorbed into the bare amplitude. Both above observed ~1e-6 → discriminator\n   passes. Quote residual estimates with ±2 order error bars.\n\n3. **[E3 cosmetic] m+F \"drop\" label** — sign convention internally consistent,\n   but the label suggests fraction decrease while observed values show increase.\n   Cause: spinup-transient recovery. Rename to `m_plus_F_change` in future scripts.\n\n## Deferred follow-ups (post-closure, optional)\n\n- **P3 p-scaling** (T55 Falsifier 4): fresh rotating_basis run at p ∈ {2670,\n  26700, 267000}, phi=4.524 fixed. Falsifier: norm drift should be p-independent\n  in rotating_basis; lab-frame counterpart should scramble linearly in p.\n  cpu_heavy ~30 min. Priority: medium.\n- **cpu_heavy lab-frame Fz reconstruction post-rotation** at phi=4.524 and phi=18.\n  True EdH conservation observable. cpu_heavy ~30 min/phi. Priority: low\n  (mixed-frame proxy sufficient for Tier 3).\n\n## Citations\n\n- Hairer-Lubich-Wanner 2006 §III.4, §V.3.1 (BCH convergence radius, Yoshida\n  composition truncation constant).\n- Yoshida 1990 *Phys. Lett. A* 150, 262 (4th-order palindromic composition).\n- Anderson et al. *LAPACK Users' Guide* 3rd ed. §4.10 (eigen backward error\n  O(D^1.5 ε_mach)).\n- Demmel & Veselić 1992 *SIAM J. Mat. Anal.* 13, 1204 (Hermitian eigenpair\n  perturbation bounds).\n- Kawaguchi-Ueda 2012 *Phys. Rep.* 520, 253 (spinor BEC review).\n- Stamper-Kurn & Ueda 2013 *Rev. Mod. Phys.* 85, 1191 (spinor BEC).\n- Loop turns: theorist T10 (original BCH derivation), researcher T55 (data\n  inventory), theorist T56 (falsifier formalization), implementer T57\n  (verification execution), critic T58 (independent re-derivation), this\n  director-driven document T59.\n\n## Related production code\n\n- `src/rotating_basis/propagators.jl:146-231` — eigen-exact local spin step (load-bearing).\n- `src/rotating_basis/` (~700 LOC, 106+ tests) — Option γ subsystem.\n- `scripts/diagnostic/klaus_bch_leak_verification.jl` (337 LOC) — the T57 analysis script,\n  retained as regression artifact.\n- `runs/eu151_klaus_phi_phys/` — the sweep configuration + JLD2 results.\n- `runs/_loop/sim/turn_57_results.jld2` — the per-phi-point summary dict.\n\n## Related memory\n\n- `option_gamma_rotating_basis.md` line 37 — the load-bearing claim now verified.\n- `barnett_mechanism_confirmed.md` (if present) — sibling Tier-3 record (T29 closure).\n- `feedback_manuscript_is_not_the_essence.md` — D1 verification depth axis this entry serves.\n```\n\nIf the barnett_mechanism_confirmed.md file does NOT exist under the memory directory, that's fine — write klaus_bch_leak_verification_2026_05_18.md de novo with the shape above. Use Glob to check.\n\n### Artifact 3: UPDATE `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` — investigation closure\n\nUse the Edit tool (NOT Write) targeted at the klaus-magnetostir-bch-leak-2026-05-13 block (around lines 1513-1540 in current state.json). Required field updates:\n\n- `current_stage`: \"Update\" → \"closed\"\n- `stages_done`: append \"Document\" (will become alphabetized [Analyze, Design, Document, Document, Execute, Hypothesize, Research, Update] — that's fine, stages can repeat in stages_done if the loop's convention so dictates; check the barnett block lines ~1446-1454 for precedent — if barnett's stages_done has \"Document\" only once, mirror that). Actually: looking at barnett's stages_done list, it has each stage once. The current klaus block already has \"Document\" in stages_done (line 1523) from a prior turn — leave as-is, don't double-add.\n- `tier_current`: already 3.0, leave.\n- `next_stage`: \"Document\" → null\n- `next_stage_action`: null (already null)\n- `blocked_on`: \"needs julia P3 validation against anko Klaus phi sweep data (P1/P2/P3 predictions in theorist/turn_10.md §3)\" → null (the blocker is dissolved — the validation HAS been done T55-T58)\n- `last_turn`: 57 → 59\n- `last_stage`: \"Execute\" → \"Document\"\n- `last_verdict`: \"CORROBORATE-WITH-ERRATA\" (already set, keep)\n- `last_critic_turn`: 58 (already set, keep)\n- `errata_pending`: 3 → 0 (errata are now propagated to memory)\n- ADD field `closing_note`: \"Tier 3 closure 2026-05-18 T59. CORROBORATE-WITH-ERRATA via T58 critic independent re-derivation. 3 advisory errata propagated to memory: option_gamma_rotating_basis.md (verification stamp + errata section) + klaus_bch_leak_verification_2026_05_18.md (dedicated record). Project's 2nd Tier-3 claim after barnett-mechanism-2026-05-16. Deferred (optional post-closure): P3 p-scaling (T55 Falsifier 4) + cpu_heavy lab-frame Fz reconstruction.\"\n- ADD field `errata_resolved` with the 3 errata IDs: [\"E1-y4-commutator-norm-analytical-gap\", \"E2-bch-residual-estimate-uncertainty-bars\", \"E3-m-plus-F-drop-label-cosmetic\"]\n\nUse Edit with absolute path; preserve surrounding JSON structure exactly; mind comma placement.\n\n### Artifact 4: APPEND `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/klaus-magnetostir.md`\n\nRead the existing file, find the most recent turn-row block, and append two new rows:\n\n- T58 row: stage=Update, verdict=CORROBORATE-WITH-ERRATA, role=critic, key result \"tier 2.7 → 3.0, 3 advisory errata, 7 confounders evaluated (4 CORROBORATE / 3 FLAG)\"\n- T59 row: stage=Document, verdict=PASS (anticipated), role=implementer_text, key result \"Tier 3 terminal closure; memory updated (option_gamma_rotating_basis.md + new klaus_bch_leak_verification_2026_05_18.md); investigation block closed in state.json with closing_note\"\n\nMatch the existing table format / row style. If the file does not have a table (just prose), append a short prose paragraph with the same content.\n\n## CONSTRAINTS\n\n- **Files allowed to create**: `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/klaus_bch_leak_verification_2026_05_18.md`, `runs/_loop/director/turn_59.md` (this turn, already written by director).\n- **Files allowed to modify (Edit only)**: `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/option_gamma_rotating_basis.md`, `runs/_loop/state.json` (TARGETED Edit, not Write — file is too large), `runs/_loop/by_tag/klaus-magnetostir.md`.\n- **Do NOT modify**: `src/`, `runs/eu151_*/`, `scripts/diagnostic/klaus_bch_leak_verification.jl` (retain as-is), `.claude/agents/*`, `.claude/scripts/*`, any other memory file, any other `runs/_loop/` file (judge/critic/sim/research/theorist turns are append-only artifacts).\n- **No julia execution required**. If you choose to run a brief `Pkg.test()` or similar smoke, do not — this is text-only Document.\n- **No new analysis scripts**.\n- **English only. No emojis.**\n- **Absolute paths in all tool calls.**\n- **Cost budget**: stay within ~1.5M effective tokens, ~12 min wall hard cap.\n- **Single commit**: at end, the artifacts represent ONE logical change (Tier-3 closure of klaus-bch-leak); auto-commit handles it post-judge.\n- **No fabrication**: all numbers in the new memory file MUST come from T57 sim/judge or T58 critic. Do NOT invent values. If a number is uncertain, cite the source turn explicitly.\n- **Preserve original line 37 of option_gamma_rotating_basis.md verbatim** — the new verification section APPENDS at the file end; the original claim is preserved as historical anchor.\n\n## SUCCESS CRITERIA (machine-evaluable in §4 Metrics block in your output)\n\nProduce `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_59.md` with the structure below. Note: stage=Document; experiment_kind=text_only.\n\n```markdown\n---\nturn: 59\nsubagent: implementer_text\ninvestigation_id: klaus-magnetostir-bch-leak-2026-05-13\nstage: Document\nverdict: PASS\n---\n\n# Turn 59 — Document closure of klaus-bch-leak verify-claim (Tier 3)\n\n## §1 Artifacts produced\n\n(list 4 artifacts: paths + create/modify status + summary of changes per artifact)\n\n## §2 Errata propagation (3 advisory)\n\n(list each errata with: source turn, claim, correction, severity, destination in memory)\n\n## §3 State.json delta\n\n(list each field changed in the klaus-magnetostir-bch-leak-2026-05-13 block: field, before, after)\n\n## §4 Metrics\n\n```json\n{\n  \"experiment_kind\": \"text_only\",\n  \"src_files_modified\": 0,\n  \"new_analysis_scripts_written\": 0,\n  \"investigation_id\": \"klaus-magnetostir-bch-leak-2026-05-13\",\n  \"stage_advancing_to\": \"Document\",\n  \"flow_template\": \"verify-claim\",\n  \"artifacts_created_count\": <int, must be 1: klaus_bch_leak_verification_2026_05_18.md>,\n  \"artifacts_modified_count\": <int, must be 3: option_gamma_rotating_basis.md, state.json, by_tag/klaus-magnetostir.md>,\n  \"memory_files_touched\": <int, must be 2>,\n  \"state_json_touched\": <bool, must be true>,\n  \"by_tag_index_touched\": <bool, must be true>,\n  \"errata_propagated_to_memory_count\": <int, must be 3>,\n  \"errata_load_bearing_count\": <int, must be 0>,\n  \"investigation_closed\": <bool, must be true>,\n  \"final_tier\": <float, must be 3.0>,\n  \"closing_note_present_in_state_json\": <bool, must be true>,\n  \"blocked_on_cleared\": <bool, must be true>,\n  \"original_line_37_preserved\": <bool, must be true>,\n  \"new_memory_file_has_verification_chain\": <bool, must be true>,\n  \"new_memory_file_has_citations\": <bool, must be true>,\n  \"new_memory_file_has_deferred_followups\": <bool, must be true>,\n  \"barnett_template_referenced\": <bool, true if barnett_mechanism_confirmed.md was found and used as template; false if file does not exist and de novo shape was used>\n}\n```\n\nMUST be a single fenced ```json``` block.\n```\n\nReport HONESTLY. If any of the 4 artifacts cannot be produced (e.g., a memory file's content is unexpectedly different from what this brief describes), STOP and report what you found rather than fabricating.",
  "expected_cost": 1100000,
  "if_fails_next_step": "T60 director examines failure mode: (a) if state.json edit failed (JSON corruption / wrong block), re-dispatch implementer_text with explicit jq-checked edit script; (b) if memory file write failed (path / permission), report to anko and noop; (c) if errata propagation incomplete (some errata IDs missing in new memory file), re-dispatch implementer_text with explicit checklist; (d) if dedicated memory file was not created and only the existing memory was updated, re-dispatch implementer_text to create the new file. None of these are scientific failures — operational re-routes only. If T59 Document produces PASS, T60 routes to either meta-stage-routing terminal close (Observe → REFUTED-BY-CONFOUNDER → Document at low cost) OR audit-class-scan T62 (if AUDIT_DUE gap reaches 10) OR yan-li-saito R4 (low-priority revival, skip unless anko prioritizes).",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "src_files_modified",
      "new_analysis_scripts_written",
      "investigation_id",
      "stage_advancing_to",
      "flow_template",
      "artifacts_created_count",
      "artifacts_modified_count",
      "memory_files_touched",
      "state_json_touched",
      "by_tag_index_touched",
      "errata_propagated_to_memory_count",
      "errata_load_bearing_count",
      "investigation_closed",
      "final_tier",
      "closing_note_present_in_state_json",
      "blocked_on_cleared",
      "original_line_37_preserved",
      "new_memory_file_has_verification_chain",
      "new_memory_file_has_citations",
      "new_memory_file_has_deferred_followups"
    ],
    "optional": ["barnett_template_referenced"],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/critic/turn_58.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_57.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_56.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_10.md && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/option_gamma_rotating_basis.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/state.json && test -d /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory && test -d /home/suzume/workspace/BEC-simulation/runs/_loop/by_tag && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/klaus-magnetostir.md && echo 'precondition OK: T58 critic, T57 sim, T56 theorist, T10 theorist, option_gamma memory, state.json, memory dir, by_tag dir, klaus-magnetostir tag all present; ready for T59 Document'"
  },
  "success_criteria": [
    {
      "id": "experiment_kind_correct",
      "metric": "experiment_kind",
      "operator": "==",
      "value": "text_only",
      "tolerance": null,
      "rationale": "Document is text-only; no julia execution."
    },
    {
      "id": "src_unchanged",
      "metric": "src_files_modified",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Document must not modify src/."
    },
    {
      "id": "no_scripts_added",
      "metric": "new_analysis_scripts_written",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Document produces memory + state changes only."
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
      "value": "Document",
      "tolerance": null,
      "rationale": "§F1 Document stage."
    },
    {
      "id": "template_consistent",
      "metric": "flow_template",
      "operator": "==",
      "value": "verify-claim",
      "tolerance": null,
      "rationale": "verify-claim template."
    },
    {
      "id": "exactly_one_artifact_created",
      "metric": "artifacts_created_count",
      "operator": "==",
      "value": 1,
      "tolerance": null,
      "rationale": "Exactly one new memory file: klaus_bch_leak_verification_2026_05_18.md."
    },
    {
      "id": "exactly_three_artifacts_modified",
      "metric": "artifacts_modified_count",
      "operator": "==",
      "value": 3,
      "tolerance": null,
      "rationale": "Three modifications: option_gamma memory, state.json, by_tag/klaus-magnetostir.md."
    },
    {
      "id": "two_memory_files_touched",
      "metric": "memory_files_touched",
      "operator": "==",
      "value": 2,
      "tolerance": null,
      "rationale": "Updated option_gamma + created klaus_bch_leak_verification."
    },
    {
      "id": "state_json_touched",
      "metric": "state_json_touched",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Investigation closure requires state.json edit."
    },
    {
      "id": "by_tag_touched",
      "metric": "by_tag_index_touched",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Closure row appended to by_tag/klaus-magnetostir.md."
    },
    {
      "id": "three_errata_propagated",
      "metric": "errata_propagated_to_memory_count",
      "operator": "==",
      "value": 3,
      "tolerance": null,
      "rationale": "T58 critic flagged exactly 3 errata (E1 Y4 gap, E2 BCH uncertainty, E3 label cosmetic); all 3 must land in memory."
    },
    {
      "id": "zero_load_bearing_errata",
      "metric": "errata_load_bearing_count",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "T58 critic determined 0 load-bearing errata; Document does not introduce any."
    },
    {
      "id": "investigation_closed_flag",
      "metric": "investigation_closed",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "current_stage must transition to 'closed' in state.json."
    },
    {
      "id": "final_tier_is_3",
      "metric": "final_tier",
      "operator": "==",
      "value": 3.0,
      "tolerance": null,
      "rationale": "tier_current must end at 3.0 (Tier-3 promotion via T58 CORROBORATE-WITH-ERRATA)."
    },
    {
      "id": "closing_note_set",
      "metric": "closing_note_present_in_state_json",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Closing note added to state.json investigation block."
    },
    {
      "id": "blocker_cleared",
      "metric": "blocked_on_cleared",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "The 'needs julia P3 validation' blocker is dissolved (validation has been done T55-T58); blocked_on must be set to null."
    },
    {
      "id": "line_37_preserved",
      "metric": "original_line_37_preserved",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Historical anchor: the original load-bearing claim at line 37 of option_gamma_rotating_basis.md must remain verbatim. Verification section APPENDS at file end."
    },
    {
      "id": "new_memory_has_chain",
      "metric": "new_memory_file_has_verification_chain",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "New memory file must explicitly list T55→T56→T57→T58→T59 verification chain for future reproducibility."
    },
    {
      "id": "new_memory_has_citations",
      "metric": "new_memory_file_has_citations",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "New memory file must cite the 6 sources from critic §6 + the loop turns; no fabrication."
    },
    {
      "id": "new_memory_has_deferred",
      "metric": "new_memory_file_has_deferred_followups",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "New memory file must list P3 p-scaling + cpu_heavy lab-frame as deferred optional follow-ups (per T58 §5)."
    }
  ],
  "failure_modes": [
    {
      "if": "investigation_closed == false OR final_tier != 3.0",
      "category": "operational",
      "next_action": "T60 director re-dispatches implementer_text with explicit jq commands to set current_stage='closed' and tier_current=3.0 in state.json klaus-bch-leak block. Indicates the state.json edit was incomplete or targeted the wrong block. Not a scientific failure."
    },
    {
      "if": "errata_propagated_to_memory_count < 3",
      "category": "operational",
      "next_action": "T60 director re-dispatches implementer_text with explicit checklist of the 3 errata IDs (E1/E2/E3) that must appear in memory. Missing errata = institutional memory loss; must be corrected."
    },
    {
      "if": "original_line_37_preserved == false",
      "category": "scope_violation",
      "next_action": "T60 director git-restores option_gamma_rotating_basis.md to pre-T59 state and re-dispatches implementer_text with explicit instruction to APPEND a new section at the file end, NOT to edit line 37. The historical anchor must be preserved verbatim."
    },
    {
      "if": "src_files_modified > 0",
      "category": "scope_violation",
      "next_action": "T60 director reverts via git restore; implementer_text was text-only by spec. Investigate which src/ file was touched and why."
    },
    {
      "if": "artifacts_created_count > 1 OR artifacts_modified_count > 3",
      "category": "scope_creep",
      "next_action": "T60 director audits the unexpected artifacts. If they are inadvertent (e.g., backup file written by tool), no action. If they expand scope (e.g., implementer_text proposed a new investigation memory entry), review and either accept or revert."
    },
    {
      "if": "blocked_on_cleared == false",
      "category": "operational",
      "next_action": "T60 director makes a one-line state.json edit to set blocked_on=null. The 'needs julia P3 validation' blocker is empirically dissolved by T55-T58."
    },
    {
      "if": "new_memory_file_has_citations == false OR new_memory_file_has_verification_chain == false",
      "category": "operational",
      "next_action": "T60 director re-dispatches implementer_text with explicit citation list (6 sources from critic §6 + 5 loop turn references). The new memory file is the durable spec; missing citations = future readers cannot trace the verification."
    },
    {
      "if": "ANY field in Metrics block missing or wrong type",
      "category": "operational",
      "next_action": "T60 director re-dispatches implementer_text with explicit reminder of the 21-field Metrics block schema. Indicates a contract-following lapse."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 2000000,
    "wall_time_hard_cap_sec": 720
  },
  "budget": {
    "expected_cost_eff": 1100000,
    "expected_wall_time_sec": 480,
    "split_by_subtask": {
      "read_required_8_files": 400000,
      "write_klaus_bch_leak_verification_md_artifact_2": 250000,
      "edit_option_gamma_memory_artifact_1": 150000,
      "edit_state_json_artifact_3": 100000,
      "edit_by_tag_klaus_magnetostir_artifact_4": 50000,
      "write_sim_turn_59_md_report": 150000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "closed",
    "if_success_tier_becomes": 3.0,
    "if_refuted_advance_to_stage": "Update (revert to T58 critic stage if Document somehow surfaces a load-bearing errata that was missed)",
    "if_refuted_tier_becomes": 2.7,
    "if_inconclusive_advance_to_stage": "Document (re-dispatch with corrected contract per failure_modes)",
    "if_inconclusive_tier_becomes": 3.0,
    "next_falsifier_to_test_after": "Investigation closes. Deferred optional follow-ups: P3 p-scaling (T55 Falsifier 4) and cpu_heavy lab-frame Fz reconstruction. Neither is required for Tier 3; either may be picked up later if anko prioritizes or if a future investigation needs them."
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read `runs/_loop/_local/scheduler_59.json` (policy=JULIA_GPU_OK; implementer_text in allowed_workloads; window 1,180,626s left; VRAM 12,950 MB free; foreign_julia=0; RAM 25.06 GB avail).
- [x] Read `runs/_loop/state.json` partial (history T28-T58; investigations dict full klaus-bch-leak block + barnett + yan-li-saito + audit-class-scan + judge-bug + meta blocks; active_investigation_id correctly set to klaus-magnetostir-bch-leak-2026-05-13; tier_current=3.0 already).
- [x] Read `runs/_loop/seed.md` end-to-end (priority order; klaus-bch-leak priority 3 active).
- [x] Read `runs/_loop/director/turn_58.md` end-to-end (T58 dispatch + critic invocation rationale).
- [x] Read `runs/_loop/critic/turn_58.md` end-to-end (VERDICT=CORROBORATE-WITH-ERRATA, 3 errata, 7 confounder verdicts).
- [x] Read `runs/_loop/judge/turn_58_critic_audit.md` filename via Glob (judge wrote a different file shape this time; T58 was judged CRITIC_PASS per state.json line 1370).
- [x] Read memory `option_gamma_rotating_basis.md` lines 1-80 (line 37 load-bearing claim; existing structure to append verification section after).
- [x] Verified template directory contents via Glob (memory dir; barnett_mechanism_confirmed.md status TBD by implementer at dispatch time).
- [x] investigation_id `klaus-magnetostir-bch-leak-2026-05-13` valid in state.json investigations dict (lines 1513-1540).
- [x] stage_advancing_to `Document` is the §F1 next stage after Update.
- [x] subagent_type `implementer_text` matches §F1 role_per_stage[Document] = implementer_text.
- [x] success_criteria 21 criteria, all machine-evaluable (==, ==true/false, == numeric values).
- [x] failure_modes cover 8 outcomes (operational, scope_violation, scope_creep) — no scientific_refuted (Document does not produce a scientific verdict).
- [x] observable_manifest precondition_check verifies 9 paths exist.
- [x] budget 1.1M expected, 2M tolerance; wall 480s expected, 720s hard cap.
- [x] §A6 research-first citation present (13 references: T28+T29 barnett precedent, T58 critic §3+§6, T56+T57+T55 verification chain, T10 original BCH, memory line 37, feedback files, Anthropic patterns, Reflexion, Grounded autonomous research, Director.md §H worked example).
- [x] §A5 D1-justified: terminal closure of D1 verification investigation at Tier 3. Project's 2nd Tier-3 claim — materially advances the D1 axis (the project's biggest blank space per anko seed.md D1 articulation).
- [x] Considered alternative dispatches:
  - Skip Document, route directly to next investigation: rejected — leaves verify-claim arc structurally incomplete; 3 errata would not propagate to memory; future readers re-litigate.
  - Switch to meta-stage-routing terminal close: rejected — defer to T60 once klaus-bch-leak Document closes; cleaner sequencing.
  - Switch to yan-li-saito R4: rejected — dormant tier 0.4, not anko-prioritized.
  - Switch to audit-class-scan T62: rejected — gap=9, below ~10-turn cadence trigger; defer to T62.
  - Add manuscript polish to Document: rejected per `feedback_manuscript_is_not_the_essence` — memory entry only.
  - **klaus-bch-leak Document is highest leverage**: locks in Tier-3 promotion record + propagates 3 errata to memory; one cheap dispatch.
- [x] All file paths in brief are absolute.
- [x] Brief explicitly forbids src/ touch, julia execution, additional script creation, fabrication of numbers or citations.
- [x] sim/turn_59.md §4 Metrics JSON block requirement specified with exact 21-field list.
- [x] No conventional commits drafted this turn (loop auto-commit handles it post-judge).
- [x] T60 routing pre-planned: PASS → meta-stage-routing terminal close OR audit-class-scan T62 OR (defer) yan-li-saito R4; FAIL → operational re-route per failure_modes table.
- [x] §F1 Document stage role correctly assigned to implementer_text per workload-class match.
- [x] No meta-meta investigation spawned (physics-class investigation closure).
- [x] Per `feedback_decision_style`: single commitment per turn = one implementer_text dispatch with 4 specific artifacts.
- [x] Per `feedback_mathematical_elegance_bias`: 3 independent errata get 3 separate propagations; no unified reformulation.
- [x] Per `feedback_mechanical_vs_investigation_threshold`: Document is mechanical bookkeeping; explicitly NOT an investigation. Single dispatch.
- [x] Per `feedback_fix_the_class_not_the_instance`: the Y4-analytical-gap (E1) is propagated to memory at class level — future rotating_basis verifications inherit the caveat without re-discovering it.
- [x] Per `feedback_no_improvised_terminology`: brief uses established terms (CORROBORATE-WITH-ERRATA, errata, Tier 3, verify-claim flow) — no coined metaphors.
- [x] Per `feedback_manuscript_is_not_the_essence`: Document scope = memory + state + by_tag. Zero manuscript paragraphs.
- [x] Per Director.md §H worked example: barnett T29 Document is the precise template; matches budget (~1.5M T29 vs 1.1M expected T59 — T59 is lighter since errata payload is simpler), structure (memory entry + by_tag append + state closure).
- [x] Drift advisories: AUDIT_DUE gap=9 (still below 10-turn trigger); no DRIFT_COST_INFLATION expected this turn.
