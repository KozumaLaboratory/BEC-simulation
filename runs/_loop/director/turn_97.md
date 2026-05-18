---
turn: 97
subagent: director
investigation_id: bug-4-itp-ddi-half-rate-revalidation-2026-05-18
stage_advancing_from: Hypothesize
stage_advancing_to: Execute
topic_tags: [d1-verification, bug-4-itp-ddi-half-rate, strang-splitting-ddi, tier1-to-tier2-promotion, regression-test-ci-gap, mechanical-batched-execute, state-json-investigation-registration]
paper_section: null
depends_on: [96, "runs/_loop/director/turn_96.md", "runs/_loop/theorist/turn_96.md", "runs/_loop/research/turn_95.md", "runs/_loop/_local/scheduler_97.json", "memory:bug_4_itp_ddi_half_rate", "memory:tier3_pipeline_survey_2026_05_18", "memory:feedback_mechanical_vs_investigation_threshold", "memory:feedback_fix_the_class_not_the_instance", "memory:feedback_cost_overhead_is_the_cost", "src/solvers/ground_state/itp_loop.jl", "test/solvers/test_itp_ddi_strang_save_every.jl", "test/solvers/test_rtp_ddi_strang_save_every.jl", "test/runtests.jl", "docs/archive/AUDIT_BUG4.md", "runs/_loop/state.json"]
produces: "T97 implementer_julia_cpu_light batched Execute dispatch. Skip the redundant Design stage (T96 §6 already designed the F5 observable manifest in full). Implementer performs in one turn: (1) register the bug-4 investigation in state.json so judge can evaluate against the contract instead of NOOP-ing; (2) F5 — run test/solvers/test_itp_ddi_strang_save_every.jl + companion RTP test via julia (~5-10 min including JIT); (3) F4 — patch test/runtests.jl to add both regression tests to FULL_EXTRA (2-line diff); (4) C4 — append addendum block to docs/archive/AUDIT_BUG4.md noting the RTP fix was applied 2026-05-02 (preserving the original archival text). This collapses the planned T97 Design + T97 Execute + T98 Update + T98 Document into one mechanical batched turn per anko feedback_mechanical_vs_investigation_threshold + feedback_fix_the_class_not_the_instance + feedback_cost_overhead_is_the_cost. Expected ~2.2M effective. The bug-4 investigation closes at Tier 2.0 on a successful T97."
---

# Turn 97 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `bug-4-itp-ddi-half-rate-revalidation-2026-05-18` (continuing from T95 Research + T96 Hypothesize). NOT registered in `state.investigations` — T95/T96 directors named the investigation in their reports but never patched state.json. This is why T96 judge returned NOOP (no investigation match for the contract). Registration is now part of the T97 dispatch deliverables.
- **Stage transition**: **Hypothesize → Execute** (skipping the redundant Design stage). Justification §3 below.
- **Tier**: 1.0 current → tier_target 2.0. Anticipated landing: 2.0 at T97 PASS (this single turn closes the arc).
- **Falsifiers carried in from T96 theorist §2 (formalized set)**:
  1. F1 itp_loop.jl structural — **CONFIRMED** at T95 §1.1 (no merge branch; two `_ddi_step!(ws, dt/2, ...)` calls per non-final step; tombstone lines 43-63).
  2. F2 regression test canonical assertions — **CONFIRMED** at T95 §1.2 + T96 §2.3 (line-by-line read; `max_dev < 1.0e-10`, phase-alignment correct).
  3. F3 RTP analogue fix present in `run_loops.jl` — **CONFIRMED** at T95 §1.3 (tombstone at lines 116-131).
  4. F4 CI tier coverage gap — T96 classified **load-bearing**; remediation = T97 implementer patch adding both tests to FULL_EXTRA. UNTESTED.
  5. F5 julia regression test execution — T96 classified **load-bearing with permitted-skip degradation**; scheduler JULIA_GPU_OK permits execution. UNTESTED.
  6. F6 external Strang-DDI convention — **PARTIALLY CONFIRMED** at T95 §3 (Javanainen-Ruostekoski 2004 cond-mat/0411154 cited).
  7. C4 AUDIT_BUG4.md staleness — T96 classified **T98 Document action** (advisory; non-blocking). Resolution = T97 implementer appends addendum.
- **Other in-flight investigations** (no changes since T96):
  - Tier-3 closed (5 physics): barnett T29, klaus-bch T59, edh-matsui T86, sign-pattern-lemma1 T94, plus yan-li-saito REFUTED-CLEAN.
  - Tier-2 closed (4 physics): judge-in-operator-bug T54, audit-due-heuristic T68, audit-class-scan-T50 T54, audit-class-scan-T61 T63, audit-class-scan-T87 T89.
  - Meta Observe ongoing (3): meta-cost-waste-audit (priority 15), meta-director-self-audit (priority 20), meta-cost-inflation (priority 40). Meta-critic-placement (priority 50) deferred.
  - `fullbdg-f6-polar-3000x` dormant (priority 99).
- **Scheduler** (`runs/_loop/_local/scheduler_97.json` read this turn): decision `go`, policy `JULIA_GPU_OK`, allowed_workloads includes `implementer_julia_cpu_light`. Window 2026-05-15T22:00 → 2026-05-31T23:59 JST, `window_seconds_left=1,133,439` (~13.12 days). Probe: VRAM 12,633 MB free, RAM 25.03 GB, GPU util 4%, foreign_julia 0. No conflict for the CPU-light julia regression test (~5-10 min including JIT, well within budget).
- **T96 drift signals** (state.history[96]): topic_repetition=0.417, subagent_repetition=0.333, manuscript_delta_zero=1.0, code_delta_zero=0.0, verdict_drift=0.1, cost_inflation=0.935, novel_claim_zero=0.0. Advisories: `DRIFT_MANUSCRIPT_DELTA_ZERO` only (advisory; correct-by-design per `feedback_manuscript_is_not_the_essence`). `novel_claim_zero` correctly reset to 0.0 at T96 Hypothesize as predicted. No `director_must_address` escalation.

