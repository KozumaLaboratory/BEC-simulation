---
turn: 68
subagent: director
investigation_id: audit-due-heuristic-bug-2026-05-18
stage_advancing_from: null (new fix-bug investigation spawning at Reproduce/Fix-collapsed stage per 3-second mechanical test)
stage_advancing_to: Fix (collapses Reproduce/Fix/Test/Document into a single implementer_text turn per `feedback_mechanical_vs_investigation_threshold` and prior-turn T67 §5 explicit T68 trajectory recommendation)
topic_tags: [drift-signals-bug, audit-due-false-positive, patterns-yaml-schema-fix, mechanical-fix-3-second-test, loop-infrastructure-hygiene, fix-class-not-instance]
paper_section: null
depends_on: [67, 66, 65, "runs/_loop/director/turn_67.md", "runs/_loop/state.json", "runs/_loop/_local/scheduler_68.json", "runs/_loop/seed.md", "runs/_loop/patterns.yaml", ".claude/scripts/drift_signals.py", "memory:feedback_mechanical_vs_investigation_threshold", "memory:feedback_fix_the_class_not_the_instance", "memory:feedback_decision_style", "memory:feedback_cost_overhead_is_the_cost"]
produces: "patterns.yaml audit_history entries gain explicit `turn:` field so `_compute_audit_due_advisory` correctly computes `last_audit_turn` instead of falling back to 0; AUDIT_DUE drift advisory clears from director_must_address noise to silent until next real ≥10-turn gap; minimal-scope fix-bug investigation closes in 1 implementer_text turn"
---

# Turn 68 — Director Report

## 1. Investigation state snapshot

- **active_investigation_id (state.json line 1877)**: `null` (post-T67 NOOP_DIRECTOR; state machine still has no open scientific work)
- **All anko priority 1-3 physics investigations terminally closed/dormant**:
  | id | priority | tier | current_stage | last_turn |
  |---|---|---|---|---|
  | barnett-mechanism-2026-05-16 | 1 | 3.0 / target 3 | closed | T29 |
  | yan-li-saito-2026-reproduction | 1 | 0.4 / target 3 | closed (DORMANT-CLOSE) | T65 |
  | klaus-magnetostir-bch-leak-2026-05-13 | 3 | 3.0 / target 3 | closed | T59 |
  | judge-in-operator-bug-2026-05-18 | 2 | 2 / target 2 | closed | T54 |
  | meta-internal-b-unification-2026-05-18 | 5 | 1 / target 1 | closed (mechanical) | T49 |
  | meta-stage-routing-2026-05-18 | 25 | 0.0 / target 1 | closed (REFUTED-BY-CONFOUNDER) | T60 |
  | audit-class-scan-2026-05-18-T50 | 20 | 2 / target 2 | closed | T54 |
  | audit-class-scan-2026-05-18-T61 | 20 | 2 / target 2 | closed | T63 |
  | fullbdg-f6-polar-3000x | 99 | 1.5 / target 2 | dormant (anko-contained) | — |
  | meta-critic-placement-2026-05-17 | 50 | 0 / target 2 | dormant (Observe, no anko trigger) | — |
- **Scheduler (scheduler_68.json)**: policy=JULIA_GPU_OK, all workloads allowed; window 1,172,356s left (~13.5 days); VRAM 12,973 MB free; foreign_julia=0. No constraint pressure.
- **Last judge verdict (T67)**: NOOP_DIRECTOR.
- **T67 drift signals (state.json line 1842-1856)**:
  - `manuscript_delta_zero: 1.0` → DRIFT_MANUSCRIPT_DELTA_ZERO (design-persistent per `feedback_manuscript_is_not_the_essence`).
  - `novel_claim_zero: 1.0` → DRIFT_NOVEL_CLAIM_ZERO (now 2 turns running T66+T67; T66 was hygiene, T67 was noop — both expected to score zero on novel-claim metric; not yet pathological).
  - `cost_inflation: 0.51` → below threshold (T67 noop was cheap at 5.86M raw / 861k eff).
  - **`AUDIT_DUE: patterns.yaml last audited at T0, gap=67`** → **REAL BUG, not false-positive as T67 director claimed**. This is the load-bearing finding of this turn — see §3 and §4 below.
  - drift_escalation: director_must_address.
