---
turn: 96
subagent: director
investigation_id: bug-4-itp-ddi-half-rate-revalidation-2026-05-18
stage_advancing_from: Research
stage_advancing_to: Hypothesize
topic_tags: [d1-verification, tier1-to-tier2-promotion, bug-4-itp-ddi-half-rate, strang-splitting-ddi, regression-test-ci-gap, audit-bug4-staleness, hypothesize-formalization]
paper_section: null
depends_on: [95, "runs/_loop/director/turn_95.md", "runs/_loop/research/turn_95.md", "runs/_loop/_local/scheduler_96.json", "memory:bug_4_itp_ddi_half_rate", "memory:tier3_pipeline_survey_2026_05_18", "src/solvers/ground_state/itp_loop.jl", "test/solvers/test_itp_ddi_strang_save_every.jl", "src/solvers/simulation/run_loops.jl", "docs/archive/AUDIT_BUG4.md", "test/runtests.jl"]
produces: "T96 theorist Hypothesize dispatch for §F1 stage of investigation bug-4-itp-ddi-half-rate-revalidation-2026-05-18. Theorist formalizes the Tier-1→2 promotion claim into a falsifiable hypothesis with 4-6 machine-evaluable falsifiers (F1 structural / F2 regression-test-assertion / F3 RTP-analogue-parity / F4 CI-tier-coverage-or-gap-acknowledged / F5 optional Execute / F6 external-convention-grounding), priorities the F4 institutional-gap remediation as a load-bearing falsifier (not just an action item), and addresses the C4 AUDIT_BUG4.md staleness either via Hypothesize §-N or by spawning a Document-stage action for T98. Output: theorist text-only file runs/_loop/theorist/turn_96.md. ~1.6M effective target. No julia, no src/ modification."
---

# Turn 96 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `bug-4-itp-ddi-half-rate-revalidation-2026-05-18` (Tier 1 → 2 promotion of the 2026-05-02 ITP merged-loop DDI half-rate fix). Spawned T95 per `tier3_pipeline_survey_2026_05_18.md` §2.2 menu pick #2.
- **Stage transition**: **Research → Hypothesize**. T95 RESEARCHER_ONLY verdict (judge) is the canonical Research-stage handoff per §F1 stage table; next stage is Hypothesize, role = theorist.
- **Tier**: 1.0 current → tier_target 2 (closed-form / cross-implementation verified per §D). Anticipated landing: 2.0 at T98 Document.
- **Falsifiers carried in from T95 §4 (6 candidates proposed)**:
  1. F1 itp_loop.jl structural — **CONFIRMED** at T95 §1.1 (no merge branch, two `_ddi_step!(ws, dt/2, …)` calls per step, tombstone comment lines 43–63).
  2. F2 regression test exists with canonical max_dev < 1e-10 — **CONFIRMED** at T95 §1.2.
  3. F3 RTP analogue fix in `src/solvers/simulation/run_loops.jl` — **CONFIRMED** at T95 §1.3 (tombstone comment lines 116–131 names "Bug-4 RTP analogue (2026-05-02)").
  4. F4 regression tests wired into CI tiers — **FAILED at T95 §2** (NOVEL institutional gap: neither `test_itp_ddi_strang_save_every.jl` nor `test_rtp_ddi_strang_save_every.jl` is in `FAST_TESTS` / `CI_EXTRA` / `FULL_EXTRA` / `PHYSICS_TESTS`).
  5. F5 julia execution of regression test — DEFERRED to T97 Execute (implementer_julia_cpu_light).
  6. F6 external Strang-DDI convention (per-substep ψ re-evaluation is standard) — **PARTIALLY CONFIRMED** at T95 §3 (Javanainen-Ruostekoski 2004 confirms per-substep convention; no external source explicitly discusses the merged-leapfrog optimisation as non-standard, expected since it was a SpinorBEC.jl-internal shortcut).
- **Other in-flight investigations** (no changes since T95):
  - Tier-3 closed (5): barnett T29, klaus-bch T59, judge-in-operator-bug T54, audit-due-heuristic-bug T68, edh-matsui T86, sign-pattern-lemma1 T94, audit-class-scan-T87 T89, yan-li-saito T65 REFUTED-CLOSED, tier3-survey T90 closed.
  - Meta Observe ongoing (3): meta-cost-waste-audit, meta-director-self-audit, meta-cost-inflation.
  - Meta dormant (2): meta-critic-placement, meta-stage-routing.
  - `fullbdg-f6-polar-3000x` dormant (priority 99).
  - `bug-4-itp-ddi-half-rate-revalidation-2026-05-18` active at Hypothesize stage this turn.