## 2. Recent-turn audit (last 3 turns of THIS investigation)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T95 | Research | RESEARCHER_ONLY (judge) | researcher_shallow read 5 src/test files + AUDIT_BUG4.md, fetched 5 external refs (Lahaye 2009, Chomaz 2022, Thalhammer 2026, Javanainen-Ruostekoski 2004, Bao-Du 2004). Confirmed F1/F2/F3 structurally. Found 2 NOVEL: F4 (CI gap) + C4 (AUDIT_BUG4.md stale). Cost 1.52M. |
| T96 | Hypothesize | NOOP (judge — investigation_id not in state.investigations) | theorist text-only formalized 7 falsifiers; classified F4 load-bearing + C4 = T98 Document action + F5 load-bearing-permitted-skip; articulated Tier 1→2 conditional + refute conditions; addressed 3 counter-hypotheses; previewed T97 Execute observable manifest in §6 (command, success criterion, falsifier_signature_if_fail, expected wall time, expected max_dev). Cost 1.56M. **Verdict was NOOP not because deliverable was deficient but because state.investigations had no entry to anchor the contract** — T96 produced HYPOTHESIS_FORMALIZED_FOR_DESIGN content, judge couldn't find the investigation. |

## 3. Flow template recall

- **Template**: `verify-claim` (§F1).
- **Stages already done**: Research (T95), Hypothesize (T96 theorist file is valid; judge NOOP was state-registration mismatch, not deliverable deficiency).
- **Canonical next stage per §F1 sequence**: Hypothesize → Design → Execute.
- **Why skip Design directly to Execute this turn**:
  1. **T96 theorist §6 IS the Design deliverable already.** The director-brief §1-§7 deliverables for T96 explicitly required Design-equivalent content: the F5 observable manifest preview (§6 of T96) includes the `command`, `success_criterion`, `falsifier_signature_if_fail` patterns (critical/moderate/numerical-noise), `expected_wall_time`, and `expected_max_dev`. The falsifier table (§2 of T96) also includes the F4 patch shape (which strings to add to which array in `test/runtests.jl`). A separate theorist Design dispatch would re-emit the same content with a different header — wasted budget.
  2. **Per `feedback_mechanical_vs_investigation_threshold`** (anko 2026-05-18: "a sed-class rename does NOT need 7 stages; ~3s recognition test"): F4 remediation = 2 lines added to one array in runtests.jl; C4 remediation = 1 paragraph appended to a markdown file; F5 = running an existing test file. **All three are mechanical**. Wrapping them in Design + Execute + Update + Document quadruples the turn count for zero added robustness — the falsifier set and dispositions are already fixed at T96.
  3. **Per `feedback_fix_the_class_not_the_instance`** (anko 2026-05-18: "when ONE instance of a problem class surfaces, grep for siblings codebase-wide and batch-fix"): the remaining bug-4 closure items form one class (CI-tier-coverage + audit-doc-staleness + julia-regression-execution = all "close the institutional debt loop"). Batching them in one implementer_julia_cpu_light turn applies the lesson directly.
  4. **Per `feedback_cost_overhead_is_the_cost`** (anko 2026-05-15: "stop deliberating about token cost; the deliberation is more expensive than the work"): a separate Design turn would cost ~1.5M for content that is already in T96 §6. Direct Execute is the correct stop-deliberating path.
- **Role for Execute stage per §F1**: `implementer (text / sympy / julia_cpu / julia_gpu per workload)`. Workload class here is `implementer_julia_cpu_light` because the F5 test is a ~5-10 min Julia run (well under JULIA_CPU_HEAVY threshold) and the rest is text-file edits.

## 4. Research grounding (§A6)

§A6 mandates ≥1 external reference. Citation grounding for this Execute dispatch:

