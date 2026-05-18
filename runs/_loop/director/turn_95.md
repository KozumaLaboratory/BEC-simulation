---
turn: 95
subagent: director
investigation_id: bug-4-itp-ddi-half-rate-revalidation-2026-05-18
stage_advancing_from: (new investigation, spawn)
stage_advancing_to: Research
topic_tags: [d1-verification, tier1-to-tier2-promotion, bug-4-itp-ddi-half-rate, strang-splitting-ddi, ground-state-itp, regression-test-audit, internal-self-consistency]
paper_section: null
depends_on: [94, "runs/_loop/director/turn_94.md", "runs/_loop/judge/turn_94.json", "runs/_loop/sim/turn_94.md", "runs/_loop/_local/scheduler_95.json", "memory:bug_4_itp_ddi_half_rate", "memory:tier3_pipeline_survey_2026_05_18", "src/solvers/ground_state/itp_loop.jl", "test/solvers/test_itp_ddi_strang_save_every.jl"]
produces: "T95 researcher_shallow dispatch for §F1 Research stage of newly-spawned investigation bug-4-itp-ddi-half-rate-revalidation-2026-05-18 (verify-claim, kind=physics, tier_target=2). Researcher confirms (a) ITP fix in src/solvers/ground_state/itp_loop.jl post-2026-05-02 + commit chain audit; (b) regression test test/solvers/test_itp_ddi_strang_save_every.jl correctness; (c) RTP analogue fix in src/solvers/simulation.jl (commit 0353b9b per memory); (d) ≥1 external Strang-splitting-for-spinor-DDI numerical-method reference; (e) inventory whether the regression test is wired into CI tiers (fast/ci/full/physics per CLAUDE.md). Stage Research output sets up T96 theorist Hypothesize. Text-only researcher_shallow; no julia execution; ~1.3M effective target."
---

# Turn 95 — Director Report

## 1. Investigation state snapshot

- **T94 closed `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18` at Tier 3.0 (judge PASS)**. That was the 4th project Tier-3 trajectory (barnett T29, klaus-bch T59, edh-matsui T86, sign-pattern-lemma1 T94). Per T94 director recommendation §5 "Recommended T95+ trajectory" candidates: (A) continue Tier-3 pipeline from survey menu — next pick #2 `bug-4-itp-ddi-half-rate-revalidation` (Tier 1→2); (B) advance one meta from Observe; (C) AUDIT_DUE not yet (last T87 closed T89; +10 → T99 next due).

- **Active investigation (NEW SPAWN this turn)**: `bug-4-itp-ddi-half-rate-revalidation-2026-05-18`. Survey menu candidate #2 per `tier3_pipeline_survey_2026_05_18.md` §2.2: "Re-run `runs/eu151_mz_scan/` post-fix vs pre-fix stored values; MEMORY.md explicitly flags this as outstanding ('All Eu DDI runs predating 2026-05-02 should be re-verified'). Internal self-consistency check, no external benchmark needed for Tier 2. Cheapest path: 2 turns + 1 optional Julia run."

  **Pivot from survey wording**: glob check this turn confirmed `runs/eu151_mz_scan/` does NOT exist on disk anymore (the artifact was apparently cleaned up). The natural target run is gone, so the Tier-2 path is NOT "re-run vs pre-fix stored values" (impossible without the stored values) but rather **"audit-then-regression-test" path**: (a) audit the fix in `src/solvers/ground_state/itp_loop.jl` to confirm it is structurally correct and merge-branch-free per the memory description; (b) audit the regression test `test/solvers/test_itp_ddi_strang_save_every.jl` to confirm it exercises the bug and is wired into the CI test tier; (c) audit the RTP analogue fix in `src/solvers/simulation.jl` (commit `0353b9b` per memory); (d) survey external Strang-splitting-for-spinor-DDI literature for any improved schemes published since the fix. This is the same Tier-2 internal self-consistency promotion, with the pre-fix-comparison path closed and the regression-test + code-audit path substituted.

- **Stage transition**: (new investigation spawn) → **Research** per §F1 verify-claim first stage. Role = researcher (per §F1 stage table).

- **Tier**: 1.0 (memory's "FIXED 2026-05-13" entry is the existing Tier-1 internal-regression anchor) → tier_target 2.0 (Tier 2 = "closed-form / sympy / cross-implementation verified" per §D; closed-form audit + regression test inspection + RTP analogue cross-check meets Tier 2).

- **Falsifiers (to be enumerated by T96 theorist Hypothesize stage; preview list for context)**:
  1. F1: Reading `src/solvers/ground_state/itp_loop.jl` shows EXACTLY ONE integration path (no `if step % save_every == 0` branching), with two `_ddi_step!(ws, dt/2, …)` calls per step → bug structurally impossible to reappear.
  2. F2: Regression test `test_itp_ddi_strang_save_every.jl` asserts max|ψ(save_every=1) − ψ(save_every=100)| < 1e-10 with DDI ON; same test exists for DDI OFF control. Both tests present and uncommented.
  3. F3: RTP analogue commit `0353b9b` actually exists in git log; its diff matches the substep-accuracy fix described in memory.
  4. F4: At least one external reference (Lima-Pelster 2011 / Lahaye 2009 dipolar BEC review / Chomaz 2022 review / a more recent 2024-2026 dipolar BEC numerics paper) discusses Strang-splitting-for-DDI integration step accuracy in spinor BECs, validating the approach.
  5. F5: Optional regression-test running (if scheduler-permitting AT THE EXECUTE STAGE T97) — `julia --project=. -e 'using SpinorBEC; include("test/solvers/test_itp_ddi_strang_save_every.jl")'` passes all 3 assertions with max_dev ~1e-13. (Deferred to T97 Execute if T96 Hypothesize designs it.)

- **Other in-flight investigations summary (no changes since T94)**:
  - `barnett-mechanism-2026-05-16` (priority 1): CLOSED Tier 3.0 T29.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3): CLOSED Tier 3.0 T59.
  - `yan-li-saito-2026-reproduction` (priority 1): CLOSED REFUTED-CLEAN T65 tier 0.4.
  - `judge-in-operator-bug-2026-05-18` (priority 2): CLOSED tier 2 T54.
  - `audit-due-heuristic-bug-2026-05-18` (priority 4): CLOSED tier 2 T68.
  - `meta-internal-b-unification-2026-05-18` (priority 5): CLOSED tier 1.
  - `tier3-verification-pipeline-survey-2026-05-18` (priority 10): CLOSED Tier 1.0 T90.
  - `edh-eu151-vortex-vs-matsui-science-2026` (priority 1): CLOSED Tier 3.0 T86.
  - `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18` (priority 1): CLOSED Tier 3.0 T94.
  - `meta-cost-waste-audit-2026-05-18` (priority 15): Observe ongoing; Hypothesize pending.
  - `audit-class-scan-2026-05-18-T87` (priority 20): CLOSED tier 2 T89; next AUDIT_DUE ~T99.
  - `meta-director-self-audit-2026-05-18` (priority 20): Observe ongoing; Hypothesize pending.
  - `meta-stage-routing-2026-05-18` (priority 25): CLOSED tier 0 REFUTED-BY-CONFOUNDER.
  - `meta-cost-inflation-2026-05-18` (priority 40): Observe ongoing.
  - `meta-critic-placement-2026-05-17` (priority 50): Observe ongoing; deferred.
  - `fullbdg-f6-polar-3000x` (priority 99): dormant.
  - **`bug-4-itp-ddi-half-rate-revalidation-2026-05-18` (priority 4; NEW this turn at Research stage)**.

