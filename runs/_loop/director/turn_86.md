---
turn: 86
subagent: director
investigation_id: edh-eu151-vortex-vs-matsui-science-2026
stage_advancing_from: Document-verify (T85 FAIL_OPERATIONAL — Phase 1 Check 6 surfaced 3 by_tag working-tree/index divergences; Phase 2/3 patching not executed; tier held at 2.75)
stage_advancing_to: Document-verify (T86 repeat-stage with corrected contract — restore 3 stale by_tag files from index, re-run Check 6, execute Phase 2 state.json patch + Phase 3 status narrative append; terminal Tier 2.75 → 3.0)
topic_tags: [d1-verification-depth, edh-eu151-matsui-science-2026, tier3-pipeline, verify-claim-document-verify-retry, terminal-closure, mechanical-repair, by-tag-index-working-tree-divergence, third-tier3-trajectory]
paper_section: null
depends_on: [85, 84, 83, "runs/_loop/director/turn_85.md", "runs/_loop/sim/turn_85.md", "runs/_loop/judge/turn_85.json", "runs/_loop/director/turn_84.md", "runs/_loop/sim/turn_84.md", "runs/_loop/judge/turn_84.json", "runs/_loop/state.json", "runs/_loop/_local/scheduler_86.json", "runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md", "runs/_loop/by_tag/edh-eu151-matsui-science-2026.md", "runs/_loop/by_tag/edh-eu151.md", "runs/_loop/by_tag/matsui-science-2026.md", "runs/_loop/by_tag/matsui-2026.md", "memory:edh_matsui_baseline_2026_05_18", "memory:feedback_mechanical_vs_investigation_threshold", "memory:feedback_cost_overhead_is_the_cost", "memory:feedback_manuscript_is_not_the_essence"]
produces: "T86 corrected-contract retry of Document-verify for edh-eu151-vortex-vs-matsui-science-2026. Single implementer_text dispatch: (1) write 3 sibling by_tag files (edh-eu151.md, matsui-science-2026.md, matsui-2026.md) from the exact corrective content already produced by T85 implementer §`Check 6 failure analysis`, (2) re-run all 7 Phase 1 checks (now 7/7 expected PASS), (3) execute Phase 2 state.json patch (tier 2.75 → 3.0, current_stage → closed, stages_done append, last_turn 85→86, closing_note terminal stamp), (4) execute Phase 3 status narrative append (T86 PASS row referencing T85 root-cause). Project's 3rd Tier-3 trajectory terminal closure (after barnett T29 and klaus-bch-leak T59) — 1st lab-paper benchmark (Matsui Science 2026)."
---

# Turn 86 — Director Report

## 1. Investigation state snapshot

- **Active investigation (continuing)**: `edh-eu151-vortex-vs-matsui-science-2026` (state.json `active_investigation_id` line 1565; investigation block lines 2147-2225). priority 1, kind physics, flow_template verify-claim, tier_current 2.75, tier_target 3, blocked_on null.
- **Stage transition**: per §B3 verdict-routing table, T85 verdict = **FAIL_OPERATIONAL** → "repeat current stage with corrected contract". T86 repeats **Document-verify** with corrective scope expanded to first restore the 3 stale by_tag files, then complete the un-executed Phase 2/3 patching that T85 stopped before.
- **Tier**: 2.75 → **3.0** (terminal) targeted this turn. Same target as T85; T85 just stopped at Phase 1 per protocol when Check 6 failed.
- **What T85 left behind** (read this turn from `runs/_loop/sim/turn_85.md` + `runs/_loop/judge/turn_85.json`):
  - 6 of 7 Phase 1 checks PASS (state.json parse, EdH block fields, memory file 11 sections, class-finding, 4 errata, status narrative T83+T84 entries).
  - **Check 6 FAIL**: 3 sibling by_tag working-tree files (`edh-eu151.md`, `matsui-science-2026.md`, `matsui-2026.md`) do not have T84 entries on disk. Root cause diagnosed in `sim/turn_85.md §Check 6 failure analysis`: T84 implementer staged edits via Edit/Write tools, edits exist in git index (`AM` status), but working-tree files are pre-T84 content. The primary file `edh-eu151-matsui-science-2026.md` is fine (PASS at T85 + already has T85 row auto-appended by the judge pipeline at the line 20 of that file).
  - Phase 2 (state.json patch) and Phase 3 (status narrative append) NOT executed per directive's STOP-on-FAIL rule.
- **Falsifier status unchanged from T85**: F3 CORROBORATE at 8.0% rel_error (T83). F1 NOT_APPLICABLE_NO_RING (T82-T83). F2/F4 deferred.
- **Other in-flight investigations** (priority-ordered, unchanged from T85 snapshot):
  | id | priority | tier | stage | notes |
  |---|---|---|---|---|
  | **edh-eu151-vortex-vs-matsui-science-2026** | **1** | **2.75 → 3.0 this turn (terminal)** | **Document-verify (T86 retry)** | active |
  | barnett-mechanism-2026-05-16 | 1 | 3.0/3 | closed | 1st Tier-3 (T29) |
  | klaus-magnetostir-bch-leak-2026-05-13 | 3 | 3.0/3 | closed | 2nd Tier-3 (T59) |
  | judge-in-operator-bug-2026-05-18 | 2 | 2.0/2 | closed | done |
  | audit-due-heuristic-bug-2026-05-18 | 4 | 2.0/2 | closed | done |
  | meta-internal-b-unification-2026-05-18 | 5 | 1.0/1 | closed | done |
  | tier3-verification-pipeline-survey-2026-05-18 | 10 | 1/1 | Document (deferred) | parent of EdH |
  | meta-cost-waste-audit-2026-05-18 | 15 | 0/1 | Observe (auto-spawn) | candidate T87+ |
  | meta-director-self-audit-2026-05-18 | 20 | 0/1 | Observe (auto-spawn) | candidate T87+ |
  | meta-cost-inflation-2026-05-18 | 40 | 0/1 | Observe (auto-spawn) | deferred |
  | meta-critic-placement-2026-05-17 | 50 | 0/2 | Observe | deferred |
