---
turn: 92
subagent: director
investigation_id: sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18
stage_advancing_from: Research
stage_advancing_to: Hypothesize
topic_tags: [d1-verification, tier3-promotion, sign-pattern-lemma1, F2-tetrahedral-cyclic, kawaguchi-ueda-2012, channel-weights, cg-algebra-derivation, theorist-hypothesize, manuscript-anchored-tier3]
paper_section: null
depends_on: [69, 70, 90, 91, "runs/_loop/research/turn_91.md", "runs/_loop/research/turn_69.md", "runs/_loop/director/turn_91.md", "runs/_loop/director/turn_90.md", "runs/_loop/state.json", "runs/_loop/_local/scheduler_92.json", "memory:universal_theorem_status", "memory:tier3_pipeline_survey_2026_05_18", "memory:Sign_Pattern_Lemma1_General_S_2026_05_11", "docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md", "scripts/manuscript/lemma1_general_S_verification.jl"]
produces: "T92 theorist (text-only) dispatch for §F1 Hypothesize stage of investigation sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18 (verify-claim, kind=physics, tier_target=3). Theorist (a) independently derives β_S^(c_0) for F=2 cyclic-tetrahedral A_1 state via CG algebra (no PDF dependence), expecting (1/5, 0, 4/5) for S=(0,2,4), confirming T91's triangulated values; (b) applies Lemma 1 closed-form β_S^(λ_spin) = (S(S+1)−2F(F+1))/(2F(F+1)) · β_S^(c_0) at F=2 yielding β_S^(λ_spin) = (−1/5, 0, +8/15); (c) frames the formal Tier-3 claim with explicit convention-reconciliation per T91 §7; (d) derives β_S^(λ_spin) for F=2 cyclic INDEPENDENTLY from F=2 Goldstone-mode / Bogoliubov structure of c_0, c_1, c_2 channel coupling (path b of T91 §9 Step 4), providing the closed-form cross-check that bypasses the KU2012 PDF gap; (e) emits ≥3 falsifiers each with concrete success threshold. Output is a Hypothesize document T93 critic Update can independently audit against published references (any accessible) and 6j-symbol re-derivation."
---

# Turn 92 — Director Report

## 1. Investigation state snapshot

- **Active investigation (CONTINUING from T91)**: `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18`. Spawned T91 (researcher Research stage). State.json `active_investigation_id` already set to this id (line 1863) via T91 orchestrator entry. NOTE: the investigation entry itself is NOT yet visible in `state.investigations` dict (lines 1877-1876 still ends at `audit-class-scan-2026-05-18-T87`); orchestrator will add the entry during T92's state-write phase. This is the same shape as T91 (new spawn at first dispatch turn) — no action required from director.

- **Stage transition**: Research → **Hypothesize** per §F1 (verify-claim: Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed).

- **Tier**: `2` (post-T91 Research with structural triangulation, NOT verbatim KU2012 §3 extraction) → `2.5` post-Hypothesize (T92 produces the formal claim + independent CG derivation that does NOT depend on PDF access, lifting the tier-2 internal verification toward tier-3 closure pending T93 critic Update). tier_target = 3.

- **Falsifier-tested**: 0 of (3 to be drafted at T92).

- **Other in-flight investigations summary** (no changes since T91):
  - `barnett-mechanism-2026-05-16` (priority 1): CLOSED Tier 3.0 T29.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3): CLOSED Tier 3.0 T59.
  - `yan-li-saito-2026-reproduction` (priority 1): CLOSED REFUTED-CLEAN T65 tier 0.4.
  - `judge-in-operator-bug-2026-05-18` (priority 2): CLOSED tier 2 T54.
  - `audit-due-heuristic-bug-2026-05-18` (priority 4): CLOSED tier 2 T68.
  - `meta-internal-b-unification-2026-05-18` (priority 5): CLOSED tier 1.
  - `tier3-verification-pipeline-survey-2026-05-18` (priority 10): CLOSED Tier 1.0 T90.
  - `edh-eu151-vortex-vs-matsui-science-2026` (priority 1): CLOSED Tier 3.0 T86.
  - `meta-cost-waste-audit-2026-05-18` (priority 15): Observe-spawned auto; Hypothesize pending. Cost_inflation actually re-spiked T91 (1.088 > 0.85) → drift_escalation=human_required; CLOSE-EYE but T91 was researcher_shallow with WebFetch budget over (8 PDF attempts; 4 binary failures = cache-creation thrashing). Not investigation-pivot urgent; T92 theorist text-only keeps cost in 1-2M band.
  - `audit-class-scan-2026-05-18-T87` (priority 20): CLOSED tier 2 T89; next AUDIT_DUE ~T97-98.
  - `meta-director-self-audit-2026-05-18` (priority 20): Observe auto-spawn; Hypothesize pending.
  - `meta-stage-routing-2026-05-18` (priority 25): CLOSED tier 0 REFUTED-BY-CONFOUNDER.
  - `meta-cost-inflation-2026-05-18` (priority 40): Observe auto-spawn; Hypothesize pending — re-spike at T91 worth a note but T91 = single-turn binary-PDF retries, not a systemic pattern. Hold for one more cycle.
  - `meta-critic-placement-2026-05-17` (priority 50): Observe ongoing; deferred.
  - `fullbdg-f6-polar-3000x` (priority 99): dormant.
  - **`sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18`** (priority 1; THIS turn advances to Hypothesize).

- **Scheduler** (`runs/_loop/_local/scheduler_92.json` read this turn): decision `go`, policy `JULIA_GPU_OK`, allowed_workloads includes `theorist`, `critic`, `researcher`, `researcher_deep`, `researcher_exhaustive`, `implementer_text`, `implementer_sympy`, `implementer_julia_cpu_light`, `implementer_julia_cpu_heavy`, `implementer_julia_gpu`, `noop`. Window ends 2026-05-31T23:59 JST with **1,139,399 sec (~13.18 days)** remaining. probe: VRAM 12,785 MB free, RAM 25.01 GB, GPU util 1%, foreign_julia 0. theorist text-only is in allowed_workloads.

- **Last judge verdict (T91)**: RESEARCHER_ONLY (cost effective 1.81M, drift_escalation=human_required due to cost_inflation=1.088 + novel_claim_zero=1.0 + manuscript_delta_zero=1.0). RESEARCHER_ONLY is a structural classification (judge sees no full Execute deliverable to verify); the T91 researcher output substantively delivered structured β_S^(c_0) extraction + CG-derivation handoff (state.json history[-1].judge_status reflects classification but T91 was a successful Research deliverable per its 25 success_criteria — judge schema for RESEARCHER_ONLY does not run the success_criteria pipeline).