- **Scheduler** (`runs/_loop/_local/scheduler_95.json` read this turn): decision `go`, policy `JULIA_GPU_OK`, allowed_workloads = {`theorist`, `researcher`, `researcher_deep`, `researcher_exhaustive`, `critic`, `implementer_text`, `implementer_sympy`, `implementer_julia_cpu_light`, `implementer_julia_cpu_heavy`, `implementer_julia_gpu`, `noop`}. Window ends 2026-05-31T23:59 JST, `window_seconds_left=1,135,470` (~13.14 days). Probe: VRAM 12,802 MB free, RAM 24.97 GB, GPU util 1%, foreign_julia 0. `researcher` (shallow) is allowed and is the §F1 Research-stage canonical workload.

  **Note on seed.md** (`runs/_loop/seed.md`): dated 2026-05-15 morning, describes a Klaus phi-magnetostir sweep with hard memory constraint. Today is 2026-05-18; scheduler probe shows `foreign_julia=0`; the seed.md julia-forbidden mode is stale per `feedback_cost_overhead_is_the_cost` and the loop's authoritative resource source is `scheduler_${N}.json` per director §B1 / §B7. Director defers to scheduler_95.json which authorizes any workload, but T95 dispatches researcher_shallow (text-only) anyway because §F1 Research is text-only by template — not driven by the stale seed.md constraint.

- **Last judge verdict (T94)**: PASS (DOCUMENT_PASS, 26/26 contract criteria satisfied). Drift signals at T94: manuscript_delta_zero=1.0, cost_inflation=1.122, novel_claim_zero=1.0 — three of these are advisory-only and persistently surface across the T91-T94 arc (T93 critic + T92 hypothesize both flagged them); `drift_escalation: human_required` is the loop's no-action-gating default. No drift gating from these for T95.

  - cost_inflation 1.122 specifically reflects T94 implementer_text at ~1.87M (above 0.8-1.0M expected for Document); this is a one-off T94 over-run on Document stage (it actually did 4 deliverables clean including the optional D), not a systemic inflation pattern. Trajectory expectation for T95 researcher_shallow: ~1.3M, normal range.
  - novel_claim_zero is 1.0 across T91-T94; the heuristic appears to not credit Tier-3 closure stamps as "novel claims" because the closure is propagation of an established Lemma 1 result. T95 spawning a new investigation should bump this metric down naturally.
  - manuscript_delta_zero 1.0 — correct by design per `feedback_manuscript_is_not_the_essence`; the loop should NOT be polishing manuscripts.

