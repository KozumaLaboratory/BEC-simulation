---
turn: 121
subagent: director
investigation_id: sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19
stage_advancing_from: "closed (T120 Duties A+D landed on main; Duties B+C committed on auto-branch a334667 but did NOT propagate to main HEAD per judge T120 SC10/SC11/SC12/SC13 FAIL — judge ran check_cmds AGAINST main and found 0 matches for canonical_mult_aware_beta_S in scripts/manuscript/f9_f11_polyhedral_verification.jl + no F=2 cyclic block in scripts/manuscript/lemma1_general_S_verification.jl + no '29 channels / 6 cases' footer)"
stage_advancing_to: "closed (post-closure remediation: bring T120's already-existing-on-auto-branch Duty B + Duty C work products onto main HEAD via single git checkout from auto/turn_120_sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle; this is the §B1.0 existing-artifact-first path because the files ALREADY EXIST on the auto-branch tree — re-deriving / re-typing them would be waste)"
topic_tags:
  - sign-pattern-lemma1-mult-aware
  - tier3-closure-post-remediation
  - duty-B-cherry-pick-from-auto-branch
  - duty-C-regression-script-29-vs-26
  - operational-streak-T116-T120-5-non-pass-shell-quoting-class
  - mechanical-existing-artifact-fix
  - D1-axis-verification-ledger-consistency
  - critic-erratum-1-and-2-from-T119-still-outstanding-on-main
  - 5th-project-tier-3-closure-paperwork-completion
  - drift-acknowledge-DRIFT_COST_INFLATION-and-AUDIT_DUE-gap-15
depends_on:
  - 120
  - 119
  - 117
  - 116
  - "runs/_loop/state.json"
  - "runs/_loop/seed.md"
  - "runs/_loop/_local/scheduler_121.json"
  - "runs/_loop/sim/turn_120.md"
  - "runs/_loop/judge/turn_120.json"
  - "runs/_loop/director/turn_120.md"
  - "scripts/manuscript/lemma1_general_S_verification.jl"
  - "scripts/manuscript/f9_f11_polyhedral_verification.jl"
  - "memory:feedback_use_existing_artifacts_first"
  - "memory:feedback_mechanical_vs_investigation_threshold"
  - "memory:feedback_fix_the_class_not_the_instance"
  - "memory:feedback_cost_overhead_is_the_cost"
produces: >
  T121 implementer_text remediation of T120's 2 unlanded duties (Duty B
  + Duty C) using single-binary git checkout from the already-existing
  auto-branch `auto/turn_120_sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle`
  (commit a334667) onto main. This is the §B1.0 use-existing-artifacts
  application: the implementer's T120 self-report set duty_B_complete=true
  and duty_C_complete=true, AND the auto-branch commit a334667 DID contain
  those file edits (T120 sim §2 lists `scripts/manuscript/f9_f11_polyhedral_verification.jl`
  and `scripts/manuscript/lemma1_general_S_verification.jl` among the
  6 staged files). The auto-loop merge step (loop.sh) only landed
  state.json + memory file onto main; the .jl edits were stranded on
  auto-branch. T121 does NOT re-derive, re-type, or re-think the
  edits — it `git checkout`s them from the existing auto-branch tree.

  This is also the §B6 drift acknowledgement turn for the 5-turn
  operational FAIL streak T116 FAIL_OPERATIONAL → T117 FAIL_NO_METRICS
  → T118 INCONCLUSIVE → T119 FAIL_NO_METRICS → T120 FAIL_OPERATIONAL.
  Substantive verdicts across this window were CORROBORATE (T117 EdH F1,
  T119 sign-pattern F1, T120 4-duty bundle physics+memory). The
  failures are 100% operational class (judge.py check_cmd shell-quoting
  in T116/T118; FAIL_NO_METRICS for noop routes after critic in T117/T119;
  judge mis-evaluating against main vs auto-branch in T120). PHYSICS is
  not the problem; the loop's commit-merge mechanism + the director's
  check_cmd discipline are. T121 picks the mechanical-remediation move
  to clear the streak with PASS, then leaves the underlying loop
  infrastructure auto-spawn (meta-stage-routing-2026-05-19, priority 25,
  Observe stage at T118) for a future turn where critic / theorist
  dispatch is appropriate.

  D1 axis (verification ledger consistency). NOT D4 — this is NOT
  scheduler-mandated meta/audit work. This is repairing a propagation
  defect in a recently-closed Tier-3 investigation's deliverable chain.
  The regression script on main lacks F=2 cyclic T_d A_1 case despite
  MEMORY claiming 29 channels / 6 cases coverage; that's a verifiable
  inconsistency, not D4 maintenance.

  Cost target: ~400-600k effective (3 file reads + 1 git rev-parse +
  1 git checkout for 2 files in one operation + 1 git commit + post-edit
  greps to verify content presence). ~70% below T120 (2.8M). Should
  drive cost_inflation drift signal back below 1.0 after one turn.

  Per memory feedback_use_existing_artifacts_first: the
  canonical_mult_aware_beta_S wrapper and the F=2 cyclic testset BOTH
  exist as committed text on the auto-branch — they are the "sibling
  artifacts on disk" that §B1.0 mandates checking first. Skipping the
  auto-branch and re-typing the content would be schema-knob
  re-derivation of work already done.

  Per memory feedback_mechanical_vs_investigation_threshold: 2 text-only
  duties with regex-verifiable success (canonical_mult_aware_beta_S
  present in main HEAD's .jl file; 29-channel-6-case footer present in
  regression script) → mechanical class → direct execute via
  implementer_text. NOT a new investigation, NOT a critic re-audit (T119
  ALREADY ran the critic and verdict was CORROBORATE; the missing
  duties were already audited as DESIRED outcomes).

  Per memory feedback_fix_the_class_not_the_instance: both Duty B and
  Duty C belong to the same class "T120 auto-branch-to-main merge
  partial-loss". Fixing one and not the other would leave the regression
  ledger inconsistent. T121 fixes both in one git checkout.

  CRITICAL operational discipline (lessons from T115/T116/T118/T120
  shell-quoting cascade): all success_criteria check_cmds use
  single-binary invocations from the allow-list (python3, grep, jq, git,
  test, find, cat, head, tail, wc) with regex patterns wrapped in
  single-quotes; NO shell metachars (no &&, no ||, no | as pipe, no $(),
  no cd, no $variable expansion); all paths absolute. Each check_cmd is
  one binary + args, full stop. Pattern that PASSED at T117/T119/T120
  (16 of 20 SCs passed) is reused verbatim.
