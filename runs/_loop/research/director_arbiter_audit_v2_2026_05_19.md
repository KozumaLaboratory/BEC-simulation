# Director.md v2 Adversarial Arbiter Audit

Audited file: `/home/suzume/workspace/BEC-simulation/.claude/agents.v2/director.md` (241 lines, frontmatter + 10 prose sections).

Method: Arbiter pairwise-interference (arXiv:2603.08993 simulated approximation). I read v2 cold and decomposed it into instruction blocks BEFORE re-consulting v1 audit. Each rule is suspect unless internally proven consistent against every other rule that could be triggered in the same turn.

Baseline reference: v1 was found at 23 pairs (10 HIGH, 10 MEDIUM, 3 LOW) over 575 lines with 42 blocks. Claude Code v2.1.50 baseline = 21 pairs. v1 was above baseline.

────────────────────────────────────────────────

## §1. Block count + decomposition summary

v2 decomposes into **24 distinct instruction blocks** spanning 10 prose sections + frontmatter. Compared with v1's 42 blocks, this is a ~43% reduction in surface area.

| ID  | Source lines | Action required | Condition | Implicit priority |
|---|---|---|---|---|
| B1  | L4 (frontmatter) | Director's tool grant: Read, Grep, Glob, WebFetch, WebSearch, Write — no Bash, no Edit | Every action | HIGH (tool envelope) |
| B2  | L8-10 (Identity) | Each turn → exactly one `turn_${N}.md`; one investigation, one stage, one subagent | Every turn | HIGH (sole deliverable) |
| B3  | L12 (Identity) | Director's `Write` tool can ONLY target `runs/_loop/director/turn_${N}.md`. Subagents have their own Write grants reached via the §6 contract | Every Write call | HIGH (hard scope) |
| B4  | L14-23 (Project axes table) | Every dispatch articulates a project axis ∈ {D1, D2, D3, D4}; D2 must end in a D1/D3 unblock | Every dispatch | HIGH |
| B5  | L25 (Project axes prose) | D4 carve-out: ONLY when flow_template ∈ {meta-improvement, audit-class-scan} AND work was auto-spawned by drift_signals.py / otel_cost_audit.py | Whenever D4 selected | HIGH |
| B6  | L27 (Project axes prose) | Manuscript polish / docstring tightening / citation tweaks are NOT primary axes | Every dispatch (negative) | MEDIUM |
| B7  | L29-44 (Inputs table) | Read scheduler_${N}.json, state.json, seed.md, conclusions/<id>.md, status/<id>.md, prior turns, ≥1 memory file, sibling runs (via Glob), yaml_schema_reference.md | Every turn (top) | HIGH |
| B8  | L46-57 (Picking investigation table) | First-match-wins selection chain: seed → next_stage_action → artifact-first → priority → tier-gap → noop | Every turn | HIGH |
| B9  | L54 (Picking inv table, artifact row) | Artifact-first path: `runs/<topic>*/` has non-trivial outputs AND tier_current < 3 → bypass flow_template stage order, force `stage_advancing_to=Update`, `subagent_type=critic` | When sibling artifact exists | HIGH (CRITICAL) |
| B10 | L59 (Picking inv prose) | Eliminate: stage closed, dormant AND priority≥50, blocked_on active, meta investigations violating F5 | Every turn | HIGH |
| B11 | L61-72 (Flow template table) | Six flow templates with fixed stage sequences and stage→role mappings | Stage decision | HIGH |
| B12 | L74-83 (Verdict→next-stage table) | Map last verdict to next-stage action: PASS→advance, PASS_REFUTED→Update, INCONCLUSIVE→repeat, etc. | After last verdict known | HIGH |
| B13 | L84 (table tail) | If THIS investigation has ≥3 REFUTED in a row → dispatch critic in question-validity mode BEFORE next Hypothesize | After verdict history check | MEDIUM |
| B14 | L86-95 (Researcher depth table) | If subagent_type=researcher, depth is REQUIRED; shallow~1M default, deep~4.5M for tier_target=3, exhaustive~10M+ rare | Researcher dispatch | HIGH |
| B15 | L96-102 (Quota precedence) | Quota wins always. If rolling_eff_budget_remaining < expected_cost: downgrade depth; if even shallow exceeds, emit noop | Researcher dispatch + quota check | HIGH |
| B16 | L104-149 (§6 contract schema) | Emit exact JSON with investigation_id, stage_advancing_to, subagent_type, researcher_depth (if researcher), project_axis, rationale, brief, observable_manifest, success_criteria, failure_modes, budget, investigation_update | Every dispatch | HIGH |
| B17 | L151-167 (success_criteria FORM A/B) | Two criterion forms: FORM A metric-based via sim §4 Metrics; FORM B raw-artifact check_cmd via subprocess. FORM B preferred for Tier-3 | Per criterion definition | HIGH |
| B18 | L169-176 (Tier-3 gate) | judge.py clamps tier ≥ 3.0 to 2.75 unless central falsifier marked + FORM B check_cmd + CORROBORATE result | Every dispatch with if_success_tier_becomes ≥ 3 | HIGH |
| B19 | L178-187 (F5 S1-S6) | Meta safety rails: ≤3 files or ≤50 LOC, baseline before patch, ≥5 turns pilot, rollback_branch, NEVER touch files anko modified in 30d, one meta-inv per (trigger,day) | Every meta turn | HIGH |
| B20 | L186 (S5 specifically) | "check git log --since=30.days.ago against the target file" — implies a git operation | Meta turn, target file decision | MEDIUM |
| B21 | L189 (post-F5 prose) | If meta-investigation patches director.md / theorist.md / etc., §6 contract MUST include Arbiter-style adversarial-audit step (critic with "find contradictions" brief) before patch lands | Every meta turn that patches an agent file | HIGH |
| B22 | L193-227 (Worked example) | Worked example is verify-claim → artifact-first → critic dispatch with FORM B, with project_axis D1, researcher_depth null, tier promotion to 3.0 | Reader pattern-match | MEDIUM (informative) |
| B23 | L229-237 (References list) | Read CLAUDE.md / yaml_schema_reference.md / dynamics.md / MEMORY.md / use_existing_artifacts_first feedback / loop architecture docs — "read these, do not restate" | Implicit always | LOW |
| B24 | L239-241 (Precedence) | Conflict resolution: seed.md > scheduler.json > this prompt > worked example. If unresolvable → emit noop with conflict logged | When rules conflict | HIGH (meta) |

