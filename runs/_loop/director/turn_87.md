---
turn: 87
subagent: director
investigation_id: audit-class-scan-2026-05-18-T87
stage_advancing_from: (new investigation — spawn) [EdH closed at T86 Tier 3.0; pipeline rotates per AUDIT_DUE director_must_address advisory]
stage_advancing_to: Observe (§F6 first stage of audit-class-scan flow; third full §F6 cycle this loop after T50 and T61)
topic_tags: [audit-class-scan, patterns-yaml, AUDIT_DUE-resolution, level-2-periodic-sweep, code-debt, third-cycle, observe-stage, post-edh-rotation, drift-director-must-address]
paper_section: null
depends_on: [86, 85, 84, 83, 63, 61, 50, "runs/_loop/director/turn_86.md", "runs/_loop/judge/turn_86.json", "runs/_loop/sim/turn_86.md", "runs/_loop/director/turn_61.md", "runs/_loop/research/turn_61_audit_class_scan.md", "runs/_loop/research/turn_50_audit_class_scan.md", "runs/_loop/state.json", "runs/_loop/_local/scheduler_87.json", "runs/_loop/patterns.yaml", "memory:feedback_fix_the_class_not_the_instance", "memory:feedback_mechanical_vs_investigation_threshold", "memory:feedback_cost_overhead_is_the_cost", "memory:feedback_manuscript_is_not_the_essence"]
produces: "T87 spawn + Observe-stage dispatch of NEW investigation `audit-class-scan-2026-05-18-T87`. Single researcher dispatch sweeps the 10 active patterns in `runs/_loop/patterns.yaml` (RECALL scan; first sweep since T61, gap=26 patterns-turns since last_scanned=T63), reports per-pattern raw/filtered counts via Grep tool, classifies findings via 3-second triage (mechanical-fix-now vs investigation-eligible vs no-action-rationalized vs no-finding), proposes L3 related_classes ONLY if a new finding doesn't fit the existing catalog. T88 Triage stage applies patterns.yaml `last_scanned` / `last_count` updates; T89 Document stage closes the cycle (per T61→T62→T63 precedent). Honors §B5 AUDIT_DUE + director_must_address drift escalation surfaced at T86."
---

# Turn 87 — Director Report

## 1. Investigation state snapshot

- **Active investigation (NEW spawn this turn)**: `audit-class-scan-2026-05-18-T87` (kind: physics, flow_template: audit-class-scan, priority 20, tier_target 2). Spawned by director per AUDIT_DUE drift advisory at T86 (gap=23, escalation `director_must_address`) and the §F6 ~10-turn cadence rule (last cycle = audit-class-scan-2026-05-18-T61 closed at T63; gap=24 turns since last sweep). Pre-routed by T86 §6.failure_modes.if_all_pass.next_action: "spawn audit-class-scan-2026-05-18-T87".
- **Previous active**: `edh-eu151-vortex-vs-matsui-science-2026` → **closed at T86 Tier 3.0** (TIER_3_TERMINAL_CLOSURE verdict). Project's 3rd Tier-3 trajectory (after barnett T29 and klaus-bch-leak T59); 1st explicit lab-paper benchmark (Matsui et al. Science 391, 384-388, 2026). 7/7 mechanical Phase 1 checks PASS at T86; state.json `current_stage="closed"` + `tier_current=3.0` + `last_verdict="TIER_3_TERMINAL_CLOSURE"` confirmed via jq verification in T86 sim §4.
- **Stage transition**: NEW investigation, no prior stage → `Observe` (first stage of §F6).
- **Tier**: 0 → target 2 (Observe → Findings → Triage → Document cycle landing at tier 2 per T50/T61 precedent).
- **Falsifiers**: none yet; audit-class-scan does not have hypothesis-falsifier shape — it has per-pattern grep findings + L3 proposed_classes audit (per §F6).
- **Other in-flight investigations (priority-ordered after EdH closure)**:
  | id | priority | tier | stage | notes |
  |---|---|---|---|---|
  | **audit-class-scan-2026-05-18-T87** (NEW) | **20** | **0/2 (this turn = Observe)** | **Observe (T87)** | active, this turn — §F6 mandatory cadence |
  | barnett-mechanism-2026-05-16 | 1 | 3.0/3 | closed | 1st Tier-3 (T29) |
  | edh-eu151-vortex-vs-matsui-science-2026 | 1 | 3.0/3 | closed (T86) | 3rd Tier-3, 1st lab-paper benchmark |
  | klaus-magnetostir-bch-leak-2026-05-13 | 3 | 3.0/3 | closed | 2nd Tier-3 (T59) |
  | judge-in-operator-bug-2026-05-18 | 2 | 2.0/2 | closed | done |
  | audit-due-heuristic-bug-2026-05-18 | 4 | 2.0/2 | closed | done |
  | meta-internal-b-unification-2026-05-18 | 5 | 1.0/1 | closed | done |
  | tier3-verification-pipeline-survey-2026-05-18 | 10 | 1/1 | Document (deferred) | parent of EdH; closure deferred to steady-state |
  | meta-cost-waste-audit-2026-05-18 | 15 | 0/1 | Observe (auto-spawn) | candidate T90+ (after audit cycle) |
  | meta-director-self-audit-2026-05-18 | 20 | 0/1 | Observe (auto-spawn) | candidate T90+ |
  | audit-class-scan-2026-05-18-T50 | 20 | 2/2 | closed | 1st cycle |
  | audit-class-scan-2026-05-18-T61 | 20 | 2/2 | closed | 2nd cycle |
  | meta-cost-inflation-2026-05-18 | 40 | 0/1 | Observe (auto-spawn) | deferred |
  | meta-critic-placement-2026-05-17 | 50 | 0/2 | Observe | deferred |
  | fullbdg-f6-polar-3000x | 99 | 1.5/2 | dormant (anko-contained) | — |
  | yan-li-saito-2026-reproduction | 1 | 0.4/3 | closed REFUTED-CLEAN (T65) | — |