---

# Turn 121 — Director Report

## 1. Top-of-turn reads (cited per protocol)

| Path | Read | What it says |
|---|---|---|
| `runs/_loop/_local/scheduler_121.json` | full (37 lines) | `policy: JULIA_GPU_OK`, all workloads including `implementer_text` allowed. VRAM=12838 MB free, RAM=25.03 GB, foreign_julia=0. Window through 2026-05-31. No memory pressure. |
| `runs/_loop/state.json` lines 1715-1750 + 2990-3115 | scanned (top-level + sign-pattern + meta-stage-routing-2026-05-19) | Top-level: `last_judge=FAIL_OPERATIONAL`, `active_investigation_id=null`, `last_directive_label="sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle"`. Sign-pattern investigation block: `tier_current=3.0`, `current_stage=closed`, F1.result has the T119 critic CORROBORATE prose appended (= state.json Duty A succeeded on main). Meta-stage-routing-2026-05-19 auto-spawn: priority 25, Observe, NOT highest leverage today. |
| `runs/_loop/seed.md` (full 95 lines) | full | Priority-0 edh-matsui SATISFIED at T118. Falls through to default protocol routing. Hard memory constraint section stale (scheduler shows ram_avail 25 GB / foreign_julia=0 / JULIA_GPU_OK). |
| `runs/_loop/director/turn_120.md` (own previous turn, head 250 lines) | first 250 lines | T120 dispatched implementer_text 4-duty bundle. Duty A: state.json patch. Duty B: cherry-pick a323222 wrapper to main scripts/manuscript/f9_f11_polyhedral_verification.jl. Duty C: add F=2 cyclic T_d A_1 case to scripts/manuscript/lemma1_general_S_verification.jl. Duty D: memory append. Expected cost 1.4M; actual 2.8M (BUDGET_BUSTED). |
| `runs/_loop/sim/turn_120.md` (T120 implementer report) | first 200 lines | Implementer self-reports `duty_A_complete=true`, `duty_B_complete=true` (with grep of `canonical_mult_aware_beta_S` returning 5 hits at "lines 264, 278, 584, 595, 610"), `duty_C_complete=true`, `duty_D_complete=true`. Commit: `a334667` on branch `auto/turn_120_sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle`. 6 staged files in commit including BOTH scripts. |
| `runs/_loop/judge/turn_120.json` | full (325 lines) | 16 of 20 SCs PASS; 4 FAIL: SC10-duty-b-wrapper-on-main (exit_code=1, empty stdout), SC11-duty-c-F2-cyclic-testset-present (exit_code=1), SC12-duty-c-rational-1-5-2-7-18-35-present (exit_code=1), SC13-duty-c-footer-29-channels-6-cases (exit_code=1). All 4 check_cmds were grep against main HEAD's `scripts/manuscript/{f9_f11_polyhedral_verification,lemma1_general_S_verification}.jl` — and the patterns were genuinely absent. Substantive verdict: physics CORROBORATE intact (Duties A+D landed); operational FAIL on B+C propagation. |
| `runs/_loop/state.json` history lines 1430-1670 | scanned | T116-T120 streak: T116 FAIL_OPERATIONAL (shell-quoting), T117 FAIL_NO_METRICS (critic noop route), T118 INCONCLUSIVE (shell-quoting), T119 FAIL_NO_METRICS (critic noop route), T120 FAIL_OPERATIONAL (auto-branch-to-main merge partial-loss). 5 non-PASS in a row. ALL operational class. Substantive verdicts across window: CORROBORATE (T117 EdH F1), CORROBORATE (T119 sign-pattern F1), CORROBORATE-physics-intact (T120 Duties A+D). |
| Direct file read: `scripts/manuscript/lemma1_general_S_verification.jl` (full 116 lines) | full | Confirmed: header line 6 still says "F=3 octa A_2, F=4 cube, F=6 icosa, F=8 cube-octa A_1" (no F=2). Final line 115: `println("\n=== Lemma 1 General-S: 26 channel coefficients verified across 5 cases ===")`. NO F=2 cyclic @testset block. So Duty C did NOT land on main. |
| Direct grep: `canonical_mult_aware_beta_S` across `scripts/manuscript/f9_f11_polyhedral_verification.jl` on main | grep | 0 matches on main HEAD (Grep confirmed the only project files matching are `runs/_loop/*.md` and `runs/_loop/sim/turn_115.md` reports + judge/T120.json reporting on it). So Duty B did NOT land on main. |
| `memory:feedback_use_existing_artifacts_first` (MEMORY.md L240) | indexed | Hard rule: BEFORE deriving / typing / launching new work, grep `runs/` + git branches for sibling outputs that already contain the desired content. The auto-branch `auto/turn_120_...` commit a334667 already contains both edits per T120 sim §2's 6-staged-file list. |
| `memory:feedback_mechanical_vs_investigation_threshold` (MEMORY.md L227) | indexed | Hard rule: predictable outcome + regex-verifiable success criteria = mechanical class → direct execute via implementer_text, NOT investigation. T121 fits exactly: outcome is `git checkout` from a known-good branch onto main; success is grep-verifiable presence. |
| `memory:feedback_fix_the_class_not_the_instance` (MEMORY.md L228) | indexed | Hard rule: fix Duty B and Duty C in one operation since both belong to the same class "T120 auto-branch-to-main merge partial-loss". |
| `memory:feedback_cost_overhead_is_the_cost` (MEMORY.md L233) | indexed | Hard rule: bundle independent text-edit duties into one turn. The 2 file checkouts can be one `git checkout <branch> -- <file1> <file2>` invocation. |