- **§B2 elimination pass**: same as T67 (zero candidates from existing physics/meta investigations).
- **New for T68**: I'm spawning a tiny `fix-bug` investigation `audit-due-heuristic-bug-2026-05-18` to address the **real drift_signals.py bug** identified below, executed in **a single implementer_text turn** per the 3-second mechanical test.

## 2. Recent-turn audit (last 3 turns)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T65 | Document (yan-li-saito DORMANT-CLOSE) | PASS | Implementer_text bundled state.json closure + memory entry. Cost 8.5M raw / 1.31M eff. |
| T66 | Document (one-field state.json hygiene) | PASS | Implementer_text canonicalized one current_stage field; 1-turn sibling-class completion of T65. Cost 8.0M raw / 1.21M eff. |
| T67 | null (steady-state noop) | NOOP_DIRECTOR | Director report only; no subagent dispatch. Cost 5.86M raw / 861k eff. Claimed AUDIT_DUE was "false-positive" because patterns.yaml entries' `last_scanned` was today — but that claim was WRONG, see §3. |
| T68 (THIS) | Fix (collapsed Reproduce/Fix/Test/Document) | (TBD) | Implementer_text adds `turn:` field to 5 patterns.yaml audit_history entries. AUDIT_DUE advisory clears. |

## 3. Flow template recall

