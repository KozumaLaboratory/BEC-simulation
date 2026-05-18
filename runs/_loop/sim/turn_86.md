---
turn: 86
subagent: implementer_text
directive_action: verify_and_close
directive_label: edh-matsui-document-verify-T86-tier-3-0-retry-by-tag-restore
investigation_id: edh-eu151-vortex-vs-matsui-science-2026
stage: Document-verify
verdict: PASS
---

# Turn 86 — Document-verify retry of edh-eu151-matsui (Tier 2.75 → 3.0)

## §1 Phase 0: by_tag index restoration (3 Writes)

Precondition check passed before any writes:
```
OK_T86_precondition: T85_artifacts_present + state_parses + tier_still_2_75 + 4_by_tag_files_exist
```

Content written as specified by director §6 brief (T85 verbatim corrective content + T86 row appended).

| File | Lines written | T84 grep count | T86 grep count | Result |
|---|---|---|---|---|
| `runs/_loop/by_tag/edh-eu151.md` | 9 | 1 | 1 | PASS |
| `runs/_loop/by_tag/matsui-science-2026.md` | 9 | 1 | 1 | PASS |
| `runs/_loop/by_tag/matsui-2026.md` | 8 | 1 | 1 | PASS |

## §2 Phase 1: Artifact verification checks (7/7)

| # | Check | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | state.json jq parse | stdout contains `OK_state_json_parses` | `OK_state_json_parses` | **PASS** |
| 2 | EdH block T84-patched fields | tier_current=2.75, last_turn=84, errata_resolved_length=4, closing_note_length>200 | tier_current=2.75, last_turn=84, last_stage="Document", last_verdict="CORROBORATE_WITH_ERRATA", last_critic_turn=83, errata_pending=0, errata_resolved_length=4, closing_note_length=1063 | **PASS** |
| 3 | Memory file: 11 required sections | `grep -c '^## '` = 11 | 11 | **PASS** |
| 4 | Memory file: class-level convention finding | `grep -c 'INTENSIVE per-atom'` >= 2 | 4 | **PASS** |
| 5 | Memory file: 4 errata | `grep -cE '\*\*\[E[1-4]...\]'` = 4 | 4 | **PASS** |
| 6 | 4 by_tag indices have T84 entry | each file returns count >= 1 | edh-eu151-matsui-science-2026.md=1; edh-eu151.md=1; matsui-science-2026.md=1; matsui-2026.md=1 | **PASS** |
| 7 | Status narrative has T83+T84 entries | `grep -cE '^### T8[34]'` >= 2 | 3 (T83 x1, T84 x2) | **PASS** |

**PHASE 1 RESULT: 7/7 checks PASS.**

## §3 Sibling-class scan results (mandatory per feedback_fix_the_class_not_the_instance)

Command: `git status --porcelain runs/_loop/by_tag/ | head -20`

Output:
```
 M runs/_loop/by_tag/barnett.md
 M runs/_loop/by_tag/bosonic-bdg.md
 M runs/_loop/by_tag/edh-eu151-matsui-science-2026.md
 M runs/_loop/by_tag/edh-eu151.md
 M runs/_loop/by_tag/fullbdg-lhy.md
 M runs/_loop/by_tag/fullbdg-mechanism-note.md
 M runs/_loop/by_tag/julia-safe-text-edit.md
 M runs/_loop/by_tag/klaus-magnetostir.md
 M runs/_loop/by_tag/manuscript-cash-in.md
 M runs/_loop/by_tag/manuscript.md
 M runs/_loop/by_tag/matsui-2026.md
 M runs/_loop/by_tag/matsui-science-2026.md
 M runs/_loop/by_tag/methodology-note.md
 M runs/_loop/by_tag/paper4-methodology.md
 M runs/_loop/by_tag/paper4.md
 M runs/_loop/by_tag/pseudo-hermitian.md
 M runs/_loop/by_tag/t7-theorist-followup.md
?? runs/_loop/by_tag/3-second-test.md
?? runs/_loop/by_tag/AUDIT_DUE-clearance.md
?? runs/_loop/by_tag/AUDIT_DUE-gap-49.md
```

All entries show ` M` (modified in working tree vs HEAD) or `??` (untracked). No `AM` entries (index/working-tree divergence class) observed. The 3 files we just wrote (`edh-eu151.md`, `matsui-science-2026.md`, `matsui-2026.md`) appear as ` M` — this is the expected post-Write state. The T85 failure class (AM status = index-ahead-of-working-tree) does not appear in any other by_tag file. Additionally, 3 untracked files (`3-second-test.md`, `AUDIT_DUE-clearance.md`, `AUDIT_DUE-gap-49.md`) are present but untracked, not diverged.