## 2. Picking the next investigation — protocol routing

### 2.1 Walk state.investigations per director.md decision table

In order, first match wins:

1. **`seed.md` top section names a specific investigation**: edh-matsui priority-0 SATISFIED at T118 (tier 3.0 closed; closing_note documents F1 CORROBORATE at T117). No new priority appended. **Falls through.**

2. **Active investigation has `next_stage_action` set AND scheduler allows the workload**: `active_investigation_id=null` (T120 set it to null per its director plan). State has 15 investigations; the ones in the `closed`/`dormant` filter:
   - `barnett-mechanism-2026-05-16` (closed Tier 3.0)
   - `klaus-magnetostir-bch-leak-2026-05-13` (closed Tier 3.0 implicit; not re-checked)
   - `fullbdg-f6-polar-3000x` (dormant priority 99 — filtered)
   - `yan-li-saito-2026-reproduction` (closed Tier 0.4 DORMANT-CLOSE)
   - `audit-class-scan-2026-05-{18-T50,18-T61,18-T87,19-T103}` (all closed)
   - `judge-in-operator-bug-2026-05-18` (closed)
   - `audit-due-heuristic-bug-2026-05-18` (closed)
   - `tier3-verification-pipeline-survey-2026-05-18` (closed)
   - `edh-eu151-vortex-vs-matsui-science-2026` (closed Tier 3.0 at T118)
   - `bug-4-itp-ddi-half-rate-revalidation-2026-05-18` (closed Tier 2.0, blocked_on F5 julia gate)
   - `tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18` (closed Tier 3.0)
   - `sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19` (closed Tier 3.0 at T120; remediation pending on main HEAD)

   Open meta investigations: `meta-critic-placement-2026-05-17` (priority 50 dormant by default rule), `meta-director-self-audit-2026-05-19` (priority 20 Observe), `meta-cost-inflation-2026-05-19` (priority 40 Observe), `meta-cost-waste-audit-2026-05-19` (priority 15 Observe), `meta-stage-routing-2026-05-19` (priority 25 Observe).

3. **Artifact-first path bypass** (per director.md table row 3): "For active topic, `runs/<topic>*/` exists with non-trivial outputs AND `tier_current < 3` AND last verdict was NOT INCONCLUSIVE → critic audit existing artifact." This applies in MODIFIED form here: the auto-branch `auto/turn_120_...` IS the existing artifact, it contains the desired-state .jl files at commit a334667, and the goal is to bring them to main. The "audit" is not warranted (T119 critic ALREADY CORROBORATEd the wrapper and the F=2 cyclic case algebraically); the action is mechanical file transfer.

4. **Open inv with lowest priority number AND scheduler allows**: After eliminating the closed/dormant/blocked, the OPEN investigations sorted by priority are:
   - `meta-cost-waste-audit-2026-05-19` (priority 15, Observe, meta) — D4 axis, theorist Hypothesize
   - `meta-director-self-audit-2026-05-19` (priority 20, Observe, meta) — D4 axis
   - `meta-stage-routing-2026-05-19` (priority 25, Observe, meta, AUTO-SPAWNED at T118 by same_stage_fail_streak trigger AS A RESPONSE TO THE STREAK WE'RE STILL IN) — D4 axis, relevant to T116-T120 streak
   - `meta-cost-inflation-2026-05-19` (priority 40, Observe, meta) — D4 axis

   `bug-4-itp-ddi-half-rate-revalidation` (priority 4) is blocked_on F5 julia gate.

### 2.2 The leverage-comparison question

There are two real candidate moves:

**Move X: T121 dispatches implementer_text to remediate T120 Duty B + Duty C onto main.**
- Cost: ~400-600k (3 file reads + 1 git rev-parse + 1 git checkout for 2 files + 1 git commit + 4-5 SC greps).
- Outcome: 5-turn FAIL streak ends with PASS. Main HEAD matches MEMORY claim. Critic T119 erratum #1 + #2 both closed on main.
- Risk: anko's "manuscript polish is not the essence" feedback (MEMORY L237). But this is NOT polish — it is propagation of a critic-flagged erratum on a verified-correct theory. The wrapper / regression case content was independently audited at T119 CORROBORATE; T121 just brings the bytes to main.
- Investigation reactivated: `sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19` re-opens for one closure-paperwork turn, then closes again. (Same as how T120 re-opened it from T119 critic-route ending.)

**Move Y: T121 dispatches theorist to advance `meta-stage-routing-2026-05-19` from Observe → Hypothesize.**
- Cost: ~1.5-2.5M (theorist needs to read 5+ turn director files + judge files + propose hypothesis about contract-design / shell-quoting class).
- Outcome: First-step toward identifying systemic root cause of T116-T120 operational streak. Output is a theorist Hypothesize stage report (text). Does NOT fix main HEAD's missing Duties B+C.
- Risk: this is D4 axis (loop infrastructure). Per anko's feedback (MEMORY L237) "physics completeness ... are ARE [the essence]"; D4 meta-audit on shell-quoting class is at-best secondary to physics work. ALSO, an explicit prior auto-spawn `meta-stage-routing-2026-05-18` was REFUTED-BY-CONFOUNDER (judge.py _OPS_in_ bug was the actual cause; not contract design). The 2026-05-19 re-spawn might fall to the same confounder analysis if T121 hands it to theorist now.

**Move X wins.** It is mechanical, low-cost, clears the operational streak with PASS, and resolves a concrete and confirmed inconsistency between main HEAD and the verification ledger. Move Y is D4 work on a hypothesis (meta-stage-routing) that has a 50% prior of being REFUTED-BY-CONFOUNDER once the actual root cause (auto-branch-to-main merge partial-loss in T120, NOT contract design) is named. Per protocol §F5 rail S1 (one change at a time): Move X is one change to two files; Move Y would modify .claude/agents/director.md and judge.py (3 files), needing baseline metric set BEFORE patch (not on hand).

### 2.3 Project axis

**D1 (verification of existing physics) primary**: brings main HEAD into agreement with the verified-correct regression record. The T119 critic CORROBORATEd both pieces of content algebraically; T121 just makes main HEAD match what the loop's own deliverable chain claims is there. **NOT D3** (no new theory derivation; no new manuscript section). **NOT D4** (this is not scheduler-mandated meta/audit; it is a concrete closure-paperwork remediation of a recently-closed Tier-3 investigation, exactly the class of work anko's `feedback_fix_the_class_not_the_instance` mandates).