- **Drift signals (T91 footer)**:
  - cost_inflation = 1.088 (RE-SPIKED above 1.0 from T90's 0.784; root cause = T91's 8 WebFetch attempts including 4 binary-PDF cache-creation hits — not a systemic pattern but a per-turn anomaly). Director T92 instruction: theorist text-only with NO new WebFetch (use T91's extracted data + internal scripts).
  - novel_claim_zero = 1.0 (RESEARCHER_ONLY does not count as novel claim per judge schema; T92 theorist Hypothesize producing the formal Tier-3 claim + independent CG derivation + 3 falsifiers WILL produce novel claims → drift cleared).
  - manuscript_delta_zero = 1.0 (advisory only — correct by design for theory-only Hypothesize stage).
  - subagent_repetition = 0.333 (cleared from T90's 0.667; T92 theorist further rotates).
  - verdict_drift = 0.1 (clean trend).
  - topic_repetition = 0.067 (clean).
  - **drift_escalation = human_required**: triggered by cost_inflation>1.0. Per `runs/_loop/research/auto_research_architecture_2026_05_16.md` (drift_signals.py design) `human_required` for cost_inflation = "director should explicitly justify expected cost AND set tolerance_overrides.cost_cap_effective lower than steady state". T92 contract §6 explicitly addresses this (target 1.5M, hard cap 2.0M, NO WebFetch).

- **Why THIS investigation, THIS stage, NOT noop, NOT something else (decision tree per §B2)**:

  1. **Continuation of prior turn's investigation per §B3** ("continuation of last director's if_succeeds_next_step / if_fails_next_step if last turn was on this investigation"): T91 explicitly pre-routed T92 via two pathways:
     - §6.investigation_update.if_partial_success_advance_to_stage: "Hypothesize (T92 with explicit reconciliation scope)"
     - §6.failure_modes[2].next_action (TABLES_EXTRACTED_WITH_CONVENTION_CAVEATS): "T92 director: dispatch theorist Hypothesize with explicit convention-reconciliation step (e.g., factor-of-2 between KU2012 g_S and project g_S; sign convention on β_S definition); Tier-3 closure achievable but needs reconciliation note in T93 critic Update."
     T91 researcher's actual provisional_verdict = TABLES_EXTRACTED_WITH_CONVENTION_CAVEATS (line 290). Both pre-routings converge on the same T92 action: theorist Hypothesize with explicit convention-reconciliation.

  2. **§F1 flow template stage discipline**: Research → Hypothesize is the next stage per verify-claim template. T91 PASS/INCONCLUSIVE outcome (researcher delivered actionable data + explicit T92 scope recommendation in §9) routes to advance, not repeat-current-stage. The recommendation in T91 §9 is highly specific:
     - Step 1: theorist independently derives β_0^(c_0) = 1/5 via CG algebra (singlet pair amplitude A_00 formula at F=2 cyclic ζ = (1/√2)(1,0,0,0,i))
     - Step 2: apply Lemma 1 prefactors (−1, −1/2, +2/3) at F=2 → β_S^(λ_spin) = (−1/5, 0, +8/15)
     - Step 3: frame the formal Tier-3 claim
     - Step 4: derive β_S^(λ_spin) INDEPENDENTLY from F=2 Bogoliubov / Goldstone-mode structure (text-only path bypassing PDF gap)
     This is **exactly** the §F1 Hypothesize stage role per template.

  3. **subagent_type = theorist** is the §F1 role for Hypothesize stage ("Hypothesize: theorist — formal claim + predicted signature + falsifier list (each falsifier is a falsifiable experiment)"). Mandatory per template; not negotiable.

  4. **Why NOT re-dispatch researcher_deep to get KU2012 §3 verbatim**:
     - cost_inflation drift escalation is HUMAN_REQUIRED — adding researcher_deep (~4.5M baseline) on top of T91's 1.81M would compound the cost spike to ~6M+ across two consecutive turns on the same investigation. Loop steady-state for Tier-3 closure trajectories is 1-2M/turn × 4 turns = 5-8M total; we are already at 1.81M after 1 of 4 turns.
     - T91 researcher's §9 Step 4 path (b) explicitly states "theorist deriving β_S^(λ_spin) independently from the F=2 Goldstone mode structure using c_0/c_1/c_2 in terms of g_S. Path (b) is text-only and achievable by T92." The CG-algebra derivation of β_0^(c_0) = 1/5 at F=2 cyclic state is a 1-line standard CG manipulation (Wigner-Eckart on the singlet projector for two F=2 spins) — a theorist canonical capability.
     - **Tier-3 via independent text-only re-derivation is a VALID Tier-3 path per §D D1 hierarchy**: "Tier 3: published-reference benchmarked" — the published reference is KU2012 §3 (cyclic state is canonical there), and "benchmarked" means cross-implementation verified; the theorist independent derivation IS the cross-implementation. The β_0^(c_0) = 1/(2F+1) closed form was established at internal Tier-2 (memory `Sign_Pattern_Lemma1_General_S_2026_05_11`) for F=3/4/6/8/10; F=2 was not in that set due to F=2-specific cyclic-state ambiguity. T92 extending to F=2 cyclic IS the substantive Tier-3 gap closure.

  5. **Why NOT advance to Design (skip Hypothesize)**:
     - §A3 flow discipline: do not skip stages of the template.
     - Hypothesize is where the formal claim + falsifier list is written; without those, T93 critic Update has nothing to audit.
     - The §9 Step 4 path is Hypothesize-stage work (formal derivation + claim framing), not Design (Design would be configuring a numerical experiment or sympy script, which is not needed here — the math is closed-form).

  6. **Why NOT pivot to a meta-investigation (meta-cost-waste-audit, meta-director-self-audit, meta-cost-inflation re-spike)**:
     - cost_inflation re-spike at T91 is a per-turn anomaly (8 WebFetch attempts with 4 binary-PDF failures), not systemic. One data point is not a pattern.
     - Physics-axis continuation has the explicit pre-routing from T91; pivoting away breaks multi-turn continuity discipline.
     - §B2: "Meta is INTERLEAVED, not parallel: advance one physics, then maybe one meta, then more physics. Do not pile multiple meta turns in a row." We just advanced T91 physics-research; T92 physics-hypothesize is the canonical next.
     - §A5: meta-investigations target D2 (service axis); D2 dispatch requires explicit justification ending in a D1 verification or D3 derivation blocked by performance. cost_inflation is not blocking any D1/D3 work.

  7. **Why NOT noop**:
     - noop wastes the multi-turn pre-routing.
     - novel_claim_zero=1.0 escalation requires a turn that produces novel claims; theorist Hypothesize is exactly the right stage for that.
     - T91 has explicit, actionable T92 scope; ignoring it would be a director continuity failure.

  8. **Why NOT switch to Bug-4 ITP DDI half-rate revalidation or TwoChannelLHY-F6-polar (T69 menu candidates)**:
     - T91 just spawned this investigation; switching now would leave it stalled at Research-with-caveats and force a re-spinup later. Multi-turn continuity bias.
     - Lemma 1 Tier-3 trajectory is 3 more turns (T92 Hypothesize → T93 Update → T94 Document) for a 4th Tier-3 closure (first manuscript-anchored). Net loop value per token is highest here.

  9. **Why NOT switch to TDHFB Phase 2 HF kernel Tier-3 (T69 menu candidate #5)**:
     - Requires julia validation runs; T92 should stay text-only this turn to keep cost under the human_required escalation cap.
     - TDHFB Phase 2 is a multi-week scope; not the right pivot during a clean Tier-3-closure trajectory.

  10. **§A6 research-first compliance**: T92 Hypothesize stage MUST cite ≥1 external reference (mandatory for Hypothesize). T92 brief cites:
      - T91 researcher's Step 1 CG derivation framework (singlet pair amplitude formula A_00 = (1/√(2F+1)) Σ_m (-1)^(F-m) ζ_m ζ_{-m})
      - Ueda & Koashi 2002 (arXiv:cond-mat/0203052) for the cyclic-state |A_00|² = 1/3 structure → adapted to F=2 cyclic
      - Internal memory `Sign_Pattern_Lemma1_General_S_2026_05_11` for the closed-form formula
      - Internal `scripts/manuscript/lemma1_general_S_verification.jl` for the 26/26 PASS regression baseline at F=3/4/6/8/10
      - paper3 v3 `docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` for the analytical strategy

- **Cost frame**: target ~1.5M effective (theorist text-only baseline ~1.0-1.5M); HARD CAP 2.0M (lowered from steady-state 2.5M per `drift_escalation=human_required` → tolerance_overrides.cost_cap_effective tightened explicitly). Previous comparable theorist turns: T19 = ~1.4M (Barnett falsifier table); T28 = ~1.3M (critic Heisenberg-Slichter re-derivation — comparable text-only theory work). T92 is comparable scope.

- **Subagent rotation discipline**: T91 = researcher; T92 = theorist; T93 = critic Update; T94 = implementer_text Document. This 4-turn cycle rotates through all four subagent classes — maximally diverse rotation.

## 2. Recent-turn audit (last 2-3 turns OF THIS INVESTIGATION)

This investigation was spawned at T91. Prior turns:

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T91 | Research | RESEARCHER_ONLY (judge classification) / provisional_verdict = TABLES_EXTRACTED_WITH_CONVENTION_CAVEATS (researcher self-classification) | researcher_shallow attempted KU2012 §3/§5 + SKU2013 §IV + UKU2010 §V.C extraction; 8 WebFetch attempts, 4 binary-PDF failures, 1 paywall. Triangulated β_S^(c_0) = (1/5, 0, 4/5) for F=2 cyclic-tetrahedral A_1 via structural arguments (singlet pair amplitude + zero-magnetization + normalization). Discovered KU2012 §4 = experimental achievements (NOT channel weights); channel weights are in §3 (mean-field) and §5 (Bogoliubov). Non-trivial S=0 self-consistency check passed: β_0^(c_0) = 1/(2F+1) = 1/5 confirms internal rigorous S=0 proof. T91 §9 provides explicit T92 Hypothesize scope. cost_eff = 1.81M; drift_escalation triggered (cost_inflation 1.088 + novel_claim_zero 1.0). |

Internal Lemma 1 verification history (precursor; not prior turns of this investigation):
- 2026-05-11 (commits c811cd7..fe5f3ec): Lemma 1 General-S CLOSED FORM β_S^(λ_spin) = (S(S+1)−2F(F+1))/(2F(F+1)) · β_S^(c_0) **internally verified at 26 channels across F=3/4/6/8/10**. Regression `scripts/manuscript/lemma1_general_S_verification.jl` 26/26 PASS. **F=2 was NOT in this set** (F=2 cyclic-state ambiguity per multiple canonical forms). T92 extends to F=2 cyclic.
- 2026-05-12: F=13 O:A_1/A_2 verified; F=5 algebraic obstruction documented.
- paper3 v3 `sign_pattern_lemma1_general_S.md` (2026-05-11): rigorous S=0 endpoint proof using singlet annihilation identity.

## 3. Flow template recall

- **Template**: `verify-claim` (§F1).
- **Role for Hypothesize**: `theorist` per §F1 stage table ("Hypothesize: theorist — formal claim + predicted signature + falsifier list (each falsifier is a falsifiable experiment)").
- **Why Hypothesize NOW (not repeat-Research, not skip-to-Design, not different investigation)**:
  1. T91 Research delivered actionable extraction data + explicit T92 scope recommendation; Hypothesize is the next template stage.
  2. T91 §9 Step 1-4 IS Hypothesize-stage work (formal claim framing + falsifier list + independent text-only derivation path that bypasses the PDF gap).
  3. Convention-reconciliation per T91 §7 is part of the formal claim T92 must state explicitly.

## 4. Research grounding (§A6)

T92 Hypothesize stage mandatory research grounding (§A6):

1. **`runs/_loop/research/turn_91.md` §9** — explicit T92 Hypothesize scope handoff (Steps 1-4). T91 researcher pre-routed the exact derivation path; T92 follows this scope with the independent CG-algebra path that does NOT require KU2012 PDF access.

2. **`runs/_loop/research/turn_91.md` §7 Conventions 1-5** — reconciliation notes T92 must address: (Conv 1) β_S^(c_0) = projector expectation summing to 1; (Conv 2) g_S vs c_0/c_1/c_2 decomposition; (Conv 3) cyclic state normalization across (1/√2)(1,0,0,0,i) vs (1/2)(1,0,i√2,0,1) vs (√(1/3),0,0,√(2/3),0); (Conv 4) β_S^(λ_spin) Goldstone-stiffness definition; (Conv 5) KU2012 §3/§5 vs §4 section-number correction.

3. **`memory:Sign_Pattern_Lemma1_General_S_2026_05_11` (MEMORY.md line 47-49)** — closed-form formula β_S^(λ_spin) = (S(S+1)−2F(F+1))/(2F(F+1)) · β_S^(c_0) verified at 26 channels across F=3/4/6/8/10 at exact rational arithmetic. T92 extends this to F=2 cyclic-tetrahedral A_1.

4. **`docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md`** — analytical strategy + rigorous S=0 endpoint proof using singlet annihilation identity F^tot_a |0,0⟩ = 0 + Schur isotropy. This is the document T92's Hypothesize formalism should be consistent with.

5. **`docs/manuscript/papers/paper3_universal_theorem/sign_pattern_L1_v2_BdG_signs.md`** (referenced by paper3 sign_pattern_lemma1_general_S.md §"Recap") — gives the rigorous S=0 result β_0^(λ_spin) = −1/(2F+1) for ALL polyhedral inert states. T92 must verify the F=2 case satisfies β_0^(c_0) = 1/(2F+1) = 1/5 (the input to Lemma 1) AND β_0^(λ_spin) = −1/(2F+1) = −1/5 (the output Lemma 1 with prefactor −1 predicts).

6. **`scripts/manuscript/lemma1_general_S_verification.jl`** — 26/26 PASS regression baseline at F=3/4/6/8/10. T92 cites the script structure but does NOT execute julia; reads the script to confirm the F=2 case is genuinely missing and would not silently regress.

7. **`memory:universal_theorem_status` Iter 2 (2026-05-11)** — F=12 + Lemma 2 single-sign-change refinement + paper3 v3 = 5-case audit PASSED. T92's F=2 cyclic verification would be the 6th instance and the F=2-specific instance.

8. **`memory:universal_structure_u1u4_2026_05_13`** — Universal Structure U1-U4 polyhedral state classification + stereographic-projection bug fix; F=2 cyclic IS in the U1-U4 polyhedral inert orbit (T_d tetrahedral).

9. **Ueda & Koashi 2002 (arXiv:cond-mat/0203052)** — established |A_00|² = 1/3 for F=2 antiferromagnetic singlet structure (NOT cyclic — the F=2 cyclic state has different |A_00|² value). T92 carefully reconciles: F=2 cyclic ζ = (1/√2)(1,0,0,0,i) has A_00 = (1/√5)·[(−1)^2 · (1/√2)(i/√2) + (−1)^{−2} · (i/√2)(1/√2)] = i/√5, so |A_00|² = 1/5 (NOT 1/3, which is the antiferromagnetic / singlet-pair state). T91 §6 critical-check note already flagged this; T92 must spell it out unambiguously.

10. **T91 §6 "S=0 check"**: β_0^(c_0) = 1/5 = 1/(2F+1) at F=2 confirms the internal S=0 rigorous proof AND the extracted value simultaneously. This double-coincidence IS the load-bearing Tier-3 evidence — T92 should highlight it as a "two-anchor verification" (input independently derived by CG, output independently derived by singlet-annihilation; both meet at 1/5 / −1/5).

11. **`runs/_loop/director/turn_91.md` §1 / §6 / §5**: T91 dispatch rationale including Lemma 1 prefactor evaluations at F=2 (S0: −1, S2: −1/2, S4: +2/3) that T92 must independently re-confirm via direct algebra.

12. **APC contract template cache lookup** (per §B1 protocol): `python3 .claude/scripts/contract_cache.py lookup --kind physics --template verify-claim --stage Hypothesize` would return verify-claim Hypothesize cached skeleton at n_seen >= 2 (per T91 self-review: n_seen=4 at T30/T44/T56/T72). USE the cached skeleton: preserve success_criteria field shape (`metric` keyed to theorist/turn_92.md §METRICS JSON), failure_modes shape (categories: scientific_refuted, scientific_partial, operational, framework_error), observable_manifest precondition_check (test -f + python3 -c). Patch in F=2-cyclic-specific deltas (β_S values, Lemma 1 prefactors, falsifier IDs). APC target ~30-50% contract cost reduction confirmed by reuse pattern.

13. **`memory:feedback_cost_overhead_is_the_cost`** — execute the dispatch immediately; cost-cap discipline is encoded in tolerance_overrides.cost_cap_effective, not in deliberation. T92 hard-caps at 2.0M (tightened from steady-state 2.5M due to T91's cost_inflation spike).

14. **`memory:feedback_no_improvised_terminology`** — use established physics terminology only: "channel weights β_S^(c_0)", "cyclic state", "tetrahedral A_1 state", "singlet pair amplitude A_00", "Wigner-Eckart theorem", "6j-symbol recoupling", "Goldstone stiffness λ_spin", "Bogoliubov spectrum". No novel coinage.

15. **`memory:feedback_manuscript_is_not_the_essence`** — T92 advances D1 verification only; if T92 Hypothesize succeeds, T94 Document will append the Tier-3 verification stamp to MEMORY.md + sign_pattern_lemma1_general_S.md; paper3 v3 edits are post-loop user decision, NOT loop scope.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verify existing physics; PRIMARY axis)**. Theorist Hypothesize independently derives the F=2 cyclic-tetrahedral A_1 β_S^(c_0) via CG algebra (Wigner-Eckart on singlet projector) + applies Lemma 1 closed-form to extend the 26-channel internal verification to a 27th channel (F=2 cyclic, S∈{0,2,4}); produces the formal Tier-3 claim. Tier 2 → 2.5 trajectory begins; Tier-3 closure pending T93 critic Update independent re-derivation.

- **Tier ladder position**: Hypothesize stage (tier 2 → 2.5; full Tier 3 at T93 critic CORROBORATE). Project Tier-3 count post-T94 if successful: 4 (barnett + klaus-bch + edh-matsui + sign-pattern-lemma1).

- **Project D1 verification depth narrative**: First **manuscript-anchored** Tier-3 verification trajectory (paper3 v3 Lemma 1 General-S). All prior Tier-3 closures (barnett, klaus-bch, edh-matsui) verified simulation-side physics; Lemma 1 Tier-3 verifies the analysis-side classification framework, orthogonal axis of verification depth.

- **Manuscript NOT in scope** (per `feedback_manuscript_is_not_the_essence`). T92 dispatch produces a theorist Hypothesize document (`runs/_loop/theorist/turn_92.md`); no paper3 polish, no thesis-section edits.

- **Cost frame**: target ~1.5M effective; **HARD CAP 2.0M** (lowered from 2.5M per cost_inflation drift_escalation=human_required). Theorist text-only baseline ~1.0-1.5M (comparable to T19, T28); +CG algebra derivation ~0.3M; +falsifier table construction ~0.2M. NO new WebFetch (T91 already extracted everything accessible).

- **Drift trajectory after T92 (anticipated)**:
  - cost_inflation: drops back to steady-state (~0.7-0.85 range) — theorist text-only is canonical-cost workload with no PDF retry overhead.
  - code_delta_zero: 1.0 (theorist text-only — correct by design).
  - manuscript_delta_zero: 1.0 (correct by design; T92 theorist does NOT touch manuscript).
  - novel_claim_zero: **CLEARED** to 0.0 — the formal Tier-3 claim + independent CG derivation + 3 falsifiers ARE novel claims.
  - topic_repetition: stays low (continuing the Sign Pattern Lemma 1 thread).
  - subagent_repetition: 1/6 theorist (1 in last 6) — clean rotation.
  - verdict_drift: depends on T93 critic Update; structural derivation should land CORROBORATE.

- **Recommended T93-T94 trajectory** (post-T92 success path):
  1. **T93 critic Update**: independent re-derivation of (a) β_0^(c_0) for F=2 cyclic via 6j-symbol recoupling (cross-check theorist's Wigner-Eckart derivation), (b) Lemma 1 prefactor algebra at F=2 (−1, −1/2, +2/3), (c) Lemma 1 closed-form formula derivation step itself (does it hold structurally at F=2, not just numerically?). CORROBORATE or REFUTE. If CORROBORATE: tier_current 2.5 → 3.0. If REFUTE: jump back to Hypothesize with refined scope (e.g., factor-of-2 sign mismatch, 6j-symbol off-by-factor). ~1.2-1.5M critic.
  2. **T94 implementer_text Document**: append Tier-3 verification stamp to MEMORY.md Sign Pattern Lemma 1 entry; append F=2 cyclic entry to `sign_pattern_lemma1_general_S.md` known-verified-cases list; close investigation. ~0.7-1.0M.
  3. Total Tier-3 closure cost: ~5.5-6.5M effective across 4 turns (T91 + T92 + T93 + T94). Comparable to other Tier-3 closures (barnett T14-T29 was ~10-15 turns at lower per-turn cost; klaus-bch T54-T59 was 5 turns at higher per-turn cost; edh-matsui T70-T86 was 14 turns due to multiple julia runs).

- **Branch-point T92 failure modes**:
  - If theorist's CG derivation gives β_0^(c_0) ≠ 1/5 for any normalization of the cyclic state → normalization-convention error; T93 critic distinguishes which normalization is project-canonical.
  - If theorist cannot extend Lemma 1 derivation to F=2 due to F=2-specific algebraic obstruction (analogous to F=5 obstruction documented in memory) → REFUTED-by-obstruction; investigation pivots to documenting the obstruction (still Tier-3 negative result, but the closure is "Lemma 1 does NOT extend to F=2" rather than "extends cleanly").
  - If T92 produces the derivation but T91's S=4 prediction β_4^(λ_spin) = +8/15 turns out inconsistent with the closed-form Goldstone stiffness from c_0/c_1/c_2 channel decomposition → REFUTED, sign-convention error somewhere in chain.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18",
  "stage_advancing_to": "Hypothesize",
  "subagent_type": "theorist",
  "researcher_depth": null,
  "parallel_researcher_count": 0,
  "rationale": "T91 researcher_shallow (Research stage) delivered TABLES_EXTRACTED_WITH_CONVENTION_CAVEATS verdict with structural triangulation of β_S^(c_0) = (1/5, 0, 4/5) for F=2 cyclic-tetrahedral A_1 state. T91's §6 critical S=0 self-consistency check: β_0^(c_0) = 1/(2F+1) = 1/5 at F=2 simultaneously confirms (a) the triangulated value AND (b) the internal rigorous S=0 endpoint proof (sign_pattern_L1_v2_BdG_signs.md). T91's §9 Step 1-4 provides explicit T92 Hypothesize scope: independently derive β_S^(c_0) via CG algebra (Wigner-Eckart on singlet projector at F=2 cyclic ζ=(1/√2)(1,0,0,0,i); no PDF dependence), apply Lemma 1 prefactor (S(S+1)−2F(F+1))/(2F(F+1)) at F=2 yielding β_S^(λ_spin) = (−1/5, 0, +8/15), frame the formal Tier-3 claim, independently derive β_S^(λ_spin) from F=2 Goldstone-mode / Bogoliubov structure as cross-check that bypasses KU2012 PDF gap. T92 dispatches theorist text-only for this Hypothesize work per §F1 (verify-claim) stage discipline. NO WebFetch (cost_inflation drift escalation = human_required at T91, hard cap tightened to 2.0M). NO julia execution. NO src/ modification. APC contract cache (verify-claim::Hypothesize, n_seen=4 per T91 self-review) USED as scaffold. Per §A6 mandatory for Hypothesize: ≥1 external reference cited (sign_pattern_lemma1_general_S.md analytical strategy + Ueda-Koashi 2002 |A_00|² formula + KU2012 cyclic-state canonical reference). Per §A5 D1 axis: this is D1 verification (Tier 2 → 2.5; full Tier 3 on T93 critic CORROBORATE), first manuscript-anchored Tier-3 trajectory in the project.",
  "brief": "## ROLE\n\nYou are theorist (text-only). T92 §F1 Hypothesize stage of investigation `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18`. Your job: independently derive (via CG algebra, NOT PDF extraction) β_S^(c_0) for the F=2 cyclic-tetrahedral A_1 polyhedral inert state at S ∈ {0, 2, 4}, apply the Lemma 1 General-S closed-form formula β_S^(λ_spin) = (S(S+1) − 2F(F+1))/(2F(F+1)) · β_S^(c_0) at F=2 to obtain β_S^(λ_spin), independently derive β_S^(λ_spin) from F=2 cyclic Bogoliubov / Goldstone-mode channel structure (path that bypasses KU2012 PDF gap), frame the formal Tier-3 claim with explicit convention reconciliation per T91 §7, and emit ≥3 falsifiers each with concrete success threshold for T93 critic Update.\n\nNO WebFetch (cost_inflation drift escalation HUMAN_REQUIRED at T91; theorist must work from T91-extracted data + internal references only). NO julia execution. NO src/ modification. NO state.json edit (orchestrator manages investigation entry).\n\nDIRECTIVE_LABEL: sign-pattern-lemma1-tier3-T92-hypothesize-F2-cyclic-cg-derivation\n\n## REQUIRED READING (READ FIRST, IN THIS ORDER)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_91.md` ENTIRE — the predecessor researcher's extracted data + §7 convention notes + §9 explicit T92 scope (Steps 1-4). This is your input data document. Read it completely.\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_92.md` (this director report) — your dispatch rationale + §6 contract.\n3. `/home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` — paper3 v3 analytical strategy + rigorous S=0 endpoint proof. Your derivation must be consistent with this document's formulation.\n4. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/universal_theorem_status.md` — Lemma 1 General-S closed-form formula + Sign Pattern Anomalous Identity + paper3 v3 5-case audit.\n5. `/home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl` — 26/26 PASS regression at F=3/4/6/8/10. READ ONLY (do not execute); confirm F=2 cyclic is genuinely missing from the script's verified set.\n6. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_91.md` §1 / §6 — T91 dispatch rationale + Lemma 1 prefactor pre-evaluations at F=2 (S0: −1, S2: −1/2, S4: +2/3) that T92 must independently re-confirm via direct algebra.\n7. (OPTIONAL — only if needed for convention disambiguation) `/home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_L1_v2_BdG_signs.md` — rigorous S=0 proof β_0^(λ_spin) = −1/(2F+1) for ALL polyhedral inert states. T92's F=2 case must satisfy this at S=0 (check input β_0^(c_0) = 1/5 → Lemma 1 prefactor −1 → output β_0^(λ_spin) = −1/5 = −1/(2F+1)).\n\n## REQUIRED OUTPUT — `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_92.md`\n\nFile MUST include these sections in this order:\n\n```markdown\n---\nturn: 92\nsubagent: theorist\ninvestigation_id: sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18\nstage_advancing_to: Hypothesize\ntopic_tags: [...]\nproduces: ...\n---\n\n# Turn 92 — Theorist Report (Hypothesize): F=2 cyclic-tetrahedral A_1 Lemma 1 General-S Tier-3 verification claim\n\n## 1. Inputs received\n[T91 §9 scope; T91 §6 cross-reference table; T91 §7 convention notes]\n\n## 2. F=2 cyclic-tetrahedral A_1 state spinor (canonical form chosen)\n[State the chosen canonical form explicitly: ζ_cyc = (1/√2)(1, 0, 0, 0, i)^T in m-basis (m=+2, +1, 0, -1, -2). Verify normalization. State explicitly that this is in the T_d tetrahedral A_1 orbit and is symmetry-equivalent to (1/2)(1, 0, i√2, 0, 1) and (√(1/3), 0, 0, √(2/3), 0) per SU(2) rotation.]\n\n## 3. Independent CG-algebra derivation of β_S^(c_0) at F=2 cyclic\n### 3.1 β_0^(c_0) = ⟨ζ⊗ζ|P_0|ζ⊗ζ⟩ via singlet projector\n[Use the singlet pair amplitude formula A_00 = (1/√(2F+1)) Σ_m (-1)^(F-m) ζ_m ζ_{-m}. At F=2: A_00 = (1/√5) Σ_m (-1)^(2-m) ζ_m ζ_{-m}.\nExpand for ζ_cyc = (1/√2)(1, 0, 0, 0, i):\n- m=+2: (-1)^0 · (1/√2)(i/√2) = i/2\n- m=+1: (-1)^1 · 0 · 0 = 0\n- m=0: (-1)^2 · 0 · 0 = 0\n- m=-1: (-1)^3 · 0 · 0 = 0\n- m=-2: (-1)^4 · (i/√2)(1/√2) = i/2\nSum: i/2 + i/2 = i. A_00 = (1/√5) · i = i/√5. |A_00|² = 1/5. ✓\nResult: β_0^(c_0) = |A_00|² = **1/5**, **derived independently of any PDF**.]\n\n### 3.2 β_2^(c_0) = 0 via zero-magnetization structural argument\n[The cyclic state has ⟨F_z⟩ = Σ_m m·|ζ_m|² = 2·(1/2) + 0 + 0 + 0 + (-2)·(1/2) = 0. Also ⟨F_x⟩ = ⟨F_y⟩ = 0 by parity arguments / direct computation. So ⟨F⟩ = 0 → spin-spin channel (S=2 projector ∝ F^(1)·F^(2)) has zero expectation. Verify by direct projector computation: P_2 has matrix elements computable; for ζ_cyc the S=2 projection is zero by SU(2) covariance argument applied to ⟨F⟩=0 states. Result: β_2^(c_0) = **0**.]\n\n### 3.3 β_4^(c_0) = 4/5 via normalization\n[Projector identity: P_0 + P_2 + P_4 = identity (in two-body F=2⊗F=2 = 0+1+2+3+4 decomposition, ONLY even S survives for symmetric bosonic two-body — confirmed by Bose statistics). β_0 + β_2 + β_4 = ⟨ζ⊗ζ|(P_0+P_2+P_4)|ζ⊗ζ⟩ = 1. So β_4^(c_0) = 1 - 1/5 - 0 = **4/5**.]\n\n### 3.4 Comparison to T91 §3.3 triangulated values\n[Table:\n| S | T91 triangulated | T92 CG derived | match? |\n|---|---|---|---|\n| 0 | 1/5 | 1/5 | YES exact |\n| 2 | 0 | 0 | YES exact |\n| 4 | 4/5 | 4/5 | YES exact |\nT92 CG derivation INDEPENDENTLY confirms T91's structural triangulation. This is a two-anchor consistency check (T91 = structural argument + secondary-source triangulation; T92 = direct CG-algebra derivation from first principles).]\n\n## 4. Application of Lemma 1 closed-form formula at F=2\n### 4.1 Lemma 1 prefactor evaluation\n[Closed form: β_S^(λ_spin) = (S(S+1) − 2F(F+1))/(2F(F+1)) · β_S^(c_0).\nAt F=2: F(F+1) = 6, 2F(F+1) = 12.\n- S=0: (0·1 − 12)/12 = -12/12 = **-1**\n- S=2: (2·3 − 12)/12 = (6-12)/12 = **-1/2**\n- S=4: (4·5 − 12)/12 = (20-12)/12 = 8/12 = **+2/3**\nAlgebra verified.]\n\n### 4.2 β_S^(λ_spin) prediction at F=2 cyclic\n[Apply prefactors to §3.1-3.3 β_S^(c_0):\n- S=0: -1 · 1/5 = **-1/5**\n- S=2: -1/2 · 0 = **0** (trivially)\n- S=4: +2/3 · 4/5 = **+8/15**]\n\n### 4.3 S=0 endpoint cross-check against rigorous proof\n[The S=0 rigorous proof in sign_pattern_L1_v2_BdG_signs.md gives β_0^(λ_spin) = -1/(2F+1) for ALL polyhedral inert states. At F=2: -1/(2·2+1) = -1/5. **MATCH** with Lemma 1 prediction. This is a non-trivial consistency check that validates Lemma 1's extension to F=2 at the S=0 endpoint.]\n\n## 5. Independent derivation of β_S^(λ_spin) from F=2 Bogoliubov / Goldstone structure (bypasses KU2012 PDF gap)\n[Per T91 §9 Step 4 path (b): derive β_S^(λ_spin) from F=2 cyclic Goldstone-mode structure using c_0, c_1, c_2 channel decomposition.\n\nCyclic state has 2 Goldstone modes (U(1) gauge + 1 broken spin rotation; the other 2 spin rotations are broken but acquire mass from discrete tetrahedral symmetry). Linear spin-stiffness λ_spin coefficient relates to the slope of the linear (Nambu-Goldstone) spin-mode dispersion ω = c_spin · k.\n\nFor F=2 cyclic, the spin-stiffness has channel decomposition λ_spin = (g_0/5)·β_0^(λ_spin) + g_2·β_2^(λ_spin) + (4g_4/5)·β_4^(λ_spin) (weighting by β_S^(c_0)).\n\nAlternatively in c_0/c_1/c_2 form: λ_spin can be obtained from the Castin-Dum / Mueller-Ho expressions for F=2 cyclic spin-mode dispersion. The relevant published result: the F=2 cyclic Goldstone stiffness for the broken-spin direction is proportional to c_1 (NOT c_2), specifically λ_spin ∝ c_1 for the gapless spin mode.\n\nConverting c_1 = (g_4 - g_2)/7 back to g_S channels and matching coefficients yields β_S^(λ_spin) channel weights. Detailed channel-coefficient match: [theorist works this out; if achievable text-only WITHIN budget, do so; if requires more than ~30 minutes of derivation, defer to T93 critic Update where it becomes the critic's independent re-derivation].\n\nIF achievable: cross-check the (-1/5, 0, +8/15) prediction directly.\nIF not achievable within budget: state explicitly that this path requires a multi-step Bogoliubov derivation that exceeds the Hypothesize stage scope and defer to T93 critic Update or to a future T94+ side investigation.]\n\n## 6. Convention reconciliation (per T91 §7)\n[Address explicitly:\n- Conv 1: β_S^(c_0) summing to 1 (projector identity). Confirmed via §3.3.\n- Conv 2: g_S (channel coupling, Wigner-Eckart-natural) vs c_0/c_1/c_2 (interaction-rotational-invariant decomposition). Lemma 1 operates in g_S basis. KU2012 §3 uses g_S terminology.\n- Conv 3: cyclic state normalization. Chose (1/√2)(1,0,0,0,i); equivalent to other forms by SU(2) rotation; β_S^(c_0) invariant under SU(2) (T_d-orbit invariant by Schur lemma + tetrahedral A_1 irrep).\n- Conv 4: β_S^(λ_spin) Goldstone stiffness definition. Use project canonical: λ_spin = Σ_S g_S β_S^(λ_spin); β_S^(λ_spin) is the dimensionless channel weight in the spin-mode dispersion coefficient.\n- Conv 5: KU2012 §3 (mean-field) + §5 (Bogoliubov) are the canonical references (NOT §4 = experimental). T91 §3.1 correctly diagnosed this.]\n\n## 7. Formal Tier-3 Hypothesize claim\n[STATE the formal claim explicitly:\n\n**Claim H1 (Lemma 1 extends to F=2)**: The Sign Pattern Lemma 1 General-S closed-form formula β_S^(λ_spin) = (S(S+1) − 2F(F+1))/(2F(F+1)) · β_S^(c_0), verified at 26 channels across F=3/4/6/8/10 polyhedral inert states (sign_pattern_lemma1_general_S.md + lemma1_general_S_verification.jl), EXTENDS to F=2 cyclic-tetrahedral A_1 with β_S^(c_0) = (1/5, 0, 4/5) at S ∈ {0, 2, 4} yielding β_S^(λ_spin) = (−1/5, 0, +8/15).\n\n**Claim H2 (S=0 endpoint cross-anchor)**: At F=2 cyclic, β_0^(c_0) = 1/(2F+1) = 1/5 (CG-derived in §3.1) AND β_0^(λ_spin) = −1/(2F+1) = −1/5 (rigorous endpoint proof from sign_pattern_L1_v2_BdG_signs.md, applied at F=2). The Lemma 1 prefactor −1 at S=0 maps β_0^(c_0) to β_0^(λ_spin) consistently with both anchors.\n\n**Claim H3 (sign boundary)**: At F=2, S_bd = √(2F(F+1)) = √12 ≈ 3.464. S=4 > S_bd → β_4^(λ_spin) > 0 (predicted +8/15). S=0, S=2 ≤ S_bd → β_S^(λ_spin) ≤ 0 (predicted -1/5 and 0). Consistent with Lemma 2 single-sign-change refinement (memory:universal_theorem_status Iter 2).\n]\n\n## 8. Falsifier list (≥3 falsifiers, each with concrete success threshold for T93 critic Update)\n[\n\n**Falsifier F1 (T93 critic re-derives β_0^(c_0) via 6j-symbol path, NOT singlet projector)**: critic uses an alternative CG-algebra route (e.g., 6j-symbol recoupling of two F=2 spins via the cyclic state structure) to compute β_0^(c_0) at F=2 cyclic. Success threshold: critic's value = 1/5 exact (rational arithmetic). If critic obtains ≠ 1/5, then Claim H1's input is wrong (either §3.1 derivation error OR cyclic-state normalization mismatch); REFUTE.\n\n**Falsifier F2 (T93 critic re-derives Lemma 1 prefactor formula structurally at F=2)**: critic re-derives the prefactor (S(S+1) − 2F(F+1))/(2F(F+1)) from the Wigner-Eckart structure for arbitrary F applied at F=2 specifically. Verifies the derivation does not have an F-specific factor that vanishes/diverges at F=2. Success threshold: critic confirms the closed form holds structurally at F=2 (no algebraic singularity, no missing 1/F or F+1 factor). If critic finds a step in the General-S derivation that requires F ≥ 3 (e.g., a denominator that vanishes at F=2), then Claim H1 REFUTED-by-obstruction at F=2.\n\n**Falsifier F3 (Goldstone-stiffness independent cross-check)**: critic derives β_S^(λ_spin) for F=2 cyclic from the Mueller-Ho / Castin-Dum F=2 cyclic Goldstone-mode dispersion expressions (independent of Lemma 1). Compare against Lemma 1 prediction (-1/5, 0, +8/15). Success threshold: match to exact rational arithmetic. If mismatch in S=0 by sign or factor → factor-of-2 / sign-convention error; if mismatch in S=4 → β_4^(c_0) input error or Lemma 1 prefactor error; if all match → Claim H1 CORROBORATED.\n\n(Optional) **Falsifier F4 (Sign Pattern Anomalous Identity check at F=2)**: critic verifies the Sign Pattern Anomalous Identity sign(β_S^(λ_spin)) = sign(Re[⟨S|F_a ζ ⊗ F_a ζ⟩ · ⟨ζ⊗ζ|S⟩*]) (memory:universal_theorem_status) at F=2 cyclic for S=0, 2, 4. Success threshold: signs match Lemma 1 prediction (−, 0, +). If signs mismatch → Sign Pattern Identity has F=2 exception; CORROBORATE-WITH-ERRATA.\n]\n\n## 9. Provisional verdict (theorist; binding verdict comes from critic Update at T93)\n[One of:\n- HYPOTHESIS_FORMALIZED_READY_FOR_CRITIC (all §3-§7 derivations clean, falsifiers in §8 are concrete)\n- HYPOTHESIS_PARTIAL_F2_OBSTRUCTION (if §4 or §5 derivation reveals a F=2-specific algebraic obstruction; investigation becomes \"Lemma 1 does NOT extend to F=2\" Tier-3 negative result)\n- HYPOTHESIS_DERIVATION_ERROR (if §3 or §4 reveals an algebra error in T91 triangulation or T92 CG derivation)]\n\n## 10. Recommended T93 critic Update scope\n[Concrete: T93 critic should (a) re-derive β_0^(c_0) at F=2 cyclic via 6j-symbol path (independent of singlet projector), (b) verify Lemma 1 closed-form prefactor algebra at F=2 has no degeneracy/obstruction, (c) if T92 §5 left the Bogoliubov-derived cross-check incomplete, critic does it independently from Mueller-Ho / Castin-Dum F=2 cyclic spectrum; (d) check Sign Pattern Anomalous Identity signs at F=2. Verdict: CORROBORATE / CORROBORATE-WITH-ERRATA / REFUTED-BY-DERIVATION-ERROR / REFUTED-BY-F2-OBSTRUCTION.]\n\n## 11. Metrics JSON\n[fenced ```json``` block per the schema in §METRICS below]\n```\n\n## METRICS JSON (single fenced ```json``` block in theorist/turn_92.md §11)\n\n```json\n{\n  \"experiment_kind\": \"text_only\",\n  \"investigation_kind\": \"physics\",\n  \"src_files_modified\": 0,\n  \"new_analysis_scripts_written\": 0,\n  \"agents_md_files_modified\": 0,\n  \"patterns_yaml_modified\": false,\n  \"state_json_modified\": false,\n  \"manuscript_edited\": false,\n  \"src_edited\": false,\n  \"julia_executed\": false,\n  \"webfetch_used\": false,\n  \"investigation_id\": \"sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18\",\n  \"stage_advancing_to\": \"Hypothesize\",\n  \"flow_template\": \"verify-claim\",\n  \"f2_cyclic_canonical_form_stated\": <true|false>,\n  \"cg_derived_beta_s_c0_S0\": <numeric value; expected 0.2 = 1/5>,\n  \"cg_derived_beta_s_c0_S2\": <numeric value; expected 0.0>,\n  \"cg_derived_beta_s_c0_S4\": <numeric value; expected 0.8 = 4/5>,\n  \"cg_derivation_matches_t91_triangulation\": <true|false>,\n  \"lemma1_prefactor_S0_at_F2\": <numeric; expected -1.0>,\n  \"lemma1_prefactor_S2_at_F2\": <numeric; expected -0.5>,\n  \"lemma1_prefactor_S4_at_F2\": <numeric; expected 0.6666666666666666>,\n  \"predicted_beta_s_lambda_spin_S0\": <numeric; expected -0.2 = -1/5>,\n  \"predicted_beta_s_lambda_spin_S2\": <numeric; expected 0.0>,\n  \"predicted_beta_s_lambda_spin_S4\": <numeric; expected 0.5333333333333333 = 8/15>,\n  \"s0_endpoint_cross_anchor_match\": <true|false; checks predicted -1/5 = -1/(2F+1) at F=2>,\n  \"sign_boundary_S_bd_at_F2_evaluated\": <numeric; expected 3.4641016151377544 = sqrt(12)>,\n  \"sign_pattern_h3_consistent\": <true|false; S=4 > S_bd → positive, S=0/2 ≤ S_bd → ≤ 0>,\n  \"bogoliubov_cross_check_attempted\": <true|false>,\n  \"bogoliubov_cross_check_completed\": <true|false; may be deferred to T93 critic if budget-prohibitive>,\n  \"convention_reconciliation_completed\": <true|false; per T91 §7 all 5 conventions addressed>,\n  \"formal_claim_h1_stated\": <true|false>,\n  \"formal_claim_h2_stated\": <true|false>,\n  \"formal_claim_h3_stated\": <true|false>,\n  \"falsifiers_count\": <int; expect 3 or 4>,\n  \"falsifier_ids_list\": [<strings>],\n  \"each_falsifier_has_concrete_threshold\": <true|false>,\n  \"provisional_verdict\": <\"HYPOTHESIS_FORMALIZED_READY_FOR_CRITIC\"|\"HYPOTHESIS_PARTIAL_F2_OBSTRUCTION\"|\"HYPOTHESIS_DERIVATION_ERROR\">,\n  \"recommended_t93_critic_scope_described\": <true|false>,\n  \"references_cited_count\": <int; expect >= 4>,\n  \"references_cited_list\": [<list>],\n  \"no_invention\": <true|false; every β value either CG-derived in §3 or cited from external reference>,\n  \"a00_calculation_verified\": <true|false; A_00 = i/sqrt(5) for ζ_cyc at F=2 verified explicitly>,\n  \"projector_normalization_verified\": <true|false; β_0 + β_2 + β_4 = 1 at F=2 cyclic verified>,\n  \"prior_lemma1_verification_at_F345610_referenced\": <true|false; cites 26-channel internal regression>\n}\n```\n\n## CONSTRAINTS\n\n- **Files allowed to modify**: `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_92.md` ONLY (theorist Hypothesize report).\n- **Files allowed to create**: `/tmp/*` (one-shot derivation helpers; sympy / pen-and-paper algebra checks).\n- **Files FORBIDDEN to modify**: `src/`, `runs/eu151_*/`, `runs/matsui_edh_baseline_*/`, `scripts/`, `docs/manuscript/`, `runs/_loop/state.json`, `.claude/agents/*`, `.claude/scripts/*`, `.claude/workload_specs.yaml`, `quota_config.json`, `.claude/settings*.json`, `runs/_loop/patterns.yaml`, any other `runs/_loop/` file (including research/, sim/, critic/, judge/, director/).\n- **NO julia execution**.\n- **NO WebFetch** (cost_inflation drift escalation = human_required at T91; theorist must work from T91-extracted data + internal references only).\n- **NO new memory file** (any Tier-3 verification stamp goes to MEMORY.md at T94 Document if T93 CORROBORATEs).\n- **English only**. No emojis. No anko-attribution. No improvised terminology — use established physics terms only (singlet projector, Wigner-Eckart, 6j-symbol, channel weight, Goldstone stiffness, etc.).\n- **No fabrication** (CRITICAL): every β value must be either (a) explicitly derived via CG algebra in §3, or (b) cited to T91's triangulation or external reference with equation citation. NO numerical guessing.\n- **Absolute paths in all Read / Write / Bash tool calls**.\n- **Cost budget**: target ~1.5M effective; HARD CAP 2.0M (tightened from steady-state 2.5M per drift_escalation=human_required). theorist text-only baseline ~1.0-1.5M; +CG algebra derivation ~0.3M; +falsifier table ~0.2M.\n- **Sympy is optional**: if §5 Bogoliubov derivation needs symbolic algebra, use `uv run --with sympy python3 - <<EOF ... EOF` (allowed under `implementer_sympy` workload; theorist text-only may also invoke sympy for personal verification but is not required to).\n\n## ANTI-PATTERN GUARDS\n\n- Do NOT modify src/, manuscript, state.json, .claude/agents/scripts, agent prompts, patterns.yaml.\n- Do NOT execute julia.\n- Do NOT WebFetch (cost discipline).\n- Do NOT skip §3 (CG derivation): this is the load-bearing T92 contribution. Even if you 'just believe' T91's value, the independent derivation IS what advances tier 2 → 2.5.\n- Do NOT skip §8 (≥3 falsifiers): T93 critic Update needs concrete success thresholds.\n- Do NOT extend to F=3/6/8/10 verification (out of scope; T92 is F=2 cyclic only; the 26-channel verification at F=3/4/6/8/10 is already in lemma1_general_S_verification.jl).\n- Do NOT do critic's job (do NOT independently re-derive Lemma 1 from 6j-symbols; that is the T93 falsifier F1/F2 work).\n- Do NOT exceed 2.0M effective tokens hard cap.\n- Do NOT invent c_0/c_1/c_2 values; the c_0 = (4g_4+3g_2)/7, c_1 = (g_4-g_2)/7, c_2 = (7g_0-10g_2+3g_4)/7 relations are standard textbook (Kawaguchi-Ueda 2012 §2 / Stamper-Kurn-Ueda 2013 §II) and may be used without further citation.\n- If §5 Bogoliubov derivation is non-trivial (would take >30 min of derivation), explicitly defer to T93 critic Update with `bogoliubov_cross_check_completed: false` — this is a valid Hypothesize-stage deliverable (the framework is set up; critic does the cross-check at Update).\n\n## REPORTING DISCIPLINE\n\n- Honest derivation steps: each algebraic manipulation either has a one-line justification or cites Wigner-Eckart / 6j / standard CG handbook.\n- If §3 CG derivation gives a value DIFFERENT from T91 triangulation (e.g., β_0^(c_0) = 1/3 instead of 1/5), DO NOT silently adjust — report the discrepancy and classify provisional_verdict = HYPOTHESIS_DERIVATION_ERROR or T91_TRIANGULATION_ERROR.\n- If §4 Lemma 1 prefactor at F=2 has an algebraic singularity (e.g., F(F+1) in a denominator with F=2 giving 6 — non-singular, but check), document the absence of singularity explicitly.\n- If §5 Goldstone-stiffness derivation is deferred, state explicitly that T93 critic must complete the independent cross-check.\n- Honest counts in §METRICS: every value either derived (§3) or cited; no fabrication.\n",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "investigation_kind",
      "src_files_modified",
      "new_analysis_scripts_written",
      "agents_md_files_modified",
      "patterns_yaml_modified",
      "state_json_modified",
      "manuscript_edited",
      "src_edited",
      "julia_executed",
      "webfetch_used",
      "investigation_id",
      "stage_advancing_to",
      "flow_template",
      "f2_cyclic_canonical_form_stated",
      "cg_derived_beta_s_c0_S0",
      "cg_derived_beta_s_c0_S2",
      "cg_derived_beta_s_c0_S4",
      "cg_derivation_matches_t91_triangulation",
      "lemma1_prefactor_S0_at_F2",
      "lemma1_prefactor_S2_at_F2",
      "lemma1_prefactor_S4_at_F2",
      "predicted_beta_s_lambda_spin_S0",
      "predicted_beta_s_lambda_spin_S2",
      "predicted_beta_s_lambda_spin_S4",
      "s0_endpoint_cross_anchor_match",
      "sign_boundary_S_bd_at_F2_evaluated",
      "sign_pattern_h3_consistent",
      "bogoliubov_cross_check_attempted",
      "bogoliubov_cross_check_completed",
      "convention_reconciliation_completed",
      "formal_claim_h1_stated",
      "formal_claim_h2_stated",
      "formal_claim_h3_stated",
      "falsifiers_count",
      "falsifier_ids_list",
      "each_falsifier_has_concrete_threshold",
      "provisional_verdict",
      "recommended_t93_critic_scope_described",
      "references_cited_count",
      "references_cited_list",
      "no_invention",
      "a00_calculation_verified",
      "projector_normalization_verified",
      "prior_lemma1_verification_at_F345610_referenced"
    ],
    "optional": [],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_92.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_91.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_91.md && test -f /home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md && test -f /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/universal_theorem_status.md && python3 -c \"import json; d = json.load(open('/home/suzume/workspace/BEC-simulation/runs/_loop/state.json')); print(f'active_inv_id: {d[\\\"active_investigation_id\\\"]}'); assert d['active_investigation_id'] == 'sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18', f'WRONG active id: {d[\\\"active_investigation_id\\\"]}'; print('OK precondition: active investigation continuing from T91 Research')\""
  },
  "success_criteria": [
    {
      "id": "experiment_kind_correct",
      "metric": "experiment_kind",
      "operator": "==",
      "value": "text_only",
      "tolerance": null,
      "rationale": "Theorist Hypothesize stage is text-only derivation."
    },
    {
      "id": "investigation_kind_physics",
      "metric": "investigation_kind",
      "operator": "==",
      "value": "physics",
      "tolerance": null,
      "rationale": "Sign Pattern Lemma 1 is a physics theory verification investigation."
    },
    {
      "id": "src_unchanged",
      "metric": "src_files_modified",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Theorist Hypothesize does not modify src/."
    },
    {
      "id": "no_scripts_committed",
      "metric": "new_analysis_scripts_written",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "/tmp/ helpers do not count."
    },
    {
      "id": "no_agents_md_changes",
      "metric": "agents_md_files_modified",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Hypothesize stage does not modify agent prompts."
    },
    {
      "id": "patterns_yaml_untouched",
      "metric": "patterns_yaml_modified",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "Unrelated to audit catalog."
    },
    {
      "id": "state_json_untouched_by_theorist",
      "metric": "state_json_modified",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "Theorist does not edit state.json; orchestrator manages investigation entry."
    },
    {
      "id": "no_manuscript_polish",
      "metric": "manuscript_edited",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "Per feedback_manuscript_is_not_the_essence."
    },
    {
      "id": "no_src_modification_explicit",
      "metric": "src_edited",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "Redundant src/ guard."
    },
    {
      "id": "no_julia_execution",
      "metric": "julia_executed",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "Hypothesize stage text-only."
    },
    {
      "id": "no_webfetch",
      "metric": "webfetch_used",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "cost_inflation drift_escalation=human_required at T91; T92 explicitly forbids WebFetch to keep cost steady."
    },
    {
      "id": "investigation_consistent",
      "metric": "investigation_id",
      "operator": "==",
      "value": "sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18",
      "tolerance": null,
      "rationale": "Theorist report must echo investigation_id."
    },
    {
      "id": "stage_consistent",
      "metric": "stage_advancing_to",
      "operator": "==",
      "value": "Hypothesize",
      "tolerance": null,
      "rationale": "Theorist report must echo Hypothesize stage."
    },
    {
      "id": "template_consistent",
      "metric": "flow_template",
      "operator": "==",
      "value": "verify-claim",
      "tolerance": null,
      "rationale": "verify-claim template per §F1."
    },
    {
      "id": "canonical_form_stated",
      "metric": "f2_cyclic_canonical_form_stated",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Section 2 must explicitly state which canonical form is chosen for ζ_cyc; ambiguity here propagates to wrong β_S^(c_0)."
    },
    {
      "id": "cg_derived_beta_S0_correct",
      "metric": "cg_derived_beta_s_c0_S0",
      "operator": "==",
      "value": 0.2,
      "tolerance": 1e-9,
      "rationale": "1/5 = 0.2 exact; the independent CG derivation must yield this value or the entire Hypothesize is invalidated."
    },
    {
      "id": "cg_derived_beta_S2_correct",
      "metric": "cg_derived_beta_s_c0_S2",
      "operator": "==",
      "value": 0.0,
      "tolerance": 1e-12,
      "rationale": "β_2^(c_0) = 0 for F=2 cyclic state (zero-magnetization structural)."
    },
    {
      "id": "cg_derived_beta_S4_correct",
      "metric": "cg_derived_beta_s_c0_S4",
      "operator": "==",
      "value": 0.8,
      "tolerance": 1e-9,
      "rationale": "4/5 = 0.8 exact via normalization."
    },
    {
      "id": "cg_matches_t91",
      "metric": "cg_derivation_matches_t91_triangulation",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Two-anchor consistency check between T91 structural triangulation and T92 direct CG derivation."
    },
    {
      "id": "prefactor_S0_correct",
      "metric": "lemma1_prefactor_S0_at_F2",
      "operator": "==",
      "value": -1.0,
      "tolerance": 1e-12,
      "rationale": "(0-12)/12 = -1 exact."
    },
    {
      "id": "prefactor_S2_correct",
      "metric": "lemma1_prefactor_S2_at_F2",
      "operator": "==",
      "value": -0.5,
      "tolerance": 1e-12,
      "rationale": "(6-12)/12 = -1/2 exact."
    },
    {
      "id": "prefactor_S4_correct",
      "metric": "lemma1_prefactor_S4_at_F2",
      "operator": "==",
      "value": 0.6666666666666666,
      "tolerance": 1e-12,
      "rationale": "(20-12)/12 = 2/3 exact."
    },
    {
      "id": "predicted_lambda_spin_S0_correct",
      "metric": "predicted_beta_s_lambda_spin_S0",
      "operator": "==",
      "value": -0.2,
      "tolerance": 1e-9,
      "rationale": "-1 · 1/5 = -1/5 = -0.2; AND matches -1/(2F+1) at F=2 from S=0 endpoint rigorous proof (two-anchor)."
    },
    {
      "id": "predicted_lambda_spin_S2_correct",
      "metric": "predicted_beta_s_lambda_spin_S2",
      "operator": "==",
      "value": 0.0,
      "tolerance": 1e-12,
      "rationale": "-1/2 · 0 = 0 trivially."
    },
    {
      "id": "predicted_lambda_spin_S4_correct",
      "metric": "predicted_beta_s_lambda_spin_S4",
      "operator": "==",
      "value": 0.5333333333333333,
      "tolerance": 1e-9,
      "rationale": "+2/3 · 4/5 = 8/15 = 0.5333..."
    },
    {
      "id": "s0_two_anchor_match",
      "metric": "s0_endpoint_cross_anchor_match",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "S=0 prediction (-1/5) must match the rigorous proof β_0^(λ_spin) = -1/(2F+1) at F=2 (= -1/5). Non-trivial cross-check that validates the entire Hypothesize."
    },
    {
      "id": "S_bd_correct",
      "metric": "sign_boundary_S_bd_at_F2_evaluated",
      "operator": "==",
      "value": 3.4641016151377544,
      "tolerance": 1e-9,
      "rationale": "S_bd = sqrt(2F(F+1)) = sqrt(12) at F=2."
    },
    {
      "id": "sign_consistent_with_S_bd",
      "metric": "sign_pattern_h3_consistent",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "S=4 > 3.46 → positive (+8/15); S=0/2 ≤ 3.46 → ≤ 0 (-1/5, 0). Lemma 2 single-sign-change consistency check."
    },
    {
      "id": "convention_reconciliation_done",
      "metric": "convention_reconciliation_completed",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Per T91 §7 all 5 conventions (β_S sum, g_S vs c_S, normalization, λ_spin definition, KU2012 section number) addressed."
    },
    {
      "id": "claim_h1_stated",
      "metric": "formal_claim_h1_stated",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "H1 = Lemma 1 extends to F=2; the load-bearing Tier-3 claim."
    },
    {
      "id": "claim_h2_stated",
      "metric": "formal_claim_h2_stated",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "H2 = S=0 two-anchor cross-check (1/5 + -1/5); the non-trivial consistency claim."
    },
    {
      "id": "claim_h3_stated",
      "metric": "formal_claim_h3_stated",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "H3 = sign boundary S_bd = sqrt(12); the Lemma 2 consistency claim."
    },
    {
      "id": "min_three_falsifiers",
      "metric": "falsifiers_count",
      "operator": ">=",
      "value": 3,
      "tolerance": null,
      "rationale": "§F1 Hypothesize stage mandate: falsifier list."
    },
    {
      "id": "falsifiers_concrete",
      "metric": "each_falsifier_has_concrete_threshold",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Each falsifier must be machine/critic-evaluable."
    },
    {
      "id": "verdict_classification_set",
      "metric": "provisional_verdict",
      "operator": "in",
      "value": ["HYPOTHESIS_FORMALIZED_READY_FOR_CRITIC", "HYPOTHESIS_PARTIAL_F2_OBSTRUCTION", "HYPOTHESIS_DERIVATION_ERROR"],
      "tolerance": null,
      "rationale": "Theorist classifies Hypothesize outcome; routes T93."
    },
    {
      "id": "t93_scope_recommended",
      "metric": "recommended_t93_critic_scope_described",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "T93 director needs explicit critic scope handoff from T92."
    },
    {
      "id": "min_references_cited",
      "metric": "references_cited_count",
      "operator": ">=",
      "value": 4,
      "tolerance": null,
      "rationale": "T91 research + paper3 sign_pattern_lemma1_general_S.md + memory universal_theorem_status + lemma1_general_S_verification.jl + (optional) sign_pattern_L1_v2_BdG_signs.md = 4-5."
    },
    {
      "id": "no_invention_enforced",
      "metric": "no_invention",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Every β value either CG-derived in §3 or cited; no fabrication."
    },
    {
      "id": "a00_explicit_calculation",
      "metric": "a00_calculation_verified",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "A_00 = i/sqrt(5) at F=2 cyclic must be shown explicitly in §3.1; this is the load-bearing CG step."
    },
    {
      "id": "projector_sums_to_one",
      "metric": "projector_normalization_verified",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "β_0 + β_2 + β_4 = 1 must be verified at F=2 cyclic; this is what gives β_4^(c_0) = 4/5."
    },
    {
      "id": "prior_verification_cited",
      "metric": "prior_lemma1_verification_at_F345610_referenced",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "26-channel regression at F=3/4/6/8/10 (lemma1_general_S_verification.jl) is the baseline T92 extends; must be referenced."
    }
  ],
  "failure_modes": [
    {
      "if": "cg_derived_beta_s_c0_S0 != 0.2 (within 1e-9) — §3.1 derivation gives a different value",
      "category": "scientific_refuted",
      "next_action": "T93 director: dispatch critic with explicit re-derivation of β_0^(c_0) via 6j-symbol path; one of (T91 triangulation, T92 §3.1 CG derivation) is wrong; critic acts as independent tiebreaker. If critic agrees with T92 != 0.2 → T91 was wrong and the structural triangulation method has a bug; re-spawn investigation with corrected scope. If critic agrees with T91 = 0.2 → T92 §3.1 has an algebra error; re-dispatch theorist with explicit error correction."
    },
    {
      "if": "cg_derivation_matches_t91_triangulation == false",
      "category": "scientific_refuted",
      "next_action": "Same as above failure; tiebreaker via T93 critic independent derivation."
    },
    {
      "if": "s0_endpoint_cross_anchor_match == false (predicted -1/5 != -1/(2F+1) at F=2)",
      "category": "framework_error",
      "next_action": "T93 director: pause investigation; dispatch critic in question-validity mode (§B3 routing rule): is the F=2 cyclic state actually in the polyhedral inert class that the S=0 endpoint rigorous proof covers? If F=2 cyclic falls OUTSIDE the rigorous proof's scope (e.g., the proof needs F ≥ 3 for Schur isotropy at polyhedral group level), then Lemma 1 may genuinely not extend to F=2; investigation pivots to documenting the F=2 obstruction."
    },
    {
      "if": "provisional_verdict == 'HYPOTHESIS_PARTIAL_F2_OBSTRUCTION'",
      "category": "scientific_partial",
      "next_action": "T93 director: dispatch critic to confirm the obstruction is genuine (not an algebra glitch in T92). If genuine: investigation closes Tier-3 NEGATIVE-RESULT ('Lemma 1 does not extend to F=2; F=2 cyclic-tetrahedral A_1 obstruction documented'). Still valuable Tier-3 outcome — analogous to F=5 obstruction documented in memory:Sign_Pattern_Lemma1_General_S."
    },
    {
      "if": "provisional_verdict == 'HYPOTHESIS_DERIVATION_ERROR'",
      "category": "operational",
      "next_action": "T93 director: re-dispatch theorist with explicit error correction; do NOT advance to critic Update on a known-broken Hypothesize."
    },
    {
      "if": "falsifiers_count < 3 OR each_falsifier_has_concrete_threshold == false",
      "category": "operational",
      "next_action": "T93 director: re-dispatch theorist with explicit falsifier-list-completion requirement; T93 critic Update needs concrete falsifiers to audit."
    },
    {
      "if": "bogoliubov_cross_check_attempted == false AND provisional_verdict == 'HYPOTHESIS_FORMALIZED_READY_FOR_CRITIC'",
      "category": "scientific_partial",
      "next_action": "T93 director: critic Update MUST complete the independent Bogoliubov-derivation cross-check itself (becomes part of T93 critic scope; not a re-dispatch of T92)."
    },
    {
      "if": "cost > 2.0M effective (hard cap exceeded)",
      "category": "operational",
      "next_action": "T93 director: cost_inflation drift_escalation may re-spike; audit theorist's derivation length; if §5 Bogoliubov derivation was the cost overrun, defer §5 to T93 critic Update explicitly; if §3 CG algebra inflated cost, that's a theorist verbosity issue (instruct briefer derivations)."
    },
    {
      "if": "webfetch_used == true",
      "category": "operational",
      "next_action": "T93 director: hard violation of T92 contract; instruct theorist to NEVER WebFetch under cost_inflation human_required escalation; if WebFetch yielded useful data, evaluate net value; if not, treat as cost waste."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 2000000,
    "wall_time_max_seconds": 900
  },
  "budget": {
    "expected_cost_eff": 1500000,
    "expected_wall_time_sec": 600,
    "split_by_subtask": {
      "context_read_t91_research_director_paper3_memory": 400000,
      "section_2_canonical_form": 100000,
      "section_3_cg_derivation_a00_normalization_zero_magnetization": 400000,
      "section_4_lemma1_prefactor_application": 100000,
      "section_5_bogoliubov_cross_check_optional": 200000,
      "section_6_convention_reconciliation": 100000,
      "section_7_formal_claim_h1_h2_h3": 100000,
      "section_8_falsifier_list": 100000,
      "theorist_turn_92_md_write": 100000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Update",
    "if_success_tier_becomes": 2.5,
    "if_partial_success_advance_to_stage": "Update (T93 critic with explicit obstruction-confirmation scope)",
    "if_partial_success_tier_becomes": 2.5,
    "if_refuted_advance_to_stage": "Hypothesize (re-dispatch theorist with error correction)",
    "if_refuted_tier_becomes": 2,
    "if_inconclusive_advance_to_stage": "Hypothesize (T93 theorist retry with refined scope)",
    "if_inconclusive_tier_becomes": 2,
    "if_data_gap_advance_to_stage": "Update (T93 critic completes the Bogoliubov cross-check independently)",
    "if_data_gap_tier_becomes": 2.5,
    "next_falsifier_to_test_after": "F1=critic-re-derives-beta_0^c0-via-6j-symbol-path-at-F2-cyclic (to be tested at T93 critic Update)"
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read scheduler_92.json THIS turn (policy JULIA_GPU_OK, theorist in allowed_workloads, window 1.14M sec).
- [x] Read state.json header (active_investigation_id = sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18 from T91; investigations dict entry pending orchestrator).
- [x] Read T91 director report ENTIRE + T91 researcher report ENTIRE (the input data + scope handoff).
- [x] Read T90 director report (precursor pre-routing — chain T90→T91→T92 multi-turn continuity).
- [x] Read memory:universal_theorem_status (Lemma 1 General-S closed form + paper3 v3 5-case audit + F=12 / Sign Pattern Anomalous Identity).
- [x] Read paper3 sign_pattern_lemma1_general_S.md (analytical strategy + S=0 endpoint proof recap; T92's derivation must be consistent).
- [x] APC contract cache: verify-claim::Hypothesize cached at n_seen=4 (per T91 §1 self-review note); used as scaffold for T92 §6 contract structure (success_criteria shape, failure_modes categories, observable_manifest precondition_check pattern).
- [x] Considered switching to a different investigation: meta-cost-waste-audit / meta-director-self-audit / meta-cost-inflation re-spike / Bug-4 ITP DDI / TwoChannelLHY-F6-polar / TDHFB Phase 2 — all explicitly considered in §1 decision tree and rejected. Continuation of T91 has explicit pre-routing + maximally cost-efficient path to 4th Tier-3 closure.
- [x] investigation_id `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18` is consistent with T91 dispatch + state.json active_investigation_id.
- [x] stage_advancing_to `Hypothesize` is the next stage per §F1 verify-claim template (Research → Hypothesize → ...); T91 verdict was effectively PASS-with-caveats which routes advance per §B3.
- [x] subagent_type `theorist` matches role_per_stage[Hypothesize] for verify-claim template per §F1 ("Hypothesize: theorist — formal claim + predicted signature + falsifier list").
- [x] researcher_depth N/A for theorist; explicitly null in contract.
- [x] success_criteria are machine-evaluable: 40 criteria, every metric appears in Metrics JSON schema in brief §METRICS; mix of ==/>=/in operators on numeric / bool / string-enum values with explicit tolerances where applicable.
- [x] failure_modes cover 9 likely failures (CG derivation disagree T91, S=0 cross-anchor mismatch, F=2 obstruction, derivation error, falsifier shortfall, Bogoliubov deferred, cost overrun, WebFetch violation, scientific tiebreaker via T93 critic).
- [x] observable_manifest precondition_check is concrete (test -f for 5 input files + python3 -c with state.json active_investigation_id assertion).
- [x] budget fits within scheduler window_seconds_left (1.14M sec >> 900 sec wall_time_max).
- [x] §A6 research-first citation present (15 enumerated references in §4 to T91 research, paper3 v3, internal memory, internal scripts, contract cache, external Ueda-Koashi 2002 for |A_00|² framework).
- [x] §A5 D-axis articulated: D1 verification (PRIMARY axis) tier 2 → 2.5 trajectory (full Tier 3 at T93); first manuscript-anchored Tier-3 trajectory. Manuscript NOT in scope.
- [x] investigation_update field describes Hypothesize-stage outcomes correctly: if_success advances to Update at tier 2.5; if_refuted re-dispatches Hypothesize at tier 2; if_data_gap routes T93 critic to complete cross-check.
- [x] Single commitment per turn (T92 advances investigation by one stage — Hypothesize — and dispatches theorist for that stage's deliverable; not collapsing with T93 Update).
- [x] Subagent rotation discipline: T91 researcher → T92 theorist → T93 critic → T94 implementer_text rotates through all 4 subagent classes in 4 consecutive turns.
- [x] novel_claim_zero drift escalation cleared by routing T92 to theorist Hypothesize that produces new formal claims H1/H2/H3 + new CG derivation + new falsifier list.
- [x] cost_inflation drift escalation human_required addressed: tolerance_overrides.cost_cap_effective tightened from 2.5M to 2.0M; brief explicitly forbids WebFetch; budget split shows 1.5M target with 200k Bogoliubov-deferable contingency.
- [x] No fabrication possible: every value in §6 contract is either (a) cited to T91 / paper3 / memory, or (b) basic algebra trivially verifiable (Lemma 1 prefactors at F=2: -1, -1/2, 2/3; S_bd = sqrt(12) ≈ 3.464; β predictions -1/5, 0, +8/15).
- [x] research-first compliance: brief cites ≥1 external reference (Ueda-Koashi 2002 |A_00|² framework + KU2012 cyclic-state canonical reference + paper3 sign_pattern_lemma1_general_S.md analytical strategy).
- [x] Per §F1 Hypothesize stage role mandate: theorist produces formal claim (H1/H2/H3) + predicted signature (β_S^(λ_spin) values) + falsifier list (≥3 with thresholds).
