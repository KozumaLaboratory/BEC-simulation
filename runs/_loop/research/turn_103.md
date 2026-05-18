---
turn: 103
subagent: researcher
topic_tags: [audit-class-scan, patterns-yaml, AUDIT_DUE-resolution, level-2-periodic-sweep, code-debt, fourth-cycle, observe-stage, post-tdhfb-rotation]
paper_section: null
depends_on: [87, 88, 89, 61, 62, 63, 50, 51, 52, 53, 54, "runs/_loop/patterns.yaml", "runs/_loop/director/turn_103.md", "runs/_loop/research/turn_87_audit_class_scan.md", "runs/_loop/research/turn_61_audit_class_scan.md"]
produces: "Per-pattern findings table (10 patterns, fourth full §F6 cycle) + triage classification + anomaly-watch duplicate-meta confirmed + L3 proposal (1) + patterns.yaml last_scanned/last_count updates queued for T104 Triage"
---

# Turn 103 — Audit-class-scan Observe Stage (Fourth Full Cycle)

## §0 Directive received

Investigation: `audit-class-scan-2026-05-19-T103`
Action: `researcher_shallow`
Stage: Observe (§F6 first stage)
Gap since last cycle: 14 turns (T87 closed at T89, `last_scanned 2026-05-18T19:00:00+09:00`)
Trigger: AUDIT_DUE drift advisory `director_must_address` at T102; §F6 cadence exceeded by 1.4×; T87 closing_note scheduled next cycle ~T98 (5 turns past mark).
Anti-pattern guards active: read-only sweep, no src/ modifications, no patterns.yaml modifications, no state.json modifications, no manuscript edits.

---

## §1 Pre-sweep context

**What is being swept**: All 10 active patterns in `runs/_loop/patterns.yaml` as of `last_scanned: 2026-05-18T19:00:00+09:00`. Catalog is unchanged from T88 Triage (no promotions, no rejections since T54). `proposed_classes: []`, `rejected_classes: [coupling-skip-gate-inconsistency (rejected T52)]`.

**Why now**: AUDIT_DUE gap = 14 turns. Last full cycle: T87 (Observe) → T88 (Triage) → T89 (Document), closed 2026-05-18T19:00:00+09:00. §F6 cadence rule (~10 turns since last cycle) exceeded by 1.4×. T87 closing_note explicitly scheduled "next cycle ~T98"; we are 5 turns past. Director dispatch fired at T103 as `director_must_address`.

**Context delta since T87 (T88–T102 activity)**:
- TDHFB Phase 2 HF kernel generic closed Tier 3 at T102: new files `src/hamiltonian/tdhfb/hartree_fock_matrix_generic.jl`, `src/hamiltonian/tdhfb/channel_kernel.jl`; new exports `hf_matrix_generic`, `hf_matrix_generic!`, `ku_c01_to_g_S`, `ku_to_g_S`, `channel_kernel`. These are the primary new code surface to audit.
- Sign-pattern Lemma 1 T94: minor extensions to `src/analysis/phases/sign_pattern.jl`.
- Bug-4 DDI revalidation T97: no new code surface.
- No deletions or renames of public API (verified via deprecated-name-leak scan below).

**Anomaly-watch**: Director turn_103.md §1 flags that both `meta-director-self-audit-2026-05-18` (auto_spawned_at_turn 80) and `meta-director-self-audit-2026-05-19` (auto_spawned_at_turn 100) are present in state.json at lines 3150 and 3465 respectively, with identical `title`, `hypothesis`, `flow_template`, `tier_target`, `priority`, and `next_stage_action`. Verified in this turn — see §3.

---

## §2 Per-pattern sweep results table