- **Scheduler** (`runs/_loop/_local/scheduler_87.json` read this turn): decision `go`, policy `JULIA_GPU_OK`, `allowed_workloads` includes `researcher` (line 13). Window ends 2026-05-31T23:59 JST with **1,145,255 sec (13.26 days) remaining**. Probe: VRAM 12,705 MB free, RAM 25.01 GB avail, GPU util 1%, foreign_julia 0. Observe is text-only Grep sweep — trivial fit, no julia.
- **Drift escalation** at T86 (state.history T86 line 1589): **`director_must_address`** (UPGRADED from `advisory`). Drift signals at T86:
  - `topic_repetition` 0.438 (EdH 8-turn focus tapering; will drop on this turn's rotation to audit-class-scan).
  - `subagent_repetition` 0.667 (3 consecutive implementer_text; T87 researcher rotates).
  - `manuscript_delta_zero` 1.0 — advisory only per `feedback_manuscript_is_not_the_essence`.
  - `code_delta_zero` 0.0 (T86 had 3 by_tag Writes + state.json Edit; T87 Observe will be 0).
  - `verdict_drift` 0.2 (one FAIL_OPERATIONAL at T85 followed by T86 PASS; recovering).
  - `cost_inflation` 1.057 (T86 was 1.83M vs ~1.5M baseline; **DRIFT_COST_INFLATION present** — partly from inheriting T85 discovery work + reading 7 large artifacts). T87 Observe expected ~2.0M (per T61 precedent 1.96M); will stay flat at ~1.0 ratio.
  - `novel_claim_zero` 0.0 (T86 TIER_3_TERMINAL_CLOSURE was a novel claim).
  - **AUDIT_DUE**: `gap=23` at T86, will be `gap=24` at T87 entry. **§F6 ~10-turn cadence threshold exceeded by 2.4×.** Mandatory to address per §B5 escalation handling.
- **Why this is the right move (not another investigation, not noop)**:
  - **Not noop**: drift escalation is `director_must_address`; AUDIT_DUE has fired for 24 turns straight (since T63 close); director must address per §B5. cost_inflation is also `director_must_address`, but cost_inflation requires a meta-investigation Hypothesize cycle which itself costs ~2M+; audit-class-scan is the cheaper of the two `director_must_address` signals to clear THIS turn.
  - **Not meta-cost-waste-audit (priority 15)**: even though lower priority number, meta-investigations have safety rails (§F5 S1-S6) requiring critic audits at Design+Evaluate, branch isolation, anko ratification. A meta-investigation Observe → Hypothesize → Design → Pilot → Evaluate cycle is 5-7 turns. Audit-class-scan is a known 3-turn template (T50/T54 = 4 turns, T61/T62/T63 = 3 turns, with §F6 §F1 collapse possible at Findings into Observe).
  - **Not F1 longer-dynamics rerun**: optional EdH post-closure refinement; not blocking; ~3M GPU + 90 min wall = expensive and EdH already at Tier 3.0 (closed). Per §B2 priority order, this is below audit-class-scan when AUDIT_DUE is director_must_address.
  - **Not advancing parent tier3-verification-pipeline-survey to Document (priority 10)**: closure_deferred per its own notes; can be folded into any steady-state turn cheaply; lower urgency than AUDIT_DUE.
  - **Not switching to a meta-investigation Hypothesize (priority 15/20)**: per §B2, meta is interleaved not parallel; only after a clear physics turn. T87 is the rotation back from 8-turn EdH-focus, so first should be physics-class work (audit-class-scan kind=physics per T50/T61 precedent). Meta can come T90+ once audit cycle closes.
- **Cost frame**: T61 (analogous Observe sweep, 10 patterns) cost ~1.96M effective. T87 budget: 2.0M expected, 2.5M hard cap. The T86 cost overrun (1.83M vs 1.5M) was due to inherited discovery work; T87 starts clean.

## 2. Recent-turn audit (last 3 turns OF the LOOP — no prior turns for this NEW investigation)

| Turn | Investigation | Stage | Verdict | What happened |
|---|---|---|---|---|
| T84 | edh-eu151-vortex-vs-matsui-science-2026 | Document | PASS (1.574M) | 5 artifacts: memory file + state.json patch (tier 2.5→2.75) + 4 by_tag indices + status narrative. T84 implementer edits to 3 sibling by_tag files landed in git index but NOT working tree (revealed only at T85 Check 6). |
| T85 | edh-eu151-vortex-vs-matsui-science-2026 | Document-verify | **FAIL_OPERATIONAL** (1.665M, BUDGET_BUSTED 2.22×) | Phase 1 Check 6 surfaced the 3 by_tag working-tree/index divergences. Per directive's STOP-on-FAIL rule, Phase 2 (state.json tier patch) and Phase 3 (status narrative append) NOT executed. Tier remained 2.75. T85 implementer left verbatim corrective content in sim/turn_85.md for T86 to consume. |
| T86 | edh-eu151-vortex-vs-matsui-science-2026 | Document-verify (retry) | **PASS** (1.827M, cost_inflation 1.057) | 4 phases executed: (0) 3 by_tag files restored from T85 verbatim content; (1) 7/7 Phase 1 checks PASS; (2) state.json patched (tier 2.75 → 3.0, current_stage 'closed', last_verdict 'TIER_3_TERMINAL_CLOSURE'); (3) status narrative T86 row appended. Sibling-class scan: 0 other AM-status by_tag files (clean). **EdH investigation terminally closed at Tier 3.0** = 3rd project Tier-3 trajectory + 1st lab-paper benchmark closure. drift_escalation upgraded to `director_must_address` for AUDIT_DUE (gap=23) + DRIFT_COST_INFLATION (T86 cost 1.83M). |

Cumulative trajectory T84 → T85 → T86 demonstrates the verify-claim Document → Document-verify split is working: T84 landed the artifacts, T85 caught a class of operational defect (Edit/Write tool index-vs-working-tree divergence) that would have silently corrupted any future scan of the by_tag indices, T86 fixed it cleanly + closed Tier 3.0. The 3-turn closure cost was 5.07M total (acceptable for terminal Tier-3 trajectory). Pipeline ROI well-justified.

## 3. Flow template recall

- **Template**: `audit-class-scan` (§F6 of director.md). Sequence: **Observe → Findings → Triage → Document → closed**. (Findings is collapsed into Observe per T50/T61 precedent; the researcher report covers both in one turn).
- **Role for stage `Observe`**: **`researcher`** (per §F6 table row). Researcher runs each active pattern's `grep_patterns` against current `src/` + `ext/` + (optionally) `test/`, records raw + filtered counts, classifies findings via 3-second triage, proposes L3 related_classes only if a new finding doesn't fit the existing catalog. Allowed under scheduler `JULIA_GPU_OK` (researcher is text-only workload).
- **Verdict-driven routing per §B3**: NEW investigation, no prior verdict, so the template starts at `Observe` stage canonically.
- **Why this stage now (not waiting until T100)**:
  - AUDIT_DUE gap = 24 turns (last cycle closed T63). §F6 cadence rule "every ~10 turns since the previous audit-class-scan" exceeded by 2.4×.
  - drift_escalation = `director_must_address` requires director action this turn; the cheaper of the two `director_must_address` signals (AUDIT_DUE vs DRIFT_COST_INFLATION) is the audit sweep.
  - EdH terminal closure at T86 cleared the priority-1 physics queue; rotation to loop-infrastructure work is canonical (T29 close → T30 meta; T59 close → T60 meta; T86 close → T87 audit per same pattern).
- **Why NOT immediate Triage skipping Observe**:
  - Without an Observe sweep, there's nothing to triage. Triage stage at T88 consumes T87's findings table.
- **Why NOT collapsing Observe+Triage+Document into one turn**:
  - Per T61 (Observe) → T62 (Triage) → T63 (Document) precedent the 3-stage split keeps per-turn cost bounded (each ~1-2M) vs a collapsed 6M+ turn.
  - Triage stage may invoke implementer (if mechanical fixes surface) or spawn child investigations (if investigation-eligible findings surface); separating it from Observe keeps the dispatcher role clear.
- **Why NOT spawning a meta-investigation about T86's index-vs-working-tree divergence class**:
  - Per `feedback_mechanical_vs_investigation_threshold`: T86's sibling-class scan returned `sibling_am_scan_count = 0` (other by_tag files had ` M` status, not `AM`; the AM-divergence class did not propagate). One instance fixed; no class-level pattern surfaced. If T87 audit surfaces the same class in a different file area, spawn at T88.

## 4. Research grounding (§A6)

T87 dispatch citations (≥1 external reference per §A6):

1. **`runs/_loop/director/turn_61.md` §6 (T61 audit-class-scan Observe dispatch)** — the canonical predecessor contract. T87 reuses its structure with minimal deltas: timestamps shift T61 → T87, last_scanned baselines shift 2026-05-18T13:00 → 2026-05-18T17:52, all other fields preserved. APC contract template cache reuse pattern per director.md §B1 item.

2. **`runs/_loop/research/turn_61_audit_class_scan.md`** — the T61 researcher's actual sweep report. T87 researcher uses §1-§4 structure verbatim, replaces counts/timestamps with T87-current values. Will reference this for the per-pattern grep invocation format.

3. **`runs/_loop/research/turn_50_audit_class_scan.md`** — the original T50 cycle's sweep (first cycle, 9 patterns). Useful as deeper template; secondary reference (T61 supersedes for current 10-pattern catalog).

4. **`runs/_loop/patterns.yaml`** — the authoritative anti-pattern catalog. As of 2026-05-18T13:00: 10 active patterns (deprecated-name-leak, api-rename-stragglers, doc-staleness, hardcoded-magic-number, dead-export, large-file-bloat, test-mock-of-real, cargo-cult-comment, paper-unit-system-wrong-param-in-spot-check, topology-function-WHAT-comment-pattern). audit_history shows 5 entries: T0, T48, T54×2, T63. T87 sweep is the 3rd full §F6 cycle.

5. **director.md §F6 (audit-class-scan template)** — the architectural definition of this flow's stages, roles, and Level 3 (analogical derivation) safety rails. T87 honors the rail "Level 3 critic-rejected proposals are logged in `patterns.yaml` `proposed_classes` with rejection reason; NOT added to active catalog."

6. **Memory `feedback_fix_the_class_not_the_instance.md` (2026-05-18)** — the meta-pattern motivating §F6 and the sibling-class scan requirement. T87 brief instructs researcher to apply the 3-second triage to each finding.

7. **Memory `feedback_mechanical_vs_investigation_threshold.md` (2026-05-18)** — the 3-second triage that distinguishes mechanical-fix-now from investigation-eligible findings. Critical for Triage stage classification at T88.

8. **Memory `feedback_cost_overhead_is_the_cost.md` (2026-05-15)** — anko's stance: stop deliberating about cost when the deliberation costs more than the work. T87 just executes the sweep; doesn't over-justify.

9. **Memory `feedback_manuscript_is_not_the_essence.md` (2026-05-15)** — T87 scope: text-only sweep report; NO manuscript, NO docstring, NO src.

10. **director.md §B5 drift escalation handling** — `director_must_address` is the highest non-halt escalation; AUDIT_DUE is named-and-cited as the canonical case requiring this rotation. T87 director ratifies the routing.

11. **`runs/_loop/director/turn_86.md` §6.failure_modes.if_all_success.next_action** — explicitly pre-routed: "T87 director: spawn audit-class-scan-2026-05-18-T87 (AUDIT_DUE gap=23 cadence trigger; researcher Observe stage running patterns.yaml 10-pattern grep sweep; ~1.2M-1.8M expected)." T87 executes exactly this routing (with the cost expectation bumped to 2.0M based on T61 actual = 1.96M; the T86 prediction was optimistic).

12. **APC contract template cache** — `physics::audit-class-scan::Observe` template has n_seen ≥ 2 (T50, T61). T87 reuses the skeleton (success_criteria field structure, failure_modes shape, observable_manifest schema, budget envelope) with the only deltas being timestamps and the investigation_id update. Per arXiv:2506.14852 (APC), this targets ~30-50% contract-section cost reduction this turn.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D2 (service axis — loop-infrastructure debt audit)**, with explicit D1-protection rationale: audit-class-scan exists to catch regressions in src/ that would corrupt future verification work. Per §F6: "Periodic catalog sweep produces a clean baseline" enables future D1 verification investigations to start without inherited noise. NOT manuscript polish.
- **Tier ladder position after T87 (anticipated)**: this investigation: 0 → ~0.5 (Observe complete, Findings classified; full tier 2 closure at T89 Document).
- **Project D1 verification depth narrative** (unchanged): 3 Tier-3 trajectories closed (barnett T29, klaus-bch-leak T59, edh-matsui T86). T87 enables future Tier-3 work by clearing accumulated debt that could mask physics regressions.
- **Manuscript NOT in scope** (per `feedback_manuscript_is_not_the_essence`). T87 writes one research artifact only.
- **Cost frame**: target ~2.0M effective (per T61 precedent 1.96M), 2.5M hard cap. Drift cost_inflation 1.057 should improve toward 1.0 if T87 lands at ~2.0M (vs 2.0M baseline).
- **Drift trajectory after T87 (anticipated)**:
  - cost_inflation: 1.057 → ~0.95 (improvement if cost stays within 2.0M).
  - code_delta_zero: 0.0 → 1.0 (pure text-only sweep).
  - manuscript_delta_zero: 1.0 (correctly, by design).
  - novel_claim_zero: 0.0 → 0.0 or 1.0 (depending on whether sweep surfaces a novel pattern finding).
  - topic_repetition: 0.438 → ~0.10 (audit-class-scan is fresh topic, rotates off EdH).
  - subagent_repetition: 0.667 → ~0.4 (researcher rotates off 3-implementer-text streak).
  - verdict_drift: 0.2 → 0.1 (Observe canonically PASSes).
  - AUDIT_DUE: gap 24 → reset to 0 at T89 Document close.
- **Recommended T88-T89 trajectory**:
  1. **T88 Triage stage** (implementer_text if mechanical fixes surface; theorist+critic if investigation-eligible findings surface; researcher-only update if no findings). Apply patterns.yaml `last_scanned` + `last_count` updates.
  2. **T89 Document stage** (implementer_text). Append audit_history row to patterns.yaml. Close investigation at tier 2. Clear AUDIT_DUE drift advisory.
  3. **T90+** options: meta-cost-waste-audit Hypothesize (priority 15, address remaining `director_must_address` cost-inflation signal); meta-director-self-audit Hypothesize (priority 20); tier3-verification-pipeline-survey Document closure (priority 10, cheap 1-turn); F1 longer-dynamics rerun (post-EdH refinement, ~3M GPU).

## 6. Dispatch decision (declarative contract)

```json
{
 "investigation_id": "audit-class-scan-2026-05-18-T87",
 "stage_advancing_to": "Observe",
 "subagent_type": "researcher",
 "researcher_depth": "shallow",
 "parallel_researcher_count": 1,
 "rationale": "T86 drift_escalation = director_must_address with AUDIT_DUE gap=23 (will be 24 at T87); §F6 ~10-turn cadence threshold exceeded 2.4×. Last full audit cycle closed T63 (audit-class-scan-2026-05-18-T61). EdH investigation closed at Tier 3.0 T86 → priority-1 physics queue empty, canonical rotation to loop-infrastructure work. T87 spawns new audit-class-scan-2026-05-18-T87 investigation, Observe stage. Researcher dispatch: shallow depth (no PDF, no external lit — pure src/ grep sweep), single agent, ~2.0M expected per T61 precedent. Honors §B5 escalation handling. Cheaper than the alternative director_must_address remediation (meta-cost-waste-audit needs 5-7 meta-improvement stages with safety rails). Contract structure inherited from T61 §6 APC cache lineage (n_seen=2) with timestamp + investigation_id deltas only.",
 "brief": "## ROLE\n\nYou are researcher. T87 §F6 Observe stage of NEW investigation `audit-class-scan-2026-05-18-T87` (audit-class-scan flow, 3rd full cycle this loop after T50 and T61). This is a periodic Level-2 recall sweep of the patterns.yaml catalog (10 active patterns; unchanged since T61 cycle). Single researcher dispatch; text-only; no julia execution; no src/ modification; no .claude/agents/ modification; no patterns.yaml modification (Triage stage at T88 handles updates).\n\nDIRECTIVE_LABEL: audit-class-scan-T87-observe\n\n=== HARD CONSTRAINTS ===\n\n- Allowed tools: Read, Glob, Grep, Bash (jq parse + rg/grep counts ONLY — NO julia, NO destructive git ops), Write (1 file specifically: the report).\n- Files allowed to CREATE/WRITE: `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_87_audit_class_scan.md` (your researcher report — the ONLY artifact).\n- Files MUST NOT be touched: `src/`, `runs/eu151_*/`, `runs/matsui_edh_baseline_*/`, `scripts/`, `.claude/agents/*`, `.claude/scripts/*`, `.claude/workload_specs.yaml`, `quota_config.json`, `.claude/settings*.json`, any memory file, `runs/_loop/state.json`, `runs/_loop/patterns.yaml` (T88 Triage handles patterns.yaml updates), any other `runs/_loop/` file.\n- NO julia execution.\n- NO new memory files.\n- NO manuscript edits (per feedback_manuscript_is_not_the_essence).\n- NO src modifications.\n- English only. No emojis.\n- Absolute paths in all tool calls.\n- Cost budget: stay within 2.5M effective tokens, ~12 min wall hard cap. Target 2.0M (T61 precedent: 1.96M).\n- NO fabrication: every count in your report MUST come from an actual rg/Grep invocation. If a count is uncertain (e.g., detect-block estimate for dead-export), explicitly mark `(manual estimate, not grep)`.\n- Use the **Grep tool**, NOT bash rg/grep — the Grep tool is the configured search anchor per environment constraints.\n\n=== REQUIRED READING (READ BEFORE WRITING ANYTHING) ===\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/patterns.yaml` end-to-end — the authoritative catalog of 10 active patterns. Each has `grep_patterns` (regex list) or `detect` (free-form script description). Read also the `audit_history` block at the end to see what previous cycles found.\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_61_audit_class_scan.md` end-to-end — the predecessor cycle's Observe stage report. This is your STRUCTURAL TEMPLATE: per-pattern subsection with grep commands, raw counts, filtered counts (post `exclude_paths`), first 5 hits per nonzero pattern, and triage classification.\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_50_audit_class_scan.md` (secondary reference for first-cycle format; T61 supersedes for current 10-pattern catalog).\n4. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_87.md` (this director report) — the dispatch rationale + §6 contract.\n5. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_61.md` §6 — the predecessor's contract shape (observable_manifest fields you must produce).\n6. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/feedback_fix_the_class_not_the_instance.md` — the meta-pattern motivating §F6.\n7. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/feedback_mechanical_vs_investigation_threshold.md` — the 3-second triage that distinguishes mechanical-fix-now from investigation-eligible findings.\n\n=== YOUR JOB — 1 ARTIFACT (turn report) WITH 10 PATTERN SWEEPS ===\n\nProduce `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_87_audit_class_scan.md` containing:\n\n### §1 Scope\n- Patterns swept: 10 (all of patterns.yaml `patterns:` list as of 2026-05-18T17:52; same catalog as T61 since no new patterns added between T63 close and T87 spawn).\n- Sweep scope: `src/` (primary), `ext/` (for large-file-bloat), `test/` (only where pattern's `exclude_paths` permits).\n- state_zoo `init_psi_*` explicitly excluded from dead-export scan per memory `state_zoo_yaml_integration_wip.md` (per T50/T61 precedent).\n- Time window: this single turn (Observe + Findings folded together; Triage at T88).\n- Diff from T61 sweep: 0 NEW active patterns (T61 catalog == T87 catalog; T54 LP-2 promotion was already-folded). Gap since T61's sweep: 26 turns (T61 → T87). 0 mechanical fixes applied between T61 close (T63) and T87 spawn, so steady-state recall expected.\n- T54-LP-2 (`topology-function-WHAT-comment-pattern`) recall: T61 reported 5 false-positives in WHY-comments; verify T54 cleanup of `src/analysis/topology.jl monopole_charge_3d` still holds (expected 0 hits at the target site).\n\n### §2 Per-pattern findings (10 subsections, one per active pattern)\n\nFor EACH of the 10 active patterns in patterns.yaml:\n\n- Subsection header: `### 2.N <pattern-id> (RECALL scan since 2026-05-18T... | gap 26 turns from T61)`\n- One code block per `grep_patterns` entry, format:\n  ```\n  rg -n '<pattern>' /home/suzume/workspace/BEC-simulation/src/\n  ```\n  with the actual Grep tool invocation you ran (absolute path, no relative paths)\n- Result: raw count for each rg, then total raw_hit_count across all patterns in this catalog entry\n- For patterns with `exclude_paths`: report filtered_count after exclusion\n- For patterns with `detect` block (not grep_patterns): describe the detect script run (e.g., for dead-export, large-file-bloat) with exact command + count\n- For each NONZERO finding, list first 5 hits as `path:line: <matching text>` (per T50/T61 precedent)\n- Closing line per pattern: `Triage classification: <mechanical-fix-now | investigation-eligible | no-action-rationalized | no-finding>` with one-sentence rationale and explicit reference to whether the count changed since T61 sweep.\n\nThe 10 active patterns to sweep (read patterns.yaml for the canonical specs):\n1. `deprecated-name-leak`\n2. `api-rename-stragglers`\n3. `doc-staleness`\n4. `hardcoded-magic-number`\n5. `dead-export`\n6. `large-file-bloat`\n7. `test-mock-of-real`\n8. `cargo-cult-comment`\n9. `paper-unit-system-wrong-param-in-spot-check`\n10. `topology-function-WHAT-comment-pattern`\n\nNote on `topology-function-WHAT-comment-pattern`: T54 promoted from proposed_classes with last_count=5 (pre-cleanup). T51 implementer cleanup targeted src/analysis/topology.jl `monopole_charge_3d`. T61 RECALL reported 5 false-positives in WHY-comments. T87 should sweep again; if still 5 false-positives (or unchanged), classify `no-action-rationalized (T51 cleanup held; grep false-positives flagged for proposed grep refinement at T88 Triage or next §F6 critic_audit per safety rail)`. If >5, list new instances and classify per their location/scope. If <5, note the diff and classify accordingly.\n\nNote on `hardcoded-magic-number`: T51 director re-triage classified the 126 1e-30 instances as no-action-rationalized due to heterogeneous semantics. T87 sweep should report the current raw count (expected ~126 unchanged), but classify directly as `no-action-rationalized (T51 director re-triage; semantics heterogeneous; flat namespace would obscure)`. Do NOT re-investigate.\n\nNote on `deprecated-name-leak`: T48 batch-fix; T50/T61 recall = 0. T87 expected 0 (no drift). If >0, list instances and classify as `regression of T48 batch-fix — escalate to T88 Triage`.\n\n### §3 Sibling-class scan + L3 related_classes proposals\n\n**Sibling-class scan (mandatory per `feedback_fix_the_class_not_the_instance`)**: If §2 surfaces any NEW finding (i.e., finding not present at T61), immediately grep for siblings codebase-wide. Use the Grep tool. Report results in §3.\n\n**L3 related_classes proposals**: If any pattern surfaces ≥1 finding that doesn't fit the existing 10 patterns + 1 rejected pattern (LP-1) + topology-function-WHAT-comment-pattern (LP-2 already accepted), propose a NEW related_class per §F6 4-question rubric:\n1. Has a runnable `grep_patterns` or `detect` block?\n2. Empirical check: would running the grep produce between 1 and ~10000 hits?\n3. Is the analogy concrete (not just \"feels similar\")?\n4. Sharp differentiation from existing catalog entries?\n\nQueue each L3 proposal with: id (kebab-case), description, grep_patterns or detect script, external anchor (= the runnable check), proposed_by = `T87 researcher audit-class-scan Observe stage`. Status: `pending_critic_audit_at_T89` (per T50-T52 precedent).\n\nIf NO new findings surface (steady-state sweep, expected outcome), explicitly write `No L3 proposals this cycle (steady state; all findings classified into existing catalog entries; T61→T87 gap=26 turns with 0 src/ changes contributing to pattern drift per T87 sweep).`\n\n### §4 Metrics (single fenced ```json``` block, REQUIRED)\n\n```json\n{\n  \"experiment_kind\": \"text_only\",\n  \"investigation_kind\": \"physics\",\n  \"src_files_modified\": 0,\n  \"new_analysis_scripts_written\": 0,\n  \"agents_md_files_modified\": 0,\n  \"patterns_yaml_modified\": false,\n  \"investigation_id\": \"audit-class-scan-2026-05-18-T87\",\n  \"stage_advancing_to\": \"Observe\",\n  \"flow_template\": \"audit-class-scan\",\n  \"patterns_scanned_count\": <int, must be 10>,\n  \"findings_total_count\": <int, sum of filtered counts across all 10 patterns>,\n  \"mechanical_fix_now_count\": <int>,\n  \"investigation_eligible_count\": <int>,\n  \"no_action_rationalized_count\": <int>,\n  \"no_finding_count\": <int>,\n  \"l3_proposals_count\": <int, 0 if steady-state>,\n  \"new_active_pattern_swept_lp2_count\": <int, raw count for topology-function-WHAT-comment-pattern this cycle>,\n  \"hardcoded_magic_number_raw_count\": <int, raw 1e-30 count this cycle for telemetry; classify as no-action-rationalized regardless>,\n  \"deprecated_name_leak_raw_count\": <int, expected 0 post-T54 batch-fix; if >0 it's a regression>,\n  \"sweep_wall_time_sec\": <float, optional; how long the rg commands took>,\n  \"src_subtree_scanned\": <bool, must be true; sweep covered src/>,\n  \"test_subtree_scanned_where_allowed\": <bool, true if test/ was scanned for patterns whose exclude_paths permit it; false otherwise>,\n  \"agents_md_unchanged\": <bool, must be true>,\n  \"judge_py_unchanged\": <bool, must be true>,\n  \"patterns_yaml_unchanged\": <bool, must be true; T87 Observe does NOT modify the catalog>,\n  \"steady_state_vs_t61\": <bool, true if findings_total_count == T61's findings_total_count (which was 0); false if any diff>,\n  \"manuscript_edited\": false,\n  \"src_edited\": false,\n  \"julia_executed\": false\n}\n```\n\nThe metrics block MUST be a single fenced ```json``` block per judge.py parsing.\n\n=== ANTI-PATTERN GUARDS ===\n\n- Do NOT modify src/, manuscript, memory files, patterns.yaml, state.json, or .claude/agents/scripts.\n- Do NOT execute julia.\n- Do NOT invent counts — every value comes from real Grep tool output.\n- Do NOT propose L3 classes without applying the §F6 4-question rubric.\n- Do NOT use anko-attribution in artifact text.\n- Do NOT use improvised metaphor terminology.\n- Do NOT exceed 2.5M effective tokens.\n- Do NOT skip the sibling-class scan if any NEW finding surfaces.\n\n=== REPORTING DISCIPLINE ===\n\nReport HONESTLY. If a grep pattern surfaces an unexpected finding (e.g., deprecated-name-leak > 0 indicating a regression of the T48 batch-fix), surface it WITHOUT trying to fix it this turn. Triage stage at T88 handles fixes; Observe stage just observes. If you discover an L3-proposal-worthy class, queue it in §3 with the §F6 4-question rubric pre-applied. Critic audit at a later turn decides accept/reject.\n\nIf the sweep is STEADY-STATE (all 10 patterns return same counts as T61 recall), that is the expected and value-positive outcome — confirms T51/T54 prior-cycle fixes held over the 26-turn gap. State this explicitly in §1 closing line.",
 "observable_manifest": {
 "required": [
 "experiment_kind",
 "investigation_kind",
 "src_files_modified",
 "new_analysis_scripts_written",
 "agents_md_files_modified",
 "patterns_yaml_modified",
 "investigation_id",
 "stage_advancing_to",
 "flow_template",
 "patterns_scanned_count",
 "findings_total_count",
 "mechanical_fix_now_count",
 "investigation_eligible_count",
 "no_action_rationalized_count",
 "no_finding_count",
 "l3_proposals_count",
 "new_active_pattern_swept_lp2_count",
 "hardcoded_magic_number_raw_count",
 "deprecated_name_leak_raw_count",
 "src_subtree_scanned",
 "test_subtree_scanned_where_allowed",
 "agents_md_unchanged",
 "judge_py_unchanged",
 "patterns_yaml_unchanged",
 "manuscript_edited",
 "src_edited",
 "julia_executed"
 ],
 "optional": ["sweep_wall_time_sec", "steady_state_vs_t61"],
 "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/patterns.yaml && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_61_audit_class_scan.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_50_audit_class_scan.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_61.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_87.md && test -d /home/suzume/workspace/BEC-simulation/src && test -d /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory && grep -c '^  - id:' /home/suzume/workspace/BEC-simulation/runs/_loop/patterns.yaml | grep -q '^11$' || grep -c '^  - id:' /home/suzume/workspace/BEC-simulation/runs/_loop/patterns.yaml | grep -q '^10$' && echo 'precondition OK: patterns.yaml + T61 template + T50 secondary template + T61 director report + T87 director report + src/ tree + memory dir all present; 10 or 11 pattern ids (active + rejected) ready for T87 audit-class-scan Observe sweep'"
 },
 "success_criteria": [
 {
 "id": "experiment_kind_correct",
 "metric": "experiment_kind",
 "operator": "==",
 "value": "text_only",
 "tolerance": null,
 "rationale": "Observe is text-only Grep sweep; no julia execution."
 },
 {
 "id": "investigation_kind_physics",
 "metric": "investigation_kind",
 "operator": "==",
 "value": "physics",
 "tolerance": null,
 "rationale": "audit-class-scan is loop-infrastructure with kind=physics per T50/T61 precedent."
 },
 {
 "id": "src_unchanged",
 "metric": "src_files_modified",
 "operator": "==",
 "value": 0,
 "tolerance": null,
 "rationale": "Observe must not modify src/. Triage (T88) handles mechanical fixes."
 },
 {
 "id": "no_scripts_added",
 "metric": "new_analysis_scripts_written",
 "operator": "==",
 "value": 0,
 "tolerance": null,
 "rationale": "Observe produces a text report only."
 },
 {
 "id": "no_agents_md_changes",
 "metric": "agents_md_files_modified",
 "operator": "==",
 "value": 0,
 "tolerance": null,
 "rationale": "Observe is a sweep, not a Design/Pilot patch."
 },
 {
 "id": "patterns_yaml_not_modified_in_observe",
 "metric": "patterns_yaml_modified",
 "operator": "==",
 "value": false,
 "tolerance": null,
 "rationale": "patterns.yaml updates (last_scanned, last_count) are queued for T88 Triage stage; T87 Observe does NOT modify the catalog."
 },
 {
 "id": "investigation_consistent",
 "metric": "investigation_id",
 "operator": "==",
 "value": "audit-class-scan-2026-05-18-T87",
 "tolerance": null,
 "rationale": "Investigation continuity."
 },
 {
 "id": "stage_consistent",
 "metric": "stage_advancing_to",
 "operator": "==",
 "value": "Observe",
 "tolerance": null,
 "rationale": "§F6 Observe stage; first stage of audit-class-scan template."
 },
 {
 "id": "template_consistent",
 "metric": "flow_template",
 "operator": "==",
 "value": "audit-class-scan",
 "tolerance": null,
 "rationale": "§F6 audit-class-scan template."
 },
 {
 "id": "all_ten_patterns_scanned",
 "metric": "patterns_scanned_count",
 "operator": "==",
 "value": 10,
 "tolerance": null,
 "rationale": "patterns.yaml has 10 active patterns as of 2026-05-18T17:52 (same as T61 catalog). Researcher must sweep all 10."
 },
 {
 "id": "deprecated_name_leak_no_regression",
 "metric": "deprecated_name_leak_raw_count",
 "operator": "==",
 "value": 0,
 "tolerance": null,
 "rationale": "T48 batch-fix landed and T50/T61 recalls reported 0 hits. T87 must also report 0; any nonzero value is a regression that T88 Triage must address."
 },
 {
 "id": "src_subtree_was_swept",
 "metric": "src_subtree_scanned",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "Sweep scope must include src/ (primary)."
 },
 {
 "id": "agents_md_unchanged_bool",
 "metric": "agents_md_unchanged",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "Observe must not touch .claude/agents/."
 },
 {
 "id": "judge_py_unchanged_bool",
 "metric": "judge_py_unchanged",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "Observe must not touch .claude/scripts/judge.py."
 },
 {
 "id": "patterns_yaml_unchanged_bool",
 "metric": "patterns_yaml_unchanged",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "Observe must not touch patterns.yaml (T88 Triage handles last_scanned/last_count updates)."
 },
 {
 "id": "no_manuscript_polish",
 "metric": "manuscript_edited",
 "operator": "==",
 "value": false,
 "tolerance": null,
 "rationale": "Per feedback_manuscript_is_not_the_essence, manuscript NOT in scope."
 },
 {
 "id": "no_src_modification",
 "metric": "src_edited",
 "operator": "==",
 "value": false,
 "tolerance": null,
 "rationale": "Observe is text-only sweep."
 },
 {
 "id": "no_julia_execution",
 "metric": "julia_executed",
 "operator": "==",
 "value": false,
 "tolerance": null,
 "rationale": "Observe is text-only Grep sweep."
 },
 {
 "id": "findings_total_count_within_expected_band",
 "metric": "findings_total_count",
 "operator": "<=",
 "value": 200,
 "tolerance": null,
 "rationale": "T61 reported 0 actionable findings; T87 should be similar (0-10 expected for steady-state). Upper bound 200 catches catastrophic regression (e.g. accidental deprecated-name-leak avalanche from a recent refactor) while leaving headroom for natural drift."
 },
 {
 "id": "l3_proposals_audited_via_rubric",
 "metric": "l3_proposals_count",
 "operator": "<=",
 "value": 3,
 "tolerance": null,
 "rationale": "T50 produced 2 L3 proposals (LP-1 rejected, LP-2 accepted), T61 produced 0. T87 expected 0-1 (steady-state). >3 indicates the rubric isn't being applied (over-proposing); <=3 is safe."
 }
 ],
 "failure_modes": [
 {
 "if": "all success_criteria PASS (steady-state sweep, 0-10 findings, all patterns covered)",
 "category": "success (audit cycle Observe stage complete; cycle continues to T88 Triage)",
 "next_action": "T88 director: dispatch implementer_text Triage stage. Job: (a) apply queued patterns.yaml last_scanned + last_count updates from T87 §2 per-pattern notes (10 entries); (b) execute any mechanical-fix-now findings from §2 (expected 0); (c) spawn child investigations for any investigation-eligible findings (expected 0); (d) NO src/ touch unless mechanical-fix-now surfaced. Budget: ~800k-1.2M (mechanical Edit + sed-class). Then T89 Document stage (implementer_text) appends audit_history row to patterns.yaml + memory entry + state.json closure (tier 2; current_stage='closed'); clears AUDIT_DUE drift advisory."
 },
 {
 "if": "deprecated_name_leak_raw_count > 0 (regression of T48 batch-fix)",
 "category": "operational (regression class — sibling-class scan failed to hold)",
 "next_action": "T88 director: dispatch implementer_text REGRESSION REPAIR turn. Read T87 §2 deprecated-name-leak subsection for the surfaced instances. Apply batch-fix using the same pattern as T48 (Edit + sibling grep). Then proceed to Triage at T89. Tier rolls back to 0; cycle restarts at Observe T90 to verify the fix held."
 },
 {
 "if": "findings_total_count > 200 (catastrophic regression — e.g. accidental deprecated-name-leak avalanche)",
 "category": "operational (audit cycle revealed major debt drift)",
 "next_action": "T88 director: spawn dedicated fix-bug investigation for the dominant pattern's class. audit-class-scan-T87 stays at Observe-only tier 0; full triage deferred until the dominant class is resolved (could take 3-5 turns). The audit cycle becomes a 2-investigation cycle: child fix-bug + parent audit Triage."
 },
 {
 "if": "researcher proposes >3 L3 related_classes (over-proposing without §F6 rubric discipline)",
 "category": "operational (rubric not being applied; safety rail engaged)",
 "next_action": "T88 director: dispatch critic L3_critic_audit stage to apply the §F6 4-question rubric to each proposal. Most likely outcome: 2-3 REJECT-WITH-RATIONALE (logged to proposed_classes rejected list); 0-1 ACCEPT-TO-ACTIVE. Tier holds at 0.5; T89 Triage proceeds after critic audit lands."
 },
 {
 "if": "researcher exceeds 2.5M effective cost",
 "category": "operational (over-budget on a routine sweep)",
 "next_action": "T88 director: review researcher token breakdown. Common cause: re-reading full patterns.yaml + multiple turn reports unnecessarily. Re-emphasize targeted reads in next cycle's brief (~T100). Triage proceeds; cost-inflation goes to drift signals."
 },
 {
 "if": "researcher modifies patterns.yaml (anti-pattern)",
 "category": "operational (constraint violation — Triage is the only stage allowed to modify patterns.yaml)",
 "next_action": "T88 director: review the modification. If it was just last_scanned/last_count (T88's job), accept and continue. If it was anything else (new pattern added without critic audit), revert and dispatch tighter T89 with explicit anti-modification clause."
 },
 {
 "if": "researcher surfaces a NEW finding (one not present at T61) WITHOUT performing the sibling-class scan",
 "category": "operational (feedback_fix_the_class_not_the_instance violation)",
 "next_action": "T88 director: dispatch implementer_text quick sibling-class scan turn (Bash + Grep). If sibling found, batch-fix at T89. If not, single-instance fix at T88 Triage."
 }
 ],
 "tolerance_overrides": {
 "cost_cap_effective": 2500000,
 "expected_steady_state": "findings_total_count == 0 (T61 result); cost_eff ~2.0M (T61 = 1.96M)"
 },
 "budget": {
 "expected_cost_eff": 2000000,
 "expected_wall_time_sec": 720,
 "split_by_subtask": {
  "required_reading_patterns_yaml_and_prior_reports": 350000,
  "grep_invocations_10_patterns": 600000,
  "per_pattern_writeup_10_subsections": 700000,
  "scope_section_l3_proposals_metrics_block": 250000,
  "self_review_and_cleanup": 100000
 }
 },
 "investigation_update": {
 "if_success_advance_to_stage": "Findings (folded into Observe; T88 Triage next)",
 "if_success_tier_becomes": 0.5,
 "if_partial_success_advance_to_stage": "Observe (T88 retry with corrected scope)",
 "if_partial_success_tier_becomes": 0.0,
 "if_refuted_advance_to_stage": "n/a (audit-class-scan has no hypothesis to refute; only per-pattern grep findings)",
 "if_refuted_tier_becomes": 0.0,
 "if_inconclusive_advance_to_stage": "Observe (T88 expanded scope)",
 "if_inconclusive_tier_becomes": 0.0,
 "next_falsifier_to_test_after": "n/a — audit-class-scan does not use falsifier framework. Per-pattern findings table at §2 is the deliverable."
 },
 "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read scheduler_87.json (decision=go, policy=JULIA_GPU_OK, researcher in allowed_workloads, window 1.14M sec remaining)
- [x] Read state.json T86 history + all 14 investigation blocks + active_investigation_id + investigations_index (EdH confirmed closed at Tier 3.0; no priority-1 physics in-flight; audit-class-scan-T87 is correct new spawn)
- [x] Read seed.md (hard constraint about parallel julia processes is from 2026-05-15 morning; T87 scheduler shows foreign_julia=0, so the constraint window has passed; researcher Observe is text-only anyway)
- [x] Read prior director turn (T86) end-to-end including its §6 contract + failure_modes.if_all_success.next_action which pre-routed T87 to audit-class-scan
- [x] Read T86 sim/turn_86.md + judge/turn_86.json to confirm EdH terminal closure landed cleanly (7/7 Phase 1, tier 3.0, current_stage 'closed')
- [x] Read T61 director.md + research/turn_61_audit_class_scan.md as APC template skeleton (n_seen=2 for audit-class-scan::Observe)
- [x] Read patterns.yaml structure + audit_history (10 active patterns; last full sweep T61, closed T63; gap=24 turns)
- [x] Read ≥1 memory file related to this investigation: feedback_fix_the_class_not_the_instance, feedback_mechanical_vs_investigation_threshold, feedback_cost_overhead_is_the_cost, feedback_manuscript_is_not_the_essence
- [x] investigation_id `audit-class-scan-2026-05-18-T87` is NEW spawn; spawn_at_turn=87, kind=physics, flow_template=audit-class-scan, priority=20 (matches T50/T61 precedent)
- [x] stage_advancing_to = Observe is the first stage of §F6 (canonical for NEW investigation)
- [x] subagent_type `researcher` matches §F6 Observe role
- [x] researcher_depth = shallow (per §F1 default for non-PDF non-external work; sweep is pure src/ grep)
- [x] success_criteria are machine-evaluable (19 criteria, each maps to a boolean/int/float field that judge.py will read from sim/turn_87.md §6 Metrics block — same field set as T61 with steady_state_vs_t61 added)
- [x] failure_modes cover: success path, deprecated-name-leak regression, catastrophic finding avalanche, L3 over-proposing, budget overrun, patterns.yaml constraint violation, sibling-scan miss (7 modes)
- [x] observable_manifest precondition_check is concrete (test -f on 5 files + test -d on 2 directories + grep -c verifies 10 or 11 pattern ids in patterns.yaml)
- [x] budget 2.0M expected fits within scheduler 1.14M sec window and 2.5M hard cap (T61 actual = 1.96M precedent)
- [x] §A6 research-first citation present (12 distinct citations: T61 director + sim, T50 sim, T86 director, T86 sim, T86 judge, patterns.yaml, director.md §F6 + §B5, 4 feedback memories, APC cache lineage)
- [x] §A5 D1/D2/D3 articulated: D2 service axis (loop-infrastructure debt audit) with explicit D1-protection rationale (catches regressions that would mask future physics verification work); manuscript NOT primary
- [x] investigation_update field updates current_stage (Observe → Findings folded → next is Triage) AND tier_current (0 → 0.5) correctly per success path
- [x] No meta-investigation spawned (audit-class-scan is the canonical §F6 routing for AUDIT_DUE; meta-cost-waste-audit (priority 15) deferred to T90+ after audit cycle closes)
- [x] No manuscript polish in scope (per `feedback_manuscript_is_not_the_essence`)
- [x] No anko-attribution in brief text (per `feedback_no_anko_attribution_in_prompts`)
- [x] No improvised metaphor terminology (per `feedback_no_improvised_terminology`)
- [x] APC contract template cache leveraged: T61 §6 skeleton reused with only timestamp + investigation_id deltas, per arXiv:2506.14852 cost-reduction pattern
