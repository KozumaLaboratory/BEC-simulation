---
turn: 64
subagent: director
investigation_id: yan-li-saito-2026-reproduction
stage_advancing_from: Document (terminal-at-tier-0.4, dormant since T49)
stage_advancing_to: Research (R4 falsifier branch — new hypothesis, restart at Research per §F1 falsifier-restart rule)
topic_tags: [yan-li-saito-2026, R4-analytical-ddi-energy-sign, BUG-9-DDI-convention, free-space-DDI, lima-pelster-chi, lit-scan, dormancy-vs-revive, D1-verification]
paper_section: null
depends_on: [37, 40, 42, 45, 48, 49, 63, "runs/_loop/director/turn_63.md", "runs/_loop/judge/turn_63.json", "runs/_loop/seed.md", "runs/_loop/state.json", "memory:yan_li_saito_2026_barnett_paper", "memory:feedback_decision_style", "memory:feedback_mechanical_vs_investigation_threshold", "memory:feedback_fix_the_class_not_the_instance"]
produces: "researcher dispatch for §F1 Research stage of yan-li-saito-2026-reproduction R4 falsifier branch: grounded literature scan on (a) free-space DDI prefactor + sign conventions across Yan-Li-Saito 2026 PRL Eq 1 vs SpinorBEC.jl `c_dd=μ_0 μ²` (no 4π) vs Stuttgart/Pfau group / Chomaz 2020 / Lima-Pelster conventions; (b) bit-exact derivation of DDI energy sign at ε_dd=1.2 polar polarized state; (c) audit of `:scalar` mode DDI Hamiltonian against paper Eq 1 (specifically the (1-3cos²θ)/|r-r'|³ kernel sign + the LHY χ(ε_dd) sign region — the 6807× framework-vs-paper density gap is the constraint to be explained or refuted). Output: 6-8 page research/turn_64_yan_li_saito_r4_ddi_sign.md with a Verdict block: REVIVE (concrete sign-convention candidate found, spawn build-theory child) | DORMANT-CLOSE (clean conventions everywhere, close investigation REFUTED-CLEAN tier 0.4) | INCONCLUSIVE (open question identified, defer). No code execution, no patterns.yaml touch."
---

# Turn 64 — Director Report

## 1. Investigation state snapshot

- **Switching investigation** from T63's `audit-class-scan-2026-05-18-T61` (CLOSED tier 2 at T63) to `yan-li-saito-2026-reproduction` (dormant tier 0.4 at T49). Reason: T63 closed the audit cycle cleanly; T63 director explicitly listed three options for T64 — (a) yan-li-saito R4 dormancy-vs-revive, (b) audit refresh (not due until ~T72), (c) anko-prompt request. Per anko's seed.md priority order (priority 2; only remaining open priority-1/2 physics thread) and per `feedback_decision_style` ("pick defaults and move"), option (a) is selected.
- **Active investigation** (T64): `yan-li-saito-2026-reproduction` (priority 2, flow_template `verify-claim`, kind=physics).
- **Stage transition**: dormant Document-terminal → **Research** (re-entry for R4 falsifier `r4-analytical-ddi-energy-sign-or-dormant-at-0.4`). Per §F1 falsifier-restart rule: "REFUTED in Update DOES NOT mean investigation failed — it means we learned a hypothesis is wrong. Next turn restarts at Hypothesize with the refuted hypothesis as a known-bad anchor." Strictly Research first (not Hypothesize) because the R4 hypothesis itself requires lit grounding (DDI prefactor / sign convention across published F=1 droplet groups) per §A6.
- **Tier**: 0.4 → 0.4 (research stage does not move tier; T65 Hypothesize+critic could move toward 1.0 or back to closed-at-0.4 depending on Research outcome). Investigation `tier_target` remains 3 (Tier-3 candidate per seed.md), but the realistic ceiling on this branch is now ~1.5 (R4 alone cannot recover the 6807× gap without a separate finding).
- **Falsifier this turn evaluated**: none (Research stage is grounding work, not falsifier-execution). Research outcome will populate the R4 falsifier's `hypothesis_grounding` field at T65 Hypothesize.
- **Other in-flight investigations summary**:
  - `barnett-mechanism-2026-05-16` (priority 1): CLOSED tier 3.0 at T29.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3): CLOSED tier 3.0 at T59.
  - `meta-internal-b-unification-2026-05-18` (priority 5): CLOSED tier 1 at T49.
  - `audit-class-scan-2026-05-18-T50` (priority 20): CLOSED tier 2 at T54.
  - `audit-class-scan-2026-05-18-T61` (priority 20): CLOSED tier 2 at T63. AUDIT_DUE drift advisory clear; next cycle ~T72.
  - `meta-stage-routing-2026-05-18` (priority 25): CLOSED tier 0 at T60 (REFUTED-BY-CONFOUNDER).
  - `judge-in-operator-bug-2026-05-18` (priority 2): CLOSED tier 2 at T54.
  - `meta-critic-placement-2026-05-17` (priority 50): meta investigation parked at Observe; per §B2 dormant+priority>=50 eliminator, NOT picked.
  - `fullbdg-f6-polar-3000x` (priority 99): contained, dormant — skip.
- **Scheduler** (`scheduler_64.json`): policy=JULIA_GPU_OK, allowed_workloads includes `researcher` (and all others; window 1,175,720s left = ~13.6 days). researcher dispatch is text-only with no julia execution, fits any policy.
- **Last judge verdict** (T63): PASS (30/30 success criteria). No `triggered_failure_modes`. T63 director's `investigation_update.if_success_advance_to_stage` chained to: "T64 director picks next investigation per seed.md priority order (all priority-1/2/3 physics CLOSED at tier 3 or dormant; anko may surface a new investigation, otherwise the loop is in a clean steady-state moment between physics arcs — consider yan-li-saito R4 dormancy-vs-revive decision OR audit refresh OR explicit anko-prompt request)." T64 honors option (a).
- **Drift signals (T63 footer)**: AUDIT_DUE cleared (T63 closure). DRIFT_COST_INFLATION likely fades (T63 was 1.76M effective < T62 2.32M). DRIFT_MANUSCRIPT_DELTA_ZERO persists (no manuscript writes by design per `feedback_manuscript_is_not_the_essence`). DRIFT_CODE_DELTA_ZERO will activate at T64 (researcher dispatch = no code touch); this is intended for a Research stage and not a meaningful drift signal.
- **Sibling-class housekeeping note** (T63 sim/turn_63.md §5 observations): T62 implementer wrote verbose description strings into `current_stage` fields for `audit-class-scan-2026-05-18-T50` (line 2003), `yan-li-saito-2026-reproduction` (line 1813), and `audit-class-scan-2026-05-18-T61` (line 2109; later corrected at T63 closure but the closing_note string is still verbose). Per `feedback_fix_the_class_not_the_instance` 3-second test: this is a sibling-class deferred cleanup (3 entries with verbose strings instead of canonical short labels). NOT in scope for T64 researcher dispatch (researcher does not edit state.json). Queue as T65+ housekeeping for an `implementer_text` micro-dispatch OR fold into the next state.json edit when one is needed for whatever direction this Research lands.