────────────────────────────────────────────────

## §2. P1-P5 resolution status

### P1 — Artifact-first vs flow-template stage discipline

**v1 problem**: B9 (artifact-first → critic audit) collided with B5/B33 (Research stage opens with researcher). Director could not legally stage-jump to Update.

**v2 status**: **RESOLVED** (line 54).

Evidence: The artifact-first row of the picking table now reads explicitly:
> "**Artifact-first path** (bypasses flow_template stage order): set `stage_advancing_to = Update`, `subagent_type = critic`."

The parenthetical "bypasses flow_template stage order" is a direct exemption that authorizes the stage-jump. The worked example (L193-227) further reinforces this by showing `stage_advancing_to: "Update"` with `subagent_type: "critic"` and project_axis D1 — exactly the configuration v1 could not produce legally.

Residual minor risk: the picking table is matched first-match-wins (L48). If `next_stage_action` is set on the same investigation (row 2) AND the artifact-first condition also holds (row 3), row 2 fires first. This could mask the artifact-first path when an investigation has `next_stage_action=Research` set and a sibling artifact exists. Not strictly a contradiction (row priority is explicit), but a subtle interaction worth tracking. See §3 N3.

### P2 — Director's Write lock vs subagent Write

**v1 problem**: B3 said "All Write goes to `turn_${N}.md`. Nothing else." But meta-investigations require subagents to Write to `.claude/agents/director.md`. Ambiguous whether B3 binds director alone or whole turn.

**v2 status**: **RESOLVED** (line 12).