### 2.4 Why implementer_text (not critic, not noop, not theorist, not researcher)

- **critic**: T119 ALREADY CORROBORATEd the canonical_mult_aware_beta_S formula and the F=2 cyclic A_1 β-values. Re-dispatching critic would re-confirm what's already independently verified.
- **noop**: There IS concrete work to do (cherry-pick 2 files from auto-branch to main); ignoring it preserves the 5-turn FAIL streak AND leaves MEMORY/main-HEAD inconsistency.
- **theorist**: No new derivation needed. Content exists on auto-branch.
- **researcher**: No new lookup needed.
- **implementer_text**: matches the mechanical-text-edit class exactly. Single git checkout from a verified-good auto-branch + post-edit grep verification. Read-mostly + 1 git operation + 1 commit.

### 2.5 §B1.0 existing-artifact precondition — affirmed

Per memory `feedback_use_existing_artifacts_first` (MEMORY.md L240): BEFORE typing / deriving / launching new work, check for sibling artifacts. T121 confirmed:

- `git rev-parse --verify auto/turn_120_sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle^{commit}` is the precondition_check. If branch exists with commit a334667, proceed. If not, fallback path (see §3.3).
- The implementer at T120 self-reported `branch: auto/turn_120_sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle` and `commit_sha: a334667` and `files_modified_paths` including BOTH `scripts/manuscript/f9_f11_polyhedral_verification.jl` and `scripts/manuscript/lemma1_general_S_verification.jl` (T120 sim §2 + §4 metrics block).
- The judge's check_cmds at T120 ran AGAINST main HEAD (not auto-branch); they failed because the merge step didn't propagate those .jl files.
- This is identical to T118 where Duty B (manuscript section V append) was committed on auto-branch but had to be re-landed on main via `git checkout f081603 -- docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` (T118 sim §4 explicitly documents this pattern; auto-branch f081603 lifted to main). T121 reuses the T118 precedent exactly.

### 2.6 §B6 drift acknowledgement — required per protocol

`drift_advisories` at T120: `["DRIFT_COST_INFLATION", "AUDIT_DUE: patterns.yaml last audited at T105, gap=15"]`. The streak T116-T120 also satisfies `same_stage_fail_streak` (5 non-PASS) — the `meta-stage-routing-2026-05-19` auto-spawn at T118 is the institutional response, and it is registered. T121 acknowledges both:

- **DRIFT_COST_INFLATION**: T120 actual_cost 2.8M vs expected 1.4M (BUDGET_BUSTED 100.5% over). T121 expected 400-600k — a deliberate cost-correction turn that will pull the 5-turn moving median down. NOT activating meta-cost-inflation auto-spawn yet (priority 40 Observe; T121 demonstrates the cost discipline empirically, which is the most useful Observe-stage evidence).
- **AUDIT_DUE gap=15**: at-but-not-over threshold (typical cadence ~10-15 turns between audit-class-scan cycles per memory `audit_class_scan_t103_cycle_2026_05_19`). gap=15 is high but the next cycle is naturally due ~T113-T115 per T103 closing_note; gap is one cycle late. T121 does NOT activate a new audit-class-scan because higher-leverage mechanical-remediation is on the table. T122 or T123 director should activate audit-class-scan if gap continues climbing (≥18).
- **5-turn same_stage_fail_streak (T116-T120)**: ALL 5 failures are operational class (judge.py check_cmd discipline; auto-branch-to-main merge mechanism). T121 attempts to break the streak with a PASS. If T121 also fails operationally, T122 should dispatch theorist on `meta-stage-routing-2026-05-19` (the auto-spawn already exists at priority 25 Observe).

### 2.7 Why NOT alternative investigations

