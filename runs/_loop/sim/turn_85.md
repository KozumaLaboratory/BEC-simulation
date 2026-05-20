---
turn: 85
subagent: implementer_text
directive_action: verify_and_close
directive_label: edh-matsui-document-verify-T85-tier-3-0-terminal-closure-lightweight
investigation_id: edh-eu151-vortex-vs-matsui-science-2026
stage: Document-verify
verdict: FAIL_CHECK6
---

# Turn 85 — Document-verify terminal closure of edh-eu151-matsui (Tier 2.75 → 3.0)

## §1 Phase 1: Artifact verification checks (7 mechanical)

Precondition check executed first:

```
$ cd /home/suzume/workspace/BEC-simulation && test -f runs/_loop/director/turn_84.md && test -f runs/_loop/sim/turn_84.md && test -f runs/_loop/judge/turn_84.json && test -f runs/_loop/state.json && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/edh_matsui_baseline_2026_05_18.md && test -f runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md && test -f runs/_loop/by_tag/edh-eu151-matsui-science-2026.md && jq empty runs/_loop/state.json && jq -e '.investigations."edh-eu151-vortex-vs-matsui-science-2026".tier_current == 2.75' runs/_loop/state.json > /dev/null && echo OK_T85_precondition...
OK_T85_precondition: T84_artifacts_present + state_json_parses + EdH_tier_2_75_confirmed
```

| # | Check | Command | Expected | Actual | Result |
|---|---|---|---|---|---|
| 1 | state.json jq parse | `jq empty runs/_loop/state.json && echo OK_state_json_parses` | stdout contains `OK_state_json_parses` | `OK_state_json_parses` | **PASS** |
| 2 | EdH block T84-patched fields | `jq '.investigations."edh-eu151-vortex-vs-matsui-science-2026" \| {tier_current, last_turn, last_stage, last_verdict, last_critic_turn, errata_pending, errata_resolved_length: (.errata_resolved \| length), closing_note_length: (.closing_note \| length)}'` | tier_current=2.75, last_turn=84, last_stage="Document", last_verdict="CORROBORATE_WITH_ERRATA", last_critic_turn=83, errata_pending=0, errata_resolved_length=4, closing_note_length > 200 | tier_current=2.75, last_turn=84, last_stage="Document", last_verdict="CORROBORATE_WITH_ERRATA", last_critic_turn=83, errata_pending=0, errata_resolved_length=4, closing_note_length=1063 | **PASS** |
| 3 | Memory file: 11 required sections present | grep all 11 section names | each section returns count >= 1 | Status=1, "Hypothesis verified"=1, "Falsifier verdicts"=1, "Sweep parameters"=1, "Critical convention finding"=1, "Verification chain"=1, "Errata"=1, "Deferred follow-ups"=1, "Citations"=1, "Related production code"=1, "Related memory"=1 (total 11 sections found by `grep -c '^## '` = 11) | **PASS** |
| 4 | Memory file: class-level convention finding | `grep -c 'INTENSIVE per-atom' edh_matsui_baseline_2026_05_18.md` | count >= 2 | count = 4 | **PASS** |
| 5 | Memory file: 4 errata | `grep -cE '\*\*\[E[1-4]( LOAD-BEARING\| ADVISORY)?\]'` | count = 4 | count = 4 | **PASS** |
| 6 | 4 by_tag indices have T84 entry | `grep -c 'T84'` on each file (working tree) | each >= 1 | edh-eu151-matsui-science-2026.md=1 (PASS); edh-eu151.md=0 (FAIL); matsui-science-2026.md=0 (FAIL); matsui-2026.md=0 (FAIL) | **FAIL** |
| 7 | Status narrative has T83+T84 entries | `grep -cE '^### T8[34]' status/edh-eu151-vortex-vs-matsui-science-2026.md` | count >= 2 | count = 3 (T83 × 1, T84 × 2) | **PASS** |

**PHASE 1 RESULT: 6/7 checks PASS. CHECK 6 FAILS.**

Per directive §Phase 1: "If any FAILS, STOP and report — do NOT proceed to Phase 2/3."

**Stopping here. Phase 2 and Phase 3 NOT executed.**

---

## §2 Phase 2: state.json terminal closure patch

NOT EXECUTED — Phase 1 Check 6 failed. Per directive, do not proceed.

## §3 Phase 3: status narrative append

NOT EXECUTED — Phase 1 Check 6 failed. Per directive, do not proceed.

---

## Check 6 failure analysis (for director routing)

The 3 sibling by_tag files (`edh-eu151.md`, `matsui-science-2026.md`, `matsui-2026.md`) have working-tree content that predates T84. The T84 implementer did edit these files, and the edits ARE present in git's staging index (`git show :<path>` confirms T84 rows exist in all 3). However, the on-disk working tree files do not contain the T84 content.

Git status for these files:
```
AM runs/_loop/by_tag/edh-eu151.md
AM runs/_loop/by_tag/matsui-2026.md
AM runs/_loop/by_tag/matsui-science-2026.md
```