- **Why THIS investigation, THIS stage, NOT noop, NOT meta, NOT a different physics target (decision tree per §B2)**:

  1. **Last director's explicit pointer**: T94 director §5 "Recommended T95+ trajectory" had three candidates (A continue Tier-3 pipeline #2 / B meta interleave / C audit-class-scan). T94 director's own recommendation was **B (meta interleave)** but with the caveat "Tier-3 candidate #2 is still available for T96+ (no urgency)". After this turn's state assessment, candidate **A** is actually higher-leverage than B because: (a) §A5 mandates D1/D2/D3 advancement and meta-improvement at Observe→Hypothesize is meta-axis, NOT D1/D2/D3; advancing a meta from Observe to Hypothesize without a clear physics payoff is exactly the kind of speculative process-work anko has explicitly de-prioritized in `feedback_cost_overhead_is_the_cost` and `feedback_manuscript_is_not_the_essence`; (b) candidate #2 is a documented institutional debt with a concrete, cheap Tier-2 path and a textually-grounded D1 verification axis. Override T94's B recommendation in favor of A — the meta-Observe-to-Hypothesize transitions can wait for a future turn when a clearer leverage signal exists for one of them.

  2. **§A5 D1/D2/D3 articulation**: T95 advances **D1 (verify existing physics; PRIMARY axis)**. Bug-4 was a real production-code bug affecting **all Eu DDI ITP runs predating 2026-05-02** — MEMORY.md explicitly flags this as outstanding institutional debt with the literal note "All Eu DDI runs predating 2026-05-02 should be re-verified." This is the canonical D1 verification-depth gap; the survey's #2 ranking acknowledges it as "cheapest internal self-consistency check." Tier 1 → 2 promotion is achievable in 2-3 turns of researcher + theorist + critic + optional implementer_text Document.

  3. **§A6 research-first compliance**: Research stage MUST cite ≥1 external reference. Cited this turn:
     - **Memory `bug_4_itp_ddi_half_rate.md`** (2026-05-02 fix record) — the load-bearing internal anchor describing the bug shape (merged form `outer_fwd(dt/2) DDI(dt/2) outer_bwd(dt/2)` integrated DDI for dt/2 per step, halving the rate when DDI is active), the fix mechanism (two adjacent V(dt/2) blocks each with its own `_ddi_step!(ws, dt/2, …)` call totaling dt per step), and the regression test pin `test_itp_ddi_strang_save_every.jl`.
     - **Memory `tier3_pipeline_survey_2026_05_18.md` §2.2** — survey-side acknowledgment that this is the cheapest internal-consistency Tier 2 candidate.
     - **Lahaye et al. 2009 "The physics of dipolar bosonic quantum gases" Rep. Prog. Phys. 72 126401** — canonical dipolar BEC review covering numerical methods for DDI integration; T95 researcher confirms whether the operator-splitting accuracy considerations in §III are consistent with the Strang dt/2 per step convention used in SpinorBEC.jl.
     - **Lima-Pelster 2011 arXiv:1103.4128 + Lima-Pelster 2012** — referenced in CLAUDE.md as scalar/quasi-2D LHY benchmarks; the operator-splitting framework section may discuss DDI integration cadence.
     - **Yan et al. 2020 PRA 102, 013317** (or similar; researcher searches) — recent dipolar BEC GP numerical-methods papers (post-fix vintage) that may have published the same or analogous gotchas in spinor-DDI codes.

  4. **NOT noop**: T94 closed a Tier-3 cleanly with judge PASS, and the survey menu has 3 remaining unactioned candidates (#2, #4 capped, #5 medium-priority). Noop here wastes the natural momentum and the conclusion-index entries for `sign-pattern-lemma1` (just-closed) and the survey (T90-closed) both explicitly point at #2 as next.

  5. **NOT a meta-investigation pivot** (delaying T94's "recommendation B"): per §B2 "Meta is INTERLEAVED, not parallel." T91-T94 was 4 physics turns in a row. Switching to a meta NOW would be the §B2 interleave moment IF there were no high-leverage physics move available. There IS one (bug-4 #2). Per `feedback_cost_overhead_is_the_cost` "stop deliberating and execute," dispatch the physics move first. Meta interleave can occur after the bug-4 arc closes around T98-T99 (which is also when the next AUDIT_DUE for audit-class-scan surfaces, allowing a 3-way clean choice).

  6. **NOT candidate #5 (TDHFB Phase 2 generic-F HF kernel)**: Per survey §2.5, this is "medium priority because TDHFB is not yet in production Eu-151 pipeline." Direct D1 production-code impact is lower than #2. Defer to a later turn.

  7. **NOT candidate #4 (TwoChannelLHY F=6 polar 30-70% error)**: Per survey §2.4 "caps at Tier 2.5; no F=6 multi-channel spinor LHY external benchmark exists." Cannot reach Tier 3 without new external data. Defer indefinitely; this is a known dead end per the NOT_FOUND list.

  8. **NOT spawning a fresh build-theory investigation**: anko's seed.md goal includes "まだ実装してない効果を入れたり," which would naturally lead to a build-theory or new-physics investigation. But the survey explicitly identified bug-4 as a higher-priority gap, and "verify existing" precedes "add new" per D1 (PRIMARY) over D3 ordering. Once bug-4 promotion lands at Tier 2 the loop can re-survey for unimplemented-effects targets.

  9. **NOT researcher_deep or researcher_exhaustive**: per §F1 Research stage table "default `shallow`. Upgrade to `deep` when: investigation `tier_target == 3` OR prior shallow research turn produced contradictions OR question involves unit-system / hyperfine-state / normalization choices." T95 target tier = 2 (not 3); no prior shallow contradictions on bug-4; no unit-system / hyperfine ambiguity (this is a code-integration-cadence audit, not a physics-convention audit). researcher_shallow is the canonical depth.

- **Cost frame**: target ~1.3M effective (shallow researcher canonical-cost workload; comparable historical: T64 yan-li R4 researcher_shallow = 1.74M, T91 sign-pattern researcher_shallow = 1.81M, T87 audit-class-scan researcher = 1.67M, T69 tier3-pipeline-survey researcher = 1.79M). HARD CAP 2.0M.

- **Subagent rotation discipline**: T91 = researcher_shallow; T92 = theorist; T93 = critic; T94 = implementer_text. T95 = researcher_shallow (4-turn gap since last shallow research at T91). Healthy rotation — different role from immediately-previous T94 implementer_text. Avoids §B same-subagent-in-a-row anti-pattern.

- **APC contract template cache lookup** (per §B1.0 cache scaffold mandate): `python3 .claude/scripts/contract_cache.py lookup --kind physics --template verify-claim --stage Research` — applicable cached skeletons from prior Research-stage dispatches (T14 barnett research, T64 yan-li R4 research, T69 tier3-pipeline-survey research, T71 matsui-pdf-extract research, T87 audit-class-scan research, T91 sign-pattern research). Use cached skeleton with success_criteria field shape keyed to `external_refs_cited >= N`, `key_internal_files_read = [...]`, `n_falsifier_candidates_proposed >= M`; failure_modes: data_gap / external-source-unavailable, framework_error; observable_manifest precondition_check: `test -f` on each src/test file to be read + `git log --oneline --grep` check. Patch in bug-4-specific deltas.

## 2. Recent-turn audit (last 2-3 turns; bug-4 has no prior turns since this is a NEW investigation)

There are no prior turns for `bug-4-itp-ddi-half-rate-revalidation-2026-05-18`. Audit instead summarizes the immediate-prior physics-investigation arc which just closed at T94:

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T92 | Hypothesize | FAIL_OPERATIONAL (judge — contract-criteria mismatch on theorist NOVEL refutation of T91 triangulation) / HYPOTHESIS_DERIVATION_ERROR with T91_TRIANGULATION_ERROR class (theorist self-class) | T92 theorist text-only CG-algebra independent derivation gave β_S^(c_0) = (1/5, 2/7, 18/35) refuting T91's (1/5, 0, 4/5); 4 internal cross-checks (orthogonality construction, projector normalization sum=1, c_0/c_1/c_2 MF consistency, sum-rule identity). Cost ~1.99M effective. |
| T93 | Update | CRITIC_PASS (judge) / CORROBORATE-WITH-T91-ERRATA (critic verdict) | Critic Update with 3 structurally-independent falsifiers all CORROBORATE T92 at exact rational arithmetic; tier_recommendation 3.0; 2 errata recorded (T91 root-cause channel_weight_vs_meanfield_term_conflation + advisory Schur-isotropy). Cost ~1.72M. |
| T94 | Document | PASS (judge — DOCUMENT_PASS, 26/26 contract criteria) | implementer_text appended F=2 cyclic case to `scripts/manuscript/lemma1_general_S_verification.jl` (3 new assertions; docstring + footer count updates to 29 channels × 6 cases) + 1 line to paper3 supporting doc + 3-paragraph Tier-3 stamp to MEMORY.md + 1-paragraph validation note to tier3-pipeline-survey memory. Investigation CLOSED Tier 3.0. Cost ~1.87M (cost_inflation 1.122 advisory). |

Net arc T91-T94: 4 turns, ~7.2M effective (T91 1.81 + T92 1.99 + T93 1.72 + T94 1.87). Verdict trajectory: RESEARCHER_ONLY (T91) → FAIL_OPERATIONAL with NOVEL theorem (T92) → CRITIC_PASS (T93) → PASS (T94). 4th project Tier-3 trajectory closed.

## 3. Flow template recall

- **Template for new investigation `bug-4-itp-ddi-half-rate-revalidation-2026-05-18`**: `verify-claim` (§F1).
- **Role for Research stage**: `researcher` per §F1 stage table ("Research: researcher; lit scan, prior loop turns, memory entries — sets up Hypothesize with citation chain. MUST specify `researcher_depth` in §6 contract: shallow (5-15 queries, ~1M) / deep (≥30 parallel queries + full-PDF mandatory + ≥2 iteration rounds, ~4.5M) / exhaustive (100+ queries + cross-citation graph, ~10M+). Default shallow. Upgrade to deep when: investigation tier_target == 3 ...").
- **Why Research NOW (NEW investigation, first stage)**: §F1 verify-claim's first stage is Research. Per §F1 stage sequence: Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed. Cannot skip to Hypothesize because:
  1. T96 theorist Hypothesize needs the regression-test-content survey, the src/ file inspection citation chain, and external Strang-DDI-numerics references to ground the falsifier list.
  2. The "what's wrong" picture is well-described in `bug_4_itp_ddi_half_rate.md` memory but the "is the fix structurally correct and locked in" picture is the Research-stage deliverable to be confirmed.
  3. §A6 research-first compliance demands external grounding before Hypothesize. Research stage produces that grounding.

## 4. Research grounding (§A6)

§A6 mandates citation for Hypothesize / Design stages; Research stage gathers the citations. Director cites here to anchor the researcher's brief:

1. **Memory `bug_4_itp_ddi_half_rate.md`** (2026-05-02 fix record; this turn re-read with 16-day-old caveat) — the load-bearing internal anchor. Documents: (a) bug shape: merged form `outer_fwd(dt/2) DDI(dt/2) outer_bwd(dt/2)` integrated DDI at dt/2 per step; (b) the why: two adjacent V(dt/2) blocks (end of step n + start of step n+1) sit between K-steps, each integrating DDI for dt/2, totaling dt; merging collapsed them; (c) fix: removed the merge optimisation; every step now uses two `_ddi_step!(ws, dt/2, …)` calls; (d) regression: `test/test_itp_ddi_strang_save_every.jl` (note: memory cites pre-refactor path; current path is `test/solvers/test_itp_ddi_strang_save_every.jl` per glob this turn — researcher confirms the current path).

2. **Memory `tier3_pipeline_survey_2026_05_18.md` §2.2** — survey-side acknowledgment that bug-4 audit revalidation is Tier 1→2 candidate. Quote: "All Eu DDI runs predating 2026-05-02 should be re-verified. Internal self-consistency check, no external benchmark needed for Tier 2. Cheapest path: 2 turns + 1 optional Julia run."

3. **CLAUDE.md `## Bug-4: ITP merged-loop DDI half-rate (FIXED 2026-05-02)`** section — top-level claim documented in the project's canonical config. Also: `## Bug-5: Faraday image n_total double-count (FIXED 2026-05-02)` for context (sibling 2026-05-02 fix campaign).

4. **`src/solvers/ground_state/itp_loop.jl`** — current production code; researcher reads to confirm the merge optimisation is removed and every step uses the close + reopen pattern. Director glob this turn confirms file path; researcher reads contents.

5. **`test/solvers/test_itp_ddi_strang_save_every.jl`** — regression test; director read this turn confirms: (a) F=1, n_steps=800, dt=0.005, c_dd=2000.0 active; (b) builds two workspaces with save_every=1 and save_every=100; (c) phase-aligns ψ_b to ψ_a, asserts max|ψ_a − ψ_b_aligned| < 1e-10; (d) DDI off control asserts energy diff < 1e-9.

6. **`src/solvers/simulation.jl`** — RTP analogue per memory ("RTP analogue (substep accuracy, not rate bug) fixed in same shape — see commit `0353b9b`"); researcher reads to confirm fix is present in the RTP path and inspect commit `0353b9b` via `git log` for the diff scope.

7. **Lahaye-Menotti-Santos-Lewenstein-Pfau 2009 "The physics of dipolar bosonic quantum gases" Rep. Prog. Phys. 72 126401 [arXiv:0905.0386]** — canonical dipolar BEC review. §III ("Theoretical description") covers Gross-Pitaevskii + operator-splitting numerical methods; researcher confirms the Strang dt/2 per step DDI integration cadence convention is consistent with this review's prescriptions (or notes if SpinorBEC.jl uses a non-standard variant).

8. **Lima-Pelster 2011 arXiv:1103.4128** — scalar/quasi-2D LHY benchmark (CLAUDE.md cited). §II or appendix may discuss numerical operator-splitting for DDI; researcher checks for any DDI-rate-accuracy commentary.

9. **Chomaz et al. 2022 "Dipolar physics: a review of experiments with magnetic quantum gases" Rep. Prog. Phys. 86 026401 [arXiv:2202.05525]** — recent dipolar BEC review; researcher checks Appendix or numerical-methods section for any post-2022 update on operator-splitting cadence for DDI.

10. **arXiv:2604.12198 grounded autonomous research** — agent self-corrects, writes the inversion in worklog. Bug-4 fix at 2026-05-02 IS this pattern at the codebase level: a bug was found, fix landed, regression test pinned. T95 Research stage independently audits the persistence of that loop self-correction.

11. **arXiv:2506.14852 APC** — Research stage uses cached verify-claim::Research skeleton (n_seen ≥ 6 from T14 / T64 / T69 / T71 / T87 / T91). Patch in bug-4-specific deltas (specific file paths, specific external refs, specific falsifier shape).

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verify existing physics; PRIMARY axis)**. Bug-4 audit revalidation is the canonical D1 verification-depth promotion candidate (Tier 1 internal regression → Tier 2 closed-form / cross-implementation verified, via regression-test audit + RTP analogue cross-check + external Strang-DDI numerics reference). Project Tier-2 count post-T98 Document (anticipated): would bump from 5 to 6.
- **Tier ladder position**: Research stage start. tier_current 1.0 → upon T95 Research PASS, theorist proceeds to Hypothesize (T96), Design (T97), Execute (T97 optional julia regression test rerun), Analyze (T97), Update (T98 critic), Document (T98 implementer_text). Tier 2.0 closure ~T98.
- **Manuscript NOT in scope** (per `feedback_manuscript_is_not_the_essence`). Bug-4 audit is a code/numerics verification investigation; no manuscript section touch at any stage. Document stage will be memory entry + (potentially) a docstring `@warn` or advisory in `itp_loop.jl` if researcher / theorist find a subtle remaining concern.
- **Project D1 verification depth narrative**: Closes one of the project's flagged outstanding institutional debts. The `feedback_use_existing_artifacts_first` memory specifically calls out under-using runs/ artifacts; T95 closes the dual question for src/ — under-auditing structural-correctness of fixed bugs.
- **Cost frame**: target ~1.3M effective; HARD CAP 2.0M. researcher_shallow Research canonical workload. T95 will not run julia; the Execute stage at T97 is where julia is OPTIONAL (regression-test rerun) per the original survey description "2 turns + 1 optional Julia run."

- **Drift trajectory after T95 (anticipated)**:
  - cost_inflation: drop to ~0.7-0.9 (researcher_shallow target 1.3M vs ~1.6M running average → ratio ~0.8).
  - code_delta_zero: 1.0 (researcher reads files; doesn't modify any).
  - manuscript_delta_zero: 1.0 (correct by design).
  - novel_claim_zero: 0.0 (Research stage produces NEW claims about fix-correctness + new external ref citations).
  - subagent_repetition: 1/5 researcher_shallow (rotation good; 4-turn gap since T91).
  - verdict_drift: T95 should land RESEARCHER_ONLY (judge enum) cleanly — Research stage canonical outcome; no operational gotchas anticipated.

- **Recommended T96+ trajectory (post-T95 Research)**:
  1. **T96 (theorist Hypothesize)**: formalize 4-5 falsifiers (F1-F5 above) with machine-evaluable criteria. Cost ~1.8M.
  2. **T97 (theorist or implementer_text Design + implementer_julia_cpu_light Execute regression-test rerun OPTIONAL)**: design the falsifier-test mapping, optionally run `test/solvers/test_itp_ddi_strang_save_every.jl` via julia_cpu_light. Cost ~1.5M if no julia; +0.5M if julia.
  3. **T98 (critic Update + implementer_text Document)**: standard close path. Cost ~2.5M combined.
  4. Total bug-4 arc: ~6.5M effective across 4 turns. Comparable to klaus-bch (5.7M T55-T59) and sign-pattern (7.2M T91-T94).

- **Branch-point T95 failure modes**:
  - **RESEARCHER_ONLY** (expected; ~92% probability): canonical Research-stage verdict; deliverable is the literature scan + memory/code audit + falsifier candidate list ready for T96 theorist Hypothesize.
  - **FAIL_OPERATIONAL** (~5% probability): file-read precondition violation (e.g., `src/solvers/ground_state/itp_loop.jl` has been refactored and moved; current glob this turn confirms it exists but T95 should still verify before reading). → T96 director_must_address re-research with corrected paths.
  - **INCONCLUSIVE** (~3% probability): researcher finds a structural concern (e.g., the fix has been reverted, OR the regression test is not wired into CI, OR a NEW subtle bug surfaces during the audit). → T96 theorist Hypothesize with revised hypothesis tree.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "bug-4-itp-ddi-half-rate-revalidation-2026-05-18",
  "stage_advancing_to": "Research",
  "subagent_type": "researcher",
  "researcher_depth": "shallow",
  "parallel_researcher_count": 1,
  "expected_cost": 1300000,
  "rationale": "T94 closed sign-pattern-lemma1 Tier-3 cleanly. Survey menu (tier3_pipeline_survey_2026_05_18.md §2.2) lists bug-4-itp-ddi-half-rate-revalidation as the cheapest Tier 1→2 promotion candidate. MEMORY.md explicitly flags 'All Eu DDI runs predating 2026-05-02 should be re-verified' as outstanding institutional debt. The natural target run runs/eu151_mz_scan/ is no longer on disk (glob this turn confirms absent), so the revalidation path pivots from artifact-comparison to fix-audit + regression-test-audit + RTP-analogue cross-check + external-Strang-DDI-numerics reference. §F1 Research stage canonical workload = researcher_shallow. Target tier 2; researcher_depth = shallow per §F1 depth rule (not 3, no prior contradictions, no unit-system ambiguity). Per §A5 D1 axis: verifies production-code correctness on a documented bug-class with potential physics impact on all pre-2026-05-02 Eu DDI ITP runs. Per §A6: ≥1 external reference required and 5+ candidates pre-cited in director §4 (Lahaye 2009 / Lima-Pelster 2011 / Chomaz 2022 + 2024-2026 dipolar numerics papers). APC cache verify-claim::Research n_seen ≥ 6 (T14/T64/T69/T71/T87/T91) → use cached skeleton, patch bug-4-specific deltas.",
  "brief": "## ROLE\n\nYou are researcher_shallow. T95 §F1 Research stage of newly-spawned investigation `bug-4-itp-ddi-half-rate-revalidation-2026-05-18` — Tier 1→2 promotion via fix audit + regression-test audit + RTP-analogue cross-check + external Strang-DDI numerics reference. Your job: gather the citation chain that T96 theorist Hypothesize needs, confirm the 2026-05-02 fix is structurally locked in, and propose the falsifier candidate list.\n\nNO julia execution (researcher_shallow scope). NO src/ modification. NO state.json edit. NO WebFetch on a paywall; PDF where openly available; abstract via WebFetch where PDF gated.\n\nDIRECTIVE_LABEL: bug-4-itp-ddi-revalidation-T95-research-shallow\n\n## REQUIRED READING (in this order)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_95.md` ENTIRE (this report) — §4 cites your starting reference set with rationale.\n2. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/bug_4_itp_ddi_half_rate.md` — primary internal anchor (16-day-old caveat; verify against current code).\n3. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tier3_pipeline_survey_2026_05_18.md` §2.2 (candidate #2 description).\n4. `/home/suzume/workspace/BEC-simulation/CLAUDE.md` section `## Bug-4: ITP merged-loop DDI half-rate (FIXED 2026-05-02)` if present (also `## Bug-5: Faraday image n_total double-count (FIXED 2026-05-02)` for context).\n5. `/home/suzume/workspace/BEC-simulation/src/solvers/ground_state/itp_loop.jl` ENTIRE — current production code; verify (a) NO `if step % save_every == 0` branching; (b) every step uses two `_ddi_step!(ws, dt/2, …)` calls; (c) close + reopen pattern matches memory description.\n6. `/home/suzume/workspace/BEC-simulation/test/solvers/test_itp_ddi_strang_save_every.jl` ENTIRE — regression test; verify (a) F=1, n_steps=800, dt=0.005, c_dd=2000.0; (b) max|ψ(save_every=1) − ψ(save_every=100)| < 1e-10 assertion present; (c) DDI off control assertion present; (d) test name + @testset structure intact.\n7. `/home/suzume/workspace/BEC-simulation/src/solvers/simulation.jl` ENTIRE — RTP analogue; verify the substep-accuracy fix is present (per memory: commit `0353b9b`).\n8. `git log --oneline --grep='DDI'` or `git log --oneline --grep='Bug-4'` or `git log --oneline 0353b9b` — confirm the commit chain (post-2026-05-02 fix landed).\n9. `git log --oneline --grep='itp_ddi'` — find the actual ITP merged-loop fix commit.\n\n## DELIVERABLES\n\nWrite report to `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_95.md`. Sections:\n\n### §1. Internal audit — fix structurally locked in?\n\n- §1.1 itp_loop.jl audit: line-numbered confirmation that NO branching on `step % save_every == 0` exists in the ITP main loop body, and that every step uses two `_ddi_step!(ws, dt/2, …)` calls (or document any deviation from memory's description).\n- §1.2 test_itp_ddi_strang_save_every.jl audit: assertion structure (max|ψ_a − ψ_b_aligned| < 1e-10 for DDI on; energy diff < 1e-9 for DDI off control); test exists and is uncommented.\n- §1.3 simulation.jl RTP analogue audit: confirm fix is present + cite commit `0353b9b` from git log.\n- §1.4 Git commit chain: list commits between 2026-04-30 and 2026-05-05 mentioning DDI / Bug-4 / itp_ddi / merged-loop. Confirm the ITP fix landed.\n\n### §2. CI tier coverage\n\nWhich `SPINORBEC_TEST_TIER` value (`fast` / `ci` / `full` / `physics`) runs the regression test? Per CLAUDE.md Commands section: 'fast (units only), ci (+ ITP/RTP integration), full (default), physics (analytic validation only).' Document whether `test/solvers/test_itp_ddi_strang_save_every.jl` is included in tier `ci`+ (i.e., is it part of the integration suite or only `full`?). If it's `full`-only the regression is NOT in CI by default, which is an institutional gap worth flagging.\n\n### §3. External reference scan (≥3 sources cited; reach ≥5 if you can find them)\n\nUse WebFetch / WebSearch (NOT PDF fetch — abstract + figure/table-extract only) for:\n- Lahaye et al. 2009 Rep. Prog. Phys. 72 126401 [arXiv:0905.0386] — §III operator-splitting numerical methods for DDI BEC.\n- Lima-Pelster 2011 arXiv:1103.4128 — scalar LHY benchmark; check Appendix for operator-splitting commentary.\n- Chomaz et al. 2022 Rep. Prog. Phys. 86 026401 [arXiv:2202.05525] — recent dipolar review.\n- Wachtler-Santos 2016 arXiv:1605.08676 — F=6 LHY context; check for numerical-method notes.\n- Any 2024-2026 spinor-DDI numerics paper (search 'Strang splitting dipolar BEC ground state' + 'imaginary time propagation DDI Strang' + 'spinor BEC DDI ITP convergence').\n\nFor EACH cited reference: 1-2 line summary + reproducible URL/DOI + relevance to Bug-4 (does it discuss DDI Strang dt/2 vs dt cadence accuracy? does it report a similar gotcha?).\n\n### §4. Falsifier candidate list (proposes T96 theorist's Hypothesize falsifiers)\n\n≥4 falsifier candidates with descriptive name + 1-line operational test. Suggested seeds from director §1.F preview list — refine, expand, OR refute these:\n- F1: itp_loop.jl structural — no merge branch, exactly two DDI(dt/2) calls per step.\n- F2: regression test exists + asserts the canonical max_dev < 1e-10 boundary.\n- F3: RTP analogue (simulation.jl) fixed in commit 0353b9b; diff inspected.\n- F4: ≥1 external Strang-DDI-numerics ref confirms the dt/2 per V-block convention is standard / not standard.\n- F5 (OPTIONAL for T97 implementer_julia_cpu_light): regression test runs and passes (no junk output, max_dev ~1e-13 actual).\n\n### §5. Tier 1 → Tier 2 promotion argument\n\nGiven §1-§4, articulate the explicit promotion claim: 'Tier 2 = closed-form / sympy / cross-implementation verified per §D. Bug-4 fix is closed-form-correctness verified via [code audit + regression-test audit + cross-implementation (RTP analogue) confirmation + external-reference convention check].' This sets up T96 theorist Hypothesize to formalize the claim.\n\n### §6. Caveats / open gaps for T96+\n\n- Is the regression test's c_dd=2000.0 + F=1 representative enough? F=6 Eu would be more relevant but heavier; argue whether F=1 + c_dd=2000 captures the structural bug class.\n- Is `runs/eu151_mz_scan/` actually GONE or just moved? glob result this turn = no match — confirm.\n- Are there OTHER pre-2026-05-02 Eu DDI runs in `runs/` that anko might want re-verified individually? Inventory them (e.g., `runs/eu151_edh*`, `runs/eu151_klaus_phi_phys/`, `runs/eu151_edh_twa/`, `runs/eu151_phase_diagram_lbfgs/`).\n\n### §7. METRICS JSON (single fenced ```json``` block per §METRICS schema below)\n\n## METRICS JSON SCHEMA\n\n```json\n{\n  \"experiment_kind\": \"researcher_shallow\",\n  \"investigation_kind\": \"physics\",\n  \"investigation_id\": \"bug-4-itp-ddi-half-rate-revalidation-2026-05-18\",\n  \"stage_advancing_to\": \"Research\",\n  \"flow_template\": \"verify-claim\",\n  \"researcher_depth\": \"shallow\",\n  \"src_files_read\": <int; expect 3: itp_loop.jl, test_itp_ddi_strang_save_every.jl, simulation.jl>,\n  \"src_files_modified\": 0,\n  \"webfetch_used\": <true|false>,\n  \"websearch_used\": <true|false>,\n  \"n_external_refs_cited\": <int; expect >= 3>,\n  \"n_internal_refs_cited\": <int; memory + CLAUDE.md count>,\n  \"itp_loop_fix_confirmed_structurally\": <true|false; F1>,\n  \"regression_test_exists_with_canonical_assertions\": <true|false; F2>,\n  \"rtp_analogue_fix_confirmed_in_simulation_jl\": <true|false; F3>,\n  \"commit_0353b9b_found_in_git_log\": <true|false>,\n  \"ci_tier_inclusion_documented\": <true|false; §2 deliverable>,\n  \"n_falsifier_candidates_proposed\": <int; expect >= 4>,\n  \"runs_eu151_mz_scan_disk_status\": <\"present\"|\"absent\"|\"moved\">,\n  \"pre_2026_05_02_eu_ddi_runs_inventoried\": <int; expect >= 3>,\n  \"tier_promotion_argument_articulated\": <true|false; §5>,\n  \"verdict\": \"RESEARCH_DONE_FOR_HYPOTHESIZE\",\n  \"state_json_modified\": false,\n  \"manuscript_main_edited\": false\n}\n```\n\n## ANTI-PATTERN GUARDS\n\n- Do NOT modify any file (researcher_shallow = Read + Grep + Glob + WebFetch + WebSearch + Write to runs/_loop/research/turn_95.md ONLY).\n- Do NOT execute julia (researcher_shallow is text-only; julia regression-test execution is T97 Execute stage if any, by implementer_julia_cpu_light).\n- Do NOT WebFetch on a known paywall (Rep. Prog. Phys. is OA-accessible at arXiv preprint stage; use arXiv URLs).\n- Do NOT chase >5 external references (researcher_shallow caps at ~15 queries per director §F1; deep-dive references should be deferred to T96 theorist if a specific point needs deeper anchoring).\n- Do NOT touch state.json, .claude/agents/*, .claude/scripts/*, patterns.yaml, manuscript src — none of these are researcher scope at this stage.\n- Do NOT exceed 2.0M effective tokens HARD CAP. Target 1.3M.\n- Do NOT improvise terminology (per feedback_no_improvised_terminology): use established numerical-method terms (Strang splitting, operator splitting, leapfrog, symplectic integrator, imaginary-time propagation, real-time propagation) only.\n- English only. No emojis. No anko-attribution.\n",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "investigation_kind",
      "investigation_id",
      "stage_advancing_to",
      "flow_template",
      "researcher_depth",
      "src_files_read",
      "src_files_modified",
      "webfetch_used",
      "websearch_used",
      "n_external_refs_cited",
      "n_internal_refs_cited",
      "itp_loop_fix_confirmed_structurally",
      "regression_test_exists_with_canonical_assertions",
      "rtp_analogue_fix_confirmed_in_simulation_jl",
      "n_falsifier_candidates_proposed",
      "runs_eu151_mz_scan_disk_status",
      "tier_promotion_argument_articulated",
      "verdict",
      "state_json_modified",
      "manuscript_main_edited"
    ],
    "optional": [
      "commit_0353b9b_found_in_git_log",
      "ci_tier_inclusion_documented",
      "pre_2026_05_02_eu_ddi_runs_inventoried"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/src/solvers/ground_state/itp_loop.jl && test -f /home/suzume/workspace/BEC-simulation/test/solvers/test_itp_ddi_strang_save_every.jl && test -f /home/suzume/workspace/BEC-simulation/src/solvers/simulation.jl && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/bug_4_itp_ddi_half_rate.md && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tier3_pipeline_survey_2026_05_18.md && echo PRECONDITIONS_OK"
  },
  "success_criteria": [
    {
      "id": "experiment_kind_correct",
      "metric": "experiment_kind",
      "operator": "==",
      "value": "researcher_shallow",
      "rationale": "Research stage canonical workload."
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
      "value": "Research",
      "rationale": "First stage of §F1 verify-claim."
    },
    {
      "id": "investigation_id_correct",
      "metric": "investigation_id",
      "operator": "==",
      "value": "bug-4-itp-ddi-half-rate-revalidation-2026-05-18",
      "rationale": "New spawn this turn."
    },
    {
      "id": "depth_shallow",
      "metric": "researcher_depth",
      "operator": "==",
      "value": "shallow",
      "rationale": "tier_target=2, no contradictions, no unit/hyperfine ambiguity; shallow is canonical per §F1."
    },
    {
      "id": "src_files_read_at_least_3",
      "metric": "src_files_read",
      "operator": ">=",
      "value": 3,
      "rationale": "Must read itp_loop.jl + test_itp_ddi_strang_save_every.jl + simulation.jl at minimum."
    },
    {
      "id": "src_unchanged",
      "metric": "src_files_modified",
      "operator": "==",
      "value": 0,
      "rationale": "Researcher Read-only; no modification scope."
    },
    {
      "id": "external_refs_cited_at_least_3",
      "metric": "n_external_refs_cited",
      "operator": ">=",
      "value": 3,
      "rationale": "§A6 mandates ≥1 external; researcher_shallow expectation is ≥3 to set up T96 theorist with adequate citation chain."
    },
    {
      "id": "internal_refs_cited_at_least_2",
      "metric": "n_internal_refs_cited",
      "operator": ">=",
      "value": 2,
      "rationale": "memory + CLAUDE.md at minimum."
    },
    {
      "id": "itp_loop_fix_structurally_confirmed",
      "metric": "itp_loop_fix_confirmed_structurally",
      "operator": "==",
      "value": true,
      "rationale": "F1 candidate falsifier; load-bearing for Tier 2 promotion."
    },
    {
      "id": "regression_test_exists_correct_assertions",
      "metric": "regression_test_exists_with_canonical_assertions",
      "operator": "==",
      "value": true,
      "rationale": "F2 candidate falsifier; load-bearing for Tier 2 promotion."
    },
    {
      "id": "rtp_analogue_fix_confirmed",
      "metric": "rtp_analogue_fix_confirmed_in_simulation_jl",
      "operator": "==",
      "value": true,
      "rationale": "F3 candidate falsifier; cross-implementation verification per §D Tier 2 definition."
    },
    {
      "id": "falsifier_candidates_proposed_at_least_4",
      "metric": "n_falsifier_candidates_proposed",
      "operator": ">=",
      "value": 4,
      "rationale": "T96 theorist Hypothesize needs ≥4 candidates to choose from; richer set means better falsifier-test mapping."
    },
    {
      "id": "tier_promotion_argument_present",
      "metric": "tier_promotion_argument_articulated",
      "operator": "==",
      "value": true,
      "rationale": "§5 deliverable; sets up the Tier 1 → Tier 2 promotion claim for T96 Hypothesize formalization."
    },
    {
      "id": "no_manuscript_polish",
      "metric": "manuscript_main_edited",
      "operator": "==",
      "value": false,
      "rationale": "§A5 manuscript polish OUT."
    },
    {
      "id": "state_json_untouched_by_researcher",
      "metric": "state_json_modified",
      "operator": "==",
      "value": false,
      "rationale": "Orchestrator manages state.json post-judge."
    },
    {
      "id": "verdict_research_done",
      "metric": "verdict",
      "operator": "==",
      "value": "RESEARCH_DONE_FOR_HYPOTHESIZE",
      "rationale": "Canonical Research-stage handoff verdict."
    }
  ],
  "failure_modes": [
    {
      "if": "itp_loop_fix_confirmed_structurally == false OR regression_test_exists_with_canonical_assertions == false",
      "category": "scientific_partial_REFUTED",
      "next_action": "T96 director pivots from `Hypothesize` to `Hypothesize-with-bug-resurfaced`: if Bug-4 has regressed (fix not present in current code), spawn a fix-bug investigation IMMEDIATELY at higher priority and call this a NOVEL finding. If regression test is missing/commented-out, propose re-adding it as T96 implementer_text Design output and re-tier the investigation."
    },
    {
      "if": "rtp_analogue_fix_confirmed_in_simulation_jl == false",
      "category": "scientific_partial_data_gap",
      "next_action": "T96 narrows scope to ITP-only Tier 2 promotion; RTP analogue becomes a separate sub-investigation. Memory entry confirms which is verified."
    },
    {
      "if": "n_external_refs_cited < 3",
      "category": "operational_under-cited",
      "next_action": "T96 director re-dispatches researcher_shallow with refined search-term list, OR (cheaper) accepts shallow-cite count and advances Hypothesize with whatever was found, flagging the gap in T96 §A6 rationale."
    },
    {
      "if": "src_files_read < 3",
      "category": "operational_under-read",
      "next_action": "T96 researcher re-dispatch with explicit file-by-file checklist; verify file paths still resolve."
    },
    {
      "if": "n_falsifier_candidates_proposed < 4",
      "category": "operational_under-proposed",
      "next_action": "T96 theorist Hypothesize works with the candidates available + adds 1-2 of their own. Acceptable degradation; not a re-dispatch trigger."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 2000000
  },
  "budget": {
    "expected_cost_eff": 1300000,
    "expected_wall_time_sec": 1200,
    "split_by_subtask": {
      "internal_file_read_and_grep": 400000,
      "external_websearch_websfetch": 500000,
      "synthesis_and_report_write": 400000
    }
  },
  "investigation_update": {
    "spawn_new_investigation": {
      "id": "bug-4-itp-ddi-half-rate-revalidation-2026-05-18",
      "title": "Bug-4 ITP merged-loop DDI half-rate revalidation (Tier 1 → 2; institutional debt item per MEMORY.md)",
      "hypothesis": "The 2026-05-02 fix to _run_itp_loop! (removed merge optimisation; every step uses two _ddi_step!(ws, dt/2, …) calls totaling dt per step) is structurally locked in to current src/solvers/ground_state/itp_loop.jl and is mirrored in src/solvers/simulation.jl RTP analogue (commit 0353b9b); the regression test test/solvers/test_itp_ddi_strang_save_every.jl exercises the canonical max|psi(save_every=1) - psi(save_every=100)| < 1e-10 assertion under DDI-on and includes a DDI-off control.",
      "flow_template": "verify-claim",
      "current_stage": "Research",
      "tier_current": 1.0,
      "tier_target": 2,
      "priority": 4,
      "kind": "physics",
      "next_stage": "Hypothesize",
      "next_stage_action": "T96 theorist Hypothesize formalizes 4-5 falsifiers based on T95 researcher_shallow proposed candidate list; design machine-evaluable criteria for each."
    },
    "if_success_advance_to_stage": "Hypothesize",
    "if_success_tier_becomes": 1.0,
    "if_refuted_advance_to_stage": "Hypothesize-with-bug-resurfaced",
    "if_refuted_tier_becomes": 0.5,
    "next_falsifier_to_test_after": "F1-itp-loop-structural-no-merge-branch"
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read state.json + scheduler_95.json + seed.md this turn
- [x] Read ≥1 memory file related to active investigation (bug_4_itp_ddi_half_rate.md + tier3_pipeline_survey_2026_05_18.md)
- [x] Read prior director turn for continuity (turn_94.md)
- [x] Read prior sim/turn_94.md + judge/turn_94.json for T94 closure confirmation
- [x] investigation_id NEW SPAWN this turn with explicit `spawn_new_investigation` block in `investigation_update`
- [x] stage_advancing_to = Research is the first stage of §F1 verify-claim template
- [x] subagent_type = researcher matches §F1 role_per_stage[Research]
- [x] researcher_depth = shallow per §F1 depth rule (tier_target=2, no contradictions, no unit-system ambiguity)
- [x] success_criteria are machine-evaluable (judge.py can apply ==, >=, ==boolean predicates against METRICS JSON fields)
- [x] failure_modes cover scientific_partial (F1/F2 fail → bug resurfaced spawn), scientific_partial (F3 fail → narrow scope), operational (under-cited / under-read), and operational (under-proposed degradation-OK)
- [x] observable_manifest precondition_check is concrete (test -f shell commands on 5 required files)
- [x] budget fits within scheduler window_seconds_left (1.3M target << 2.0M cap << window ~13 days)
- [x] §A6 research-first citation present (Lahaye 2009, Lima-Pelster 2011, Chomaz 2022, KU2012-by-reference, Wachtler-Santos 2016, plus memory + CLAUDE.md internal)
- [x] §A5 D1/D2/D3 articulated; D1 (verify existing physics) is PRIMARY axis; manuscript NOT primary
- [x] APC contract template cache: cited verify-claim::Research n_seen ≥ 6; used cached skeleton scaffold
- [x] anko's seed.md julia-forbidden caveat acknowledged + correctly superseded by current scheduler_95.json (probe-driven, foreign_julia=0, JULIA_GPU_OK)
- [x] No improvised terminology; no anko-attribution in agent prompts