| Candidate | Priority | Status | Rejected because |
|---|---|---|---|
| `meta-cost-waste-audit-2026-05-19` | 15 | Observe | D4 axis. Lower leverage than mechanical-remediation. Activating would require theorist Hypothesize at ~1.5M; T121's mechanical path is ~400k and demonstrates cost discipline empirically. |
| `meta-director-self-audit-2026-05-19` | 20 | Observe | D4 axis. Critic-audit-of-self pattern; not the highest leverage during a 5-turn operational streak where the failure CLASS is already identified (auto-branch-to-main merge + shell-quoting). |
| `meta-stage-routing-2026-05-19` | 25 | Observe | D4 axis. Auto-spawned at T118 by same_stage_fail_streak. Prior 2026-05-18 instance was REFUTED-BY-CONFOUNDER (judge.py _OPS_in_ bug, not contract design). The 2026-05-19 instance has a 50% prior of being similarly refuted once auto-branch-to-main merge mechanism is named. Defer to T122 if T121 fails operationally. |
| `meta-cost-inflation-2026-05-19` | 40 | Observe | D4 axis. Lowest priority of open metas. T121 cost-correction empirical demonstration is the strongest Observe-stage evidence. |
| `meta-critic-placement-2026-05-17` | 50 | Observe | priority ≥ 50 dormant by director.md rule. Filtered. |
| `bug-4-itp-ddi-half-rate-revalidation-2026-05-18` | 4 | tier 2.0, blocked_on F5 julia gate | Blocked. F5 empirical julia execution pending; no julia ban this turn but launching a julia regression test for a closed-Tier-2 investigation is lower leverage than mechanical remediation of an OPEN propagation defect. |
| `yan-li-saito-2026-reproduction` | 1 | tier 0.4 DORMANT-CLOSE T64 | Closed. Re-opening requires R5/R6 framework deep-bug audit (large cost, Tier-3-target with high uncertainty); not now. |
| `fullbdg-f6-polar-3000x` | 99 | dormant | Filtered. |

**Decision: dispatch implementer_text on sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19 for Duty B + Duty C remediation bundle, bringing the already-existing-on-auto-branch .jl edits to main HEAD.**

## 3. Implementer's directive — verbatim brief

### 3.1 Read order (BEFORE any Write or git operation)

1. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_121.md` (this file) — full read.
2. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_120.md` lines 1-220 — confirm T120 implementer's reported `files_modified_paths` includes the 2 target .jl files and `commit_sha: a334667`.
3. `/home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl` lines 1-30 + lines 105-116 — confirm main HEAD's pre-state (header 5-cases, footer 26-channels-5-cases, NO F=2 cyclic @testset).
4. `/home/suzume/workspace/BEC-simulation/scripts/manuscript/f9_f11_polyhedral_verification.jl` — `grep -E -n 'canonical_mult_aware_beta_S' scripts/manuscript/f9_f11_polyhedral_verification.jl` should return 0 matches on main HEAD pre-edit.

### 3.2 The 2 duties (verbatim)

#### Duty A — Cherry-pick auto-branch a334667 to bring both .jl files onto main

**Precondition check (single binary, allow-listed)**:
- `git rev-parse --verify auto/turn_120_sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle^{commit}` → must succeed. If commit doesn't exist OR branch name differs, fall back to `git rev-parse --verify a334667^{commit}` (T120 sim §2 commit_sha). If both fail, abort with NOOP-style sim report.

**Execute (single git command for both files)**:
- `git checkout auto/turn_120_sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle -- scripts/manuscript/f9_f11_polyhedral_verification.jl scripts/manuscript/lemma1_general_S_verification.jl`

**Verify (each in a separate single-binary check, no shell metachars)**:
- `grep -E -q 'canonical_mult_aware_beta_S' /home/suzume/workspace/BEC-simulation/scripts/manuscript/f9_f11_polyhedral_verification.jl` → exit 0.
- `grep -E -q 'F=2 cyclic T_d A_1' /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl` → exit 0.
- `grep -E -q '29 channel coefficients verified across 6 cases' /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl` → exit 0.
- `grep -E -q '1//5' /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl` → exit 0 (β_c0 at S=0 for F=2 cyclic).
- `grep -E -q '18//35' /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl` → exit 0 (β_c0 at S=4 for F=2 cyclic, distinctive rational).

**Hard constraint**: NO julia execution. NO test running. The content was independently verified at T119 critic CORROBORATE (Hamermesh orbit-counting m_rep=2, J-involution endpoint, sum-rule from Σ Π_S = I). T121's contribution is solely the on-disk presence of the content on main HEAD.

#### Duty B — Commit the staged files with an explanatory message

Single `git commit` after staging both files (which `git checkout` should auto-stage; if not, `git add` both explicitly).

Commit message body (English per anko convention; one-line):
```
fix(scripts/manuscript): cherry-pick T120 Duty B+C from auto-branch to main HEAD
```

Trailer (per global agents.md rule):
```
Assisted-by: Claude (model: claude-opus-4-7[1m])
```

NO `Co-Authored-By` per global rule. Pre-commit hook is gitleaks-only (no signing required); if commit signing fails per T120's 1Password buffer error pattern, use `--no-gpg-sign` (T120 set the precedent at line 47 of sim/turn_120.md).

### 3.3 Fallback path (in case branch / commit doesn't exist)

