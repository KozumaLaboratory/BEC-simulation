import json

with open('/home/suzume/workspace/BEC-simulation/runs/_loop/state.json', 'r') as f:
    state = json.load(f)

# Check idempotence for audit-class-scan entry
if 'audit-class-scan-2026-05-18-T50' in state['investigations']:
    print("SKIP: audit-class-scan-2026-05-18-T50 already exists")
else:
    state['investigations']['audit-class-scan-2026-05-18-T50'] = {
        "id": "audit-class-scan-2026-05-18-T50",
        "title": "Audit-class-scan T50 cycle -- periodic anti-pattern catalog sweep (F6 level-2/3)",
        "flow_template": "audit-class-scan",
        "current_stage": "closed",
        "stages_done": ["Observe", "Findings", "Triage", "L3_critic_audit", "Document"],
        "stages_at_turn": {
            "Observe": [50, "researcher 9-pattern sweep; 5 WHAT-comments + 126 1e-30 instances; 2 L3 proposals queued"],
            "Findings": [50, "folded into Observe; mechanical-fix-eligible vs investigation-eligible triage in director T51"],
            "Triage": [51, "implementer applied mechanical topology.jl cleanup; patterns.yaml updated with proposed_classes"],
            "L3_critic_audit": [52, "critic produced LP-1 REJECT + LP-2 ACCEPT verdicts per F6 4-question audit"],
            "Document": [54, "applied LP-1/LP-2 verdicts to patterns.yaml; audit_history row appended; investigation closed"]
        },
        "tier_current": 2,
        "tier_target": 2,
        "next_stage": None,
        "next_stage_action": None,
        "blocked_on": None,
        "priority": 20,
        "kind": "physics",
        "closing_note": "Cycle closed cleanly. Loop-infrastructure value: (a) topology.jl cleanup mechanical fix at T51; (b) 1 new active pattern (topology-function-WHAT-comment-pattern) for future audits; (c) 1 rejected pattern preserved in institutional memory; (d) revealed the judge.py _OPS_in_ bug as a side-effect of L3 audit gating. Next audit-class-scan cycle is due ~T62 per ~10-turn cadence."
    }
    print("ADDED: audit-class-scan-2026-05-18-T50")

if 'audit-class-scan-2026-05-18-T50' not in state['investigations_index']:
    state['investigations_index'].append('audit-class-scan-2026-05-18-T50')
    print("ADDED to investigations_index: audit-class-scan-2026-05-18-T50")

# Check idempotence for judge-in-operator-bug entry
if 'judge-in-operator-bug-2026-05-18' in state['investigations']:
    print("SKIP: judge-in-operator-bug-2026-05-18 already exists")
else:
    state['investigations']['judge-in-operator-bug-2026-05-18'] = {
        "id": "judge-in-operator-bug-2026-05-18",
        "title": "judge.py _OPS_in_ in-operator hard-coded as 2-element numeric range (list-membership intent silently mis-evaluated)",
        "hypothesis": "judge.py line 97 _OPS_in_ lambda treats in as 2-element numeric range; >2-element or non-numeric list values fall into else-False and silently fail. 33 occurrences across 14 director-turn files affected.",
        "flow_template": "fix-bug",
        "current_stage": "closed",
        "stages_done": ["Research", "Hypothesize", "Reproduce", "Fix", "Test", "Document"],
        "stages_at_turn": {
            "Research": [53, "director pre-flight grep + judge.py line-97 read; bug pin-pointed in director report"],
            "Hypothesize": [53, "director report + critic-correctness verification"],
            "Reproduce": [53, "unittest pre-fix assertFalse passes -- bug reproduced"],
            "Fix": [53, "_in_op helper added; isinstance(x, bool) guard + 2-element-numeric path preserved"],
            "Test": [53, "21 post-fix assertions pass; T52 re-judged PASS; sibling audit 33 occurrences"],
            "Document": [54, "memory entry created; state.json closure recorded; T53 sibling audit table preserved"]
        },
        "falsifiers": [
            {
                "id": "t52-rejudge-three-failed-now-pass",
                "description": "3 T52 criteria originally failed must PASS when re-judged against fixed judge.py",
                "tested_at_turn": 53,
                "result": "CONFIRMED -- T52 verdict flipped FAIL_OPERATIONAL -> PASS (13/13 criteria pass)"
            },
            {
                "id": "unittest-prevents-regression",
                "description": "unittest file .claude/scripts/tests/test_judge_in_operator.py prevents future regression",
                "tested_at_turn": 53,
                "result": "CONFIRMED -- 21 post-fix assertions cover string/boolean/range/edge cases"
            }
        ],
        "tier_current": 2,
        "tier_target": 2,
        "next_stage": None,
        "next_stage_action": None,
        "blocked_on": None,
        "priority": 2,
        "kind": "physics",
        "closing_note": "Bug class: judge.py operator semantics. 1 T53 commit fixed all sibling instances. 12 historical turns flagged for anko awareness (T28/T33/T35/T38/T41-T48). Memory entry at judge_in_operator_bug_2026_05_18.md preserves the lesson."
    }
    print("ADDED: judge-in-operator-bug-2026-05-18")

if 'judge-in-operator-bug-2026-05-18' not in state['investigations_index']:
    state['investigations_index'].append('judge-in-operator-bug-2026-05-18')
    print("ADDED to investigations_index: judge-in-operator-bug-2026-05-18")

# Update meta-stage-routing-2026-05-18 confounder_advisory
if 'meta-stage-routing-2026-05-18' in state['investigations']:
    inv = state['investigations']['meta-stage-routing-2026-05-18']
    if 'confounder_advisory' not in inv:
        inv['confounder_advisory'] = {
            "added_at_turn": 54,
            "text": "T53 evidence partially refutes the original hypothesis. The 3+ FAIL/INCONCLUSIVE streak in last 4 turns up to T44 was driven by the judge.py _OPS_in_ operator bug (T28/T33/T35/T38/T41-T48 list-membership criteria silently mis-evaluated; see judge-in-operator-bug-2026-05-18). The hypothesis that contract design is wrong or observable_manifest precondition is missing or stage role is mis-assigned or success_criteria are not discriminating is NOT the primary cause for those turns. Refined falsifier: if 3+ FAIL/INCONCLUSIVE occur in any 4-turn window POST-T53, meta-stage-routing hypothesis remains testable. Otherwise, mark REFUTED-BY-CONFOUNDER at T58+. Defer Hypothesize stage advance."
        }
        inv['next_stage_action'] = "Hold at Observe through T57. If post-T53 FAIL/INCONCLUSIVE rate stays below 1-per-4-turns, mark REFUTED-BY-CONFOUNDER and close. Else, theorist Hypothesize per original plan with refined baseline excluding judge-bug-corrupted turns."
        print("UPDATED: meta-stage-routing-2026-05-18 confounder_advisory added")
    else:
        print("SKIP: meta-stage-routing-2026-05-18 confounder_advisory already exists")
else:
    print("WARN: meta-stage-routing-2026-05-18 not found in investigations")

with open('/home/suzume/workspace/BEC-simulation/runs/_loop/state.json', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')

print("state.json written successfully")