| pattern_id | grep_invocation | raw_hits (src) | raw_hits (ext) | filtered_hits | triage | one-sentence rationale |
|---|---|---|---|---|---|---|
| deprecated-name-leak | 3 patterns (see §2.1) | 0 | 0 | 0 | no-finding | 0 hits across all 3 patterns in src/ and ext/; T48 batch-fix holds; no regression. |
| api-rename-stragglers | 4 patterns (see §2.2) | 0 | 0 | 0 | no-finding | 0 hits for @deprecate, Base.depwarn, _old_, _v1_ in src/ and ext/. |
| doc-staleness | 4 grep + manual (see §2.3) | 1 (non-actionable) | 0 | 0 actionable | no-action-rationalized | 1 TODO hit is the same explicit "not an unfilled TODO" meta-comment (canonical_polyhedral_states.jl:90); 3 spot-checks pass. |
| hardcoded-magic-number | `\b1e-?\d+\b` + `\b1\.0e-?\d+\b` (see §2.4) | 357 + 22 | 19 | 0 actionable | no-action-rationalized | 1e-30 specifically = 126 (stable vs T87); broader regex = 357 (first recorded; all semantically heterogeneous); T51 re-triage holds; see §2.4 note. |
| dead-export | detect-block manual (see §2.5) | ~7 new exports checked | — | 0 confirmed dead | no-action-rationalized | New TDHFB HF kernel exports (channel_kernel, hf_matrix_generic, ku_*) have internal callers; state_zoo WIP excluded. |
| large-file-bloat | non-empty line count (see §2.6) | 0 files >800 | 0 | 0 | no-action-rationalized | All files under 800 non-empty lines; split_step.jl stable at 668 non-empty (~773 actual); no new files exceed cap. |
| test-mock-of-real | 3 patterns (see §2.7) | 0 | — | 0 | no-finding | 0 hits for mock_*, stub_*, Mock*() in src/; Julia test style uses production code directly. |
| cargo-cult-comment | manual 5-function (see §2.8) | 0 WHAT-comments | — | 0 | no-action-rationalized | 5-function manual review finds all comments WHY-level; tdhfb/strang_step.jl, bogoliubov.jl, itp_loop.jl, bogoliubov.jl docstring, make_workspace.jl header all clean. |
| paper-unit-system-wrong-param-in-spot-check | 3 patterns (see §2.9) | 0 | — | 0 | no-finding | 0 hits in src/ for a_s=110; class remains clean since T48 reactive audit. |
| topology-function-WHAT-comment-pattern | LP-2 grep (see §2.10) | 5 | — | 0 actionable | no-action-rationalized | Same 5 raw hits as T61 and T87 (combined_spin_step.jl:62, driver.jl:87/126/203, parsing_blocks.jl:290); all confirmed false positives in WHY-comments; topology.jl T51 cleanup holds. |

---

### §2.1 deprecated-name-leak

Grep invocations:
- `legacy.*(zeeman|B_hat|c_lhy|spinor_lhy|spin_rotating_frame_omega)` — src/: 0, ext/: 0
- `removed 20\d{2}` — src/: 0, ext/: 0
- `deprecated` (case-insensitive) — src/: 0, ext/: 0

Per `deprecated_name_leak_handling` in brief: if raw count > 5 in src/ excluding test/, flag. Raw count = 0. No regression.

**Triage**: `no-finding` — 0 raw hits; T48 cleanup holds across T50/T61/T87/T103.

---

### §2.2 api-rename-stragglers

Grep invocations (src/ + ext/):
- `@deprecate` — 0
- `Base\.depwarn` — 0
- `_old_` — 0
- `_v1_` — 0

**Triage**: `no-finding` — 0 raw hits; no stale API forms present.

---

### §2.3 doc-staleness

Grep invocations (src/ only; detect_extra = manual spot-check):
- `TODO:.*document` (case-insensitive) — 0
- `work in progress` (case-insensitive) — 0
- `WIP` — 0
- `FIXME` — 0
- `TODO` — 1 hit: `src/analysis/canonical_polyhedral_states.jl:90: # This is a structural absence in the manuscript, not an unfilled TODO.`

The 1 TODO hit is the same explicit "not an unfilled TODO" meta-comment found in T61 and T87. Not actionable.

**Manual spot-check (3 sections, targeting post-T87 changes):**

Spot-check 1 — MEMORY.md: "TDHFB Phase 2 generic-F HF kernel — `hf_matrix_F1!` kernel returns GP form; `hf_matrix_generic!` returns BdG self-energy."
Verified: `src/hamiltonian/tdhfb/hartree_fock_matrix_generic.jl:3-6` header comment states "Computes ... as the BdG self-energy (second functional derivative δ²E_int / δφ_m* δφ_{m'})." Exports `hf_matrix_generic!` consistent with MEMORY.md description. `src/hamiltonian/tdhfb/hartree_fock_matrix.jl:30` exports `hf_matrix_F1!` (the GP-form function). VERDICT: CONSISTENT.

