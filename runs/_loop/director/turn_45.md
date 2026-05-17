---
turn: 45
subagent: director
investigation_id: yan-li-saito-2026-reproduction
stage_advancing_from: Execute
stage_advancing_to: Update
topic_tags: [yan-li-saito-2026, r2-fl-vortex-refuted, seed-topology-not-sufficient, m-relaxation-incomplete, lhy-chi-branch-suspect, r3-vs-r4-routing-decision, critic-update-lats-reflect]
paper_section: null
depends_on: [44, 43, 42, 40, 37, "runs/_loop/director/turn_44.md", "runs/_loop/theorist/turn_44.md", "runs/_loop/sim/turn_44.md", "runs/_loop/judge/turn_44.json", "runs/_loop/judge/turn_43_critic_audit.md", "runs/_loop/sim/turn_40.md", "memory:yan_li_saito_2026_barnett_paper"]
produces: "Critic Update memo (runs/_loop/judge/turn_45_critic_audit.md): independent audit of T44 R2_b REFUTE (n_max=3.09 D₀ from fl_vortex seed at dx=0.125); robustness check of confounder-elimination claim; R3 vs R4 routing recommendation with quantitative tier transition; flag of LHY χ(ε_dd=1.18) branch as next-most-probable root cause."
---

# Turn 45 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `yan-li-saito-2026-reproduction` (priority 1, tier_current 0.75; T37→T44 cascade continuing).
- **Stage transition**: **Execute → Update** per §F1 verify-claim. T44 implementer's `falsification_result: "REFUTED"` (sim/turn_44.md §4 metrics + §7 falsification table) is the substantive verdict; per §B3 mapping `REFUTED (scientific) → Update`. The judge `INCONCLUSIVE` at turn_44.json is an evaluator-coupling artifact (T44 implementer metrics were judged against T44-director's theorist-Hypothesize success_criteria from T43-director — wrong contract; same evaluator-quirk class as turn_43.json and turn_20.json).
- **Tier**: 0.75 → 0.70 (provisional, pending critic confirmation; R2_b REFUTE was the expected next worst-case branch per theorist H3, not a free fall; tier loss is mild because the cascade is converging on a clear answer).
- **Falsifiers tested/refuted**:
  - `f1-direct-reproduction` (T37) FALSIFIED.
  - T40 5-pt seed-basin: (b) density-basin + (a2) topology-axis (coarse grid) REFUTED.
  - T42 critic CORROBORATEd grid-resolution; closed DDI bit-equal.
  - T43 Execute REFUTED Form (B) at dx=0.125 with spherical-m=+1 seed (n_max=2.00 D₀).
  - T43 critic Update identified seed-topology + c1=0 + slow DDI off-diagonal mixing CONFOUNDER → routed R2.
  - **T44 Execute REFUTED** R2 fl_vortex hypothesis: **n_max=3.09 D₀** (1.5× the spherical-seed baseline, but 32× below PASS threshold 100 D₀ and 3× below the REFUTE-edge 10 D₀). Topology preserved throughout ITP (F_z=-1e-6, L_z=3e-6, m-populations symmetric). Spin texture evolved (0.25, 0.50, 0.25) → (0.375, 0.250, 0.375) — **partial m=0 relaxation** (NOT the full (0.5, 0, 0.5) Mermin-Ho equilibrium observed at T40 P4's coarse grid in 5000 steps). E_LHY/E_contact = 2.2× (qualitative change from T43 delocalized state). Topology IS sufficient to encode flux-closure structure (mu_final=0.316 vs 0.120 for spherical; finite E_kin=0.009 from vortex phase) but NOT sufficient to drive self-binding at dx=0.125.
- **Other in-flight investigations**:
  - `barnett-mechanism-2026-05-16`: closed Tier 3.0.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3, blocked on julia P3 validation): yan-li-saito priority 1 cascade still mid-flight; defer.
  - `fullbdg-f6-polar-3000x` (priority 99, dormant): contained.
  - `meta-critic-placement-2026-05-17` (priority 50, Observe): accumulating evidence (T43 critic flagged judge-evaluator-coupling quirk; T44 judge fired AGAIN with the same class). §B2 interleaving rule: still defer; the meta is gaining ammunition from the cascade itself.
  - `meta-stage-routing-2026-05-18` (priority 25, kind=meta, Observe, **AUTO-SPAWNED at T44** per `auto_spawned_by_trigger: same_stage_fail_streak`): drift-detector reported 3+ FAIL/INCONCLUSIVE in last 4 turns (T40 INCONCLUSIVE, T43 FAIL_NUMERICAL, T44 INCONCLUSIVE). I acknowledge the trigger but the actual root cause of all 3 is the **same judge-evaluator-coupling quirk** plus genuine scientific REFUTEs, not a stage-routing flaw. The yan-li-saito cascade is on the correct stage trajectory (Hypothesize → Execute → Update is exactly right). The meta wants to investigate stage routing; the data says routing is fine and the noise is in judge.py contract-matching. Per §B2 interleaving, advance after R2_b is fully closed by critic; flag the actual root cause (judge metric-name binding) for the meta's Hypothesize stage.
  - `meta-internal-b-unification-2026-05-18` (priority 5): CLOSED.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T43-Update (critic) | Update | CRITIC PASS / CONFOUNDER-CONFIRMED + R2 routing | §C identified c1=0 + uniform-m=+1 seed cannot reach (0.5, 0, 0.5) basin via 2.4e-5/t_ho DDI off-diagonal. §E: R2 fl_vortex retry at same grid. Tier 0.8 → 0.75. |
