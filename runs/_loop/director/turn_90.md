---
turn: 90
subagent: director
investigation_id: tier3-verification-pipeline-survey-2026-05-18
stage_advancing_from: Synthesize
stage_advancing_to: Document
topic_tags: [survey-document-closure, tier3-pipeline-survey, state-cleanliness, parent-survey-closure, post-edh-matsui-tier3, single-commitment, deferred-19-turns]
paper_section: null
depends_on: [89, 70, 69, 86, "runs/_loop/director/turn_89.md", "runs/_loop/judge/turn_89.json", "runs/_loop/sim/turn_70.md", "runs/_loop/state.json", "runs/_loop/_local/scheduler_90.json", "memory:tier3_pipeline_survey_2026_05_18", "memory:feedback_mechanical_vs_investigation_threshold", "memory:feedback_decision_style", "memory:feedback_manuscript_is_not_the_essence", "memory:feedback_cost_overhead_is_the_cost"]
produces: "T90 implementer_text dispatch for §F4 Document stage of tier3-verification-pipeline-survey-2026-05-18 (the survey investigation that spawned the now-closed-Tier-3 edh-eu151-vortex-vs-matsui-science-2026 child). Terminal close: (a) flip state.json entry current_stage from the T70-style overlong narrative-overlay back to the simple string 'closed', append 'Document' to stages_done, set next_stage/next_stage_action to null, add closing_note that records survey completion + child investigation Tier-3 outcome; (b) NO new memory file (the survey methodology is already captured at `memory/tier3_pipeline_survey_2026_05_18.md` created at T70 — this turn just closes the state.json entry; appending a 2-paragraph closure section to that existing memory file is optional but recommended). State-cleanliness restored after 19-turn (T70 → T90) deferral; closes the last lingering non-closed pre-T87 investigation."
---

# Turn 90 — Director Report

## 1. Investigation state snapshot

