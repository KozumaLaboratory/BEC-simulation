---
turn: 83
subagent: director
investigation_id: edh-eu151-vortex-vs-matsui-science-2026
stage_advancing_from: Analyze (T82 PASS contract; scientific verdict OPERATIONAL_GATE on F3 + NOT_APPLICABLE_NO_RING on F1/F2)
stage_advancing_to: Update (critic deep-audit: F3 energy-convention discrepancy + F1 dynamics-too-short interpretation + framework-vs-prediction triage)
topic_tags: [d1-verification-depth, edh-eu151-matsui-science-2026, tier3-pipeline, update-stage-critic-independent-eval, f3-operational-gate-energy-convention-audit, f1-not-applicable-dynamics-time-too-short, total-energy-extensive-vs-intensive, zeeman-convention-reconciliation]
paper_section: null
depends_on: [82, 81, 80, 72, "runs/_loop/director/turn_82.md", "runs/_loop/sim/turn_82.md", "runs/_loop/judge/turn_82.json", "runs/_loop/theorist/turn_72.md", "runs/_loop/_local/scheduler_83.json", "runs/_loop/state.json", "scripts/diagnostic/matsui_edh_t82_analyze.jl", "src/analysis/energy.jl", "memory:tier3_pipeline_survey_2026_05_18", "memory:bug_4_itp_ddi_half_rate", "memory:full_bdg_F6_polar_broken", "memory:feedback_mathematical_elegance_bias"]
produces: "critic Update verdict on T82 OPERATIONAL_GATE: (i) audit src/analysis/energy.jl total_energy() convention (extensive vs intensive; Zeeman inclusion) against T81 reported gs_energy_final=-967.027; (ii) audit T72 §5.3 TF formula derivation/applicability at N=30000, omega_ref=2π·100Hz isotropic; (iii) classify F3 verdict in {CORROBORATE-after-convention-fix, INCONCLUSIVE-theory-needs-refinement, REFUTED-framework-bug, REFUTED-prediction-bug}; (iv) ratify or revise F1 NOT_APPLICABLE_NO_RING classification (recommend longer-dynamics rerun or accept partial-tier closure); (v) emit independent next-action pointer for T84."
---

# Turn 83 — Director Report

## 1. Investigation state snapshot

- **Active investigation** (`state.active_investigation_id` line 1359): `edh-eu151-vortex-vs-matsui-science-2026`.
  - `current_stage = "Update (T83 critic independent eval of F1/F2/F3 verdicts; CORROBORATE-path tier 2.5 → 2.75; closure at T84 Document)"` (state.json line 1946 — set by T82 judge from the success-path action; the success-path advance was correct for "contract PASS" but the actual scientific verdict OPERATIONAL_GATE requires a different sub-branch of Update — critic audit, not Document).
  - `tier_current = 2.5` (state.json line 1997 — auto-bumped by judge on contract PASS; this is OPTIMISTIC since the scientific result is not actually CORROBORATE. T83 critic Update will revise.)
  - `tier_target = 3`, `priority = 1`, `kind = physics`, `flow_template = verify-claim`, `blocked_on = null`.
  - 4 falsifiers declared; F1+F2+F3 tested at T82 (but F1/F2 = NOT_APPLICABLE; F3 = OPERATIONAL_GATE); F4 (c_dd=0 control) untested-optional.
  - `stages_done` includes both "Analyze" (T76 ghost) and "Analyze (F1+F2+F3 …)" (T82 explicit) — minor judge-side dedup artifact, doesn't affect routing.