## 2. Recent-turn audit (last 2-3 turns OF yan-li-saito-2026-reproduction specifically)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T45 | Update | INCONCLUSIVE (CONFOUNDER-PARTIAL) | Critic R2b vs R2c update; LHY-LOOKS-OK; routing R2_c-extend-itp. tier 0.75 → 0.7. |
| T48 | Update (normalization audit Option C) | partial-REFUTE LANDED | Framework D₀ ≡ paper D₀ (3.24 vs 3.43 μm⁻³, 5.5% agreement via a_s=21 a₀). 152× gap-anchor flagged at T47 was wrong-input error (T47-critic-input-error: a_s=110 instead of 21 a₀). 6807× density gap to paper target UNCHANGED. tier 0.6 → 0.4. |
| T49 | Document | PASS (closure) | Document closure of T48 normalization audit. Memory annotated with a_s=21 a₀ in D₀. patterns.yaml `paper-unit-system-wrong-param-in-spot-check` added. Investigation entered dormancy at tier 0.4 with `next_falsifier_id: "r4-analytical-ddi-energy-sign-or-dormant-at-0.4"`. |
| T50-T63 (15 turns) | — | — | Investigation dormant; loop spent on audit-class-scan T50 cycle, judge-bug fix, klaus-bch-leak tier-3 closure, audit-class-scan T61 cycle, meta-stage-routing closure. |
| T64 (THIS TURN) | Research (R4 branch) | (TBD) | Researcher grounded lit scan on DDI sign / convention across published F=1 droplet codes — to surface a concrete sign-convention candidate (REVIVE) OR confirm clean conventions (DORMANT-CLOSE) OR identify open question (INCONCLUSIVE). |

## 3. Flow template recall

- **Template**: `verify-claim` (§F1): Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed.
- **Role for Research stage**: `researcher` per §F1 stage table ("Research: researcher — lit scan, prior loop turns, memory entries; sets up Hypothesize with citation chain").
- **Why Research NOW** (vs Hypothesize directly):
  - The R4 falsifier (`r4-analytical-ddi-energy-sign-or-dormant-at-0.4`) is a NEW hypothesis branch within a partially-REFUTED investigation. Per §F1 falsifier-restart: REFUTED restarts at Hypothesize WITH the refuted hypothesis as known-bad anchor. BUT: the R4 hypothesis itself ("the DDI energy sign convention is wrong in the framework") needs external grounding before formalization — what conventions exist in the literature, where do they differ, which (if any) would the framework's `c_dd=μ_0 μ²` (no 4π) be inconsistent with at the F=1 polarized polar limit. Per §A6 research-first: Hypothesize MUST cite a real source.
  - The previous Research stage at T30 (yan-li-saito original Hypothesize) was for the F1-direct-reproduction falsifier (now FALSIFIED at T37/T40). T64 Research is a SECOND Research stage for the R4 sub-falsifier. The investigation's `stages_done` field will gain a second `Research` entry (acceptable per §F1's iterative nature for falsifier branches).
  - Could also collapse Research+Hypothesize into a single theorist turn IF the lit scan is trivially short. But Yan-Li-Saito 2026 PRL + Pfau group conventions + Lima-Pelster conventions span multiple papers; a focused researcher dispatch is the right shape per `feedback_decision_style`.
- **Why NOT continuing audit-class-scan**: T63 closed it cleanly; next cycle is ~T72 per drift cadence. Re-entering it would create cycle interference.
- **Why NOT a different investigation**:
  - Priority 1 (barnett) CLOSED tier 3.
  - Priority 3 (klaus-bch-leak) CLOSED tier 3.
  - Priority 99 (fullbdg-f6-polar) contained, dormant — explicitly NOT to spend turns on per seed.md.
  - Priority 50 (meta-critic-placement) auto-eliminated per §B2 dormant+priority>=50 rule.
  - Only priority-2 thread is yan-li-saito itself; no other anko-surfaced investigation in seed.md.