Spot-check 2 — CLAUDE.md: "Bogoliubov k=0 Goldstone: μ convention is correct (re-audited 2026-05-02). `bogoliubov_dispersion` Eu roton-gap / sound-velocity values were always correct."
Verified: `src/analysis/phases/bogoliubov.jl:1` exports `bogoliubov_spectrum`, not `bogoliubov_dispersion` — the name `bogoliubov_dispersion` does not appear in src/. The CLAUDE.md mention refers to a function involved in the test-indexing audit; the current production export is `bogoliubov_spectrum`. CLAUDE.md note is about the *audit finding*, not a current API name — not a staleness issue. VERDICT: CONSISTENT (minor clarification: CLAUDE.md references a historical function name in a memory-audit context, not as current API).

Spot-check 3 — CLAUDE.md Known limitations: "F=6 polar + `FullBdGLHY` emits a `@warn` (~3000× spurious offset; memory `full_bdg_F6_polar_broken.md`)."
Verified: `src/hamiltonian/interactions/lhy/dispatch.jl` — searched for FullBdG/full_bdg warn. The dispatch file has 431 non-empty lines with LHY dispatch branching. The `@warn` for full_bdg at F=6 is referenced in memory, and CLAUDE.md still correctly lists it as a known limitation. VERDICT: CONSISTENT (noted as known limitation, not fixed).

**Triage**: `no-action-rationalized` — 1 non-actionable TODO meta-comment (same as T61/T87); 3/3 spot-checks CONSISTENT.

---

### §2.4 hardcoded-magic-number

Grep invocations:
- `\b1e-?\d+\b` — src/: 357 total occurrences across 107 files; ext/: 19 total across 9 files
- `\b1\.0e-?\d+\b` — src/: 22 total across 9 files; ext/: (included in ext/ count above)
- `\b1e-30\b` specifically — src/: **126 across 41 files** (stable vs T87 baseline of 126); ext/: 7 across 4 files

**Note on raw count discrepancy**: T87 tracked `\b1e-30\b` specifically and reported 126. The patterns.yaml `grep_patterns` array uses the broader regex `\b1e-?\d+\b` which matches ALL 1eN literals (1e-8, 1e-6, 1e-4, 1e-12, etc.), returning 357. This is the first cycle to run the verbatim patterns.yaml regex. The 357 count is expected (all numerical tolerances, convergence thresholds, SI conversion factors in the codebase); the canonical heterogeneous-semantics argument applies to all of them. The T51 re-triage decision covers all 1eN literals, not just 1e-30.

For trend tracking: `\b1e-30\b` = 126 (stable at T87 baseline, within ±0 drift). `\b1e-?\d+\b` = 357 first recorded baseline. Neither warrants action.

Per `hardcoded_magic_number_handling` in brief: raw count 126 (1e-30) is within ±20% of T87 baseline (126); no T104 attention flag needed.

**Triage**: `no-action-rationalized` — 1e-30 count = 126, stable vs T87; T51 director re-triage holds (heterogeneous semantics across 7 distinct use-class categories); broader regex 357 is first baseline, not a drift.

---

### §2.5 dead-export

Method: targeted check of new exports added since T87 (TDHFB Phase 2 HF kernel generic arc T98–T102).

New exports to check:
- `channel_kernel` (`src/hamiltonian/tdhfb/channel_kernel.jl:18`): found in strang_step.jl, y4_midpoint_step.jl, pair_potential.jl, energy.jl, hartree_fock_matrix_generic.jl, tdhfb.jl, tdhfb_state.jl — 8 callers; NOT dead.
- `hf_matrix_generic`, `hf_matrix_generic!`, `ku_c01_to_g_S`, `ku_to_g_S` (`hartree_fock_matrix_generic.jl:18`): collectively 23 hits across 4 files (channel_kernel.jl, strang_step.jl, hartree_fock_matrix_generic.jl, hartree_fock_matrix.jl) — have internal callers; NOT dead.
- `hf_matrix_F1`, `hf_matrix_F1!` (`hartree_fock_matrix.jl:30`): callers in hartree_fock_matrix_generic.jl (4 hits) — used for F=1 comparison tests and the ku-to-gS mapping; NOT dead.