- **T82 PASS** (judge/turn_82.json — read in full):
  - All 8 success_criteria PASS at contract level. `status: "PASS"`.
  - BUT the canonical metric `falsification_result = "OPERATIONAL_GATE"` (line 168) is the controlling SCIENTIFIC verdict. F1 = NOT_APPLICABLE_NO_RING (line 39), F2 = NOT_APPLICABLE_NO_RING (line 139), F3 = OPERATIONAL_GATE (line 144). The contract was designed to pass on "decisive classification" — and OPERATIONAL_GATE IS a decisive classification — but it routes to a different next-action branch.
  - Key numerics: e_sim/atom = -0.0322 ℏω_ref/atom (line 140); e_mf/atom T72 prediction = +10.5 ℏω_ref/atom (line 141); rel_error = 1.00307 (~100.3%, just above the >100% OPERATIONAL_GATE threshold per T72 §5.5).
  - pop_c12 grew 4.78e-5 → 1.86e-3 (40×) over 10 ms — EdH instability is seeded but not at observable ring threshold (need ~1% per the implementer's added 1% pop guard; need ~50-160 ms physical for definitive ring per sim §6).
  - Cost: 2.016M effective vs 1.3M expected = 1.55× BUDGET_OVER (judge.cost_audit). Drift advisory `DRIFT_COST_INFLATION` re-triggered (cost_inflation = 1.08).
  - Implementer's own §8 (sim/turn_82.md lines 326-407) identifies the root-cause hypothesis explicitly: discrepancy may be "wavefunction normalization convention (`∫|ψ|² = 1` vs `∫|ψ|² = N`)" OR Zeeman double-counting OR T72 TF formula misapplication at marginal-TF parameters (`μ_TF/ℏω_ref = 12.6`). Recommends a decisive 1-line sanity check: non-interacting harmonic trap (c0=c1=c_dd=0, no Zeeman) should give `E_total = 1.5 ℏω_ref` if intensive, `1.5×N = 45000 ℏω_ref` if extensive.

- **T83 routing decision** (load-bearing):
  - Per §B3 verdict-router: T82 contract = PASS, but per T82's own `failure_modes` block: `if falsification_result == 'OPERATIONAL_GATE' OR f3_band == 'OPERATIONAL_GATE' → T83 director dispatches critic in deep-audit mode` (director/turn_82.md lines 277-280, item 5). T82 verdict matches → critic deep-audit is the explicitly pre-routed next action.
  - Per §F1 `verify-claim` template Analyze → **Update**. Update role = `critic` (mandatory, independent context). The Update stage in verify-claim is precisely for critic to evaluate the Analyze data → corroborate / refute / flag. OPERATIONAL_GATE is the "flag for triage" sub-branch.
  - **Why NOT theorist again**: T72 already derived the F3 prediction (E_mf/N = 10.5 ℏω_ref/atom). T80 already did src-anchored Bz-sign derivation. Theorist would re-derive what is on file. The question now is INDEPENDENT EVALUATION of: (a) is T72's derivation correct? (b) is the sim's reported energy correctly interpreted? Critic is the §F1 designated role.
  - **Why NOT implementer (yet)**: the decisive 1-line sanity check (non-interacting trap GS energy) requires Julia execution, but critic's first job is to triage: does the discrepancy arise from `total_energy()` reporting convention (Read-only audit of src/analysis/energy.jl is sufficient), from Zeeman double-counting (Read-only audit of propagators.jl + energy.jl), or from T72 TF derivation (algebraic re-check). Only if the critic concludes "needs empirical test" does T84 dispatch implementer_julia_cpu_light for the sanity check. Critic-first preserves the F1 flow-template order and is cheaper.
  - **Why NOT switch investigations**: EdH = priority 1; all others priority 10-99. The OPERATIONAL_GATE is the highest-leverage diagnostic surface in the project — it either (a) reveals a documentation bug in T72 (likely; 32,580× extensive-vs-intensive mismatch suggests T72 forgot the N factor), (b) reveals a real wiring bug in `total_energy()`, OR (c) reveals an interpretation issue. All three are decisive scientific findings.
  - **Why NOT noop**: data is on disk, T82 implementer already flagged the decisive test, critic input is clear. Noop wastes the highest-leverage diagnostic moment.
  - **Why NOT advance to Document (CORROBORATE-path)**: state.json's auto-set `current_stage` says "CORROBORATE-path tier 2.5 → 2.75" but that branch presupposes ALL_CORROBORATE, which T82 didn't yield. Document would falsely close on OPERATIONAL_GATE. Critic-first is mandatory.

- **Scheduler** (scheduler_83.json, read this turn):
  - `policy = JULIA_GPU_OK` (probe-authoritative; window 2026-05-15T22:00 → 2026-05-31T23:59 JST, 1,149,440 sec left = 13.3 days).
  - All 11 workloads allowed including `critic` (line 17).
  - Probe: VRAM free 12,705 MB, RAM 25.06 GB, GPU util 1%, foreign_julia=0. Critic is text-only Read; no resource pressure.

- **Drift escalation** = `director_must_address` (state.history T82 line 1333):
  - `DRIFT_MANUSCRIPT_DELTA_ZERO`: advisory only per `feedback_manuscript_is_not_the_essence`. T83 does not address (correct).
  - `DRIFT_COST_INFLATION` (cost_inflation = 1.08): T82 came in at 2.016M (expected 1.3M, 55% over). T83 critic baseline is ~1.3M (text-only Read); if T83 lands at ≤1.5M cost_inflation drops below 1.0. Addressed by routing to critic (text-only, no Julia).
  - `AUDIT_DUE: patterns.yaml gap=19`: still deferred under priority-1 EdH advancement. EdH OPERATIONAL_GATE diagnosis is 1-3 turns; audit-scan defers to T86+ steady-state.

- **Other in-flight investigations** (priority-ordered, unchanged from T82):
  | id | priority | tier | stage | status |
  |---|---|---|---|---|
  | **edh-eu151-vortex-vs-matsui-science-2026** | **1** | **2.5/3** | **Update (T83 critic deep-audit on OPERATIONAL_GATE)** | active |
  | barnett-mechanism-2026-05-16 | 1 | 3.0/3 | closed | done |
  | klaus-magnetostir-bch-leak-2026-05-13 | 3 | 3.0/3 | closed | done |
  | audit-due-heuristic-bug-2026-05-18 | 4 | 2.0/2 | closed | done |
  | meta-internal-b-unification-2026-05-18 | 5 | 1.0/1 | closed | done |
  | tier3-verification-pipeline-survey-2026-05-18 | 10 | 1/1 | Document (deferred) | T70 done |
  | meta-cost-waste-audit-2026-05-18 | 15 | 0/1 | Observe (auto-spawn) | deferred to post-EdH |
  | meta-director-self-audit-2026-05-18 | 20 | 0/1 | Observe (auto-spawn) | deferred to post-EdH |
  | meta-cost-inflation-2026-05-18 | 40 | 0/1 | Observe (auto-spawn) | deferred to post-EdH |
  | fullbdg-f6-polar-3000x | 99 | 1.5/2 | dormant (anko-contained) | — |

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T80 | Execute (Bz-sign non-Julia leverage path) | PASS (1.893M, BUDGET_OVER 1.46×) | theorist: src-anchored H_Zee = -p·m_F, p_dimless=-162.78, m_F=-6 minimum at Bz<0; predicted PASS for GS landing at m_F=-6. Closed Bz-sign confounder. |
| T81 | Execute (R2 GPU retry via wrapper script) | PASS (1.879M, BUDGET_OK 0.75×) | implementer_julia_gpu: GS converged at pop[c=13]=0.9999, Mz=-6.0, gs_energy_final=-967.027; dynamics 12 snapshots over 10 ms, norm_drift=6.7e-13, pop_c12 grew 40× to 1.86e-3. PASS_PREDICTION_CONFIRMED. |
| T82 | Analyze (jld2 extraction + F1/F2/F3 classification) | PASS contract / OPERATIONAL_GATE science (2.016M, BUDGET_OVER 1.55×) | implementer_julia_cpu_light: scripts/diagnostic/matsui_edh_t82_analyze.jl (commit a9976a4); F1 NOT_APPLICABLE_NO_RING (pop_c12 < 0.2% at all 12 frames; dynamics too short for definitive ring); F2 NOT_APPLICABLE (depends F1); F3 OPERATIONAL_GATE (e_sim/atom=-0.0322 vs T72 pred +10.5/atom, 100.3% deviation; sim's §8 identifies extensive-vs-intensive normalization as primary suspect, recommends 1-line non-interacting trap sanity check). |
| T83 (THIS) | Update (critic deep-audit on OPERATIONAL_GATE) | (TBD) | critic: independent eval. (a) Read src/analysis/energy.jl + propagators.jl + verify Zeeman convention; (b) re-derive T72 §5.3 E_mf/N from scratch independently and compare to T72's +10.5 value; (c) classify F3 root cause in {documentation-bug-in-T72, wiring-bug-in-energy.jl, normalization-mismatch, theory-misapplied-at-N=30000}; (d) ratify or revise F1 NOT_APPLICABLE classification + recommend longer-dynamics rerun if needed; (e) emit T84 next-action pointer. NO Julia execution. |

## 3. Flow template recall

- **Template**: `verify-claim` (§F1). Sequence: Research → Hypothesize → Design → Execute → Analyze → **Update** → Document → closed.
- **Stage advance per §B3 verdict-routing**: T82 contract = PASS (decisive classification produced) → advance to next-in-template = Update. Per §F1 "REFUTED in Update DOES NOT mean investigation failed — it means we learned a hypothesis is wrong" — analogous for OPERATIONAL_GATE: it's a decisive triage outcome that the critic must evaluate, not a failure to advance.
- **Role for Update (§F1 row)**: `critic` (mandatory, independent context). Workload class `critic` is in scheduler.allowed_workloads (line 17).
- **Why this stage now**:
  - Analyze produced the data + the implementer's own §8 root-cause hypothesis. Update is the canonical next stage where an INDEPENDENT critic eval against that data is the §F1 mandatory step.
  - Per §F1 row Update: "if REFUTED, hypothesis revised + tier-- or tier_target--; if CONFIRMED, tier++". OPERATIONAL_GATE is a third sub-branch — the critic resolves which of {framework-bug, theory-bug, convention-mismatch} applies, which then determines tier movement (REFUTED-framework → tier 0.5; CORROBORATE-after-convention-fix → tier 2.75).
  - Per Section G "LATS" pattern: Analyze = experiment-output node; Update (critic) = Reflect+Backprop step. T82 is the experiment node; T83 critic IS the Reflect step.
  - Per Section G "Anthropic Effective Harnesses": T72 = Initializer (durable falsifier bands); T82 = Coder Analyze; T83 critic = independent Auditor (the critic-as-3rd-party that the harness pattern emphasizes for high-stakes verdicts).
  - Per `feedback_mathematical_elegance_bias` (memory): "N independent issues → N simple fixes, not 1 unifying reformulation." The OPERATIONAL_GATE may be a SINGLE simple cause (T72 forgot the N factor in extensive energy → e_mf needs to be 10.5/30000 = 3.5e-4 ℏω_ref/atom, agreeing with sim's +3.22e-4) rather than a unifying reformulation of the energy convention. Critic should look for this elegant simple resolution FIRST before invoking framework bugs.
- **Why NOT skip to Document**: state.json auto-set Document as the CORROBORATE-path branch; critic must first resolve OPERATIONAL_GATE → CORROBORATE or REFUTED before Document is legitimate.
- **Why NOT repeat Analyze**: extraction already done; the issue is interpretation. Critic Audit > Analyze Refinement.
- **Why NOT switch investigations**: EdH priority 1; the operational gate is the highest-leverage diagnostic in the project.

## 4. Research grounding (§A6)

T83 dispatch citations (≥1 external reference per §A6):

1. **T82 sim §8 (sim/turn_82.md lines 326-407)** — implementer's own root-cause hypothesis enumeration. Item 3 explicitly: "**The T72 formula uses physical energies (extensive) not normalized to 1**: T72's `E_mf/N = 10.5 ℏω_ref/atom` means the TOTAL extensive non-Zeeman energy is `N × 10.5 = 315,000 ℏω_ref`. The simulation's non-Zeeman total is only `+9.67 ℏω_ref`. This is 32,580× smaller." This is the EXACT clue: 30000 × 32,580 ≠ 1 (it's about 1e9), so it's NOT a single-factor-of-N mismatch in the extensive direction. BUT note 30000 / 9.67 ≈ 3100 ≠ 32580; the arithmetic in T82 §8 has an algebraic slip the critic should catch and re-derive carefully. The actual ratio 10.5 / 3.22e-4 = 32,580 ≈ N × something. Critic should resolve this with rigorous re-derivation.

2. **T72 §5.3 (theorist/turn_72.md lines 370-382)** — the load-bearing derivation: "Zero-point: (3/2)ℏω_ref = ... = 150 Hz·h. Contact-TF: μ_TF = 12.6·ℏω_ref = 8.35e-31 J. E_contact/N = (5/7)·8.35e-31 = 5.96e-31 J/atom = 900 Hz·h. ... Total E_mf/N ≈ 6.96e-31 J/atom ≈ 1050 Hz·h ≈ 10.5 ℏω_ref in dimensionless units." Critic must independently re-derive each line. Particular suspects: (a) is μ_TF = 12.6·ℏω_ref correct for N=30000, c0+36c1, isotropic box=12, ω_ref=2π·100Hz? (b) is the (5/7)μ_TF Thomas-Fermi formula valid at μ_TF/ℏω_ref ~ 12.6 (marginal TF)? (c) is the unit conversion 1050 Hz·h / (ℏω_ref) where ω_ref = 2π·100 Hz = 1050 / 100 = 10.5 correct?

3. **CLAUDE.md §Conventions** — "ITP Zeeman shift subtracts min(E_m) to prevent overflow." Critic must confirm whether `total_energy()` in `src/analysis/energy.jl` includes or excludes this shift. The T82 §8 (lines 343-348) claims the shift does NOT propagate to total_energy — critic must VERIFY this by reading the source.

4. **`src/analysis/energy.jl`** — the load-bearing source. Critic reads `total_energy()` definition + its sub-functions (`zeeman_energy`, `kinetic_energy`, `interaction_energy`, etc.) to determine: (a) extensive vs intensive convention; (b) Zeeman handling; (c) what's included in the sum.

5. **`src/hamiltonian/integrator/propagators.jl` line 65 (per T82 §8)** — claimed location of the ITP min(E_m) subtraction in propagator exponent. Critic verifies the line number + the convention.

6. **Memory `bug_4_itp_ddi_half_rate`** — bug fixed 2026-05-02; T81 GS used post-fix code (commit chain through 2433e32 on main). Critic confirms no contamination — relevant because Bug-4 affected ITP energies by ~7% historically.

7. **Memory `full_bdg_F6_polar_broken`** — analogous case where "ψ converges to same minimum as `:scalar` but reported energy off by ~3000×". A different bug (LHY-related), but the SHAPE of the discrepancy (numerically convergent state + report-scale wrong) is similar to what T82 §8 §5 hypothesizes. Critic should treat this as analogue prior — "energy reporting can be wrong by large factors at the right combination of options" is an observed class.

8. **Memory `feedback_mathematical_elegance_bias`** (anko 2026-05-15) — "N independent issues → N simple fixes, not 1 unifying reformulation." Critic should first check the simplest explanation: did T72 §5.3 forget a factor of N, or use a confusing convention where the "/N" was already taken out? Independently re-deriving the dimensional analysis line-by-line is the elegant test.

9. **Memory `tier3_pipeline_survey_2026_05_18`** — investigation lineage; F3 is the third leg of the Tier-3 verification triangle. OPERATIONAL_GATE resolution determines whether this investigation advances or recedes.

10. **AI Scientist v2 / LATS pattern (Section G)** — critic-as-Reflect is the canonical place to catch derivation-stage errors that the proposing theorist missed because of confirmation bias. T80 theorist self-derived Bz; T72 theorist self-derived E_mf; independent critic re-derivation is the institutional safeguard.

11. **Anthropic Effective Harnesses (Section G)** — Critic in the Effective Harness pattern is the Auditor; specifically tasked with independent re-derivation against the same data, NOT incremental refinement of the original derivation.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verification axis — primary)**. T83 closes the loop on the experimental-vs-theoretical comparison for F3. Critic Update is the canonical step that determines whether the framework reproduces Matsui's prediction (CORROBORATE), refutes it (REFUTED), or reveals a documentation/convention issue (third option). Manuscript NOT in scope.

- **Tier ladder position**: EdH `tier_current = 2.5` (auto-bumped by judge on T82 contract PASS, but optimistic since scientific verdict is OPERATIONAL_GATE). T83 outcomes:
  - **Critic CORROBORATE-after-convention-fix (e.g., T72 forgot ÷N → e_mf/atom is really 3.5e-4 not 10.5, agreeing with sim +3.22e-4 within ~10%)**: tier advances to **2.75**. T84 implementer_text Document with errata to T72 + memory entry + tier closure at 3.0 in T85. Pipeline T83→T85 = 3 turns to Tier 3.0 (still on track for project's 3rd Tier-3 claim).
  - **Critic CORROBORATE-after-running-sanity-check (i.e., critic recommends T84 implementer_julia_cpu_light non-interacting trap GS to empirically determine extensive vs intensive)**: tier holds at **2.5**. T84 sanity check → T85 critic re-eval → T86 Document. Pipeline T83→T86 = 4 turns to Tier 3.0.
  - **Critic INCONCLUSIVE (TF formula misapplied at marginal-TF parameters, needs Bogoliubov correction)**: tier drops to **2.25**. T84 theorist refines T72 §5.3 with full GP integration → T85 critic re-evaluate → T86 Document. Pipeline T83→T86 = 4 turns to Tier 3.0.
  - **Critic REFUTED-framework-bug (e.g., total_energy() has a real wiring bug)**: tier drops to **1.0**. Spawn fix-bug child investigation (very large prior, given T82 §8 documented framework analogue `full_bdg_F6_polar_broken`).
  - **Critic REFUTED-theory-bug (T72 §5.3 fundamentally wrong derivation, not just convention)**: tier drops to **1.5**. T84 theorist re-derive from scratch.
  - **Critic-side-recommendation: longer-dynamics rerun for F1** (orthogonal to F3 issue): T84 dispatches implementer_julia_gpu rerun with duration 30-50 dimless (~50-80 ms physical). Cost ~2-3M. Independent of F3 path.

- **Cost trend** (last 8 turns): T75=1.866M, T76=3.056M, T77=1.563M, T78=1.430M, T79=1.729M, T80=1.893M, T81=1.879M, T82=2.016M. **T83 forecast = 1.0-1.5M** (critic text-only Read of src/analysis/energy.jl + propagators.jl + T72 + T82 metrics + independent re-derivation). Hard cap: 1.7M. cost_inflation drops below 1.0 if T83 lands at ≤1.4M.

- **DRIFT trajectory after T83 (anticipated)**:
  - subagent_repetition: T79 implementer_julia_gpu → T80 theorist → T81 implementer_julia_gpu → T82 implementer_julia_cpu_light → T83 critic = 5 distinct subagent classes. Stays at 0.2.
  - cost_inflation: 1.08 → expected drop to 0.7-0.85 if T83 critic lands at 1.0-1.4M.
  - code_delta_zero: T83 critic produces only critic/turn_83.md (no src commits). May stay at 0 unless critic recommends an immediate src docstring fix.
  - manuscript_delta_zero: holds at 1.0 correctly.
  - novel_claim_zero: 0.0 (T83 cites T72/T82/src verbatim).
  - topic_repetition: T82 was 0.125 (low, EdH advances correctly). T83 stays in 0.1-0.2 range.

- **Recommended T84+ trajectory** (informational, depends on T83 outcome):
  - **T84 if T83 CORROBORATE-after-convention-fix**: implementer_text Document — memory entry `edh_matsui_baseline_2026.md` + T72 §5.3 errata addendum + state.json tier closure at 3.0. Pipeline T83→T84 = 2 turns to Tier 3.0 (best case).
  - **T84 if T83 needs empirical sanity-check**: implementer_julia_cpu_light runs `non_interacting_trap_gs_sanity.jl` (Read existing infrastructure: bare HarmonicOscillator + ITP, expect E_total = 1.5 ℏω_ref per atom × N_atoms = 45000 if extensive, OR 1.5 if intensive). Critic re-eval at T85 → Document T86.
  - **T84 if T83 INCONCLUSIVE on T72 derivation**: theorist refines T72 §5.3 with full GP-Bogoliubov treatment (Refine sub-step in §F1 build-theory shape, but happening inside verify-claim flow).
  - **T84 if T83 REFUTED-framework**: spawn `edh-energy-reporting-bug-2026-05-18` fix-bug child investigation.
  - **Parallel option (F1)**: regardless of F3 path, the F1 NOT_APPLICABLE may want a longer-dynamics rerun (50-80 ms physical, ~3M GPU cost). Defer until F3 resolved.

- **Manuscript NOT in scope.** T83 produces critic/turn_83.md only. No by_tag/manuscript edits.

## 6. Dispatch decision (declarative contract)

```json
{
 "investigation_id": "edh-eu151-vortex-vs-matsui-science-2026",
 "stage_advancing_to": "Update (critic deep-audit on T82 OPERATIONAL_GATE; independent re-derivation of T72 §5.3 + src-anchored audit of src/analysis/energy.jl + Zeeman convention reconciliation + F1 NOT_APPLICABLE classification ratification)",
 "subagent_type": "critic",
 "researcher_depth": null,
 "parallel_researcher_count": 0,
 "rationale": "T82 contract PASS but scientific verdict OPERATIONAL_GATE (F3: e_sim/atom=-0.032 vs T72 pred +10.5, 100.3% deviation; F1+F2 NOT_APPLICABLE due to dynamics-too-short). Per §F1 verify-claim template Analyze → Update; per T82's own failure_modes block item 5 (OPERATIONAL_GATE → 'critic deep-audit mode'); per Section G LATS pattern Reflect step. T82 implementer's own §8 root-cause enumeration provides the critic's starting point: 5 candidate explanations including extensive-vs-intensive normalization mismatch (the elegant explanation). Critic text-only Read of src/analysis/energy.jl + propagators.jl + T72 + T82 + independent re-derivation. NO Julia execution. ~1.0-1.4M cost. Decisive: outputs CORROBORATE-after-convention-fix / INCONCLUSIVE / REFUTED-framework / REFUTED-theory, each routing T84.",
 "brief": "ROLE: critic (Update stage; mandatory independent-context audit per §F1 verify-claim flow template). Adversarially audit T82's OPERATIONAL_GATE classification on F3 and the F1 NOT_APPLICABLE_NO_RING classification. Output an INDEPENDENT verdict.\n\nDIRECTIVE_LABEL: edh-matsui-update-T83-critic-operational-gate-deep-audit\n\n=== HARD CONSTRAINT: NO JULIA EXECUTION ===\n\nThis is a critic text-only audit. Allowed tools: Read, Grep, Glob. NO Bash invocation of julia. NO Write to anything except runs/_loop/critic/turn_83.md. NO src/ edits. If you conclude a Julia sanity check is needed (e.g., non-interacting trap GS energy to resolve extensive-vs-intensive), DO NOT run it — instead recommend it as T84 next action in your verdict.\n\n=== CONTEXT (must read in order) ===\n\n1. `runs/_loop/director/turn_83.md` (this file) §1, §3, §4, §5.\n2. `runs/_loop/judge/turn_82.json` — all metrics including the 12-frame per-frame summary + f3_zeeman_reconciliation_note (a long string with the implementer's own decomposition).\n3. `runs/_loop/sim/turn_82.md` §4 (Metrics JSON), §6 (F1 ring-detection per-frame analysis with 1%-population guard rationale), §7 (F2 NA), §8 (F3 ZEEMAN CONVENTION RECONCILIATION — the load-bearing section; specifically the 5 hypothesized root causes and the 'Decisive test for T83' subsection lines 400-407), §9 (issues; pop_threshold=1% added; not in T72 §6.2 — needs critic ratification).\n4. `runs/_loop/theorist/turn_72.md` §5.3 (lines 370-382 — the E_mf/N = 10.5 ℏω_ref/atom derivation; trace each line). Also §5.1 (the constraint c_0 + 36 c_1 = 4π(a_s/a_ho)N — interaction parameter convention). Also §5.5 (the OPERATIONAL_GATE band definition).\n5. `src/analysis/energy.jl` — read `total_energy()` definition + all sub-functions. Determine: (a) what is the convention — is it the sum of terms each with `∫|ψ|² dV`-weighted integrand, with ψ unit-normalized? (b) is the Zeeman contribution included? (c) is the result extensive (per total atom number) or intensive (per atom)?\n6. `src/hamiltonian/integrator/propagators.jl` around line 65 — verify the ITP `_outer_potential_fwd!` claim from T82 §8 that the min(E_m) subtraction is in the propagator exponent only, not in `total_energy`.\n7. `CLAUDE.md` §Conventions — 'ITP Zeeman shift subtracts min(E_m) to prevent overflow' — verify this is consistent with what you find in src.\n8. `runs/matsui_edh_baseline_9ca97308/config.yaml` — confirm N=30000, ω_ref convention, c1_ratio, c_dd value, grid=32³ box=12 (T81 §1).\n9. Memory: `tier3_pipeline_survey_2026_05_18.md`, `bug_4_itp_ddi_half_rate.md`, `full_bdg_F6_polar_broken.md` (analogue prior for energy-report-wrong-by-large-factor class).\n\n=== AUDIT TASKS (mandatory; all five must appear in your verdict) ===\n\n**Task A — Independent re-derivation of T72 §5.3 E_mf/N at Case A.**\n\nDo NOT trust T72's numerical values. Re-derive from scratch:\n- Case A parameters: N=30000, ω_ref=2π·100Hz isotropic, a_s=110 a_B (CLAUDE.md §¹⁵¹Eu), c_dd computed from μ_Eu=6.977μ_B.\n- Compute a_ho = sqrt(ℏ/(m·ω_ref)) for Eu-151. Express in SI.\n- Compute the TF chemical potential: μ_TF = (1/2) ℏω_ref · (15 N a_s / a_ho)^(2/5).\n- Compute E_mf/N in BOTH conventions: (a) per-atom intensive E/N in J/atom, then converted to ℏω_ref-per-atom (T72's stated convention); (b) total extensive E in J then in ℏω_ref-total (the sim's likely convention since sim reports -967.027 as a single scalar).\n- Resolve: does T72's '10.5 ℏω_ref in dimensionless units' mean (10.5 ℏω_ref total) OR (10.5 ℏω_ref per atom)?\n\n**Task B — Read src/analysis/energy.jl and determine the actual convention.**\n\nGrep for `total_energy`, `zeeman_energy`, `kinetic_energy`, `dipole_energy`, `lhy_energy`. For each component:\n- Is the integral over `∫|ψ(x)|² ...` where ψ is normalized to 1 or to N?\n- Is the final return value extensive (J or ℏω_ref total) or intensive (per atom)?\n- Does Zeeman include the min(E_m) shift?\n\nThe definitive answer comes from src; do not infer from documentation alone.\n\n**Task C — Reconcile sim vs theory after convention is fixed.**\n\nGiven sim reports gs_energy_final = -967.027 (units = ?), and your Task A and Task B results:\n- Map sim's value into the same convention as T72's prediction.\n- Compute the (corrected) relative error |E_sim - E_mf|/|E_mf|.\n- Classify F3 in {CORROBORATE-after-convention-fix, INCONCLUSIVE, REFUTED-framework, REFUTED-theory}.\n\n**Task D — Ratify or revise F1 NOT_APPLICABLE_NO_RING.**\n\nT82 implementer added a `pop_c12 >= 0.01` (1%) population guard that is not in T72 §6.2. Audit:\n- Is the 1% guard physically justified? (Sub-percent ring is observationally meaningless?)\n- Is T82's classification of NOT_APPLICABLE_NO_RING correct, or should it be INCONCLUSIVE (T72's bands had no NA option)?\n- Recommend: should T84 dispatch implementer_julia_gpu for a longer-dynamics rerun (e.g., 30-50 dimless = 50-80 ms physical) to definitively test F1? Estimate cost (likely ~3M GPU). Provide a clear yes/no recommendation with reasoning.\n\n**Task E — Independent next-action pointer for T84.**\n\nProvide a single explicit recommendation in your `next_action_for_t84` field:\n- If F3 resolves CORROBORATE after convention fix: 'T84 implementer_text Document with T72 §5.3 errata; tier 2.75 → 3.0'.\n- If F3 needs empirical sanity check: 'T84 implementer_julia_cpu_light non-interacting trap GS sanity (expect E_total = 1.5 ℏω_ref per atom OR 45000 total depending on convention); 30 lines Julia, <1 min wall'.\n- If F3 INCONCLUSIVE: 'T84 theorist refines T72 §5.3 with explicit dimensional check'.\n- If F3 REFUTED-framework: 'T84 director spawns child fix-bug investigation `edh-energy-reporting-bug-2026-05-18` for src/analysis/energy.jl'.\n- F1 parallel recommendation: 'separately, T85+ may dispatch implementer_julia_gpu for 50-ms dynamics rerun OR document F1 as inconclusive at current duration'.\n\n=== OUTPUT FORMAT ===\n\nWrite `runs/_loop/critic/turn_83.md` with the following sections:\n\n```markdown\n---\nturn: 83\nsubagent: critic\ndirective_action: critic_audit\ndirective_label: edh-matsui-update-T83-critic-operational-gate-deep-audit\ninvestigation_id: edh-eu151-vortex-vs-matsui-science-2026\ntopic_tags: [d1-verification-depth, edh-eu151-matsui-science-2026, update-stage, critic-independent-audit, f3-operational-gate-resolution, energy-convention-extensive-vs-intensive, zeeman-shift-handling]\ndepends_on: [82, 81, 80, 72, director/turn_83, sim/turn_82, theorist/turn_72]\nproduces: \"INDEPENDENT verdict on F3 OPERATIONAL_GATE + F1 NOT_APPLICABLE: classification (CORROBORATE-after-convention-fix / INCONCLUSIVE / REFUTED-framework / REFUTED-theory) + next-action pointer for T84\"\n---\n\n# Turn 83 — Critic Update: EdH-Matsui F3 OPERATIONAL_GATE Deep Audit\n\n## 1. Verdict-up-front\n\n(One paragraph: classification + rationale + T84 recommendation.)\n\n## 2. Task A — Independent re-derivation of T72 §5.3 E_mf/N\n\n(Show all algebra: a_ho computation, μ_TF formula, E_mf/N in BOTH conventions.)\n\n## 3. Task B — src/analysis/energy.jl convention audit\n\n(Cite specific line numbers from src. Definitive answer on extensive vs intensive + Zeeman.)\n\n## 4. Task C — Sim vs theory reconciliation\n\n(Map sim into T72 convention. Compute corrected rel_error. Classify F3.)\n\n## 5. Task D — F1 NOT_APPLICABLE ratification\n\n(Justify or revise. Recommend longer-dynamics rerun yes/no with cost estimate.)\n\n## 6. Task E — T84 next-action pointer\n\n(Single explicit pointer; routable by T84 director.)\n\n## 7. Errata (if any) to T72, T80, T82 derivations or claims\n\n(Each erratum: location + correction + impact.)\n\n## 8. Independent references cited\n\n(Papers / src files / memory; ≥3 references beyond the ones the director listed.)\n\n## 9. Metrics block (judge.py reads this)\n\n```json\n{\n  \"experiment_kind\": \"critic_audit\",\n  \"workload_class\": \"critic\",\n  \"f3_critic_classification\": \"CORROBORATE_AFTER_CONVENTION_FIX\" | \"INCONCLUSIVE\" | \"REFUTED_FRAMEWORK\" | \"REFUTED_THEORY\",\n  \"f3_corrected_rel_error\": <float>,\n  \"f3_convention_resolved\": \"extensive\" | \"intensive\" | \"ambiguous\",\n  \"t72_section_5_3_correctness\": \"correct\" | \"errata\" | \"refuted\",\n  \"src_energy_jl_convention\": <string description>,\n  \"src_energy_jl_zeeman_inclusion\": <bool>,\n  \"f1_classification_ratified\": <bool>,\n  \"f1_pop_guard_1pct_justified\": <bool>,\n  \"f1_longer_dynamics_rerun_recommended\": <bool>,\n  \"f1_longer_dynamics_rerun_duration_dimless\": <float or null>,\n  \"f1_longer_dynamics_rerun_cost_estimate_M\": <float or null>,\n  \"next_action_for_t84\": <string; specific routable directive>,\n  \"tier_recommendation\": <float in {1.0, 1.5, 2.25, 2.5, 2.75}>,\n  \"verdict_token\": \"CORROBORATE_WITH_ERRATA\" | \"REFUTED\" | \"INCONCLUSIVE\" | \"CONFOUNDER_FOUND\",\n  \"errata_count\": <int>,\n  \"errata_load_bearing_count\": <int>,\n  \"errata_advisory_count\": <int>,\n  \"n_references_cited\": <int>,\n  \"derivation_lines_independent\": <int, count of lines you re-derived from scratch>\n}\n```\n\n## 10. Self-review checklist\n\n- [ ] Re-derived T72 §5.3 line-by-line from scratch (Task A)?\n- [ ] Read src/analysis/energy.jl with specific line citations (Task B)?\n- [ ] Reconciled sim vs theory with EXPLICIT convention map (Task C)?\n- [ ] Ratified or revised F1 NOT_APPLICABLE (Task D)?\n- [ ] Emitted concrete T84 pointer (Task E)?\n- [ ] No Julia execution attempted?\n- [ ] No src/ modifications?\n- [ ] Metrics block judge-machine-readable?\n```\n\n=== ANTI-PATTERN GUARDS ===\n\n- DO NOT defer to T72 or T82's derivations; INDEPENDENT re-derivation is the entire point.\n- DO NOT just say 'looks correct' on Task A without showing the algebra.\n- DO NOT propose 'split into two fix-bug investigations'; per `feedback_mathematical_elegance_bias`, look for the elegant single explanation first.\n- DO NOT invent new falsifiers; you are auditing the existing F1/F2/F3.\n- DO NOT exceed 1.7M effective cost; aim for 1.0-1.4M.\n- DO NOT use anko-attribution in critic/turn_83.md text.\n- DO NOT manuscript-polish; this is D1 verification.",
 "observable_manifest": {
 "required": [
 "f3_critic_classification",
 "f3_corrected_rel_error",
 "f3_convention_resolved",
 "t72_section_5_3_correctness",
 "src_energy_jl_convention",
 "f1_classification_ratified",
 "next_action_for_t84",
 "tier_recommendation",
 "verdict_token"
 ],
 "optional": [
 "src_energy_jl_zeeman_inclusion",
 "f1_pop_guard_1pct_justified",
 "f1_longer_dynamics_rerun_recommended",
 "f1_longer_dynamics_rerun_duration_dimless",
 "f1_longer_dynamics_rerun_cost_estimate_M",
 "errata_count",
 "errata_load_bearing_count",
 "errata_advisory_count",
 "n_references_cited",
 "derivation_lines_independent"
 ],
 "precondition_check": "cd /home/suzume/workspace/BEC-simulation && test -f runs/_loop/judge/turn_82.json && test -f runs/_loop/sim/turn_82.md && test -f runs/_loop/theorist/turn_72.md && test -f src/analysis/energy.jl && test -f src/hamiltonian/integrator/propagators.jl && test -f runs/matsui_edh_baseline_9ca97308/config.yaml && grep -q 'total_energy' src/analysis/energy.jl && echo OK_T83_critic_precondition: all source files + prior turn artifacts present + total_energy symbol grep hit"
 },
 "success_criteria": [
 {
 "id": "critic_verdict_decisive",
 "metric": "f3_critic_classification",
 "operator": "in",
 "value": ["CORROBORATE_AFTER_CONVENTION_FIX", "INCONCLUSIVE", "REFUTED_FRAMEWORK", "REFUTED_THEORY"],
 "tolerance": null,
 "rationale": "Critic MUST produce a decisive F3 classification; ambiguity defeats the Update purpose."
 },
 {
 "id": "convention_resolved",
 "metric": "f3_convention_resolved",
 "operator": "in",
 "value": ["extensive", "intensive", "ambiguous"],
 "tolerance": null,
 "rationale": "Critic MUST determine the convention used by src/analysis/energy.jl OR explicitly declare it remains ambiguous (requires empirical T84 test). Either is a valid outcome; silence is not."
 },
 {
 "id": "t72_audit_decisive",
 "metric": "t72_section_5_3_correctness",
 "operator": "in",
 "value": ["correct", "errata", "refuted"],
 "tolerance": null,
 "rationale": "Critic's audit of T72 §5.3 must terminate with one of three verdicts."
 },
 {
 "id": "src_audit_present",
 "metric": "src_energy_jl_convention",
 "operator": "!=",
 "value": "",
 "tolerance": null,
 "rationale": "Critic must read src/analysis/energy.jl and produce a non-empty convention description string."
 },
 {
 "id": "f1_ratified",
 "metric": "f1_classification_ratified",
 "operator": "in",
 "value": [true, false],
 "tolerance": null,
 "rationale": "Boolean ratification of T82's F1 NOT_APPLICABLE_NO_RING classification; either ratify or revise."
 },
 {
 "id": "next_action_specific",
 "metric": "next_action_for_t84",
 "operator": "!=",
 "value": "",
 "tolerance": null,
 "rationale": "T84 director needs a concrete routable pointer; empty string fails."
 },
 {
 "id": "tier_recommendation_valid",
 "metric": "tier_recommendation",
 "operator": "in",
 "value": [1.0, 1.5, 2.25, 2.5, 2.75],
 "tolerance": null,
 "rationale": "Tier recommendation must be one of the canonical advance/regress points; arbitrary floats are inadmissible."
 },
 {
 "id": "verdict_token_valid",
 "metric": "verdict_token",
 "operator": "in",
 "value": ["CORROBORATE_WITH_ERRATA", "REFUTED", "INCONCLUSIVE", "CONFOUNDER_FOUND"],
 "tolerance": null,
 "rationale": "Standard verdict token vocabulary."
 }
 ],
 "failure_modes": [
 {
 "if": "f3_critic_classification == 'CORROBORATE_AFTER_CONVENTION_FIX' AND verdict_token == 'CORROBORATE_WITH_ERRATA'",
 "category": "success (critic resolves OPERATIONAL_GATE; T72 needed an errata; framework is correct)",
 "next_action": "T84 director: dispatch implementer_text Document. Memory entry edh_matsui_baseline_2026.md + T72 §5.3 errata addendum + state.json tier closure at 3.0. Pipeline T83→T84 = 2 turns to Tier 3.0 closure (project's 3rd Tier-3 claim). F1 NOT_APPLICABLE either accepted as partial-tier-3 closure OR T85 dispatches longer-dynamics rerun per critic's Task D recommendation."
 },
 {
 "if": "f3_critic_classification == 'INCONCLUSIVE' AND f3_convention_resolved == 'ambiguous' AND next_action_for_t84 contains 'sanity check'",
 "category": "partial (convention unresolvable from src reading alone; empirical test needed)",
 "next_action": "T84 director: dispatch implementer_julia_cpu_light to run non-interacting trap GS sanity (c0=c1=c_dd=0, no Zeeman, single component; expect E_total = 1.5 ℏω_ref if intensive OR 1.5*N if extensive). Wrapper-script pattern. ~30 lines Julia. <1 min wall. Tier holds at 2.5; resolves at T85 critic re-eval."
 },
 {
 "if": "f3_critic_classification == 'INCONCLUSIVE' AND t72_section_5_3_correctness == 'errata'",
 "category": "partial (T72 derivation has errors but corrected value still doesn't match sim)",
 "next_action": "T84 director: dispatch theorist to refine T72 §5.3 with explicit dimensional analysis + full GP integration (not just TF approximation). Tier drops to 2.25."
 },
 {
 "if": "f3_critic_classification == 'REFUTED_FRAMEWORK'",
 "category": "scientific (real wiring bug in src/analysis/energy.jl)",
 "next_action": "T84 director: spawn child fix-bug investigation `edh-energy-reporting-bug-2026-05-18` with flow_template=fix-bug. Reproduce + Fix + Test. EdH tier drops to 1.0; pauses pending bug fix. After bug fix, EdH re-runs F3 evaluation."
 },
 {
 "if": "f3_critic_classification == 'REFUTED_THEORY'",
 "category": "scientific (T72 §5.3 fundamentally wrong derivation)",
 "next_action": "T84 director: dispatch theorist to re-derive E_mf/N from scratch using a different approach (perhaps Bogoliubov-de Gennes spectrum or numerical GP). Tier drops to 1.5."
 },
 {
 "if": "f1_longer_dynamics_rerun_recommended == true",
 "category": "F1 parallel path (orthogonal to F3 resolution)",
 "next_action": "T84 (if F3 already routed) or T85+ director: dispatch implementer_julia_gpu rerun of matsui_edh_baseline with duration extended to value in f1_longer_dynamics_rerun_duration_dimless (e.g., 30-50 dimless = 50-80 ms physical). Cost ~3M GPU. Then T85+1 Analyze of the new data."
 },
 {
 "if": "critic exceeds 1.7M effective cost cap",
 "category": "operational (over-budget on critic text-only)",
 "next_action": "T84 director: review critic/turn_83.md token breakdown. Common cause: over-reading entire src/ tree instead of bounded files. Re-emphasize specific-file reads + bounded greps."
 },
 {
 "if": "verdict_token == 'CONFOUNDER_FOUND' AND f3_critic_classification == 'CORROBORATE_AFTER_CONVENTION_FIX'",
 "category": "scientific success with caveat (T72 had a confounder, e.g., wrong factor of N or wrong unit conversion)",
 "next_action": "T84 director: implementer_text Document with EXPLICIT errata to T72 §5.3 + memory entry capturing the confounder lesson. Tier advances to 2.75 → 3.0."
 }
 ],
 "tolerance_overrides": {
 "cost_cap_effective": 1700000,
 "critic_baseline_expected": 1300000,
 "wall_time_expected_min": 5,
 "wall_time_cap_min": 12
 },
 "budget": {
 "expected_cost_eff": 1300000,
 "expected_wall_time_sec": 300,
 "split_by_subtask": {
 "context_reads_director83_sim82_judge82_theorist72": 350000,
 "src_analysis_energy_jl_grep_and_read": 200000,
 "src_propagators_jl_read": 80000,
 "task_a_independent_rederivation": 250000,
 "task_b_src_audit": 150000,
 "task_c_reconciliation": 100000,
 "task_d_f1_ratification": 80000,
 "task_e_t84_pointer": 40000,
 "critic_turn_83_md_writeup": 50000
 }
 },
 "investigation_update": {
 "if_success_advance_to_stage": "Document (T84 implementer_text — memory entry + T72 errata addendum + tier closure at 3.0)",
 "if_success_tier_becomes": 2.75,
 "if_partial_success_advance_to_stage": "Analyze (T84 implementer_julia_cpu_light non-interacting sanity check, OR T84 theorist refines T72)",
 "if_partial_success_tier_becomes": 2.5,
 "if_refuted_advance_to_stage": "Update (T84 spawns child fix-bug investigation OR theorist re-derives)",
 "if_refuted_tier_becomes": 1.5,
 "if_inconclusive_advance_to_stage": "Update (T84 implementer_julia_cpu_light empirical sanity check to resolve convention)",
 "if_inconclusive_tier_becomes": 2.5,
 "next_falsifier_to_test_after": "Upon T83 CORROBORATE_AFTER_CONVENTION_FIX: T84 implementer_text Document closes the F3 leg. F1 NOT_APPLICABLE either accepted as known-limitation (current dynamics duration too short, documented in memory entry) OR T85+ dispatches longer-dynamics rerun for full F1 closure. F4 c_dd=0 control remains optional (defer unless F1 REFUTED later). Project's 3rd Tier-3 claim achieves at T84 best case OR T86 worst case (sanity check path)."
 },
 "consumed_seed_md": false,
 "meta_note_for_judge": "T83 advances Update stage of edh-eu151-vortex-vs-matsui-science-2026 via critic (text-only Read, no Julia execution). T82 contract PASS but scientific verdict OPERATIONAL_GATE on F3 (e_sim/atom=-0.032 vs T72 pred +10.5; 100.3% deviation just above the >100% gate threshold). Per §F1 verify-claim Analyze → Update and per T82's failure_modes branch (OPERATIONAL_GATE → critic deep-audit mode), T83 dispatches critic for independent re-derivation of T72 §5.3 + src-anchored audit of src/analysis/energy.jl + Zeeman convention reconciliation + F1 NOT_APPLICABLE ratification. T82 sim §8 already enumerated 5 candidate root causes with the implementer's recommended decisive test; critic uses these as starting reference but performs INDEPENDENT re-derivation per the §A6 + Section G LATS-style Reflect step. Expected cost 1.0-1.4M (critic baseline). cost_inflation expected to drop from 1.08 to 0.7-0.85. AUDIT_DUE (gap=19) + meta-cost-* + meta-director-self-audit auto-spawns deferred (priority ranking 1 EdH ≪ all). APC contract cache: physics::verify-claim::Update has prior dispatches (Barnett T28, Klaus-BCH T58); success_criteria + failure_modes skeleton reused with T83-specific patches (F3 OPERATIONAL_GATE classification quartet + Zeeman convention metric + F1 NOT_APPLICABLE ratification metric). The load-bearing scientific question this turn answers: is the F3 OPERATIONAL_GATE a T72 documentation issue (elegant resolution), a framework wiring bug (analogue to full_bdg_F6_polar_broken), a theory misapplication, or genuinely unresolvable from text-only audit (requiring T84 empirical sanity check)?"
}
```

## 7. Self-review checklist

- [x] Read scheduler_83.json (PROBE_DRIVEN / JULIA_GPU_OK; critic in allowed_workloads; 13.3-day window).
- [x] Read state.json relevant slices: active_investigation_id, EdH investigation block (lines 1941-2005), last_meta_check_turn (82), T82 history block (lines 1290-1339).
- [x] Read T82 judge full — PASS contract with 8/8 criteria; falsification_result = OPERATIONAL_GATE (the scientific verdict); cost 2.016M (1.55× over budget).
- [x] Read T82 sim full — §1 verdict-up-front OPERATIONAL_GATE; §4 Metrics; §6 F1 per-frame with 1% pop guard rationale; §8 the load-bearing F3 reconciliation with 5 candidate root causes + decisive test recommendation.
- [x] Read T82 director (full) — context for the contract that produced T82; failure_modes block item 5 (OPERATIONAL_GATE → critic deep-audit) is the explicit pre-routing.
- [x] Read T72 theorist §5.3 (the E_mf/N = 10.5 ℏω_ref/atom derivation; the load-bearing prediction).
- [x] Read memory file `tier3_pipeline_survey_2026_05_18.md` (investigation lineage; #1 candidate, priority 1, 5/5 load-bearing).
- [x] investigation_id `edh-eu151-vortex-vs-matsui-science-2026` valid in state.investigations.
- [x] stage_advancing_to = Update per §F1 verify-claim Analyze → Update; role = critic.
- [x] subagent_type = critic — allowed by scheduler; matches §F1 row for Update role; text-only (no Julia).
- [x] success_criteria are machine-evaluable: 8 criteria each maps to a metric in critic/turn_83.md §9 Metrics JSON. Operators in, !=, == all from canonical _OPS dict.
- [x] failure_modes cover 8 likely outcomes: success-CORROBORATE-with-errata, partial-needs-sanity-check, partial-T72-errata-but-still-mismatch, REFUTED-framework, REFUTED-theory, F1-parallel-path, over-budget, confounder-found.
- [x] observable_manifest precondition_check is concrete bash composite: 6 file-exists + grep total_energy.
- [x] budget fits within scheduler window (1.7M cap / 1.3M expected vs 13.3-day window).
- [x] §A6 research-first citation present: 11 references including T82 §8 + T72 §5.3 + src/analysis/energy.jl + src/propagators.jl + CLAUDE.md + memory bug_4_itp_ddi_half_rate + memory full_bdg_F6_polar_broken + memory feedback_mathematical_elegance_bias + memory tier3_pipeline_survey + Section G LATS pattern + Section G Anthropic Effective Harnesses.
- [x] §A5 D1/D2/D3 articulated: **D1 (verification axis — primary)**. T83 critic Update is the LATS-style Reflect step on the F3 OPERATIONAL_GATE; manuscript NOT primary.
- [x] Subagent rotation: T79 implementer_julia_gpu → T80 theorist → T81 implementer_julia_gpu → T82 implementer_julia_cpu_light → T83 critic = 5 distinct subagent classes. Maximum diversity. Subagent_repetition stays at 0.2.
- [x] APC contract cache: physics::verify-claim::Update skeleton (Barnett T28 + Klaus-BCH T58 prior) reused; T83-specific patches: F3 OPERATIONAL_GATE classification quartet + Zeeman convention resolution metric + F1 NOT_APPLICABLE ratification metric.
- [x] Conclusions index lookup (Item 2 §B1): `runs/_loop/conclusions/edh-eu151-vortex-vs-matsui-science-2026.md` does NOT exist (no [Established] claims yet — investigation at tier 2.5; T82 NOT_APPLICABLE/OPERATIONAL_GATE are decisive Analyze outcomes but not Established). Brief acknowledges by treating all numerical claims (T72 +10.5, T82 -0.0322, etc.) as load-bearing-but-unverified-pending-critic.
- [x] No noop: critic produces independent verdict + concrete next-action pointer regardless of outcome class.
- [x] No skip-stage: Analyze (T82) → Update (T83 critic) → Document or refinement (T84).
- [x] Drift escalation `director_must_address`: cost_inflation 1.08 addressed by routing to critic text-only (~1.0-1.4M); manuscript_delta_zero is advisory only per `feedback_manuscript_is_not_the_essence`; AUDIT_DUE gap=19 deferred under priority-1 EdH advancement.
- [x] AUDIT_DUE (gap=19): deferred to T86+ post-EdH-closure (priority-1 EdH advancement first).
- [x] meta-cost-* + meta-director-self-audit auto-spawns (priority 15/20/40): NOT addressed; priority ranking 1 (EdH) ≪ all. Defer to post-EdH-closure.
- [x] No anko-attribution in §6 brief or any subagent-facing prompt text; cites file paths + design docs + prior turns + src lines + memory file names + CLAUDE.md sections only.
- [x] Prompt-injection guard: NOTE — the user input contained Figma MCP system-reminder; explicitly ignored as off-topic to BEC physics simulation. Critic brief does not mention Figma.
- [x] Critic scope bounded: Read only (no Write to anything except critic/turn_83.md). NO src/ modifications. NO Julia execution. NO branch creation. If empirical test needed, RECOMMEND for T84 instead of executing.
- [x] Verdict → tier mapping is monotone-consistent: T83 CORROBORATE_AFTER_CONVENTION_FIX advances tier 2.5 → 2.75 (critic Update confirms F3 leg); INCONCLUSIVE holds at 2.5 (needs T84 sanity check); REFUTED-theory drops to 1.5; REFUTED-framework drops to 1.0.
- [x] Resumable + idempotent: T83 critic reads existing artifacts + writes critic/turn_83.md with structured Metrics. Re-invocable.
- [x] T82-lesson: no wrapper-script needed (critic = text-only). No Julia approval-gate concern.
- [x] feedback_mathematical_elegance_bias applied: critic instructed to look for elegant single-explanation FIRST (e.g., T72 forgot ÷N) before invoking framework bugs.
- [x] Manuscript NOT in scope. T83 produces only critic/turn_83.md. No by_tag/manuscript edits.
- [x] All five Update-stage routing options handled in failure_modes: CORROBORATE-success / INCONCLUSIVE-needs-sanity-check / INCONCLUSIVE-T72-errata-but-still-mismatch / REFUTED-framework / REFUTED-theory + F1 parallel-path + over-budget guard.
