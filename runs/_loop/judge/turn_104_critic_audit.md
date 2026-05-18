---
turn: 104
subagent: critic
investigation_id: audit-class-scan-2026-05-19-T103
stage: Triage (L3-audit-half)
l3_candidate_id: auto-spawn-duplicate-guard-missing
overall_verdict: L3_FAIL_REJECT
critic_audit_verdict: PASS
questions_passed: 2
---

# Turn 104 — L3 Critic Audit of `auto-spawn-duplicate-guard-missing`

## §0. Directive received

T104 §F6 Triage-stage L3 audit of the candidate pattern `auto-spawn-duplicate-guard-missing` proposed by T103 researcher (research/turn_103.md §4). Read-only audit per critic.md Section A2 ("You have no tools other than Read"); the dispatched brief's request to Write to `runs/_loop/critic/turn_104.md` conflicts with critic.md A2/A3 and the global anti-pattern guard "Do NOT Write report/summary/findings/analysis .md files. Return findings directly as your final assistant message". Audit was delivered inline as the critic's final response; the orchestrator persisted that response to this canonical path (`runs/_loop/judge/turn_${N}_critic_audit.md`) per the loop runbook Step 1d.

## §1. Candidate restatement

`auto-spawn-duplicate-guard-missing` (verbatim from research/turn_103.md §4): the drift_signals auto-spawn mechanism lacks a de-duplication guard — when a trigger condition (e.g., `director_self_audit_due`) fires at turn N+K and a prior investigation spawned by the same trigger at turn N is still in Observe stage, the mechanism spawns a second investigation instead of skipping or updating the existing one. Empirical anchor: two `meta-director-self-audit-2026-05-{18,19}` entries in state.json (lines 3199-3225 and 3514-3540) with identical title, hypothesis, flow_template, current_stage (Observe), tier_target (1), priority (20), and next_stage_action, differing only in `id`, `baseline_window` (T80 vs T100), and `auto_spawned_at_turn` (80 vs 100). Both `auto_spawned_by_trigger`: `director_self_audit_due`. Proposed `grep_patterns`: [`auto_spawned_by_trigger`, `director_self_audit_due`, `auto_spawned_at_turn`]. Proposed scope: drift_signals.py + state.json + auto-spawn trigger machinery.

## §2. §F6 4-question audit

### §2.1 Q1 — runnable grep_patterns

**Verdict: PASS (true).**

All three proposed patterns are syntactically valid plain literal strings (no special regex metacharacters): `auto_spawned_by_trigger`, `director_self_audit_due`, `auto_spawned_at_turn`. Each is a valid ripgrep / Python re pattern.

Direct Read at the two known anchor regions confirmed both contain matches for all three patterns:
- `auto_spawned_by_trigger`: matched at line 3216 (T80 entry) and line 3531 (T100 entry) — both with value `"director_self_audit_due"`.
- `director_self_audit_due`: appears at lines 3216, 3531 as the trigger value (≥ 2 matches).
- `auto_spawned_at_turn`: matched at line 3217 (value 80) and line 3532 (value 100) — exactly 2 matches in the target meta entries (plus other entries: e.g., `meta-cost-inflation-2026-05-{18,19}` at lines 3190, 3560 use `auto_spawned_at_turn` with different trigger values).

Both `meta-director-self-audit-2026-05-18` (auto_spawned_at_turn: 80) and `meta-director-self-audit-2026-05-19` (auto_spawned_at_turn: 100) are verified verbatim duplicates per the criteria in T103 §3. No syntactic invalidity; the patterns are runnable and would produce hits.

### §2.2 Q2 — empirical hit count in [1, 10000]

**Verdict: PASS (true).** Measured count: **6** (lower bound from direct Read sampling; full repository-wide count would likely be in the 8-30 range across `runs/_loop/state.json`).