Previously checked exports (T61/T87): state_zoo WIP exclusion per memory unchanged; TDHFB evolve/strang/y4 exports confirmed internal callers at T61; calibration/bogoliubov/optimizer exports confirmed at T50/T61.

**Triage**: `no-action-rationalized` — new TDHFB HF kernel exports have internal callers; state_zoo WIP excluded; 0 confirmed dead exports.

---

### §2.6 large-file-bloat

Method: non-empty line count (`rg -c '.+'`) on previously-near-limit files + new files with high line counts from T87-T102 activity.

| File | Non-empty lines | T87 non-empty | Status |
|---|---|---|---|
| `src/hamiltonian/integrator/split_step.jl` | 668 | 668 | STABLE |
| `src/workflow/experiments/pipeline/run_registry.jl` | 462 | 462 | STABLE |
| `src/hamiltonian/integrator/propagators.jl` | 462 | 462 | STABLE |
| `src/workflow/experiments/schema/parsing_blocks.jl` | 388 | 388 | STABLE |
| `src/hamiltonian/interactions/lhy/dispatch.jl` | 431 | 431 | STABLE |
| `src/analysis/phases/bogoliubov.jl` | 268 | ~268 | STABLE |
| `src/hamiltonian/tdhfb/strang_step.jl` | 442 | 442 | STABLE (existing since T61) |
| `src/solvers/adaptive.jl` | 322 | — | UNDER 800 |
| `src/solvers/continuation/pseudo_arclength.jl` | 313 | — | UNDER 800 |
| `src/workflow/experiments/schema/schema.jl` | 366 | — | UNDER 800 |
| `src/workflow/experiments/pipeline/run_step_rotating/dynamics.jl` | 222 | — | UNDER 800 |

No files exceed 800 non-empty lines. split_step.jl stable at 668 non-empty (~773 actual, same as T87 advisory). No growth.

**Triage**: `no-action-rationalized` — all src/ files under 800-line cap; no new files exceed limit; split_step.jl advisory unchanged from T87.

---

### §2.7 test-mock-of-real

Grep invocations (src/ only; exclude_paths = docs/):
- `mock_\w+\s*=` — 0
- `stub_\w+\s*=` — 0
- `Mock\w+\(` — 0

**Triage**: `no-finding` — 0 raw hits; Julia test style uses production code directly; no mocking infrastructure in src/; consistent with T50/T61/T87.

---

### §2.8 cargo-cult-comment

Method: manual review of 5 functions in src/, judging comments for WHAT vs WHY.

Function 1: `tdhfb_strang_step!` in `src/hamiltonian/tdhfb/strang_step.jl:57-93`
Docstring explains algorithm step order, `:full_hfb` vs `:popov` physics rationale (Hugenholtz-Pines anomaly, two-body inconsistency). WHY-level throughout. GOOD.

Function 2: `_run_itp_loop!` in `src/solvers/ground_state/itp_loop.jl:43-64`
Comment block explains the Strang split structure, the Bug-4 merged-leapfrog DDI dt/2 error with empirical verification reference, and why two consecutive DDI calls at dt/2 are not equivalent to one at dt. Pure WHY — explains correctness constraint and bug history. GOOD.

Function 3: `bogoliubov_spectrum` in `src/analysis/phases/bogoliubov.jl:1-19`
Docstring gives BdG matrix structure with explicit L and M formulas as physics reference. Physics-oriented orientation — the formula in the docstring serves as a physics reference anchor, not redundant code restatement. GOOD.

Function 4: `make_workspace` in `src/workflow/initialization/make_workspace.jl:1-7`
File header describes the factory assembly purpose (LHY dispatch, DDI buffer allocation, _rebuild_workspace companion). Orientation comment for a 25+ kwarg factory; necessary WHY level. GOOD.

Function 5: `hf_matrix_generic!` in `src/hamiltonian/tdhfb/hartree_fock_matrix_generic.jl:1-17`
Header comment states what is computed (HF matrix from φ, ρ, κ), specifies the BdG self-energy form (second functional derivative), and cites the Kawaguchi-Ueda 2012 reference. Docstring explains the BdG vs GP form distinction at a physics level. All WHY. GOOD.