- **Active investigation (switching from T89's audit-class-scan-T87 which closed cleanly)**: `tier3-verification-pipeline-survey-2026-05-18` (priority 10, flow_template `survey` per §F4, kind=physics, tier_target 1). State.json lines 2317-2344: `current_stage="Document (deferred to T73+ steady-state via implementer_text; not blocking child investigation T71+ research)"` (T70-style overlong narrative-overlay, structurally analogous to the T62/T63/T88/T89 deviation pattern), `stages_done=["Research", "Synthesize"]`, `next_stage="Document"`, `next_stage_action="Survey Document stage may be done at any steady-state turn (1-turn implementer_text closure); not blocking child investigation T71+ work"`, `tier_current=1`, `tier_target=1`, `closing_note=null`. The child investigation this survey spawned (`edh-eu151-vortex-vs-matsui-science-2026`) is now CLOSED Tier 3.0 at T86 — the survey's purpose is fully realized. Closure has been explicitly deferred since T70 (19 turns); §F4 Document stage is owed.
- **Stage transition**: Synthesize → **Document** per §F4 (Research → Synthesize → Document → closed). This is the terminal stage of the survey template; tier 1 → 1 (already at target on Synthesize completion; Document is the closure narrative, not a tier advance).
- **Tier**: `1.0` → `1.0` (Document is template-terminal closure; tier_current was already at tier_target=1 since T70 Synthesize). Project Tier-3 count stays at 3 (barnett T29, klaus-bch-leak T59, edh-matsui T86); the survey itself is template-target tier 1.
- **Falsifier this turn evaluated**: none. §F4 Document stage is closure narrative + state.json finalization (the survey template has no falsifiers — it is exploratory not verificative).
- **Other in-flight investigations summary** (after T89 audit-class-scan-T87 close):
  - `barnett-mechanism-2026-05-16` (priority 1): CLOSED tier 3.0 at T29.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3): CLOSED tier 3.0 at T59.
  - `edh-eu151-vortex-vs-matsui-science-2026` (priority 1): CLOSED tier 3.0 at T86 (this T90 survey's child; closure is the success metric for the parent survey).
  - `yan-li-saito-2026-reproduction` (priority 1): CLOSED REFUTED-CLEAN at T65 tier 0.4.
  - `judge-in-operator-bug-2026-05-18` (priority 2): CLOSED tier 2 at T54.
  - `audit-due-heuristic-bug-2026-05-18` (priority 4): CLOSED tier 2 at T68.
  - `meta-internal-b-unification-2026-05-18` (priority 5): CLOSED tier 1.
  - `tier3-verification-pipeline-survey-2026-05-18` (priority 10): **THIS TURN's target**; Document pending since T70 (19 turns); 1-turn implementer_text close.
  - `meta-cost-waste-audit-2026-05-18` (priority 15): Observe complete (auto-spawned, spawned_findings recorded); Hypothesize pending (theorist). Cost_inflation drift cleared T87/T88/T89 — no longer urgent but still on the queue.
  - `audit-class-scan-2026-05-18-T50` (priority 20): CLOSED tier 2 at T54.
  - `audit-class-scan-2026-05-18-T61` (priority 20): CLOSED tier 2 at T63.
  - `audit-class-scan-2026-05-18-T87` (priority 20): CLOSED tier 2 at T89 (T89 PASS 33/33; AUDIT_DUE cleared until ~T98).
  - `meta-director-self-audit-2026-05-18` (priority 20): Observe complete (auto-spawn); Hypothesize pending.
  - `meta-stage-routing-2026-05-18` (priority 25): CLOSED tier 0.
  - `meta-cost-inflation-2026-05-18` (priority 40): Observe complete (auto-spawn); Hypothesize pending. Cost_inflation cleared so deprioritized.
  - `meta-critic-placement-2026-05-17` (priority 50): Observe ongoing; deferred.
  - `fullbdg-f6-polar-3000x` (priority 99): dormant (anko-contained), skip.
- **Scheduler** (`runs/_loop/_local/scheduler_90.json` read this turn): decision `go`, policy `JULIA_GPU_OK`, all workloads allowed including `implementer_text` (line 18 of allowed_workloads). Window ends 2026-05-31T23:59 JST with **1,142,326 sec (13.22 days) remaining**. Probe: VRAM 12,700 MB free, RAM 24.98 GB avail, GPU util 1%, foreign_julia 0. `implementer_text` for a single state.json edit + optional memory append is trivially within budget.
- **Last judge verdict**: T89 = PASS (33/33 success criteria, 0 issues, 0 triggered_failure_modes, effective cost 1.59M, cost_audit `BUDGET_OK` 1.59M/1.50M=1.06). T89 closed audit-class-scan-T87 cleanly at tier 2.0. The audit-class-scan cycle (T87+T88+T89) is fully terminated. Need to pick next move.
- **Drift signals (T89 footer expected, post-judge)** — T89 cost_inflation continued downward trend (1.59M < 1.66M T88 < 1.83M T86). manuscript_delta_zero=1.0 (advisory only). novel_claim_zero will be 1.0 again (Document closure is non-novel). AUDIT_DUE remains cleared since T88 turn:88 audit_history row (next surface ~T98). subagent_repetition: T85/T86/T88/T89 = 4 of last 5 implementer_text; T90 implementer_text would be 5 of last 6 (**uptick — rotation pressure**). BUT (a) survey-Document is the cheapest 1-shot closure available, (b) it's pre-routed by T70 director, (c) state-cleanliness has higher institutional value than rotation purity, (d) T91+ explicitly routes to non-implementer subagents (theorist for Sign Pattern Lemma 1 Tier-3 OR researcher for next investigation lit-anchor).
- **Why this is the right move (THIS investigation, THIS stage, NOT noop, NOT something else)**:
  - **Pre-routed by T70**: `next_stage_action: "Survey Document stage may be done at any steady-state turn (1-turn implementer_text closure); not blocking child investigation T71+ work"`. T70-T89 spent on the child (EdH-Matsui Tier-3 trajectory) + intermediate physics + audit cycles. NOW is the "steady-state turn" T70 referred to: child closed Tier 3.0, audit cycle closed, no urgent physics work, T91+ next-investigation pivot is the natural next step.
  - **Survey purpose is fulfilled**: the survey existed to populate the Tier-3 pipeline from [Established] memory inventory. The top-ranked candidate (EdH-Matsui) was spawned at T70, executed T71-T86, and closed Tier 3.0 — the survey's deliverable is realized. Closing the parent restores state-cleanliness.
  - **State-corruption signal**: current_stage carries the 99-char narrative `"Document (deferred to T73+ steady-state via implementer_text; not blocking child investigation T71+ research)"` — same T62/T63/T88/T89 deviation pattern that misleads cold-context director enumeration. T89 fixed the equivalent overlay on audit-class-scan-T87; T90 fixes it for tier3-verification-pipeline-survey. Mechanical batch-fix per `feedback_fix_the_class_not_the_instance` (the class is "T70-style narrative-in-current_stage at Document-pending investigations").
  - **Cheapest available move**: 1 state.json edit + 1 optional memory file append (~300-500k effective). Compare to: spawn `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda` Tier 2→3 theorist (~2-3M but produces D1 verification advance); F1 longer-dynamics rerun for EdH (~3M GPU); meta-cost-waste-audit Hypothesize (~2M theorist meta-work). All non-trivially more expensive. Per `feedback_cost_overhead_is_the_cost`, do the cheap mechanical closure now.
  - **Not noop**: noop would leave state.json `current_stage` carrying the narrative overlay indefinitely; the survey is the last lingering Document-deferred investigation (audit-class-scan-T87 was the previous one, closed T89). Noop wastes the turn budget that was preallocated.
  - **Not spawning new physics investigation THIS turn**: single commitment per turn (`feedback_decision_style`). A new physics investigation needs Research-stage dispatch (researcher) or Hypothesize-stage dispatch (theorist) with its own success criteria. Combining survey-Document with new-physics-spawn would inflate scope and risk FAIL_OPERATIONAL. Cleanest: close survey at T90, route T91 dispatch to next D1 verification investigation.
  - **Not pivoting to meta-cost-waste-audit Hypothesize (priority 15)**: meta is interleaved not parallel per §B2; cost_inflation already cleared since T87 so meta-cost-waste-audit is no longer urgent; survey-Document is higher-priority state-cleanliness.
  - **Not pivoting to F1 longer-dynamics EdH rerun**: optional post-closure refinement that anko did not request; ~3M GPU; the EdH investigation is closed Tier 3.0 so there's no tier-pressure to extend.
  - **Subagent rotation pressure noted but overridden THIS turn**: 5/6 implementer_text incoming, but the rotation pressure is best addressed by routing T91 to theorist (Sign Pattern Lemma 1 Tier-3 closure, ~1.5M, F=2 Kawaguchi-Ueda cross-check from T69 §2.3 menu) which is the cheapest non-implementer D1 advance. T90 closes infra debt; T91 picks the productive rotation pivot.
- **Cost frame**: T63 (analogous Document closure with 1 memory file + 1 state.json edit) cost 1.50M effective. T89 (analogous T87 cycle Document close with new memory file) cost 1.59M. T90 is SIMPLER than T89 because there's NO new memory file required (the survey methodology is already captured at `memory/tier3_pipeline_survey_2026_05_18.md` from T70) — just one state.json edit + an optional 2-paragraph append to that existing memory file. Target ~600k-1.0M effective, 1.5M hard ceiling. Cheapest closure in the recent ladder.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T69 | Research | PASS | researcher inventoried [Established]-tagged memory claims (4 inventoried) + produced ranked 5-candidate Tier-3 promotion menu + 4 NOT_FOUND benchmark gaps recorded. Top pick: edh-eu151-vortex-vs-matsui-science-2026. |
| T70 | Synthesize | PASS | theorist organized T69 menu; structured state.json patch for implementer; spawned child `edh-eu151-vortex-vs-matsui-science-2026` (priority 1, tier_target 3, 4 falsifiers F1-F4); recorded methodology in `memory/tier3_pipeline_survey_2026_05_18.md`. Survey moved to next_stage=Document with explicit deferral note. |
| T90 (THIS TURN) | Document | (TBD; cycle terminal close) | state.json closure: current_stage T70-narrative-overlay → "closed"; stages_done appends "Document"; next_stage/next_stage_action → null; closing_note records child investigation Tier 3.0 outcome. Optional: 2-paragraph append to existing memory file recording survey-purpose-realized + child-outcome. |

The 19-turn deferral (T70 → T90) is by design per T70's pre-routing — survey closure was correctly deprioritized until the child reached terminal closure. Now that EdH-Matsui is Tier 3.0 closed (T86) AND the audit-class-scan-T87 cycle is closed (T89), the survey's terminal close is the cleanest next institutional move.

The T70 sim/turn_70.md §3 documents the exact state.json shape that needs the T90 closure delta: `current_stage`, `stages_done`, `stages_at_turn`, `next_stage`, `next_stage_action`, plus the new `closing_note` field per T50/T61/T87 (closed audit-class-scan cycles) and `klaus-magnetostir-bch-leak` (closed verify-claim) precedents.

## 3. Flow template recall

- **Template**: `survey` (§F4): Research → Synthesize → **Document** → closed.
- **Role for Document**: `implementer_text` per §F4 stage table ("Document: implementer_text — memory entry; possibly spawn child investigation"). The child investigation (`edh-eu151-vortex-vs-matsui-science-2026`) was already spawned at T70 Synthesize, so the §F4 Document role here is purely state.json closure narrative + optional memory append.
- **Verdict-driven routing per §B3**: T70 verdict was PASS (Synthesize complete, child spawned, methodology memory written). Per §B3 table, PASS verdict advances to next stage in template (Document, terminal close). T70 added an explicit deferral note for the next steady-state turn — that turn is T90.
- **Why Document NOW (not waiting further)**:
  - The child investigation `edh-eu151-vortex-vs-matsui-science-2026` has been CLOSED Tier 3.0 since T86 (4 turns ago). The survey's deliverable is realized.
  - The audit-class-scan-T87 cycle (which competed for closure-attention slots T87-T89) is now closed.
  - No urgent physics investigation is queued for T90 — closing this is the natural next move.
  - Per `feedback_mechanical_vs_investigation_threshold` 3-second test: this is a "edit one state.json record + optionally append 2 paragraphs to one existing memory file" change with predictable outcome ("state.json parses, current_stage=closed, closing_note present"). Mechanical execution, not investigation.
  - Per `feedback_cost_overhead_is_the_cost`: completing the closure now is cheaper than further deliberation; state.json `current_stage` field carries a 99-char narrative that misleads cold-context readers.
- **Why NOT collapsing Document + new-investigation-spawn**:
  - Single commitment per turn (`feedback_decision_style`). T90 closes the survey cleanly; T91 picks the next pivot from the T69 §2 menu (Sign Pattern Lemma 1 Tier-3 vs Kawaguchi-Ueda is the cheapest at ~2 turns theorist, OR Bug-4 ITP DDI half-rate revalidation; both menu items #2/#3 are viable).
  - Collapsing would inflate T90's scope and risk a FAIL_OPERATIONAL.

## 4. Research grounding (§A6)

T90 dispatch citations (mechanical bookkeeping closure; grounding emphasizes precedent + safety rails per the canonical Document-closure shape established at T63/T89):

1. **`runs/_loop/sim/turn_70.md` end-to-end** — the T70 implementer's actual state.json patch application that left the survey at `current_stage="Document (deferred to T73+ steady-state via implementer_text; not blocking child investigation T71+ research)"` with `next_stage="Document"` and `next_stage_action="Survey Document stage may be done at any steady-state turn (1-turn implementer_text closure); not blocking child investigation T71+ work"`. T90 honors this T70 pre-routing.

2. **`runs/_loop/director/turn_70.md` §6** — the T70 director's structured patch packet specifying the exact survey state.json shape post-T70.

3. **`runs/_loop/director/turn_89.md` §6** — the canonical predecessor contract for THIS turn's shape (audit-class-scan-T87 Document closure: state.json field-by-field delta + closing_note). T90 reuses its structure with deltas: investigation_id `audit-class-scan-2026-05-18-T87` → `tier3-verification-pipeline-survey-2026-05-18`, flow_template `audit-class-scan` → `survey`, no new memory file (the methodology memory already exists at `tier3_pipeline_survey_2026_05_18.md`), closing_note content shifts from "3rd audit-class-scan cycle steady-state" to "survey deliverable realized via EdH-Matsui Tier 3.0 closure".

4. **`runs/_loop/judge/turn_89.json`** — T89 PASS verdict (33/33 criteria). investigation_update.if_success_advance_to_stage for T89 was simple `"closed"` (audit-class-scan-T87 close); T90 mirrors this minimalism with even simpler scope (no new memory file required).

5. **`runs/_loop/state.json` `audit-class-scan-2026-05-18-T50/T61/T87` + `klaus-magnetostir-bch-leak-2026-05-13` + `barnett-mechanism-2026-05-16` entries** — the 5 canonical closed-investigation entry shapes (4 audit-class-scan, 1 verify-claim, 1 verify-claim): `current_stage="closed"` simple string, `stages_done` array includes Document, `next_stage=null`, `next_stage_action=null`, `closing_note` narrative. T90 mirrors this template for the survey.

6. **`/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tier3_pipeline_survey_2026_05_18.md`** (the existing survey methodology memory file from T70) — already documents the 5-candidate menu, ranking rationale, NOT_FOUND benchmarks, excluded categories. T90 may OPTIONALLY append a 2-paragraph closure section recording the child investigation's terminal Tier 3.0 outcome + lessons for future surveys. NOT required for §F4 template compliance (the memory file already exists; the template only requires state.json closure).

7. **`runs/_loop/state.json` `tier3-verification-pipeline-survey-2026-05-18` entry (lines 2317-2344)** — the current state shape that T90 patches: `current_stage` 99-char narrative, `stages_done` 2-element array, `next_stage="Document"`, etc. T90 reads this entry pre-edit, applies the closure delta, validates post-edit.

8. **Memory `feedback_fix_the_class_not_the_instance.md`** (anko 2026-05-18) — meta-pattern motivating batch-fixing the "T62-style narrative-in-current_stage" class. T89 fixed audit-class-scan-T87's instance; T90 fixes the survey's instance — same class, same fix shape.

9. **Memory `feedback_mechanical_vs_investigation_threshold.md`** (anko 2026-05-18) — 3-second test: this Document IS mechanical (predictable outcome, success = state.json parses + current_stage=="closed"). No flow theater.

10. **Memory `feedback_decision_style.md`** — single commitment per turn; T90 closes the survey; T91 picks the next pivot.

11. **Memory `feedback_cost_overhead_is_the_cost.md`** (anko 2026-05-15) — execute the closure immediately rather than further deliberation.

12. **Memory `feedback_manuscript_is_not_the_essence.md`** (anko 2026-05-15) — survey-Document closure is institutional-hygiene work that clears state for future D1/D2/D3 work. Not manuscript polish.

13. **Director.md §F4 Document stage role table** — Document role = `implementer_text`. The "memory entry" half of §F4 was already done at T70 Synthesize (the `tier3_pipeline_survey_2026_05_18.md` file); §F4 Document is the state.json closure + optional methodology-memory append.

14. **Director.md §F4 (the survey template definition itself)** — "Document — implementer_text — memory entry; possibly spawn child investigation". The "possibly spawn child" half was done at T70 (EdH-Matsui spawned). The "memory entry" half is the optional appendix at T90.

15. **`runs/_loop/director/turn_63.md` §6 (T61-cycle Document closure)** + **`runs/_loop/sim/turn_63.md`** — the canonical 2-artifact Document-closure shape (memory + state.json) executed at T63. T90 simplifies this: state.json only (memory already exists), optional 2-paragraph append.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D2 (service axis: state-cleanliness; restores cold-context director enumeration accuracy)**. The survey's child investigation EdH-Matsui was the actual D1 verification advance (closed Tier 3.0 T86). T90 finalizes the parent infrastructure that produced that D1 outcome. Per §A5 D2 justification ("optimize blocked by performance"): unclosed survey investigation leaves state.json carrying narrative-overlay in `current_stage` field that misleads future cold-context director runs into thinking Document is still pending; closing the survey restores clean enumeration for T91+ next-pivot picks.
- **Tier ladder position**: T90 advances `tier3-verification-pipeline-survey-2026-05-18` from tier 1 (Synthesize complete) to tier 1 (Document complete, cycle terminal close). The survey template's tier_target IS 1 — it is exploratory, not Tier-3 candidate. Project Tier-3 count stays at 3 (barnett + klaus-bch-leak + edh-matsui), unchanged.
- **Project D1 verification depth narrative**: 3 Tier-3 trajectories closed. T90 keeps loop infrastructure clean for the next D1 pivot (T91+).
- **Manuscript NOT in scope** (per `feedback_manuscript_is_not_the_essence`). T90 modifies state.json + optionally appends to one memory file + writes sim/turn_90.md only.
- **Cost frame**: target ~600k-1.0M effective (simpler than T89's 1.59M because NO new memory file required; just state.json edit + optional 2-paragraph append to existing memory). 1.5M hard cap. T90 is the SIMPLEST closure in the recent ladder; if it lands at ~700k it further clears DRIFT_COST_INFLATION trend.
- **Drift trajectory after T90 (anticipated)**:
  - cost_inflation: continues downward (~700k expected vs 1.59M T89).
  - code_delta_zero: 1.0 (state.json + memory only; no src/ touched — correct by design).
  - manuscript_delta_zero: 1.0 (correctly, by design).
  - novel_claim_zero: 1.0 (Document closure is closure narrative; no novel claims).
  - topic_repetition: drops slightly (audit-class-scan → tier3-pipeline-survey is a topic switch).
  - subagent_repetition: 5 of last 6 implementer_text (T84/T85/T86/T88/T89/T90; uptick — T91+ MUST rotate; recommend theorist for Sign Pattern Lemma 1 Tier-3 closure from T69 §2 menu).
  - verdict_drift: 0.0 (T90 canonically PASSes mechanical Document).
- **Recommended T91-T92 trajectory** (priority-ordered pivots):
  1. **T91 theorist Hypothesize for `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda`** (Tier 2 → 3, ~1.5-2.5M theorist text-only, cheapest non-implementer rotation, D1 axis advance). Spawn the investigation at T91 from T69 §2.3 menu item #3; compare General-S closed form against KU2012 §4 channel weight tables for F=2 T_d state. 1-2 turn investigation (Research stage already done at T69 lit-anchor; can skip directly to Hypothesize).
  2. **T91+ researcher_deep for `bug-4-itp-ddi-half-rate-revalidation`** (Tier 1 → 2, ~1.5-3M, T69 §2.2 menu item #2; complementary to EdH F3 falsifier which implicitly audited Bug-4 at production parameters). Could pair with #1.
  3. **T91+ meta-cost-waste-audit Hypothesize** (priority 15): cost_inflation already cleared since T87 so deprioritized; if T90+ trend reverses, reactivate.
  4. **F1 longer-dynamics EdH rerun** (~3M GPU, post-closure refinement): optional; not blocking; EdH already Tier 3.0.
  5. **Anko-surfaced new direction** (if seed.md updates): highest priority by §B2 rules.
- **Subagent rotation discipline T91+**: 5 of last 6 implementer_text incoming. T91 MUST be theorist or researcher (not implementer_text) to rotate. The Sign Pattern Lemma 1 Tier-3 pivot is the natural theorist rotation candidate (cheapest D1 advance + already-done Research at T69 means jump to Hypothesize). I recommend T91 = theorist Hypothesize for `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda` (verify-claim template skipping straight to Hypothesize since Research is already done).

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "tier3-verification-pipeline-survey-2026-05-18",
  "stage_advancing_to": "Document",
  "subagent_type": "implementer_text",
  "parallel_researcher_count": 1,
  "rationale": "T70 Synthesize stage completed PASS and explicitly deferred Document closure to any steady-state turn via next_stage_action='Survey Document stage may be done at any steady-state turn (1-turn implementer_text closure); not blocking child investigation T71+ work'. The survey's child investigation edh-eu151-vortex-vs-matsui-science-2026 has been CLOSED Tier 3.0 since T86 (deliverable realized); the audit-class-scan-T87 cycle was closed at T89 PASS 33/33. NOW is the steady-state turn T70 referred to. Per feedback_mechanical_vs_investigation_threshold 3-second test, this is pure mechanical bookkeeping (one state.json record edit + optional 2-paragraph append to an existing memory file; success = state.json parses + current_stage=='closed' + closing_note present). The T89 predecessor dispatched implementer_text for analogous Document closure of audit-class-scan-T87; T90 mirrors that shape with deltas: investigation_id audit-class-scan-T87 -> tier3-verification-pipeline-survey, flow_template audit-class-scan -> survey, NO new memory file (the methodology memory already exists at memory/tier3_pipeline_survey_2026_05_18.md from T70), optional 2-paragraph append section that records the child investigation's terminal Tier 3.0 outcome. APC contract template cache hit on physics::survey::Document not available (n_seen=0 for survey-Document; closest analog is audit-class-scan::Document at T63/T89 which T90 adapts).",
  "brief": "## ROLE\n\nYou are implementer_text. T90 §F4 Document stage of tier3-verification-pipeline-survey-2026-05-18 (the survey investigation that spawned the now-closed-Tier-3 edh-eu151-vortex-vs-matsui-science-2026 child at T70). Terminal close. Mechanical bookkeeping ONLY: apply one state.json record edit + OPTIONAL 2-paragraph append to the existing memory file `memory/tier3_pipeline_survey_2026_05_18.md`. NO new memory file (the methodology was already captured at T70). No patterns.yaml writes. No src/ modification. No agent-prompt modification.\n\nDIRECTIVE_LABEL: tier3-pipeline-survey-T90-document\n\n## REQUIRED READING (READ FIRST, BEFORE EDITING ANYTHING)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_90.md` (this director report) -- the dispatch rationale + §6 contract.\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_70.md` §6 -- the T70 director's patch packet for the survey state.json shape post-Synthesize.\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_70.md` end-to-end -- the T70 implementer's state.json edits that established the current shape T90 will close.\n4. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_89.md` -- predecessor Document-closure shape for audit-class-scan-T87 (state.json edit pattern T90 will adapt).\n5. `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_89.json` -- T89 PASS verdict reference for the closure shape T90 emulates.\n6. `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` lines 2317-2344 -- the `tier3-verification-pipeline-survey-2026-05-18` entry T90 will close. ALSO read the `audit-class-scan-2026-05-18-T87` entry (lines 2524-2575) AND the `audit-class-scan-2026-05-18-T61` entry (lines 2213-2263) for canonical closed-state shape template.\n7. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tier3_pipeline_survey_2026_05_18.md` -- the existing survey methodology memory file from T70. May be appended (optional) with a 2-paragraph closure section at the end. Do NOT rewrite earlier sections.\n\n## YOUR JOB -- 1 REQUIRED ARTIFACT + 1 OPTIONAL\n\n### Artifact 1 (REQUIRED): Update state.json\n\nApply the following delta to the `tier3-verification-pipeline-survey-2026-05-18` investigation entry in `state.json.investigations` (lines 2317-2344):\n\n- `current_stage`: from `\"Document (deferred to T73+ steady-state via implementer_text; not blocking child investigation T71+ research)\"` (T70-set narrative overlay) -> `\"closed\"` (simple string).\n- `stages_done`: from `[\"Research\", \"Synthesize\"]` -> `[\"Research\", \"Synthesize\", \"Document\"]` (append Document).\n- `stages_at_turn`: ADD a Document row to the existing dict:\n  ```python\n  stages_at_turn[\"Document\"] = [90, \"implementer_text terminal closure: child investigation edh-eu151-vortex-vs-matsui-science-2026 closed Tier 3.0 at T86; survey deliverable realized; state.json closure narrative + optional 2-paragraph append to existing memory/tier3_pipeline_survey_2026_05_18.md\"]\n  ```\n  Preserve existing Research/Synthesize entries VERBATIM.\n- `tier_current`: unchanged (`1`).\n- `tier_target`: unchanged (`1`).\n- `next_stage`: from `\"Document\"` -> `null`.\n- `next_stage_action`: from `\"Survey Document stage may be done at any steady-state turn (1-turn implementer_text closure); not blocking child investigation T71+ work\"` -> `null`.\n- REPLACE `closing_note: null` with:\n  `closing_note: \"Survey deliverable realized 2026-05-18 T90. Child investigation edh-eu151-vortex-vs-matsui-science-2026 (spawned at T70 from §2.1 menu top pick) closed Tier 3.0 at T86 (3rd project Tier-3 trajectory; 1st lab-paper benchmark -- Matsui et al. Science 391, 384-388, 2026). 4 menu candidates still available for future Tier-3 promotion (Bug-4 ITP DDI half-rate revalidation #2; Sign Pattern Lemma 1 Tier-3 vs Kawaguchi-Ueda #3; TwoChannelLHY F=6 30-70% #4 capped Tier 2.5; TDHFB Phase 2 HF kernel #5). 4 NOT_FOUND benchmark gaps recorded in memory/tier3_pipeline_survey_2026_05_18.md. Survey methodology preserved in same memory file for future surveys. 19-turn deferral (T70 to T90) was by design per T70 next_stage_action; closure now restores state-cleanliness for T91+ next-pivot picks. Recommended T91 dispatch: theorist Hypothesize for sign-pattern-lemma1-tier3-vs-kawaguchi-ueda (T69 §2.3 menu item #3; cheapest D1 advance; rotates subagent off implementer_text after 5 of last 6).\"`\n\nDo NOT touch any other state.json field (turn, history, last_judge, other investigations, schema_version, current_agent_hashes, last_directive_*, last_error, retries, etc. -- orchestrator manages those).\n\nValidate post-edit: `python3 -c \"import json; d = json.load(open('/home/suzume/workspace/BEC-simulation/runs/_loop/state.json')); e = d['investigations']['tier3-verification-pipeline-survey-2026-05-18']; assert e['current_stage'] == 'closed'; assert e['tier_current'] == 1; assert 'Document' in e['stages_done']; assert e['next_stage'] is None; assert e['next_stage_action'] is None; assert e['closing_note'] is not None; assert 'edh-eu151-vortex-vs-matsui-science-2026' in e['closing_note']; print('OK_json T90 survey closure applied')\" && echo OK_state`\n\n### Artifact 2 (OPTIONAL but RECOMMENDED): Append closure section to existing memory file\n\nAppend a 2-paragraph closure section to the END of `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tier3_pipeline_survey_2026_05_18.md` (do NOT rewrite earlier sections; only append at the end). Suggested heading: `## Outcome (T90 closure)`. Content shape:\n\n```markdown\n## Outcome (T90 closure)\n\n**Survey closed at tier 1 (= tier_target) as of 2026-05-18 T90.** Top-ranked candidate `edh-eu151-vortex-vs-matsui-science-2026` (§2.1) was spawned at T70 Synthesize, executed T71-T86 (researcher_deep Matsui PDF extraction at T71; theorist Hypothesize bands D1-D7 at T72; implementer matsui_edh_baseline.yaml Case A at T73; Execute T74-T82; critic CORROBORATE_WITH_ERRATA at T83; Document T84-T86), and CLOSED Tier 3.0 at T86 (3rd project Tier-3 trajectory; 1st lab-paper benchmark). F3 (GS energy self-consistency) CORROBORATEd at 8.0% rel_error within 20% band; F1 ring-emergence NOT_APPLICABLE_NO_RING ratified at T86 with optional longer-dynamics rerun deferred. The survey's prediction that the EdH-Matsui candidate would be the highest-load-bearing × highest-benchmark-quality Tier-3 candidate was validated.\n\nRemaining 4 candidates from the §2 menu are available for future Tier-3 promotion: #2 `bug-4-itp-ddi-half-rate-revalidation` (Tier 1→2, cheapest, internal self-consistency check); #3 `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda` (Tier 2→3, 1-2 turn theorist, F=2 T_d cross-check against KU2012 channel weight tables); #4 `twochannel-lhy-F6-polar-30-70-percent-error` (capped Tier 2.5 due to NOT_FOUND F=6 multi-channel spinor LHY benchmark); #5 `tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum` (Tier 2→3 via F=1 sound velocity vs KU2012 §4.2). 4 NOT_FOUND benchmark gaps recorded in the parent file remain authoritative. Survey methodology (load-bearing × benchmark-quality × cost ranking) is preserved for future Tier-3 pipeline scans -- the same ranking shape can be re-applied when the [Established] memory inventory grows or new external benchmarks surface.\n```\n\nUse English only. No emojis. No anko-attribution. No improvised terminology. If you skip Artifact 2 (acceptable for cost reasons), set `memory_file_appended_outcome_section` to false in the Metrics JSON; otherwise set true.\n\n## RECOMMENDED EXECUTION SHAPE (mirroring T89 precedent)\n\n1. **Precondition check first**: run the precondition_check from this director report's observable_manifest. If it fails, STOP and report; do not improvise.\n2. Use the `Read` tool to inspect the current state.json `tier3-verification-pipeline-survey-2026-05-18` entry (lines 2317-2344) and confirm shape.\n3. Write a one-shot Python helper to `/tmp/state_close_t90_survey.py` that uses `json.load` + `json.dump(..., indent=2)` to apply the state.json delta. Avoid hand-editing JSON (whitespace + nesting risks).\n4. Run the helper; validate JSON parse after edit.\n5. If executing Artifact 2: use the `Edit` tool to append the new heading + 2-paragraph section at the end of the memory file. Verify with `tail -30` post-edit.\n6. Optionally `git diff runs/_loop/state.json` to show the change.\n7. Write `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_90.md` describing the artifacts with the §4 Metrics JSON block (see below).\n\n## METRICS JSON (single fenced ```json``` block in sim/turn_90.md §4)\n\n```json\n{\n  \"experiment_kind\": \"text_only\",\n  \"investigation_kind\": \"physics\",\n  \"src_files_modified\": 0,\n  \"new_analysis_scripts_written\": 0,\n  \"agents_md_files_modified\": 0,\n  \"patterns_yaml_modified\": false,\n  \"state_json_modified\": true,\n  \"state_json_tier3_survey_closed\": true,\n  \"state_json_tier3_survey_tier_current\": 1,\n  \"state_json_tier3_survey_stages_done_includes_document\": true,\n  \"state_json_tier3_survey_has_closing_note\": true,\n  \"state_json_tier3_survey_next_stage_is_null\": true,\n  \"state_json_tier3_survey_next_stage_action_is_null\": true,\n  \"state_json_history_array_modified\": false,\n  \"state_json_other_investigations_modified\": false,\n  \"state_json_valid_after_edit\": true,\n  \"memory_files_added\": 0,\n  \"memory_files_added_list\": [],\n  \"memory_file_appended_outcome_section\": <true | false; true if Artifact 2 executed>,\n  \"existing_methodology_memory_file_preserved\": true,\n  \"investigation_id\": \"tier3-verification-pipeline-survey-2026-05-18\",\n  \"stage_advancing_to\": \"Document\",\n  \"flow_template\": \"survey\",\n  \"judge_py_unchanged\": true,\n  \"agents_md_unchanged\": true,\n  \"src_subtree_untouched\": true,\n  \"manuscript_edited\": false,\n  \"src_edited\": false,\n  \"julia_executed\": false\n}\n```\n\n## CONSTRAINTS\n\n- **Files allowed to modify**: `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json`, `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_90.md` (the turn report).\n- **Files allowed to modify if executing Artifact 2**: `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tier3_pipeline_survey_2026_05_18.md` (APPEND ONLY at end of file).\n- **Files allowed to create**: `/tmp/state_close_t90_survey.py` (one-shot helper script).\n- **Files FORBIDDEN to modify**: `src/`, `runs/eu151_*/`, `runs/matsui_edh_baseline_*/`, `scripts/`, `.claude/agents/*`, `.claude/scripts/*`, `.claude/workload_specs.yaml`, `quota_config.json`, `.claude/settings*.json`, `runs/_loop/patterns.yaml`, any other `runs/_loop/` file, any other investigation entry in state.json, state.json `turn` / `history` / `last_judge` / `schema_version` / `current_agent_hashes` / `last_directive_*` / `last_error` / `retries` fields, any docs/manuscript files. Do NOT rewrite earlier sections of `tier3_pipeline_survey_2026_05_18.md` (append-only).\n- **No julia execution required**. No new analysis scripts in `runs/auto/`.\n- **English only. No emojis. No anko-attribution. No improvised terminology.**\n- **Absolute paths in all Read / Write / Bash tool calls.**\n- **Cost budget**: stay within ~1.5M effective tokens, ~8 min wall hard cap. Target 700k-1.0M (simpler than T89 because no new memory file is required).\n- **No fabrication**: every claimed metric value in sim/turn_90.md must correspond to an actual file state observable via Read after the edits.\n\n## ANTI-PATTERN GUARDS\n\n- Do NOT modify src/, manuscript, state.history, patterns.yaml, .claude/agents/scripts, or .claude/workload_specs.yaml.\n- Do NOT execute julia.\n- Do NOT close any other investigation; only `tier3-verification-pipeline-survey-2026-05-18`.\n- Do NOT create a new memory file (the methodology memory already exists at T70; only optional append).\n- Do NOT rewrite earlier sections of the existing memory file; append-only.\n- Do NOT leave `current_stage` as a long narrative string post-T90 (must be the simple string `\"closed\"`).\n- Do NOT spawn a new investigation in state.json this turn (single commitment per turn; T91 will pick the next pivot).\n- Do NOT exceed 1.5M effective tokens.\n- Do NOT skip the closing_note (it captures the survey-deliverable-realized institutional record).\n\n## REPORTING DISCIPLINE\n\nIf the precondition check fails (state.json not parseable; tier3-pipeline-survey entry malformed or already closed; T70 outputs missing), STOP and report; do not improvise. If post-edit JSON validation fails, REVERT (`git restore /home/suzume/workspace/BEC-simulation/runs/_loop/state.json`) and report. Do not commit broken state. If you discover that the survey is already closed (current_stage already `\"closed\"`), STOP and report -- that would be a state-corruption signal worth investigating. Honest counts only -- every claimed metric in sim/turn_90.md must correspond to actual file state.",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "investigation_kind",
      "src_files_modified",
      "new_analysis_scripts_written",
      "agents_md_files_modified",
      "patterns_yaml_modified",
      "state_json_modified",
      "state_json_tier3_survey_closed",
      "state_json_tier3_survey_tier_current",
      "state_json_tier3_survey_stages_done_includes_document",
      "state_json_tier3_survey_has_closing_note",
      "state_json_tier3_survey_next_stage_is_null",
      "state_json_tier3_survey_next_stage_action_is_null",
      "state_json_history_array_modified",
      "state_json_other_investigations_modified",
      "state_json_valid_after_edit",
      "memory_files_added",
      "memory_files_added_list",
      "memory_file_appended_outcome_section",
      "existing_methodology_memory_file_preserved",
      "investigation_id",
      "stage_advancing_to",
      "flow_template",
      "judge_py_unchanged",
      "agents_md_unchanged",
      "src_subtree_untouched",
      "manuscript_edited",
      "src_edited",
      "julia_executed"
    ],
    "optional": [],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/state.json && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_70.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_70.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_89.json && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_89.md && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tier3_pipeline_survey_2026_05_18.md && python3 -c \"import json; d = json.load(open('/home/suzume/workspace/BEC-simulation/runs/_loop/state.json')); inv = d['investigations']['tier3-verification-pipeline-survey-2026-05-18']; assert inv['tier_current'] == 1, 'survey tier_current must be 1 pre-T90'; assert 'Synthesize' in inv['stages_done'], 'survey stages_done must include Synthesize pre-T90'; assert 'Document' not in inv['stages_done'], 'survey stages_done must NOT include Document pre-T90'; assert inv['next_stage'] == 'Document', 'survey next_stage must be Document pre-T90'; assert inv.get('closing_note') is None, 'survey closing_note must be null pre-T90'; assert 'closed' not in inv['current_stage'].lower() or inv['current_stage'].startswith('Document'), 'survey must not be already-closed pre-T90'; print('OK precondition: survey entry at tier 1 with Synthesize done, Document pending, ready for T90 closure')\""
  },
  "success_criteria": [
    {
      "id": "experiment_kind_correct",
      "metric": "experiment_kind",
      "operator": "==",
      "value": "text_only",
      "tolerance": null,
      "rationale": "Document is text-only state.json edit + optional memory append; no julia execution."
    },
    {
      "id": "investigation_kind_physics",
      "metric": "investigation_kind",
      "operator": "==",
      "value": "physics",
      "tolerance": null,
      "rationale": "tier3-verification-pipeline-survey is kind=physics per state.json line 2342."
    },
    {
      "id": "src_unchanged",
      "metric": "src_files_modified",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Document closure must not modify src/."
    },
    {
      "id": "no_scripts_committed",
      "metric": "new_analysis_scripts_written",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "/tmp/ helper is /tmp/-local and does not count."
    },
    {
      "id": "no_agents_md_changes",
      "metric": "agents_md_files_modified",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Document closure does not modify agent prompts."
    },
    {
      "id": "patterns_yaml_untouched",
      "metric": "patterns_yaml_modified",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "Survey closure is unrelated to patterns.yaml audit catalog."
    },
    {
      "id": "state_json_modified_correctly",
      "metric": "state_json_modified",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "state.json must receive the closure edit on survey investigation entry."
    },
    {
      "id": "survey_closed",
      "metric": "state_json_tier3_survey_closed",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "current_stage flipped from T70-style narrative-overlay to the simple string 'closed'."
    },
    {
      "id": "survey_tier_one",
      "metric": "state_json_tier3_survey_tier_current",
      "operator": "==",
      "value": 1,
      "tolerance": null,
      "rationale": "tier_current stays at 1 (= tier_target since T70; Document is terminal closure, not tier advance)."
    },
    {
      "id": "survey_stages_done_has_document",
      "metric": "state_json_tier3_survey_stages_done_includes_document",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "stages_done must append Document."
    },
    {
      "id": "survey_has_closing_note",
      "metric": "state_json_tier3_survey_has_closing_note",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Survey-deliverable-realized narrative captured in closing_note field per T50/T61/T87/T89 + klaus-bch-leak precedents."
    },
    {
      "id": "survey_next_stage_null",
      "metric": "state_json_tier3_survey_next_stage_is_null",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Closed investigation has no next_stage."
    },
    {
      "id": "survey_next_stage_action_null",
      "metric": "state_json_tier3_survey_next_stage_action_is_null",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Closed investigation has no next_stage_action."
    },
    {
      "id": "history_untouched",
      "metric": "state_json_history_array_modified",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "history array is orchestrator-managed."
    },
    {
      "id": "other_investigations_untouched",
      "metric": "state_json_other_investigations_modified",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "Only the survey entry is closed this turn."
    },
    {
      "id": "state_json_parses",
      "metric": "state_json_valid_after_edit",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "post-edit JSON must parse."
    },
    {
      "id": "no_new_memory_files",
      "metric": "memory_files_added",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Methodology memory already exists at T70; T90 only optionally appends to it."
    },
    {
      "id": "methodology_memory_preserved",
      "metric": "existing_methodology_memory_file_preserved",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Earlier sections of tier3_pipeline_survey_2026_05_18.md must NOT be rewritten; append-only if Artifact 2 executed."
    },
    {
      "id": "investigation_consistent",
      "metric": "investigation_id",
      "operator": "==",
      "value": "tier3-verification-pipeline-survey-2026-05-18",
      "tolerance": null,
      "rationale": "Implementer report must echo the investigation_id from director contract."
    },
    {
      "id": "stage_consistent",
      "metric": "stage_advancing_to",
      "operator": "==",
      "value": "Document",
      "tolerance": null,
      "rationale": "Implementer report must echo Document from director contract."
    },
    {
      "id": "template_consistent",
      "metric": "flow_template",
      "operator": "==",
      "value": "survey",
      "tolerance": null,
      "rationale": "Survey template per §F4 (state.json line 2320)."
    },
    {
      "id": "judge_py_intact",
      "metric": "judge_py_unchanged",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Document closure must not modify judge.py."
    },
    {
      "id": "agents_md_intact",
      "metric": "agents_md_unchanged",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Document closure must not modify agent prompts."
    },
    {
      "id": "src_subtree_intact",
      "metric": "src_subtree_untouched",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Document closure must not modify src/."
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
      "rationale": "Redundant src/ guard for clarity."
    },
    {
      "id": "no_julia_execution",
      "metric": "julia_executed",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "Document closure is text-only."
    }
  ],
  "failure_modes": [
    {
      "if": "state_json_parses == false OR state_json_modified == false",
      "category": "operational",
      "next_action": "T91 director re-dispatches implementer_text Document closure with corrected scope; revert state.json from git if mid-edit corruption."
    },
    {
      "if": "survey_closed == false (current_stage still not 'closed' after edit)",
      "category": "operational",
      "next_action": "T91 director re-dispatches with explicit string-literal expectation; the edit failed to apply the field-level change."
    },
    {
      "if": "other_investigations_untouched == false",
      "category": "operational",
      "next_action": "T91 director audits the unintended-modification; revert state.json from git and re-apply only the survey-entry delta."
    },
    {
      "if": "survey_has_closing_note == false",
      "category": "operational",
      "next_action": "T91 director re-dispatches with explicit closing_note string; field was set to null when non-null was expected."
    },
    {
      "if": "methodology_memory_preserved == false (earlier sections of tier3_pipeline_survey_2026_05_18.md were rewritten)",
      "category": "operational",
      "next_action": "T91 director restores memory file from git; re-dispatches with append-only constraint repeated explicitly."
    },
    {
      "if": "subagent dispatched anything julia/GPU when scheduler allows but contract forbids",
      "category": "framework_error",
      "next_action": "T91 director reviews implementer prompt for unauthorized escalation; this is the contract being ignored, not a scheduler failure."
    },
    {
      "if": "T90 implementer encounters precondition_check failure (e.g., survey already closed, or T70 sim/turn_70.md missing)",
      "category": "data_gap",
      "next_action": "T91 director investigates state-corruption signal; if survey already closed at some prior turn that director missed, document the discrepancy and move to next pivot (Sign Pattern Lemma 1 Tier-3 OR meta-cost-waste-audit)."
    },
    {
      "if": "cost > 1.5M effective (hard cap)",
      "category": "operational",
      "next_action": "T91 director audits cost source; if implementer over-elaborated the optional Artifact 2 memory append, instructs T91+ to skip Artifact 2 in similar future closures."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 1500000,
    "wall_time_max_seconds": 480
  },
  "budget": {
    "expected_cost_eff": 800000,
    "expected_wall_time_sec": 300,
    "split_by_subtask": {
      "context_read_and_precondition": 200000,
      "state_json_helper_write_and_apply": 250000,
      "optional_memory_append": 150000,
      "sim_turn_90_md_write": 200000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "closed",
    "if_success_tier_becomes": 1,
    "if_partial_success_advance_to_stage": "Document (T91 retry with corrected scope)",
    "if_partial_success_tier_becomes": 1,
    "if_refuted_advance_to_stage": "n/a (survey Document has no hypothesis to refute; only mechanical closure)",
    "if_refuted_tier_becomes": 1,
    "if_inconclusive_advance_to_stage": "Document (T91 expanded clarity)",
    "if_inconclusive_tier_becomes": 1,
    "next_falsifier_to_test_after": "n/a (survey template does not use falsifier framework)"
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read state.json (lines 1750-1775 active_investigation_id + investigations_index, lines 2317-2344 survey entry, lines 2524-2575 audit-class-scan-T87 entry for shape template, lines 1900-1970 yan-li-saito for closed-shape template, lines 2106-2150 audit-class-scan-T50 entry) + scheduler_90.json + seed.md (still stale 2026-05-15 morning Klaus-julia ban, not applicable T90) THIS turn.
- [x] Read judge/turn_89.json (T89 PASS verdict 33/33) + director/turn_89.md §1-§6 (precedent contract structure).
- [x] Read sim/turn_70.md (the T70 state.json patch that established the current shape) + memory/tier3_pipeline_survey_2026_05_18.md (the existing methodology memory).
- [x] Considered switching to a different investigation (sign-pattern-lemma1-tier3-vs-kawaguchi-ueda Hypothesize, meta-cost-waste-audit Hypothesize, F1 longer-dynamics EdH rerun) -- all explicitly considered and rejected in §1 for this turn; routed to T91 instead.
- [x] investigation_id `tier3-verification-pipeline-survey-2026-05-18` valid in state.investigations (line 2317).
- [x] stage_advancing_to `Document` is the next stage per flow template §F4 (Research → Synthesize → Document → closed; T70 completed Synthesize, T70 next_stage_action explicitly set next stage to Document with steady-state deferral).
- [x] subagent_type `implementer_text` matches role_per_stage[Document] for `survey` template per §F4 ("Document: implementer_text — memory entry; possibly spawn child investigation"; spawn-child half done at T70, memory-entry already exists from T70, T90 does the state.json closure + optional append).
- [x] success_criteria are machine-evaluable: 27 criteria, every metric appears in Metrics JSON schema sketched in brief §METRICS JSON; all use ==/== operators on scalar/bool values; judge.py will trivially apply.
- [x] failure_modes cover the 7 most likely failures (state.json parse, current_stage not flipped, other-investigation corruption, closing_note missing, methodology memory rewritten, unauthorized julia, precondition failure, cost overrun).
- [x] observable_manifest precondition_check is concrete (single bash one-liner using test + python3 -c with 7 explicit assertions; would actually run and fail-fast if state diverged from expected).
- [x] budget fits within scheduler window_seconds_left (1.14M sec >> 480 sec wall_time_max).
- [x] §A6 research-first citation present (15 enumerated references in §4 to prior loop turns, memory files, state.json entries, director.md template definitions).
- [x] §A5 D-axis articulated: D2 service axis with explicit blocked-by justification (state-cleanliness for cold-context director enumeration; the survey was the engine that produced the EdH-Matsui D1 Tier-3 advance). Manuscript NOT in scope.
- [x] investigation_update field updates current_stage (T70-narrative → "closed") AND tier_current (1 → 1; terminal closure not tier advance) correctly per success path.
- [x] §F4 safety rails: append-only on existing memory file; no new memory file; no patterns.yaml touch; no src/; no agents.md.
- [x] Single commitment per turn (not collapsing with T91 next-pivot spawn).
- [x] Subagent rotation pressure noted (5 of 6 implementer_text) and explicitly routed to theorist at T91 (Sign Pattern Lemma 1 Tier-3 from T69 §2.3 menu).