- **Scheduler** (`runs/_loop/_local/scheduler_86.json` read this turn): decision `go`, policy `JULIA_GPU_OK`, allowed_workloads include `implementer_text` (line 18). Window ends 2026-05-31T23:59 JST with **1,146,136 sec (13.27 days) remaining**. Probe: VRAM 12,702 MB free, RAM 25.06 GB avail, GPU util 1%, foreign_julia 0. Document-verify retry is text-only — trivial fit.
- **Drift escalation** (state.history T85 line 1540): `advisory`. Drift signals:
  - `topic_repetition` 0.278 (EdH for 8 turns; expected for a terminal-closing investigation).
  - `subagent_repetition` 0.333 (steady mix).
  - `manuscript_delta_zero` 1.0 — advisory only per `feedback_manuscript_is_not_the_essence`.
  - `code_delta_zero` 0.0 (T85 had no src changes per design).
  - `verdict_drift` 0.2 (one FAIL_OPERATIONAL at T85 in last 5 turns).
  - `cost_inflation` 0.886 (close to recent baseline; T85 was 1.66M = 2.22× expected 750k due to cost-overhead of reading + diagnosing the divergence; T86 should be lighter since T85 already diagnosed the root cause and gave the corrective content verbatim).
  - `novel_claim_zero` 0.0.
  - **AUDIT_DUE**: gap 22. **Still deferred to T87** (post-EdH terminal closure) per the priority-1-first sequencing precedent (T59→T60→T61 pattern).
- **Why this is the right move (not switch, not noop)**:
  - **Not switch**: EdH at tier 2.75 with all artifacts staged in git + T85 implementer's corrective content already produced verbatim. T86 retry is the cheapest path to lock in Tier 3.0. Switching to audit-class-scan (priority 20) or a meta-investigation (priority 15+) would leave EdH dangling at 2.75 indefinitely.
  - **Not noop**: T85 left the implementer's corrective content (verbatim) in `sim/turn_85.md`. Executing it is 1-3 file Writes + 2 Edits + re-run Phase 1. Cheap, mechanical, value-positive.
  - **Repeat with correction** is canonical §B3 routing for FAIL_OPERATIONAL.
- **Cost frame**: T85 cost 1.66M (2.22× expected 750k) — the cost overhead came from reading 7 artifacts + diagnosing the working-tree/index divergence. T86 retry inherits the diagnosis for free (already in `sim/turn_85.md §Check 6 failure analysis` + the verbatim content for the 3 files). Expected T86 cost: ~800k-1.1M effective (lighter than T85 since most reads can be skipped — T85 already did the discovery work). Hard cap 1.5M.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T83 | Update (critic deep-audit on T82 OPERATIONAL_GATE) | CRITIC_PASS, CORROBORATE_WITH_ERRATA (1.932M) | critic re-derived E_mf/N = 10.57 ✓; src/analysis/energy.jl audited as INTENSIVE per-atom by construction; F3 rel_error 8.0% << 20% → CORROBORATE; 4 errata; tier_recommendation 2.75. |
| T84 | Document (implementer_text) | PASS (1.574M) | 5 artifacts: new memory file `edh_matsui_baseline_2026_05_18.md`; state.json patch tier 2.5→2.75 + closing_note + errata_resolved; 4 by_tag indices appended (primary `edh-eu151-matsui-science-2026.md` PLUS 3 siblings); status narrative T83+T84 entries. Judge: 12/12 success_criteria PASS. **HOWEVER**: T84 implementer's edits to the 3 sibling by_tag files apparently landed in git index but not on working tree — surfaced only at T85 Check 6. T84 judge PASS based on metrics implementer self-reported; metrics did not check on-disk-match-index. |
| T85 | Document-verify (implementer_text) | **FAIL_OPERATIONAL** (1.665M, BUDGET_BUSTED 2.22×) | Phase 1 Check 6 surfaced 3 by_tag working-tree/index divergences. Per directive's STOP-on-FAIL rule, Phase 2 (state.json tier patch) and Phase 3 (status narrative append) NOT executed. tier remained 2.75. Implementer produced verbatim corrective content for the 3 files in `§Check 6 failure analysis` and recommended T86 repair. Status narrative T85 FAIL_OPERATIONAL row already auto-appended by judge pipeline (visible at primary by_tag index line 20). |

Cumulative trajectory: T70 (researcher_deep PDF) → T71 (researcher_deep refine) → T72 (theorist quantitative bands) → T73 (Design) → T74-T81 (Execute retries + R2 PASS) → T82 (Analyze) → T83 (Update CORROBORATE) → T84 (Document) → T85 (Document-verify FAIL_OPERATIONAL Check 6) → **T86 (Document-verify retry with correction; this turn)**.

## 3. Flow template recall

- **Template**: `verify-claim` (§F1). Sequence: Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed. Document-verify is the lightweight artifact-validation sub-stage that locks tier from 2.75 → 3.0.
- **Verdict-driven routing per §B3**:
  - T85 verdict = `FAIL_OPERATIONAL` → "repeat current stage with corrected contract"
  - Corrected contract for T86: restore the 3 by_tag files first (the 1 thing T85 lacked), then proceed identically.
- **Role for Document-verify**: `implementer_text` (text-only file restoration + state.json Edit + status narrative append). Allowed under scheduler `JULIA_GPU_OK` (text workloads are a subset).
- **Why this stage now (not different investigation, not noop)**:
  - T85 implementer DID the discovery + diagnosis work; the corrective content for the 3 files is already in `runs/_loop/sim/turn_85.md` lines 76-106 verbatim. Walking away from this leverage = wasted T85 cost.
  - EdH at tier 2.75 is the project's only open priority-1 investigation. Closing it at Tier 3.0 unblocks the T87+ scheduler to start audit-class-scan (cadence trigger) or F1 longer-dynamics rerun or meta-investigation work.
  - Repeat-with-correction is shorter than start-from-scratch because the T85 implementer left the corrective payload visible.
- **Why NOT skipping the verification turn and just patching state.json without by_tag fix**:
  - The verification (Check 6) is load-bearing — it would just FAIL again next time something scans by_tag indices for the T84 entry. The 3-file restore is the actual root-cause fix.
  - Also: §A2 hard constraint, director cannot Write to anything but the director turn file.
- **Why NOT spawning a meta-investigation about why T84 edits didn't persist to working tree**:
  - Per `feedback_mechanical_vs_investigation_threshold`: a 3-file restore from staged git content + 1 state.json field patch + 1 status append is a mechanical fix, not a multi-stage investigation. Success criterion is "Check 6 returns 4 PASS instead of 1 PASS, tier reaches 3.0". 3-second test passed.
  - If the pattern recurs (T84-like edits landing in index but not on disk) in any future turn, THEN spawn audit-class-scan with a pattern entry for "Edit/Write tool produces AM status indicating workspace divergence". For now, single instance.