**sibling_am_scan_count = 0** (no other by_tag files have AM divergence).

## §4 Phase 2: state.json terminal closure patch

Targeted Edit on `runs/_loop/state.json` EdH block (lines ~2147-2225 pre-edit).

Fields patched:

| Field | Before | After |
|---|---|---|
| `current_stage` | "Document-verify (T85 lightweight verification...)" | "closed" |
| `tier_current` | 2.75 | 3.0 |
| `next_stage` | "Document-verify (T85...)" | "closed" |
| `next_stage_action` | T85 dispatch text | T87 audit-class-scan recommendation |
| `last_turn` | 84 | 86 |
| `last_stage` | "Document" | "Document-verify" |
| `last_verdict` | "CORROBORATE_WITH_ERRATA" | "TIER_3_TERMINAL_CLOSURE" |
| `closing_note` | T84 note (1063 chars) | Extended with terminal-closure stamp (T85 root-cause + T86 repair) |
| `stages_done` | 11 entries | 12 entries (Document-verify appended) |

Post-Edit jq verification:
```
$ jq empty /home/suzume/workspace/BEC-simulation/runs/_loop/state.json && echo OK_state_post_T86_edit
OK_state_post_T86_edit

$ jq '.investigations."edh-eu151-vortex-vs-matsui-science-2026" | {tier_current, current_stage, last_turn, last_stage, last_verdict}' runs/_loop/state.json
{
  "tier_current": 3.0,
  "current_stage": "closed",
  "last_turn": 86,
  "last_stage": "Document-verify",
  "last_verdict": "TIER_3_TERMINAL_CLOSURE"
}
```

## §5 Phase 3: status narrative append

Edit appended to `/home/suzume/workspace/BEC-simulation/runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md` after the existing T85 entry.

Verification: `grep -cE '^### T86' status/edh-eu151-vortex-vs-matsui-science-2026.md` = 1 (PASS).

The file now ends with the T86 PASS narrative row.

## 6. Metrics

```json
{
  "experiment_kind": "text_only",
  "workload_class": "implementer_text",
  "src_files_modified": 0,
  "new_analysis_scripts_written": 0,
  "investigation_id": "edh-eu151-vortex-vs-matsui-science-2026",
  "stage_advancing_to": "closed",
  "flow_template": "verify-claim",
  "phase_0_files_restored": 3,
  "phase_0_all_3_have_t84_post_write": true,
  "phase_0_all_3_have_t86_post_write": true,
  "sibling_am_scan_count": 0,
  "phase_1_checks_total": 7,
  "phase_1_checks_passed": 7,
  "state_json_jq_parses": true,
  "state_json_tier_advanced_to_3": true,
  "state_json_current_stage_is_closed": true,
  "memory_file_11_sections_present": true,
  "memory_file_class_finding_present": true,
  "memory_file_4_errata_present": true,
  "by_tag_indices_4_have_t84": true,
  "status_narrative_t83_t84_present": true,
  "status_narrative_t86_appended": true,
  "investigation_tier_advanced": true,
  "final_tier": 3.0,
  "investigation_closed": true,
  "closing_note_extended": true,
  "new_memory_files_created": 0,
  "by_tag_indices_modified": 3,
  "manuscript_edited": false,
  "src_edited": false,
  "julia_executed": false,
  "tests_passed": null,
  "warnings": [],
  "physical_red_flags": [],
  "falsification_result": "CONFIRMED"
}
```

## §7 Self-review

- [x] All 7 Phase 1 checks PASS post-Phase-0? Yes — 7/7
- [x] All 3 by_tag files written with T84 + T86 rows? Yes — grep confirms 1 each in all 3 files
- [x] state.json post-Edit tier_current = 3.0? Yes — jq confirms 3.0
- [x] state.json post-Edit current_stage = 'closed'? Yes — jq confirms "closed"
- [x] Status narrative T86 row appended? Yes — grep -cE '^### T86' = 1
- [x] No new memory file created? Correct — 0
- [x] No src/ modified? Correct
- [x] No julia executed? Correct
- [x] Cost within 1.5M cap? Yes — lightweight text-only turn, estimated well under cap
- [x] Primary by_tag file edh-eu151-matsui-science-2026.md NOT modified? Correct — only the 3 stale sibling files were written