- **Template**: `fix-bug` (§F3), but collapsed to single turn per `feedback_mechanical_vs_investigation_threshold` ("3-second test: success criterion testable by `grep` or `compiles`? → just do it").
- **Role for stage Fix**: `implementer_text` (no julia / no GPU / no sympy — it's a yaml edit + a python verification re-run).
- **Why this stage now (the load-bearing decision change vs T67)**:
  - **T67 director was wrong about the AUDIT_DUE source**. T67 report §1 claimed: "AUDIT_DUE: patterns.yaml last audited at T0, gap=66 → false-positive (heuristic uses absolute T0 reference rather than max(last_scanned) from patterns.yaml entries; all 10 entries show last_scanned: '2026-05-18T09:00:00+09:00')."
  - **The actual source of the bug** (verified this turn by reading `.claude/scripts/drift_signals.py` lines 229-260): `_compute_audit_due_advisory` does NOT read individual patterns entries' `last_scanned`; it reads the TOP-LEVEL `audit_history` LIST and looks for `entry.get("turn")` on each row. The 5 audit_history entries in patterns.yaml lines 231-315 have `run_at:` timestamps but **NO `turn:` field whatsoever**. So `entry.get("turn") or 0` returns 0 for every row → `last_audit_turn = max(0, 0, 0, 0, 0) = 0` → `gap = current_turn - 0 = 67` → advisory permanently triggers. This is a **genuine bug, not a false positive heuristic**.
  - **Sibling-class check** (per `feedback_fix_the_class_not_the_instance`): I grepped `drift_signals.py` for similar `entry.get("turn")` patterns elsewhere — only 1 instance on line 255 (the buggy one) reads `turn` from a yaml-list entry whose schema doesn't define one. The other 5 `.get("turn", ...)` calls (lines 75, 124, 187, 221, 247, 343) all read from `state.json history` entries which DO have `turn:` fields by schema. No sibling instances elsewhere in the script. Class scope = 1 file, 1 line of code, plus the 5-entry yaml data fix.
  - **Why fix the DATA (patterns.yaml) and not the LOGIC (drift_signals.py)?** Per CLAUDE.md user pref "Simplicity first: clear, simple code" and minimal-scope fix-bug template:
    - Option A (data fix): add `turn: <N>` to each of the 5 audit_history entries. 5 yaml lines added. Heuristic intent preserved as-written.
    - Option B (logic fix): change drift_signals.py to parse `run_at:` timestamps, map to turns via state.json history search-by-timestamp. ~15-20 lines of new logic + timestamp parsing + state.json read coupling.
    - Option A wins on simplicity AND respects the heuristic contract (which was clearly designed assuming `turn:` field would be present per the `_compute_audit_due_advisory` docstring "compares last run's turn counter").
    - Going forward, the audit-class-scan flow §F6 Document stage should write `turn:` into new audit_history entries — this is captured in this turn's `next_falsifier_to_test_after` as an institutional rule.
- **Why this counts as a real dispatch (not over-engineered noop hygiene)**:
  - **D2 service-axis justification per §A5**: AUDIT_DUE noise is degrading director decision quality. T67 director explicitly mis-diagnosed it as false-positive (wasted reasoning) and the heuristic forces `drift_escalation: director_must_address` every turn (forcing director to address it in §5 each turn even when there's nothing to address). This is direct loop-infrastructure cost. Per §D2 the service-axis fix is justified because it "ends in a D1 verification ... blocked by performance" — the performance blocker is director attention being wasted on phantom advisories rather than scientific work.
  - **Sibling-class fix per `feedback_fix_the_class_not_the_instance`**: T67 director identified the wrong root cause; this turn corrects the diagnosis (1 source-line + 5 yaml-data-entries) and ensures the class doesn't recur (institutional rule for future audit-class-scan Document stages).
  - **3-second test passes** per `feedback_mechanical_vs_investigation_threshold`: one-sentence solution ("add `turn:` to each audit_history entry per its triggered_by reference"), testable by `python3 .claude/scripts/drift_signals.py` against state.json showing AUDIT_DUE no longer in advisories.
- **Why NOT continue noop**: T67's noop was justified because no candidate existed; T68 has a candidate (the bug T67 mis-diagnosed). Two-noops-in-a-row was T67's own forecast as acceptable but **only if no candidate surfaces** — this turn surfaces a real candidate.
- **Why NOT spawn audit-class-scan T68**: patterns.yaml entries' `last_scanned` was correctly refreshed at T62. Next real audit-class-scan cycle is ~T72 per the ~10-turn cadence rule. AUDIT_DUE advisory firing now is NOT because a real audit is due; it's because the heuristic bug makes it fire constantly. **Fixing the heuristic IS the right response, not running another premature audit cycle**.

## 4. Research grounding (§A6)

Per §A6: dispatch must cite ≥1 external reference. This turn's dispatch is a Fix-stage in a fix-bug flow (collapsed), so the grounding is mainly internal-pattern (loop's own prior lessons). External references:

1. **Memory `feedback_mechanical_vs_investigation_threshold.md`** (anko 2026-05-18): "If success criterion is `grep` or `compiles` → just do it." This turn's success criterion: `python3 drift_signals.py ... | jq` shows no AUDIT_DUE in advisories. Mechanical, collapses to one implementer turn.
2. **Memory `feedback_fix_the_class_not_the_instance.md`** (anko 2026-05-18): "The moment I learn about ONE instance of a class, I should grep widely for all siblings." Done in §3 above (1 sibling-call-site found in drift_signals.py; no extra instances elsewhere). Plus institutional-rule writeback (next audit-class-scan Document stage MUST include `turn:` in new audit_history rows).
3. **Memory `feedback_decision_style.md`** (anko 2026-04-24): "pick defaults and move". Default for mechanical bug fix in loop infrastructure: just patch it. Don't deliberate format options.
4. **Memory `feedback_cost_overhead_is_the_cost.md`** (anko 2026-05-15): "deliberation is more expensive than the work". Routing this fix through full fix-bug 6-stage flow (Research → Hypothesize → Reproduce → Fix → Test → Document) would cost ~6 turns × 1.2M-1.5M eff = ~8M eff for what is a 1-turn ~1M-eff edit. Collapse is mandatory.
5. **Loop architecture doc `runs/_loop/research/auto_research_architecture_2026_05_16.md`** (per director.md §B1): the loop's design assumes drift_signals are HIGH-SIGNAL — phantom advisories degrade the design intent. Fixing this preserves the architecture's calibration.
6. **Prior turn T67 §5 explicit forecast**: T67 director wrote: "T68 director considers (a) **mechanical fix to drift_signals.py AUDIT_DUE heuristic** (use max(patterns.yaml entries' last_scanned) not absolute T0). One-Python-file edit, ~1M eff. Per `feedback_mechanical_vs_investigation_threshold` this is mechanical, not investigation-grade." T67's diagnosis-direction was wrong (the fix is in patterns.yaml DATA not in drift_signals.py LOGIC) but the ACTION classification was correct: mechanical, 1 turn, ~1M eff.
7. **Anthropic context engineering essay (per director.md §G)**: "Write strategy for durable state". This fix preserves the drift_signals architecture's intent (per-turn advisories should be high-signal) so future-T74+ directors continue to trust the advisory channel.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D2 (service axis)** — loop-infrastructure drift_signals.py heuristic correctness. Justification per §A5: the noise was directly degrading director reasoning quality (T67 wasted ~400k eff tokens on mis-diagnosing this advisory as false-positive in §1 of its report). Fix removes the noise so future directors don't repeat the mis-diagnosis.
- **Tier ladder position**: new investigation `audit-due-heuristic-bug-2026-05-18` enters at tier 0 → target tier 2 (Tier 2 = "fix verified by regression test", here: `drift_signals.py` returns no AUDIT_DUE on post-fix patterns.yaml). Closes in 1 turn.
- **Manuscript NOT in scope** (per `feedback_manuscript_is_not_the_essence`).
- **DRIFT_NOVEL_CLAIM_ZERO at T67 (2nd consecutive)**: T68 will likely also score novel_claim_zero=1.0 (a mechanical infrastructure fix is not a novel scientific claim). This will hit 3 consecutive. Per T67 §5 forecast: "T69+ director considers spawning a meta-investigation on the novel_claim_zero metric: is the metric calibrated correctly for a steady-state phase (hygiene turns + noops will all be novel_claim_zero=1.0; this is expected and not a pathology)?" — defer that meta-investigation to T69+ if the 3-consecutive trigger fires; for T68 it's a sibling concern not yet load-bearing.
- **Loop steady-state diagnostic**:
  - Cost trending stable post-closure phase: T64-T67 in the 5-8M raw / 0.86-1.31M eff range. T68 forecast ~6-8M raw / ~1.0-1.2M eff (implementer_text on yaml fix + verification).
  - Verdict streak post-T53: 13/13 turns operationally clean (0 FAIL_OPERATIONAL). T68 is structured to preserve this streak.
- **Recommended T69+ trajectory** (informational):
  - If anko surfaces a new physics investigation in seed.md by T69, advance it at Research stage.
  - If anko remains silent through T69, consider:
    (a) meta-investigation on `novel_claim_zero` metric calibration (3-consecutive trigger expected to fire at T68 → T69 should address it OR formally suppress the advisory for hygiene/noop turns).
    (b) low-commitment survey-template on a yet-unstudied corner of the framework — requires anko ratification.
  - DO NOT noop two turns in a row past T68 — escalates per the "3-noops warrants meta or halt" rule from T67.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "audit-due-heuristic-bug-2026-05-18",
  "stage_advancing_to": "Fix",
  "subagent_type": "implementer",
  "rationale": "T67 director mis-diagnosed AUDIT_DUE drift advisory as false-positive arising from a `max(last_scanned)` heuristic, but reading `.claude/scripts/drift_signals.py` lines 229-260 this turn shows the heuristic actually reads `audit_history` list's `turn:` field per entry. patterns.yaml lines 231-315 audit_history entries have `run_at:` but NO `turn:` field, so `entry.get('turn') or 0` returns 0 for every row, last_audit_turn=0, gap=current_turn permanently. Real bug. Per `feedback_mechanical_vs_investigation_threshold` 3-second test: one-sentence fix (add `turn:` to each of 5 entries per the turn-number referenced in each `triggered_by:` field), testable by `python3 drift_signals.py` returning no AUDIT_DUE. Collapse fix-bug Reproduce/Fix/Test/Document into one implementer_text turn. Sibling-class scan complete (1 buggy `entry.get('turn')` call site in drift_signals.py; no other yaml-list-with-no-turn-schema reads). Per `feedback_fix_the_class_not_the_instance`: also append institutional rule to patterns.yaml comment header so future audit-class-scan Document stages include `turn:`. D2 service-axis justified per §A5: drift advisory noise was directly degrading director reasoning quality (T67 wasted ~400k eff on mis-diagnosis).",
  "brief": "ROLE: implementer_text (no julia, no GPU). TASK: 1-turn collapsed fix-bug for AUDIT_DUE heuristic bug.\n\nSTEP 1 — Read `.claude/scripts/drift_signals.py` lines 229-260 to confirm the heuristic reads `entry.get('turn') or 0` from each patterns.yaml audit_history entry.\n\nSTEP 2 — Read `runs/_loop/patterns.yaml` lines 231-315 to confirm 5 audit_history entries lack `turn:` field (verified by this director report).\n\nSTEP 3 — Edit `runs/_loop/patterns.yaml`: add `turn:` field as the FIRST key of each existing audit_history entry, with values per the triggered_by/notes content:\n  - entry 1 (run_at 2026-05-18T01:50:00 — pre-loop manual): `turn: 0` (pre-flow audit, no in-loop turn associated)\n  - entry 2 (run_at 2026-05-18T05:00:00 — T48 researcher): `turn: 48`\n  - entry 3 (run_at 2026-05-18T12:00:00 — T50 audit-class-scan, applied at T51): `turn: 54` (use cycle's Document close turn per T50 cycle's closing_note 'applied at T51' and audit-class-scan-2026-05-18-T50.stages_at_turn.Document=[54,...])\n  - entry 4 (run_at 2026-05-18T13:00:00 — T52 critic L3, T54 applied): `turn: 54`\n  - entry 5 (run_at 2026-05-18T09:00:00 — T61/T62/T63 cycle): `turn: 63` (per audit-class-scan-2026-05-18-T61.stages_at_turn.Document=[63,...])\n\nUse Edit tool one entry at a time OR a single block-replace if all 5 fit cleanly. Preserve all existing fields (run_at, triggered_by, patterns_scanned, findings_count, notes).\n\nSTEP 4 — Append a comment to patterns.yaml header (the audit_history block's existing comment around line 228-231) noting: 'Each entry MUST include `turn: <N>` — `_compute_audit_due_advisory` in drift_signals.py reads this field to compute the audit gap. Document-stage of audit-class-scan flow §F6 must write this.' Place inside the existing comment block, not as a new top-level comment.\n\nSTEP 5 — Verify the fix:\n  a) `cd /home/suzume/workspace/BEC-simulation && python3 -c \"import yaml; d=yaml.safe_load(open('runs/_loop/patterns.yaml').read()); turns=[e.get('turn') for e in d['audit_history']]; assert all(t is not None for t in turns), f'missing turn in some entries: {turns}'; assert max(turns) >= 60, f'max turn {max(turns)} seems too low'; print('OK_audit_history_turns:', turns)\"` → expect `OK_audit_history_turns: [0, 48, 54, 54, 63]`\n  b) `cd /home/suzume/workspace/BEC-simulation && python3 .claude/scripts/drift_signals.py 2>&1 | head -40` — expect output that does NOT contain `AUDIT_DUE` substring (gap = 68 - 63 = 5, below the ≥10 threshold).\n\nSTEP 6 — Update state.json:\n  - Append new investigation `audit-due-heuristic-bug-2026-05-18` entry to `investigations` dict + add id to `investigations_index` list. Use this skeleton:\n    {\n      \"id\": \"audit-due-heuristic-bug-2026-05-18\",\n      \"title\": \"AUDIT_DUE drift heuristic constantly fires because patterns.yaml audit_history entries lack `turn:` field\",\n      \"hypothesis\": \"_compute_audit_due_advisory in drift_signals.py line 255 reads entry.get('turn') or 0 from each patterns.yaml audit_history entry; entries have only run_at timestamp, no turn field; so last_audit_turn=0 always, gap=current_turn always, advisory fires permanently. Adding turn: <N> to each existing entry (per triggered_by ref) restores correct gap computation.\",\n      \"flow_template\": \"fix-bug\",\n      \"current_stage\": \"closed\",\n      \"stages_done\": [\"Reproduce\", \"Fix\", \"Test\", \"Document\"],\n      \"stages_at_turn\": {\"Reproduce\": [68, \"director T68 §3 read of drift_signals.py + patterns.yaml\"], \"Fix\": [68, \"implementer_text added turn: field to 5 audit_history entries\"], \"Test\": [68, \"python3 drift_signals.py confirms no AUDIT_DUE in advisories\"], \"Document\": [68, \"institutional rule written into patterns.yaml audit_history comment header\"]},\n      \"falsifiers\": [{\"id\": \"audit-due-cleared\", \"description\": \"drift_signals.py output must not contain AUDIT_DUE after fix\", \"tested_at_turn\": 68, \"result\": \"<pending — implementer fills in>\"}, {\"id\": \"all-entries-have-turn-field\", \"description\": \"all 5 audit_history entries must have a non-null turn field\", \"tested_at_turn\": 68, \"result\": \"<pending>\"}],\n      \"tier_current\": 2,\n      \"tier_target\": 2,\n      \"next_stage\": null,\n      \"next_stage_action\": null,\n      \"blocked_on\": null,\n      \"priority\": 4,\n      \"kind\": \"physics\",\n      \"closing_note\": \"Mechanical fix-bug collapsed to 1 turn per `feedback_mechanical_vs_investigation_threshold`. Class-scope: 1 buggy entry.get('turn') call in drift_signals.py + 5 audit_history yaml entries lacking turn:. Sibling-class scan: no other yaml-list reads with optional-but-load-bearing turn:. Institutional rule appended to patterns.yaml audit_history comment header so future audit-class-scan Document stages include turn:. D2 service-axis: removes phantom drift advisory that wasted T67 director ~400k eff on mis-diagnosis.\"\n    }\n  - Set state.json `active_investigation_id` to `\"audit-due-heuristic-bug-2026-05-18\"`.\n  - DO NOT touch other investigations.\n\nSTEP 7 — Produce sim/turn_68.md report with §1 What I did, §2 Files touched, §3 Verification command output (steps 5a/5b), §4 Metrics (audit_history_turns_added: 5, audit_due_advisory_clears: true|false based on step 5b output, drift_signals_other_advisories_unchanged: true|false), §5 Closing.\n\nGUARDRAIL: NO git commit, NO branch creation, NO touching src/, NO touching `.claude/scripts/drift_signals.py` (the fix is in DATA not LOGIC). The patterns.yaml is the only file mutated outside state.json and sim/turn_68.md.",
  "observable_manifest": {
    "required": ["audit_history_turns_added", "audit_due_advisory_clears", "drift_signals_other_advisories_unchanged"],
    "optional": ["yaml_entry_count_before_after"],
    "precondition_check": "cd /home/suzume/workspace/BEC-simulation && python3 -c \"import yaml; p='runs/_loop/patterns.yaml'; d=yaml.safe_load(open(p).read()); ah=d.get('audit_history') or []; assert len(ah)==5, f'expected 5 audit_history entries, got {len(ah)}'; pre_turns=[e.get('turn') for e in ah]; assert all(t is None for t in pre_turns), f'pre-fix expected all None, got {pre_turns} — fix may already be applied OR entries differ from director assumption'; print(f'OK_T68_precondition: {len(ah)} audit_history entries, all turn:None as expected pre-fix')\""
  },
  "success_criteria": [
    {
      "id": "patterns_yaml_audit_history_has_turn_field_on_all_entries",
      "metric": "audit_history_turns_added",
      "operator": "==",
      "value": 5,
      "tolerance": null,
      "rationale": "All 5 existing audit_history entries must have a `turn:` field after the fix. Count of additions = 5."
    },
    {
      "id": "audit_due_advisory_no_longer_fires",
      "metric": "audit_due_advisory_clears",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "After fix, running drift_signals.py against current state.json must NOT emit AUDIT_DUE advisory (gap = 68 - 63 = 5 < 10 threshold). This is the direct success signal of the bug fix."
    },
    {
      "id": "other_drift_advisories_unchanged",
      "metric": "drift_signals_other_advisories_unchanged",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "DRIFT_MANUSCRIPT_DELTA_ZERO + DRIFT_NOVEL_CLAIM_ZERO are independent signals; the fix MUST NOT alter them (would indicate over-scoped edit)."
    },
    {
      "id": "no_src_modification",
      "metric": "src_files_modified_count",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Fix is in DATA (patterns.yaml) not LOGIC (drift_signals.py). Modifying src/ would be over-scope."
    },
    {
      "id": "no_drift_signals_py_modification",
      "metric": "claude_scripts_drift_signals_py_modified",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "Fix is in DATA (patterns.yaml) not LOGIC. Touching drift_signals.py would be over-scope and adopt Option B when Option A was selected per CLAUDE.md simplicity-first."
    },
    {
      "id": "investigation_recorded_in_state",
      "metric": "audit_due_heuristic_bug_2026_05_18_in_state_investigations",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "The fix-bug investigation must be recorded in state.json for institutional memory and for the closing_note text to be retrievable by future directors."
    },
    {
      "id": "investigation_closed_same_turn",
      "metric": "audit_due_heuristic_bug_2026_05_18_current_stage",
      "operator": "==",
      "value": "closed",
      "tolerance": null,
      "rationale": "Per 3-second mechanical test, the investigation closes in the same turn it's spawned. tier_current=tier_target=2."
    }
  ],
  "failure_modes": [
    {
      "if": "precondition_check fails (audit_history entries already have turn: field OR entry count != 5)",
      "category": "data_gap",
      "next_action": "T69 director re-reads patterns.yaml; if turn: fields already present, treat T68 as no-op-but-close (still spawn the investigation in state.json with falsifier marked CONFIRMED-NO-OP), then re-run drift_signals.py to verify AUDIT_DUE is gone; if entry count differs, T69 director re-reads patterns.yaml and adjusts the turn:value mapping accordingly."
    },
    {
      "if": "drift_signals.py STILL emits AUDIT_DUE after fix (success_criteria.audit_due_advisory_clears=false)",
      "category": "framework_error",
      "next_action": "T69 director investigates: does the heuristic have a SECOND code path also emitting AUDIT_DUE (sibling-class miss)? Re-grep drift_signals.py for 'AUDIT_DUE' string. If only one emit site found, debug locally with `python3 -c 'import sys; sys.path.insert(0, \".claude/scripts\"); from drift_signals import _compute_audit_due_advisory; ...'` to print intermediate values. May require Option B (logic fix) escalation."
    },
    {
      "if": "implementer touches src/ or drift_signals.py (over-scope)",
      "category": "operational",
      "next_action": "T69 director reverts those changes (git checkout) and re-dispatches the data-only fix with explicit prohibition restated. May indicate brief was unclear; tighten brief on next mechanical-fix dispatch."
    },
    {
      "if": "implementer fabricates a turn: value that doesn't match the audit_history entry's actual closing turn (e.g., uses run_at timestamp date directly instead of looking up the actual close turn from state.json)",
      "category": "operational",
      "next_action": "T69 director verifies by cross-referencing each audit_history entry's `triggered_by:` field against state.json investigations stages_at_turn map; corrects any wrong turns. The director-provided mapping in the brief (0,48,54,54,63) is the authoritative source."
    },
    {
      "if": "yaml syntax error introduced (file no longer parses)",
      "category": "operational",
      "next_action": "T69 director runs `python3 -c \"import yaml; yaml.safe_load(open('runs/_loop/patterns.yaml').read())\"` to confirm parse failure, then either reverts file or re-applies via cleaner Edit calls (one entry at a time, smaller diffs)."
    },
    {
      "if": "DRIFT_NOVEL_CLAIM_ZERO now hits 3-consecutive at T68 (T66+T67+T68 all novel_claim_zero=1.0)",
      "category": "framework_error",
      "next_action": "T69 director considers spawning meta-investigation `novel-claim-zero-metric-calibration-2026-05-18` to either (a) suppress novel_claim_zero for hygiene/mechanical-fix/noop turn types, or (b) accept the signal as legitimate and treat 3-consecutive as a real prompt to surface a new physics investigation (escalate to anko). Likely outcome (a): the metric over-counts hygiene phases. Per T67 §5 forecast this was already on the radar."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 2000000
  },
  "budget": {
    "expected_cost_eff": 1100000,
    "expected_wall_time_sec": 180,
    "split_by_subtask": {
      "implementer_read_drift_signals": 100000,
      "implementer_read_patterns_yaml": 100000,
      "implementer_5_yaml_edits": 300000,
      "implementer_verify_python_calls": 200000,
      "implementer_state_json_update": 200000,
      "implementer_sim_md_report": 200000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "closed (fix-bug collapsed; audit-due-heuristic-bug-2026-05-18 closes same-turn at tier 2)",
    "if_success_tier_becomes": 2,
    "if_refuted_advance_to_stage": "Reproduce (escalate to Option B logic fix in drift_signals.py if data fix doesn't clear advisory)",
    "if_refuted_tier_becomes": 0,
    "if_inconclusive_advance_to_stage": "Test (re-run verification with more diagnostic output; one-turn retry budget then escalate)",
    "if_inconclusive_tier_becomes": 1,
    "next_falsifier_to_test_after": "Institutional rule: future audit-class-scan Document stages (§F6) MUST include `turn: <N>` when appending a new audit_history row. Patterns.yaml comment header to be updated accordingly. No further falsifier for this investigation (closed same-turn). If novel_claim_zero hits 3-consecutive at T68 the next director should consider spawning a calibration meta-investigation."
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read state.json + scheduler.json + seed.md this turn (state.json multi-range read covering active_investigation_id line 1877, all investigation current_stage/priority/blocked_on fields, history T28-T67, drift signals T66-T67; scheduler_68.json full read confirms JULIA_GPU_OK + 13.5 days window; seed.md full read confirms NO new anko-prioritized investigation surfaced post-T67).
- [x] Read ≥1 memory file related to active investigation (new investigation; read 3 anko-feedback memory files: feedback_mechanical_vs_investigation_threshold, feedback_fix_the_class_not_the_instance, feedback_cost_overhead_is_the_cost — these together motivate the 3-second-test 1-turn fix-bug collapsed dispatch).
- [x] investigation_id valid in state.investigations (new id `audit-due-heuristic-bug-2026-05-18` spawning this turn; precondition check ensures patterns.yaml entries are in expected pre-fix state).
- [x] stage_advancing_to is the next stage per flow template (fix-bug §F3 collapsed to single Fix stage per mechanical-fix-threshold rule).
- [x] subagent_type matches role_per_stage[stage] (implementer for Fix; implementer_text variant since fix is yaml + python verify, no julia/GPU).
- [x] success_criteria are machine-evaluable: count of `turn:` fields added (5), AUDIT_DUE substring presence in drift_signals.py output (false), other advisories unchanged boolean, src/drift_signals.py modification flags, state.json investigation presence and stage — all directly checkable by python/grep.
- [x] failure_modes cover 6 most likely failures: precondition mismatch (data gap), bug not cleared (framework error), over-scope edits (operational), wrong turn:value mapping (operational), yaml syntax break (operational), DRIFT_NOVEL_CLAIM_ZERO 3-consecutive escalation (framework error).
- [x] observable_manifest precondition_check is concrete: python yaml-load + assertion all 5 entries have turn:None pre-fix.
- [x] budget fits within scheduler window_seconds_left (1.1M eff vs ample 13.5 day window; one of the cheaper turns).
- [x] §A6 research-first citation present (7 references — 4 anko-feedback memory files + loop architecture doc + T67 §5 forecast + Anthropic Write strategy).
- [x] §A5 D1/D2/D3 articulated: T68 advances **D2 (service axis)** with explicit justification per §A5 ("requires explicit justification ending in a D1 verification or D3 derivation blocked by performance" — phantom advisory was directly degrading director reasoning quality, blocking future D1/D3 work by polluting the advisory channel). Manuscript NOT primary.
- [x] T67's wrong diagnosis of AUDIT_DUE explicitly corrected in §3 (sibling-class fix per `feedback_fix_the_class_not_the_instance`: when prior turn's diagnosis is wrong, this turn's first act is to re-verify the source code, not to perpetuate the wrong claim).