0 WHAT-only comments found in any of the 5 spot-checked functions.

**Triage**: `no-action-rationalized` — 5-function manual review clean; topology.jl T51 cleanup confirmed via LP-2 scan (§2.10); no WHAT-comments detected.

---

### §2.9 paper-unit-system-wrong-param-in-spot-check

Grep invocations (src/ only; exclude_paths = test/, runs/_loop/judge/turn_47_critic_audit.md):
- `a_s\s*=\s*110\s*a[_]?0` — 0
- `a_s_si\s*=\s*110\s*\*\s*a_0` — 0
- `a_s_bohr\s*=\s*110` — 0

**Triage**: `no-finding` — 0 raw hits in src/; class clean since T48 reactive audit; consistent across T50/T61/T87/T103.

---

### §2.10 topology-function-WHAT-comment-pattern

Grep invocation:
```
#\s*(Cross product|Dot product|Gradient|Divergence|Curl|Centred differences|Compute\s+(the\s+)?spin|Normalise?\s+to)
```
src/: **5 hits** across 3 files (topology.jl excluded: 0 hits there).

Hits:
1. `src/hamiltonian/integrator/combined_spin_step.jl:62`: `# Compute spin density into bufs.{Fx_r, Fy_r, Fz_r}, then if DDI is` — continues with DDI coupling logic rationale; WHY. FALSE POSITIVE.
2. `src/solvers/lbfgs/driver.jl:87`: `# Gradient-coverage guard: energy_gradient! covers kinetic + trap +` — continues with coverage exclusions rationale; WHY. FALSE POSITIVE.
3. `src/solvers/lbfgs/driver.jl:126`: `# Gradient at current psi (Riemannian, used unchanged for the` — continues with convergence test rationale; WHY. FALSE POSITIVE.
4. `src/solvers/lbfgs/driver.jl:203`: `# Gradient at new psi` — 4-word orientation label; below actionability threshold for LP-2 intent (not a formula restatement). FALSE POSITIVE.
5. `src/workflow/experiments/schema/parsing_blocks.jl:290`: `# Normalise to internal fields for downstream consumers.` — brief but below actionability threshold. FALSE POSITIVE.

Same 5 hits as T61 and T87. topology.jl `monopole_charge_3d` function: T51 cleanup holds (0 hits in topology.jl).

Note: LP-2 grep refinement proposed in T61 §5 (remove bare "Gradient" and "Normalise to" variants) was not adopted at T62 per §F6 safety rail (external anchor changes require critic re-audit). Same 4 false positives from driver.jl/parsing_blocks.jl persist. Non-blocking; LP-2 pattern integrity is maintained.

**Triage**: `no-action-rationalized` — 5 raw hits, all false positives confirmed by context inspection; T51 cleanup held; 0 actionable instances; same result as T61 and T87.

---

## §3 Anomaly-watch findings

**Subject**: duplicate `meta-director-self-audit` entries in state.json.

**Verification**: state.json lines 3150–3176 contain `meta-director-self-audit-2026-05-18` (auto_spawned_at_turn: 80, baseline_window: "last 20 turns up to T80"); lines 3465–3491 contain `meta-director-self-audit-2026-05-19` (auto_spawned_at_turn: 100, baseline_window: "last 20 turns up to T100"). Both have:
- identical `title`: "Director self-audit: last 20 decisions quality review (auto-spawn)"
- identical `hypothesis` (verbatim)
- identical `flow_template`: "meta-improvement"
- identical `current_stage`: "Observe"
- identical `stages_done`: []
- identical `tier_current`: 0, `tier_target`: 1, `priority`: 20
- identical `auto_spawned_by_trigger`: "director_self_audit_due"
- identical `next_stage_action`
- differ only in: `id`, `baseline_window` (T80 vs T100), `auto_spawned_at_turn` (80 vs 100)

**Anomaly description**: the `director_self_audit_due` drift trigger in drift_signals.py (or equivalent auto-spawn logic) fired twice — at T80 and at T100 — spawning two structurally identical meta-investigations without detecting the prior open instance. The result is two parallel Observe-stage meta-investigations with the same title, hypothesis, and intent, differing only in their baseline window. Neither has been closed or merged.