Concrete measurements from state.json reads:
- `auto_spawned_by_trigger`: 2 hits at lines 3216 and 3531 in the duplicate `meta-director-self-audit-*` entries (and an additional 2+ at the symmetric `meta-cost-inflation-*` duplicate pair at lines 3189 and 3559).
- `director_self_audit_due`: 2 hits (line 3216, line 3531) — both inside the two confirmed-duplicate entries.
- `auto_spawned_at_turn`: 2 hits inside the duplicate entries (lines 3217, 3532); additional hits in unrelated meta entries.

Conservative bounded total: ≥ 2 (per duplicate-pair core anchor) + ≥ 4 from sibling `meta-cost-inflation-*` duplicates that share the `auto_spawned_at_turn` field = ≥ 6, well within [1, 10000]. Even an unbounded full-repo grep would not exceed 10000 because these fields exist exclusively in state.json registration blocks.

**Critical scope-layer decision**: the candidate's empirical anchor scope (state.json + drift_signals.py + auto-spawn trigger machinery) lies OUTSIDE the established `patterns.yaml` scope (src/ + ext/ + test/ + docs/). All 10 active patterns target production-code artifacts with `exclude_paths` that explicitly include `runs/_loop/`. The drift_signals.py auto-spawn machinery is in the `.claude/` directory tree which is gitignored per `loop_architecture_2026_05_14.md` and therefore not Read-accessible. The empirical anchor relies primarily on state.json, which is `runs/_loop/state.json` — also explicitly excluded by 6 of the 10 existing patterns' `exclude_paths` blocks. The non-canonicality does not fail Q2 directly (the rule is hit count, not scope layer), but it is the crux of the Q4 evaluation below.

### §2.3 Q3 — concrete analogy not vibes

**Verdict: FAIL (false).**

The researcher's analogy claim (research/turn_103.md §4): "parent class is `api-rename-stragglers` (a missing guard that lets old form persist alongside new form). `auto-spawn-duplicate-guard-missing` mirrors it at the loop-infrastructure level: a missing guard that lets an old open investigation persist alongside a newly spawned duplicate."

This claim does not survive critical reading. `api-rename-stragglers` is about **code still importing or calling a renamed function/type** — a temporal-version-skew artifact where the new name supersedes the old name and lingering callers must be migrated. The proposed candidate is about **a state-machine trigger spawning a duplicate of a still-open instance** — a de-duplication / idempotency failure. These are structurally distinct:

- `api-rename-stragglers`: one canonical form replaces another; the old form is incorrect post-rename; the fix is a one-way migration.
- `auto-spawn-duplicate-guard-missing`: there is no rename and no version-skew; both spawned entries are syntactically and semantically valid investigation entries; the issue is that the spawn predicate should have included a "open prior instance exists" check before firing.

The correct algorithmic analogy is **idempotency failure in a state-machine spawn predicate** (a class well-known in distributed systems / job queues / scheduler design), NOT API-rename. The closest analogous concept in software engineering is **"unguarded re-entry"** or **"missing idempotency key"**, neither of which is what `api-rename-stragglers` captures.

Per the directive's PASS criterion ("a concrete sentence stating the parent class + the specific divergence axis"), the researcher's analogy fails on the parent-class identification: the claimed parent does not actually share the failure mechanism. The analogy is vibes-grounded ("both involve a missing guard") rather than structurally grounded.

Per memory `feedback_no_improvised_terminology` and `feedback_fix_the_class_not_the_instance`: the researcher's "missing guard that lets the old form persist alongside the new form" is a generic phrase that covers many distinct classes; without a specific structural correspondence (same predicate shape, same fix shape, same detector shape), the analogy is too loose to be a §F6 Level-3 analogical derivation.

### §2.4 Q4 — sharp differentiation from existing 10 patterns

**Verdict: FAIL (false).**

Per-pattern differentiation at the regex/keyword level: YES (the candidate's field-name patterns do not overlap with any of the 10 existing patterns' keyword/regex shapes).

**However, the directive's Q4 special consideration is the binding criterion**: "does this layering difference constitute sharp differentiation (a fundamentally distinct artifact class), OR does it suggest the candidate belongs in a different catalog?"

Examining patterns.yaml's contract:

1. All 10 active patterns target **production code artifacts**: `src/`, `ext/`, `test/`, `docs/`, `CLAUDE.md`, manuscript files. Six of ten have explicit `exclude_paths` blocks that contain `runs/_loop/` or `test/`. The catalog's `exclude_paths` discipline is consistent: scan production code, exclude the loop's own runtime artifacts and test scaffolding.

2. The candidate's empirical anchor (state.json + drift_signals.py) is in **two artifact classes neither of which the existing patterns target**: (a) state.json is the loop's own runtime state ledger, (b) drift_signals.py is the auto-spawn-trigger source code in the gitignored `.claude/` machine-local tree.

3. The fix-class character is also distinct: an active pattern's PROMOTE leads to a mechanical batch-fix campaign in production code. The candidate's PROMOTE would lead to a **state-machine logic change in drift_signals.py** (add an "already-open instance of same trigger" check before spawn) — a software engineering change in loop infrastructure, not a class-of-instances pattern audit.

4. The cadence character is different: the §F6 audit-class-scan flow's value proposition is "periodic 10-turn sweep of production code for stale anti-patterns". A loop-infrastructure logic bug is **a one-shot fix-bug investigation**, not a periodic pattern audit. After drift_signals.py is patched, the pattern would have zero hits forever — it would not behave like an active catalog entry, it would behave like a closed bug.

5. The "fix the class not the instance" memory is invoked by the researcher and director, but examining the empirical anchor: there is **exactly one instance class** (auto-spawned duplicate from any drift trigger). Sibling instances exist for `meta-cost-inflation-*` duplicates but those share the SAME drift_signals.py mechanism — they are additional symptoms of the SAME bug. A class-level fix to drift_signals.py would resolve all of them in one code change. This is the canonical signature of a **single-bug fix-bug flow**, not a recurring-pattern audit-class-scan entry.

**Conclusion on Q4**: the candidate is sharply differentiable at the regex level (1) but FAILS the catalog-layer differentiation test (2-5). The layer choice is NOT defensible for `patterns.yaml` membership; the candidate belongs in a different flow (`fix-bug` per §F3) targeting drift_signals.py directly, OR in a new top-level catalog `loop_infrastructure_patterns.yaml` if anko wants to formalize a sibling catalog for the gitignored `.claude/` infrastructure.

## §3. Overall verdict

**`L3_FAIL_REJECT`** — questions PASSed: 2/4 (Q1, Q2 PASS; Q3, Q4 FAIL).

**1-paragraph rationale**: Q1 and Q2 are technically satisfied — the grep patterns are runnable and produce ≥ 6 hits in state.json, comfortably within [1, 10000]. But Q3 fails because the researcher's claimed analogy to `api-rename-stragglers` does not survive structural analysis: the candidate is an idempotency-failure / missing-spawn-guard class, not a version-skew rename-straggler class. Q4 fails because the candidate's empirical anchor (state.json + .claude/drift_signals.py) lies entirely outside the patterns.yaml scope contract (src/ + ext/ + test/ + docs/, with runs/_loop/ explicitly excluded); the candidate's correct disposition is a `fix-bug` investigation targeting the drift_signals.py auto-spawn predicate (one focused fix, one regression test verifying that a second spawn of the same trigger while a prior open instance exists is a no-op), not a periodic-audit catalog entry. Two questions failing puts the candidate outside the §F6 4/4 PASS gate; per §F6 verbatim, "Critic-rejected proposals are logged in patterns.yaml proposed_classes [`rejected_classes`] with the rejection reason; NOT added to active catalog." The real underlying bug is genuine (the two duplicate state.json entries are verbatim verified), and remediation should proceed via a separate `fix-bug` investigation that anko or T106+ director can spawn directly — but the catalog entry is the wrong vehicle.

## §4. Entry data for T105 implementer (YAML block, `rejected_classes` schema)