| T44-Hypothesize+Design (theorist) | Hypothesize+Design | THEORIST_PASS (operational) | H1 joint hypothesis: n_max ≥ 100 D₀ AND m_+1 ∈ [0.35, 0.65] AND \|L_z\|/N ≤ 0.05 AND \|F_z\|/N ≤ 0.10. H3 3-branch table. D-stages used runtime state_zoo `init_psi_fl_vortex` (avoiding cross-box k-pad). Observable manifest 22 REQUIRED (Lz, m-populations both present — T20 contract-mistake class avoided). Predicted central n_max ∈ [1000, 5000] D₀; flagged R2_c as highest-probability prior. |
| T44-Execute (implementer) | Execute | judge=INCONCLUSIVE (evaluator-coupling artifact) / substantive REFUTED (R2_b) | n_max=3.09 D₀ at 96³ box=12 F32 dx=0.125 from fl_vortex seed. Pre-ITP sanity check PASS (m-pops exactly (0.25, 0.50, 0.25), L_z=-3.9e-15, F_z=0). Post-ITP m-pops = (0.375, 0.250, 0.375) — partial m=0 relaxation; NOT the (0.5, 0, 0.5) endpoint observed at T40 P4 coarse grid. F_z, L_z stayed at zero throughout. E_LHY/E_contact=2.2× qualitative change. Wall time 58s, norm_drift 4.4e-8 (5 orders below physical gate). |

**T44 implementer recommendation** (sim/turn_44.md §6): "R3 (128³ box=8 dx=0.0625 with topology-correct seed) first, as it directly tests whether the self-bound basin is reachable at finer dx while preserving the fl_vortex topology." Theorist H3 R2_b routing said "either R3 OR R4 (theorist analytical re-derivation); my recommendation: R3 first." The critic's Update is needed to ratify (or push back on) this routing before T46 burns ~10× the cost (128³ has 2.37× cells than 96³ plus longer FFT path).

## 3. Flow template recall

- **Template**: `verify-claim` (Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed).
- **Stage transition rule** per §B3: Execute produced `falsification_result: "REFUTED"` with `physical_red_flags` populated. Per the mapping table: `REFUTED (scientific) → jump to Update`. This is the **canonical LATS Reflect+Backprop step** (per director.md §G: "Our critic stage IS the Reflect+Backprop step").
- **Role for stage Update**: **critic** (§F1 Update row: "**critic** (mandatory; independent context); if REFUTED, hypothesis revised + tier-- or tier_target--; if CONFIRMED, tier++").
- **Why this stage now (vs other options)**:
  - **Why not skip Update and jump to T45=Execute R3 (128³)** as implementer recommended: the implementer recommendation is reasonable but **unaudited**. The critic must independently check: (i) is the R2_b REFUTE robust? (e.g., could 6250 steps have been insufficient for m=0 to fully relax to 0, and density was just about to start nucleating?); (ii) is the cheapest disambiguator R3 (finer dx) or R4 (analytical LHY χ branch audit + framework deep-bug scan)?; (iii) is the cost of R3 (~3-5M effective + ~5-10 min GPU at 128³) justified vs spending ~2M on theorist analytical scan first? Skipping critic at this branch point would be the T43→T44 mistake-class repeated (where theorist's §2.5 dismissed seed-topology without critic audit, leading to the seed-topology confounder being missed). The cascade has burnt ~50M effective tokens across 8 turns on this investigation; critic insertion at the R2_b branch point is cheap insurance.
  - **Why not skip Update and jump to T45=Hypothesize (theorist proposes R4 directly)**: theorist made an explicit conditional recommendation in H3 ("My recommendation: R3 first"); if I dispatch theorist to revise without critic audit, I'm second-guessing theorist's own output without independent input. Critic provides the independent voice §F1 demands.
  - **Why not Document REFUTED (close investigation as Tier 0)**: parent hypothesis (SpinorBEC.jl can reproduce paper Fig 1c) is NOT robustly refuted by one dx point + one seed strategy. Critic must clarify which sub-hypothesis is closed (Form-B-at-dx=0.125-with-topology-correct-seed) vs which remains open (Form-B at finer dx; LHY χ branch; framework deep-bug). Premature closure loses the cascade's learning.
  - **Why not switch to klaus-bch-leak (priority 3)**: priority 3 << 1; cascade has clear next move; switching now wastes the accumulated context.
  - **Why not switch to meta-stage-routing-2026-05-18 (priority 25, auto-spawned T44)**: §B2 interleaving rule — mid-cascade not the moment. Furthermore, the auto-spawn trigger's diagnosis ("stage routing flaw") is empirically WRONG: the routing was correct, the noise was judge-evaluator-coupling (T44 contract didn't match T44 sim metrics because the contract was for theorist Hypothesize and the sim was Execute). Flag this in the meta's eventual Observe stage. Letting meta proceed now would waste tokens on a misframed problem; the right move is to let the cascade complete and surface the actual judge-coupling pattern for the meta to consume.
  - **Why not switch to meta-critic-placement-2026-05-17 (priority 50)**: same interleaving rule + the cascade itself is generating ammunition for it (T43+T44 both showed judge-coupling quirks the critic could investigate).
  - **Why not run audit-class-scan (AUDIT_DUE drift advisory, gap=44 turns)**: this is a legitimate signal but defer ONE MORE turn to keep cascade momentum to a clean tier-checkpoint. Re-flag for T47+ after critic Update lands the R3 vs R4 decision.
  - **Why not noop**: clear high-leverage actionable directive at a critical decision branch.

## 4. Research grounding (§A6)

**External references for this critic Update dispatch**:

1. **`runs/_loop/sim/turn_44.md` §4 metrics + §5 observations + §7 falsification table** (LOAD-BEARING input): the data critic must independently audit. Key numbers: n_max=3.09 D₀, post-ITP m-pops (0.375, 0.250, 0.375), F_z=-1e-6, L_z=3e-6, mu_final=0.316, E_kin/N=0.009, E_LHY/N=0.129, E_contact/N=0.059, E_LHY/E_contact=2.2.

2. **`runs/_loop/theorist/turn_44.md` §H1-H3 + §3 sanity checks + §5 open questions**: the hypothesis critic is auditing the refutation of. Theorist's predicted central n_max ∈ [1000, 5000] vs observed 3.09 D₀ (300-1600× below). Open Q3 explicitly anticipated this exact scenario: "What if R2 m-populations come back as (0.5, 0, 0.5) but $n_{\rm max} \approx 2\,D_0$? ... route to R2_b → R3 (finer dx)." Observed m-pops (0.375, 0.250, 0.375) are intermediate, NOT (0.5, 0, 0.5); does this change the routing? Critic must address.

