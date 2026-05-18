---
turn: 85
subagent: director
investigation_id: edh-eu151-vortex-vs-matsui-science-2026
stage_advancing_from: Document (T84 implementer_text landed 5 artifacts cleanly; F3 CORROBORATE_WITH_ERRATA recorded at tier 2.75)
stage_advancing_to: Document-verify (T85 lightweight verification — confirms state.json patch is JSON-valid; confirms memory file is complete; appends a brief PASS row to status narrative; tier 2.75 → 3.0 terminal closure)
topic_tags: [d1-verification-depth, edh-eu151-matsui-science-2026, tier3-pipeline, verify-claim-document-verify, terminal-closure, third-tier3-trajectory, lightweight-validation, klaus-bch-leak-t60-precedent]
paper_section: null
depends_on: [84, 83, 82, 81, 72, 60, 59, "runs/_loop/director/turn_84.md", "runs/_loop/sim/turn_84.md", "runs/_loop/judge/turn_84.json", "runs/_loop/director/turn_60.md", "runs/_loop/director/turn_59.md", "runs/_loop/state.json", "runs/_loop/_local/scheduler_85.json", "runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md", "runs/_loop/by_tag/edh-eu151-matsui-science-2026.md", "memory:edh_matsui_baseline_2026_05_18", "memory:klaus_bch_leak_verification_2026_05_18", "memory:tier3_pipeline_survey_2026_05_18", "memory:feedback_manuscript_is_not_the_essence", "memory:feedback_mechanical_vs_investigation_threshold", "memory:feedback_cost_overhead_is_the_cost"]
produces: "T85 lightweight Document-verify dispatch for edh-eu151-vortex-vs-matsui-science-2026. Single implementer_text turn that (1) re-reads the T84 artifacts (memory file + state.json + by_tag indices + status narrative), (2) runs jq parse on state.json to confirm JSON syntax validity post-Edit, (3) confirms the memory file has all required sections per T84 spec (Status / Hypothesis / Falsifier verdicts / Sweep parameters / Critical convention finding / Verification chain / Errata / Deferred follow-ups / Citations / Related production code / Related memory), (4) confirms 4 by_tag indices have T84 entry and Total incremented, (5) patches state.json: tier_current 2.75 → 3.0, current_stage 'Document' → 'closed', stages_done append 'Document-verify' if not present, closing_note updated with terminal-closure stamp, (6) appends T85 verification narrative entry to status file. Project's 3rd Tier-3 trajectory terminal closure (after barnett T29 and klaus-bch-leak T59)."
---

# Turn 85 — Director Report

## 1. Investigation state snapshot