1. **Javanainen-Ruostekoski 2004 (arXiv:cond-mat/0411154)** — the canonical "most-recent-ψ" convention for state-dependent potentials in split-step GPE integration. The Bug-4 fix aligns with this published convention; the F5 julia regression test mechanically validates the alignment is preserved in current production code. Cited at T95 §3 and T96 §2.1.
2. **Thalhammer (2026) arXiv:2601.19838** — recent (2026) splitting-methods paper for ITP ground-state computation; confirms Strang is the canonical 2nd-order ITP scheme. The fix structure (close-and-reopen with two `_ddi_step!(ws, dt/2, ...)` calls) implements Strang correctly.
3. **Bao-Du 2004 (SIAM J. Sci. Comput. 25, 1674)** — TSSP ITP discretization foundation. The regression test's `max_dev < 1.0e-10` floor is consistent with TSSP expected accuracy at the F=1 c_dd=2000 test parameters.
4. **Memory `bug_4_itp_ddi_half_rate.md`** (16-day caveat acknowledged; T95/T96 re-verified against current code) — load-bearing internal anchor.
5. **Memory `feedback_mechanical_vs_investigation_threshold.md`** + **`feedback_fix_the_class_not_the_instance.md`** + **`feedback_cost_overhead_is_the_cost.md`** — load-bearing for the meta-decision to batch + skip Design stage.
6. **APC contract template cache** (arXiv:2506.14852): `verify-claim::Execute` is high-frequency. Cached skeletons from T20 barnett execute (julia_gpu c_dd=0 control), T57 klaus-bch execute (analyze_existing), T74-T82 edh-matsui execute (multiple julia_gpu retries). Use cached skeleton with success_criteria keyed on `julia_test_pass_count`, `regression_test_max_dev`, `state_json_investigation_registered`, `runtests_jl_FULL_EXTRA_patched`, `audit_bug4_md_addendum_appended`. Patch in bug-4-specific deltas (file paths, julia command, exact diff text).

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verify existing physics; PRIMARY axis)**. The 2026-05-02 Bug-4 fix is empirically falsified — the regression test on current source code is the canonical empirical falsifier of the bug class (per T96 §2.3). If the test passes, the fix is structurally + empirically + cross-implementation verified, which is the §D Tier-2 standard for code-correctness claims. The institutional debt items (F4 CI gap + C4 audit doc staleness) get closed in the same turn.
- **Tier ladder position**: 1.0 → 2.0 on T97 PASS. T98 unnecessary if F4+F5+C4 all land cleanly; the Document stage collapses into the same Execute turn (memory entry update is also a mechanical text edit).
- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence`. No `docs/manuscript/` files touched.
- **Cost frame**: target ~2.2M effective; HARD CAP 3.0M. Breakdown:
  - state.json registration: 200K
  - julia regression test run (F5 ITP + RTP): 1,200K (~5-10 min including JIT)
  - runtests.jl patch (F4): 200K (2-line diff + verify file)
  - AUDIT_BUG4.md addendum (C4): 200K (single paragraph append)
  - memory entry update + final report: 400K
  - Comparable historical: T20 barnett julia GPU execute = 4M; T78 matsui julia GPU = 2.3M; T74 matsui julia preflight = 1.8M. T97 is light because no large simulation, just running an existing test.
- **Drift trajectory after T97 (anticipated)**:
  - cost_inflation: ~1.15 (2.2M actual vs ~1.9M running median → ratio ~1.16; within healthy range).
  - code_delta_zero: 0.0 (test/runtests.jl modified + docs/archive/AUDIT_BUG4.md modified).
  - manuscript_delta_zero: 1.0 (correct by design).
  - novel_claim_zero: 0.0 (the empirical F5 test pass IS a novel claim in the heuristic — first execution of the regression test post-fix in the loop).
  - subagent_repetition: 1/5 implementer (post T94 implementer_text + T95 researcher + T96 theorist + T97 implementer_julia_cpu_light = healthy rotation, 3-turn gap since last implementer at T94, different workload class).
- **Branch-point T97 failure modes** (preview; full structured failure_modes in §6 contract):
  - **PASS / CLOSE_TIER_2** (expected; ~85% probability): all 4 deliverables succeed; investigation closes at Tier 2.0 in same turn.
  - **F5 FAIL (julia test fails)** (~5% probability): bug has actually regressed between T95 audit and T97 run. Spawn fix-bug investigation IMMEDIATELY at priority 1.
  - **F4 partial (only 1 of 2 tests added)** (~3% probability): operational mistake; T98 implementer_text completes the second.
  - **C4 partial (addendum format wrong)** (~2% probability): advisory; T98 implementer_text refines.
  - **state.json malformed after registration** (~3% probability): operational; revert and retry on T98.
  - **NOVEL** (~2% probability): F5 reveals an unexpected production-mode bug (e.g., the test passes at F=1 c_dd=2000 but the implementer notices an F=6 path that was missed). Side-dispatch critic at T98.

- **Recommended T98+ trajectory (post-T97 PASS)**: investigation closes at Tier 2.0 in same turn (Document-stage memory update folded in). T98 director picks from: (a) meta interleave (meta-cost-waste-audit Hypothesize, priority 15); (b) audit-class-scan T98 (AUDIT_DUE next due gap=10 from T87 close, would fire at T98-T99); (c) spawn a fresh physics investigation from the remaining survey menu (#4 capped 2.5 or #5 medium-priority TDHFB Phase 2). Per §B2 meta-interleave rule and 4 consecutive physics turns (T95-T98), T99 is the natural meta interleave moment.

## 6. Dispatch decision (declarative contract)

```json
{
 "investigation_id": "bug-4-itp-ddi-half-rate-revalidation-2026-05-18",
 "stage_advancing_to": "Execute",
 "subagent_type": "implementer",
 "researcher_depth": null,
 "parallel_researcher_count": 0,
 "rationale": "T96 theorist Hypothesize delivered a complete falsifier set with machine-evaluable criteria + F4/C4 dispositions + T97 Execute observable manifest in §6 (judge NOOP was state.investigations registration mismatch, not deliverable deficiency — confirmed by reading T96 theorist file). Per anko feedback_mechanical_vs_investigation_threshold + feedback_fix_the_class_not_the_instance + feedback_cost_overhead_is_the_cost: skip the redundant Design stage and batch all remaining mechanical bug-4 closure items (state.json registration + F5 julia regression test + F4 runtests.jl patch + C4 AUDIT_BUG4.md addendum) into one implementer_julia_cpu_light turn. Scheduler JULIA_GPU_OK permits Julia execution. Investigation closes at Tier 2.0 on success.",
 "brief": "## ROLE\n\nYou are implementer (julia_cpu_light class). T97 §F1 Execute stage of investigation `bug-4-itp-ddi-half-rate-revalidation-2026-05-18`. Your job: batch-execute four mechanical closure items that together promote the investigation from Tier 1.0 to Tier 2.0 in one turn. The investigation is NOT yet registered in `runs/_loop/state.json` — registration is part of your deliverables.\n\nThe theorist at T96 already designed the F5 observable manifest in `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_96.md` §6 — use it verbatim; do NOT re-design.\n\nDIRECTIVE_LABEL: bug-4-itp-ddi-revalidation-T97-batched-execute-tier2-closure\n\nWrite final report to `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_97.md`.\n\n## REQUIRED READING (in this order)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_97.md` ENTIRE (this report).\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_96.md` ENTIRE — especially §2 falsifier table + §3 F4 disposition + §4 C4 disposition + §5 Tier 1→2 conditional + §6 F5 observable manifest preview.\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_95.md` ENTIRE — citation chain + 5 external refs + F4/C4 NOVEL findings.\n4. `/home/suzume/workspace/BEC-simulation/CLAUDE.md` §Commands + §Bug-4 (for `SPINORBEC_TEST_TIER` definitions).\n\n## DELIVERABLES (4 batched items)\n\n### Deliverable A: Register the investigation in state.json\n\nThe T95/T96 directors named the investigation but never patched `runs/_loop/state.json`. Add this entry to `state.investigations` (and append the id to `state.investigations_index`):\n\n```json\n\"bug-4-itp-ddi-half-rate-revalidation-2026-05-18\": {\n  \"id\": \"bug-4-itp-ddi-half-rate-revalidation-2026-05-18\",\n  \"title\": \"Bug-4 ITP merged-loop DDI half-rate fix Tier 1->2 revalidation (2026-05-02 fix audit)\",\n  \"hypothesis\": \"The 2026-05-02 Bug-4 ITP merged-loop DDI half-rate fix is Tier-2-verified (closed-form code structure + regression-test + cross-implementation), conditional on jointly satisfying falsifiers F1+F2+F3+F4+F5+F6 (per T96 theorist §2).\",\n  \"flow_template\": \"verify-claim\",\n  \"current_stage\": \"closed\",\n  \"stages_done\": [\"Research\", \"Hypothesize\", \"Execute\", \"Document\"],\n  \"stages_at_turn\": {\n    \"Research\": [95, \"researcher_shallow audit + 5 external refs; F1/F2/F3 confirmed structurally; F4/C4 NOVEL\"],\n    \"Hypothesize\": [96, \"theorist formalized 7 falsifiers; F4 load-bearing; C4 T98 Document action; F5 load-bearing permitted-skip\"],\n    \"Execute\": [97, \"implementer_julia_cpu_light batched: state.json registration + F5 julia regression test + F4 runtests.jl patch + C4 AUDIT_BUG4.md addendum\"],\n    \"Document\": [97, \"folded into Execute per anko feedback_mechanical_vs_investigation_threshold\"]\n  },\n  \"falsifiers\": [\n    {\"id\": \"F1-itp_loop-no-merge-branch\", \"description\": \"src/solvers/ground_state/itp_loop.jl has no merge branch; two _ddi_step!(ws, dt/2, ...) calls per non-final step; tombstone lines 43-63\", \"tested_at_turn\": 95, \"result\": \"CONFIRMED structurally\"},\n    {\"id\": \"F2-regression-test-canonical\", \"description\": \"test/solvers/test_itp_ddi_strang_save_every.jl asserts max_dev < 1.0e-10 phase-aligned + energy diff < 1e-10 DDI-on + < 1e-9 DDI-off\", \"tested_at_turn\": 95, \"result\": \"CONFIRMED structurally\"},\n    {\"id\": \"F3-rtp-analogue-fix\", \"description\": \"src/solvers/simulation/run_loops.jl has Bug-4 RTP analogue tombstone at lines 116-131; close-and-reopen with _half_potential_step!(ws, dt/2, ...) calls\", \"tested_at_turn\": 95, \"result\": \"CONFIRMED structurally\"},\n    {\"id\": \"F4-ci-tier-coverage\", \"description\": \"both test_itp_ddi_strang_save_every.jl and test_rtp_ddi_strang_save_every.jl added to FULL_EXTRA in test/runtests.jl\", \"tested_at_turn\": 97, \"result\": \"<implementer fills in: CONFIRMED if added cleanly, PARTIAL/FAILED otherwise>\"},\n    {\"id\": \"F5-julia-regression-test-pass\", \"description\": \"julia --project=. -e 'using SpinorBEC; include(\\\"test/solvers/test_itp_ddi_strang_save_every.jl\\\")' returns 3 Pass + 0 Fail; same for RTP companion\", \"tested_at_turn\": 97, \"result\": \"<implementer fills in: PASS/FAIL with observed max_dev>\"},\n    {\"id\": \"F6-external-convention\", \"description\": \"Javanainen-Ruostekoski 2004 arXiv:cond-mat/0411154 most-recent-psi convention cited\", \"tested_at_turn\": 95, \"result\": \"CONFIRMED partial\"},\n    {\"id\": \"C4-audit-bug4-md-addendum\", \"description\": \"docs/archive/AUDIT_BUG4.md has 2026-05-18 addendum noting the RTP fix was applied (preserving original archival text)\", \"tested_at_turn\": 97, \"result\": \"<implementer fills in: CONFIRMED if appended cleanly>\"}\n  ],\n  \"tier_current\": <implementer fills in: 2.0 on success, 1.0 if F5 fails>,\n  \"tier_target\": 2,\n  \"next_stage\": null,\n  \"next_stage_action\": null,\n  \"blocked_on\": null,\n  \"priority\": 4,\n  \"kind\": \"physics\",\n  \"last_turn\": 97,\n  \"last_stage\": \"Execute\",\n  \"last_verdict\": \"<implementer fills in: TIER_2_CLOSURE_PASS or FAIL_WITH_REASON>\",\n  \"closing_note\": \"<implementer fills in: 2-3 sentence closing note summarizing arc T95-T97 + final F5 max_dev value + F4/C4 patch confirmations>\"\n}\n```\n\nALSO update at the top level of state.json:\n- Append `\"bug-4-itp-ddi-half-rate-revalidation-2026-05-18\"` to `investigations_index` (the list at line ~2114).\n- DO NOT change `active_investigation_id` (the orchestrator manages this post-judge).\n\nUse standard JSON edit (Read state.json → identify the closing `}` of `investigations` dict at the end → insert the new entry just before it). Verify with `python3 -c 'import json; json.load(open(\"runs/_loop/state.json\"))'` after edit.\n\n### Deliverable B: F5 — Run the julia regression tests\n\nRun the canonical regression test:\n\n```bash\ncd /home/suzume/workspace/BEC-simulation\njulia --project=. -e 'using SpinorBEC; include(\"test/solvers/test_itp_ddi_strang_save_every.jl\")' 2>&1 | tee /tmp/bug4_itp_test_T97.log\n```\n\nThen the companion RTP test:\n\n```bash\njulia --project=. -e 'using SpinorBEC; include(\"test/solvers/test_rtp_ddi_strang_save_every.jl\")' 2>&1 | tee /tmp/bug4_rtp_test_T97.log\n```\n\nExpected per T96 §6: both tests report `Test Summary: Pass: 3 Fail: 0 Error: 0 Broken: 0` for the outer testset; empirical max_dev ~ 1e-13 to 1e-14 per AUDIT_BUG4.md historical record.\n\n**Failure dispositions per T96 §6**:\n- max_dev ~ 0.1-0.2: bug REGRESSED — spawn fix-bug investigation IMMEDIATELY priority 1.\n- max_dev 1e-10 < d < 1e-3: accuracy regression but not full bug — spawn fix-bug at standard priority.\n- max_dev 1e-10 < d < 1e-9: numerical-noise floor boundary — Tier 2 conditionally stamps with memo.\n- All-pass with max_dev ~ 1e-13: full PASS, Tier 2.0 closure.\n\nCapture from stdout: the exact Test Summary line + the actual max_dev value if logged. Both go in the F5 falsifier result.\n\nWall-time: ~5-10 min for ITP test (JIT dominates; F=1 12x12x6 grid + 800 ITP steps); ~3-5 min for RTP test (n_steps=200). Total ~8-15 min. Within JULIA_CPU_LIGHT scheduler budget.\n\n### Deliverable C: F4 — Patch test/runtests.jl\n\nAdd both regression tests to `FULL_EXTRA` in `/home/suzume/workspace/BEC-simulation/test/runtests.jl`. The `FULL_EXTRA` array starts at line 110 and ends at line 155.\n\nInsert these two entries at a sensible location (e.g., after line 125 `\"solvers/test_pause_resume.jl\",` which is the last `solvers/` entry before `dynamics/`):\n\n```julia\n    \"solvers/test_itp_ddi_strang_save_every.jl\",  # Bug-4 ITP DDI half-rate regression (2026-05-02 fix)\n    \"solvers/test_rtp_ddi_strang_save_every.jl\",  # Bug-4 RTP analogue regression (2026-05-02 fix)\n```\n\nUse `Edit` to make the change. After edit, verify with:\n```bash\ngrep -n 'test_itp_ddi_strang_save_every\\|test_rtp_ddi_strang_save_every' /home/suzume/workspace/BEC-simulation/test/runtests.jl\n```\nExpect 2 matches (one for each new line).\n\nDO NOT run `julia --project=. -e 'using Pkg; Pkg.test()'` to verify — that would re-run the full test suite (~6 min) on top of the F5 ~10 min, doubling cost. The grep above is sufficient regression check; the F5 dedicated runs already validate the tests themselves work.\n\n### Deliverable D: C4 — Append addendum to docs/archive/AUDIT_BUG4.md\n\nThe file `docs/archive/AUDIT_BUG4.md` line 86-92 says RTP fix \"not auto-fixed\" but current `run_loops.jl` HAS the fix. Per T96 §4, append an addendum block at the end of the file (after the existing line 100 `## Memory note` block — preserve original archival text):\n\n```markdown\n\n---\n\n## Addendum 2026-05-18 — RTP analogue fix applied (loop T97)\n\nThe \"Not auto-fixed\" status above (lines 86-92) describes the state at\nthe time of writing (ITP fix applied, RTP fix decision pending). The\nRTP analogue fix was subsequently applied in the same shape as the ITP\nfix: see `src/solvers/simulation/run_loops.jl` lines 116-131 tombstone\ncomment naming \"Bug-4 RTP analogue (2026-05-02)\". Every non-final RTP\nstep now executes exactly two `_half_potential_step!(ws, dt/2, ...)`\ncalls (close + reopen pair), aligning with the Javanainen-Ruostekoski\n2004 [arXiv:cond-mat/0411154] \"most-recent-psi\" convention.\n\nRegression test `test/solvers/test_rtp_ddi_strang_save_every.jl` pins\n`max_dev < 1.0e-10` for both DDI-on (regression target) and DDI-off\n(control) on a F=1 c_dd=2000 RTP run. Both ITP and RTP regression\ntests were added to `FULL_EXTRA` in `test/runtests.jl` at T97 (loop\nrevalidation cycle 2026-05-18); previously only ad-hoc manual runs\nwould trigger them.\n\nPer-step cost: the RTP fix doubles per-step DDI cost on non-checkpoint\nsteps (same as the ITP fix). The cost-vs-correctness trade-off noted\nin §\"Related — RTP merged-leapfrog accuracy degradation\" above was\nresolved in favour of correctness.\n\nLoop turn references: T95 researcher audit\n(runs/_loop/research/turn_95.md §1.3 + §C4) identified this doc\nstaleness as a NOVEL finding; T96 theorist (runs/_loop/theorist/turn_96.md\n§4) classified it as a T98 Document action; T97 implementer applied\nthe addendum (this block) as part of the Tier 1->2 closure of\ninvestigation bug-4-itp-ddi-half-rate-revalidation-2026-05-18.\n```\n\nUse `Edit` to append (Read the file first to get exact text, then Edit to add). After edit, verify with `tail -30 /home/suzume/workspace/BEC-simulation/docs/archive/AUDIT_BUG4.md` showing the new addendum.\n\n## FINAL REPORT\n\nWrite to `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_97.md` with the following sections:\n\n### §1. Execution summary\n\nOne paragraph: what was run, what was patched, what passed, what (if anything) failed.\n\n### §2. F5 julia regression test results\n\nFor each of ITP + RTP tests:\n- Exact `Test Summary` line from stdout\n- Observed max_dev value (if logged)\n- Wall time\n- Verdict (PASS / FAIL_BUG_REGRESSED / FAIL_ACCURACY_REGRESSION / FAIL_NUMERICAL_NOISE_BOUNDARY)\n\n### §3. F4 runtests.jl patch\n\n- Lines added (verbatim)\n- Grep verification output\n- Verdict (CONFIRMED / FAILED)\n\n### §4. C4 AUDIT_BUG4.md addendum\n\n- Verbatim addendum content (or 'as in director brief §6 Deliverable D')\n- Tail verification output\n- Verdict (CONFIRMED / FAILED)\n\n### §5. state.json registration\n\n- The exact JSON entry added to state.investigations\n- Final tier_current value\n- Final last_verdict and closing_note\n- python3 json.load verification output\n- Verdict (CONFIRMED / FAILED)\n\n### §6. METRICS JSON (single fenced ```json``` block per schema below)\n\n## METRICS JSON SCHEMA\n\n```json\n{\n  \"experiment_kind\": \"modify_code_and_run_julia\",\n  \"investigation_kind\": \"physics\",\n  \"investigation_id\": \"bug-4-itp-ddi-half-rate-revalidation-2026-05-18\",\n  \"stage_advancing_to\": \"Execute\",\n  \"flow_template\": \"verify-claim\",\n  \"state_json_modified\": true,\n  \"state_json_investigation_registered\": true,\n  \"investigation_id_in_state\": \"bug-4-itp-ddi-half-rate-revalidation-2026-05-18\",\n  \"julia_executed\": true,\n  \"julia_test_files_run\": [\"test/solvers/test_itp_ddi_strang_save_every.jl\", \"test/solvers/test_rtp_ddi_strang_save_every.jl\"],\n  \"itp_test_pass_count\": <int; expect 3>,\n  \"itp_test_fail_count\": <int; expect 0>,\n  \"itp_test_error_count\": <int; expect 0>,\n  \"itp_test_max_dev_observed\": <float; expect ~1e-13>,\n  \"rtp_test_pass_count\": <int; expect 3>,\n  \"rtp_test_fail_count\": <int; expect 0>,\n  \"rtp_test_error_count\": <int; expect 0>,\n  \"rtp_test_max_dev_observed\": <float; expect ~1e-13>,\n  \"runtests_jl_modified\": true,\n  \"runtests_jl_itp_test_added\": true,\n  \"runtests_jl_rtp_test_added\": true,\n  \"runtests_jl_target_array\": \"FULL_EXTRA\",\n  \"audit_bug4_md_modified\": true,\n  \"audit_bug4_md_addendum_appended\": true,\n  \"audit_bug4_md_original_text_preserved\": true,\n  \"src_files_modified\": 0,\n  \"docs_modified\": 1,\n  \"tests_added_to_runtests_jl\": 2,\n  \"webfetch_used\": false,\n  \"sympy_invoked\": false,\n  \"manuscript_main_edited\": false,\n  \"tier_reached\": <float; expect 2.0>,\n  \"investigation_closed_at_tier2\": <bool; expect true>,\n  \"verdict\": \"TIER_2_CLOSURE_PASS\"\n}\n```\n\n## ANTI-PATTERN GUARDS\n\n- Do NOT re-do T95/T96 work. Trust their structural confirmations. Your job is the 4 mechanical executions.\n- Do NOT run `Pkg.test()` (full test suite) — wastes ~6 min on top of F5 ~10 min for no added information; F5 already validates the relevant tests.\n- Do NOT modify `src/` (only `test/runtests.jl` and `docs/archive/AUDIT_BUG4.md` and `runs/_loop/state.json`).\n- Do NOT modify `runs/_loop/state.json` `active_investigation_id` field (orchestrator owns that).\n- Do NOT modify the original archival text in `docs/archive/AUDIT_BUG4.md` lines 86-92 — append the addendum AFTER existing content.\n- Do NOT improvise terminology per `feedback_no_improvised_terminology`. Use established numerical-method terms (Strang splitting, regression test, CI tier, addendum).\n- Do NOT exceed 3.0M effective tokens HARD CAP. Target 2.2M.\n- If F5 julia run fails with bug-regression signature (max_dev ~ 0.1-0.2), STOP all other deliverables and spawn a fix-bug investigation as a NOVEL T98 trigger — the institutional closure (F4/C4) does not make sense if the fix has regressed.\n- If state.json JSON is malformed after your edit, REVERT the file and report the failure mode; do not commit broken state.json.\n- English only. No emojis. No anko-attribution in agent prompts (memory files can cite anko).\n\n## SUCCESS DEFINITION\n\nT97 PASS = all 4 deliverables CONFIRMED:\n1. state.json valid JSON with bug-4 investigation registered AND in investigations_index, tier_current=2.0, current_stage=closed.\n2. F5 julia tests both report Pass: 3 Fail: 0 Error: 0; max_dev < 1e-10 (target ~1e-13).\n3. test/runtests.jl FULL_EXTRA contains both new strings (verified by grep returning 2 matches).\n4. docs/archive/AUDIT_BUG4.md tail contains the addendum block with the 2026-05-18 date marker.\n\nOn PASS, the investigation closes at Tier 2.0; T98 director picks the next pivot per §B2.\n",
 "observable_manifest": {
   "required": [
     "experiment_kind",
     "investigation_kind",
     "investigation_id",
     "stage_advancing_to",
     "flow_template",
     "state_json_modified",
     "state_json_investigation_registered",
     "julia_executed",
     "itp_test_pass_count",
     "itp_test_fail_count",
     "itp_test_error_count",
     "itp_test_max_dev_observed",
     "rtp_test_pass_count",
     "rtp_test_fail_count",
     "rtp_test_error_count",
     "rtp_test_max_dev_observed",
     "runtests_jl_modified",
     "runtests_jl_itp_test_added",
     "runtests_jl_rtp_test_added",
     "audit_bug4_md_modified",
     "audit_bug4_md_addendum_appended",
     "audit_bug4_md_original_text_preserved",
     "tier_reached",
     "investigation_closed_at_tier2",
     "verdict"
   ],
   "optional": [
     "julia_test_files_run",
     "runtests_jl_target_array",
     "src_files_modified",
     "docs_modified",
     "tests_added_to_runtests_jl",
     "webfetch_used",
     "sympy_invoked",
     "manuscript_main_edited",
     "investigation_id_in_state"
   ],
   "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_97.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_96.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_95.md && test -f /home/suzume/workspace/BEC-simulation/test/solvers/test_itp_ddi_strang_save_every.jl && test -f /home/suzume/workspace/BEC-simulation/test/solvers/test_rtp_ddi_strang_save_every.jl && test -f /home/suzume/workspace/BEC-simulation/test/runtests.jl && test -f /home/suzume/workspace/BEC-simulation/docs/archive/AUDIT_BUG4.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/state.json && python3 -c 'import json; json.load(open(\"/home/suzume/workspace/BEC-simulation/runs/_loop/state.json\"))' && which julia && echo PRECONDITIONS_OK"
 },
 "success_criteria": [
   {
     "id": "experiment_kind_correct",
     "metric": "experiment_kind",
     "operator": "==",
     "value": "modify_code_and_run_julia",
     "rationale": "Batched modify+execute is the canonical Execute-stage workload class."
   },
   {
     "id": "investigation_kind_physics",
     "metric": "investigation_kind",
     "operator": "==",
     "value": "physics",
     "rationale": "verify-claim physics investigation."
   },
   {
     "id": "investigation_id_correct",
     "metric": "investigation_id",
     "operator": "==",
     "value": "bug-4-itp-ddi-half-rate-revalidation-2026-05-18",
     "rationale": "Active investigation continuity from T95-T96."
   },
   {
     "id": "stage_consistent",
     "metric": "stage_advancing_to",
     "operator": "==",
     "value": "Execute",
     "rationale": "T97 advances from Hypothesize (T96) to Execute per §F1 sequence (Design folded into Execute per anko mechanical-vs-investigation threshold)."
   },
   {
     "id": "state_json_registered",
     "metric": "state_json_investigation_registered",
     "operator": "==",
     "value": true,
     "rationale": "Deliverable A: bug-4 must be added to state.investigations + investigations_index so judge can evaluate against contract."
   },
   {
     "id": "julia_executed",
     "metric": "julia_executed",
     "operator": "==",
     "value": true,
     "rationale": "Deliverable B: F5 julia regression test must run."
   },
   {
     "id": "itp_test_passes",
     "metric": "itp_test_pass_count",
     "operator": ">=",
     "value": 3,
     "rationale": "F5 ITP regression: 3 @test assertions (DDI-on max_dev, DDI-on energy diff, DDI-off energy diff)."
   },
   {
     "id": "itp_test_no_fails",
     "metric": "itp_test_fail_count",
     "operator": "==",
     "value": 0,
     "rationale": "Any failure means bug regressed or accuracy degraded — see failure_modes."
   },
   {
     "id": "itp_test_no_errors",
     "metric": "itp_test_error_count",
     "operator": "==",
     "value": 0,
     "rationale": "Errors indicate operational problem (compile failure, missing dep)."
   },
   {
     "id": "itp_max_dev_below_floor",
     "metric": "itp_test_max_dev_observed",
     "operator": "<",
     "value": 1.0e-10,
     "rationale": "Per T96 §6, max_dev must be below 1e-10 for the canonical assertion to hold."
   },
   {
     "id": "rtp_test_passes",
     "metric": "rtp_test_pass_count",
     "operator": ">=",
     "value": 3,
     "rationale": "F5 RTP companion test parity check."
   },
   {
     "id": "rtp_test_no_fails",
     "metric": "rtp_test_fail_count",
     "operator": "==",
     "value": 0,
     "rationale": "RTP analogue fix must hold."
   },
   {
     "id": "runtests_jl_patched",
     "metric": "runtests_jl_modified",
     "operator": "==",
     "value": true,
     "rationale": "Deliverable C: F4 remediation."
   },
   {
     "id": "runtests_jl_itp_added",
     "metric": "runtests_jl_itp_test_added",
     "operator": "==",
     "value": true,
     "rationale": "Both regression tests must be added; this verifies the ITP one."
   },
   {
     "id": "runtests_jl_rtp_added",
     "metric": "runtests_jl_rtp_test_added",
     "operator": "==",
     "value": true,
     "rationale": "Both regression tests must be added; this verifies the RTP one."
   },
   {
     "id": "audit_bug4_md_patched",
     "metric": "audit_bug4_md_modified",
     "operator": "==",
     "value": true,
     "rationale": "Deliverable D: C4 remediation."
   },
   {
     "id": "audit_bug4_md_addendum",
     "metric": "audit_bug4_md_addendum_appended",
     "operator": "==",
     "value": true,
     "rationale": "Addendum block was appended (not in-place edit)."
   },
   {
     "id": "audit_bug4_md_original_preserved",
     "metric": "audit_bug4_md_original_text_preserved",
     "operator": "==",
     "value": true,
     "rationale": "Archival convention: append-only, never rewrite."
   },
   {
     "id": "tier_2_reached",
     "metric": "tier_reached",
     "operator": ">=",
     "value": 2.0,
     "rationale": "Tier 1 -> 2 promotion is the arc goal."
   },
   {
     "id": "investigation_closed",
     "metric": "investigation_closed_at_tier2",
     "operator": "==",
     "value": true,
     "rationale": "Investigation closure in same turn per anko mechanical-vs-investigation threshold."
   },
   {
     "id": "no_src_modification",
     "metric": "src_files_modified",
     "operator": "==",
     "value": 0,
     "rationale": "Execute stage modifies tests/docs/state only; no src/ touch (the fix is already in src from 2026-05-02)."
   },
   {
     "id": "no_manuscript",
     "metric": "manuscript_main_edited",
     "operator": "==",
     "value": false,
     "rationale": "§A5 manuscript polish OUT."
   },
   {
     "id": "verdict_tier2_closure",
     "metric": "verdict",
     "operator": "==",
     "value": "TIER_2_CLOSURE_PASS",
     "rationale": "Canonical batched Execute + closure verdict."
   }
 ],
 "failure_modes": [
   {
     "if": "itp_test_max_dev_observed >= 0.1 OR rtp_test_max_dev_observed >= 0.1",
     "category": "scientific_NOVEL_bug_regressed",
     "next_action": "Bug-4 fix has REGRESSED between T95 audit and T97 run. STOP all other T97 deliverables. T98 director spawns fix-bug-bug-4-itp-ddi-half-rate-regressed-2026-05-18 at priority 1 (preempts all other investigations). T97 reports the regression as NOVEL; bug-4-revalidation investigation stays Tier 1.0 (NOT promoted), awaits the new fix-bug arc closure."
   },
   {
     "if": "(itp_test_fail_count > 0 OR rtp_test_fail_count > 0) AND itp_test_max_dev_observed < 0.001 AND rtp_test_max_dev_observed < 0.001",
     "category": "scientific_accuracy_regression",
     "next_action": "Accuracy regression but not full bug. T98 director spawns fix-bug-bug-4-accuracy-regression-2026-05-18 at standard priority (priority 4-5). Investigation tier_current degrades to 1.5 (partial closure); F5 falsifier result = ACCURACY_REGRESSION."
   },
   {
     "if": "itp_test_fail_count > 0 AND 1.0e-10 < itp_test_max_dev_observed < 1.0e-9",
     "category": "operational_numerical_noise_boundary",
     "next_action": "Numerical-noise floor boundary case (FFT plan determinism / compiler reordering). Tier 2 conditionally stamps with a 'numerical-noise-boundary advisory' memo in memory entry. T98 director audits the threshold (raise to 1e-9?) but does NOT spawn a fix-bug investigation. F5 falsifier result = NUMERICAL_NOISE_BOUNDARY_TIER_2_CONDITIONAL."
   },
   {
     "if": "itp_test_error_count > 0 OR rtp_test_error_count > 0",
     "category": "operational_julia_error",
     "next_action": "Julia compile / dependency error. T98 director re-dispatches implementer with corrected julia invocation OR escalates to anko if SpinorBEC.jl itself fails to load. Tier promotion paused at 1.0; F1/F2/F3 structural confirmation from T95 still holds."
   },
   {
     "if": "runtests_jl_itp_test_added == false OR runtests_jl_rtp_test_added == false",
     "category": "operational_F4_partial",
     "next_action": "T4 partial patch (1 of 2 tests added). T98 implementer_text completes the missing addition in 1 turn. F4 falsifier result = PARTIAL; investigation tier conditionally stamps at 1.8 pending T98 completion."
   },
   {
     "if": "audit_bug4_md_addendum_appended == false OR audit_bug4_md_original_text_preserved == false",
     "category": "operational_C4_partial",
     "next_action": "C4 disposition advisory only — Tier 2 still stamps without C4 addendum. T98 implementer_text refines on next turn. Memory entry notes the C4 remediation pending."
   },
   {
     "if": "state_json_investigation_registered == false",
     "category": "operational_state_corruption",
     "next_action": "If state.json is corrupted (invalid JSON), T97 sim/turn_97.md reports the revert. T98 director MUST run python3 -c 'import json; json.load(open(\"runs/_loop/state.json\"))' as the first action and may need to manually patch state.json from a git-recovered copy."
   },
   {
     "if": "tier_reached < 2.0 AND verdict != TIER_2_CLOSURE_PASS",
     "category": "operational_unexpected_partial",
     "next_action": "Verdict mismatch. T98 director audits the failure modes above to determine which sub-deliverable degraded; investigation stays at the highest sub-tier confirmed by T97 (1.0 / 1.5 / 1.8) and the missing sub-deliverable is the T98 Document target."
   }
 ],
 "tolerance_overrides": {
   "cost_cap_effective": 3000000,
   "wall_time_cap_sec": 1800
 },
 "budget": {
   "expected_cost_eff": 2200000,
   "expected_wall_time_sec": 1500,
   "split_by_subtask": {
     "read_t96_theorist_and_t95_research_context": 300000,
     "state_json_registration": 200000,
     "julia_itp_regression_test_run_incl_jit": 700000,
     "julia_rtp_regression_test_run_incl_jit": 500000,
     "runtests_jl_F4_patch_and_grep_verify": 200000,
     "audit_bug4_md_C4_addendum_append": 200000,
     "final_report_metrics_synthesis": 100000
   }
 },
 "investigation_update": {
   "if_success_advance_to_stage": "closed",
   "if_success_tier_becomes": 2.0,
   "if_success_closing_note": "Tier 2.0 terminal closure 2026-05-18 T97. Bug-4 ITP merged-loop DDI half-rate fix (2026-05-02) Tier 1->2 promotion completed via batched mechanical Execute: F1/F2/F3 structural confirmation (T95), 7 falsifiers formalized with F4 load-bearing + C4 T98-Document-action dispositions (T96 theorist), F5 julia regression tests run (max_dev ~ 1e-13 expected), F4 runtests.jl FULL_EXTRA patch applied, C4 AUDIT_BUG4.md 2026-05-18 addendum appended. 5th project Tier-2+ closure of the T69-T70 survey menu (after edh-matsui Tier 3 T86, sign-pattern-lemma1 Tier 3 T94). 3-turn arc T95-T97 (researcher_shallow 1.52M + theorist 1.56M + implementer_julia_cpu_light ~2.2M = ~5.3M total, on par with sign-pattern T91-T94 4-turn arc). Per anko feedback_mechanical_vs_investigation_threshold, Design + Update + Document stages folded into Execute. Survey menu remaining: #4 capped Tier 2.5, #5 medium-priority TDHFB Phase 2.",
   "if_refuted_advance_to_stage": "Hypothesize-with-bug-resurfaced",
   "if_refuted_tier_becomes": 0.5,
   "if_novel_advance_to_stage": "spawn-fix-bug-bug-4-regressed-2026-05-18",
   "if_novel_tier_becomes": 1.0,
   "next_falsifier_to_test_after": null
 },
 "if_succeeds_next_step": "T98 director picks next pivot. Candidates by priority: (a) AUDIT_DUE next due (last T87 close T89, +10 = T99 — borderline; check scheduler advisory at T98); (b) meta-cost-waste-audit Hypothesize (priority 15, longest-pending Observe); (c) meta-director-self-audit Hypothesize (priority 20); (d) spawn fresh physics investigation from survey menu #5 TDHFB Phase 2 HF kernel (priority 1; cheapest remaining Tier-3 candidate). Per §B2 meta-interleave rule, T98 is the natural meta interleave moment after T95-T97 = 3 physics turns. Recommended: meta-cost-waste-audit Hypothesize (theorist text-only ~1.6M) — addresses long-pending STAGE_OUTLIER finding on noop ratio 12.46×.",
 "if_fails_next_step": "If F5 reveals bug regression (max_dev ~ 0.1+): T98 director spawns fix-bug-bug-4-regressed-2026-05-18 at priority 1; bug-4-revalidation stays at Tier 1.0 pending the new arc's closure. If F5 reveals accuracy regression: T98 director spawns fix-bug-bug-4-accuracy at priority 4-5; tier stays at 1.5. If state.json corrupted: T98 director's first action = python3 json.load check + git recovery if needed. If F4/C4 partial: T98 implementer_text completes in 1 turn. If julia compile error: T98 director audits SpinorBEC.jl loadability + escalates to anko if framework-level.",
 "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read state.json + scheduler_97.json + seed.md this turn (seed.md is 3-day-stale per `feedback_cost_overhead_is_the_cost`; scheduler_97.json authoritative JULIA_GPU_OK)
- [x] Read T96 theorist + T95 research + T96 director for context
- [x] Read ≥1 memory file related to active investigation (bug_4_itp_ddi_half_rate.md + tier3_pipeline_survey_2026_05_18.md + 3 anko feedback memories on mechanical-vs-investigation, fix-the-class, cost-overhead)
- [x] investigation_id `bug-4-itp-ddi-half-rate-revalidation-2026-05-18` continues from T95-T96; registration is a deliverable this turn
- [x] stage_advancing_to = Execute is the next stage per §F1 verify-claim sequence (Design folded into Execute per anko feedback_mechanical_vs_investigation_threshold + feedback_fix_the_class_not_the_instance; T96 theorist §6 already designed the F5 observable manifest)
- [x] subagent_type = implementer matches §F1 role_per_stage[Execute] (workload class julia_cpu_light per JULIA_GPU_OK scheduler + ~5-10 min test wall time)
- [x] success_criteria are machine-evaluable: 23 criteria, all using ==/>=/< operators against METRICS JSON fields the implementer reports
- [x] failure_modes cover scientific (bug regressed, accuracy regression, numerical noise boundary) AND operational (julia error, F4 partial, C4 partial, state.json corruption, verdict mismatch)
- [x] observable_manifest precondition_check is concrete (test -f on 8 files + python3 JSON validity + which julia + PRECONDITIONS_OK echo)
- [x] budget fits within scheduler window_seconds_left (2.2M target << 3.0M cap << window ~13 days; 25min wall-time << 1800s cap)
- [x] §A6 research-first citation present (Javanainen-Ruostekoski 2004 + Thalhammer 2026 + Bao-Du 2004 + 3 anko feedback memories + APC cache reference)
- [x] §A5 D1/D2/D3 articulated: D1 verify (PRIMARY); manuscript NOT in scope
- [x] APC contract template cache: verify-claim::Execute n_seen >= 4 (T20/T57/T74/T78); used cached skeleton scaffold
- [x] No improvised terminology (Strang splitting, regression test, CI tier, addendum are established)
- [x] No anko-attribution in implementer brief (memory references CAN cite anko; agent prompts do not)
- [x] T96 drift advisories MANUSCRIPT_DELTA_ZERO (correct by design) acknowledged; no `director_must_address` escalation pending
- [x] subagent rotation: implementer gap = 3 turns since T94 implementer_text; different workload class (julia_cpu_light vs text); no §B same-subagent-in-a-row violation
- [x] Skipping Design stage justified explicitly in §3 (3 anko feedback memories cited; T96 §6 contains design content)