3. **`runs/_loop/sim/turn_40.md` §4 P4 row** (T40 P4 baseline at coarse grid dx=0.4375): n_max=0.61 D₀, m-pops (0.500, 6e-25, 0.500) — full m=0 evacuation in 5000 steps at COARSE grid. T44 (fine grid, 6250 steps, same fl_vortex seed) gave only partial relaxation (0.375, 0.250, 0.375). **Discrepancy**: at fine grid the m=0 evacuation route is SLOWER than at coarse grid? Critic must explain or flag. Possible reasons: (a) finer dx changes the DDI-off-diagonal matrix element magnitude (DDI scales like 1/|r-r'|³, fine grid samples shorter distances), (b) the LHY repulsion at finer grid (where local density is higher in the partial-nucleation regime) suppresses m-channel mixing, (c) the ITP relaxation rate is grid-dependent and we just need more steps. This is a NEW load-bearing observation NOT in theorist's H2 chain.

4. **`runs/_loop/judge/turn_43_critic_audit.md` §C + §3.3** (the prior critic's CONFOUNDER argument): T44 critic must check whether the confounder-elimination claim survives. T43 critic said "fl_vortex seed bypasses the kinetic bottleneck because it starts at m-populations already in the right ballpark". T44 evidence: starting point (0.25, 0.50, 0.25) → ended at (0.375, 0.250, 0.375) instead of (0.5, 0, 0.5). The kinetic bottleneck IS reduced (we moved partway) but NOT eliminated. Critic must judge: does this partial-progress show the bottleneck is the rate-limiting step (R2_c partial nucleation, route to extend ITP) or that there's a separate barrier (R2_b genuine REFUTE, route to R3 or R4)?

5. **Memory `yan_li_saito_2026_barnett_paper.md` lines 36-46 (Hamiltonian Eq 1) + lines 85-101 (LHY χ(ε_dd) implementation issue + free-space ITP convergence concern + likely failure modes)**: paper's E_LHY uses Lima-Pelster χ(ε_dd) with explicit `Re` operator because ε_dd > 1 gives imaginary part in the integrand. Memory line 114-115 explicitly lists "LHY χ(ε_dd) numerical-integral discrepancy at ε_dd > 1 (the χ integrand has imaginary part for ε_dd > 1; 'Re' matters)" as a likely failure mode. We're at ε_dd = 1.18 > 1. Theorist §5 Q1 deferred this audit to R2_b firing. R2_b HAS fired. **Critic must surface this as the R4 candidate root cause** (not necessarily prove it wrong, but flag it as the next-investigation target if R3 also fails).

6. **`src/hamiltonian/interactions/lhy.jl`** + memory `lhy_refactor_2026_05_12.md` (CLAUDE.md mentions `Scalar LHY: @warn approximation`): our scalar LHY for ε_dd > 1 implementation specifics. Critic may briefly check whether the integrand handling matches Lima-Pelster's Re ∫₀^π ... formula or whether SpinorBEC.jl uses a different branch convention. This is a 1-line check, not a deep audit.

7. **Memory `feedback_decision_style.md`** (anko prefers minimal clarifying questions; commit to defaults): critic must commit to ONE routing recommendation (R3 or R4 or extend-ITP) with reasoning, not hedge across all three. The DECISION TREE is for director; the RECOMMENDATION is the critic's deliverable.

8. **Memory `feedback_mathematical_elegance_bias.md`** (N independent issues → N simple fixes, not 1 unifying reformulation): the R2_b refutation could have N possible causes. Critic should rank them by direct testability + cost, NOT propose a single unifying re-derivation (which would be the R4-only path's failure mode).

9. **Memory `feedback_fix_the_class_not_the_instance.md`**: the partial m=0 relaxation (T44) vs full evacuation (T40 P4) discrepancy is potentially a CLASS-LEVEL observation about fine-vs-coarse grid m-channel relaxation rates. Critic should note this for the eventual audit-class-scan (T47+).

10. **director.md §G "Grounded autonomous research (arXiv:2604.12198)" + LATS critic-as-Reflect+Backprop**: this critic Update IS the canonical Reflect step. The expected output IS the routing decision for T46.

11. **`feedback_manuscript_is_not_the_essence`**: critic must focus on D1 (verification of paper reproduction claim) and D3 (theory understanding of why it's failing), NOT on documenting the refutation in manuscript form. The investigation may close with a clean PARTIAL or REFUTE; the closing memory entry is the appropriate output channel.

12. **`runs/_loop/director/turn_44.md` §F1 dispatch decision** (the prior director context): I am the same director persona; turn_44 chose theorist Hypothesize+Design as the correct pre-Execute step. T45 critic Update is the symmetric post-Execute step — consistent application of the verify-claim template.

13. **`runs/_loop/judge/turn_44.json` `criteria_results` all-null + `triggered_failure_modes: []`**: the contract-evaluator coupling I called out at the §1 stage transition. Critic should not be confused by this; the SUBSTANTIVE verdict is in sim/turn_44.md §7 (REFUTED, R2_b). The judge-coupling quirk is the eventual data point for meta-stage-routing.

**Why these inform the dispatch**: refs 1-2 are the data + hypothesis critic is auditing; ref 3 is a new load-bearing physics observation that needs critic interpretation; refs 4-6 are the LHY-χ-branch + DDI-off-diagonal-rate alternative-cause threads critic must rank; refs 7-9 are methodological discipline; refs 10-13 are the meta-context (LATS pattern, manuscript scope, prior director consistency, judge-quirk acknowledgment).

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 PRIMARY** (verify existing physics — Tier-3 candidate paper reproduction). The critic Update is the gating step that determines whether T46 burns ~10× more compute on R3 (128³ finer dx) or pivots to R4 (theorist analytical LHY χ branch audit, ~2M effective). High-leverage cost-routing decision.
- **D3 SECONDARY**: the LHY χ(ε_dd>1) branch question is genuine new-theory work (paper's `Re ∫` operator handling vs SpinorBEC.jl's `:scalar` mode). Critic surfaces this as the next-investigation target if applicable.
- **D2 NOT advanced this turn**.
- **Tier ladder position**: 0.75 → 0.70 if critic confirms R2_b robust + R3 worth attempting; 0.65 if critic concludes both R3 and R4 are needed (joint cost ~5M but settles the question); 0.85 if critic finds 6250 steps was actually insufficient (push back on REFUTE, route to extend ITP first — partial nucleation argument).
- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence`.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "yan-li-saito-2026-reproduction",
  "stage_advancing_to": "Update",
  "subagent_type": "critic",
  "rationale": "T44 Execute produced substantive `falsification_result: REFUTED` (R2_b branch: n_max=3.09 D₀ at fl_vortex seed, dx=0.125, 96³ box=12 F32; below REFUTE threshold 10 D₀ and 32× below PASS threshold 100 D₀). Per §F1 verify-claim, REFUTED Execute → critic Update (mandatory independent context). The critic must (a) audit whether the REFUTE is robust or could be confounded by partial m=0 relaxation (observed m-populations (0.375, 0.250, 0.375) are intermediate between initial (0.25, 0.50, 0.25) and T40 P4's full-evacuation endpoint (0.5, 0, 0.5) — suggesting the m-channel relaxation route did NOT complete; T44 may be R2_c partial nucleation, not R2_b genuine REFUTE); (b) independently rank the next-step options (R3 finer dx at 128³ box=8 dx=0.0625; R4 theorist analytical LHY χ(ε_dd=1.18) branch audit + framework deep-bug scan; R2_c-extend extend ITP at same grid to test whether m-evacuation completes and density nucleates); (c) commit to ONE routing recommendation for T46 with quantitative tier transition; (d) flag the load-bearing NEW observation (partial m=0 relaxation at fine grid vs full evacuation at coarse grid in 5000 steps) which is NOT covered by theorist H2 chain — interpret or flag; (e) cross-check the LHY χ(ε_dd > 1) branch hypothesis as the next-most-probable root cause if R3 also fails (memory yan_li_saito_2026_barnett_paper.md line 114-115 explicitly lists this as a likely failure mode). This critic Update at ~1.5-2M effective gates a T46 dispatch worth ~3-5M (R3) or ~2M (R4); strictly dominated cost-routing decision.",
  "brief": "## ROLE\n\nYou are the critic subagent. Update stage for the yan-li-saito-2026-reproduction investigation per §F1 verify-claim template: independent audit of T44 Execute's substantive REFUTED verdict (sim/turn_44.md §7 R2_b).\n\nDeliverable: `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_45_critic_audit.md`.\n\n## CONTEXT\n\nT44 implementer Executed the R2 fl_vortex retry (theorist/turn_44.md §6 directive): runtime state_zoo `init_psi_fl_vortex` seed at 96³ box=12 dx=0.125 F32 rotating_basis GPU, 6250 ITP steps, ALL other parameters IDENTICAL to T43 P0_pre. The pre-ITP sanity check PASSED exactly as theorist predicted: m-populations (0.25, 0.50, 0.25) uniform, L_z=-3.9e-15, F_z=0. The post-ITP state:\n- n_max_D0 = 3.09 (1.5× the T43 spherical-seed baseline of 2.00 D₀, but 32× below the joint-falsifier PASS threshold of 100 D₀, and below the REFUTE-edge of 10 D₀).\n- m_populations = (0.375, 0.250, 0.375) — INTERMEDIATE between initial (0.25, 0.50, 0.25) and T40 P4's full-evacuation endpoint (0.500, 6e-25, 0.500).\n- F_z/N = -1e-6, L_z/N = 3e-6 (both within band).\n- mu_final = 0.316 (vs 0.120 for T43 P0_pre spherical-seed — vortex gradient energy IS encoded).\n- E_LHY/N = 0.129 >> E_contact/N = 0.059 (ratio 2.2× — qualitative change from T43 delocalized state).\n- norm_drift = 4.4e-8 (F32 floor, 5 orders below physical gate).\n- Wall time 58s.\n\nImplementer flagged this as R2_b REFUTE and recommended T45 = R3 (128³ box=8 dx=0.0625 finer dx with same topology-correct seed). Theorist H3 R2_b table said \"either R3 OR R4 (theorist analytical re-derivation); my recommendation: R3 first.\"\n\nYour job is the LATS Reflect+Backprop step: audit the REFUTE robustness, address the new observation (partial m=0 relaxation), and commit to ONE routing recommendation with quantitative tier transition.\n\n## REQUIRED READING\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_44.md` end-to-end (the data you are auditing; §4 metrics, §5 observations, §6 issues/deviations, §7 falsification check).\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_44.md` §H1-H3 (the hypothesis being audited; §H3 R2_b table for the routing logic theorist proposed) + §3 sanity checks + §5 open questions Q3 (anticipated this scenario).\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_40.md` §4 P4 row (coarse-grid baseline: n_max=0.61 D₀ with FULL m=0 evacuation (0.500, 6e-25, 0.500) in 5000 steps — the comparison datum your audit must address).\n4. `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_43_critic_audit.md` §C (the prior critic's CONFOUNDER argument and DDI off-diagonal rate 2.4e-5/t_ho derivation) + §3.3 (joint falsifier spec) — to check whether the confounder-elimination claim survives T44 data.\n5. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/yan_li_saito_2026_barnett_paper.md` lines 36-46 (paper's Hamiltonian Eq 1, especially E_LHY with explicit `Re` operator) + lines 85-101 (LHY χ(ε_dd) audit + free-space ITP convergence concern) + lines 113-122 (likely failure modes — esp. line 114-115 'LHY χ(ε_dd) numerical-integral discrepancy at ε_dd > 1; Re matters').\n6. Optional spot-check: `/home/suzume/workspace/BEC-simulation/src/hamiltonian/interactions/lhy.jl` for the `:scalar` LHY implementation — does the integrand handle the imaginary-part branch correctly at ε_dd = 1.18? (1-line scan, NOT a deep audit).\n7. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_45.md` §1, §3, §4 — director context for which routing decisions are in scope.\n8. `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` lines 2366-2400 — yan-li-saito investigation block (history, falsifiers).\n\n## AUDIT TASKS (sections A-F, mirror the T43 critic audit structure)\n\n### §A. R2_b REFUTE robustness\n\nIs the REFUTE robust or could the partial m=0 relaxation indicate R2_c (incomplete ITP) rather than R2_b (true REFUTE)?\n\nKey question: at T40 P4 dx=0.4375, m=0 fully evacuated in 5000 steps. At T44 dx=0.125, m=0 only partially relaxed (0.5 → 0.25) in 6250 steps. Why the slower relaxation at fine grid?\n\nHypotheses to rank:\n- (i) DDI off-diagonal matrix element is grid-dependent (finer dx samples shorter distances; DDI ~1/r³ amplification at short range may change the spin-mixing rate).\n- (ii) LHY repulsion at finer grid (higher local density in the partial-nucleation pocket) raises the energy barrier for m-channel transfer.\n- (iii) The fine-grid simulation hasn't run long enough — 6250 steps is shorter than what the slower fine-grid relaxation needs.\n- (iv) T40 P4 used JLD2-loaded ComplexF64; T44 used runtime-built F32. Numerical-precision-dependent m-channel relaxation (F32 round-off may help OR hurt — unclear sign).\n\nIf hypothesis (iii) holds, T46 should be extend-ITP at same grid (cheaper than R3). If (i)-(ii), R3 is the right next step. If (iv) needs to be ruled out, theorist or implementer must propose a discriminator.\n\nVerdict options: ACCEPT-R2_b-REFUTE-ROBUST; ROUTE-TO-R2_c-EXTEND-ITP; UNDETERMINED-NEED-EXTENDED-RUN.\n\n### §B. Confounder-elimination claim audit\n\nT43 critic §C argued seed-topology was the confounder blocking T43's REFUTE. T44 used the topology-correct seed. Did this eliminate the confounder?\n\n- Pre-ITP topology IS correct (m-pops (0.25, 0.50, 0.25), F_z=0, L_z=0 — confirmed sanity check PASS).\n- Post-ITP topology preserved (F_z=-1e-6, L_z=3e-6 — equal-and-opposite winding cancelled).\n- BUT post-ITP m-pops did not reach the full Mermin-Ho (0.5, 0, 0.5) endpoint — only halfway.\n\nVerdict: did topology actually get to the basin's ENERGY MINIMUM, or did ITP stop at a local minimum / didn't complete? \n\nThis is the same shape as T43's confounder (\"seed wasn't representative of the basin\"); critic must judge whether T44's partial-relaxation is a NEW confounder of the SAME class (i.e., the basin is even harder to reach than estimated — would require yet another seed-construction strategy or longer ITP), or whether T44 genuinely refutes the joint hypothesis (Form B sharp-dx_crit + topology-correct seed = sufficient).\n\nVerdict options: CONFOUNDER-RESOLVED (REFUTE survives); CONFOUNDER-PARTIAL (need extend-ITP to disambiguate); NEW-CONFOUNDER (seed-construction needs further refinement, e.g., true Mermin-Ho initial state at (0.5, 0, 0.5)).\n\n### §C. LHY χ(ε_dd > 1) branch hypothesis cross-check\n\nMemory yan_li_saito_2026_barnett_paper.md line 114-115 explicitly flags 'LHY χ(ε_dd) numerical-integral discrepancy at ε_dd > 1 (the χ integrand has imaginary part for ε_dd > 1; Re matters)' as a likely failure mode. We are at ε_dd = 1.18.\n\nQuick check (optional, time-permitting):\n- Read `/home/suzume/workspace/BEC-simulation/src/hamiltonian/interactions/lhy.jl` for the `:scalar` mode integrand. Does it use `real(integrand)` or just take real-valued samples? At ε_dd > 1, the integrand `[1 + ε_dd(3cos²θ - 1)]^(5/2)` is imaginary for cos²θ < (1 - 1/ε_dd)/3 = (1 - 0.847)/3 = 0.051, i.e. θ ∈ (~77°, ~103°) — a non-negligible angular band.\n- If our `:scalar` mode silently NaN's or returns 0 over the imaginary band, the χ value we use at ε_dd=1.18 is wrong by some factor.\n- This does NOT need a deep audit — just confirm whether the line-of-code looks plausibly correct or flag-for-followup.\n\nVerdict options: LHY-LOOKS-OK (R4 not load-bearing); LHY-SUSPECT-NEEDS-AUDIT (R4 should be Theorist priority); LHY-NOT-CHECKED-FLAG-FOR-T47.\n\n### §D. New observation: fine-grid slower m-channel relaxation\n\nThe partial m=0 relaxation at dx=0.125 (0.5 → 0.25 in 6250 steps) vs full evacuation at dx=0.4375 (0.5 → ~0 in 5000 steps) is a NEW observation NOT in theorist's H2 chain. Critic provides a physics interpretation OR flags as deserving its own falsifier.\n\n### §E. Routing recommendation (single commitment)\n\nCommit to ONE of:\n- **R3 (finer dx at 128³ box=8 dx=0.0625, same fl_vortex seed via state_zoo)**: tests reading-(i) of T43 critic §B (Form B with dx_crit < 0.125; finer dx needed). Cost: ~5-10 min GPU + ~3-5M effective. Tier transition: 0.85 if R3_a (n_max ≥ 100 D₀ at finer grid), 0.55 if R3_b (still refutes — strong negative evidence for the joint hypothesis).\n- **R4 (theorist analytical re-derivation of self-bound condition + LHY χ(1.18) branch audit)**: addresses reading-(ii) of T43 critic §B (framework-deep-bug). Cost: ~2-3M effective text + sympy only. Tier transition: 0.70 if R4 finds a known issue (route to fix-bug investigation); 0.75 if R4 confirms framework is OK (routes to R3 as fallback).\n- **R2_c (extend ITP at same grid by 2× to 12500 steps total)**: addresses §A hypothesis (iii) (just need more time for m-relaxation). Cost: ~2-3M effective + ~2 min GPU. Tier transition: depends on outcome.\n\nMy preliminary inclination is R4-first-then-R3 because R4 is cheaper, has a high-prior root cause already identified (LHY χ branch), and would prevent burning ~10× compute on R3 if a framework issue exists. But the final call is yours; you may push back with evidence.\n\nIf you push back on the implementer's R3-first recommendation, articulate the cost-benefit clearly.\n\n### §F. Tier transition\n\nCommit to a tier transition for T45. Suggested range based on §A-§E verdicts:\n- 0.85 if §A=R2_c (partial nucleation, route to extend-ITP) — REFUTE downgraded\n- 0.75 if §A=ACCEPT and §B=PARTIAL and §E=R4-first — cascade-pause for theory work\n- 0.70 if §A=ACCEPT and §E=R3 — REFUTE robust, cost-route to finer dx\n- 0.55 if §A=ACCEPT and §C=LHY-SUSPECT — cascade in trouble, framework issue likely\n\n## METRICS BLOCK (required at end, for judge.py to parse)\n\n```json\n{\n  \"audit_target\": \"T44_Execute_sim_turn_44.md\",\n  \"section_A_verdict\": \"ACCEPT-R2_b-REFUTE-ROBUST\" | \"ROUTE-TO-R2_c-EXTEND-ITP\" | \"UNDETERMINED-NEED-EXTENDED-RUN\",\n  \"section_B_verdict\": \"CONFOUNDER-RESOLVED\" | \"CONFOUNDER-PARTIAL\" | \"NEW-CONFOUNDER\",\n  \"section_C_verdict\": \"LHY-LOOKS-OK\" | \"LHY-SUSPECT-NEEDS-AUDIT\" | \"LHY-NOT-CHECKED-FLAG-FOR-T47\",\n  \"section_D_observation_addressed\": true | false,\n  \"section_E_routing_recommendation\": \"R3\" | \"R4\" | \"R2_c-extend-itp\" | \"R4-then-R3\",\n  \"section_F_tier_transition\": <float in [0.4, 0.95]>,\n  \"falsification_robust\": true | false,\n  \"next_falsifier_id\": \"<string e.g. dx-refinement-128cubed-fl-vortex OR lhy-chi-eps-dd-1.18-branch-audit OR extend-itp-12500-steps-same-grid>\",\n  \"next_falsifier_observable_manifest\": [\"<key1>\", \"<key2>\", ...],\n  \"new_class_pattern_candidate\": \"<string or null>\",\n  \"cost_budget_t46_estimate_effective\": <float>,\n  \"cost_budget_t46_estimate_gpu_wall_sec\": <float>,\n  \"sources_cited\": <integer>,\n  \"critic_md_on_disk\": true,\n  \"investigation_id\": \"yan-li-saito-2026-reproduction\",\n  \"recommends_close_investigation\": true | false,\n  \"meta_data_point\": \"<string capturing any meta-critic-placement or meta-stage-routing relevant evidence>\"\n}\n```\n\n## STYLE\n\n- Use [Established] / [Plausible] / [Speculative] / [Unknown] calibration tags throughout audit sections.\n- Per `feedback_decision_style`: commit to ONE §E routing in the metrics block; the discussion may rank multiple but the metric is one string.\n- Per `feedback_mathematical_elegance_bias`: rank causes by direct testability + cost; do NOT propose a single unifying re-derivation that solves all.\n- Per `feedback_no_improvised_terminology`: standard physics (Lima-Pelster χ, Mermin-Ho, DDI off-diagonal, etc.); no novel labels.\n- Independence: this is an INDEPENDENT context audit. You may agree with theorist H3 OR push back. Push-back requires evidence.\n- No re-running julia; no GPU dispatch. Text + light file inspection (lhy.jl spot-check optional).\n- Budget: ~1.5-2M effective. \n- Do NOT reopen DDI conventions (T42 §B closed) or grid-resolution hypothesis (T42 §A CORROBORATE).\n\n## DELIVERABLE\n\nWrite `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_45_critic_audit.md` with §1 (bottom line), §2 (audit sections A-F), §3 (cost-routing rationale), §4 (open questions for T46), §5 (sources cited), §6 (metrics JSON block).",
  "observable_manifest": {
    "required": [
      "critic_md_on_disk",
      "section_A_verdict",
      "section_B_verdict",
      "section_C_verdict",
      "section_E_routing_recommendation",
      "section_F_tier_transition",
      "falsification_robust",
      "next_falsifier_id",
      "cost_budget_t46_estimate_effective",
      "sources_cited",
      "investigation_id"
    ],
    "optional": [
      "section_D_observation_addressed",
      "next_falsifier_observable_manifest",
      "new_class_pattern_candidate",
      "cost_budget_t46_estimate_gpu_wall_sec",
      "recommends_close_investigation",
      "meta_data_point"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_44.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_44.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_40.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_43_critic_audit.md && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/yan_li_saito_2026_barnett_paper.md && test -f /home/suzume/workspace/BEC-simulation/src/hamiltonian/interactions/lhy.jl && test -f /home/suzume/workspace/BEC-simulation/CLAUDE.md && echo 'precondition OK: T44 sim/theorist + T40 sim + T43 critic + memory + lhy.jl + CLAUDE all present'"
  },
  "success_criteria": [
    {
      "id": "critic_md_on_disk",
      "metric": "critic_md_on_disk",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Audit trail required; critic must Write to runs/_loop/judge/turn_45_critic_audit.md."
    },
    {
      "id": "section_a_verdict_committed",
      "metric": "section_A_verdict",
      "operator": "in",
      "value": ["ACCEPT-R2_b-REFUTE-ROBUST", "ROUTE-TO-R2_c-EXTEND-ITP", "UNDETERMINED-NEED-EXTENDED-RUN"],
      "tolerance": null,
      "rationale": "Critic must commit to ONE robustness verdict on the partial-m-relaxation observation; not 'all three' hedging."
    },
    {
      "id": "section_b_verdict_committed",
      "metric": "section_B_verdict",
      "operator": "in",
      "value": ["CONFOUNDER-RESOLVED", "CONFOUNDER-PARTIAL", "NEW-CONFOUNDER"],
      "tolerance": null,
      "rationale": "Critic must commit to whether T43-critic's confounder-elimination claim survives T44 data."
    },
    {
      "id": "section_c_verdict_committed",
      "metric": "section_C_verdict",
      "operator": "in",
      "value": ["LHY-LOOKS-OK", "LHY-SUSPECT-NEEDS-AUDIT", "LHY-NOT-CHECKED-FLAG-FOR-T47"],
      "tolerance": null,
      "rationale": "LHY χ(ε_dd=1.18) branch is the next-most-probable root cause per memory yan_li_saito_2026_barnett_paper.md line 114-115; critic must address."
    },
    {
      "id": "routing_committed",
      "metric": "section_E_routing_recommendation",
      "operator": "in",
      "value": ["R3", "R4", "R2_c-extend-itp", "R4-then-R3"],
      "tolerance": null,
      "rationale": "Critic must commit to ONE T46 routing recommendation per feedback_decision_style."
    },
    {
      "id": "tier_transition_in_range",
      "metric": "section_F_tier_transition",
      "operator": "in",
      "value": [0.4, 0.95],
      "tolerance": null,
      "rationale": "Tier transition must be in a sensible range — not closure (would be < 0.4) nor jump beyond what evidence supports (would be > 0.95)."
    },
    {
      "id": "next_falsifier_specified",
      "metric": "next_falsifier_id",
      "operator": "!=",
      "value": "",
      "tolerance": null,
      "rationale": "Critic must name the next falsifier for T46 to test (lets director draft T46 dispatch without needing to invent it)."
    },
    {
      "id": "cost_budget_realistic",
      "metric": "cost_budget_t46_estimate_effective",
      "operator": "<=",
      "value": 6000000,
      "tolerance": null,
      "rationale": "T46 estimate must fit per-turn cap. R3 is ~3-5M; R4 is ~2-3M; R2_c-extend is ~2-3M; all fit comfortably."
    },
    {
      "id": "sources_minimum",
      "metric": "sources_cited",
      "operator": ">=",
      "value": 5,
      "tolerance": null,
      "rationale": "T44 sim + T44 theorist + T40 sim + T43 critic + memory paper minimum (5)."
    },
    {
      "id": "falsification_robust_committed",
      "metric": "falsification_robust",
      "operator": "in",
      "value": [true, false],
      "tolerance": null,
      "rationale": "Boolean commitment on whether T44's REFUTE survives audit. Couples to §A verdict."
    }
  ],
  "failure_modes": [
    {
      "if": "critic_md_on_disk failed",
      "category": "operational",
      "next_action": "T46 = re-dispatch critic with stricter file-path enforcement. If 2nd attempt fails, escalate to anko."
    },
    {
      "if": "section_E_routing_recommendation == 'R3' AND falsification_robust == true AND section_C_verdict != 'LHY-SUSPECT-NEEDS-AUDIT'",
      "category": "scientific_routing_R3",
      "next_action": "T46 = theorist Design for R3 (128³ box=8 dx=0.0625, same fl_vortex state_zoo seed, joint falsifier; tier_target_on_pass=0.85, tier_target_on_refute=0.55). Then T47 implementer_julia_gpu Execute R3. Budget ~3-5M effective + ~5-10 min GPU."
    },
    {
      "if": "section_E_routing_recommendation == 'R4' OR section_E_routing_recommendation == 'R4-then-R3'",
      "category": "scientific_routing_R4",
      "next_action": "T46 = theorist or implementer_text+sympy R4 analytical re-derivation. Specifically: (i) LHY χ(ε_dd=1.18) branch audit via sympy direct evaluation of `Re ∫₀^π sinθ [1 + 1.18(3cos²θ - 1)]^(5/2)/2 dθ` and cross-comparison with src/hamiltonian/interactions/lhy.jl :scalar mode output; (ii) self-bound minimum condition derivation for the paper's flux-closure-torus magnetic-vortex geometry under our DDI conventions. Budget ~2-3M effective text + sympy."
    },
    {
      "if": "section_E_routing_recommendation == 'R2_c-extend-itp'",
      "category": "scientific_routing_R2c",
      "next_action": "T46 = implementer_julia_gpu extend ITP from T44 results JLD2 (runs/yan_li_saito_f1_grid_refinement/results_R2_fl_vortex.jld2) by another 6250-12500 steps to test whether n_max continues rising as m=0 component continues evacuating. Cheaper test of incomplete-relaxation hypothesis before committing to R3 or R4."
    },
    {
      "if": "section_F_tier_transition > 0.90",
      "category": "scope_violation",
      "next_action": "REJECT. Critic appears to claim T44 was NOT a REFUTE but a PASS — inconsistent with sim/turn_44.md §7 substantive REFUTED verdict. Re-dispatch critic to reconsider."
    },
    {
      "if": "section_F_tier_transition < 0.40",
      "category": "scope_violation",
      "next_action": "REJECT. Critic appears to want to close investigation as failure — premature given multiple R3/R4/extend-ITP options remain unexplored. Re-dispatch with explicit constraint."
    },
    {
      "if": "All critical criteria pass AND falsification_robust committed AND routing committed",
      "category": "scientific_advance",
      "next_action": "T46 dispatched per the routing recommendation. Cascade continues; tier per §F. Update state.json.investigations.yan-li-saito-2026-reproduction with the new falsifier, new tier, new stage (Hypothesize again for R3/R4 design; Execute for R2_c extend-ITP)."
    },
    {
      "if": "critic attempts to reopen DDI conventions (T42 §B) OR grid-resolution hypothesis (T42 §A)",
      "category": "scope_violation",
      "next_action": "REJECT. Both are closed at T42. Critic's job is the NEW question (R2_b vs R2_c disambiguation + R3 vs R4 routing), not re-litigating closed sub-questions."
    },
    {
      "if": "cost > 2.5M effective",
      "category": "operational",
      "next_action": "Acceptable up to per-turn 6M cap; warn anko if exceeds 2.5M (critic should not be doing implementer work)."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 2500000
  },
  "budget": {
    "expected_cost_eff": 1800000,
    "expected_wall_time_sec": 1200,
    "split_by_subtask": {
      "read_t44_sim_theorist_t40_sim_t43_critic_memory": 600000,
      "section_a_b_robustness_confounder_audit": 400000,
      "section_c_lhy_chi_branch_spotcheck": 200000,
      "section_d_e_new_observation_routing_decision": 400000,
      "section_f_tier_metrics_write_md": 200000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Update (then per critic's routing: Hypothesize for R3/R4 design OR Execute for R2_c extend-ITP)",
    "if_success_tier_becomes": 0.70,
    "if_success_falsifier_update": "T44 R2 fl_vortex retry at dx=0.125 produced substantive REFUTED (n_max=3.09 D₀, R2_b branch). T45 critic Update will commit to: §A robustness verdict (REFUTE robust vs partial-relaxation confounder); §B confounder-elimination assessment (does T43-critic's claim survive); §C LHY χ(1.18) branch suspect-flag; §E single routing recommendation (R3 OR R4 OR R2_c-extend-itp); §F quantitative tier transition. Pre-T45 state: cascade has narrowed the parent hypothesis to (Form B sharp-dx_crit threshold + topology-correct seed = sufficient) NOT joint sufficient at dx=0.125 — open whether finer dx, LHY branch fix, or extended ITP is the next step.",
    "if_refuted_advance_to_stage": "Hypothesize (if critic concludes investigation should close as REFUTED parent hypothesis, theorist drafts a closure-memory entry capturing the negative result + framework-class lesson)",
    "if_refuted_tier_becomes": 0.40,
    "next_falsifier_to_test_after": "Per critic §E routing: if R3 → `dx-refinement-128cubed-fl-vortex` (T46 theorist Design + T47 Execute); if R4 → `lhy-chi-eps-dd-1.18-branch-audit` (T46 theorist+sympy or implementer_text+sympy); if R2_c-extend-itp → `extend-itp-12500-steps-same-grid-r2-from-jld2` (T46 implementer_julia_gpu). Director will draft T46 dispatch per the critic's commitment in §E. Meta-stage-routing-2026-05-18 (priority 25, auto-spawned T44): the actual root cause of the recent INCONCLUSIVE streak is judge-evaluator-coupling (judge.py evaluates sim metrics against the wrong contract when stages alternate Hypothesize/Execute); file this as the meta's Observe-stage data point next time it's interleaved (T47+). AUDIT_DUE patterns.yaml (gap=45 turns): defer to T47+ but flag for explicit attention then; the partial-m-relaxation-at-fine-vs-coarse-grid observation is a candidate new pattern."
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read `runs/_loop/_local/scheduler_45.json` (policy=JULIA_GPU_OK; critic in allowed_workloads; window 1195831s ≈ 332 hours left; VRAM 12949 MB free / GPU 1% util — comfortable for cheap critic + any T46 follow-up).
- [x] Read `runs/_loop/state.json` lines 2200-2523 (investigations + meta-investigations + auto-spawned meta-stage-routing at T44 + last_meta_check_turn=44; current_stage=Hypothesize per state which is stale — actually we're post-Execute T44; updating state via this dispatch).
- [x] Read `runs/_loop/seed.md` end-to-end (yan-li-saito priority 1 Tier-3 candidate; cost cap 100M rolling / 6M per-turn — well within limits).
- [x] Read `runs/_loop/director/turn_44.md` (the prior director dispatch — confirmed theorist Hypothesize+Design was correct precursor; T45 critic Update is the symmetric post-Execute step).
- [x] Read `runs/_loop/theorist/turn_44.md` §0-§9 + §11 metrics block (the hypothesis being audited; verified theorist explicitly anticipated R2_b scenario in §5 Q3).
- [x] Read `runs/_loop/sim/turn_44.md` end-to-end (the data: n_max=3.09, partial m-relaxation, F_z=L_z=0 — the load-bearing inputs for critic).
- [x] Read `runs/_loop/judge/turn_44.json` (verified INCONCLUSIVE is evaluator-coupling artifact: criteria_results all-null + triggered_failure_modes empty; substantive verdict in sim §7 = REFUTED).
- [x] Read `runs/_loop/judge/turn_43_critic_audit.md` §1-§C (the prior critic's confounder argument — the chain T45 critic must check for survival).
- [x] Read memory `yan_li_saito_2026_barnett_paper.md` lines 1-130 (LHY χ branch flag at line 114-115 is the load-bearing pointer for §C audit).
- [x] investigation_id 'yan-li-saito-2026-reproduction' valid in state.investigations.
- [x] stage_advancing_to 'Update' is the next stage per §F1 (Execute REFUTED → critic Update).
- [x] subagent_type 'critic' matches role_per_stage[Update] in §F1.
- [x] success_criteria are machine-evaluable (each operator+value pair lets judge.py parse against critic JSON metrics block).
- [x] failure_modes cover the 6-8 most likely failures: file-write fail, three routing branches (R3 / R4 / R2_c-extend), tier-out-of-range high+low, scope-violation (reopen DDI/grid), cost-cap, success-advance.
- [x] observable_manifest precondition_check is concrete bash (7 file checks + echo).
- [x] budget 1.8M effective fits within scheduler window (1195831s) AND per-turn cap (6M) AND tolerance_override 2.5M.
- [x] §A6 research-first citation present (13 references in §4, anchored on T44 sim/theorist + T40 sim + T43 critic + memory paper + LHY framework + methodological feedback files + LATS pattern + manuscript-scope discipline).
- [x] §A5 D1 articulated (yan-li-saito Tier-3 candidate verification — critic gates cost-routing for T46); D3 secondary (LHY χ branch is genuine new-theory thread); manuscript NOT primary (explicit in §5).
- [x] Investigation update field updates current_stage to Update (success) AND tier_current to 0.70 (per cascade trajectory). On refuted-of-this-Update → close-investigation pre-document path.
- [x] Considered switching investigations: klaus-bch-leak (priority 3, lower); meta-critic-placement (priority 50, interleaving defer); meta-stage-routing (priority 25, auto-spawned but its diagnosis is empirically wrong — actual root cause is judge-coupling not stage-routing; defer); audit-class-scan (legitimate but cascade-momentum priority); noop (rejected — high-leverage decision branch).
- [x] Considered alternate routings: skip-to-Execute-R3 (rejected — burns 10× compute without independent audit, repeats T43→T44 lack-of-critic-at-branch-point mistake); skip-to-Hypothesize-R4 (rejected — second-guesses theorist H3 without independent input); close-as-REFUTED (rejected — premature given R3/R4/extend-ITP still unexplored).