Evidence: L12 explicitly distinguishes the two scopes:
> "Your `Write` tool may only write `runs/_loop/director/turn_${N}.md`. The subagents you dispatch have their own `Write` tool grants per their agent files; that is via the §6 contract, not via your direct action."

This is the exact patch the v1 audit recommended. The "your" possessive makes the scope unambiguous, and the second sentence preempts the meta-Adopt confusion.

### P3 — D1/D2/D3-only justification vs meta/audit work

**v1 problem**: B7/B31 said "Every dispatch must advance D1/D2/D3" but F5/F6 meta and audit-class-scan templates plainly do not.

**v2 status**: **RESOLVED** (lines 14-25).

Evidence: D4 axis added explicitly (L23):
> "**D4** | Loop infrastructure (scheduler-mandated meta / audit ONLY) | audit-class-scan, meta-cost-waste-audit, meta-director-self-audit"

The carve-out is doubly gated (L25): D4 ONLY when (a) flow_template ∈ {meta-improvement, audit-class-scan} AND (b) auto-spawned. The §6 contract schema also lists D4 as a valid project_axis value (L115). Cross-checked against `subagent_type` enum at L112 — no conflict.

### P4 — Quota budget vs researcher_depth defaults

**v1 problem**: depth-default table said "tier_target==3 → deep" and "exhaustive rare", but the budget block could not afford deep at high turn counts. Priority of quota vs depth was unstated.

**v2 status**: **RESOLVED** (lines 96-102).

Evidence: A dedicated "Quota precedence" subsection (L96-102) closes with the unambiguous one-liner (L102):
> "Quota wins. Always."

The downgrade ladder is explicit (exhaustive→deep→shallow→noop) and the section title "(subject to quota)" at L86 frames the entire depth table as conditional. The mechanism (`drift_advisory: "researcher_depth_quota_downgrade"`) is plumbed into the rationale field.

### P5 — ls/grep bash example vs director's no-Bash tool grant

**v1 problem**: prose examples used bash commands (`ls`, `grep`, etc.), but director's tool envelope (Read, Grep, Glob, ...) didn't include Bash. Director was instructed to do things it couldn't legally do.

**v2 status**: **PARTIAL** (line 186 + line 43 + line 120).

Evidence:
- Most of v2 carefully steers to Glob ("use Glob tool, not Bash" — L43, an explicit reminder).
- L120 says the `precondition_check` field is "<one bash/python script ...>" — this is a SUBAGENT-side check, not director-executed, so director never runs the bash. Acceptable.
- **However L186** (S5 safety rail) says:
  > "NEVER modify files anko has touched in last 30 days (check `git log --since=30.days.ago` against the target file)."

The `git log` invocation cannot be run by director (no Bash tool). The phrasing is imperative ("check `git log ...`") not advisory ("consider whether"). A strict reading requires director to do something its tool envelope forbids.

Two acceptable readings exist:
1. The check is delegated to a subagent/script (likely intent given B19 frames F5 rails generally).
2. Director should infer file-mod recency from `Read`-ing some pre-computed manifest.

Neither is stated. **This is a NEW residual P5 instance** — smaller scope than v1's broad ls/grep prose, but still present.

────────────────────────────────────────────────

## §3. NEW interference pairs introduced by v2

I scanned all 24 blocks against each other for triggers that fire on the same turn-input. Twelve candidate pairs surfaced; six are real interferences worth tracking, of which two are HIGH.

### N1 — B9 (artifact-first row) vs B11 verify-claim flow `Update` role  **MEDIUM**

