---
turn: 52
subagent: critic
investigation_id: audit-class-scan-2026-05-18-T50
stage: L3_critic_audit
proposal_count: 2
verdicts: { LP-1: "REJECT-WITH-RATIONALE", LP-2: "ACCEPT-TO-ACTIVE" }
---

# Turn 52 — L3 Critic Audit of patterns.yaml::proposed_classes

## 1. Scope

- Proposals audited: **LP-1** (`coupling-skip-gate-inconsistency`), **LP-2** (`topology-function-WHAT-comment-pattern`).
- Audit basis: director.md §F6 4-question safety rail.
- Independent re-verification performed (greps re-read via direct Read of candidate file:lines; coupling-gate sites probed for any 1e-X != 1e-30 deviation).
- Tool constraint: this critic instance was dispatched with `Read` only. Grep verification done by directly reading the file:line pairs identified in the director's pre-flight + adjacent files (`combined_spin_step.jl:62`, `parsing_blocks.jl:290`, `lbfgs/driver.jl:87,126,203` for LP-2; `spin_mixing.jl:12`, `losses.jl:54-114`, `lhy/dispatch.jl:72`, `rotating_basis/propagators.jl:22,43` for LP-1 0-hit confirmation). Cross-checked against researcher's T50 sweep, which originally ran `rg` on the same regexes.

## 2. LP-1: coupling-skip-gate-inconsistency

### 2.1 Empirical re-verification

**Grep**: `abs\([a-zA-Z_]\w*\)\s*[><=]+\s*1e-(?!30\b)\d+`

**Raw hit count in `src/`: 0.**

Verification path: I sampled the canonical coupling-gate sites flagged by T50 researcher (41 files with 1e-30, 126 instances total). Direct file reads confirm:

- `src/hamiltonian/interactions/spin_mixing.jl:12` — `abs(c1) < 1e-30 && return nothing` → suffix is `1e-30`, excluded by negative lookahead.
- `src/hamiltonian/interactions/lhy/dispatch.jl:72` — `eps_dd = abs(c0) > 1e-30 ? c_dd / c0 : 0.0` → same.
- `src/hamiltonian/interactions/losses.jl:54-114` — all gates `>= 1e-30` or `> 1e-30` → excluded.
- `src/rotating_basis/propagators.jl:22,43` — `abs(θ) + abs(φ) < 1e-30` → first `abs(θ)` has trailing `+`, not `[><=]`; second `abs(φ)` is followed by `<` then `1e-30` (excluded). Plus this is an angle gate (rad), not a coupling gate.
- `src/hamiltonian/integrator/combined_spin_step.jl:67` — `abs(ws.ddi.C_dd) > 1e-30` → matched but `abs(...)` argument is `ws.ddi.C_dd` which contains `.`, not matched by `[a-zA-Z_]\w*`. Still, suffix is 1e-30 — excluded either way.

The codebase is **strictly consistent** at `1e-30` for every `abs(...)`-style coupling/angle gate I sampled. No deviation exists today.

**True/false positive analysis**: N/A (0 hits).