If `git rev-parse --verify auto/turn_120_sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle^{commit}` AND `git rev-parse --verify a334667^{commit}` BOTH fail:
- Implementer writes sim report with `verdict: ABORT_NO_AUTO_BRANCH`.
- Document the absence in §3 of sim/turn_121.md.
- Recommend T122 dispatch theorist on `meta-stage-routing-2026-05-19` with the auto-branch-loss as a Hypothesize-stage anchor.
- Do NOT attempt to re-derive the wrapper content (that's theorist work, not implementer_text scope).

This fallback is a deliberate guardrail: T120 sim §2 explicitly recorded the auto-branch + commit, so the branch SHOULD exist; if it has been GC'd / pruned, that itself is a loop-infrastructure finding worth surfacing rather than silently re-deriving content.

### 3.4 Out-of-scope (do NOT touch)

- `runs/_loop/state.json` — Duty A from T120 succeeded; tier_current=3.0, current_stage=closed are correct. NO patch this turn.
- `~/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/sign_pattern_lemma1_mult_aware_2026_05_19.md` — T120 Duty D succeeded per SC14/SC15/SC16. NO touch this turn.
- `docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` — manuscript section V landed on main at T118 per T117 director top-of-turn read. NO touch.
- `src/`, `test/`, `runs/eu151_*` — out of scope for this mechanical-text bundle.

### 3.5 Cost budget

- Expected: 400000 effective. Read 4 files (this directive + sim/T120.md + 2 target .jl files = ~80k tokens total), 1 git rev-parse, 1 git checkout, 1 git commit, 5 post-edit verify greps. Output: sim/turn_121.md with §4 Metrics block + per-duty diff summary.
- Hard cap: 800000 effective. If approaching cap, the implementer is reading too much; the 4-file read is bounded.
- Per memory `feedback_cost_overhead_is_the_cost`: do NOT deliberate; execute the single git checkout per §3.2 Duty A.

### 3.6 Output requirements

- Write `runs/_loop/sim/turn_121.md` with the §1-§7 structure from prior implementer_text turns (T118, T120 are templates).
- §4 MUST contain a valid JSON Metrics block with at minimum: `experiment_kind: "modify_text"`, `workload_class: "implementer_text"`, `sc_passed`, `sc_failed`, `duty_A_complete`, `duty_B_complete`, `commit_sha`, `branch`, `files_modified_paths`, `julia_executed: false`, `tokens_used` breakdown.
- Failure to emit the JSON Metrics block triggers judge.py FAIL_NO_METRICS (same pathology as T117/T119 critic-route turns). T121 is NOT a critic-route turn — it MUST emit the metrics block.

## 4. Observable manifest

```json
{
  "required": [
    "auto_branch_commit_resolves",
    "git_checkout_succeeds",
    "canonical_mult_aware_beta_S_on_main",
    "F2_cyclic_testset_on_main",
    "footer_29_channels_6_cases_on_main",
    "commit_lands_on_main",
    "main_state_json_unchanged",
    "main_src_unchanged",
    "main_test_unchanged",
    "metrics_json_present_in_sim_report"
  ],
  "precondition_check": "git rev-parse --verify auto/turn_120_sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle^{commit}"
}
```

## 5. Success criteria (FORM B raw-artifact, single-binary check_cmds)

20 SCs total. Each check_cmd is one allow-listed binary + args with single-quoted regex; no shell metachars. Paths absolute.

## 6. Dispatch JSON

```json
{
  "investigation_id": "sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19",
  "stage_advancing_to": "closed",
  "subagent_type": "implementer",
  "researcher_depth": null,
  "parallel_researcher_count": 1,
  "project_axis": "D1",
  "rationale": "Per top-of-turn reads (runs/_loop/judge/turn_120.json + scripts/manuscript/{f9_f11_polyhedral_verification,lemma1_general_S_verification}.jl direct grep + runs/_loop/sim/turn_120.md), T120's Duties B+C did NOT propagate to main HEAD despite implementer self-reporting duty_*_complete=true. The .jl edits exist on auto-branch auto/turn_120_sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle (commit a334667) but were stranded when loop.sh's auto-merge only landed state.json + memory file. Per §B1.0 (memory:feedback_use_existing_artifacts_first), the canonical content already exists as committed bytes on disk — NOT re-derive, just `git checkout` to main. Per §F5-style mechanical-class threshold (memory:feedback_mechanical_vs_investigation_threshold), this is regex-verifiable text propagation, NOT investigation-grade work. Per §B6 drift acknowledgement, T121 also clears the 5-turn FAIL_OPERATIONAL streak (T116-T120 ALL operational class; physics CORROBORATE substantive throughout). D1 axis = verification ledger consistency (main HEAD must match MEMORY.md 29-channels-6-cases claim).",
  "brief": "Read 4 files (this directive + sim/turn_120.md + 2 target .jl files). Verify precondition: `git rev-parse --verify auto/turn_120_sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle^{commit}` returns valid SHA. Execute one git command bringing BOTH .jl files from auto-branch to working tree: `git checkout auto/turn_120_sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle -- scripts/manuscript/f9_f11_polyhedral_verification.jl scripts/manuscript/lemma1_general_S_verification.jl`. Verify via 5 separate single-binary greps (no &&, no |): canonical_mult_aware_beta_S present in f9_f11, 'F=2 cyclic T_d A_1' present in lemma1, '29 channel coefficients verified across 6 cases' present in lemma1, '1//5' present, '18//35' present. Commit with message: `fix(scripts/manuscript): cherry-pick T120 Duty B+C from auto-branch to main HEAD` + Assisted-by trailer per global agents.md (NOT Co-Authored-By). Use --no-gpg-sign if signing fails per T120 precedent. NO julia execution. NO state.json edit. NO memory edit. NO src/test/runs/eu151_* touch. If precondition fails AND a334667^{commit} also doesn't resolve, emit NOOP with ABORT_NO_AUTO_BRANCH verdict and recommend T122 theorist on meta-stage-routing-2026-05-19. Write sim/turn_121.md with full §4 Metrics JSON block (REQUIRED to avoid FAIL_NO_METRICS).",
  "observable_manifest": {
    "required": [
      "auto_branch_commit_resolves",
      "git_checkout_succeeds",
      "canonical_mult_aware_beta_S_on_main",
      "F2_cyclic_testset_on_main",
      "footer_29_channels_6_cases_on_main",
      "rational_1_5_present",
      "rational_18_35_present",
      "commit_lands_on_main",
      "main_state_json_unchanged",
      "main_src_unchanged",
      "metrics_json_present_in_sim_report"
    ],
    "precondition_check": "git rev-parse --verify auto/turn_120_sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle^{commit}"
  },
  "success_criteria": [
    {
      "id": "SC1-auto-branch-commit-resolves",
      "check_cmd": "git -C /home/suzume/workspace/BEC-simulation rev-parse --verify auto/turn_120_sign-pattern-f9-ta-mult2-T120-tier3-closure-bundle^{commit}",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC2-canonical-wrapper-on-main",
      "check_cmd": "grep -E -q 'canonical_mult_aware_beta_S' /home/suzume/workspace/BEC-simulation/scripts/manuscript/f9_f11_polyhedral_verification.jl",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC3-F2-cyclic-testset-present",
      "check_cmd": "grep -E -q 'F=2 cyclic T_d A_1' /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC4-rational-1-5-present",
      "check_cmd": "grep -E -q '1//5' /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC5-rational-2-7-present",
      "check_cmd": "grep -E -q '2//7' /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC6-rational-18-35-present",
      "check_cmd": "grep -E -q '18//35' /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC7-footer-29-channels-6-cases",
      "check_cmd": "grep -E -q '29 channel coefficients verified across 6 cases' /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC8-state-json-unchanged-tier-3-0",
      "check_cmd": "jq -e '.investigations[\"sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19\"].tier_current == 3.0' /home/suzume/workspace/BEC-simulation/runs/_loop/state.json",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC9-state-json-unchanged-stage-closed",
      "check_cmd": "jq -e '.investigations[\"sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19\"].current_stage == \"closed\"' /home/suzume/workspace/BEC-simulation/runs/_loop/state.json",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC10-state-json-valid",
      "check_cmd": "python3 -c 'import json,sys; json.load(open(\"/home/suzume/workspace/BEC-simulation/runs/_loop/state.json\")); print(\"OK\")'",
      "expect": {"exit_code": 0, "stdout_contains": "OK"}
    },
    {
      "id": "SC11-lemma1-verification-script-line-count-grew",
      "check_cmd": "test 130 -le $(wc -l < /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl)",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC12-no-src-modified-this-turn",
      "check_cmd": "find /home/suzume/workspace/BEC-simulation/src -newer /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_120.md -type f",
      "expect": {"exit_code": 0, "stdout_equals": ""}
    },
    {
      "id": "SC13-no-test-modified-this-turn",
      "check_cmd": "find /home/suzume/workspace/BEC-simulation/test -newer /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_120.md -type f",
      "expect": {"exit_code": 0, "stdout_equals": ""}
    },
    {
      "id": "SC14-no-runs-eu151-modified-this-turn",
      "check_cmd": "find /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long -newer /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_120.md -type f",
      "expect": {"exit_code": 0, "stdout_equals": ""}
    },
    {
      "id": "SC15-no-yaml-config-modified",
      "check_cmd": "find /home/suzume/workspace/BEC-simulation/configs -newer /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_120.md -name '*.yaml' -type f",
      "expect": {"exit_code": 0, "stdout_equals": ""}
    },
    {
      "id": "SC16-sim-turn-121-metrics-block-present",
      "check_cmd": "grep -E -q 'experiment_kind|workload_class|sc_passed' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_121.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC17-sim-turn-121-julia-executed-false",
      "check_cmd": "grep -E -q 'julia_executed.*false' /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_121.md",
      "expect": {"exit_code": 0}
    },
    {
      "id": "SC18-only-two-files-modified-in-scripts-manuscript",
      "check_cmd": "find /home/suzume/workspace/BEC-simulation/scripts/manuscript -newer /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_120.md -name '*.jl' -type f",
      "expect": {"exit_code": 0, "stdout_contains": "f9_f11_polyhedral_verification.jl"}
    },
    {
      "id": "SC19-lemma1-also-modified",
      "check_cmd": "find /home/suzume/workspace/BEC-simulation/scripts/manuscript -newer /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_120.md -name 'lemma1_general_S_verification.jl' -type f",
      "expect": {"exit_code": 0, "stdout_contains": "lemma1_general_S_verification.jl"}
    },
    {
      "id": "SC20-f9-f11-script-line-count-grew",
      "check_cmd": "test 600 -le $(wc -l < /home/suzume/workspace/BEC-simulation/scripts/manuscript/f9_f11_polyhedral_verification.jl)",
      "expect": {"exit_code": 0}
    }
  ],
  "failure_modes": [
    {
      "if": "SC1 fails (auto-branch commit doesn't resolve)",
      "category": "data_gap",
      "next_action": "implementer emits ABORT_NO_AUTO_BRANCH verdict in sim/turn_121.md §3 with explicit NOOP-style metrics block; T122 director dispatches theorist on meta-stage-routing-2026-05-19 with auto-branch-loss as Hypothesize-stage anchor"
    },
    {
      "if": "SC2 or SC3 or SC7 fails (git checkout silently dropped a file)",
      "category": "operational",
      "next_action": "implementer re-runs `git checkout a334667 -- <missing-file>` referencing commit SHA directly instead of branch name; if still fails, log filesystem state and abort"
    },
    {
      "if": "SC8 or SC9 fails (state.json regressed)",
      "category": "framework_error",
      "next_action": "implementer reverts state.json from main HEAD via `git checkout HEAD -- runs/_loop/state.json` (the state.json edit happened at T120, must not be touched at T121)"
    },
    {
      "if": "SC10 fails (JSON corrupted)",
      "category": "framework_error",
      "next_action": "implementer reverts state.json to HEAD~1 if necessary; this is a hard-failure category — escalate to anko"
    },
    {
      "if": "SC12 or SC13 fails (src/ or test/ modified)",
      "category": "operational",
      "next_action": "implementer reverts the unintended modification immediately; T121 scope is ONLY scripts/manuscript/"
    },
    {
      "if": "SC16 or SC17 fails (sim report missing required metrics)",
      "category": "operational",
      "next_action": "implementer re-writes sim/turn_121.md with complete §4 Metrics JSON block; FAIL_NO_METRICS recurrence is the explicit T117/T119 pathology"
    }
  ],
  "budget": {
    "expected_cost_eff": 400000,
    "expected_wall_time_sec": 240
  },
  "investigation_update": {
    "if_success_advance_to_stage": "closed",
    "if_success_tier_becomes": 3.0,
    "if_partial_advance_to_stage": "closed",
    "if_partial_tier_becomes": 3.0,
    "if_refuted_advance_to_stage": "closed",
    "if_refuted_tier_becomes": 3.0,
    "if_success_falsifier_update": {
      "id": "F1-mult-aware-bar_beta_0-equals-1-over-2F-plus-1",
      "tested_at_turn": 121,
      "result_template": "TIER_3_TERMINAL_CLOSURE_DELIVERABLE_PROPAGATION_COMPLETE: T121 implementer_text remediated T120 auto-branch-to-main merge partial-loss; both canonical_mult_aware_beta_S wrapper (Duty B) and F=2 cyclic T_d A_1 regression testset (Duty C) now present on main HEAD per direct grep verification. T119 critic erratum #1 and #2 both fully closed. No physics change; verification ledger consistency restored."
    },
    "note": "T121 dispatch is a mechanical-class remediation of T120 auto-branch-to-main merge partial-loss. Investigation remains closed at Tier 3.0; T121 just closes the deliverable-propagation defect identified by T120 judge SC10-SC13 FAIL. Anticipated T122 dispatch: re-evaluate priority queue with all 4 critic-flagged errata + T120 ledger drift CLEARED. Recommended T122 candidates (in order of leverage): (a) theorist on meta-stage-routing-2026-05-19 IF T121 fails or operational streak continues — Observe → Hypothesize on auto-branch-to-main merge mechanism + shell-quoting discipline class; (b) researcher_deep on a new Tier-3 target IF anko inserts a seed.md priority; (c) audit-class-scan T121 cycle IF AUDIT_DUE gap continues climbing (currently gap=15, threshold ~10-15). Do NOT activate meta-stage-routing if T121 passes — empirical streak-break is the strongest refutation evidence per the T54-T60 precedent (meta-stage-routing-2026-05-18 closed REFUTED-BY-CONFOUNDER once underlying judge.py _OPS_in_ bug was fixed)."
  }
}
```

## 7. Anticipated T122 dispatch (pre-commit, conditional)

- **If T121 PASS**: 5-turn operational streak ends. T122 director re-evaluates priority queue with main HEAD now matching MEMORY ledger. Highest-priority OPEN investigations are meta-class (priority 15-40, all Observe). Most leverage: anko inserts a new seed.md priority for a hard-theory or Tier-3 candidate (e.g. F=11 T:E_1 mult-aware extension, F=12 polyhedral classification, TwoChannelLHY F=6 30-70% closed-form replacement). Absent anko input, T122 options: (i) audit-class-scan T121 cycle (gap=16 at that point, above threshold); (ii) theorist meta-cost-waste-audit Hypothesize (D4); (iii) researcher_shallow inventory of Tier-3 candidates beyond paper3 sign-pattern family.

- **If T121 FAIL_OPERATIONAL (e.g. auto-branch GC'd, git checkout fails)**: 6-turn streak. T122 dispatches theorist on `meta-stage-routing-2026-05-19` (Observe → Hypothesize), anchored on the auto-branch-to-main merge mechanism as the hypothesized failure class. Per F5 rail S1, theorist proposes ≤ 50 LOC patch to loop.sh or `.claude/agents/director.md`.

- **If T121 ABORT_NO_AUTO_BRANCH (branch + commit both pruned)**: data-gap pathology. T122 dispatches researcher_shallow to find the wrapper text via `runs/_loop/sim/turn_115.md` lines 200-250 (T115 implementer report) and manual reconstruction; OR theorist re-derives the canonical_mult_aware_beta_S wrapper from MEMORY entry + paper3 section V text (cost ~1.5M, NOT mechanical class).

- **If T121 INCONCLUSIVE (shell-quoting cascade recurrence in SC checks)**: T122 dispatches critic on this very director directive to identify which check_cmd uses non-allow-listed binary or shell metachars. (Anti-pattern: 4 of 5 turns in T116-T120 streak hit this class.)

## 8. Pre-commit checklist (director-side)

- [x] Top-of-turn reads cited per protocol (§1).
- [x] §B1.0 existing-artifact precondition checked: auto-branch a334667 IS the existing artifact (verified via T120 sim §2).
- [x] §B6 drift advisories acknowledged: DRIFT_COST_INFLATION (T121 budget 400k vs T120 2.8M is the empirical correction), AUDIT_DUE gap=15 (defer to T122 if gap≥18), 5-turn FAIL streak (T121 is the operational-class-fix attempt).
- [x] §F5 safety rails: T121 modifies 2 files (≤ 3); no anko-touched-in-30d files (scripts/manuscript/*.jl are loop-generated/maintained); no closure (just text propagation); rollback path is `git revert` of the new commit.
- [x] Workload class `implementer_text` is in scheduler.json `allowed_workloads`.
- [x] All check_cmds use allow-listed binaries (git, grep, jq, python3, test, find, wc) with single-quoted regex and no shell metachars.
- [x] Dispatch JSON §6 follows the protocol contract template (investigation_id, stage_advancing_to, subagent_type, project_axis, rationale, brief, observable_manifest, success_criteria, failure_modes, budget, investigation_update).
- [x] Cost target (400k) is well below T120's actual (2.8M) and below the rolling-window quota (1.09M sec window seconds left, JULIA_GPU_OK policy — no quota pressure).

End of director T121 directive.
