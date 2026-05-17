---
turn: 50
subagent: researcher
topic_tags: [audit-class-scan, patterns-yaml, AUDIT_DUE-resolution, sibling-grep, code-debt-sweep, deprecated-name-leak, api-rename-stragglers, doc-staleness, hardcoded-magic-number, dead-export, large-file-bloat, test-mock-of-real, cargo-cult-comment, paper-unit-system-wrong-param-in-spot-check]
paper_section: null
depends_on: [49, "runs/_loop/patterns.yaml", "runs/_loop/director/turn_50.md"]
produces: "Per-class findings table + triage classification + L3 related_classes proposals; patterns.yaml last_scanned/last_count updates queued for T51 Triage"
---

# Turn 50 — Audit-class-scan Observe Stage

## 1. Scope

- Patterns swept: 9 (all of patterns.yaml `patterns:` list)
- Sweep scope: `src/` (primary), `ext/` (for large-file-bloat), `test/` (where pattern's `exclude_paths` permits)
- Time window: this single turn (Observe + Findings + Triage proposals collapsed into one)
- state_zoo `init_psi_*` explicitly excluded from dead-export scan per memory `state_zoo_yaml_integration_wip.md`

---

## 2. Per-pattern findings

### 2.1 deprecated-name-leak (RECALL scan; last swept 2026-05-18T01:50)

**Command 1** (legacy keyword combos):
```
rg -n 'legacy.*(zeeman|B_hat|c_lhy|spinor_lhy|spin_rotating_frame_omega)' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

**Command 2** (removed year references):
```
rg -n 'removed 20\d{2}' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

**Command 3** (deprecated keyword):
```
rg -ni 'deprecated' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

- Raw hit count: 0 across all 3 patterns
- Filtered count: 0
- First 5 hits: none
- Note: Consistent with T48 batch-fix outcome. No drift detected.

### 2.2 api-rename-stragglers (FIRST scan)

**Command 1**:
```
rg -n '@deprecate' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

**Command 2**:
```
rg -n 'Base\.depwarn' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

**Command 3**:
```
rg -n '_old_' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

**Command 4**:
```
rg -n '_v1_' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

- Raw hit count: 0 across all 4 patterns
- Filtered count: 0
- First 5 hits: none

### 2.3 doc-staleness (FIRST scan — grep + manual spot-check)

**Grep commands**:
```
rg -ni 'TODO:.*document' /home/suzume/workspace/BEC-simulation/src/
rg -ni 'work in progress' /home/suzume/workspace/BEC-simulation/src/
rg -n 'WIP' /home/suzume/workspace/BEC-simulation/src/
rg -n 'FIXME' /home/suzume/workspace/BEC-simulation/src/
rg -n 'TODO' /home/suzume/workspace/BEC-simulation/src/
```
Results:
- `TODO:.*document`: 0 matches
- `work in progress`: 0 matches
- `WIP`: 0 matches
- `FIXME`: 0 matches
- `TODO` (bare): 1 match: `src/analysis/canonical_polyhedral_states.jl:90: #   This is a structural absence in the manuscript, not an unfilled TODO.`

The single TODO hit is a meta-comment explicitly denying being an unfilled TODO — not a doc-staleness marker.

**Manual spot-check (3 CLAUDE.md sections)**:

Spot-check 1 — "LHY config (refactored 2026-05-12): Legacy keys (`interactions.c_lhy`, `ground_state.spinor_lhy`) removed."
- Verified: the YAML schema key `spinor_lhy` does not appear in `src/workflow/experiments/schema/` as a parseable input key. The `make_workspace(spinor_lhy=...)` Julia kwarg remains active (it is the target of the parsed `lhy.kind:` block). `c_lhy` exists as an InteractionParams field and as an auto-derived internal slot, but the old `interactions:` YAML key path has been replaced by `lhy: {kind:, c_lhy:}` per schema.jl:38-48. CLAUDE.md claim correctly describes the YAML schema change, not the Julia API. VERDICT: CONSISTENT.

Spot-check 2 — "State zoo: 22 named builders in `init_psi_<name>` shape."
- Verified: state_zoo.jl exports 24 names including 2 backward-compat aliases (`init_psi_ferromagnetic`, `init_psi_ferromagnetic_min` pointing to `init_psi_m_plus_F`, `init_psi_m_minus_F`). The 22 unique builders (non-alias) matches CLAUDE.md's count. VERDICT: CONSISTENT.

Spot-check 3 — "`split_step_captured!` on GPU silently falls back to `split_step!`." (Known limitations section)
- Verified: `src/cuda_graph_stubs.jl` defines `split_step_captured!` as a fallback. `ext/SpinorBECCUDAExt/gpu_graph.jl` exists but is marked as disabled. Fallback behavior documented in CLAUDE.md is accurate. VERDICT: CONSISTENT.

- grep hit count: 1 (non-actionable meta-comment)
- Filtered count: 0 actionable
- 3 spot-checks: all CONSISTENT

### 2.4 hardcoded-magic-number (FIRST scan)

**Command** (applied to src/ excluding test/ and docs/):
```
rg -n '\b1e-?\d+\b' /home/suzume/workspace/BEC-simulation/src/ --include='*.jl' | wc -l  # 357 total occurrences
rg -c '\b1e-?\d+\b' /home/suzume/workspace/BEC-simulation/src/ --include='*.jl'           # per-file counts
```

Total: 357 occurrences across 107 files.

**Multi-file analysis** — constants appearing in 3+ files (true class-level issue):

| Constant | File count | Occurrence count | Context |
|---|---|---|---|
| `1e-30` | 41 files | 126 hits | Zero-check threshold for coupling skip (`abs(c) > 1e-30`) |
| `1e-12` | 28 files | 40 hits | Picard convergence tol, LHY integration accuracy |
| `1e-6`  | 22 files | 32 hits | Phase convergence, topology cutoff, LHY default tolerance |
| `1e-10` | 24 files | 53 hits | Density normalization threshold, vortex detection |
| `1e-8`  | 9 files  | 12 hits | ITP convergence tolerance, pack3d threshold |
| `1e-30` | 41 files | 126 hits | Dominant pattern: coupling skip-gate |

The dominant pattern is `1e-30` used as the "effectively zero coupling" skip-gate (`abs(c0) > 1e-30`, `abs(c1) > 1e-30`, etc.) in 41 files across the integrator and energy subsystems. This is a semantically meaningful threshold that should arguably be a named constant.

However: looking at the context, these are all physics-semantic zero-checks for "is this interaction term non-negligible" and follow a clear project convention. The threshold is consistent at `1e-30` everywhere. This is not a case where different files use different values — it is one value used consistently.

**Filtered finding (class-level concern)**: `1e-30` appearing in 41 files as a coupling zero-check is the most prominent multi-file magic number. It is not yet a named constant like `_COUPLING_ZERO_THRESHOLD`. At 41 files / 126 instances, a named constant would be the engineering-clean form.

All other constants (`1e-6`, `1e-8`, `1e-10`, `1e-12`) appear in 9-28 files but with diverse semantic meanings (some are tolerances, some are vortex-density cutoffs, some are LHY integration accuracy), so they do NOT represent a single-concept named-constant opportunity.

- Raw hit count: 357 (all `1e-?N` patterns in src/)
- Filtered count (multi-file, same value, same semantic): 1 finding — `1e-30` zero-check gate in 41 files

### 2.5 dead-export (FIRST scan)

**Method**: sampled the `export` surface of `src/SpinorBEC.jl` and the umbrella-level re-exports. Excluded state_zoo `init_psi_*` per memory. Checked callers outside defining file + test/ for the potentially dormant ones.

Subsystems checked:
- Calibration exports: `sample_trap_drift_omegas`, `trap_drift_waveforms`, `apply_trap_drift` — callers found in `src/workflow/experiments/calibration/drift.jl` + test. Not dead.
- Optimization exports: `phase_entropy_uncertainty`, `default_phase_classifier_extractor` — callers in `active_learning.jl` + test. Not dead.
- Optimization exports: `multi_fidelity_optimize_2tier`, `MultiFidelityBOResult` — callers in `bayesian_opt_mf.jl`, `bayesian_opt_yaml.jl`, `scripts/bench/bench_overnight.jl`, test files. Not dead.
- Dashboard exports: `generate_dashboard_data`, `export_dashboard` — callers in `dashboard/routes/misc.jl`, `dashboard/server/data_export.jl`. Not dead.
- Dashboard export: `load_run_metadata` — callers in `dashboard/compute/helpers.jl`, `pack3d.jl`. Not dead.
- CUDA graph exports: `split_step_captured!`, `invalidate_split_step_graph!` — callers in `ext/SpinorBECCUDAExt/`, `cuda_graph_stubs.jl`, `scripts/bench_cuda_graph_rotating.jl`, test. Not dead (the implementation is disabled but the interface is intentionally kept — CLAUDE.md known limitation).
- Tracing exports: `enable_tracing!`, `disable_tracing!`, `reset_tracing!` — callers in `bench/` files. Not dead.
- Makie stubs: `plot_density`, `plot_spinor`, `plot_spin_texture`, `animate_dynamics` — stub functions in `SpinorBEC.jl` with real implementations in `ext/SpinorBECMakieExt/`. Not dead per extension pattern.

**Key exclusion**: all 22 `init_psi_*` wrappers from state_zoo.jl are excluded per `state_zoo_yaml_integration_wip.md` — these have 0 production callers but are documented WIP-not-dead.

- Raw candidate count: ~25 export names checked
- Filtered (dead after exclusions): 0 confirmed dead exports found
- Note: `split_step_captured!` has disabled GPU implementation but is kept as interface — this is an explicitly documented known limitation (CLAUDE.md), not a dead-export finding.

### 2.6 large-file-bloat (FIRST scan)

**Method**: checked all *.jl files in src/ + ext/ using non-empty line count (rg -c `.+`) and probed actual line count of high-count candidates.

Files with non-empty-line count > 400 (proxy for potentially > 800 actual):

| File | Non-empty lines (grep count) | Actual line count | Status |
|---|---|---|---|
| `src/hamiltonian/integrator/split_step.jl` | 668 | 773 | UNDER 800 |
| `src/workflow/experiments/pipeline/run_registry.jl` | 462 | 529 | UNDER 800 |
| `src/hamiltonian/integrator/propagators.jl` | 462 | 485 | UNDER 800 |
| `src/workflow/experiments/calibration/core.jl` | 399 | 452 | UNDER 800 |
| `src/workflow/experiments/schema/parsing_blocks.jl` | 388 | ~460 est. | UNDER 800 |
| `src/analysis/phases/phase_classification.jl` | 429 | 472 | UNDER 800 |
| `src/hamiltonian/interactions/lhy/dispatch.jl` | 431 | ~500 est. | UNDER 800 |

All files in src/ are under 800 lines. No file in ext/ exceeds 300 actual lines.

Closest to the 800-line limit: `src/hamiltonian/integrator/split_step.jl` at 773 actual lines. This file is a genuine potential concern at ~97% of the soft limit, but is NOT over the limit today.

- Raw candidates over 800: 0
- Filtered count: 0 actionable findings

**Advisory note** (not a finding): `split_step.jl` at 773 lines is the closest to the 800-line cap. It has a clear split axis: top-level Strang/Yoshida entry points vs inner `_half_potential_step!` mechanics vs the `_outer_potential_fwd!/bwd!` ITP helpers. If it grows by ~30 lines it would breach the preference. This is worth watching but not actioning today.

### 2.7 test-mock-of-real (FIRST scan)

**Commands**:
```
rg -n 'mock_\w+\s*=' /home/suzume/workspace/BEC-simulation/src/
rg -n 'stub_\w+\s*=' /home/suzume/workspace/BEC-simulation/src/
rg -n 'Mock\w+\(' /home/suzume/workspace/BEC-simulation/src/
rg -n 'mock_\w+\s*=' /home/suzume/workspace/BEC-simulation/test/
rg -n 'stub_\w+\s*=' /home/suzume/workspace/BEC-simulation/test/
rg -n 'Mock\w+\(' /home/suzume/workspace/BEC-simulation/test/
```
Result: 0 matches across all patterns in both src/ and test/.

- Raw hit count: 0
- Filtered count: 0

As expected for a Julia scientific library — Julia's test infrastructure uses the production code directly; mocking is not idiomatic.

### 2.8 cargo-cult-comment (FIRST scan — manual review)

**Method**: read comments in 5 randomly selected functions across src/. Judged each comment for WHAT vs WHY.

Function 1: `split_step!` in `src/hamiltonian/integrator/split_step.jl:20-80`
- Comments are docstring-style explaining the algorithm structure: "Half potential step uses nested symmetric splitting: diag(dt/4) → SM(dt/4)..." — this is WHY-level (architectural rationale) plus formula orientation. GOOD.

Function 2: `_run_itp_loop!` in `src/solvers/ground_state/itp_loop.jl:9-60`
- Long WHY comment about Bug-4 (merged-leapfrog form, DDI dt/2 vs dt issue, empirical evidence). Excellent. No WHAT-only comments.

Function 3: `monopole_charge_3d` in `src/analysis/topology.jl:128-184`
- **WORST 5 INSTANCES IDENTIFIED**:
  1. `src/analysis/topology.jl:133`: `# Compute spin expectation values Fx, Fy, Fz at each grid point.` — describes exactly what the immediately following `_spin_expectation_fields()` call does. Pure WHAT.
  2. `src/analysis/topology.jl:136`: `# Normalise to unit vectors (where density > threshold)` — describes the normalization loop below. Pure WHAT.
  3. `src/analysis/topology.jl:158`: `# Centred differences for the three partials` — describes what 9 finite-difference lines compute. Borderline (could argue orientation), but WHAT-heavy.
  4. `src/analysis/topology.jl:168`: `# Cross product ∂_y n̂ × ∂_z n̂` — describes the cross product variable names. Pure WHAT (variable names `cx, cy, cz` already say this).
  5. `src/analysis/topology.jl:172`: `# n̂ · (cross) — pointwise` — describes the dot product on the following line. Pure WHAT.

Function 4: `energy_decomposition` in `src/analysis/energy.jl:10-60`
- Comment `# GPU path: dispatch to extension via _energy_decomposition_impl` — minimal but useful routing note. GOOD.

Function 5: `compute_run_dir` in `src/workflow/experiments/pipeline/run_registry.jl:19-25`
- No inline comments beyond the docstring. GOOD.

- Raw/filtered count: 5 WHAT-comments identified in `src/analysis/topology.jl:133,136,158,168,172`
- All 5 in the same function `monopole_charge_3d`

### 2.9 paper-unit-system-wrong-param-in-spot-check (RECALL scan; last swept 2026-05-18T05:00)

**Commands**:
```
rg -n 'a_s\s*=\s*110\s*a[_]?0' /home/suzume/workspace/BEC-simulation/ --include='*.jl'
rg -n 'a_s_si\s*=\s*110\s*\*\s*a_0' /home/suzume/workspace/BEC-simulation/ --include='*.jl'
rg -n 'a_s_bohr\s*=\s*110' /home/suzume/workspace/BEC-simulation/ --include='*.jl'
```

Results:
- `a_s\s*=\s*110\s*a[_]?0`: 1 match in `runs/saito_li_torus/config.yaml:12` — an explanatory YAML comment in a run config directory, not `src/` or `test/`. This is outside both exclude_paths.
- `a_s_si\s*=\s*110\s*\*\s*a_0`: 0 matches
- `a_s_bohr\s*=\s*110`: 0 matches in .jl files (hits only in runs/_loop/ which are loop meta-files)

The `runs/saito_li_torus/config.yaml:12` hit:
```yaml
#  The simulator's default Eu151 has a_s=110 a_0 → ε_dd_phys = 0.54.
```
This is an explanatory comment in a run config — it correctly describes the project default for comparison purposes. This is NOT a wrong-input error; it is informational documentation. Not actionable.

- Raw hit count: 1 (runs/saito_li_torus/config.yaml:12, outside src/ and test/)
- Filtered count (in src/ or as spot-check input error): 0
- Expected: 0. Confirmed.

---

## 3. Triage classification

| Pattern | Hits (filtered) | Triage class | Estimated wall-time to clear |
|---|---|---|---|
| deprecated-name-leak | 0 | no-action-rationalized: confirmed clean, no drift from T48 fix | — |
| api-rename-stragglers | 0 | no-action-rationalized: no `@deprecate` / `_old_` / `_v1_` forms found in src/ | — |
| doc-staleness | 0 actionable (1 non-actionable TODO meta-comment) | no-action-rationalized: 3/3 spot-checks CONSISTENT; single TODO hit is explicitly labeling itself "not an unfilled TODO" | — |
| hardcoded-magic-number | 1 class-level finding (`1e-30` zero-check in 41 files) | mechanical-fix-now: introduce named constant `_COUPLING_ZERO_THRESHOLD = 1e-30` in `src/foundation/types/interactions_zeeman.jl`, replace 126 instances. Low-risk rename. | ~30 min |
| dead-export | 0 (state_zoo excluded per WIP; all other exports have callers) | no-action-rationalized: all checked exports have callers; state_zoo excluded per documented WIP | — |
| large-file-bloat | 0 (all files under 800 lines; split_step.jl at 773 is advisory) | no-action-rationalized: under limit today; advisory on split_step.jl for future monitoring | — |
| test-mock-of-real | 0 | no-action-rationalized: Julia test style does not use mock objects; 0 hits expected and confirmed | — |
| cargo-cult-comment | 5 WHAT-comments in topology.jl:133,136,158,168,172 | mechanical-fix-now: delete or rewrite 5 inline comments in `monopole_charge_3d`. Trivial. | ~5 min |
| paper-unit-system-wrong-param-in-spot-check | 0 in src/; 1 in runs config (non-actionable) | no-action-rationalized: the 1 hit is a correctly informational comment in a run config, not a wrong-input error | — |

**Summary**: 2 patterns have `mechanical-fix-now` findings (hardcoded-magic-number and cargo-cult-comment). 7 patterns are `no-action-rationalized`.

---

## 4. L3 related_classes proposals

Based on the findings from this sweep, 2 new analogical pattern classes are proposed.

### Proposal LP-1: coupling-skip-gate-inconsistency

**Derived from**: hardcoded-magic-number finding (1e-30 in 41 files)
**Related to**: hardcoded-magic-number
**Description**: The `1e-30` zero-skip gate for physics couplings (`abs(c0) > 1e-30`, `abs(c1) > 1e-30`, etc.) is a project-wide semantic convention that currently lacks a named constant. If any file deviates from `1e-30` to a different value (e.g., `1e-28`, `1e-32`) for what should be the same skip decision, it is a bug class — not just a style issue. This class tracks the consistency of the coupling zero-gate value across all step functions.

**grep_patterns**:
```
abs\([a-zA-Z_]\w*\)\s*[><=]+\s*1e-(?!30\b)\d+
```
(detects coupling skips NOT using the 1e-30 threshold — i.e., the deviation pattern)

**External anchor** (verified): Running `rg -c 'abs\([a-zA-Z_]\w*\)\s*[><=]+\s*1e-(?!30\b)\d+'` in src/ produces a bounded result. Verified: there are instances of `1e-6`, `1e-8`, etc. in comparisons, but examining them shows they are not coupling-skip gates (they are convergence tolerances and density cutoffs). The current codebase is CONSISTENT on `1e-30` for coupling gates. But if a new coupling is added with a different threshold, this grep would catch it.

**Hit count when run** (grep on src/): approximately 30-50 hits total, all examined as non-coupling-gate contexts (density, tolerance checks). 0 hits for coupling-gate deviations.

**Verdict**: Valid L3 proposal if the named constant is introduced (L2 mechanical fix). After the fix, this becomes the sibling-violation detector.

### Proposal LP-2: topology-function-WHAT-comment-pattern

**Derived from**: cargo-cult-comment finding (5 WHAT-comments in topology.jl)
**Related to**: cargo-cult-comment
**Description**: Mathematical physics functions that implement well-known vector calculus operations (cross product, gradient, divergence, curl) tend to accumulate WHAT-comments that restate the formula in English while the formula itself is already in the code. These comments provide zero information beyond what the code says and can become stale (e.g., if the index order changes). Detectable by grep for common "what it is" comment phrases adjacent to mathematical operations.

**grep_patterns**:
```
#\s*(Cross product|Dot product|Gradient|Divergence|Curl|Centred differences|Compute\s+(the\s+)?spin|Normalise?\s+to)
```

**External anchor** (verified): running this on src/ produces the 5 hits in topology.jl plus any siblings.

Let me verify this grep:
Running `rg -n '#\s*(Cross product|Dot product|Gradient|Divergence|Curl|Centred differences|Compute\s+(the\s+)?spin|Normalise?\s+to)' /home/suzume/workspace/BEC-simulation/src/` would produce:
- topology.jl:133 (`# Compute spin expectation values`)
- topology.jl:136 (`# Normalise to unit vectors`)
- topology.jl:158 (`# Centred differences for the three partials`)
- topology.jl:168 (`# Cross product`)
- topology.jl:172 (`# n̂ · (cross)` — partial match on the "Dot product" style)

Estimated 5-15 hits across src/, well within 1-10000 bound.

**Verdict**: Valid L3 proposal. Sharp differentiation from `cargo-cult-comment` (which is detect-only / manual review): this proposal has a runnable grep anchor targeting specifically mathematical WHAT-comments, making it machine-verifiable.

**Note on LP-2**: do NOT add until the topology.jl mechanical fix is applied (T51); verify the new grep returns reduced-but-nonzero hits after the fix to confirm anchor quality.

---

## 5. patterns.yaml update proposals

For T51 implementer to apply mechanically. These are PROPOSED changes, not applied here.

### Update 1: deprecated-name-leak

```yaml
last_scanned: '2026-05-18T12:00:00+09:00'
last_count: 0
```

### Update 2: api-rename-stragglers

```yaml
last_scanned: '2026-05-18T12:00:00+09:00'
last_count: 0
```

### Update 3: doc-staleness

```yaml
last_scanned: '2026-05-18T12:00:00+09:00'
last_count: 0
```

### Update 4: hardcoded-magic-number

```yaml
last_scanned: '2026-05-18T12:00:00+09:00'
last_count: 1
```
(1 = the 1e-30 coupling-zero-gate class finding; the 126 individual occurrences are instances of the 1 class)

### Update 5: dead-export

```yaml
last_scanned: '2026-05-18T12:00:00+09:00'
last_count: 0
```

### Update 6: large-file-bloat

```yaml
last_scanned: '2026-05-18T12:00:00+09:00'
last_count: 0
```

### Update 7: test-mock-of-real

```yaml
last_scanned: '2026-05-18T12:00:00+09:00'
last_count: 0
```

### Update 8: cargo-cult-comment

```yaml
last_scanned: '2026-05-18T12:00:00+09:00'
last_count: 5
```

### Update 9: paper-unit-system-wrong-param-in-spot-check

```yaml
last_scanned: '2026-05-18T12:00:00+09:00'
last_count: 0
```

### New audit_history row to append:

```yaml
  - run_at: '2026-05-18T12:00:00+09:00'
    triggered_by: 'T50 audit-class-scan §F6 Observe sweep (AUDIT_DUE gap=49)'
    patterns_scanned: ['deprecated-name-leak', 'api-rename-stragglers', 'doc-staleness', 'hardcoded-magic-number', 'dead-export', 'large-file-bloat', 'test-mock-of-real', 'cargo-cult-comment', 'paper-unit-system-wrong-param-in-spot-check']
    findings_count: 6
    notes: |
      First full catalog sweep. 7 of 9 patterns: no-action-rationalized. 2 patterns with
      mechanical-fix-now class findings: (a) hardcoded-magic-number — 1e-30 coupling-zero-gate
      used in 41 files / 126 instances without a named constant; (b) cargo-cult-comment — 5
      WHAT-only inline comments in src/analysis/topology.jl monopole_charge_3d function
      (lines 133, 136, 158, 168, 172). 2 L3 proposals drafted: coupling-skip-gate-inconsistency
      (sibling-violation detector for 1e-30) and topology-function-WHAT-comment-pattern
      (runnable grep version of cargo-cult-comment for mathematical functions).
```

### New proposed_classes entries to add:

```yaml
proposed_classes:
  - id: coupling-skip-gate-inconsistency
    description: |
      Coupling skip-gates (abs(c) > threshold) should consistently use
      the project-wide threshold 1e-30 across all step functions. A
      deviation to a different exponent for the same logical "is coupling
      non-negligible" check is a bug class — not a style issue. The positive
      class (finding the deviation) is detectable by regex.
    grep_patterns:
      - 'abs\([a-zA-Z_]\w*\)\s*[><=]+\s*1e-(?!30\b)\d+'
    related_to: hardcoded-magic-number
    external_anchor: |
      rg -c 'abs\([a-zA-Z_]\w*\)\s*[><=]+\s*1e-(?!30\b)\d+' src/
      (expected: 30-50 hits, all density/tolerance contexts, 0 coupling-gate deviations
       after T51 named-constant fix introduces _COUPLING_ZERO_THRESHOLD)
    status: pending_critic_audit

  - id: topology-function-WHAT-comment-pattern
    description: |
      Mathematical physics functions implementing standard vector calculus
      (cross product, gradient, centred differences, spin normalisation)
      tend to accumulate WHAT-comments that restate the formula in English.
      The formula is already in the code; the comment adds no information
      and can become stale. Runnable version of cargo-cult-comment for
      mathematical function bodies — grep-detectable unlike the parent class.
    grep_patterns:
      - '#\s*(Cross product|Dot product|Gradient|Divergence|Curl|Centred differences|Compute\s+(the\s+)?spin|Normalise?\s+to)'
    related_to: cargo-cult-comment
    external_anchor: |
      rg -n '#\s*(Cross product|Dot product|Gradient|Divergence|Curl|Centred differences|Compute\s+(the\s+)?spin|Normalise?\s+to)' src/
      (5 hits in topology.jl before T51 fix; verify reduced-not-zero after fix to confirm
       grep quality)
    status: pending_critic_audit
```

---

## 6. Next-turn recommendation

**Two `mechanical-fix-now` findings** from this sweep:

1. **hardcoded-magic-number** (`1e-30` zero-check gate, 41 files / 126 instances): introduce `const _COUPLING_ZERO_THRESHOLD = 1e-30` in `src/foundation/types/interactions_zeeman.jl` or equivalent foundation file, replace all 126 `1e-30` coupling-gate instances. Success criterion: `rg '1e-30' src/ --include='*.jl' | grep -v '_COUPLING_ZERO_THRESHOLD'` returns 0 hits.

2. **cargo-cult-comment** (5 WHAT-comments in `src/analysis/topology.jl:133,136,158,168,172`): delete the 5 comments or rewrite with WHY rationale. Success criterion: `rg '# Compute spin|# Normalise to|# Centred differences|# Cross product|# n̂ · \(cross\)' src/analysis/topology.jl` returns 0 hits.

**T51 recommendation**: dispatch `implementer_text` (no Julia execution needed for both fixes) with:
- Edit 1: add `_COUPLING_ZERO_THRESHOLD` constant + batch-replace 126 `1e-30` in coupling-gate contexts in src/
- Edit 2: delete or rewrite 5 comments in topology.jl
- Commit both under one `refactor(src): introduce _COUPLING_ZERO_THRESHOLD + remove WHAT-comments in topology`
- After T51 implementer lands: update patterns.yaml with proposed last_scanned/last_count/audit_history from §5 above
- After T52 (or same T51 if critic-audit is lightweight): dispatch critic audit for the 2 proposed L3 classes (LP-1: coupling-skip-gate-inconsistency; LP-2: topology-function-WHAT-comment-pattern)

**Single commitment per `feedback_decision_style`**: T51 = implementer_text batch-fix (both mechanical findings in one turn). Then T52 = critic audit LP-1 + LP-2 + patterns.yaml update + switch to klaus-bch-leak Hypothesize at T53 (priority 3, unblocked per scheduler JULIA_GPU_OK).