## 4. Research grounding (§A6)

T86 dispatch citations (≥1 external reference per §A6):

1. **`runs/_loop/sim/turn_85.md` lines 50-106** — T85 implementer's verbatim corrective content for the 3 by_tag files + the diagnosis "AM = Added to index (staged), but working tree has different (older) content". T86 inherits this diagnosis and uses the verbatim file content. This is the single most load-bearing reference.

2. **`runs/_loop/judge/turn_85.json` lines 4-13 + lines 156-165** — judge's enumerated issues list pinpointing the exact 8 boolean-flag-failures. T86 brief explicitly targets each one.

3. **`runs/_loop/director/turn_85.md` §6 `failure_modes.if phase_1_checks_passed < 7`** — T85 director's pre-planned routing for the exact failure that occurred: "T86 director: dispatch implementer_text repair turn — read sim/turn_85.md §1 to identify which check(s) failed, route appropriate repair. If by_tag index missing T84 → append T84 row. Tier holds at 2.75 (T85 did not lock in terminal closure); retry T86 with repaired artifacts." T86 executes exactly this routing.

4. **`runs/_loop/director/turn_60.md` (analogous post-fail repair pattern)** — when a verification turn surfaces an operational issue (T60 was a clean repair turn after meta-stage-routing closed with confounder), the canonical pattern is single small implementer_text dispatch with explicit success criteria. T86 mirrors that small + scoped shape.

5. **`runs/_loop/sim/turn_84.md` §1-§5** — T84 implementer self-report listing the 5 artifacts that were supposedly produced; cross-referencing against T85 Check 6 result reveals that 3 of 4 by_tag edits did not persist to working tree. T86 verifies all 4 by_tag files post-repair.

6. **Memory `edh_matsui_baseline_2026_05_18.md`** — the durable record T85 already verified at 11 sections + 4 errata + class-finding intact (Checks 3/4/5 PASS). T86 leaves it untouched.

7. **Memory `feedback_mechanical_vs_investigation_threshold.md` (2026-05-18)** — "3-second test: success criterion = `jq parse exits 0 && grep <T84> 4 by_tag files returns 4 PASS && state.json tier == 3.0`. Predictable outcome. Just execute." T86 IS a 3-second-test passing mechanical repair turn.

8. **Memory `feedback_cost_overhead_is_the_cost.md` (2026-05-15)** — "Deliberating about whether to do the mechanical fix costs more than executing it." T85 already paid the discovery cost (1.66M); T86 executes the prescribed remedy.

9. **Memory `feedback_manuscript_is_not_the_essence.md` (2026-05-15)** — T86 scope: 3 by_tag Writes + 1 state.json Edit + 1 status narrative append. NO manuscript, NO docstring, NO src.

10. **Memory `feedback_fix_the_class_not_the_instance.md` (2026-05-18)** — "When ONE instance of a problem class surfaces, immediately grep for siblings codebase-wide." T86 brief includes a sibling-class scan step (`git status` filter for `AM` entries) — if any OTHER index-vs-working-tree divergences exist, surface them in §3 of `sim/turn_86.md`; defer fix to T87+ if not load-bearing to EdH closure.

11. **Director.md §F1 verify-claim Document row + closed row** — "closed: tier_current >= tier_target; investigation done". T86 advances tier_current to 3 = tier_target → terminal closure condition met by definition.

12. **APC contract template cache** — `physics::verify-claim::Document-verify-retry` is a new skeleton variation on T85's `Document-verify`. The structural delta is: T86 contract adds 3 file Writes (restore from index content) BEFORE re-running Phase 1, otherwise identical to T85. Director carries forward T85's success_criteria block and observable_manifest with this delta.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verification axis — primary)**. T86 locks in the 3rd Tier-3 trajectory for the project. The tier ladder hits Tier 3.0 = "published-reference benchmarked" specifically Matsui et al. Science 391, 384-388 (2026) Eu-151 EdH paper.
- **Tier ladder position after T86 (anticipated)**:
  - EdH: 2.75 → **3.0** (terminal). `current_stage = closed`.
  - Project Tier-3 count: **3 investigations at Tier 3.0**.
- **Project D1 verification depth narrative** (post-T86):
  - T29: 1st Tier-3 (Barnett, internal-framework re-derivation).
  - T59: 2nd Tier-3 (Klaus BCH leak, cross-implementation).
  - **T86: 3rd Tier-3 (EdH Eu-151 F3 vs Matsui 2026 Science 391:384)** — first explicit lab-paper benchmark.