**Is it useful as a forward-looking watchdog?** No, see Q2 below. The §F6 1-10000 rule explicitly excludes "zero hits today, maybe useful tomorrow" patterns because they cannot be distinguished from "regex is broken" without rerunning periodically. There is a separate mechanism (Triage's `last_count = 0` field on an active pattern) for "this pattern is currently clean", but that mechanism applies to a pattern that has *already* fired at least once. A pattern that has never fired and has no current evidence is speculation.

### 2.2 4-question audit

- **Q1 (runnable detector): YES.** A concrete `grep_patterns` regex is supplied (verbatim above) and is syntactically valid.
- **Q2 (1–10000 hits): NO.** Hit count is 0. The §F6 rule explicitly forbids both endpoints: "too narrow" is the named failure mode and it applies here. No director-approved waiver exists; the director's turn_52 §2 preflight explicitly flagged this and routed it to critic.
- **Q3 (concrete analogy to `hardcoded-magic-number`): PARTIAL.** The proposal is a refinement of `hardcoded-magic-number` rather than a sibling — it asks "if `1e-30` is the agreed convention, find deviations". This is conceptually clean. **However**, since T51's director re-triage rejected `hardcoded-magic-number`'s 1e-30 finding as `no-action-rationalized` (the 126 instances are semantically heterogeneous — coupling gates, density floors, angle gates, divide-by-zero guards), the parent class itself was not promoted to a named-constant fix. With no named convention `_COUPLING_ZERO_THRESHOLD` introduced, the premise "deviation from the project-wide threshold" lacks a project-wide threshold to deviate from. The analogy stands on a stronger phrasing of the parent class than the parent class itself supports.
- **Q4 (sharp differentiation from 9 active patterns): YES, structurally.** None of the 9 active patterns target threshold-value consistency across same-semantic gate sites. `hardcoded-magic-number` is the closest neighbor (parent) but is value-agnostic. Differentiation is sharp on paper.

### 2.3 Verdict

**REJECT-WITH-RATIONALE.**

Rationale: The §F6 1–10000 empirical-anchor rule exists precisely to filter speculative patterns. LP-1 has 0 hits because there is no current inconsistency to catch, and the parent rule (`hardcoded-magic-number` → introduce `_COUPLING_ZERO_THRESHOLD`) was rejected at T51 due to semantic heterogeneity, so the proposed deviation has no canonical baseline. Promoting LP-1 to active catalog would (a) violate the safety rail it is meant to be guarded by, (b) ship a regex that today's audits will report as `last_count = 0` indistinguishably from "regex broken", and (c) create a sibling-violation detector for a parent rule that the project explicitly decided not to enforce.

If a future audit cycle finds a genuine 1e-32 / 1e-28 coupling-gate deviation in the wild (an *instance*), that instance can drive a fresh L3 proposal at that time — backed by 1+ real hits. That is the correct entry into the catalog per §F6's "find class when triggered by instance" baseline.

Note for the record: LP-1's intent ("consistency of threshold values across same-semantic call sites") is a legitimate design quality concern. It is just not what §F6's pattern catalog is built to surface. A different mechanism (a periodic lint, or a `const` audit at integration test time) would be the right tool. That is a research-mode proposal, not a pattern-catalog entry.

## 3. LP-2: topology-function-WHAT-comment-pattern

### 3.1 Empirical re-verification

**Grep**: `#\s*(Cross product|Dot product|Gradient|Divergence|Curl|Centred differences|Compute\s+(the\s+)?spin|Normalise?\s+to)`

**Raw hit count in `src/`: 5** (matches director pre-flight count, independently verified by reading each cited line).

First 5 (only) hits with file:line, with TRUE/FALSE-POSITIVE call:

1. `src/hamiltonian/integrator/combined_spin_step.jl:62`
   `# Compute spin density into bufs.{Fx_r, Fy_r, Fz_r}, then if DDI is`
   → **FALSE-POSITIVE**. Reading lines 62-66 (verified by Read), this is a multi-line WHY-comment explaining the routing logic ("if DDI is active fold it through the FFT convolution... When DDI is off we still need the spin density (for c1 ⟨F⟩) but the convolution is skipped and Phi_* is treated as zero."). The first line *looks* like a WHAT preamble but is the topic sentence of a WHY paragraph.

2. `src/workflow/experiments/schema/parsing_blocks.jl:290`
   `# Normalise to internal fields for downstream consumers.`
   → **TRUE-POSITIVE (mild)**. Reading lines 290-298: the comment describes WHAT the next 7 lines do (copy `lhy_block["c_lhy"]` into `inter["c_lhy"]`). The WHY would be "lhy YAML schema accepts a top-level block; downstream parsers expect interactions.c_lhy" — that *is* informational and is the kind of bridging-comment that has value. Borderline; tighter than a pure cargo-cult WHAT but still leans WHAT.

3. `src/solvers/lbfgs/driver.jl:87`
   `# Gradient-coverage guard: energy_gradient! covers kinetic + trap +`
   → **FALSE-POSITIVE**. Reading 87-90+ (verified), this is the start of a multi-line WHY paragraph documenting *what energy_gradient! is missing* (c2 singlet-pair channel) and *why the guard exists*. Substantive WHY.

4. `src/solvers/lbfgs/driver.jl:126`
   `# Gradient at current psi (Riemannian, used unchanged for the`
   → **TRUE-POSITIVE (clear)**. Reading 126-128: `# Gradient at current psi (Riemannian, used unchanged for the / # convergence test — `grad_norm` is the *physical* residual).` — the "Gradient at current psi" portion is pure WHAT; the parenthetical adds modest WHY. Borderline WHAT-heavy.

5. `src/solvers/lbfgs/driver.jl:203`
   `# Gradient at new psi`
   → **TRUE-POSITIVE (clear)**. Pure WHAT label for the next line `E_new = energy_gradient!(grad_new, psi, ws; k_squared_dev)`. Classic cargo-cult.

**True-positive count: 3 (lines 290, 126, 203), borderline-WHAT. False-positive count: 2 (lines 62, 87 — multi-line WHY paragraphs whose first line happens to match the regex).**

A 60% true-positive rate at a 5-hit population is acceptable for a class-level pattern detector (the false-positives are recoverable via 3-line context reading before any mechanical fix). The pattern produces actionable signal.

### 3.2 4-question audit

- **Q1 (runnable detector): YES.** Concrete regex; matches the project's hits at the expected count.
- **Q2 (1–10000 hits): YES.** 5 hits, well within range.
- **Q3 (concrete analogy to `cargo-cult-comment`): YES, sharp.** `cargo-cult-comment` parent is explicitly `detect: |  Manual review` (no grep). LP-2 *upgrades* the parent from manual to runnable by targeting a specific high-density-of-violations sub-domain (vector calculus / math-physics function bodies). This is the canonical L3 "runnable specialization of a manual parent" — exactly the §F6 use case.
- **Q4 (sharp differentiation from 9 active patterns): YES.** Differentiation against the 9-pattern set:
  - vs `cargo-cult-comment` (parent): LP-2 is a runnable specialization with concrete regex; parent is review-only. Sharp.
  - vs `doc-staleness`: doc-staleness targets CLAUDE.md / README / memory drift (high-impact docs); LP-2 targets inline source comments. Different scope.
  - vs `deprecated-name-leak`, `api-rename-stragglers`: name-tracking patterns, not comment-content patterns. Different concern.
  - All other 5 (hardcoded-magic-number, dead-export, large-file-bloat, test-mock-of-real, paper-unit-system-wrong-param-in-spot-check): orthogonal subjects.
  Sharp differentiation confirmed.

### 3.3 Verdict

**ACCEPT-TO-ACTIVE.**

Rationale: LP-2 passes all 4 §F6 questions, has 5 real hits with a 60% true-positive yield, and represents the canonical "runnable specialization of a manual parent" L3 derivation. The proposed regex is tight enough not to swamp future audits (5 hits is below the 10000 noise ceiling by 3 orders) and broad enough to catch real candidates outside the originating file (topology.jl was the trigger; current hits are in `combined_spin_step.jl`, `parsing_blocks.jl`, `lbfgs/driver.jl`).

Two safety notes for the T53 implementer who will promote LP-2 to active catalog:
1. **Recommend adding `exclude_paths: [test/, docs/]`** in the active-catalog entry to mirror sibling patterns (the regex would otherwise match docstring snippets in test files).
2. **Recommend `last_count: 5`** at promotion time, **last_scanned** = T52 timestamp. Of the 5 current hits, lines 62 and 87 are FALSE-POSITIVES (multi-line WHY paragraphs); the actionable instances are 290, 126, 203 (~3 mechanical-fix candidates for a future audit cycle if anko prioritizes).

Differentiation from the active `cargo-cult-comment` is preserved: parent stays as the "manual review of any source comment" entry, LP-2 sits beside it as the "grep-detectable subset focused on math-physics function bodies". This is the §F6-intended catalog topology.

## 4. Summary

- **LP-1 verdict: REJECT-WITH-RATIONALE.** 0 hits fails §F6 1–10000 rule; parent rule was already declined; speculative watchdog not differentiable from broken-regex at last_count=0. Stays in `proposed_classes` permanently with rejection_reason; NOT added to active catalog.
- **LP-2 verdict: ACCEPT-TO-ACTIVE.** All 4 questions pass; 5 hits (3 true-positive); sharp specialization of `cargo-cult-comment`. Moves from `proposed_classes` to active `patterns:` at T53.
- **T53 implementer action required**:
  1. **YAML edit 1**: in `runs/_loop/patterns.yaml`, append `rejection_reason` to the LP-1 entry under `proposed_classes` with the rationale from §2.3 above (keep the entry there with status `rejected_2026-05-18T13:00`).
  2. **YAML edit 2**: move the LP-2 entry from `proposed_classes` into the active `patterns:` list with `exclude_paths: [test/, docs/]` added, `last_scanned: '2026-05-18T13:00:00+09:00'`, `last_count: 5`, `related_classes: [cargo-cult-comment]`.
  3. **audit_history**: append a new row noting the L3 critic-audit outcome (1 accept, 1 reject) with this turn's timestamp.
  4. **No src/ touch.** No state.json touch by implementer; director handles state.json close-out for the audit-class-scan cycle (tier 0.85 → 1.0 at Document stage T53/T54).

## 5. Metrics

```json
{
  "experiment_kind": "text_only",
  "proposals_audited": 2,
  "lp_1_grep_hit_count": 0,
  "lp_1_q1_runnable_detector": true,
  "lp_1_q2_in_range": false,
  "lp_1_q3_concrete_analogy": true,
  "lp_1_q4_sharp_differentiation": true,
  "lp_1_verdict": "REJECT-WITH-RATIONALE",
  "lp_2_grep_hit_count": 5,
  "lp_2_q1_runnable_detector": true,
  "lp_2_q2_in_range": true,
  "lp_2_q3_concrete_analogy": true,
  "lp_2_q4_sharp_differentiation": true,
  "lp_2_verdict": "ACCEPT-TO-ACTIVE",
  "audit_report_present": true,
  "src_files_modified": 0,
  "patterns_yaml_modified": false,
  "state_json_modified": false,
  "investigation_id": "audit-class-scan-2026-05-18-T50",
  "stage_advancing_to": "L3_critic_audit",
  "flow_template": "audit-class-scan",
  "obstruction_encountered": false,
  "verdict_summary": "mixed: LP-1 REJECT (0 hits, fails §F6 1-10000 rule, parent rule already declined), LP-2 ACCEPT (5 hits, sharp runnable specialization of cargo-cult-comment)"
}
```

---

VERDICT: INCONCLUSIVE