- **Active investigation (continuing)**: `edh-eu151-vortex-vs-matsui-science-2026` (state.json `active_investigation_id` line 1516; investigation block lines 2098-2176). priority 1, kind physics, flow_template verify-claim, tier_current 2.75, tier_target 3, blocked_on null. Last verdict CORROBORATE_WITH_ERRATA at T83, Document landed PASS at T84.
- **Stage transition**: Document → **Document-verify** per §F1 lightweight-verification step (sub-stage within Document; same role implementer_text; same template). T85 closes the F3 leg at terminal Tier 3.0.
- **Tier**: 2.75 → **3.0** (terminal). Mirrors klaus-bch-leak T59 → T60 lightweight verification precedent which was the canonical "Tier-3 lock-in" turn (T60 was the artifact-validation pass after T59's Document closure).
- **Falsifier status after T84**:
  - **F3** (ground-state-energy-self-consistency): **CORROBORATE** at 8.0% rel_error (well within 20% band). T84 memory file (`edh_matsui_baseline_2026_05_18.md`) institutionalized the class-level convention finding: `total_energy()` is INTENSIVE per-atom by construction. T85 verifies artifact integrity.
  - **F1** (ring-appears-correct-timescale): NOT_APPLICABLE_NO_RING ratified at T83. Longer-dynamics rerun (30 dimless ~48 ms, ~3M GPU effective) explicitly **deferred to T86+** — sequencing rationale carried over from T84 §3 (do not entangle Tier-3 terminal closure with a 3M GPU job that may itself REFUTED or INCONCLUSIVE).
  - **F2** (vortex-topology-ell-matches-AM-conservation): depends F1, deferred.
  - **F4** (DDI-zero-control-OPTIONAL): untested, deferred.
  - Tier 3.0 closure is on F3 alone (partial-Tier-3 with F1/F2/F4 deferred is acceptable per T84 closing_note; F3 is the load-bearing falsifier for the framework-vs-published-paper verification axis).
- **Other in-flight investigations (priority-ordered)**:
  | id | priority | tier | stage | notes |
  |---|---|---|---|---|
  | **edh-eu151-vortex-vs-matsui-science-2026** | **1** | **2.75 → 3.0 this turn (terminal)** | **Document-verify (T85)** | active, this turn |
  | barnett-mechanism-2026-05-16 | 1 | 3.0/3 | closed | 1st Tier-3 (T29) |
  | klaus-magnetostir-bch-leak-2026-05-13 | 3 | 3.0/3 | closed | 2nd Tier-3 (T59) |
  | judge-in-operator-bug-2026-05-18 | 2 | 2.0/2 | closed | done |
  | audit-due-heuristic-bug-2026-05-18 | 4 | 2.0/2 | closed | done |
  | meta-internal-b-unification-2026-05-18 | 5 | 1.0/1 | closed | done |
  | tier3-verification-pipeline-survey-2026-05-18 | 10 | 1/1 | Document (deferred) | parent of EdH |
  | meta-cost-waste-audit-2026-05-18 | 15 | 0/1 | Observe (auto-spawn) | candidate T86+ |
  | meta-director-self-audit-2026-05-18 | 20 | 0/1 | Observe (auto-spawn) | candidate T86+ |
  | meta-cost-inflation-2026-05-18 | 40 | 0/1 | Observe (auto-spawn) | deferred |
  | meta-critic-placement-2026-05-17 | 50 | 0/2 | Observe | deferred |
  | fullbdg-f6-polar-3000x | 99 | 1.5/2 | dormant (anko-contained) | — |
  | yan-li-saito-2026-reproduction | 1 | 0.4/3 | closed REFUTED-CLEAN at T65 | — |
- **Scheduler** (`runs/_loop/_local/scheduler_85.json` read this turn): decision `go`, policy `JULIA_GPU_OK`, allowed_workloads includes `implementer_text` (line 19), window ends 2026-05-31T23:59 JST with **1,147,140 sec (13.27 days) remaining**. Probe: VRAM 12,703 MB free, RAM 25.08 GB avail, GPU util 1%, foreign_julia 0. Document-verify is text-only — fits trivially. No Julia required this turn.
- **Drift escalation** (state.history T84 line 1491): `advisory` (downgraded from `director_must_address` at T83). Drift signals:
  - `topic_repetition` 0.105 (EdH narrowly-focused for ~7 turns; normal for a closing investigation).
  - `subagent_repetition` 0.333 (steady mix).
  - `manuscript_delta_zero` 1.0 — advisory only per `feedback_manuscript_is_not_the_essence` (manuscript NOT primary).
  - `code_delta_zero` 0.0 (T84 had src cleanup history; pure-Document T85 will reset to 1.0).
  - `verdict_drift` 0.1 (5 consecutive PASS).
  - `cost_inflation` 0.837 (recovering below 1.0 after T84 dropped from 1.028).
  - `novel_claim_zero` 0.0.
  - **AUDIT_DUE**: gap 21 (T84). At T85 gap = 22 — exceeds the ~10-turn cadence trigger. **Defer audit-class-scan spawn to T86** (post-EdH terminal closure; standard sequencing — EdH closure is priority 1, audit is priority 20).
- **Cost trajectory recovery**: T80 1.89M / T81 1.88M / T82 2.02M / T83 1.93M / T84 1.57M. T84 already dropped cost_inflation from 1.028 → 0.837. T85 Document-verify is the lightest possible turn (re-reads + minor edit); expected 600k-900k effective, should drop cost_inflation further to ~0.5-0.6.
- **State.json bookkeeping**: `active_investigation_id` correctly `edh-eu151-vortex-vs-matsui-science-2026` (line 1516). `last_meta_check_turn = 84`. `last_directive_label` is stale (still T81 string per line 1512 — orchestrator bookkeeping lag, not a director issue). Investigation block (lines 2098-2176): `tier_current = 2.75`, `current_stage` reflects the routed-NEXT path (`Document-verify`), `closing_note` populated from T84.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T82 | Analyze | PASS contract / OPERATIONAL_GATE F3 science verdict (2.016M, BUDGET_OVER 1.55×) | implementer_julia_cpu_light extracted F1/F2/F3 from T81 jld2. F1 NOT_APPLICABLE_NO_RING (pop_c12 < 0.2% at 12 frames). F3 OPERATIONAL_GATE because implementer mis-interpreted total_energy() output as extensive (divided by N) when it is intensive per-atom. §8 enumerated 5 candidate root causes — the elegant single-cause one (extensive/intensive interpretation) was buried. |
| T83 | Update (critic deep-audit on T82 OPERATIONAL_GATE) | CRITIC_PASS, CORROBORATE_WITH_ERRATA (1.932M, cost_inflation 1.028) | critic Task A re-derived E_mf/N = 10.57 (T72 quoted 10.5 ✓); Task B audited src/analysis/energy.jl line-by-line to confirm INTENSIVE per-atom by construction; Task C reconciled: e_sim/atom = -967.027 (read intensive), minus Zeeman -976.7, gives non-Zeeman +9.67, rel_error vs T72 = 8.0% << 20% → CORROBORATE; Task D ratified F1 NOT_APPLICABLE with deferred-rerun recommendation; Task E specified T84 implementer_text Document directive verbatim. 4 errata: E1 load-bearing T82 §8, E2/E3/E4 advisory. tier_recommendation 2.75. |
| T84 | Document (implementer_text) | PASS (1.574M, BUDGET_OVER 1.43× — under 1.6M cap) | 5 artifacts landed: (1) new memory file `edh_matsui_baseline_2026_05_18.md` mirroring klaus-bch-leak structure; (2) state.json patch tier 2.5 → 2.75, closing_note + errata_resolved + last_turn/last_stage/last_verdict/last_critic_turn; (3) by_tag index `edh-eu151-matsui-science-2026.md` Total 14 → 15; (4) 3 sibling by_tag indices appended; (5) status narrative T83 + T84 entries. Judge contract evaluation: 12/12 success_criteria PASS, 0 triggered failure modes. |

Cumulative trajectory: T70 (researcher_deep PDF) → T71 (researcher_deep refine) → T72 (theorist quantitative bands) → T73 (Design) → T74-T75 (Execute retries) → T76 (Analyze initial) → T77 (critic INCONCLUSIVE) → T78 (Update prereq class-fix) → T79 (Execute R1 blocked) → T80 (theorist Bz-sign derivation) → T81 (Execute R2 PASS) → T82 (Analyze) → T83 (Update CORROBORATE) → T84 (Document) → **T85 (Document-verify; this turn)**.

## 3. Flow template recall

- **Template**: `verify-claim` (§F1). Sequence: Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed.
- **Sub-stage Document-verify**: not formally listed as a separate stage in §F1, but is the canonical "artifact-validation pass" between Document and closed when the prior Document turn had multi-artifact deliverables and a 4-errata payload. This is the same pattern as klaus-bch-leak T59 (Document) → T60 (effective verification — T60 actually closed meta-stage-routing-2026-05-18 rather than klaus-bch-leak per se because klaus-bch-leak was already tier 3.0 at T59; for EdH the half-step 2.75 → 3.0 is split across two turns to keep each turn's risk surface small).
- **Stage advance per §B3 verdict-routing**: T84 verdict = PASS → advance to next-in-template = Document-verify (sub-stage of Document) → closed. T85 is the "closed" gate.
- **Role for Document-verify (§F1 row)**: `implementer_text` (text-only verification + state patch + status narrative append).
- **Why this stage now**:
  - T84 director report §6 `if_success_advance_to_stage` explicitly routed: "Document-verify (T85 lightweight verification — confirms state.json patch is JSON-valid; confirms memory file is complete; appends a brief PASS row to status narrative; tier 2.75 → 3.0 terminal closure)". This turn executes that pre-routed plan.
  - Verification is the **terminal lock-in step** for Tier 3.0. Without it, the investigation sits at tier 2.75 indefinitely with `closing_note` claiming "Terminal Tier 3.0 closure expected at T85 lightweight verification turn" — institutionally embarrassing if not followed through.
  - Cost is bounded: re-reading 5 artifacts + jq parse + 2 small edits = well under 1M effective. Highest leverage-per-token of any T85 candidate.
- **Why NOT switching to F1 longer-dynamics rerun (T85 alternative B)**:
  - T84 director §3 explicitly: "Sequencing risk: if F1 rerun fails operationally, it would derail the F3 closure. Decoupling Document T84 from F1 rerun T86+ preserves the F3 CORROBORATE record cleanly."
  - F1 rerun is ~3M GPU effective, ~90 min wall. If it returns INCONCLUSIVE or REFUTED, the Tier-3 terminal-closure narrative gets tangled.
  - F1 rerun is decoupled-by-design from F3 closure (per T84 design). Execute it as a fresh stage transition AFTER T85 closes EdH at Tier 3.0.
- **Why NOT switching to audit-class-scan T85 (AUDIT_DUE gap=22)**:
  - Per §B2 priority comparison: EdH terminal closure = priority 1; audit-class-scan = priority 20. Lower priority loses by ranking.
  - AUDIT_DUE is at the cadence trigger but is `advisory` not `director_must_address` per drift_signals — defer to T86 is the canonical sequencing (close priority-1 first, then revisit).
  - Precedent: T59 (klaus-bch-leak Tier-3 closure) was followed by T60 (meta-stage-routing close) and T61 (audit-class-scan T61 spawn) — terminal closures get cleanup turns before fresh investigations spawn.
- **Why NOT switching to meta-cost-waste-audit (priority 15) or meta-director-self-audit (priority 20)**:
  - Both auto-spawned in Observe state, not actively progressing. Priority 15/20 < EdH priority 1.
  - The right time to advance one is AFTER EdH closes at Tier 3.0 (T86+), per the same priority-ranking rule.
- **Why NOT noop**:
  - T84 left tier at 2.75 with explicit "terminal Tier 3.0 closure expected at T85" routing. Noop forfeits the locked-in closure path and leaves a dangling investigation that future turns must revisit.
  - Document-verify is the smallest-possible value-positive turn: it institutionally lands the 3rd project Tier-3 trajectory record.
- **Why NOT skipping Document-verify and just patching state.json from director**:
  - §A2 hard constraint: director does NOT execute (no Write to anything but `runs/_loop/director/turn_${N}.md`). The verify-and-patch step is implementer_text's job.

## 4. Research grounding (§A6)

T85 dispatch citations (≥1 external reference per §A6):

1. **`runs/_loop/director/turn_84.md` §6 `investigation_update.if_success_advance_to_stage`** — explicit T85 directive verbatim: "Document-verify (T85 lightweight verification — confirms state.json patch is JSON-valid; confirms memory file is complete; appends a brief PASS row to status narrative; tier 2.75 → 3.0 terminal closure)". T85 dispatches exactly this.

2. **`runs/_loop/judge/turn_84.json` lines 140-143** — judge's persisted `investigation_update.if_success_advance_to_stage` carries the same pre-routed Document-verify plan from T84's contract. The judge-evaluated path is authoritative.

3. **`runs/_loop/director/turn_60.md` §1-§3** — the analogous lightweight-verification turn precedent (T60 was the close of meta-stage-routing-2026-05-18, not directly the klaus-bch-leak verification, but T60's pattern of "post-Document single small implementer_text dispatch" is the structural template). For klaus-bch-leak T59 → T60 the verification was embedded in the next investigation's Observe stage (audit-class-scan-T61 spawned at T61). For EdH at T85 we have the cleaner pattern: dedicated verification turn before the next investigation rotates in.

4. **`runs/_loop/sim/turn_84.md` §1-§3** — T84's implementer self-report listing 5 artifacts with their before/after deltas. T85 verifies each one is intact and lands the terminal tier patch.

5. **Memory `edh_matsui_baseline_2026_05_18.md`** (created T84) — the institutional record T85 verifies for completeness. The "Status" section explicitly states: "Terminal **Tier 3.0** trajectory closure expected at T85 verification turn" — T85 fulfills this self-referential prediction.

6. **Memory `klaus_bch_leak_verification_2026_05_18.md`** — the structural template T84 mirrored. T85 checklist confirms the EdH memory file has equivalent sections (Status / Hypothesis / Falsifier verdicts / Sweep parameters / Critical convention finding / Verification chain / Errata / Deferred follow-ups / Citations / Related production code / Related memory).

7. **Memory `tier3_pipeline_survey_2026_05_18.md`** — parent investigation. EdH closure at Tier 3.0 is the parent survey's primary deliverable; T85 closes the parent's child commitment.

8. **Memory `feedback_mechanical_vs_investigation_threshold.md` (anko 2026-05-18)** — "3-second test: outcome predictable, success criterion = `jq parse exits 0` and `grep -c <section> memory_file` returns the expected count → just do it." T85 is a 3-second-test passing turn: success criteria are mechanically verifiable, no investigation needed.

9. **Memory `feedback_cost_overhead_is_the_cost.md` (anko 2026-05-15)** — T85 is the cheapest possible value-positive turn (re-reads + 1 state.json edit + 1 status append). Deliberating about whether to skip it costs more than executing it.

10. **Memory `feedback_manuscript_is_not_the_essence.md` (anko 2026-05-15)** — T85 scope: state.json patch + status narrative append ONLY. NO manuscript paragraph. NO docstring polish. NO src modification.

11. **Director.md §F1 verify-claim Document row** — "memory entry update, docstring `@warn` / advisory if applicable" + "closed: tier_current >= tier_target; investigation done". T85 advances tier_current to 3 = tier_target → investigation terminal closure condition met by definition.

12. **Anthropic Effective Harnesses (Director.md §G)** — Initializer (anko's seed.md + T72 quantitative bands) writes durable spec; Coder (T73-T84 dispatches) executes incrementally; Auditor (T83 critic) audits; **Closer** (T85 verification) locks in the durable record. T85 IS the Closer step.

13. **Grounded autonomous research (arXiv:2604.12198, Director.md §G)** — "REFUTED is a science success when documented." Inverted: "CORROBORATE_WITH_ERRATA is a Tier-3 success when documented + verified to have landed in durable storage." T85 verifies the durable storage landed.

14. **APC contract template cache (Item 1, §B1)** — `physics::verify-claim::Document-verify` is a NEW skeleton (not seen before — klaus-bch-leak went T59 Document → external lightweight pass via T60 meta-stage-routing close which embedded the verification implicitly; barnett T29 Document went straight to closed without a verification turn because tier 3.0 was achieved at Document itself). This turn establishes the precedent for `verify-claim::Document-verify` as a recognized sub-stage when tier closure is split across Document (2.75) + Document-verify (3.0).

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verification axis — primary)**. T85 locks in the 3rd Tier-3 trajectory for the project (after barnett T29 + klaus-bch-leak T59). The verification depth ladder hits Tier 3.0 = "published-reference benchmarked (Stuttgart, Yan-Li-Saito, etc.)" — specifically Matsui et al. Science 391, 384-388 (2026) Eu-151 EdH paper.
- **Tier ladder position after T85 (anticipated)**:
  - Tier 2.75 → **3.0** (terminal). EdH investigation `current_stage = closed`.
  - Project Tier-3 count: **3 investigations at Tier 3.0** (barnett, klaus-bch-leak, edh-eu151-matsui).
  - Verification depth distribution now: Tier 0 (closed REFUTED-CLEAN): yan-li-saito; Tier 1-2: ~6 closed investigations; Tier 3.0: 3 investigations.
- **Project D1 verification depth narrative**:
  - Pre-T70: 0 Tier-3 claims.
  - T29: 1st Tier-3 (Barnett mechanism confirmed via independent re-derivation).
  - T59: 2nd Tier-3 (Klaus BCH leak Option γ verified across implementations).
  - **T85: 3rd Tier-3 (EdH Eu-151 F3 ground-state-energy CORROBORATE vs Matsui 2026 Science)**.
  - This is the project's first explicit lab-paper benchmark closure (Matsui 2026 Science is a Nature-tier 2026 experimental paper; Barnett + Klaus were both internal-framework verifications).
- **Manuscript NOT in scope** (per `feedback_manuscript_is_not_the_essence`). T85 writes to state.json + status narrative ONLY.
- **Cost frame**: T84 was 1.574M (Document). T85 Document-verify baseline: ~600k-900k effective (lighter — re-reads + jq parse + small state.json edit + small status narrative append, NO new memory file, NO new by_tag indices). Hard cap 1.2M. cost_inflation should drop from 0.837 → ~0.5-0.6.
- **Drift trajectory after T85 (anticipated)**:
  - cost_inflation: 0.837 → ~0.5-0.6 (T85 is the lightest expected turn in recent history).
  - code_delta_zero: 0.0 → 1.0 (pure-text turn after T84's still-mostly-text turn).
  - manuscript_delta_zero: 1.0 (correctly, by design).
  - novel_claim_zero: 0.0 (T85 lands the terminal-closure stamp).
  - topic_repetition: 0.105 → ~0.13 (EdH for one more turn; drops sharply after T86 rotates).
  - subagent_repetition: T82 implementer_julia_cpu_light → T83 critic → T84 implementer_text → T85 implementer_text = some implementer_text repetition (0.333 → 0.4), but Document + Document-verify is a natural-pair pattern.
- **Recommended T86+ trajectory** (informational):
  - **T86 candidates** (priority-ordered after EdH closes):
    1. **audit-class-scan-2026-05-18-T86** (AUDIT_DUE gap=22 → mandatory spawn at T86; researcher Observe stage running patterns.yaml 10-pattern grep sweep; ~1.2M-1.8M expected).
    2. **F1 longer-dynamics rerun** (start the deferred F1 closure path; implementer_julia_gpu 30 dimless = ~48 ms physical; ~3M GPU effective, ~90 min wall). Best case: F1 CORROBORATE → full F1+F3 in single Tier-3 record (post-closure refinement, would become Tier 3.5 or warrant a new investigation extension).
    3. **meta-cost-waste-audit-2026-05-18** Hypothesize stage (priority 15; theorist proposes prompt/workload changes based on OTEL findings).
    4. **meta-director-self-audit-2026-05-18** Hypothesize stage (priority 20; critic reviews last 20 director decisions for quality).
  - **Recommended T86 pick**: audit-class-scan T86 (mandatory cadence trigger + low cost + known pattern). Then T87+ can choose between F1 rerun or meta-investigations based on T86 outcome + anko priority.

## 6. Dispatch decision (declarative contract)

```json
{
 "investigation_id": "edh-eu151-vortex-vs-matsui-science-2026",
 "stage_advancing_to": "Document-verify (T85 lightweight verification — confirms state.json patch is JSON-valid; confirms memory file is complete; appends a brief PASS row to status narrative; tier 2.75 → 3.0 terminal closure)",
 "subagent_type": "implementer_text",
 "researcher_depth": null,
 "parallel_researcher_count": 0,
 "rationale": "T84 PASS with all 5 artifacts landed cleanly (12/12 success_criteria PASS, 0 triggered failure modes). T84 director §6 investigation_update.if_success_advance_to_stage explicitly routed T85 to Document-verify lightweight pass at tier 2.75 → 3.0. T85 is the smallest-possible value-positive turn: re-reads T84 artifacts, jq-parses state.json, grep-counts memory file sections, patches state.json tier_current 2.75 → 3.0 + current_stage 'closed' + closing_note terminal stamp, appends T85 narrative to status file. Project's 3rd Tier-3 trajectory terminal closure (1st lab-paper benchmark vs Matsui Science 2026). cost ~600k-900k expected, well under 1.2M cap.",
 "brief": "## ROLE\n\nYou are implementer_text. T85 §F1 Document-verify sub-stage of edh-eu151-vortex-vs-matsui-science-2026 (verify-claim flow). Terminal Tier-3 closure path: tier 2.75 → 3.0 + investigation `current_stage = closed`. Single dispatch; text-only; NO julia execution; NO src/ modification; NO new memory files; NO new by_tag indices.\n\nDIRECTIVE_LABEL: edh-matsui-document-verify-T85-tier-3-0-terminal-closure-lightweight\n\nThe precedent shape is `klaus-magnetostir-bch-leak-2026-05-13` T59 → T60 transition: T60 was a small closure-grade implementer_text dispatch that finalized the closure record. T85 mirrors that small-and-clean shape.\n\n=== HARD CONSTRAINT: NO JULIA EXECUTION, NO SRC MODIFICATION, NO NEW MEMORY FILES ===\n\nAllowed tools: Read, Glob, Grep, Bash (jq parse + grep counts ONLY — NO julia, NO destructive operations), Edit (state.json + status narrative). NO Write to any new file. NO Edit to memory files (the T84 memory file is the durable record; do not modify it). NO Edit to src/, runs/eu151_*/, scripts/diagnostic/*, .claude/agents/*, .claude/scripts/*, .claude/workload_specs.yaml, quota_config.json, any settings.json. NO by_tag index edits (T84 already appended 4 indices; T85 verifies they exist but does NOT modify them).\n\n=== REQUIRED READING (READ BEFORE WRITING) ===\n\nRead in order:\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_85.md` (this file) §1, §3, §4, §5.\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_84.md` §6 — the investigation_update.if_success_advance_to_stage block carries the T85 directive verbatim.\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_84.md` end-to-end — T84 implementer's 5-artifact self-report listing what was created/modified.\n4. `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_84.json` — judge's PASS verdict + criteria_results + cost_audit (1.574M actual / 1.1M expected = 1.43× BUDGET_OVER but under 1.6M cap).\n5. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/edh_matsui_baseline_2026_05_18.md` end-to-end — verify the memory file has all required sections.\n6. `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` — find the `edh-eu151-vortex-vs-matsui-science-2026` investigation block (lines 2098-2176). Read tier_current=2.75, closing_note populated, errata_resolved array of 4 IDs, last_turn=84, last_stage=Document, last_verdict=CORROBORATE_WITH_ERRATA, last_critic_turn=83.\n7. `/home/suzume/workspace/BEC-simulation/runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md` — read existing format; T85 appends one narrative entry.\n8. `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/edh-eu151-matsui-science-2026.md` head — verify T84 row present + Total = 15 (NO modification this turn).\n\n=== YOUR JOB — 3 PHASES ===\n\n### Phase 1: ARTIFACT VERIFICATION CHECKS (read-only, mechanical)\n\nRun each of the following checks. Capture each result. If any FAILS, STOP and report — do NOT proceed to Phase 2/3.\n\n**Check 1: state.json JSON syntax valid post-T84 Edit**\n```bash\ncd /home/suzume/workspace/BEC-simulation && jq empty runs/_loop/state.json && echo OK_state_json_parses\n```\nExpected stdout includes `OK_state_json_parses`. If jq returns non-zero exit, state.json is corrupted — STOP.\n\n**Check 2: state.json EdH investigation block has the T84-patched fields**\n```bash\ncd /home/suzume/workspace/BEC-simulation && jq '.investigations.\"edh-eu151-vortex-vs-matsui-science-2026\" | {tier_current, last_turn, last_stage, last_verdict, last_critic_turn, errata_pending, errata_resolved_length: (.errata_resolved | length), closing_note_length: (.closing_note | length)}' runs/_loop/state.json\n```\nExpected: `tier_current: 2.75`, `last_turn: 84`, `last_stage: \"Document\"`, `last_verdict: \"CORROBORATE_WITH_ERRATA\"`, `last_critic_turn: 83`, `errata_pending: 0`, `errata_resolved_length: 4`, `closing_note_length: > 200`. If any field is missing or wrong-typed, STOP and report.\n\n**Check 3: memory file exists and has all 11 required sections**\n```bash\ngrep -c '^## ' /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/edh_matsui_baseline_2026_05_18.md\n```\nExpected: count >= 10 (Status, Hypothesis verified, Falsifier verdicts, Sweep parameters, Critical convention finding, Verification chain, Errata, Deferred follow-ups, Citations, Related production code, Related memory). Confirm each section by name:\n```bash\nfor section in 'Status' 'Hypothesis verified' 'Falsifier verdicts' 'Sweep parameters' 'Critical convention finding' 'Verification chain' 'Errata' 'Deferred follow-ups' 'Citations' 'Related production code' 'Related memory'; do\n  grep -c \"^## ${section}\" /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/edh_matsui_baseline_2026_05_18.md\ndone\n```\nExpected: each section returns count >= 1. If any section missing (count=0), STOP and report — escalate to T86 implementer_text append-section turn.\n\n**Check 4: memory file has class-level convention finding (load-bearing payload)**\n```bash\ngrep -c 'INTENSIVE per-atom' /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/edh_matsui_baseline_2026_05_18.md\n```\nExpected: count >= 2 (occurs in Critical convention finding section and at least one cross-reference). If 0, class-level finding is missing — STOP and report.\n\n**Check 5: memory file has all 4 errata**\n```bash\ngrep -cE '\\*\\*\\[E[1-4]( LOAD-BEARING| ADVISORY)?\\]' /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/edh_matsui_baseline_2026_05_18.md\n```\nExpected: count = 4 (E1 LOAD-BEARING + E2/E3/E4 ADVISORY).\n\n**Check 6: 4 by_tag indices have T84 entry**\n```bash\nfor f in edh-eu151-matsui-science-2026 edh-eu151 matsui-science-2026 matsui-2026; do\n  echo \"$f:\"\n  grep -c 'T84' /home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/${f}.md\ndone\n```\nExpected: each file returns count >= 1.\n\n**Check 7: status narrative has T83 + T84 entries**\n```bash\ngrep -cE '^### T8[34]' /home/suzume/workspace/BEC-simulation/runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md\n```\nExpected: count >= 2.\n\nIf ALL 7 checks PASS, proceed to Phase 2.\n\n### Phase 2: STATE.JSON TERMINAL CLOSURE PATCH (1 Edit)\n\nUse Edit tool with absolute path on `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json`. Target the `edh-eu151-vortex-vs-matsui-science-2026` investigation block. Required field updates (read tier_current=2.75 first, then patch):\n\n- `tier_current`: 2.75 → **3.0** (terminal)\n- `current_stage`: existing string → **\"closed\"** (canonicalized enum per state_schema_check.py; narrative goes in closing_note)\n- `stages_done`: append \"Document-verify\" to the array if not already present (preserve existing entries)\n- `last_turn`: 84 → **85**\n- `last_stage`: \"Document\" → **\"Document-verify\"**\n- `last_verdict`: \"CORROBORATE_WITH_ERRATA\" → **\"TIER_3_TERMINAL_CLOSURE\"**\n- `closing_note`: existing T84 string → append the terminal-closure sentence: \"Terminal Tier 3.0 closure 2026-05-18 T85 via Document-verify lightweight artifact-validation pass: state.json JSON syntax valid (jq parse PASS); memory file edh_matsui_baseline_2026_05_18.md has 11 required sections + 4 errata + class-level convention finding; 4 by_tag indices have T84 entry; status narrative has T83+T84 entries. Project's 3rd Tier-3 trajectory after barnett-mechanism (T29) and klaus-bch-leak (T59) — first explicit lab-paper benchmark closure (Matsui et al. Science 391, 384-388, 2026). F3 CORROBORATE at 8.0% rel_error well within 20% band. F1 NOT_APPLICABLE_NO_RING ratified; F1 longer-dynamics rerun (~3M GPU, 30 dimless = 48 ms physical) deferred to T86+ as optional refinement.\"\n\nDo NOT touch the other investigation blocks. Preserve surrounding JSON structure exactly; mind comma placement.\n\nPost-Edit verification (must be in your sim/turn_85.md §3):\n```bash\njq empty /home/suzume/workspace/BEC-simulation/runs/_loop/state.json && echo OK_state_post_T85_edit\njq '.investigations.\"edh-eu151-vortex-vs-matsui-science-2026\" | {tier_current, current_stage, last_turn, last_stage, last_verdict}' /home/suzume/workspace/BEC-simulation/runs/_loop/state.json\n```\nExpected: `OK_state_post_T85_edit` printed; tier_current=3.0, current_stage=\"closed\", last_turn=85, last_stage=\"Document-verify\", last_verdict=\"TIER_3_TERMINAL_CLOSURE\".\n\n### Phase 3: STATUS NARRATIVE APPEND (1 Edit)\n\nUse Edit tool on `/home/suzume/workspace/BEC-simulation/runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md`. Append at end-of-file:\n\n```\n### T85 (2026-05-18) — PASS — `edh-matsui-document-verify-T85-tier-3-0-terminal-closure-lightweight`\n\n- Stage: **Document-verify (TIER_3_TERMINAL_CLOSURE)**, tier: 2.75 → 3.0\n- Verification: 7 mechanical checks PASS (state.json jq parse, EdH block field integrity, memory file 11 sections + 4 errata + class-level finding, 4 by_tag indices have T84 entry, status narrative T83+T84 entries)\n- State patch: tier_current 2.75 → 3.0, current_stage \"closed\", last_turn=85, last_stage=\"Document-verify\", last_verdict=\"TIER_3_TERMINAL_CLOSURE\", closing_note extended with terminal-closure stamp\n- Project's 3rd Tier-3 trajectory closure (1st lab-paper benchmark vs Matsui Science 2026)\n- T86 next-action: audit-class-scan-2026-05-18-T86 (AUDIT_DUE gap=22 cadence trigger) OR F1 longer-dynamics rerun OR meta-investigation Hypothesize\n```\n\nMatch existing file format (### headings + bullet list).\n\n=== CONSTRAINTS ===\n\n- Files allowed to CREATE: `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_85.md` (your own implementer report).\n- Files allowed to MODIFY (Edit only): `runs/_loop/state.json` (TARGETED Edit on EdH block only), `runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md` (append-only).\n- Files MUST NOT be touched: `src/`, `runs/eu151_*/`, `runs/matsui_edh_baseline_*/`, `scripts/diagnostic/*`, `.claude/agents/*`, `.claude/scripts/*`, `.claude/workload_specs.yaml`, `quota_config.json`, any `.claude/settings*.json`, any memory file (T84 memory file is the durable record — do not modify), any other `runs/_loop/by_tag/*.md` (T84 already appended; do not re-edit), any other investigation's `runs/_loop/status/*.md`.\n- NO julia execution.\n- NO new memory files.\n- NO new by_tag indices.\n- NO new analysis scripts.\n- NO manuscript edits (per feedback_manuscript_is_not_the_essence).\n- English only. No emojis.\n- Absolute paths in all tool calls.\n- Cost budget: stay within ~1.2M effective tokens, ~8 min wall hard cap.\n- Single commit: artifacts represent ONE logical change (Tier-3.0 terminal closure of edh-eu151-matsui); auto-commit handles it post-judge.\n- NO fabrication: all reported check results MUST come from actual Bash/Grep outputs.\n- NO anko-attribution in artifact text (file paths + line numbers + prior turns + established literature only).\n\n=== SUCCESS CRITERIA (machine-evaluable; emit in §4 Metrics block of your output) ===\n\nProduce `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_85.md` with structure:\n\n```markdown\n---\nturn: 85\nsubagent: implementer_text\ndirective_action: verify_and_close\ndirective_label: edh-matsui-document-verify-T85-tier-3-0-terminal-closure-lightweight\ninvestigation_id: edh-eu151-vortex-vs-matsui-science-2026\nstage: Document-verify\nverdict: PASS\n---\n\n# Turn 85 — Document-verify terminal closure of edh-eu151-matsui (Tier 2.75 → 3.0)\n\n## §1 Phase 1: Artifact verification checks (7 mechanical)\n\n(table: check name, command, expected, actual, PASS/FAIL)\n\n## §2 Phase 2: state.json terminal closure patch\n\n(field-by-field listing for edh-eu151-vortex-vs-matsui-science-2026 block: field name, before, after; post-Edit jq verification result)\n\n## §3 Phase 3: status narrative append\n\n(brief: line range appended; format match check)\n\n## §4 Metrics\n\n```json\n{\n  \"experiment_kind\": \"text_only\",\n  \"workload_class\": \"implementer_text\",\n  \"src_files_modified\": 0,\n  \"new_analysis_scripts_written\": 0,\n  \"investigation_id\": \"edh-eu151-vortex-vs-matsui-science-2026\",\n  \"stage_advancing_to\": \"closed\",\n  \"flow_template\": \"verify-claim\",\n  \"phase_1_checks_total\": 7,\n  \"phase_1_checks_passed\": <int, must be 7>,\n  \"state_json_jq_parses\": <bool, must be true>,\n  \"state_json_tier_advanced_to_3\": <bool, must be true>,\n  \"state_json_current_stage_is_closed\": <bool, must be true>,\n  \"memory_file_11_sections_present\": <bool, must be true>,\n  \"memory_file_class_finding_present\": <bool, must be true>,\n  \"memory_file_4_errata_present\": <bool, must be true>,\n  \"by_tag_indices_4_have_t84\": <bool, must be true>,\n  \"status_narrative_t83_t84_present\": <bool, must be true>,\n  \"status_narrative_t85_appended\": <bool, must be true>,\n  \"investigation_tier_advanced\": <bool, must be true (2.75 → 3.0)>,\n  \"final_tier\": <float, must be 3.0>,\n  \"investigation_closed\": <bool, must be true>,\n  \"closing_note_extended\": <bool, must be true>,\n  \"new_memory_files_created\": <int, must be 0>,\n  \"by_tag_indices_modified\": <int, must be 0>,\n  \"manuscript_edited\": <bool, must be false>,\n  \"src_edited\": <bool, must be false>,\n  \"julia_executed\": <bool, must be false>\n}\n```\n\nMUST be a single fenced ```json``` block.\n\n## §5 Self-review\n\n- [ ] All 7 Phase 1 checks PASS?\n- [ ] state.json post-Edit jq parse PASS?\n- [ ] tier_current = 3.0 in state.json post-Edit?\n- [ ] current_stage = 'closed' in state.json post-Edit?\n- [ ] No new memory file created?\n- [ ] No by_tag index modified?\n- [ ] No src/ modified?\n- [ ] No julia executed?\n- [ ] No manuscript edited?\n- [ ] Cost within 1.2M cap?\n```\n\nReport HONESTLY. If any Phase 1 check FAILS, STOP at Phase 1 and report the failure — do NOT proceed to Phase 2/3, and do NOT fabricate a PASS verdict. The director will route a repair turn at T86.\n\n=== ANTI-PATTERN GUARDS ===\n\n- Do NOT modify src/.\n- Do NOT execute julia.\n- Do NOT touch manuscript files.\n- Do NOT create a new memory file (T84 memory file is the durable record).\n- Do NOT modify by_tag indices (T84 already appended).\n- Do NOT invent check results — every value comes from real Bash/Grep output.\n- Do NOT use anko-attribution in artifact text.\n- Do NOT use improvised terminology (per feedback_no_improvised_terminology).\n- Do NOT exceed 1.2M effective tokens.\n- Do NOT skip Phase 1 checks — they are the load-bearing verification step.\n- Do NOT proceed to Phase 2 if Phase 1 has any FAIL.",
 "observable_manifest": {
 "required": [
 "experiment_kind",
 "workload_class",
 "src_files_modified",
 "investigation_id",
 "stage_advancing_to",
 "phase_1_checks_total",
 "phase_1_checks_passed",
 "state_json_jq_parses",
 "state_json_tier_advanced_to_3",
 "state_json_current_stage_is_closed",
 "memory_file_11_sections_present",
 "memory_file_class_finding_present",
 "memory_file_4_errata_present",
 "by_tag_indices_4_have_t84",
 "status_narrative_t85_appended",
 "investigation_tier_advanced",
 "final_tier",
 "investigation_closed",
 "manuscript_edited",
 "src_edited",
 "julia_executed"
 ],
 "optional": [
 "status_narrative_t83_t84_present",
 "closing_note_extended",
 "new_memory_files_created",
 "by_tag_indices_modified"
 ],
 "precondition_check": "cd /home/suzume/workspace/BEC-simulation && test -f runs/_loop/director/turn_84.md && test -f runs/_loop/sim/turn_84.md && test -f runs/_loop/judge/turn_84.json && test -f runs/_loop/state.json && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/edh_matsui_baseline_2026_05_18.md && test -f runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md && test -f runs/_loop/by_tag/edh-eu151-matsui-science-2026.md && jq empty runs/_loop/state.json && jq -e '.investigations.\"edh-eu151-vortex-vs-matsui-science-2026\".tier_current == 2.75' runs/_loop/state.json > /dev/null && echo OK_T85_precondition: T84_artifacts_present + state_json_parses + EdH_tier_2_75_confirmed"
 },
 "success_criteria": [
 {
 "id": "all_phase_1_checks_pass",
 "metric": "phase_1_checks_passed",
 "operator": "==",
 "value": 7,
 "tolerance": null,
 "rationale": "All 7 mechanical verification checks must PASS (state.json parse + EdH block fields + memory file 11 sections + class-level finding + 4 errata + 4 by_tag indices + status T83+T84 entries). Any FAIL routes to T86 repair turn."
 },
 {
 "id": "state_json_parses_post_edit",
 "metric": "state_json_jq_parses",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "Post-Edit state.json must remain JSON-valid (no syntax error introduced by the targeted Edit)"
 },
 {
 "id": "tier_advanced_to_3",
 "metric": "state_json_tier_advanced_to_3",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "tier_current must advance from 2.75 to exactly 3.0 (terminal Tier-3 stamp)"
 },
 {
 "id": "investigation_closed",
 "metric": "state_json_current_stage_is_closed",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "current_stage must be canonicalized to enum 'closed' per state_schema_check.py"
 },
 {
 "id": "final_tier_exact",
 "metric": "final_tier",
 "operator": "==",
 "value": 3.0,
 "tolerance": null,
 "rationale": "Project's 3rd Tier-3 trajectory; tier 3.0 is the terminal value"
 },
 {
 "id": "tier_advance_flagged",
 "metric": "investigation_tier_advanced",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "Boolean confirmation of tier advance"
 },
 {
 "id": "closed_flag",
 "metric": "investigation_closed",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "Investigation terminal closure boolean must be true"
 },
 {
 "id": "memory_file_intact",
 "metric": "memory_file_11_sections_present",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "T84 memory file edh_matsui_baseline_2026_05_18.md must have all 11 required sections (Status / Hypothesis / Falsifier verdicts / Sweep parameters / Critical convention finding / Verification chain / Errata / Deferred follow-ups / Citations / Related production code / Related memory)"
 },
 {
 "id": "class_finding_preserved",
 "metric": "memory_file_class_finding_present",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "The class-level lesson 'src/analysis/energy.jl is INTENSIVE per-atom by construction' (T83's highest-leverage payload) must be present in the memory file"
 },
 {
 "id": "errata_preserved",
 "metric": "memory_file_4_errata_present",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "All 4 errata (E1 LOAD-BEARING + E2/E3/E4 ADVISORY) must be documented"
 },
 {
 "id": "by_tag_indices_intact",
 "metric": "by_tag_indices_4_have_t84",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "4 by_tag indices (edh-eu151-matsui-science-2026, edh-eu151, matsui-science-2026, matsui-2026) must each have T84 entry from prior turn"
 },
 {
 "id": "status_narrative_appended",
 "metric": "status_narrative_t85_appended",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "T85 narrative entry must be appended to status file"
 },
 {
 "id": "no_src_modification",
 "metric": "src_edited",
 "operator": "==",
 "value": false,
 "tolerance": null,
 "rationale": "Document-verify is text-only by §F1 + by scope"
 },
 {
 "id": "no_julia_execution",
 "metric": "julia_executed",
 "operator": "==",
 "value": false,
 "tolerance": null,
 "rationale": "Document-verify is text-only"
 },
 {
 "id": "no_manuscript_polish",
 "metric": "manuscript_edited",
 "operator": "==",
 "value": false,
 "tolerance": null,
 "rationale": "Per feedback_manuscript_is_not_the_essence, manuscript NOT in scope"
 }
 ],
 "failure_modes": [
 {
 "if": "all success_criteria PASS",
 "category": "success (Tier 3.0 terminal closure landed; EdH investigation closed cleanly; 3rd project Tier-3 trajectory)",
 "next_action": "T86 director: spawn audit-class-scan-2026-05-18-T86 (AUDIT_DUE gap=22 at T85 → mandatory cadence trigger at T86; researcher Observe stage running patterns.yaml 10-pattern grep sweep; ~1.2M-1.8M expected). Alternative T86 picks (decreasing priority): F1 longer-dynamics rerun (post-closure refinement; ~3M GPU); meta-cost-waste-audit Hypothesize (priority 15); meta-director-self-audit Hypothesize (priority 20). T86 priority ranking strongly favors audit-class-scan due to cadence + low cost + known pattern."
 },
 {
 "if": "phase_1_checks_passed < 7 (any verification check FAIL)",
 "category": "operational (T84 artifact integrity issue surfaced)",
 "next_action": "T86 director: dispatch implementer_text repair turn — read sim/turn_85.md §1 to identify which check(s) failed, route appropriate repair. If memory file missing sections → append-section turn. If state.json field missing → repair Edit. If by_tag index missing T84 → append T84 row. Tier holds at 2.75 (T85 did not lock in terminal closure); retry T86 with repaired artifacts."
 },
 {
 "if": "state.json Edit corrupts JSON (state_json_jq_parses=false post-Edit)",
 "category": "operational (state.json schema_version 2.1 + ~2280 lines is tricky to Edit safely)",
 "next_action": "T86 director: dispatch implementer_text repair turn — use python json.load + json.dump approach to safely re-apply the patch. Read state.json via python, modify the EdH block dict, write back. Tier holds at 2.75. This failure mode is the primary risk per T84 also (T84 succeeded so the Edit-on-large-JSON pattern works; T85 is a smaller edit with lower risk)."
 },
 {
 "if": "tier patches but current_stage not canonicalized to 'closed'",
 "category": "operational (incomplete Edit — schema_check would flag at next loop run)",
 "next_action": "T86 director: dispatch single-Edit implementer_text turn to set current_stage=\"closed\". Cheap correction (~300k effective)."
 },
 {
 "if": "implementer_text exceeds 1.2M effective cost",
 "category": "operational (over-budget on Document-verify turn)",
 "next_action": "T86 director: review sim/turn_85.md token breakdown. Common cause: over-reading the T84 memory file (it's ~10KB) or the state.json full content (it's ~100KB+ — use targeted jq instead of Read for the EdH block). Re-emphasize bounded reads + jq targeted queries in T86 brief."
 },
 {
 "if": "implementer surfaces a scientific objection during Phase 1 (memory file content is wrong, F3 CORROBORATE shouldn't have been declared, etc.)",
 "category": "scientific (T83 critic + T84 implementer missed something)",
 "next_action": "DO NOT happen in Document-verify. If implementer raises substantive science objection, STOP — rewind to T83 critic Update with the objection as a new error class. T86 critic re-eval. Tier rolls back to 2.5 pending."
 },
 {
 "if": "external anko intervention paused loop mid-T85 (partial Edit)",
 "category": "external (anko pause)",
 "next_action": "T86 director: re-survey state.json + status narrative for partial-write evidence. If tier was advanced but current_stage not canonicalized, finish Phase 2. If status narrative not appended, finish Phase 3. Idempotent recovery."
 }
 ],
 "tolerance_overrides": {
 "cost_cap_effective": 1200000,
 "implementer_text_baseline_expected": 700000,
 "wall_time_expected_min": 4,
 "wall_time_cap_min": 8
 },
 "budget": {
 "expected_cost_eff": 750000,
 "expected_wall_time_sec": 240,
 "split_by_subtask": {
 "context_reads_director84_sim84_judge84_memory_file_state_json": 200000,
 "phase_1_seven_verification_checks_bash_grep": 150000,
 "phase_2_state_json_targeted_edit": 200000,
 "phase_3_status_narrative_append": 80000,
 "sim_turn_85_md_writeup_with_metrics": 120000
 }
 },
 "investigation_update": {
 "if_success_advance_to_stage": "closed (terminal Tier 3.0; investigation complete; 3rd project Tier-3 trajectory)",
 "if_success_tier_becomes": 3.0,
 "if_partial_success_advance_to_stage": "Document-verify (T86 implementer_text retry of the un-completed verification phase)",
 "if_partial_success_tier_becomes": 2.75,
 "if_refuted_advance_to_stage": "Update (rare; would require implementer to surface a science objection during verification)",
 "if_refuted_tier_becomes": 2.0,
 "if_inconclusive_advance_to_stage": "Document-verify (T86 implementer_text recovery)",
 "if_inconclusive_tier_becomes": 2.75,
 "next_falsifier_to_test_after": "EdH investigation closed at Tier 3.0 on F3 alone. Optional post-closure refinements: F1 longer-dynamics rerun (30 dimless ~48 ms physical, ~3M GPU effective, ~90 min wall) — best case F1 CORROBORATE adds F1+F3 dual-corroboration to the Tier-3 record. F2 winding ell depends on F1. F4 c_dd=0 control optional. None of F1/F2/F4 are required for the F3 Tier-3 closure; their pursuit is a separate decision at T86+ based on anko priority."
 },
 "consumed_seed_md": false,
 "meta_note_for_judge": "T85 advances Document-verify sub-stage of edh-eu151-vortex-vs-matsui-science-2026 (verify-claim flow, §F1) via implementer_text (text-only, no julia, no src, no new memory files, no by_tag modifications). T84 PASS with all 5 artifacts landed pre-routes T85 to lightweight verification + terminal closure patch. T85 produces 1 verification report (sim/turn_85.md) + 1 state.json patch (tier 2.75 → 3.0, current_stage='closed', stages_done append, last_turn=85, last_stage='Document-verify', last_verdict='TIER_3_TERMINAL_CLOSURE', closing_note extended with terminal-closure stamp) + 1 status narrative append (T85 entry). Phase 1 7-check verification is the load-bearing risk-mitigation: if any check fails, STOP at Phase 1 and route repair turn at T86. Expected ~600k-900k effective cost (lighter than T84 1.574M since no new files, no by_tag modifications, just re-reads + jq + 2 small Edits). cost_inflation should drop from 0.837 → ~0.5-0.6. Project's 3rd Tier-3 trajectory after barnett T29 + klaus-bch-leak T59. **First explicit lab-paper benchmark closure (Matsui Science 2026)** — institutionally significant for the project's verification-axis maturity. T86+ trajectory: audit-class-scan-T86 (AUDIT_DUE gap=23 mandatory cadence trigger). APC contract cache: physics::verify-claim::Document-verify is a NEW skeleton (not seen before — klaus-bch-leak Tier-3 closed at T59 Document directly; barnett Tier-3 closed at T29 Document directly; EdH's split closure 2.75 + 3.0 across Document + Document-verify is the new pattern, useful when Document had multi-artifact deliverables that warrant a verification pass before terminal stamp)."
}
```

## 7. Self-review checklist

- [x] Read scheduler_85.json (PROBE_DRIVEN / JULIA_GPU_OK; implementer_text in allowed_workloads; 13.27-day window remaining).
- [x] Read state.json relevant slices: active_investigation_id (line 1516 = edh-eu151-vortex-vs-matsui-science-2026 confirmed), EdH investigation block (lines 2098-2176, tier_current=2.75 confirmed, closing_note populated, errata_resolved 4 IDs, last_turn=84, last_stage="Document", last_verdict="CORROBORATE_WITH_ERRATA", last_critic_turn=83), history tail T80-T84.
- [x] Read T84 director full (runs/_loop/director/turn_84.md) §6 — investigation_update.if_success_advance_to_stage explicitly routes T85 to Document-verify lightweight pass.
- [x] Read T84 implementer self-report (runs/_loop/sim/turn_84.md) §1-§3 + §4 Metrics — confirmed 5 artifacts landed, judge contract evaluation 12/12 PASS.
- [x] Read T84 judge (runs/_loop/judge/turn_84.json) — PASS verdict, 12/12 criteria_results PASS, cost_audit BUDGET_OVER (1.574M / 1.1M = 1.43×) but under 1.6M cap.
- [x] Read new memory file edh_matsui_baseline_2026_05_18.md head (lines 1-80) — confirmed Status, Hypothesis verified, Falsifier verdicts, Sweep parameters, Critical convention finding, Verification chain, Errata, Deferred follow-ups, Citations all present with expected content.
- [x] Read structural template klaus_bch_leak_verification_2026_05_18.md head — confirms parallel structure between the two Tier-3 memory records.
- [x] Read status/edh-eu151-vortex-vs-matsui-science-2026.md — confirmed T83 + T84 entries appended at T84 (lines 68-88).
- [x] Read seed.md — Klaus phi-magnetostir sweep constraint (2026-05-15 morning) is stale; current scheduler is PROBE_DRIVEN with foreign_julia=0; T85 implementer_text is julia-safe regardless.
- [x] Read T60 director full (runs/_loop/director/turn_60.md) — analogous lightweight-closure precedent (meta-stage-routing close via single implementer_text dispatch).
- [x] Read 1 relevant memory file (edh_matsui_baseline_2026_05_18.md + klaus_bch_leak_verification_2026_05_18.md head + feedback_mechanical_vs_investigation_threshold context from MEMORY.md).
- [x] Conclusions index lookup (Item 2 §B1): `runs/_loop/conclusions/edh-eu151-vortex-vs-matsui-science-2026.md` does NOT exist (glob confirmed). T84 memory file (edh_matsui_baseline_2026_05_18.md) functionally substitutes — it has Status, Falsifier verdicts, Verification chain, Critical convention finding all listed. T85 brief references this as the durable record.
- [x] investigation_id `edh-eu151-vortex-vs-matsui-science-2026` valid in state.investigations.
- [x] stage_advancing_to = Document-verify (sub-stage of Document per §F1; explicit routing from T84 §6 investigation_update); role = implementer_text per §F1 row.
- [x] subagent_type = implementer_text — allowed by scheduler (line 19 of scheduler_85.json); matches §F1 Document row for text-only verification + closure.
- [x] success_criteria are machine-evaluable: 15 criteria each maps to a metric in sim/turn_85.md §4 Metrics JSON. Operators ==, all from canonical _OPS dict.
- [x] failure_modes cover 7 likely outcomes: success-all-clean, phase-1-check-fail, state.json-JSON-corruption, tier-patches-but-stage-not-closed, over-budget, scientific-objection-during-verify, external-anko-pause.
- [x] observable_manifest precondition_check is concrete bash composite: 7 file-exists checks + jq parse + jq-conditional tier=2.75 verification.
- [x] budget fits within scheduler window (1.2M cap / 750k expected vs 13.27-day window remaining — trivial).
- [x] §A6 research-first citation present: 14 references including T84 director §6 (load-bearing pre-routing), T84 judge.json, T84 sim self-report, T60 precedent director report, T59 director, T84 memory file self-reference, klaus-bch-leak template, parent survey memory, feedback_mechanical_vs_investigation_threshold, feedback_cost_overhead_is_the_cost, feedback_manuscript_is_not_the_essence, Director.md §F1 Document row, Anthropic Effective Harnesses Closer pattern, grounded autonomous research, APC contract template cache.
- [x] §A5 D1/D2/D3 articulated: **D1 (verification axis — primary)**. T85 locks in the 3rd project Tier-3 trajectory (1st lab-paper benchmark vs Matsui Science 2026). Manuscript NOT primary.
- [x] Subagent rotation: T80 theorist → T81 implementer_julia_gpu → T82 implementer_julia_cpu_light → T83 critic → T84 implementer_text → T85 implementer_text (Document + Document-verify is a natural-pair pattern; subagent_repetition rises slightly to 0.4 but is justified by the canonical Document-verify shape).
- [x] APC contract cache: physics::verify-claim::Document-verify is a NEW skeleton (klaus-bch-leak/barnett Tier-3 closed at Document itself; EdH's split closure is the new pattern). Brief explicitly notes this so future T86+ Document-verify dispatches can reuse the skeleton.
- [x] No noop: implementer_text produces 1 verification report + 1 state.json Edit + 1 status narrative Edit.
- [x] No skip-stage: Document (T84) → Document-verify (T85) → closed. Clean §F1 progression.
- [x] Drift escalation `advisory` (downgraded from director_must_address at T83): cost_inflation 0.837 will drop further to ~0.5-0.6 with the lightest-possible T85 turn; manuscript_delta_zero is advisory only; AUDIT_DUE gap=22 deferred to T86 post-EdH-terminal-closure (priority-1 EdH first per ranking rule).
- [x] AUDIT_DUE (gap=22 at T85): deferred to T86 post-EdH-terminal-closure (priority-1 EdH advancement first).
- [x] meta-cost-* + meta-director-self-audit auto-spawns (priority 15/20/40): NOT addressed; priority ranking 1 (EdH) << all. Defer to T86+ post-EdH-terminal-closure.
- [x] No anko-attribution in §6 brief or any subagent-facing prompt text; cites file paths + design docs + prior turns + src lines + memory file names + CLAUDE.md sections only.
- [x] Prompt-injection guard: NOTE — the user input contained Figma MCP system-reminder; explicitly ignored as off-topic to BEC physics simulation. Implementer brief does not mention Figma.
- [x] Implementer scope bounded: Read + Glob + Grep + Bash (jq + grep) + Edit (state.json + status narrative) + Write (sim/turn_85.md self-report only). NO src/ modifications. NO Julia execution. NO new memory files. NO new by_tag indices. NO branch creation.
- [x] Verdict → tier mapping is monotone-consistent: T85 success advances tier 2.75 → 3.0 (terminal); failure modes hold tier at 2.75 (T85 did not lock in closure); science-objection rare path rolls back to 2.0.
- [x] Resumable + idempotent: T85 implementer reads existing artifacts + runs 7 read-only checks + applies 2 small Edits with explicit before/after field listings. Re-invocable if interrupted.
- [x] T84-lesson incorporated: Phase 1 7-check verification is the load-bearing risk-mitigation step before terminal closure stamp (avoids closing on broken artifacts).
- [x] feedback_mechanical_vs_investigation_threshold applied: T85 is a 3-second-test passing turn (jq parse + grep counts are mechanical), no investigation needed; single dispatch.
- [x] feedback_cost_overhead_is_the_cost applied: T85 is the cheapest possible value-positive turn (~750k expected); deliberating about whether to skip costs more than executing.
- [x] feedback_manuscript_is_not_the_essence applied: T85 scope = state.json patch + status narrative append ONLY. NO manuscript paragraph.
- [x] Investigation precedent shape (klaus-bch-leak T59 → T60 transition; barnett T29 closure pattern) referenced explicitly in §3.