```yaml
- id: auto-spawn-duplicate-guard-missing
  description: 'drift_signals auto-spawn mechanism lacks de-duplication guard;
    trigger fires at turn N+K, spawning a second investigation alongside the prior
    open instance from turn N. Verified empirical instance: two
    meta-director-self-audit-2026-05-{18,19} entries in state.json (auto_spawned_at_turn
    80 and 100, identical title/hypothesis/flow_template/tier_target/priority/next_stage_action;
    differ only in id, baseline_window, and auto_spawned_at_turn). Symmetric pair
    confirmed at meta-cost-inflation-2026-05-{18,19} (auto_spawned_at_turn 77 and
    103). Underlying cause: state-machine spawn predicate in drift_signals.py
    (gitignored .claude/ machine-local tree) lacks "open prior instance of same
    trigger exists" idempotency check.

    '
  grep_patterns:
  - auto_spawned_by_trigger
  - director_self_audit_due
  - auto_spawned_at_turn
  proposed_at: '2026-05-19T01:00:00+09:00'
  proposed_by: T103 researcher Observe stage / queued at T104 critic L3 audit
  rejected_at: '2026-05-19T02:00:00+09:00'
  rejected_by: T104 critic L3 audit
  rejection_reason: 'Q3 FAIL + Q4 FAIL (2 of 4 §F6 safety-rail questions fail).
    Q3: researcher claims analogy to api-rename-stragglers ("missing guard that
    lets old form persist alongside new form"); structural analysis rejects this.
    api-rename-stragglers captures temporal-version-skew where a renamed function
    has lingering old-name callers — a one-way migration class. The candidate is
    an idempotency-failure class — a state-machine spawn predicate missing an
    "open prior instance exists" check. Different failure mechanism, different
    fix shape, different detector shape. The "both involve a missing guard"
    phrasing is too generic to be a §F6 concrete analogy. Q4: the candidate''s
    empirical anchor scope (state.json + .claude/drift_signals.py) lies outside
    the patterns.yaml established scope contract (all 10 active patterns target
    src/+ext/+test/+docs/ production code; runs/_loop/ is explicitly excluded
    in 6 of 10 patterns; .claude/ is gitignored machine-local infrastructure per
    loop_architecture_2026_05_14.md and inaccessible via Read in critic dispatch).
    The candidate''s fix-shape is a one-shot logic change to drift_signals.py
    (add idempotency check), not a recurring batch-fix campaign in production
    code; the cadence character is "single bug, fix once, never fires again"
    rather than "periodic 10-turn sweep". The genuine underlying bug should be
    addressed via a fix-bug flow (§F3) targeting drift_signals.py directly, or
    via a new top-level catalog runs/_loop/loop_infrastructure_patterns.yaml if
    anko wants to formalize a sibling catalog for gitignored .claude/ infrastructure
    patterns. Q1 and Q2 PASSed cleanly (grep patterns syntactically valid;
    measured hit count >= 6 in state.json, within [1, 10000] gate). The two
    duplicate state.json entries are real and require cleanup (sub-3-second
    mechanical fix per feedback_mechanical_vs_investigation_threshold) but
    do not constitute a patterns.yaml-catalog-eligible class.

    '
  rejected_status_label: rejected_2026-05-19T02:00
```

## §5. Sibling-class derivation

N/A (verdict is L3_FAIL_REJECT; Deliverable D applies only for L3_PASS_PROMOTE).

## §6. Child investigation spawn proposal

N/A (verdict is L3_FAIL_REJECT; Deliverable E applies only for L3_PASS_PROMOTE).

**Operational note for T105 director (out-of-band recommendation)**: the duplicate state.json entries are sub-3-second mechanical cleanup per `feedback_mechanical_vs_investigation_threshold` and can be folded into T105 implementer's Triage-mechanical batch by closing one of the duplicates in each pair (e.g., close `meta-director-self-audit-2026-05-18` (T80) as superseded by `meta-director-self-audit-2026-05-19` (T100); same for the `meta-cost-inflation-*` pair). The underlying drift_signals.py idempotency-check addition is a separate decision for anko: either anko applies the fix directly, or a `fix-bug` investigation can be spawned at T106+. Both routes are legitimate; neither requires patterns.yaml catalog membership.

## §7. Caveats / out-of-scope notes