`AM` = Added to index (staged), but working tree has different (older) content. The T85 Check 6 grep runs against the working tree and therefore returns 0 for these 3 files.

The primary file `edh-eu151-matsui-science-2026.md` has status `A` (added in index, working tree matches) — grep returns 1, PASS.

Staged (index) content for the 3 failing files — these are correct:
- `edh-eu151.md` index: Total=3, T84 row present
- `matsui-science-2026.md` index: Total=3, T84 row present
- `matsui-2026.md` index: Total=2, T84 row present

The T84 content failure is a working-tree/index divergence, not a missing edit. The T84 judge PASS was valid because the judge reads the artifacts the implementer produced (staged edits), not the working tree state post-edit.

**Recommended T86 repair**: a minimal implementer_text repair turn that writes the 3 sibling by_tag working-tree files to match their git index content. Alternatively, the orchestrator's commit step for T84 artifacts would resolve the divergence if the staged files are committed. Check whether `git stash` or `git checkout -- <path>` (from index) would restore the correct working-tree state before proceeding to Phase 2/3.

The correct working-tree content for the 3 files (from git index):

`edh-eu151.md`:
```
# tag `edh-eu151` — turn history

Total: 3

- **T70** [PASS] `edh-eu151-vortex-vs-matsui-spawn-T70`
- **T71** [RESEARCHER_ONLY] `matsui-science-2026-pdf-extract`
- **T84** [PASS] `edh-matsui-document-T84-tier-2-75-corroborate-with-errata-closure-path`
```

`matsui-science-2026.md`:
```
# tag `matsui-science-2026` — turn history

Total: 3

- **T71** [RESEARCHER_ONLY] `matsui-science-2026-pdf-extract`
- **T81** [PASS] `edh-matsui-execute-T81-r2-gpu-wrapper-script-workaround`
- **T84** [PASS] `edh-matsui-document-T84-tier-2-75-corroborate-with-errata-closure-path`
```

`matsui-2026.md`:
```
# tag `matsui-2026` — turn history

Total: 2

- **T70** [PASS] `edh-eu151-vortex-vs-matsui-spawn-T70`
- **T84** [PASS] `edh-matsui-document-T84-tier-2-75-corroborate-with-errata-closure-path`
```

---

## 4. Metrics

```json
{
  "experiment_kind": "text_only",
  "workload_class": "implementer_text",
  "src_files_modified": 0,
  "new_analysis_scripts_written": 0,
  "investigation_id": "edh-eu151-vortex-vs-matsui-science-2026",
  "stage_advancing_to": "closed",
  "flow_template": "verify-claim",
  "phase_1_checks_total": 7,
  "phase_1_checks_passed": 6,
  "state_json_jq_parses": true,
  "state_json_tier_advanced_to_3": false,
  "state_json_current_stage_is_closed": false,
  "memory_file_11_sections_present": true,
  "memory_file_class_finding_present": true,
  "memory_file_4_errata_present": true,
  "by_tag_indices_4_have_t84": false,
  "status_narrative_t83_t84_present": true,
  "status_narrative_t85_appended": false,
  "investigation_tier_advanced": false,
  "final_tier": 2.75,
  "investigation_closed": false,
  "closing_note_extended": false,
  "new_memory_files_created": 0,
  "by_tag_indices_modified": 0,
  "manuscript_edited": false,
  "src_edited": false,
  "julia_executed": false,
  "check_6_failure_detail": "3 of 4 sibling by_tag files (edh-eu151.md, matsui-science-2026.md, matsui-2026.md) have working-tree content that predates T84; T84 edits exist in git index (AM status) but not on disk. Primary file edh-eu151-matsui-science-2026.md: working tree matches index (PASS). Repair: restore working tree from index for 3 files.",
  "tokens_used": {
    "theorist": null,
    "researcher": null,
    "implementer": null,
    "critic": null,
    "orchestrator": 10954340,
    "total": 10954340,
    "effective_full_rate": 1664728,
    "breakdown": {
      "input_fresh": 10100,
      "cache_creation": 393016,
      "cache_read": 10529135,
      "output": 22089
    },
    "n_messages": 88,
    "n_message_starts": 88
  }
}
```

## §5 Self-review

- [ ] All 7 Phase 1 checks PASS? **NO — Check 6 FAIL (3/4 sibling by_tag files missing T84 in working tree)**
- [ ] state.json post-Edit jq parse PASS? N/A — Phase 2 not executed
- [ ] tier_current = 3.0 in state.json post-Edit? N/A — Phase 2 not executed
- [ ] current_stage = 'closed' in state.json post-Edit? N/A — Phase 2 not executed
- [x] No new memory file created? Yes
- [x] No by_tag index modified? Yes (0 modifications)
- [x] No src/ modified? Yes
- [x] No julia executed? Yes
- [x] No manuscript edited? Yes
- [x] Cost within 1.2M cap? Yes (re-reads only, no executions)

**Overall verdict: FAIL at Phase 1 Check 6. Director must route T86 repair to restore 3 sibling by_tag working-tree files from git index, then re-run T85 Document-verify protocol.**