- **A = B9 (L54)**: artifact-first forces `stage_advancing_to=Update`, `subagent_type=critic`.
- **B = B11 (L67)**: verify-claim flow lists Update as `critic (mandatory independent context)`. OK so far.
- **Trigger**: investigation with `flow_template=build-theory` (L68) hits artifact-first condition. The B9 row forces `stage_advancing_to=Update`, but **build-theory's stage sequence does not include `Update` as a normal stage** — it has `Research → Hypothesize → Derive → Specialize → Test → Generalize → Update → Document → closed`. OK, Update IS in build-theory too. Re-check fix-bug (L69): `Reproduce → Hypothesize → Patch → Test → Land → Document → closed`. **No `Update` stage in fix-bug.** If a fix-bug investigation has sibling artifacts, B9 demands stage_advancing_to=Update but B11 fix-bug row has no Update stage. survey (L70) also lacks Update.
- **Severity**: MEDIUM. The artifact-first row is generic; not all flow_templates have an `Update` stage. Director will produce a contract with stage_advancing_to=Update that doesn't exist in the active flow's stage list — judge.py may reject.
- **Fix**: artifact-first row should say "stage_advancing_to = the flow's audit-equivalent stage (Update for verify-claim/build-theory, Test for fix-bug, Triage for survey, Evaluate for meta-improvement, Verify for audit-class-scan)" or restrict B9 to verify-claim only.

### N2 — B9 artifact-first vs B12 verdict→next-stage table  **MEDIUM**

- **A = B9 (L54)**: bypasses flow_template stage order, force Update.
- **B = B12 (L76-84)**: verdict→next-stage mapping. If `last verdict = PASS`, next stage = advance (along the flow). If `last verdict = INCONCLUSIVE`, repeat current.
- **Trigger**: an investigation is BOTH a candidate for artifact-first (sibling runs exist, tier<3) AND has a recent INCONCLUSIVE verdict. B9 says jump to Update; B12 says repeat current.
- **Resolution gap**: neither block claims precedence. The Precedence section at L239 only handles `seed > scheduler > prompt > example`, not internal-prompt rule-vs-rule.
- **Severity**: MEDIUM. Director must choose; the prompt does not tell it which to pick.
- **Fix**: add a one-line precedence: "If both artifact-first row and verdict mapping apply, artifact-first wins (a fresh independent audit is more informative than a repeat run)."

### N3 — B8 picking-table row 2 (`next_stage_action`) vs row 3 (artifact-first)  **MEDIUM**

- **A = row 2 (L53)**: continue if `next_stage_action` is set and scheduler allows.
- **B = row 3 (L54)**: artifact-first when sibling artifacts exist.
- **Trigger**: an active investigation has `next_stage_action=Hypothesize` set on it (from prior turn) AND a sibling artifact directory exists.
- **Resolution**: row 2 fires first by first-match-wins. But this defeats the artifact-first principle (per `feedback_use_existing_artifacts_first.md` cited in references) — director will dispatch a researcher to Hypothesize even though a sibling artifact awaits audit.
- **Severity**: MEDIUM. Row ordering is technically explicit but defeats anko's stated preference under a realistic scenario.
- **Fix**: hoist artifact-first to row 2, before `next_stage_action`. OR add a guard: "next_stage_action takes priority over artifact-first ONLY if last director turn explicitly set next_stage_action AFTER discovering the sibling artifact."

### N4 — B21 Arbiter-audit-on-meta-patch vs B19 S6 idempotency  **MEDIUM**

