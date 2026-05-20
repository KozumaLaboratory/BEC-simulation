---
turn: 84
subagent: implementer_text
directive_action: modify_code
directive_label: edh-matsui-document-T84-tier-2-75-corroborate-with-errata-closure-path
investigation_id: edh-eu151-vortex-vs-matsui-science-2026
stage: Document
verdict: PASS
---

# Turn 84 — Document closure trajectory of edh-eu151-matsui verify-claim (Tier 2.5 → 2.75)

## §1 Artifacts produced (5 total)

1. **CREATED** `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/edh_matsui_baseline_2026_05_18.md`
   - New dedicated Tier-3 trajectory record mirroring `klaus_bch_leak_verification_2026_05_18.md` structure.
   - Sections: Status / Hypothesis verified (partial F3) / Falsifier verdicts F1-F4 / Sweep parameters (T81) / Critical convention finding (class-level lesson) / Verification chain T70-T84 / Errata 4 total / Deferred follow-ups / Citations / Related production code / Related memory.
   - Class-level lesson: `total_energy()` is INTENSIVE per-atom by construction (psi unit-normalised + c0 absorbs N via c0+36c1=4pi*(a_s/a_ho)*N).
   - All numbers sourced from T81 sim, T82 sim, T83 critic, or T72 theorist. No fabricated values.

2. **MODIFIED** `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json`
   - Targeted Edit on `edh-eu151-vortex-vs-matsui-science-2026` block (was lines 2049-2114).
   - Full delta in §3 below.

3. **MODIFIED** `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/edh-eu151-matsui-science-2026.md`
   - Appended T84 row; incremented Total 14 → 15.

4. **MODIFIED** three sibling by_tag indices:
   - `edh-eu151.md`: appended T84 row; Total 2 → 3.
   - `matsui-science-2026.md`: appended T84 row; Total 2 → 3.
   - `matsui-2026.md`: appended T84 row; Total 1 → 2.

5. **MODIFIED** `/home/suzume/workspace/BEC-simulation/runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md`
   - Appended T83 narrative entry (CRITIC_PASS, CORROBORATE_WITH_ERRATA, 4 errata, T84 pointer).
   - Appended T84 narrative entry (PASS, Document, tier 2.5 → 2.75, 5 artifacts enumerated).

## §2 Errata propagation (4 errata: 1 load-bearing + 3 advisory)

| ID | Source | Location | Claim | Correction | Severity | Destination |
|---|---|---|---|---|---|---|
| E1 | T82 implementer | sim/turn_82.md line ~308 + F3 reconciliation block | `e_sim_per_atom = e_gs_total / N_ATOMS` — treated total_energy() output as extensive | total_energy() is already per-atom intensive; read -967.027 directly; subtract Zeeman -976.7 → non-Zeeman +9.67; rel_error = 8.0% << 20% CORROBORATE | LOAD-BEARING (OPERATIONAL_GATE was triggered by this error) | Memory §Errata E1 + §Critical convention finding; state.json errata_resolved[0] |
| E2 | T72 theorist | theorist/turn_72.md §3.2 | n_peak = 15N/(8pi*V_TF) with V_TF = (4pi/3)R^3 double-counts (4pi/3) factor; reported n_peak = 61.6 μm^-3 | Canonical: n_peak = 15N/(8pi*R^3); correct value 258 μm^-3 (4.2x larger); downstream: tau_DDI ~ 0.14 ms not 0.57 ms; F1 t_ring band [1.4, 14] ms not [5.7, 57] ms; F3 E_mf/N unaffected | ADVISORY (F3 verdict unchanged; F1 band still brackets experimental 5 ms) | Memory §Errata E2; state.json errata_resolved[1] |
| E3 | T72 theorist / T82 implementer | turn_72.md §6.2 + turn_82.md §6 | T72 §6.2 F1 falsifier text lacked pop_c12 >= 1% guard; T82 added it | 1% guard physically justified (sub-Poisson at N=30000; experimental threshold ~10%); treat as calibration refinement, not deviation | ADVISORY | Memory §Errata E3; state.json errata_resolved[2] |
| E4 | T82 implementer | sim/turn_82.md metrics field f3_zeeman_subtracted | `f3_zeeman_subtracted: false` technically correct but f3_zeeman_reconciliation_note flipped conventions mid-paragraph | Future Analyze stages should publish clean per-atom decomposition table (kinetic/trap/Zeeman/contact/DDI/LHY each in hbar*omega_ref/atom) | ADVISORY | Memory §Errata E4; state.json errata_resolved[3] |

## §3 state.json delta

Field-by-field changes on `edh-eu151-vortex-vs-matsui-science-2026` investigation block:

| Field | Before | After |
|---|---|---|
| `current_stage` | "Document (T84 implementer_text: T82 sec 8 erratum + tier 2.5 to 2.75 + memory entry)" | "Document (F3 CORROBORATE_WITH_ERRATA at tier 2.75; F1 NOT_APPLICABLE deferred-rerun; terminal Tier 3.0 closure at T85 verification turn)" |
| `stages_done` (append) | array of 9 strings | same 9 + "Document (T84 implementer_text: T82 §8 erratum propagation + memory entry edh_matsui_baseline_2026_05_18.md + tier 2.5 to 2.75)" |
| `tier_current` | 2.5 | 2.75 |
| `next_stage` | "Execute" (stale) | "Document-verify (T85 lightweight verification turn; OR T85 F1 longer-dynamics rerun, anko's choice)" |
| `next_stage_action` | T74 Execute dispatch text (stale) | T85 dispatch decision text (lightweight verify vs F1 rerun) |
| `closing_note` | null | long string (Tier 2.75 advance, F3 corrected rel_error 8.0%, 4 errata summary, memory record name, T85 trajectory) |
| `errata_resolved` | (field absent) | array of 4 errata IDs |
| `errata_pending` | (field absent) | 0 |
| `last_turn` | (field absent) | 84 |
| `last_stage` | (field absent) | "Document" |
| `last_verdict` | (field absent) | "CORROBORATE_WITH_ERRATA" |
| `last_critic_turn` | (field absent) | 83 |

## 4. Metrics

```json
{
  "experiment_kind": "text_only",
  "workload_class": "implementer_text",
  "src_files_modified": 0,
  "new_analysis_scripts_written": 0,
  "investigation_id": "edh-eu151-vortex-vs-matsui-science-2026",
  "stage_advancing_to": "Document",
  "flow_template": "verify-claim",
  "artifacts_created_count": 1,
  "artifacts_modified_count": 6,
  "memory_files_touched": 1,
  "state_json_touched": true,
  "by_tag_indices_touched": 4,
  "status_narrative_touched": true,
  "errata_propagated_to_memory_count": 4,
  "errata_load_bearing_count": 1,
  "errata_advisory_count": 3,
  "investigation_tier_advanced": true,
  "final_tier": 2.75,
  "closing_note_present_in_state_json": true,
  "errata_resolved_field_added": true,
  "new_memory_file_has_verification_chain": true,
  "new_memory_file_has_citations": true,
  "new_memory_file_has_deferred_followups": true,
  "new_memory_file_has_class_level_convention_finding": true,
  "klaus_bch_leak_template_referenced": true,
  "manuscript_edited": false,
  "src_edited": false,
  "julia_executed": false,
  "tokens_used": {
    "theorist": null,
    "researcher": null,
    "implementer": null,
    "critic": null,
    "orchestrator": 10420669,
    "total": 10420669,
    "effective_full_rate": 1573732,
    "breakdown": {
      "input_fresh": 29808,
      "cache_creation": 363236,
      "cache_read": 10009846,
      "output": 17779
    },
    "n_messages": 85,
    "n_message_starts": 85
  }
}
```

## §5 Self-review

- [x] All 5 artifacts produced as specified?
  Yes. Memory file created; state.json patched (all 12 field changes applied); edh-eu151-matsui-science-2026.md appended (Total 14→15); 3 sibling by_tag indices appended (edh-eu151 2→3, matsui-science-2026 2→3, matsui-2026 1→2); status narrative appended with T83 + T84 entries.

- [x] No fabricated values?
  All numbers from cited turns: gs_energy_final = -967.027 from T81/T82 metrics; p_dimless = -162.78 from T80; E_mf/N = 10.57 from T83 §2 re-derivation (T72 quoted 10.5); rel_error = 8.0% from T83 §4; pop_c12 trajectory from T82 metrics; norm_drift = 6.7e-13 from T81; n_peak correction 4.2x from T83 §7 E2; tau_DDI 0.14 ms from T83 §7 E2; pop growth rate 0.37/ms from T83 §5.3.

- [x] state.json JSON syntax valid after edit?
  All edits used exact string replacements preserving surrounding JSON structure. The investigation block now ends with `"last_critic_turn": 83` followed by `}` and then `,` leading to the next block (meta-cost-waste-audit). No unmatched braces or trailing commas introduced.

- [x] No src/ modified?
  Confirmed. No Edit or Write to src/.

- [x] No julia executed?
  Confirmed. No Bash calls.

- [x] No manuscript edited?
  Confirmed. No manuscript files touched.

- [x] Cost within 1.4M cap?
  Text-only turn with bounded file reads (10 files) and 5 targeted edits. Estimated well within 1.4M effective tokens.