- **Manuscript NOT in scope** (per `feedback_manuscript_is_not_the_essence`). T86 writes to 3 by_tag files (restore from T85's verbatim content) + state.json + status narrative ONLY.
- **Cost frame**: target ~800k-1.1M effective (lighter than T85's 1.66M because diagnosis is done; T86 is mostly Writes + a re-run of Phase 1 checks). Hard cap 1.5M. cost_inflation should improve from 0.886 → ~0.7.
- **Drift trajectory after T86 (anticipated)**:
  - cost_inflation: 0.886 → ~0.7 (improvement).
  - code_delta_zero: 0.0 → 1.0 (pure-text turn).
  - manuscript_delta_zero: 1.0 (correctly, by design).
  - novel_claim_zero: 0.0 (T86 lands the terminal-closure stamp).
  - topic_repetition: 0.278 → ~0.31 (EdH for one more turn).
  - verdict_drift: 0.2 → 0.0 (T86 PASS resets the count).
- **Recommended T87+ trajectory** (informational): same as T85's recommendation, shifted by 1 turn:
  1. **audit-class-scan-2026-05-18-T87** (AUDIT_DUE gap=23, mandatory at T87).
  2. **F1 longer-dynamics rerun** (~3M GPU, ~90 min wall).
  3. **meta-cost-waste-audit-2026-05-18** Hypothesize.
  4. **meta-director-self-audit-2026-05-18** Hypothesize.

## 6. Dispatch decision (declarative contract)

```json
{
 "investigation_id": "edh-eu151-vortex-vs-matsui-science-2026",
 "stage_advancing_to": "Document-verify (T86 retry — restore 3 stale by_tag files from verbatim T85 corrective content, re-run Phase 1 checks now 7/7, execute Phase 2 state.json terminal-closure patch tier 2.75 → 3.0 + current_stage 'closed', execute Phase 3 status narrative T86 PASS append; terminal Tier-3 trajectory closure)",
 "subagent_type": "implementer_text",
 "researcher_depth": null,
 "parallel_researcher_count": 0,
 "rationale": "T85 verdict FAIL_OPERATIONAL: Phase 1 Check 6 surfaced 3 by_tag working-tree/index divergences; T85 implementer stopped at Phase 1 per directive's STOP-on-FAIL rule and produced verbatim corrective content for the 3 files in sim/turn_85.md §Check 6 failure analysis lines 76-106. Per §B3 verdict-routing FAIL_OPERATIONAL → repeat current stage with corrected contract. T86 retry: write the 3 files using T85's verbatim content, re-run all 7 Phase 1 checks (now 7/7 expected), then execute the un-completed Phase 2 (state.json patch tier 2.75 → 3.0 + current_stage closed) and Phase 3 (status narrative T86 append). 3 Writes + 1 Edit + 1 Append. ~800k-1.1M effective expected, well under 1.5M cap. Project's 3rd Tier-3 trajectory closes — 1st lab-paper benchmark (Matsui Science 391:384, 2026).",
 "brief": "## ROLE\n\nYou are implementer_text. T86 §F1 Document-verify-retry sub-stage of edh-eu151-vortex-vs-matsui-science-2026 (verify-claim flow). T85 hit FAIL_OPERATIONAL at Phase 1 Check 6 because 3 sibling by_tag files have working-tree content predating T84 (T84 staged the edits to git index but they did not persist to disk). T85 implementer produced verbatim corrective content in `sim/turn_85.md §Check 6 failure analysis`. T86 retries with the corrective Writes prepended.\n\nDIRECTIVE_LABEL: edh-matsui-document-verify-T86-tier-3-0-retry-by-tag-restore\n\n=== HARD CONSTRAINTS ===\n\n- Allowed tools: Read, Glob, Grep, Bash (jq parse + grep counts + git status filter ONLY — NO julia, NO destructive git ops), Write (3 by_tag files specifically), Edit (state.json + status narrative).\n- Files allowed to CREATE/WRITE: `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_86.md` (your implementer report).\n- Files allowed to WRITE-OVER (using Write tool): `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/edh-eu151.md`, `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/matsui-science-2026.md`, `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/matsui-2026.md` — exact content from `sim/turn_85.md` §Check 6 failure analysis lines 76-106 (with T86 entry appended).\n- Files allowed to MODIFY (Edit only): `runs/_loop/state.json` (targeted Edit on EdH block only), `runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md` (append-only).\n- Files MUST NOT be touched: `src/`, `runs/eu151_*/`, `runs/matsui_edh_baseline_*/`, `scripts/diagnostic/*`, `.claude/agents/*`, `.claude/scripts/*`, `.claude/workload_specs.yaml`, `quota_config.json`, any `.claude/settings*.json`, any memory file (T84 memory file is the durable record), the primary by_tag index `edh-eu151-matsui-science-2026.md` (already correct + already has T85 row).\n- NO julia execution.\n- NO new memory files.\n- NO manuscript edits (per feedback_manuscript_is_not_the_essence).\n- NO src modifications.\n- English only. No emojis.\n- Absolute paths in all tool calls.\n- Cost budget: stay within 1.5M effective tokens, ~10 min wall hard cap.\n- NO fabrication: every reported metric must come from real Bash/Grep/jq output.\n\n=== REQUIRED READING (READ BEFORE ANY WRITE) ===\n\nRead in order:\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_86.md` (this file) §1, §3, §6.\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_85.md` lines 50-106 — the verbatim corrective content for the 3 by_tag files (you will use this exact content).\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_85.json` lines 1-50 — the explicit list of failed criteria.\n4. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_85.md` §6 — the original T85 contract (your Phase 1/2/3 spec is unchanged; the only additional step is Phase 0 = restore 3 by_tag files).\n5. `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/edh-eu151-matsui-science-2026.md` — primary index, ALREADY correct (working tree matches index, has T84 + T85 row). DO NOT modify.\n6. Current working-tree content of the 3 stale files:\n   - `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/edh-eu151.md` (Total 2, missing T84 row)\n   - `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/matsui-science-2026.md` (Total 2, missing T84 row)\n   - `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/matsui-2026.md` (Total 1, missing T84 row)\n7. `/home/suzume/workspace/BEC-simulation/runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md` — read existing format; T86 appends one narrative entry.\n8. `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` — find the `edh-eu151-vortex-vs-matsui-science-2026` investigation block (lines 2147-2225). Read tier_current=2.75 (still — T85 did not patch it).\n\n=== YOUR JOB — 4 PHASES ===\n\n### Phase 0: BY_TAG INDEX RESTORATION (3 Writes — new this turn)\n\nWrite EXACTLY this content to each of the 3 files (overwriting current working-tree content):\n\n**File: `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/edh-eu151.md`** — overwrite with:\n```\n# tag `edh-eu151` — turn history\n\nTotal: 4\n\n- **T70** [PASS] `edh-eu151-vortex-vs-matsui-spawn-T70`\n- **T71** [RESEARCHER_ONLY] `matsui-science-2026-pdf-extract`\n- **T84** [PASS] `edh-matsui-document-T84-tier-2-75-corroborate-with-errata-closure-path`\n- **T86** [PASS] `edh-matsui-document-verify-T86-tier-3-0-retry-by-tag-restore`\n```\n\n**File: `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/matsui-science-2026.md`** — overwrite with:\n```\n# tag `matsui-science-2026` — turn history\n\nTotal: 4\n\n- **T71** [RESEARCHER_ONLY] `matsui-science-2026-pdf-extract`\n- **T81** [PASS] `edh-matsui-execute-T81-r2-gpu-wrapper-script-workaround`\n- **T84** [PASS] `edh-matsui-document-T84-tier-2-75-corroborate-with-errata-closure-path`\n- **T86** [PASS] `edh-matsui-document-verify-T86-tier-3-0-retry-by-tag-restore`\n```\n\n**File: `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/matsui-2026.md`** — overwrite with:\n```\n# tag `matsui-2026` — turn history\n\nTotal: 3\n\n- **T70** [PASS] `edh-eu151-vortex-vs-matsui-spawn-T70`\n- **T84** [PASS] `edh-matsui-document-T84-tier-2-75-corroborate-with-errata-closure-path`\n- **T86** [PASS] `edh-matsui-document-verify-T86-tier-3-0-retry-by-tag-restore`\n```\n\n(These extend the T85 verbatim content by adding the T86 row — T86 itself is a PASS event per this turn's expected closure.)\n\nPost-Write verification:\n```bash\nfor f in edh-eu151 matsui-science-2026 matsui-2026; do\n  echo \"$f:\"\n  grep -c 'T84' /home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/${f}.md\n  grep -c 'T86' /home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/${f}.md\ndone\n```\nExpected: each file returns 1 for T84 and 1 for T86.\n\n**Sibling-class scan (mandatory per `feedback_fix_the_class_not_the_instance`)**:\n```bash\ncd /home/suzume/workspace/BEC-simulation && git status --porcelain runs/_loop/by_tag/ | head -20\n```\nIf any OTHER by_tag file has `AM` status (index/working-tree divergence) beyond the 3 we are about to fix, list them in §3 of your sim/turn_86.md report; DO NOT fix them this turn unless they affect EdH closure. Report only — defer fix to T87+.\n\n### Phase 1: ARTIFACT VERIFICATION CHECKS (re-run all 7, expect 7/7 PASS)\n\nIdentical to T85 directive's Phase 1, with Check 6 expected to now PASS.\n\n**Check 1: state.json JSON syntax valid**\n```bash\ncd /home/suzume/workspace/BEC-simulation && jq empty runs/_loop/state.json && echo OK_state_json_parses\n```\n\n**Check 2: state.json EdH block has T84-patched fields**\n```bash\ncd /home/suzume/workspace/BEC-simulation && jq '.investigations.\"edh-eu151-vortex-vs-matsui-science-2026\" | {tier_current, last_turn, last_stage, last_verdict, last_critic_turn, errata_pending, errata_resolved_length: (.errata_resolved | length), closing_note_length: (.closing_note | length)}' runs/_loop/state.json\n```\nExpected: tier_current=2.75, last_turn=84 OR 85 (T85 metrics may have been auto-rolled forward by judge), last_verdict='CORROBORATE_WITH_ERRATA' OR similar, errata_resolved_length=4, closing_note_length>200.\n\n**Check 3: memory file has 11 required sections** — same as T85; expected PASS.\n\n**Check 4: memory file has class-level convention finding (INTENSIVE per-atom)** — same as T85; expected PASS.\n\n**Check 5: memory file has 4 errata** — same as T85; expected PASS.\n\n**Check 6: 4 by_tag indices have T84 entry** (this is the previously-failing check):\n```bash\nfor f in edh-eu151-matsui-science-2026 edh-eu151 matsui-science-2026 matsui-2026; do\n  echo \"$f:\"\n  grep -c 'T84' /home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/${f}.md\ndone\n```\nExpected: each file returns count >= 1. Now all 4 PASS post-Phase-0.\n\n**Check 7: status narrative has T83+T84 entries** — same as T85; expected PASS.\n\n**PHASE 1 SUCCESS GATE: 7/7 PASS.** If any FAIL surfaces beyond the previously-known 3 by_tag (i.e., a different check fails), STOP and report. Otherwise proceed.\n\n### Phase 2: state.json TERMINAL CLOSURE PATCH (1 Edit)\n\nIdentical to T85 directive's Phase 2. Use Edit tool with absolute path on `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json`. Target the `edh-eu151-vortex-vs-matsui-science-2026` investigation block. Patch:\n\n- `tier_current`: 2.75 → **3.0**\n- `current_stage`: existing string → **\"closed\"** (canonicalized enum)\n- `stages_done`: append \"Document-verify\" to the array if not already present (preserve existing entries — current array has 11 entries, narrative ones; ensure 'Document-verify' is added if missing). NOTE: the canonical enum is short; do not duplicate.\n- `last_turn`: 84 → **86**\n- `last_stage`: \"Document\" → **\"Document-verify\"**\n- `last_verdict`: \"CORROBORATE_WITH_ERRATA\" → **\"TIER_3_TERMINAL_CLOSURE\"**\n- `closing_note`: existing T84 string → append the terminal-closure sentence: \"Terminal Tier 3.0 closure 2026-05-18 T86 via Document-verify-retry path (T85 hit FAIL_OPERATIONAL on Check 6 due to 3 by_tag working-tree/index divergences from T84; T86 restored the 3 files from T85 verbatim corrective content, re-ran all 7 Phase 1 checks now 7/7 PASS, then executed Phase 2 state.json patch + Phase 3 status narrative append). Project's 3rd Tier-3 trajectory after barnett-mechanism (T29) and klaus-bch-leak (T59) — first explicit lab-paper benchmark closure (Matsui et al. Science 391, 384-388, 2026). F3 CORROBORATE at 8.0% rel_error well within 20% band. F1 NOT_APPLICABLE_NO_RING ratified; F1 longer-dynamics rerun (~3M GPU, 30 dimless = 48 ms physical) deferred to T87+ as optional refinement.\"\n\nPost-Edit verification:\n```bash\njq empty /home/suzume/workspace/BEC-simulation/runs/_loop/state.json && echo OK_state_post_T86_edit\njq '.investigations.\"edh-eu151-vortex-vs-matsui-science-2026\" | {tier_current, current_stage, last_turn, last_stage, last_verdict}' /home/suzume/workspace/BEC-simulation/runs/_loop/state.json\n```\nExpected: tier_current=3.0, current_stage=\"closed\", last_turn=86, last_stage=\"Document-verify\", last_verdict=\"TIER_3_TERMINAL_CLOSURE\".\n\n### Phase 3: STATUS NARRATIVE APPEND (1 Edit)\n\nUse Edit tool on `/home/suzume/workspace/BEC-simulation/runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md`. Append at end-of-file:\n\n```\n### T86 (2026-05-18) — PASS — `edh-matsui-document-verify-T86-tier-3-0-retry-by-tag-restore`\n\n- Stage: **Document-verify (TIER_3_TERMINAL_CLOSURE)**, tier: 2.75 → 3.0\n- Phase 0 repair: 3 by_tag files restored from T85 verbatim corrective content (root cause: T84 Edit/Write produced AM git status — index had T84 entries, working tree did not)\n- Verification: 7/7 mechanical checks PASS (Check 6 now passes after Phase 0 restore)\n- State patch: tier_current 2.75 → 3.0, current_stage \"closed\", last_turn=86, last_stage=\"Document-verify\", last_verdict=\"TIER_3_TERMINAL_CLOSURE\", closing_note extended with terminal-closure stamp + T85→T86 retry rationale\n- Project's 3rd Tier-3 trajectory closure (1st lab-paper benchmark vs Matsui Science 2026)\n- T87 next-action: audit-class-scan-2026-05-18-T87 (AUDIT_DUE gap=23 cadence trigger) OR F1 longer-dynamics rerun OR meta-investigation Hypothesize\n```\n\nMatch existing file format.\n\n=== SUCCESS CRITERIA (machine-evaluable; emit in §4 Metrics block) ===\n\nProduce `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_86.md` with structure:\n\n```markdown\n---\nturn: 86\nsubagent: implementer_text\ndirective_action: verify_and_close\ndirective_label: edh-matsui-document-verify-T86-tier-3-0-retry-by-tag-restore\ninvestigation_id: edh-eu151-vortex-vs-matsui-science-2026\nstage: Document-verify\nverdict: PASS\n---\n\n# Turn 86 — Document-verify retry of edh-eu151-matsui (Tier 2.75 → 3.0)\n\n## §1 Phase 0: by_tag index restoration (3 Writes)\n\n(table: file, lines written, T84 grep, T86 grep)\n\n## §2 Phase 1: Artifact verification checks (7/7)\n\n(table: check, command, expected, actual, PASS/FAIL)\n\n## §3 Sibling-class scan results (mandatory per feedback_fix_the_class_not_the_instance)\n\n(report: git status filter result for runs/_loop/by_tag/; any AM-status files beyond the 3 we fixed; defer-or-not decision)\n\n## §4 Phase 2: state.json terminal closure patch\n\n(field-by-field listing; post-Edit jq verification)\n\n## §5 Phase 3: status narrative append\n\n(brief: line range appended)\n\n## §6 Metrics\n\n```json\n{\n  \"experiment_kind\": \"text_only\",\n  \"workload_class\": \"implementer_text\",\n  \"src_files_modified\": 0,\n  \"new_analysis_scripts_written\": 0,\n  \"investigation_id\": \"edh-eu151-vortex-vs-matsui-science-2026\",\n  \"stage_advancing_to\": \"closed\",\n  \"flow_template\": \"verify-claim\",\n  \"phase_0_files_restored\": <int, must be 3>,\n  \"phase_0_all_3_have_t84_post_write\": <bool, must be true>,\n  \"phase_0_all_3_have_t86_post_write\": <bool, must be true>,\n  \"sibling_am_scan_count\": <int, additional AM-status by_tag files beyond the 3>,\n  \"phase_1_checks_total\": 7,\n  \"phase_1_checks_passed\": <int, must be 7>,\n  \"state_json_jq_parses\": <bool, must be true>,\n  \"state_json_tier_advanced_to_3\": <bool, must be true>,\n  \"state_json_current_stage_is_closed\": <bool, must be true>,\n  \"memory_file_11_sections_present\": <bool, must be true>,\n  \"memory_file_class_finding_present\": <bool, must be true>,\n  \"memory_file_4_errata_present\": <bool, must be true>,\n  \"by_tag_indices_4_have_t84\": <bool, must be true>,\n  \"status_narrative_t83_t84_present\": <bool, must be true>,\n  \"status_narrative_t86_appended\": <bool, must be true>,\n  \"investigation_tier_advanced\": <bool, must be true>,\n  \"final_tier\": <float, must be 3.0>,\n  \"investigation_closed\": <bool, must be true>,\n  \"closing_note_extended\": <bool, must be true>,\n  \"new_memory_files_created\": <int, must be 0>,\n  \"by_tag_indices_modified\": <int, must be 3>,\n  \"manuscript_edited\": <bool, must be false>,\n  \"src_edited\": <bool, must be false>,\n  \"julia_executed\": <bool, must be false>\n}\n```\n\n## §7 Self-review\n\n- [ ] All 7 Phase 1 checks PASS post-Phase-0?\n- [ ] All 3 by_tag files written with T84 + T86 rows?\n- [ ] state.json post-Edit tier_current = 3.0?\n- [ ] state.json post-Edit current_stage = 'closed'?\n- [ ] Status narrative T86 row appended?\n- [ ] No new memory file created?\n- [ ] No src/ modified?\n- [ ] No julia executed?\n- [ ] Cost within 1.5M cap?\n```\n\nReport HONESTLY. If Phase 0 Writes succeed but Phase 1 still fails (different check, e.g. some other file went stale), STOP and document — director will route a tighter T87 repair.\n\n=== ANTI-PATTERN GUARDS ===\n\n- Do NOT modify src/, manuscript, memory files, or .claude/agents/scripts.\n- Do NOT execute julia.\n- Do NOT modify the primary by_tag file `edh-eu151-matsui-science-2026.md` (already correct).\n- Do NOT use git checkout / git reset / git stash to restore files — use Write tool with the verbatim content from T85 sim report. Avoiding git restore commands keeps the change visible in the orchestrator's commit step.\n- Do NOT invent check results — every value comes from real tool output.\n- Do NOT use anko-attribution in artifact text.\n- Do NOT exceed 1.5M effective tokens.\n- Do NOT skip the sibling-class scan in Phase 0.",
 "observable_manifest": {
 "required": [
 "experiment_kind",
 "workload_class",
 "src_files_modified",
 "investigation_id",
 "stage_advancing_to",
 "phase_0_files_restored",
 "phase_0_all_3_have_t84_post_write",
 "phase_0_all_3_have_t86_post_write",
 "phase_1_checks_total",
 "phase_1_checks_passed",
 "state_json_jq_parses",
 "state_json_tier_advanced_to_3",
 "state_json_current_stage_is_closed",
 "memory_file_11_sections_present",
 "memory_file_class_finding_present",
 "memory_file_4_errata_present",
 "by_tag_indices_4_have_t84",
 "status_narrative_t86_appended",
 "investigation_tier_advanced",
 "final_tier",
 "investigation_closed",
 "by_tag_indices_modified",
 "manuscript_edited",
 "src_edited",
 "julia_executed"
 ],
 "optional": [
 "sibling_am_scan_count",
 "status_narrative_t83_t84_present",
 "closing_note_extended",
 "new_memory_files_created"
 ],
 "precondition_check": "cd /home/suzume/workspace/BEC-simulation && test -f runs/_loop/director/turn_85.md && test -f runs/_loop/sim/turn_85.md && test -f runs/_loop/judge/turn_85.json && test -f runs/_loop/state.json && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/edh_matsui_baseline_2026_05_18.md && test -f runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md && test -f runs/_loop/by_tag/edh-eu151-matsui-science-2026.md && test -f runs/_loop/by_tag/edh-eu151.md && test -f runs/_loop/by_tag/matsui-science-2026.md && test -f runs/_loop/by_tag/matsui-2026.md && jq empty runs/_loop/state.json && jq -e '.investigations.\"edh-eu151-vortex-vs-matsui-science-2026\".tier_current == 2.75' runs/_loop/state.json > /dev/null && echo OK_T86_precondition: T85_artifacts_present + state_parses + tier_still_2_75 + 4_by_tag_files_exist"
 },
 "success_criteria": [
 {
 "id": "phase_0_three_files_restored",
 "metric": "phase_0_files_restored",
 "operator": "==",
 "value": 3,
 "tolerance": null,
 "rationale": "Must write exactly 3 by_tag files (edh-eu151.md, matsui-science-2026.md, matsui-2026.md) — the 3 with stale working-tree content per T85 Check 6."
 },
 {
 "id": "phase_0_t84_present_post_write",
 "metric": "phase_0_all_3_have_t84_post_write",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "After Phase 0 Writes, all 3 restored files must have a T84 entry — restores the T84 work that was lost to the working-tree/index divergence."
 },
 {
 "id": "phase_0_t86_present_post_write",
 "metric": "phase_0_all_3_have_t86_post_write",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "After Phase 0 Writes, all 3 restored files must have the T86 entry (this turn) appended — establishes the closure record for the retry turn."
 },
 {
 "id": "all_phase_1_checks_pass",
 "metric": "phase_1_checks_passed",
 "operator": "==",
 "value": 7,
 "tolerance": null,
 "rationale": "All 7 mechanical verification checks now PASS (post-Phase-0 restore unblocks Check 6)."
 },
 {
 "id": "state_json_parses_post_edit",
 "metric": "state_json_jq_parses",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "Post-Edit state.json must remain JSON-valid."
 },
 {
 "id": "tier_advanced_to_3",
 "metric": "state_json_tier_advanced_to_3",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "tier_current must advance from 2.75 to exactly 3.0."
 },
 {
 "id": "investigation_closed_flag",
 "metric": "state_json_current_stage_is_closed",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "current_stage canonicalized to enum 'closed' per state_schema_check.py."
 },
 {
 "id": "final_tier_exact",
 "metric": "final_tier",
 "operator": "==",
 "value": 3.0,
 "tolerance": null,
 "rationale": "Project's 3rd Tier-3 trajectory; tier 3.0 is the terminal value."
 },
 {
 "id": "tier_advance_flagged",
 "metric": "investigation_tier_advanced",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "Boolean confirmation of tier advance."
 },
 {
 "id": "closed_flag",
 "metric": "investigation_closed",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "Investigation terminal closure boolean must be true."
 },
 {
 "id": "by_tag_indices_intact",
 "metric": "by_tag_indices_4_have_t84",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "All 4 by_tag indices have T84 entry post-Phase-0 (was the T85 failure point)."
 },
 {
 "id": "by_tag_indices_modified_exactly_3",
 "metric": "by_tag_indices_modified",
 "operator": "==",
 "value": 3,
 "tolerance": null,
 "rationale": "Exactly 3 by_tag files modified — the 3 stale ones. The primary file edh-eu151-matsui-science-2026.md MUST NOT be modified."
 },
 {
 "id": "memory_file_intact",
 "metric": "memory_file_11_sections_present",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "T84 memory file remains intact (T85 already verified)."
 },
 {
 "id": "class_finding_preserved",
 "metric": "memory_file_class_finding_present",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "Class-level INTENSIVE per-atom finding present (T85 already verified)."
 },
 {
 "id": "errata_preserved",
 "metric": "memory_file_4_errata_present",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "All 4 errata documented (T85 already verified)."
 },
 {
 "id": "status_narrative_appended",
 "metric": "status_narrative_t86_appended",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "T86 narrative entry appended to status file."
 },
 {
 "id": "no_src_modification",
 "metric": "src_edited",
 "operator": "==",
 "value": false,
 "tolerance": null,
 "rationale": "Document-verify-retry is text-only."
 },
 {
 "id": "no_julia_execution",
 "metric": "julia_executed",
 "operator": "==",
 "value": false,
 "tolerance": null,
 "rationale": "Document-verify-retry is text-only."
 },
 {
 "id": "no_manuscript_polish",
 "metric": "manuscript_edited",
 "operator": "==",
 "value": false,
 "tolerance": null,
 "rationale": "Per feedback_manuscript_is_not_the_essence, manuscript NOT in scope."
 }
 ],
 "failure_modes": [
 {
 "if": "all success_criteria PASS",
 "category": "success (Tier 3.0 terminal closure landed; EdH investigation closed cleanly; 3rd project Tier-3 trajectory; 1st lab-paper benchmark)",
 "next_action": "T87 director: spawn audit-class-scan-2026-05-18-T87 (AUDIT_DUE gap=23 cadence trigger; researcher Observe stage running patterns.yaml 10-pattern grep sweep; ~1.2M-1.8M expected). Alternative T87 picks (decreasing priority): F1 longer-dynamics rerun (post-closure refinement; ~3M GPU); meta-cost-waste-audit Hypothesize (priority 15); meta-director-self-audit Hypothesize (priority 20)."
 },
 {
 "if": "phase_0_files_restored < 3 (some Write tool call failed or skipped)",
 "category": "operational (Phase 0 incomplete)",
 "next_action": "T87 director: read sim/turn_86.md §1 to identify which Write(s) did not land. Dispatch single-Write implementer_text repair (~250k effective each). Tier holds at 2.75."
 },
 {
 "if": "phase_1_checks_passed < 7 BUT phase_0 completed (a DIFFERENT check fails beyond the previously-known 3 by_tag)",
 "category": "operational (new failure mode surfaced; sibling-class scan may have under-detected)",
 "next_action": "T87 director: read sim/turn_86.md §2 + §3 to identify the new failure. If memory file went stale (similar AM status divergence), restore via Write. If state.json schema check failed, route a state_schema_check.py-aware Edit turn. Tier holds at 2.75."
 },
 {
 "if": "state.json Edit corrupts JSON (state_json_jq_parses=false post-Edit)",
 "category": "operational (state.json schema_version 2.1, ~2330 lines)",
 "next_action": "T87 director: dispatch implementer_text repair turn using python json.load + json.dump approach to safely re-apply the patch. Tier holds at 2.75."
 },
 {
 "if": "implementer modifies the primary by_tag file (edh-eu151-matsui-science-2026.md) accidentally",
 "category": "operational (over-eager Write)",
 "next_action": "T87 director: review diff. If primary file's T70-T85 history was preserved AND only the T86 row added, accept (re-judge as PASS). If T-history corrupted, restore from git index via Write. Tier holds at 2.75 pending check."
 },
 {
 "if": "implementer surfaces a scientific objection during Phase 1 (memory file content is wrong, F3 CORROBORATE shouldn't have been declared, etc.)",
 "category": "scientific (T83 critic + T84 implementer missed something)",
 "next_action": "DO NOT happen in retry-Document-verify. If implementer raises substantive science objection, STOP — rewind to T83 critic Update with the objection as a new error class. T87 critic re-eval. Tier rolls back to 2.5 pending."
 },
 {
 "if": "sibling_am_scan_count > 0 (other by_tag files also have AM status)",
 "category": "operational class-pattern (defer-or-not decision)",
 "next_action": "T86 closes EdH at Tier 3.0 regardless. T87 director: spawn a follow-up fix-bug investigation 'by-tag-index-AM-divergence-2026-05-18' (small mechanical batch-restore across all stale by_tag files); OR fold into next audit-class-scan as a new pattern in patterns.yaml."
 },
 {
 "if": "implementer_text exceeds 1.5M effective cost",
 "category": "operational (over-budget on a small mechanical turn)",
 "next_action": "T87 director: review sim/turn_86.md token breakdown. Common cause: re-reading the T85 sim full content unnecessarily (large file) instead of just the §Check 6 corrective payload + the small per-file content blocks. Re-emphasize targeted reads in T87 brief."
 }
 ],
 "tolerance_overrides": {
 "cost_cap_effective": 1500000,
 "phase_0_writes_must_be_exact": "verbatim from T85 sim §Check 6 + T86 row append"
 },
 "budget": {
 "expected_cost_eff": 950000,
 "expected_wall_time_sec": 480,
 "split_by_subtask": {
  "reading_t85_and_state": 250000,
  "phase_0_three_writes": 250000,
  "phase_1_seven_checks": 150000,
  "phase_2_state_edit": 150000,
  "phase_3_status_append": 50000,
  "sim_report_authoring": 100000
 }
 },
 "investigation_update": {
 "if_success_advance_to_stage": "closed (terminal Tier 3.0; investigation complete; 3rd project Tier-3 trajectory; 1st lab-paper benchmark — Matsui Science 2026)",
 "if_success_tier_becomes": 3.0,
 "if_partial_success_advance_to_stage": "Document-verify (T87 retry of the un-completed phase)",
 "if_partial_success_tier_becomes": 2.75,
 "if_refuted_advance_to_stage": "Update (rare; would require implementer to surface a science objection during verification)",
 "if_refuted_tier_becomes": 2.0,
 "if_inconclusive_advance_to_stage": "Document-verify (T87 recovery)",
 "if_inconclusive_tier_becomes": 2.75,
 "next_falsifier_to_test_after": "EdH investigation closes at Tier 3.0 on F3 alone. Optional post-closure refinements: F1 longer-dynamics rerun (~3M GPU, 30 dimless = 48 ms physical, ~90 min wall) — best case F1 CORROBORATE adds F1+F3 dual-corroboration. F2 winding ell depends on F1. F4 c_dd=0 control optional. None required for the F3 Tier-3 closure; their pursuit is a separate decision at T87+ based on anko priority."
 },
 "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read state.json (offset-paginated) + scheduler_86.json + seed.md (still relevant — no julia constraint active currently since probe shows foreign_julia=0) this turn
- [x] Read ≥1 memory file related to active investigation (referenced `edh_matsui_baseline_2026_05_18`, `feedback_mechanical_vs_investigation_threshold`, `feedback_fix_the_class_not_the_instance`, `feedback_cost_overhead_is_the_cost`, `feedback_manuscript_is_not_the_essence`)
- [x] Read last 3 turns of THIS investigation: T83 (Update CORROBORATE), T84 (Document PASS), T85 (Document-verify FAIL_OPERATIONAL)
- [x] Read prior director turn (T85) end-to-end including its §6 contract + failure_modes routing
- [x] Read T85 sim/turn_85.md to extract the verbatim corrective content for the 3 by_tag files
- [x] Read T85 judge/turn_85.json to confirm exact failed criteria + metrics
- [x] investigation_id `edh-eu151-vortex-vs-matsui-science-2026` valid in state.investigations
- [x] stage_advancing_to = Document-verify is repeat-stage per §B3 FAIL_OPERATIONAL routing (not advancing forward, not skipping)
- [x] subagent_type `implementer_text` matches verify-claim §F1 Document role + scheduler allowed_workloads
- [x] success_criteria are machine-evaluable (18 criteria, each maps to a boolean/int/float field that judge.py will read from sim/turn_86.md §6 Metrics block)
- [x] failure_modes cover: success path, Phase 0 incomplete, Phase 1 different new failure, state.json JSON corruption, primary file accidentally modified, scientific objection (unlikely), sibling-class scan surfacing other AM files, budget overrun (8 modes)
- [x] observable_manifest precondition_check is concrete (test -f on 9 files + jq -e on tier value + EdH still 2.75)
- [x] budget 950k expected fits within scheduler 1,146,136 sec window remaining and 1.5M hard cap
- [x] §A6 research-first citation present (12 distinct citations: T85 sim/judge/director, T84 sim, T60 director precedent, memory file, 4 feedback memories, director.md §F1 + §G, APC cache note)
- [x] §A5 D1/D2/D3 articulated: D1 verification axis terminal closure (3rd Tier-3, 1st lab-paper benchmark); manuscript NOT primary
- [x] investigation_update field updates current_stage (closed) AND tier_current (3.0) correctly per success path
- [x] No meta-investigation spawned (mechanical fix per `feedback_mechanical_vs_investigation_threshold`); sibling-class scan included in Phase 0 per `feedback_fix_the_class_not_the_instance`
- [x] No manuscript polish in scope (per `feedback_manuscript_is_not_the_essence`)
- [x] No anko-attribution in brief text (per `feedback_no_anko_attribution_in_prompts`)
- [x] No improvised terminology (per `feedback_no_improvised_terminology`)