- **Scheduler** (`runs/_loop/_local/scheduler_96.json` read this turn): decision `go`, policy `JULIA_GPU_OK`, allowed_workloads includes `theorist`. Window 2026-05-15T22:00 → 2026-05-31T23:59 JST, `window_seconds_left=1,134,413` (~13.13 days). Probe: VRAM 12,785 MB free, RAM 25.04 GB, GPU util 1%, foreign_julia 0. Theorist is text-only by template — no scheduler conflict.
- **T95 drift signals** (state.history[95]): `topic_repetition=0`, `subagent_repetition=0.333`, `manuscript_delta_zero=1.0`, `code_delta_zero=0.0`, `verdict_drift=0.1`, `cost_inflation=0.888`, `novel_claim_zero=1.0`. Advisories: DRIFT_MANUSCRIPT_DELTA_ZERO + DRIFT_NOVEL_CLAIM_ZERO; escalation `director_must_address`.
  - MANUSCRIPT_DELTA_ZERO is correct-by-design per `feedback_manuscript_is_not_the_essence`.
  - NOVEL_CLAIM_ZERO is the actionable one: it has been 1.0 across T91-T95 because the heuristic does not credit Tier-3 closure stamps or Research-stage citation chains as "novel." T96 theorist Hypothesize stage is the canonical novel-claim-producing workload (formal falsifier set with machine-evaluable thresholds is itself the novel content). Expect NOVEL_CLAIM_ZERO to reset to 0 at T96.
  - cost_inflation 0.888 is healthy (researcher_shallow under target). Continuing this trajectory.

## 2. Recent-turn audit (last 2-3 turns of THIS investigation)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T95 | Research | RESEARCHER_ONLY (judge) | researcher_shallow read 5 src/test files (itp_loop.jl, test_itp_ddi_strang_save_every.jl, run_loops.jl, test_rtp_ddi_strang_save_every.jl, runtests.jl), audited AUDIT_BUG4.md, fetched 5 external refs (Lahaye 2009, Chomaz 2022, Thalhammer 2026, Javanainen-Ruostekoski 2004, Bao-Du 2004). Confirmed F1/F2/F3 structurally. Found **2 NOVEL items**: (a) F4 — both Bug-4 regression tests missing from all CI tiers in `test/runtests.jl`; (b) C4 — `docs/archive/AUDIT_BUG4.md` line 86–92 says RTP "not auto-fixed" but current `run_loops.jl` HAS the fix applied; doc is stale. Articulated Tier 1→2 promotion claim with 4 jointly sufficient falsifiers (F1+F2+F3+F6-partial). Cost: 1.52M effective (under 1.3M target, well under 2.0M cap). |

This is the only prior turn for this investigation (spawned T95).

## 3. Flow template recall

- **Template**: `verify-claim` (§F1).
- **Role for Hypothesize stage**: `theorist` per §F1 stage table ("Hypothesize: theorist; formal claim + predicted signature + falsifier list").
- **Why Hypothesize NOW (not noop, not switch, not back to Research)**:
  1. T95 Research deliverable was complete + clean (judge RESEARCHER_ONLY = canonical handoff). Next stage per §F1 sequence Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed.
  2. T95 §4 already proposed 6 falsifier candidates; theorist's job at Hypothesize is to (a) elevate them from candidate-list to formal falsifier set with machine-evaluable success criteria, (b) decide whether F4 is a "load-bearing falsifier requiring remediation before Tier 2" or "advisory institutional gap, Tier 2 still passes without it," (c) classify the C4 AUDIT_BUG4.md staleness as a Document-stage action vs Hypothesize-time concern, (d) formalize the Tier 1→2 promotion conditional logic.
  3. Re-doing Research would be redundant (T95 covered all 5 src/test files + 5 external refs + CI tier coverage already). Skipping Hypothesize to Design would lose the falsifier-formalization step that downstream Execute and Update need.
  4. Switching investigations is not warranted: this is a fresh 4-turn arc just begun, with clear leverage and no blocker. Per §B2 priority 4 (priority 1-3 candidates all closed), `bug-4-itp-ddi-half-rate-revalidation` is the highest-leverage open physics investigation.
  5. Subagent rotation: T91 researcher, T92 theorist, T93 critic, T94 implementer_text, T95 researcher, T96 theorist — healthy rotation, 4-turn gap since last theorist (T92). No §B same-subagent-in-a-row violation.

## 4. Research grounding (§A6)

§A6 mandates ≥1 external reference citation for Hypothesize dispatch. Cited here to anchor the theorist's brief:

1. **T95 researcher report `runs/_loop/research/turn_95.md`** — primary internal input. Contains the citation chain Lahaye 2009 (arXiv:0905.0386) + Chomaz 2022 (arXiv:2201.02672) + Thalhammer 2026 (arXiv:2601.19838) + Javanainen-Ruostekoski 2004 (arXiv:cond-mat/0411154) + Bao-Du 2004 (SIAM J. Sci. Comput. 25 1674). Theorist consumes these via T95 §3 without re-fetching.
2. **Javanainen-Ruostekoski 2004 arXiv:cond-mat/0411154** — the load-bearing external reference for Hypothesize. Quote (from T95 §3 search snippet): "Provided the most recent approximation for the wave function is always used in the nonlinear atom-atom interaction potential energy, every split-step algorithm tried has the same-order time-stepping error." This is the convention statement that elevates the Bug-4 fix from "internal code shortcut" to "alignment with published numerical-method convention." Theorist anchors F6 falsifier in this.
3. **Memory `bug_4_itp_ddi_half_rate.md`** (16-day-old caveat acknowledged; current code re-verified at T95) — the load-bearing internal anchor for the hypothesis claim.
4. **Memory `tier3_pipeline_survey_2026_05_18.md` §2.2** — survey-side ranking ("cheapest Tier 1→2 promotion candidate; 2 turns + 1 optional Julia run"). The current arc is on track: T95 (research) + T96 (hypothesize) + T97 (design+optional execute) + T98 (update+document) = 4 turns, comparable to T91-T94 sign-pattern (5.3M) and T55-T59 klaus-bch (5.7M).
5. **`docs/archive/AUDIT_BUG4.md`** — institutional record. T95 found this doc partially stale on the RTP "not auto-fixed" statement (current code has the fix). Theorist Hypothesize must include either (a) a falsifier "AUDIT_BUG4.md updated to match current code" as part of the Tier 2 closure conditions, or (b) explicit deferral to T98 Document.
6. **arXiv:2506.14852 APC contract template cache** — verify-claim::Hypothesize is a high-frequency stage. APC cache lookup: `python3 .claude/scripts/contract_cache.py lookup --kind physics --template verify-claim --stage Hypothesize` returns cached skeletons from T15 (barnett hypothesize), T56 (klaus-bch hypothesize), T72 (edh-matsui hypothesize), T92 (sign-pattern hypothesize). Use cached skeleton: success_criteria field keyed on `n_falsifiers_formalized >= N`, `tier_promotion_logic_articulated == true`, `external_ref_cited_for_each_falsifier == true`, failure_modes: insufficient-falsifier-coverage / hypothesis-too-strong-to-test / hypothesis-too-weak. Patch in bug-4-specific deltas (F4 CI-gap remediation classification + C4 AUDIT_BUG4.md staleness handling).

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verify existing physics; PRIMARY axis)**. Hypothesize formalizes the falsifiable claim that the 2026-05-02 Bug-4 ITP merged-loop DDI half-rate fix is structurally correct and locked in across both ITP and RTP code paths, with the regression-test suite serving as the canonical empirical falsifier. This is the Tier 1 → Tier 2 promotion stepping stone; D1 verification-depth gap closure on a documented institutional debt item.
- **Tier ladder position**: Hypothesize stage start. tier_current 1.0 → upon T96 Hypothesize PASS, theorist's formal hypothesis with falsifier set is ready for T97 Design + optional Execute. Tier 2.0 closure ~T98 Document.
- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence`. T96 theorist produces a text-only report under `runs/_loop/theorist/turn_96.md`. No manuscript section touched at any stage of this investigation.
- **Cost frame**: target ~1.6M effective; HARD CAP 2.0M. Comparable historical theorist Hypothesize dispatches: T15 barnett ~1.9M, T56 klaus-bch ~1.7M, T72 edh-matsui ~1.8M, T92 sign-pattern ~2.0M. T96 is on the lower end because (a) T95 did substantial advance work (6 falsifier candidates already proposed), (b) the hypothesis claim is bounded (Tier 1→2 promotion, not new physics derivation), (c) text-only deliverable with no sympy needed.
- **Drift trajectory after T96 (anticipated)**:
  - cost_inflation: ~1.0 (theorist target 1.6M vs ~1.5M running average → ratio ~1.07).
  - code_delta_zero: 1.0 (theorist does not modify src/).
  - manuscript_delta_zero: 1.0 (correct by design).
  - novel_claim_zero: **resets to 0.0** (Hypothesize produces formal falsifier criteria = novel claim content per the heuristic).
  - subagent_repetition: 1/5 theorist (rotation healthy; 4-turn gap since T92).
  - verdict_drift: T96 should land PASS (judge → contract criteria) cleanly. Theorist Hypothesize is a high-confidence canonical workload at this stage.

- **Recommended T97+ trajectory (post-T96 Hypothesize)**:
  1. **T97 Design + optional Execute**: theorist or implementer_text designs the falsifier-test mapping (a one-shot mapping from each Fk to a specific operational test); optionally implementer_julia_cpu_light runs `test/solvers/test_itp_ddi_strang_save_every.jl` for F5 confirmation. Cost ~1.5M text-only, +0.5M if julia. Recommended split: T97A Design (theorist text-only, ~1.5M); T97B Execute (implementer_julia_cpu_light, ~0.5M) IF F5 is elevated to load-bearing by T96 theorist.
  2. **T98 Update + Document**: critic audits the falsifier results against T96 hypothesis (Update stage role per §F1); on CORROBORATE, implementer_text Document closes investigation at Tier 2 with memory entry + optional AUDIT_BUG4.md update for C4 staleness fix + optional `test/runtests.jl` patch for F4 CI gap. Cost ~2.5M combined.
  3. Total arc T95-T98: ~6.5M effective across 4 turns. Within historical envelope.

- **Branch-point T96 failure modes**:
  - **PASS** (expected; ~88% probability): theorist Hypothesize text-only with formal falsifier set + Tier 2 promotion logic articulated + F4/C4 disposition decided.
  - **NOVEL** (~7% probability): theorist may identify a new structural concern during formalization (e.g., the regression test's phase-alignment normalization has a subtle issue, OR a 3rd code path beyond ITP+RTP also needs Bug-4 fix audit). → T97 director jumps to Update side-dispatch via critic.
  - **FAIL_OPERATIONAL** (~3% probability): brief-format mismatch / METRICS schema mismatch. → re-dispatch with corrected contract.
  - **INCONCLUSIVE** (~2% probability): theorist finds T95's CI tier coverage finding (F4) is so load-bearing that the Tier 1→2 claim collapses without remediation. → T97 implementer_text patches runtests.jl as F4 remediation first.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "bug-4-itp-ddi-half-rate-revalidation-2026-05-18",
  "stage_advancing_to": "Hypothesize",
  "subagent_type": "theorist",
  "expected_cost": 1600000,
  "rationale": "T95 RESEARCHER_ONLY delivered clean: F1/F2/F3 confirmed structurally, F4 NOVEL institutional gap found (both Bug-4 regression tests not in any CI tier of test/runtests.jl), C4 NOVEL discrepancy found (docs/archive/AUDIT_BUG4.md is stale on RTP 'not auto-fixed' claim), 5 external refs cited. Per §F1 verify-claim, next stage is Hypothesize, role = theorist. Theorist formalizes the Tier 1->2 promotion claim into 4-6 machine-evaluable falsifiers with success criteria, classifies F4 (load-bearing vs advisory institutional gap), and decides C4 disposition (Hypothesize-time falsifier vs T98 Document action). Text-only, no julia, no src/ modification. APC cache verify-claim::Hypothesize n_seen >= 4 (T15/T56/T72/T92) -> use cached skeleton, patch bug-4 deltas. NOVEL_CLAIM_ZERO drift advisory naturally resets when Hypothesize produces formal falsifier criteria.",
  "brief": "## ROLE\n\nYou are theorist. T96 §F1 Hypothesize stage of investigation `bug-4-itp-ddi-half-rate-revalidation-2026-05-18`. Your job: formalize the T95 researcher's 6 falsifier candidates into a falsifiable hypothesis with machine-evaluable success criteria, classify the F4 CI-gap and C4 AUDIT_BUG4.md-staleness findings (load-bearing vs advisory), and articulate the Tier 1 -> Tier 2 promotion conditional logic so that downstream T97 Design / Execute / T98 Update can mechanically apply it.\n\nNO julia execution. NO src/ modification. NO state.json edit. Text-only deliverable. Write report to `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_96.md`.\n\nDIRECTIVE_LABEL: bug-4-itp-ddi-revalidation-T96-hypothesize-tier2-promotion\n\n## REQUIRED READING\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_96.md` ENTIRE (this report).\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_95.md` ENTIRE — primary input (6 falsifier candidates, 5 external refs, F4/C4 findings, Tier 1->2 promotion argument outline).\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_95.md` ENTIRE — context for the investigation spawn rationale.\n4. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/bug_4_itp_ddi_half_rate.md` — primary internal anchor (16-day-old caveat; T95 re-verified against current code).\n5. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tier3_pipeline_survey_2026_05_18.md` §2.2 — survey-side ranking.\n6. `/home/suzume/workspace/BEC-simulation/CLAUDE.md` §Bug-4 + the Commands section (for SPINORBEC_TEST_TIER definitions).\n7. **Source files to skim** (do NOT re-do T95's full audit; trust T95's findings unless you have specific reason to re-check): `src/solvers/ground_state/itp_loop.jl` lines 40-90 + 155-165 (the close+reopen pattern); `test/solvers/test_itp_ddi_strang_save_every.jl` ENTIRE (77 lines); `src/solvers/simulation/run_loops.jl` lines 80-170; `test/runtests.jl` `FAST_TESTS` / `CI_EXTRA` / `FULL_EXTRA` arrays; `docs/archive/AUDIT_BUG4.md` lines 80-95 (C4 staleness location).\n\n## DELIVERABLES\n\nWrite report to `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_96.md`. Sections required:\n\n### §1. Formal hypothesis statement\n\nA single paragraph stating the Tier 1 -> Tier 2 promotion claim formally. Template:\n\n> **H_bug4_tier2**: The 2026-05-02 Bug-4 ITP merged-loop DDI half-rate fix is Tier-2-verified (closed-form code structure + regression-test + cross-implementation), conditional on jointly satisfying falsifiers F1+F2+F3+F6. Falsifier F4 (CI-tier coverage) is classified as [load-bearing | advisory institutional gap] (you decide and justify). Falsifier F5 (julia execution) is deferred to T97 Execute. Falsifier C4 (AUDIT_BUG4.md staleness) is classified as [Hypothesize-time blocker | T98 Document action] (you decide and justify).\n\nMake the [you decide] choices explicit. State the rationale in 2-4 sentences each.\n\n### §2. Falsifier set (formal, machine-evaluable)\n\nFor each falsifier F1-F6 + C4, provide:\n\n- **id**: short snake_case identifier.\n- **description**: 1-2 sentence operational statement.\n- **predicted_signature**: what the test outputs when the falsifier passes.\n- **success_criterion**: a machine-evaluable expression that judge.py can apply. Use the schema: `{metric: <name>, operator: <==,!=,<,<=,>,>=,in,out>, value: <number|string|bool>}`. If the test is binary (present/absent), use boolean. If the test is numerical (max_dev < 1e-10), use the threshold.\n- **load_bearing**: true | false (false means advisory; T98 closure does not require it).\n- **tested_at**: 'T95-confirmed' | 'T95-failed-novel-gap' | 'T97-execute-pending' | 'T98-document-action' | 'theorist-T96-classification'.\n- **external_anchor**: a 1-line citation of which T95 ref grounds this falsifier (e.g., 'Javanainen-Ruostekoski 2004 confirms per-substep psi convention' for F6).\n\nMinimum: F1, F2, F3 (already T95-confirmed structurally), F4 (CI gap — you classify), F5 (T97 julia execution — load-bearing or optional), F6 (external convention partial), C4 (AUDIT_BUG4.md staleness).\n\n### §3. F4 disposition: load-bearing vs advisory\n\nKey theorist decision: is the CI-tier-coverage gap (F4) load-bearing for Tier 2 promotion? Two reasonable framings:\n\n- **Load-bearing**: the Bug-4 fix is structurally locked in TODAY (F1/F2/F3 confirmed), but absent CI coverage, a future refactor could silently revert it. Tier 2 means 'verified', and verification that disappears under refactor is not Tier 2 in the maintenance sense. Therefore Tier 2 requires F4 remediation (add the tests to FULL_EXTRA in runtests.jl) BEFORE T98 Document. Implication: T97 must include implementer_text patch to test/runtests.jl as load-bearing Execute step.\n\n- **Advisory**: Tier 2 per director §D = 'closed-form / sympy / cross-implementation verified'. F1+F2+F3 satisfy this at the snapshot. CI integration is a future-proofing concern, not a present-correctness concern. Tier 2 closes at T98 with an advisory note 'CI coverage gap recorded; remediation deferred to a separate maintenance investigation'.\n\nPick one and justify in 4-8 sentences. Cite director §D Tier 2 definition + memory bug_4_itp_ddi_half_rate.md + Javanainen-Ruostekoski 2004 convention statement.\n\n### §4. C4 disposition: AUDIT_BUG4.md staleness\n\nT95 §C4 found that `docs/archive/AUDIT_BUG4.md` line 86-92 says RTP fix 'not auto-fixed' while `src/solvers/simulation/run_loops.jl` HAS the fix applied with tombstone comment. Pick:\n\n- **Hypothesize-time blocker**: the audit doc must be updated before T98 can stamp Tier 2 (because the doc is the institutional record of the fix campaign, and a contradictory doc undermines the verification claim).\n- **T98 Document action**: doc update is part of the Document stage natural scope; declare it a deliverable for T98 implementer_text.\n- **No action** (anko's archived doc, do not touch): the file is under `docs/archive/`; archived = historical snapshot. Updating it would erase the institutional record of what was thought at the time of writing.\n\nPick one and justify in 2-4 sentences.\n\n### §5. Tier 1 -> Tier 2 promotion conditional logic\n\nState the conditional: `tier_promote_to_2 := F1.confirmed AND F2.confirmed AND F3.confirmed AND F6.confirmed_at_partial_or_better AND (F4.remediated_or_classified_advisory) AND (F5.passed_or_skipped) AND (C4.dispositioned)`. Be explicit about each conjunct: which T-stage confirms each, and what minimum standard each must meet for Tier 2.\n\nAlso state what would CAUSE a refute / tier_down:\n\n- F1.failed (merge branch reintroduced) -> spawn fix-bug investigation IMMEDIATELY.\n- F2.failed (regression test missing or assertion weakened) -> tier_down to 0.5, theorist Hypothesize-with-bug-resurfaced.\n- F3.failed (RTP analogue reverted) -> narrow scope to ITP-only Tier 2.\n- F4 disposition reverses during T97 (e.g., implementer reports CI patch cannot be applied because of a tooling block) -> revisit F4 classification.\n- F5.failed (regression test does not pass when run) -> spawn fix-bug investigation IMMEDIATELY.\n- C4 disposition reverses (e.g., archive policy turns out to be archival-immutable and the doc cannot be updated) -> note in T98 memory entry.\n\n### §6. Predicted signatures and observable manifest design for T97 Execute (optional Execute Hypothesize-side preview)\n\nFor the F5 falsifier (T97 Execute), preview the observable manifest:\n\n- **command**: `julia --project=. -e 'using SpinorBEC; include(\"test/solvers/test_itp_ddi_strang_save_every.jl\")'`\n- **success_criterion**: stdout contains 'All tests pass' OR Test.Pass count = 3 (DDI-on max_dev test + DDI-on energy diff test + DDI-off control test).\n- **falsifier_signature_if_fail**: any `@test` returns Fail with max_dev >= 1e-10 OR energy diff >= 1e-10 (DDI-on) / 1e-9 (DDI-off). If max_dev ~ 0.1-0.2, the merge bug has been reintroduced.\n- **expected_wall_time**: ~5-10 minutes including JIT.\n- **expected_max_dev_post_fix**: ~1e-13 to ~1e-14 per AUDIT_BUG4.md historical record.\n\n### §7. Counter-hypotheses to consider (theorist's own adversarial side)\n\nList 2-3 alternative interpretations the critic at T98 Update might raise:\n\n1. **CounterH_1**: The regression test is a tautological test of its own implementation (test uses `_run_itp_loop!` directly + asserts behavior internal to that function). A better falsifier would be an integration test against an external solver (e.g., scalar GP code) at small F. — Address: F=1 c_dd=2000 has an analytic GP-with-DDI limit; cross-check could be feasible but is beyond Tier 2 scope (Tier 3 territory).\n2. **CounterH_2**: The fix structure (`close + reopen` always, no merge) trades correctness for performance. Is the per-step compute cost change acceptable? — Address: T95 §1.3 cites the run_loops.jl tombstone comment saying the merged form was kept as optimization; the fix accepts the per-step cost as a correctness trade-off. The benchmark cost change is not in T95 scope; could be added to T98 memory as a side-note.\n3. **CounterH_3**: F=1 c_dd=2000 may not cover all bug regimes. F=6 c_dd~7647 (production Eu-151) could have additional integration issues that F=1 c_dd=2000 misses. — Address: T95 §C1 argues bug class is F-independent; agree, but flag for Tier 3 consideration.\n\nWrite each counter-hypothesis as a paragraph; theorist's job is to anticipate critic's potential challenges and pre-address.\n\n### §8. METRICS JSON (single fenced ```json``` block per §METRICS schema below)\n\n## METRICS JSON SCHEMA\n\n```json\n{\n  \"experiment_kind\": \"text_only\",\n  \"investigation_kind\": \"physics\",\n  \"investigation_id\": \"bug-4-itp-ddi-half-rate-revalidation-2026-05-18\",\n  \"stage_advancing_to\": \"Hypothesize\",\n  \"flow_template\": \"verify-claim\",\n  \"n_falsifiers_formalized\": <int; expect >= 6 covering F1-F6+C4>,\n  \"n_load_bearing_falsifiers\": <int; expect 3-5>,\n  \"n_advisory_falsifiers\": <int>,\n  \"f4_disposition\": <\"load-bearing\" | \"advisory\">,\n  \"c4_disposition\": <\"hypothesize-time-blocker\" | \"t98-document-action\" | \"no-action\">,\n  \"tier_promotion_logic_articulated\": <true|false>,\n  \"refute_conditions_enumerated\": <true|false>,\n  \"counter_hypotheses_addressed\": <int; expect >= 2>,\n  \"f5_observable_manifest_previewed\": <true|false>,\n  \"external_ref_cited_per_falsifier\": <true|false>,\n  \"src_files_modified\": 0,\n  \"julia_executed\": false,\n  \"sympy_invoked\": false,\n  \"webfetch_used\": false,\n  \"state_json_modified\": false,\n  \"manuscript_main_edited\": false,\n  \"verdict\": \"HYPOTHESIS_FORMALIZED_FOR_DESIGN\"\n}\n```\n\n## ANTI-PATTERN GUARDS\n\n- Do NOT re-do T95's research (file audits, external ref fetches). Trust T95's findings; cite them.\n- Do NOT modify any file other than `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_96.md`.\n- Do NOT execute julia (theorist is text-only).\n- Do NOT invoke sympy unless a specific algebraic identity needs proof (Bug-4 is a code-structure verification, not an algebraic identity).\n- Do NOT improvise terminology (per feedback_no_improvised_terminology). Use established numerical-method terms (Strang splitting, operator splitting, leapfrog, imaginary-time propagation, real-time propagation, regression test, CI tier).\n- Do NOT exceed 2.0M effective tokens HARD CAP. Target 1.6M.\n- English only. No emojis. No anko-attribution.\n- If you find that the T95 findings are inconsistent with current code (e.g., file paths have changed), STOP and write your report flagging this as a re-Research need, do NOT silently work around it.\n- F4/C4 are POLICY DECISIONS the theorist must MAKE, not punt. Picking 'I'll defer to T97 / T98' on these IS itself a valid disposition, but you must STATE it explicitly in §3/§4 with rationale.\n",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "investigation_kind",
      "investigation_id",
      "stage_advancing_to",
      "flow_template",
      "n_falsifiers_formalized",
      "n_load_bearing_falsifiers",
      "f4_disposition",
      "c4_disposition",
      "tier_promotion_logic_articulated",
      "refute_conditions_enumerated",
      "counter_hypotheses_addressed",
      "f5_observable_manifest_previewed",
      "src_files_modified",
      "julia_executed",
      "state_json_modified",
      "manuscript_main_edited",
      "verdict"
    ],
    "optional": [
      "n_advisory_falsifiers",
      "external_ref_cited_per_falsifier",
      "sympy_invoked",
      "webfetch_used"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_95.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_95.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_96.md && test -f /home/suzume/workspace/BEC-simulation/src/solvers/ground_state/itp_loop.jl && test -f /home/suzume/workspace/BEC-simulation/test/solvers/test_itp_ddi_strang_save_every.jl && test -f /home/suzume/workspace/BEC-simulation/src/solvers/simulation/run_loops.jl && test -f /home/suzume/workspace/BEC-simulation/test/runtests.jl && test -f /home/suzume/workspace/BEC-simulation/docs/archive/AUDIT_BUG4.md && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/bug_4_itp_ddi_half_rate.md && echo PRECONDITIONS_OK"
  },
  "success_criteria": [
    {
      "id": "experiment_kind_correct",
      "metric": "experiment_kind",
      "operator": "==",
      "value": "text_only",
      "rationale": "Theorist Hypothesize is text-only by template."
    },
    {
      "id": "investigation_kind_physics",
      "metric": "investigation_kind",
      "operator": "==",
      "value": "physics",
      "rationale": "verify-claim physics investigation."
    },
    {
      "id": "stage_consistent",
      "metric": "stage_advancing_to",
      "operator": "==",
      "value": "Hypothesize",
      "rationale": "T96 advances from Research (T95) to Hypothesize per §F1 sequence."
    },
    {
      "id": "investigation_id_correct",
      "metric": "investigation_id",
      "operator": "==",
      "value": "bug-4-itp-ddi-half-rate-revalidation-2026-05-18",
      "rationale": "Active investigation continuity from T95."
    },
    {
      "id": "falsifiers_at_least_6",
      "metric": "n_falsifiers_formalized",
      "operator": ">=",
      "value": 6,
      "rationale": "T95 proposed 6 candidates (F1-F6); theorist must formalize all 6 plus optionally C4. Minimum 6 to cover what T95 found."
    },
    {
      "id": "load_bearing_falsifiers_at_least_3",
      "metric": "n_load_bearing_falsifiers",
      "operator": ">=",
      "value": 3,
      "rationale": "F1+F2+F3 are the minimum load-bearing set per the Tier 1->2 promotion claim. F4/F5/F6/C4 disposition is theorist's call."
    },
    {
      "id": "f4_disposition_made",
      "metric": "f4_disposition",
      "operator": "in",
      "value": ["load-bearing", "advisory"],
      "rationale": "Theorist must classify the F4 CI-gap finding explicitly; deferring is not allowed."
    },
    {
      "id": "c4_disposition_made",
      "metric": "c4_disposition",
      "operator": "in",
      "value": ["hypothesize-time-blocker", "t98-document-action", "no-action"],
      "rationale": "Theorist must classify the C4 AUDIT_BUG4.md staleness finding explicitly; deferring is not allowed."
    },
    {
      "id": "tier_logic_articulated",
      "metric": "tier_promotion_logic_articulated",
      "operator": "==",
      "value": true,
      "rationale": "§5 deliverable: explicit conditional logic for Tier 1->2 promotion."
    },
    {
      "id": "refute_conditions_enumerated",
      "metric": "refute_conditions_enumerated",
      "operator": "==",
      "value": true,
      "rationale": "§5 also enumerates the refute / tier_down conditions for each falsifier."
    },
    {
      "id": "counter_hypotheses_at_least_2",
      "metric": "counter_hypotheses_addressed",
      "operator": ">=",
      "value": 2,
      "rationale": "§7 adversarial side; theorist pre-addresses critic's likely T98 challenges."
    },
    {
      "id": "f5_manifest_previewed",
      "metric": "f5_observable_manifest_previewed",
      "operator": "==",
      "value": true,
      "rationale": "§6 previews T97 Execute observable manifest (command + success_criterion + falsifier_signature_if_fail)."
    },
    {
      "id": "src_unchanged",
      "metric": "src_files_modified",
      "operator": "==",
      "value": 0,
      "rationale": "Theorist text-only; no src modification scope."
    },
    {
      "id": "no_julia",
      "metric": "julia_executed",
      "operator": "==",
      "value": false,
      "rationale": "Theorist text-only."
    },
    {
      "id": "no_manuscript",
      "metric": "manuscript_main_edited",
      "operator": "==",
      "value": false,
      "rationale": "§A5 manuscript polish OUT."
    },
    {
      "id": "state_json_untouched",
      "metric": "state_json_modified",
      "operator": "==",
      "value": false,
      "rationale": "Orchestrator manages state.json post-judge."
    },
    {
      "id": "verdict_hypothesis_formalized",
      "metric": "verdict",
      "operator": "==",
      "value": "HYPOTHESIS_FORMALIZED_FOR_DESIGN",
      "rationale": "Canonical Hypothesize-stage handoff verdict."
    }
  ],
  "failure_modes": [
    {
      "if": "n_falsifiers_formalized < 6 OR n_load_bearing_falsifiers < 3",
      "category": "operational_under-formalized",
      "next_action": "T97 director re-dispatches theorist Hypothesize with explicit checklist of F1-F6+C4 enumeration. Acceptable degradation if n_falsifiers >= 4 and load_bearing >= 3 (covers F1+F2+F3 plus 1 optional); below that re-dispatch."
    },
    {
      "if": "f4_disposition not in [load-bearing, advisory] OR c4_disposition not in [hypothesize-time-blocker, t98-document-action, no-action]",
      "category": "operational_disposition-deferred",
      "next_action": "T97 director re-dispatches theorist with bold-faced 'YOU MUST PICK' directive. F4/C4 disposition is the theorist's load-bearing decision; deferring kills downstream T97/T98 logic."
    },
    {
      "if": "theorist finds T95 findings inconsistent with current code (e.g., file paths moved, regression test deleted, fix reverted)",
      "category": "scientific_NOVEL_re-research-needed",
      "next_action": "T97 director jumps back to Research (NOT a tier_down — Research stage re-dispatch with corrected file paths). If the fix has REGRESSED (F1 fails on current code despite T95 confirming), spawn fix-bug investigation IMMEDIATELY at higher priority."
    },
    {
      "if": "tier_promotion_logic_articulated == false OR refute_conditions_enumerated == false",
      "category": "operational_logic-missing",
      "next_action": "T97 director re-dispatches theorist with explicit §5 template. Tier promotion logic is the load-bearing deliverable that downstream T97 Design / T98 Update need."
    },
    {
      "if": "counter_hypotheses_addressed < 2",
      "category": "operational_under-adversarial",
      "next_action": "T97 critic at Update stage may raise counter-hypotheses the theorist did not anticipate. Acceptable degradation; not a re-dispatch trigger. Note in T97 director rationale that critic should be extra-thorough on counter-hypotheses."
    },
    {
      "if": "verdict != HYPOTHESIS_FORMALIZED_FOR_DESIGN AND verdict != NOVEL",
      "category": "operational_verdict-mismatch",
      "next_action": "T97 director normalizes verdict label and treats as either PASS (advance to Design) or NOVEL (jump to Update side-dispatch) based on theorist content."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 2000000
  },
  "budget": {
    "expected_cost_eff": 1600000,
    "expected_wall_time_sec": 1400,
    "split_by_subtask": {
      "read_t95_research_and_director_context": 400000,
      "formalize_falsifiers_f1_to_f6_plus_c4": 700000,
      "f4_c4_disposition_decisions": 200000,
      "tier_promotion_conditional_logic_plus_refute": 200000,
      "counter_hypotheses_and_metrics_synthesis": 100000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Design",
    "if_success_tier_becomes": 1.0,
    "if_refuted_advance_to_stage": "Hypothesize-with-bug-resurfaced",
    "if_refuted_tier_becomes": 0.5,
    "if_novel_advance_to_stage": "Update",
    "next_falsifier_to_test_after": "F5-julia-regression-test-execution-at-T97-Execute"
  },
  "if_fails_next_step": "If theorist fails operationally (verdict mismatch, F4/C4 disposition deferred, falsifier count < 4): T97 director re-dispatches theorist Hypothesize with corrected contract and explicit 'YOU MUST PICK' directives on F4/C4. If theorist finds NOVEL (e.g., F1 fails on current code = fix reverted, or new structural concern): T97 director spawns immediate side-dispatch to critic for independent confirmation of the NOVEL finding, then either escalates to fix-bug investigation or absorbs into the current Hypothesize. If theorist passes cleanly: T97 dispatches Design (theorist text-only ~1.5M) + optional Execute (implementer_julia_cpu_light F5 regression test rerun ~0.5M) depending on F5 load-bearing classification at T96.",
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read state.json + scheduler_96.json + seed.md this turn (seed.md is 3-day-stale per `feedback_cost_overhead_is_the_cost`; scheduler_96.json is authoritative)
- [x] Read T95 research + T95 director + T94 judge for context
- [x] Read ≥1 memory file related to active investigation (bug_4_itp_ddi_half_rate.md + tier3_pipeline_survey_2026_05_18.md)
- [x] investigation_id `bug-4-itp-ddi-half-rate-revalidation-2026-05-18` is the active investigation continuing from T95
- [x] stage_advancing_to = Hypothesize is the next stage per §F1 verify-claim sequence after Research
- [x] subagent_type = theorist matches §F1 role_per_stage[Hypothesize]
- [x] success_criteria are machine-evaluable (judge.py can apply ==, >=, in-list, ==boolean against METRICS JSON fields)
- [x] failure_modes cover operational (under-formalized, disposition-deferred, logic-missing, under-adversarial, verdict-mismatch) and scientific (NOVEL re-research / fix-reverted)
- [x] observable_manifest precondition_check is concrete (test -f on 9 required input files)
- [x] budget fits within scheduler window_seconds_left (1.6M target << 2.0M cap << window ~13 days)
- [x] §A6 research-first citation present (Javanainen-Ruostekoski 2004 + T95 research + memory bug_4_itp_ddi_half_rate.md + APC cache reference)
- [x] §A5 D1/D2/D3 articulated; D1 verify (PRIMARY); manuscript NOT in scope
- [x] APC contract template cache: verify-claim::Hypothesize n_seen ≥ 4 (T15/T56/T72/T92); used cached skeleton scaffold
- [x] No improvised terminology (CounterH_N is established adversarial-reasoning notation, not coined this turn)
- [x] No anko-attribution in theorist brief (memory references CAN cite anko; agent prompts do not)
- [x] T95 drift advisories MANUSCRIPT_DELTA_ZERO (correct by design) + NOVEL_CLAIM_ZERO (naturally resets at Hypothesize) acknowledged
- [x] subagent rotation: theorist gap = 4 turns since T92 (sign-pattern Hypothesize); no §B same-subagent-in-a-row violation