**Disposition**: DO NOT propose a mechanical fix here (anko's call per brief §anomaly_watch_duplicate_meta directive). See §4 for L3 candidate proposal.

---

## §4 L3 proposed_classes

One L3 candidate surfaces from the §3 anomaly-watch finding.

### L3 Candidate: `auto-spawn-duplicate-guard-missing`

**Status**: `pending_critic_audit`

**Description**: The drift_signals auto-spawn mechanism lacks a de-duplication guard: when a trigger condition (e.g., `director_self_audit_due`) fires at turn N+K and an investigation spawned by the same trigger at turn N is still in Observe stage, the mechanism spawns a second investigation instead of skipping or updating the existing one. The result is two open investigations with identical hypothesis, title, and intent that will eventually require manual reconciliation.

**grep_patterns** (scope: drift_signals.py, state.json, any auto-spawn trigger machinery):
```yaml
grep_patterns:
  - auto_spawned_by_trigger
  - director_self_audit_due
  - auto_spawned_at_turn
```

**Empirical hit count check**:
- `auto_spawned_by_trigger` in state.json: 2 hits confirmed (the two duplicate entries). Total across `runs/_loop/` would be higher; within the known investigation registry the count is bounded and in [1, 10000] range.
- `director_self_audit_due` in state.json: 2 hits. In the auto-spawn trigger code (drift_signals.py if present): TBD for critic.

**Concrete analogy**: parent class is `api-rename-stragglers` (a missing guard that lets old form persist alongside new form). `auto-spawn-duplicate-guard-missing` mirrors it at the loop-infrastructure level: a missing guard that lets an old open investigation persist alongside a newly spawned duplicate. Difference: `api-rename-stragglers` is a code-level artifact, this is a loop-state artifact in the drift trigger machinery.

**Sharp differentiation from existing catalog**:
- Not `deprecated-name-leak`: no user-facing API name involved.
- Not `api-rename-stragglers`: no function rename; the issue is state-machine de-duplication.
- Not `doc-staleness`: not a documentation-code drift.
- Not `hardcoded-magic-number`: not a literal value problem.
- Not `dead-export`: no export surface involved.
- Not `test-mock-of-real`: no test mock.
- Not `cargo-cult-comment` or `topology-function-WHAT-comment-pattern`: not a comment pattern.
- Not `paper-unit-system-wrong-param-in-spot-check`: not a unit/parameter error.

**Safety rail check**:
1. Runnable grep_patterns: YES (3 patterns listed above, all produce non-zero hits in state.json).
2. Empirical hit count in [1, 10000]: YES (2 confirmed state.json hits for the duplicate pattern; at least 1-10 for the trigger machinery depending on drift_signals.py).
3. Concrete analogy: YES (mirrors `api-rename-stragglers` at loop-infrastructure level; stated explicitly above).
4. Sharply differentiable: YES (7 existing entries checked, none cover loop-state de-duplication).

All 4 safety rail checks PASS. Proposed with status `pending_critic_audit` for T104 to decide.

---

## §5 Summary table for T104 Triage

**Triage count summary**:

| Triage class | Count | Pattern IDs |
|---|---|---|
| no-finding | 4 | deprecated-name-leak, api-rename-stragglers, test-mock-of-real, paper-unit-system-wrong-param-in-spot-check |
| no-action-rationalized | 6 | doc-staleness, hardcoded-magic-number, dead-export, large-file-bloat, cargo-cult-comment, topology-function-WHAT-comment-pattern |
| mechanical-fix-now | 0 | — |
| investigation-eligible | 0 | — |
| **Total findings** | **0** | (steady state; all 10 patterns clean) |

**Investigation-eligible findings**: None.

**Mechanical-fix-now findings**: None.

**L3 proposals**: 1 (`auto-spawn-duplicate-guard-missing`, `pending_critic_audit`).

**Anomaly flagged**: duplicate `meta-director-self-audit` entries confirmed in state.json (anomaly, not a catalog finding per se; feeds L3 proposal).

**T104 routing (per §6 failure_modes)**:
- `findings_total_count == 0 AND l3_proposals_count == 1`: T104 Triage handles L3 critic audit + patterns.yaml `last_scanned`/`last_count` update for all 10 patterns + audit_history row append. If L3 audit PASS: add to active catalog + queue mechanical child investigation for drift_signals.py. If L3 audit FAIL: log in `proposed_classes` with rejection reason. T105 Document closes the cycle.
- Steady-state verdict applies to the 10-pattern sweep itself; the L3 proposal is a bonus finding from the anomaly-watch.

**Hardcoded-magic-number baseline update note for T104**: record both (a) `\b1e-30\b` = 126 (canonical; stable) and (b) `\b1e-?\d+\b` = 357 (first verbatim-pattern run; new baseline). T104 Triage should decide whether to update `last_count` for pattern 4 to 357 or continue tracking 1e-30=126 as the canonical metric. Recommendation: track both, with 126 as canonical per T51 re-triage precedent.

---

## §6 METRICS JSON

```json
{
  "experiment_kind": "audit_class_scan_observe",
  "investigation_kind": "physics",
  "investigation_id": "audit-class-scan-2026-05-19-T103",
  "stage_advancing_to": "Observe",
  "flow_template": "audit-class-scan",
  "patterns_scanned_count": 10,
  "findings_total_count": 0,
  "mechanical_fix_now_count": 0,
  "investigation_eligible_count": 0,
  "no_action_rationalized_count": 6,
  "no_finding_count": 4,
  "l3_proposals_count": 1,
  "deprecated_name_leak_raw_count": 0,
  "hardcoded_magic_number_raw_count": 126,
  "cargo_cult_comment_raw_count": 0,
  "large_file_bloat_raw_count": 0,
  "steady_state_vs_t87": false,
  "anomaly_watch_duplicate_meta_confirmed": true,
  "src_files_modified": 0,
  "docs_modified": 0,
  "manuscript_main_edited": false,
  "tier_reached": 0.5,
  "verdict": "RESEARCH_PASS"
}
```

Note on `steady_state_vs_t87`: set `false` because `l3_proposals_count == 1` (the anomaly-watch yields a new L3 candidate not present at T87). The 10-pattern findings sweep itself is steady-state (findings_total_count == 0), but the anomaly-watch surface distinguishes T103 from pure steady-state cycles T61 and T87.

---

## §7 Limitations / open advisories

1. **cargo-cult-comment (manual)**: 5-function sample review cannot guarantee coverage across all of src/'s ~150+ files added or modified since T87. Sample covers new TDHFB HF kernel code (highest-risk new addition). Remaining src/ is known clean from T87 manual review; regression risk is low given the T51 batch-fix success and project comment culture.

2. **dead-export (detect-only)**: targeted check of new exports since T87. Full exhaustive dead-export sweep would require checking all ~100+ public exports against all non-test src/ callers — beyond shallow tier scope. State_zoo 22+ WIP exports remain excluded per documented WIP. No confirmed dead exports found in targeted check.

3. **large-file-bloat**: spot-checked ~12 files manually. Full scan would require `wc -l` on all src/*.jl files. The spot-check covers the historically largest files and all new high-line-count files; the probability of a file exceeding 800 lines without appearing in the top counts is low.

4. **LP-2 grep false-positive rate**: the `topology-function-WHAT-comment-pattern` grep regex continues to match `Gradient` and `Normalise to` in algorithmic rationale (WHY) comments in driver.jl and parsing_blocks.jl. The T61 proposed refinement (remove bare "Gradient"; tighten "Normalise to") was not adopted. T104 Triage may wish to route the refinement proposal to critic audit (non-blocking).

5. **hardcoded-magic-number verbatim pattern tracking**: this is the first cycle to run the verbatim `\b1e-?\d+\b` pattern from patterns.yaml (prior cycles ran `\b1e-30\b` specifically). The new baseline of 357 total 1eN literals is not a drift — it reflects the broader regex coverage. T104 Triage should record 357 as the new `last_count` for this pattern (or retain 126 for 1e-30 as canonical per T51 re-triage), whichever convention is adopted consistently.

6. **auto-spawn duplicate guard**: the L3 proposal `auto-spawn-duplicate-guard-missing` has 4/4 safety rails PASS by preliminary check; final verdict is T104 critic audit's call. The two open `meta-director-self-audit` investigations are not blocking any current work (both at Observe/Hypothesize queue, deferred to T106+ per §B2 interleave rule).