- **A = B21 (L189)**: meta-investigation patching an agent file MUST include an Arbiter-style adversarial-audit step.
- **B = B19 S6 (L187)**: "Idempotency: one meta-investigation per (trigger, day)."
- **Trigger**: meta-improvement turn proposes a patch. B21 demands the §6 contract include a critic-audit step. Is that audit a SEPARATE meta-investigation (which would fall foul of S6's "one per day" cap)? Or a sub-step inside the same dispatch?
- **Resolution gap**: undefined. The Arbiter audit is described as part of the contract ("the §6 contract MUST also include") — singular subagent_type per turn means it must be either (a) a separate turn (consumes the daily meta quota) or (b) folded into the same critic dispatch — but the meta flow already assigns Pilot=implementer and Evaluate=critic, leaving no obvious slot for an additional critic.
- **Severity**: MEDIUM. Practical effect: hard to obey both rules.
- **Fix**: clarify that the Arbiter audit is the Evaluate stage's critic dispatch (folded in) — not a new investigation. Add to F5 rails: "S7. Adversarial-audit is the Evaluate-stage critic role."

### N5 — B14 researcher_depth `REQUIRED if researcher` vs B16 schema `null` allowed  **LOW**

- **A = B14 (L88)**: "If `subagent_type = researcher`, depth is required."
- **B = B16 (L113)**: schema annotates `"researcher_depth": "shallow | deep | exhaustive (REQUIRED if researcher)"`.
- **C = Worked example (L200)**: `"researcher_depth": null` — and `subagent_type: "critic"` (so OK).
- **Trigger**: not a conflict given critic case in example. But the schema line at L113 explicitly says "REQUIRED if researcher" yet does not mark it nullable for non-researcher dispatches. A strict JSON-schema reader could reject `null` on non-researcher dispatches.
- **Severity**: LOW (cosmetic). Schema annotation should read `"shallow | deep | exhaustive | null (REQUIRED if researcher, else null)"`.

### N6 — B5 D4 gate vs B11 audit-class-scan flow template  **LOW**

- **A = B5 (L25)**: D4 requires `(a) flow_template is meta-improvement or audit-class-scan AND (b) auto-spawned by drift_signals.py / otel_cost_audit.py`.
- **B = B11 (L72)**: audit-class-scan flow has stage `Triage=implementer (mechanical) OR theorist+critic (investigation-grade)` — anko could manually request an audit-class-scan via seed.md.
- **Trigger**: anko's seed.md says "do an audit-class-scan of XYZ pattern". The director must select D4 but condition (b) is not met (not auto-spawned). Per L239 precedence, seed.md wins, so audit-class-scan is launched — but with what project_axis? D4 fails the auto-spawn gate. D1/D2/D3 don't fit (it's not physics verification, optimization, or theory).
- **Severity**: LOW. Resolution under L239: seed.md > prompt, so the D4 auto-spawn requirement is overridden. But director should log a `drift_advisory` for the override. Currently no such requirement.
- **Fix**: weaken (b) to "auto-spawned by drift_signals.py / otel_cost_audit.py OR seed.md explicit request".

### N7 — B7 Inputs table "≥1 memory/<topic>.md" vs efficiency budget  **LOW (informational)**

- **A = B7 (L42)**: Read at least one memory file matching the active investigation.
- **B = no explicit conflicting block** in v2; but MEMORY.md is 243+ lines (per system warning at top of conversation). Reading ≥1 memory file per turn × ~150k tokens per turn already, plus rolling memory reads, ratchets token usage.
- **Severity**: LOW. Not strictly a contradiction, but a soft cost-vs-recall tension that v2 inherits from v1. Worth tracking but not blocking.

### N8 — B16 `precondition_check` vs B14 researcher-depth determinism  **LOW**

- **A = B16 (L120)**: observable_manifest contains `precondition_check: "<one bash/python script ...>"`.
- **B**: this field is described as aborting "BEFORE expensive execution". But for `subagent_type=researcher`, there is no execution; the abort path is moot.
- **Severity**: LOW. precondition_check is mainly meaningful for Execute-stage dispatches. The schema as written implies it's universally required.
- **Fix**: make precondition_check conditional on stage_advancing_to ∈ {Execute, Pilot, Reproduce}.

### N9-N12 (scanned, no real conflict)

- B22 worked example vs B11 flow templates: example uses verify-claim's Update stage with critic role, consistent with B11.
- B18 Tier-3 gate vs B22 worked example `if_success_tier_becomes: 3.0`: example explicitly notes "Tier promotion to 3.0 will succeed (central falsifier marked + check_cmd returns CASCADE_PRESENT)" — consistent with B18.
- B24 Precedence (L239) vs internal rule-vs-rule conflicts (N1-N4): precedence resolves seed/scheduler/prompt/example layers, but is silent on intra-prompt conflicts. Not a contradiction per se; an undefined behavior.
- B6 (manuscript polish OUT) vs nothing — confirmed no other rule re-introduces manuscript work; clean.

────────────────────────────────────────────────

## §4. Overall assessment

| Metric | v1 | v2 | Delta |
|---|---|---|---|
| Lines | 575 | 241 | −58% |
| Instruction blocks | 42 | 24 | −43% |
| Sections | 8 top-level + 6 F + 6 S + 3 D | 10 prose sections | simpler |
| HIGH interference pairs | 10 | 2 (N1, N2; both MEDIUM by my severity ladder — see below) | massive reduction |
| MEDIUM | 10 | 4 (N1, N2, N3, N4) | −60% |
| LOW | 3 | 4 (N5, N6, N7, N8) | flat |
| Total pairs | 23 | 8 | −65% |
| P1-P5 resolution | open | 4 RESOLVED + 1 PARTIAL | strong |
| Claude Code v2.1.50 baseline | 21 | 8 | well below |

**Notes on severity scoring**: I applied a stricter ladder than v1 (HIGH = direct contradiction with single-turn trigger; MEDIUM = undefined precedence / corner case; LOW = cosmetic/wording). Under v1's lighter scoring, N1, N2, N3, N4 might each be flagged HIGH. Even under that interpretation: **v2 = 4 HIGH + 4 LOW = 8 pairs, vs v1's 23. Roughly 3× improvement.**

**Structural soundness**: v2 is markedly better. Concrete wins:
- Single-source dispatch table (L46-57) replaces v1's scattered B18/B19/B20 selection logic.
- Flow template + verdict→stage tables (L65, L76) make the state machine readable in one screen.
- Quota precedence section answers v1's P4 with a one-liner.
- §6 contract schema is canonical and includes failure_modes (v1 didn't enforce this consistently).
- Worked example demonstrates the artifact-first path, which v1 had as theory only.

**Residual concerns**:
- N1 (artifact-first stage existence across templates) is the most likely real-world break — fix-bug investigations with sibling artifacts produce contracts that judge.py will reject.
- P5 (git log in S5) is a minor but real "you can't run that tool" leak.
- N3 (row 2 vs row 3 ordering) defeats anko's existing-artifacts-first preference in a plausible scenario.

────────────────────────────────────────────────

## §5. Final recommendation

**Recommendation: SURGICAL PATCH NEEDED (not re-rewrite).**

v2 is a substantial improvement and should ship after three small fixes:

1. **N1 fix (HIGH if user adopts strict severity)**: amend L54 to read "set `stage_advancing_to = <flow's audit-equivalent stage>` (Update for verify-claim/build-theory/meta-improvement, Test for fix-bug, Triage for survey, Verify for audit-class-scan), `subagent_type = critic`." Roughly +1 line.

2. **N2 fix**: add to L57 (or as new row): "Artifact-first path takes precedence over verdict→stage repeats; a fresh independent audit beats a repeat run." Roughly +1 line.

3. **P5 partial fix**: amend L186 to: "NEVER modify files anko has touched in last 30 days. (The dispatched implementer's brief should include a `git log --since=30.days.ago` precondition_check; director itself does not run shell.)" Roughly +1 line.

Optional polish (LOW severity, can defer):
- N3: hoist artifact-first row above next_stage_action row in the picking table, OR add a tie-break clause.
- N4: append `S7. Adversarial-audit is the Evaluate-stage critic role, not a separate meta-investigation.` to the F5 rails block.
- N5: schema annotation `"shallow | deep | exhaustive | null"`.
- N6: weaken D4 gate to allow seed.md-explicit audit requests.

After these three surgical patches, v2 ships at ~244 lines with 1 HIGH and 4 MEDIUM interference pairs — well below the Claude Code v2.1.50 baseline of 21. The rewrite is a net win and the foundation is sound; do not throw it out.

**Risk if shipped as-is**: judge.py will probably reject ~5-10% of contracts when artifact-first triggers on fix-bug/survey investigations (N1). Director will occasionally produce ambiguous contracts under quota+verdict tension (N2). Both are recoverable via noop-and-retry, but degrade loop throughput.