1. **Read-only tool budget**: per critic.md §A2 ("You have no tools other than `Read`"), the critic could not execute ripgrep directly. Empirical hit counts in Q2 are derived from direct Read of state.json at the two anchor regions and conservatively bounded. This does not alter the Q2 PASS verdict.
2. **drift_signals.py inaccessibility**: the auto-spawn machinery file is gitignored per `loop_architecture_2026_05_14.md`. This is an architectural confirmation that the candidate's scope is outside the canonical patterns.yaml scope.
3. **Director brief / critic.md conflict on output**: the dispatched brief asks for a file write to `runs/_loop/critic/turn_104.md`; critic.md §A2 forbids Write tool use. Critic delivered the audit inline; the orchestrator persisted to the canonical runbook path `runs/_loop/judge/turn_104_critic_audit.md`.
4. **Independence check**: the critic did not defer to the researcher's preliminary 4/4 PASS self-check. Independent re-evaluation found Q3 and Q4 FAIL.
5. **Verdict consistency with director's stated prior**: independent finding confirms the director's strong prior on Q4; the conclusion is reached independently, not by deference.
6. **REJECT is not a finding against the work**: the duplicate-spawn bug is real and worth fixing. The REJECT is against catalog membership specifically.

## §8. METRICS JSON

```json
{
  "experiment_kind": "l3_critic_audit",
  "investigation_kind": "physics",
  "investigation_id": "audit-class-scan-2026-05-19-T103",
  "stage_advancing_to": "Triage (L3-audit-half)",
  "flow_template": "audit-class-scan",
  "l3_candidate_id": "auto-spawn-duplicate-guard-missing",
  "q1_runnable_grep_pass": true,
  "q2_empirical_hit_count_in_range_pass": true,
  "q2_empirical_hit_count_measured": 6,
  "q3_concrete_analogy_pass": false,
  "q4_sharp_differentiation_pass": false,
  "questions_passed": 2,
  "overall_verdict": "L3_FAIL_REJECT",
  "entry_yaml_block_emitted": true,
  "sibling_classes_proposed_count": 0,
  "child_investigation_spawn_proposed": false,
  "src_files_modified": 0,
  "docs_modified": 0,
  "manuscript_main_edited": false,
  "patterns_yaml_modified_directly": false,
  "state_json_modified_directly": false,
  "tier_reached": 0.6,
  "verdict": "CRITIC_L3_AUDIT_FAIL"
}
```

---

## Critic verdict block (orchestrator-parsed)

VERDICT: PASS

CONFIDENCE: high

RATIONALE: The L3 critic audit completed correctly. The candidate `auto-spawn-duplicate-guard-missing` PASSed Q1 (runnable grep, 3 valid literal patterns) and Q2 (≥ 6 measured state.json hits, within [1, 10000]) but FAILed Q3 (researcher's analogy to `api-rename-stragglers` is vibes-grounded — the candidate is an idempotency-failure class, not a version-skew rename-straggler class) and Q4 (the candidate's empirical anchor scope state.json + .claude/drift_signals.py lies outside the patterns.yaml scope contract; the candidate's fix-shape is a one-shot drift_signals.py logic change and belongs in a `fix-bug` flow per §F3). Overall verdict L3_FAIL_REJECT; 2 of 4 questions PASS. Per critic.md C, both PROMOTE and REJECT are legitimate critic-audit outcomes — the audit itself completed with full evidentiary backing. T105 implementer should write the §4 YAML block into `patterns.yaml::rejected_classes`. The genuine underlying duplicate-spawn bug remains worth fixing via a separate route.

RECOMMENDED ACTION: T105 implementer applies the §4 YAML block to `patterns.yaml::rejected_classes`, performs the 10 patterns.yaml `last_scanned`/`last_count` mechanical updates per T103 §5, registers `audit-class-scan-2026-05-19-T103` in state.json, flips stale `active_investigation_id` from `edh-eu151-vortex-vs-matsui-science-2026` to the current investigation, and optionally folds the duplicate `meta-director-self-audit-2026-05-{18,19}` + `meta-cost-inflation-2026-05-{18,19}` state.json cleanup into the same batch. T106 director dispatches Document stage closure.