- **Why NOT noop**: AUDIT_DUE cleared at T63; no scheduler blocker; researcher workload available; window has ~13.6 days. The loop has clean state and budget — doing useful science is cheaper than deferring.
- **Why NOT requesting anko-prompt** (T63 director's option (c)): per Director.md (no explicit guidance), but per `feedback_decision_style`, pick a defensible default. yan-li-saito R4 IS the anko-listed path (priority 2 in seed.md, next_falsifier_id explicitly set). Defensible default.

## 4. Research grounding (§A6)

External / prior references this dispatch grounds against:

1. **Yan-Li-Saito 2026 PRL 136 186502 (arXiv:2605.11670v1, 2026-05-13)** — `memory/yan_li_saito_2026_barnett_paper.md` line 42: `E_ddi = (μ_0 (gμ_B)² / 8π) ∫∫ ρ(r) ρ(r') (1 - 3cos²θ)/|r-r'|³`. Paper uses single-component DDI (spin fully polarized) with explicit `μ_0(gμ_B)²/8π` prefactor. Our framework's `c_dd = μ_0 μ²` (no 4π) — at polar polarized state f=F, m·gμ_B=gμ_B·F → matches paper when our μ ≡ gμ_B·F. **First check**: does the framework's DDI implementation at polar polarized F=1 produce exactly `(μ_0 (gμ_B)² / 8π) ∫∫ ρ²` after accounting for F=1 specialization?
2. **`memory/yan_li_saito_2026_barnett_paper.md` lines 56-75** — Normalization conventions. D₀ = 1/(a_s³ N²); paper anchor 3.43 μm⁻³ vs framework 3.24 μm⁻³ (5.5% match via a_s=21 a₀ at T48). The 6807× density gap is to TARGET density (~13000 D₀-units), not to D₀ itself. R4 must explain this 6807× factor.
3. **`memory/yan_li_saito_2026_barnett_paper.md` lines 96-100** — "Where SpinorBEC.jl needs alignment: 1. LHY χ(ε_dd) bit-exact match. Our `:scalar` mode computes Lima-Pelster Q_5 form; must verify the same `Re ∫₀^π ...` integrand and same factor (5/2)." This is R4's specific scope.
4. **CLAUDE.md project file: "DDI: `c_dd=μ₀μ²` (no 4π), `Q_αβ=k̂_αk̂_β−δ_αβ/3` (no 1/(4π)), `Q(k=0)=0`. Chain self-consistent."** — the framework's documented DDI convention. R4 audit must verify this chain self-consistently matches paper Eq 1 at the F=1 polar polarized limit.
5. **`runs/_loop/state.json` yan-li-saito-2026-reproduction.history[1].note (T49)** — "Document closure of T48 normalization audit per Option C committed routing. Memory annotated with a_s=21 a₀ in D₀; patterns.yaml `paper-unit-system-wrong-param-in-spot-check` added; partial-REFUTE landed." — T48 closed the input-error question. R4 is the analytical-derivation question that remains.
6. **`runs/_loop/director/turn_63.md` §6.investigation_update.next_falsifier_to_test_after** — "T64 director picks next investigation per seed.md priority order... consider yan-li-saito R4 dormancy-vs-revive decision OR audit refresh OR explicit anko-prompt request." T64 honors option (a) with a Research-stage approach (groundwork before commitment).
7. **`runs/_loop/seed.md` lines 35-50** — Yan-Li-Saito 2026 reproduction priority 2, tier 0→3 (only remaining priority-1/2 open thread). Lists "Q3 Free-space ITP convergence" + "Q5 state_zoo has flux-closure-torus builder" as open audit questions; R4 is the deeper-level analytical question about DDI sign.
8. **Pfau group conventions** (Chomaz et al. PRL 122 130405, 2019; Chomaz, Ferrier-Barbut, Wenzel, Bisset, Pohl, Ferlaino 2026 review) — established free-space DDI sign convention for ε_dd > 1 droplet stability. R4 researcher dispatch must compare these conventions to paper Eq 1 + SpinorBEC framework. **External, not memory-only — researcher fetches via WebFetch/WebSearch**.
9. **Lima-Pelster 2011** PRA 84 041604(R) "Quantum fluctuations in dipolar Bose gases" — origin of the χ(ε_dd) integral form. Our `:scalar` mode is documented as using Lima-Pelster Q_5; need to verify the sign convention (especially the Re[] selection for ε_dd > 1 imaginary-part region). **External reference, researcher fetches.**
10. **Memory `feedback_decision_style`** (anko 2026-05-15): pick defaults and move. R4 dormancy-vs-revive decision had been deferred 15 turns — picking a defensible default (Research stage grounded in lit) is the right move.
11. **Memory `feedback_mechanical_vs_investigation_threshold`** (anko 2026-05-18, 3-second test): this is NOT a mechanical change. The R4 question requires actual lit reading + analytical comparison ("Could I describe the entire solution in one sentence?" → NO; "Is the success criterion testable by `grep` or `compiles`?" → NO). Research stage flow is appropriate.
12. **Memory `feedback_manuscript_is_not_the_essence`** (anko 2026-05-15): R4 is verification of an external claim against the framework, not manuscript polish. D1 axis.
13. **Director.md §F1 falsifier-restart rule**: REFUTED → restart at Hypothesize with refuted hyp as known-bad anchor. Modified here by §A6 research-first: Hypothesize needs lit grounding first when the new hypothesis spans an external-paper / framework-convention comparison.
14. **Grounded autonomous research (arXiv:2604.12198, Director.md §G "gold standard for Update stage")**: agent proposed HSE, ran it, refuted its own prior. Pattern: revisit a partial-REFUTE branch with a fresh hypothesis grounded in external lit — the explicit modeled behavior that T64 is enacting.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verify-existing-physics, primary axis)**. The framework's DDI sign / prefactor convention chain (`c_dd = μ_0 μ²`, `Q_αβ = k̂_αk̂_β − δ_αβ/3`, `Q(k=0)=0`) is a Tier-1/2 claim (internal regression covered; closed-form / sympy verification partial). R4 Research stage is the lit-grounded pathway toward Tier-2-confirmed-against-published-paper status: either (a) find a concrete sign-convention bug in our framework → BUG-9 candidate; (b) confirm framework-paper equivalence at F=1 polar polarized limit → DDI claim chain promoted toward Tier 3 in the yan-li-saito context. Also pre-positions **D3** path (if researcher returns REVIVE verdict, T65 spawns a build-theory child for the analytical derivation, grounded in citation chain).
- **Tier ladder position**: T64 does not move yan-li-saito's tier (Research stage is groundwork; tier moves at Update). Investigation stays at 0.4. Project Tier-3 count stays at 2 (barnett + klaus-bch-leak).
- **Manuscript NOT in scope** (per `feedback_manuscript_is_not_the_essence`). Memory file may be updated at T65+ Document if a verdict lands.
- **Cost frame**: researcher Research stage with focused brief and 2-4 external paper reads + framework grep. Expected ~2.0-2.5M effective: lit-scan reads (~1.0M) + framework convention audit greps (~0.3M) + 6-8 page Markdown writing (~0.7M) + bookkeeping (~0.3M). Stays within per-turn cap (6M) with margin.
- **Drift signal forecast post-T64**: AUDIT_DUE remains clear (~T72). DRIFT_COST_INFLATION should fade (T64 ~2.0-2.5M is mid-range for researcher). DRIFT_MANUSCRIPT_DELTA_ZERO persists (no manuscript). DRIFT_CODE_DELTA_ZERO=1 (researcher = no code; intended). novel_claim_zero: depends on verdict (REVIVE → novel claim about DDI sign-convention candidate; DORMANT-CLOSE → no new claim, REFUTED-CLEAN; INCONCLUSIVE → defer claim). Expected verdict: PASS regardless of REVIVE/DORMANT-CLOSE/INCONCLUSIVE — those are SCIENTIFIC verdicts decided at T65 Hypothesize/Update, not the T64 operational verdict.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "yan-li-saito-2026-reproduction",
  "stage_advancing_to": "Research",
  "subagent_type": "researcher",
  "rationale": "T63 closed audit-class-scan-T61 cycle cleanly at tier 2; T63 director's investigation_update flagged three options for T64. Per anko's seed.md priority 2 (only remaining open priority-1/2 physics thread) and per feedback_decision_style ('pick defaults and move'), select option (a) — yan-li-saito R4 dormancy-vs-revive decision. The R4 falsifier (next_falsifier_id 'r4-analytical-ddi-energy-sign-or-dormant-at-0.4') concerns the framework's DDI sign / prefactor convention chain at the F=1 polar polarized limit vs Yan-Li-Saito 2026 PRL Eq 1 (μ_0(gμ_B)²/8π · ∫∫ρρ'·(1-3cos²θ)/|r-r'|³). Per §F1 falsifier-restart rule + §A6 research-first, the new hypothesis branch needs lit grounding BEFORE Hypothesize formalization — a focused researcher dispatch comparing Yan-Li-Saito Eq 1 / Pfau group conventions / Lima-Pelster χ(ε_dd) / SpinorBEC framework c_dd=μ_0 μ² chain. Three verdict outcomes: REVIVE (concrete sign-convention candidate found → T65 build-theory child for analytical derivation); DORMANT-CLOSE (clean conventions everywhere → close yan-li-saito at tier 0.4 REFUTED-CLEAN at T65); INCONCLUSIVE (open question identified, defer). Researcher dispatch is text-only with no julia execution; researcher does NOT edit state.json (queued sibling-class cleanup for T65+). Expected cost ~2.0-2.5M effective, within per-turn cap.",
  "brief": "## ROLE\n\nYou are researcher. T64 §F1 Research stage of yan-li-saito-2026-reproduction R4 falsifier branch (re-entering Research after the investigation went dormant at T49 tier 0.4 partial-REFUTE). Mission: produce a focused, lit-grounded analytical-DDI-sign-convention audit that lets T65 director decide whether to spawn a build-theory child (REVIVE), close the investigation REFUTED-CLEAN at tier 0.4 (DORMANT-CLOSE), or defer (INCONCLUSIVE).\n\n## REQUIRED READING (READ FIRST, BEFORE WRITING)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_64.md` (this director report) — full rationale + §6 contract.\n2. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/yan_li_saito_2026_barnett_paper.md` end-to-end — paper's Eq 1 + normalization + 'Where SpinorBEC.jl needs alignment' section (lines 96-100).\n3. `/tmp/yan_li_saito_2605.11670.pdf` IF available — paper local copy per memory line 13. If not present (test with `test -f /tmp/yan_li_saito_2605.11670.pdf`), proceed with the memory's verbatim excerpts and arXiv WebFetch.\n4. `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` investigation `yan-li-saito-2026-reproduction` — entire entry including falsifiers, history, falsifiers_tested. Especially `next_falsifier_id: 'r4-analytical-ddi-energy-sign-or-dormant-at-0.4'`.\n5. `/home/suzume/workspace/BEC-simulation/CLAUDE.md` — section on DDI convention: 'DDI: `c_dd=μ₀μ²` (no 4π), `Q_αβ=k̂_αk̂_β−δ_αβ/3` (no 1/(4π)), `Q(k=0)=0`. Chain self-consistent.' Also section on `¹⁵¹Eu` and `Known limitations`.\n6. Framework's `:scalar` DDI implementation files. Use `Grep` to locate (NOT full read unless needed):\n   - `/home/suzume/workspace/BEC-simulation/src/hamiltonian/interactions/ddi*.jl`\n   - `/home/suzume/workspace/BEC-simulation/src/hamiltonian/interactions/lhy/`\n   - `/home/suzume/workspace/BEC-simulation/src/foundation/types/ddi*.jl`\n   - Specifically: how `c_dd` is consumed in the FFT kernel; how the angular factor enters (`(1-3cos²θ)` vs `(3cos²θ-1)` sign); how the spin-polarized → scalar reduction is performed at F=1.\n7. `/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_grid_refinement/` and `/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/` — prior T31-T49 yan-li-saito runs. Especially `runs/yan_li_saito_f1_torus_gs/run_t35_post.jl:88-90` per memory line 75 (D0_factor derivation). Look for prior DDI sign / convention discussion in commit history or notes.\n8. The 4 prior loop turns specifically on DDI sign / convention question:\n   - `/home/suzume/workspace/BEC-simulation/runs/_loop/critic/turn_42.md` (LHY-LOOKS-OK / DDI-prefactor-bit-equal).\n   - `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_30_yan_li_saito_q_resolution.md` (original 5-row paper→framework mapping at T30; Q-paper-energy-table NOT_FOUND there).\n   - `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_48.md` (T48 normalization audit Option C; 152× resolved as input error, gap 6807× unchanged).\n9. External — use `WebFetch` for the published paper PDF if local copy missing:\n   - arXiv:2605.11670v1 (Yan-Li-Saito 2026 PRL).\n   - Lima-Pelster PRA 84 041604(R) 2011 (χ(ε_dd) origin).\n   - Chomaz, Ferrier-Barbut, Wenzel et al. PRL 2019 OR Chomaz review 2026 (Pfau group free-space DDI conventions).\n10. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/feedback_decision_style.md` (pick defaults and move; do not deliberate endlessly).\n\n## YOUR JOB — 1 ARTIFACT\n\nWrite a single deliverable at `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_64_yan_li_saito_r4_ddi_sign.md` (6-8 pages, English only, no emojis). Required sections (numbered):\n\n```markdown\n---\nturn: 64\nsubagent: researcher\ninvestigation_id: yan-li-saito-2026-reproduction\nfalsifier_id: r4-analytical-ddi-energy-sign-or-dormant-at-0.4\nstage: Research\ntopic_tags: [...]\n---\n\n# Turn 64 — Researcher Report: Yan-Li-Saito R4 DDI Sign Convention Audit\n\n## §1. Scope\n\nOne paragraph. What R4 is, why it was deferred, what this Research stage answers.\n\n## §2. Convention chain — Yan-Li-Saito 2026 PRL Eq 1\n\nVerbatim Eq 1 from paper (per memory excerpt or fresh fetch). Identify:\n- Angular kernel sign: `(1-3cos²θ)/|r-r'|³` (paper) vs framework's documented `Q_αβ = k̂_αk̂_β − δ_αβ/3`.\n- Prefactor: `μ_0(gμ_B)²/8π` (paper) vs framework's `c_dd = μ_0 μ²` (no 4π).\n- F=1 polar polarized reduction: how the spin-projected DDI in paper Eq 1 reduces to scalar `(μ_0(gμ_B)²/8π)∫∫ρ²·(1-3cos²θ)/|r-r'|³` when f=F everywhere.\n\n## §3. Convention chain — SpinorBEC framework `:scalar` mode\n\nGrep + cite specific files/lines. Identify:\n- `c_dd` consumption in DDI FFT kernel.\n- Angular factor implementation (`Q(k) = k̂_αk̂_β − δ_αβ/3` in k-space).\n- F=1 specialization at polar polarized state (f → F-aligned everywhere).\n- LHY: `:scalar` mode computes Lima-Pelster Q_5 χ(ε_dd) integral; cite framework file + verify sign convention (especially `Re[]` for ε_dd > 1 imaginary region).\n\n## §4. Bit-exact comparison at F=1 polar polarized limit\n\nAt the F=1 polar polarized state with μ ≡ gμ_B·F (F=1 → μ = gμ_B): does the framework's DDI energy expression equal paper Eq 1 term-by-term? Show the algebra explicitly. Identify ANY discrepancy in prefactor (e.g., missing 8π, missing factor of 2, etc.) or angular-factor sign.\n\n## §5. LHY χ(ε_dd) at ε_dd=1.2 — sign and convention\n\nLima-Pelster Q_5 form: `χ(ε_dd) = Re ∫₀^π sinθ [1 + ε_dd(3cos²θ-1)]^(5/2) / 2 dθ`. At ε_dd=1.2, the integrand becomes complex over part of the θ range (where `1 + 1.2·(3cos²θ-1) < 0`). Verify:\n- Paper's selection of Re[] vs principal-value vs imaginary-part-discard convention.\n- SpinorBEC's `:scalar` mode handling of this regime — does the implementation use the same `Re[]` selection?\n- Numerical χ(1.2) value cross-checked: paper gives ~1.6 (if listed) vs framework's `lima_pelster_Q5` output at ε_dd=1.2.\n\n## §6. Stuttgart / Pfau / Chomaz group conventions\n\nBrief external lit check (2-3 papers minimum). Specifically:\n- Chomaz 2020 PRL (or Chomaz review 2026) free-space DDI sign for ε_dd > 1 droplet stability. Does Pfau group prefactor convention match Yan-Li-Saito's `μ_0(gμ_B)²/8π`?\n- One other group (Innsbruck or otherwise) for triangulation.\n- Is there a SIGN-LEVEL discrepancy in the literature, or only prefactor/normalization conventions?\n\n## §7. 6807× density gap — what could explain it\n\nThe T48 partial-REFUTE found D₀ ≡ paper D₀ (5.5%) but the target density gap is 6807×. Candidate hypotheses (rank-order by plausibility based on §2-§6 above):\n- H1: DDI prefactor wrong by O(10-100) → cumulative effect via χ(ε_dd) and self-binding scaling → 6807×. Test: bit-exact §4 audit.\n- H2: LHY χ(ε_dd>1) sign or Re[] convention wrong → wrong droplet self-binding pressure → wrong target density. Test: §5 audit.\n- H3: GS convergence problem (ITP did not reach the deep droplet branch from T40 P0-P4 initial conditions); independent of DDI/LHY signs. Test: re-investigate ITP convergence, NOT in R4 scope (R4 is analytical only).\n- H4: Paper's reported target density 13000 D₀-units is itself in error or normalized differently. Test: re-fetch paper Fig 1c colormap range.\n- ANY other plausible candidate from §2-§6.\n\nDo NOT speculate; rank-order on EVIDENCE found in §2-§5.\n\n## §8. Verdict\n\nExactly one of three lines, with justification:\n\n- **REVIVE**: a concrete DDI / LHY sign or prefactor candidate emerged from §4 or §5 above; T65 should spawn a build-theory child for analytical-derivation of the corrected expression, grounded in the citation chain established here.\n- **DORMANT-CLOSE**: no sign-convention discrepancy found across §2-§6; framework-paper equivalence at F=1 polar polarized limit confirmed term-by-term. T65 closes yan-li-saito at tier 0.4 REFUTED-CLEAN with the 6807× gap attributed to H3/H4 (out of R4 scope) or simply unexplained.\n- **INCONCLUSIVE**: §2-§6 reveal an open question that cannot be resolved without code-execution (sympy / julia). T65 director must spawn a sympy or julia_cpu_light dispatch.\n\nIf REVIVE: propose 1-2 specific build-theory child investigations (id, hypothesis, falsifier, expected tier_target).\nIf DORMANT-CLOSE: propose the closing_note text for state.json.\nIf INCONCLUSIVE: propose the next dispatch shape (subagent + brief).\n\n## §9. Citation chain\n\nList all external references actually consulted (paper URL / arXiv ID + section + page range). Mark each as 'fetched-this-turn' or 'memory-cited' or 'framework-source-cited'. Minimum 4 external references for a build-theory-grounded Research stage.\n\n## §10. Metrics block (single fenced ```json``` block, REQUIRED for judge)\n\n```json\n{\n  \"experiment_kind\": \"text_only\",\n  \"investigation_kind\": \"physics\",\n  \"src_files_modified\": 0,\n  \"new_analysis_scripts_written\": 0,\n  \"agents_md_files_modified\": 0,\n  \"state_json_modified\": false,\n  \"patterns_yaml_modified\": false,\n  \"memory_files_added\": 0,\n  \"research_md_files_added\": 1,\n  \"research_md_files_added_list\": [\"turn_64_yan_li_saito_r4_ddi_sign.md\"],\n  \"research_section_count\": 10,\n  \"external_references_consulted_count\": <N, >= 4>,\n  \"external_references_fetched_this_turn_count\": <N>,\n  \"framework_source_files_grepped_count\": <N>,\n  \"verdict\": \"REVIVE\" | \"DORMANT-CLOSE\" | \"INCONCLUSIVE\",\n  \"sign_convention_discrepancy_found\": <bool>,\n  \"prefactor_discrepancy_found\": <bool>,\n  \"lhy_chi_convention_discrepancy_found\": <bool>,\n  \"investigation_id\": \"yan-li-saito-2026-reproduction\",\n  \"falsifier_id\": \"r4-analytical-ddi-energy-sign-or-dormant-at-0.4\",\n  \"stage_advancing_to\": \"Research\",\n  \"flow_template\": \"verify-claim\",\n  \"judge_py_unchanged\": true,\n  \"agents_md_unchanged\": true,\n  \"src_subtree_untouched\": true\n}\n```\n```\n\n## RECOMMENDED EXECUTION SHAPE\n\n1. Read all 10 required references end-to-end (or grep + skim for §6-7 framework files).\n2. WebFetch the Yan-Li-Saito paper's Eq 1 region if local PDF absent; WebFetch 2-3 external lit conventions papers (Lima-Pelster 2011 + Chomaz 2020 minimum).\n3. Write the deliverable at the exact absolute path. Use `Write` tool (memory.md is content-rich; not Bash heredocs).\n4. Verify §10 Metrics JSON is parseable: `python3 -c \"import json, re; t=open('/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_64_yan_li_saito_r4_ddi_sign.md').read(); m=re.search(r'```json\\\\n(.+?)\\\\n```', t, re.DOTALL); json.loads(m.group(1)); print('OK_metrics_json')\"`.\n5. Optionally cross-check section count is 10 with `grep -c '^## §' /home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_64_yan_li_saito_r4_ddi_sign.md`.\n\n## CONSTRAINTS\n\n- **Files allowed to create**: `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_64_yan_li_saito_r4_ddi_sign.md` (the deliverable). NO other files.\n- **Files FORBIDDEN to modify**: `src/`, `runs/eu151_*/`, `runs/yan_li_saito_*/` (read-only), `scripts/`, `.claude/agents/*`, `.claude/scripts/*`, `runs/_loop/patterns.yaml`, `runs/_loop/state.json`, `runs/_loop/seed.md`, any memory file. Also FORBIDDEN: writing to `runs/_loop/director/` or `runs/_loop/sim/` (researcher reports go in `runs/_loop/research/`).\n- **No julia execution required**. No sympy execution. Researcher = lit + framework-grep + writing.\n- **English only. No emojis.**\n- **Absolute paths in all Read / Write / WebFetch tool calls.**\n- **Cost budget**: stay within ~2.5M effective tokens, ~12 min wall hard cap.\n- **No fabrication**: every external reference cited in §9 must be a real source with retrievable identifier (arXiv ID / DOI / journal+volume). NO 'see related work' hand-waves.\n- **3-second test does NOT apply here** (per `feedback_mechanical_vs_investigation_threshold`): this is genuine investigation work (lit comparison + analytical derivation cross-check), not mechanical execution.\n\n## SUCCESS CRITERIA (see §6.success_criteria in director report)\n\nMust produce: (a) deliverable at the exact path; (b) 10 numbered sections (§1-§10); (c) §10 Metrics JSON parseable; (d) verdict ∈ {REVIVE, DORMANT-CLOSE, INCONCLUSIVE}; (e) external_references_consulted_count >= 4; (f) framework_source_files_grepped_count >= 2; (g) src_subtree_untouched; (h) state.json/patterns.yaml/memory unchanged.\n\n## REPORTING DISCIPLINE\n\n- If you discover during research that one of the prior loop turns (T42/T48) ALREADY did the bit-exact check (§4), report this in §4 with a citation to the file/line and proceed to §5-§8 (don't re-do — accept the prior finding).\n- If §2-§5 are clean and §6 finds no group-level discrepancy, the honest verdict is DORMANT-CLOSE. Do NOT manufacture a REVIVE just to keep the investigation alive. Per `feedback_decision_style`, a clean DORMANT-CLOSE is a legitimate Tier-1 verification outcome.\n- If external papers are not accessible (WebFetch fails, no local PDF), report this in §9 with the attempted URLs and proceed with memory-cited content; mark verdict accordingly (likely INCONCLUSIVE with 'external-lit-access-blocked' subreason).\n- Do not write code or scripts. Researcher = reading + writing only.",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "investigation_kind",
      "src_files_modified",
      "new_analysis_scripts_written",
      "agents_md_files_modified",
      "state_json_modified",
      "patterns_yaml_modified",
      "memory_files_added",
      "research_md_files_added",
      "research_md_files_added_list",
      "research_section_count",
      "external_references_consulted_count",
      "external_references_fetched_this_turn_count",
      "framework_source_files_grepped_count",
      "verdict",
      "sign_convention_discrepancy_found",
      "prefactor_discrepancy_found",
      "lhy_chi_convention_discrepancy_found",
      "investigation_id",
      "falsifier_id",
      "stage_advancing_to",
      "flow_template",
      "judge_py_unchanged",
      "agents_md_unchanged",
      "src_subtree_untouched"
    ],
    "optional": [],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/state.json && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_64.md && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/yan_li_saito_2026_barnett_paper.md && test -f /home/suzume/workspace/BEC-simulation/CLAUDE.md && test ! -f /home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_64_yan_li_saito_r4_ddi_sign.md && python3 -c \"import json; d = json.load(open('/home/suzume/workspace/BEC-simulation/runs/_loop/state.json')); inv = d['investigations']['yan-li-saito-2026-reproduction']; assert inv['tier_current'] == 0.4, f'yan-li-saito tier_current must be 0.4 pre-T64; got {inv[chr(34)+chr(116)+chr(105)+chr(101)+chr(114)+chr(95)+chr(99)+chr(117)+chr(114)+chr(114)+chr(101)+chr(110)+chr(116)+chr(34)]}'; assert inv['priority'] == 1 or inv['priority'] == 2, 'priority must be 1 or 2 per seed.md priority order'; assert inv.get('next_falsifier_id') == 'r4-analytical-ddi-energy-sign-or-dormant-at-0.4', 'next_falsifier_id must match R4 branch'; print('OK precondition: yan-li-saito at tier 0.4 with R4 falsifier id ready for Research stage')\""
  },
  "success_criteria": [
    {
      "id": "experiment_kind_correct",
      "metric": "experiment_kind",
      "operator": "==",
      "value": "text_only",
      "tolerance": null,
      "rationale": "Research stage is text-only lit + framework grep."
    },
    {
      "id": "investigation_kind_physics",
      "metric": "investigation_kind",
      "operator": "==",
      "value": "physics",
      "tolerance": null,
      "rationale": "yan-li-saito-2026-reproduction is kind=physics per state.json."
    },
    {
      "id": "src_unchanged",
      "metric": "src_files_modified",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Research stage must not modify src/."
    },
    {
      "id": "no_scripts_committed",
      "metric": "new_analysis_scripts_written",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Researcher does not write executable scripts."
    },
    {
      "id": "no_agents_md_changes",
      "metric": "agents_md_files_modified",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Research stage does not touch agent prompts."
    },
    {
      "id": "state_json_untouched",
      "metric": "state_json_modified",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "Researcher does not edit state.json; T65 implementer_text will close or revive based on verdict."
    },
    {
      "id": "patterns_yaml_untouched",
      "metric": "patterns_yaml_modified",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "Researcher does not edit patterns.yaml."
    },
    {
      "id": "no_memory_files_added",
      "metric": "memory_files_added",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Memory entry creation is T65+ Document-stage work, not T64 Research."
    },
    {
      "id": "exactly_one_research_md_added",
      "metric": "research_md_files_added",
      "operator": "==",
      "value": 1,
      "tolerance": null,
      "rationale": "Single deliverable at the exact specified path."
    },
    {
      "id": "research_md_correct_filename",
      "metric": "research_md_files_added_list",
      "operator": "==",
      "value": ["turn_64_yan_li_saito_r4_ddi_sign.md"],
      "tolerance": null,
      "rationale": "Exact filename match; no spurious extras."
    },
    {
      "id": "ten_sections",
      "metric": "research_section_count",
      "operator": "==",
      "value": 10,
      "tolerance": null,
      "rationale": "10 numbered sections per brief (§1-§10)."
    },
    {
      "id": "min_four_external_refs",
      "metric": "external_references_consulted_count",
      "operator": ">=",
      "value": 4,
      "tolerance": null,
      "rationale": "Build-theory-grounded Research stage requires >= 4 external references per §A6."
    },
    {
      "id": "min_two_framework_files_grepped",
      "metric": "framework_source_files_grepped_count",
      "operator": ">=",
      "value": 2,
      "tolerance": null,
      "rationale": "Framework-paper comparison requires at least DDI implementation + LHY implementation grep."
    },
    {
      "id": "verdict_one_of_three",
      "metric": "verdict",
      "operator": "in",
      "value": ["REVIVE", "DORMANT-CLOSE", "INCONCLUSIVE"],
      "tolerance": null,
      "rationale": "Verdict must be exactly one of the three pre-routed values per §8 of brief."
    },
    {
      "id": "investigation_consistent",
      "metric": "investigation_id",
      "operator": "==",
      "value": "yan-li-saito-2026-reproduction",
      "tolerance": null,
      "rationale": "Investigation continuity."
    },
    {
      "id": "falsifier_consistent",
      "metric": "falsifier_id",
      "operator": "==",
      "value": "r4-analytical-ddi-energy-sign-or-dormant-at-0.4",
      "tolerance": null,
      "rationale": "R4 falsifier branch per state.json."
    },
    {
      "id": "stage_consistent",
      "metric": "stage_advancing_to",
      "operator": "==",
      "value": "Research",
      "tolerance": null,
      "rationale": "§F1 Research stage; falsifier-restart for R4 branch."
    },
    {
      "id": "template_consistent",
      "metric": "flow_template",
      "operator": "==",
      "value": "verify-claim",
      "tolerance": null,
      "rationale": "§F1 verify-claim template per state.json."
    },
    {
      "id": "judge_py_intact",
      "metric": "judge_py_unchanged",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "T53 fixed judge.py; T64 must not touch."
    },
    {
      "id": "agents_md_intact",
      "metric": "agents_md_unchanged",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Research stage is lit + writing only."
    },
    {
      "id": "src_subtree_untouched_explicit",
      "metric": "src_subtree_untouched",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Research stage does not touch src/."
    }
  ],
  "failure_modes": [
    {
      "if": "research_md_files_added != 1 OR research_md_files_added_list != ['turn_64_yan_li_saito_r4_ddi_sign.md']",
      "category": "operational",
      "next_action": "T65 director instructs researcher to re-Write the deliverable at the exact absolute path. Verify with `ls /home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_64*.md` post-write."
    },
    {
      "if": "research_section_count != 10",
      "category": "operational",
      "next_action": "T65 director instructs researcher to append missing section(s) per §1-§10 schema. Section headers are `## §1. Scope` ... `## §10. Metrics block`."
    },
    {
      "if": "external_references_consulted_count < 4",
      "category": "operational",
      "next_action": "T65 director instructs researcher to expand §9 citation chain with additional external lit (Pfau group / Lima-Pelster / Chomaz). Per §A6, build-theory-grounded Research requires >= 4 external sources."
    },
    {
      "if": "verdict not in ['REVIVE', 'DORMANT-CLOSE', 'INCONCLUSIVE']",
      "category": "operational",
      "next_action": "T65 director instructs researcher to commit to one of the three pre-routed verdict values. Hedge-verdicts ('MAYBE-REVIVE', 'NEEDS-FURTHER-STUDY') are not acceptable — they are equivalent to INCONCLUSIVE per the brief and must use that label."
    },
    {
      "if": "verdict == 'REVIVE' AND sign_convention_discrepancy_found == false AND prefactor_discrepancy_found == false AND lhy_chi_convention_discrepancy_found == false",
      "category": "scientific_inconsistency",
      "next_action": "T65 director audits researcher report — REVIVE verdict without a concrete discrepancy candidate is internally inconsistent. Critic side-dispatch may be needed to challenge the verdict OR researcher re-do §4-§5 with concrete algebra."
    },
    {
      "if": "verdict == 'DORMANT-CLOSE'",
      "category": "scientific_dormant_close",
      "next_action": "T65 director dispatches implementer_text Document-stage to close yan-li-saito-2026-reproduction at tier 0.4 REFUTED-CLEAN. Memory entry + state.json closing_note with R4 verdict. Investigation moves from dormant to closed cleanly. Loop returns to seed.md priority order — anko-prompt for new investigation OR audit refresh."
    },
    {
      "if": "verdict == 'REVIVE'",
      "category": "scientific_revive",
      "next_action": "T65 director spawns build-theory child investigation per researcher's §8 proposal. Child Hypothesize stage with theorist or critic+sympy depending on the discrepancy candidate's nature. Parent yan-li-saito-2026-reproduction tier advances modestly (0.4 → 0.5 acknowledging the lit-grounded sub-investigation pathway)."
    },
    {
      "if": "verdict == 'INCONCLUSIVE'",
      "category": "scientific_inconclusive",
      "next_action": "T65 director re-routes per researcher's §8 specific next-dispatch proposal (sympy or julia_cpu_light). Investigation remains dormant if the next dispatch shape is not anko-prioritized; explicit defer-noted in state.json."
    },
    {
      "if": "src_files_modified > 0 OR state_json_modified == true OR patterns_yaml_modified == true OR memory_files_added > 0",
      "category": "scope_violation",
      "next_action": "T65 director treats as scope violation. Revert via `git restore`. Researcher must produce a SINGLE deliverable at the specified path; no state.json / memory / patterns.yaml / src edits."
    },
    {
      "if": "precondition check fails (yan-li-saito tier_current != 0.4 OR next_falsifier_id != R4)",
      "category": "framework_error",
      "next_action": "T65 director investigates state corruption: did some other turn modify yan-li-saito? Run `git log -p --grep='yan-li-saito' runs/_loop/state.json` to find unexpected modification. Escalate via noop if mystery."
    },
    {
      "if": "external lit web access blocked (WebFetch failures across multiple URLs)",
      "category": "operational",
      "next_action": "T65 director acknowledges in §6 reroute: lit-access-blocked → researcher proceeds with memory-cited references only, verdict likely INCONCLUSIVE with 'lit-access-blocked' subreason. T65 either dispatches a second researcher attempt with alternative access OR closes at INCONCLUSIVE deferred."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 3000000,
    "wall_time_hard_cap_sec": 900
  },
  "budget": {
    "expected_cost_eff": 2200000,
    "expected_wall_time_sec": 600,
    "split_by_subtask": {
      "read_required_10_files_memory_state_claudemd_director_prior_research": 400000,
      "framework_grep_ddi_and_lhy_files": 200000,
      "webfetch_external_3_papers_yan_li_saito_lima_pelster_chomaz": 600000,
      "compose_research_md_10_sections_with_eq_comparison": 800000,
      "verify_metrics_json_parses_and_section_count": 100000,
      "bookkeeping": 100000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Hypothesize (T65 — if verdict=REVIVE, theorist spawns build-theory child per researcher §8 proposal; if verdict=DORMANT-CLOSE, implementer_text Document closes yan-li-saito at tier 0.4 REFUTED-CLEAN; if verdict=INCONCLUSIVE, T65 re-routes per researcher §8 next-dispatch proposal). Tier remains 0.4 at T64; advances only at T65+ depending on verdict.",
    "if_success_tier_becomes": 0.4,
    "if_refuted_advance_to_stage": "(N/A; Research stage is groundwork, not falsifier-execution — no scientific refutation possible at this stage)",
    "if_refuted_tier_becomes": 0.4,
    "if_inconclusive_advance_to_stage": "Research (re-dispatch researcher with corrected contract per failure_modes; missing sections or section count != 10 or refs < 4)",
    "if_inconclusive_tier_becomes": 0.4,
    "next_falsifier_to_test_after": "Depends on verdict. REVIVE → spawn build-theory child investigation; that child gets its own falsifier set. DORMANT-CLOSE → investigation closed; T66+ director picks per seed.md (anko may surface new priority-1 investigation; otherwise audit refresh ~T72 OR explicit anko-prompt). INCONCLUSIVE → defer-noted; T65 picks per researcher §8 next-dispatch proposal."
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read `runs/_loop/_local/scheduler_64.json` (policy=JULIA_GPU_OK; researcher in allowed_workloads; window 1,175,720s left; VRAM 12,972 MB free; foreign_julia=0; RAM 25.04 GB avail).
- [x] Read `runs/_loop/state.json` (active_investigation_id was `audit-class-scan-2026-05-18-T61` closed at T63; yan-li-saito-2026-reproduction confirmed at tier 0.4 dormant with R4 next_falsifier_id; switching active_investigation_id to yan-li-saito-2026-reproduction this turn).
- [x] Read `runs/_loop/seed.md` end-to-end (priority 2 yan-li-saito open; no new investigation surfaced since T62).
- [x] Read `runs/_loop/director/turn_63.md` (T63 dispatch + PASS + T64 routing options listed).
- [x] Read `runs/_loop/judge/turn_63.json` (T63 PASS; 30/30 criteria; no triggered_failure_modes).
- [x] Read `runs/_loop/sim/turn_63.md` (T63 implementer report; observed sibling-class verbose-string-in-current_stage issue; queued for T65+ cleanup).
- [x] Read `runs/_loop/judge/turn_62.json` (T62 PASS context for T63 chain).
- [x] Read memory `yan_li_saito_2026_barnett_paper.md` (paper Eq 1 + normalization + 'Where SpinorBEC.jl needs alignment' section — provides §2-§4 grounding for researcher brief).
- [x] Read memory `feedback_mechanical_vs_investigation_threshold.md` (3-second test: R4 is genuine investigation, not mechanical; researcher dispatch appropriate).
- [x] investigation_id `yan-li-saito-2026-reproduction` is consistent with state.json; switched from prior turn's audit-class-scan-2026-05-18-T61.
- [x] stage_advancing_to `Research` is correct per §F1 falsifier-restart rule + §A6 research-first; Research stage role = researcher per §F1 stage table.
- [x] subagent_type `researcher` matches §F1 role_per_stage[Research]; in scheduler.allowed_workloads.
- [x] success_criteria 21 criteria, all machine-evaluable (==, >=, in).
- [x] failure_modes cover 11 outcomes (operational missing deliverable/sections/refs, scientific inconsistency, scientific dormant-close/revive/inconclusive routing, scope violation, framework_error precondition fail, operational web-access-blocked).
- [x] observable_manifest precondition_check tests 5 file existences + absence of to-be-created deliverable (idempotency) + Python assertion that yan-li-saito tier_current==0.4 and next_falsifier_id matches R4.
- [x] budget 2.2M expected, 3.0M tolerance; wall 600s expected, 900s hard cap. Within per-turn 6M cap with margin.
- [x] §A6 research-first citation present (14 references; primary: Yan-Li-Saito 2026 PRL Eq 1, memory paper-summary, CLAUDE.md DDI convention, prior loop turns T42/T48 critic/sim, Pfau group conventions external, Lima-Pelster external, Grounded autonomous research arXiv:2604.12198 pattern reference).
- [x] §A5 D-axis: D1 (verify-existing-physics; DDI sign/prefactor chain is Tier-1/2 claim — R4 Research promotes toward Tier-2 published-paper-equivalence audit). Pre-positions D3 if REVIVE. NOT manuscript polish.
- [x] §F1 verify-claim template followed: Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed. T64 = second Research stage (for R4 sub-falsifier branch). Acceptable per falsifier-restart pattern.
- [x] Considered alternative dispatches:
  - Continue audit-class-scan: NOT due until ~T72 per drift cadence; would create cycle interference.
  - Dispatch noop: scheduler clear, budget clear, useful science exists.
  - Skip yan-li-saito and request anko-prompt: per `feedback_decision_style`, pick defensible default. yan-li-saito IS anko-prioritized (seed.md priority 2).
  - Dispatch implementer_text directly to close yan-li-saito at tier 0.4: would PREEMPT the R4 verdict without doing the actual analytical audit. Premature.
  - Dispatch theorist Hypothesize directly (skip Research): would violate §A6 research-first; Hypothesize needs lit-grounding for an external-paper / framework-convention comparison.
  - Fold the sibling-class state.json verbose-string cleanup into this turn: researcher does not edit state.json; cleanup queued for T65+.
  - **Research stage dispatch with researcher is the highest leverage**: cheap (2.2M expected), grounded in §F1 + §A6, pre-routes T65 with 3 verdict-specific decision branches (REVIVE / DORMANT-CLOSE / INCONCLUSIVE), advances D1 (DDI sign convention verification depth), unblocks the 15-turn yan-li-saito dormancy.
- [x] All file paths in brief are absolute.
- [x] Brief explicitly forbids src/ touch, state.json modification, patterns.yaml modification, memory writes, agents.md modification, julia execution, sympy execution.
- [x] research/turn_64 deliverable has exact filename specification: `turn_64_yan_li_saito_r4_ddi_sign.md`.
- [x] §10 Metrics JSON block has 24 fields; verdict ∈ 3 enumerated values; pre-routes T65 decision-tree cleanly.
- [x] T65 routing pre-planned for all 3 verdict outcomes:
  - REVIVE → spawn build-theory child investigation per researcher §8.
  - DORMANT-CLOSE → implementer_text Document-stage closure at tier 0.4 REFUTED-CLEAN.
  - INCONCLUSIVE → re-route per researcher §8 specific next-dispatch proposal.
- [x] No meta-investigation spawned (yan-li-saito is kind=physics; R4 child if spawned would also be kind=physics build-theory).
- [x] Per `feedback_decision_style`: single commitment per turn = one researcher dispatch.
- [x] Per `feedback_mathematical_elegance_bias`: simple Research stage, not a reformulation; defer R4 derivation itself to T65+ build-theory child if REVIVE.
- [x] Per `feedback_mechanical_vs_investigation_threshold`: 3-second test failed for R4 (not mechanical; requires lit comparison + analytical algebra) — researcher Research stage is correct flow.
- [x] Per `feedback_fix_the_class_not_the_instance`: sibling-class state.json verbose-string cleanup observed (T50/T61/yan-li-saito current_stage fields); queued for T65+ implementer_text micro-dispatch; not in T64 scope.
- [x] Per `feedback_no_improvised_terminology`: brief uses established terms (R4 falsifier, DDI prefactor, Lima-Pelster χ, polar polarized state, REVIVE / DORMANT-CLOSE / INCONCLUSIVE, build-theory child). No coined metaphors.
- [x] Per `feedback_manuscript_is_not_the_essence`: no manuscript paragraph; research deliverable + future state.json closure/spawn only.
- [x] Per Director.md §F1 Research stage: researcher handles lit scan + framework-grep + prior-loop-turn audit for the falsifier branch's hypothesis grounding.
- [x] Drift advisories post-T64 forecast: AUDIT_DUE clear until ~T72. DRIFT_COST_INFLATION fades (T64 ~2.2M < T63 1.76M but still mid-range). DRIFT_MANUSCRIPT_DELTA_ZERO persists by design. DRIFT_CODE_DELTA_ZERO=1 (researcher = no code; intended). novel_claim_zero: 0 if REVIVE, 1 if DORMANT-CLOSE/INCONCLUSIVE; either is acceptable.
- [x] No emojis used in director report.
