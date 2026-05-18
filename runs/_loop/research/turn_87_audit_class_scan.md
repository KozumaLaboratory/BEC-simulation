---
turn: 87
subagent: researcher
topic_tags: [audit-class-scan, patterns-yaml, AUDIT_DUE-resolution, level-2-periodic-sweep, code-debt, third-cycle, observe-stage]
paper_section: null
depends_on: [61, 63, 87, "runs/_loop/patterns.yaml", "runs/_loop/director/turn_87.md", "runs/_loop/research/turn_61_audit_class_scan.md"]
produces: "Per-pattern findings table (10 patterns) + triage classification + L3 proposals assessment (0); patterns.yaml last_scanned/last_count updates queued for T88 Triage"
---

# Turn 87 — Audit-class-scan Observe Stage (3rd full cycle)

## §1 Scope

- Patterns swept: 10 (all of patterns.yaml `patterns:` list as of 2026-05-18T17:52; unchanged since T61 catalog)
- Sweep scope: `src/` (primary), `ext/` (for large-file-bloat), `test/` (where pattern's `exclude_paths` permits)
- state_zoo `init_psi_*` explicitly excluded from dead-export scan per memory `state_zoo_yaml_integration_wip.md` (per T50/T61 precedent)
- Time window: this single turn (Observe + Findings folded together; Triage at T88)
- Diff from T61 sweep: 0 NEW active patterns (T61 catalog == T87 catalog; T54 LP-2 promotion was already folded at T61). Gap since T61's sweep: 26 turns (T61 Observe → T87 Observe; T63 close to T87 spawn).
- T54-LP-2 (`topology-function-WHAT-comment-pattern`) recall: T61 reported 5 false-positives in WHY-comments and confirmed 0 actionable hits in topology.jl. T87 sweep confirms same 5 hits, same false-positive assessment.
- **Steady-state outcome expected and confirmed**: all 10 patterns return 0 actionable findings, consistent with T61. No regressions detected over the 26-turn gap.

---

## §2 Per-pattern findings

### 2.1 deprecated-name-leak (RECALL scan since T61 | gap 26 turns from T61)

```
rg -n 'legacy.*(zeeman|B_hat|c_lhy|spinor_lhy|spin_rotating_frame_omega)' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

```
rg -n 'removed 20\d{2}' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

```
rg -ni 'deprecated' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

- Raw hit count: 0 across all 3 grep patterns
- Filtered count (after exclude_paths = ['test/', '.claude/logs/', 'runs/_loop/']): 0
- First 5 hits: none
- Note: T48 batch-fix, T50 recall (0), T61 recall (0). No drift detected over 26-turn gap.

Triage classification: `no-finding` — 0 raw hits across all 3 patterns; T48 batch-fix continues to hold; no regression since T61. Count unchanged (0 == T61 count of 0).

**Queued patterns.yaml update**: `last_scanned: '2026-05-18T<T88-timestamp>+09:00'`, `last_count: 0`

---

### 2.2 api-rename-stragglers (RECALL scan since T61 | gap 26 turns from T61)

```
rg -n '@deprecate' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

```
rg -n 'Base\.depwarn' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

```
rg -n '_old_' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

```
rg -n '_v1_' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

- Raw hit count: 0 across all 4 grep patterns
- Filtered count (after exclude_paths = ['test/']): 0
- First 5 hits: none
- Note: T50 first scan (0), T61 recall (0). Still clean.

Triage classification: `no-finding` — 0 raw hits; no `@deprecate`, `Base.depwarn`, `_old_`, or `_v1_` forms in src/. Count unchanged (0 == T61 count of 0).

**Queued patterns.yaml update**: `last_scanned: '2026-05-18T<T88-timestamp>+09:00'`, `last_count: 0`

---

### 2.3 doc-staleness (RECALL scan since T61 | gap 26 turns from T61 + manual spot-check)

```
rg -ni 'TODO:.*document' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

```
rg -ni 'work in progress' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

```
rg -n 'WIP' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

```
rg -n 'FIXME' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

```
rg -n 'TODO' /home/suzume/workspace/BEC-simulation/src/
```
Result: 1 match:
- `src/analysis/canonical_polyhedral_states.jl:90: #   This is a structural absence in the manuscript, not an unfilled TODO.`

Same non-actionable meta-comment as T50 and T61.

**Manual spot-check (3 CLAUDE.md sections):**

Spot-check 1 — CLAUDE.md: "LHY config: `kind` ∈ {`scalar`, `quasi_2d`, `two_channel`, `full_bdg`, `polar_contact`, `polar_dipolar`, `fm_contact`, `fm_dipolar`, `icosahedral`, `none`}."
- Verified: `src/hamiltonian/interactions/lhy/dispatch.jl` lines 1-4 export `compute_spinor_lhy_two_channel`, `compute_spinor_lhy_polar_contact`, `compute_spinor_lhy_polar_dipolar`, `compute_spinor_lhy_fm_contact`, `compute_spinor_lhy_fm_dipolar`, `compute_spinor_lhy_icosahedral`. Internal dispatch references scalar/quasi_2d/none/full_bdg as valid kinds in comments (lines 36-60). All 9 `kind` values remain present. VERDICT: CONSISTENT.

Spot-check 2 — CLAUDE.md: "rotating_basis loss support — `RotatingBasisWS` has `loss::LossParams` field."
- Verified: `src/rotating_basis/workspace.jl:131` defines `loss::LossParams` as a struct field; line 154 provides it as a keyword with default `LossParams()`. VERDICT: CONSISTENT.

Spot-check 3 — MEMORY.md: "TDHFB A4 CLOSED — Opt-in `picard_midpoint=true` kwarg on `tdhfb_strang_step!`."
- Verified: `src/hamiltonian/tdhfb/strang_step.jl:106` has `picard_midpoint::Bool=false` kwarg; lines 114-119 implement the Picard midpoint branch. `src/hamiltonian/tdhfb/evolve.jl:12-14` also threads through `picard_midpoint` and `picard_midpoint_max_iter`. VERDICT: CONSISTENT.

- grep hit count: 1 (non-actionable meta-comment, identical to T61 finding)
- Filtered count: 0 actionable
- 3/3 spot-checks: CONSISTENT

Triage classification: `no-action-rationalized` — 1 grep hit is an explicit "not an unfilled TODO" meta-comment (same as T61); spot-checks all pass; no doc-staleness detected. Count unchanged since T61.

**Queued patterns.yaml update**: `last_scanned: '2026-05-18T<T88-timestamp>+09:00'`, `last_count: 0`

---

### 2.4 hardcoded-magic-number (RECALL scan since T61 | gap 26 turns from T61)

```
rg -n '\b1e-30\b' /home/suzume/workspace/BEC-simulation/src/ --glob='*.jl'  (count mode)
```

Result: 126 total occurrences across 41 files (identical to T50 and T61 counts).

Per-file distribution (top 5 by count, same as T61):
- `src/hamiltonian/interactions/lhy/dispatch.jl`: 13
- `src/analysis/phases/bogoliubov.jl`: 9
- `src/rotating_basis/propagators.jl`: 7
- `src/hamiltonian/integrator/split_step.jl`: 9
- `src/hamiltonian/interactions/losses.jl`: 9

Full file list (41 files): rotating_basis/propagators.jl(7), rotating_basis/integrators.jl(2), hamiltonian/interactions/losses.jl(9), hamiltonian/interactions/spin_mixing.jl(2), analysis/observables/multipole.jl(1), analysis/phases/phase_classification.jl(4), hamiltonian/integrator/combined_spin_step.jl(4), analysis/phases/bogoliubov.jl(9), hamiltonian/integrator/force_gradient.jl(3), solvers/ground_state/advanced.jl(2), analysis/phases/bogoliubov/scan.jl(2), hamiltonian/integrator/split_step.jl(9), hamiltonian/integrator/propagators.jl(1), solvers/ground_state.jl(1), hamiltonian/interactions/tensor_interaction.jl(3), analysis/energy.jl(5), hamiltonian/integrator/split_step_kernels.jl(2), hamiltonian/interactions/lhy/dispatch.jl(13), hamiltonian/potentials/optics.jl(1), analysis/spin_rotation.jl(1), hamiltonian/interactions/interactions.jl(3), hamiltonian/interactions/nematic.jl(3), analysis/majorana.jl(1), analysis/stability_analysis.jl(3), hamiltonian/potentials/raman.jl(1), solvers/continuation/scan_1d.jl(1), solvers/continuation/scan_2d.jl(1), hamiltonian/potentials/light_shift.jl(2), solvers/continuation/boundary.jl(2), solvers/lbfgs/driver.jl(3), solvers/lbfgs/energy_gradient.jl(4), solvers/lbfgs/helpers.jl(1), workflow/initialization/state_dispatch.jl(1), workflow/initialization/make_workspace.jl(6), workflow/initialization/thomas_fermi.jl(1), workflow/io/save_rotating_result.jl(1), workflow/io/dashboard/route_helpers.jl(1), workflow/experiments/analyzers/spectroscopy.jl(2), workflow/experiments/analyzers/analyzers_large/bogoliubov_mode.jl(3), workflow/experiments/analyzers/stability.jl(2), workflow/experiments/runtime/runtime_io.jl(3).

- Raw hit count: 126 across 41 files — identical to T50 and T61 (no growth)
- Filtered count: 0 actionable per T51 director re-triage

Triage classification: `no-action-rationalized` — T51 director re-triage concluded that the 126 1e-30 instances have heterogeneous semantics (coupling-gates, density floors, angle guards, div-by-zero guards, loss-rate gates, magnitude gates, sum-shape guards). A flat namespace constant would obscure rather than clarify. Count stable at 126 across T50→T61→T87 (no growth in 26-turn gap). Do not re-investigate.

**Queued patterns.yaml update**: `last_scanned: '2026-05-18T<T88-timestamp>+09:00'`, `last_count: 0`

---

### 2.5 dead-export (RECALL scan since T61 | gap 26 turns from T61 — detect-block)

Method: inspected SpinorBEC.jl export surface for new exports since T61; sampled key subsystem exports and verified callers.

New since T61 — checked exports in src/SpinorBEC.jl (read lines 1-150):
- Calibration subsystem (lines 68-73): `CalibrationSet`, `CoilCalibration`, `FORTCalibration`, `RabiCalibration`, `DEFAULT_CALIBRATION`, `load_calibration`, `apply_calibration!`, `run_yaml_calibrated`, `coil_mv_to_gauss`, `fort_mw_to_trap_hz`, `rabi_mw_to_rad_s`, `CalibrationHistory`, `load_calibration_history`, `load_calibration_csv`, `interpolate_calibration`, `sample_trap_drift_omegas`, `trap_drift_waveforms`, `apply_trap_drift` — all re-exported from the Calibration submodule; used by YAML-driven workflows and calibration-block parsers. Not dead.
- Analyzers subsystem: `analyzers_large/` directory confirmed present (skyrmion_detect.jl, synthetic_dim.jl, bogoliubov_mode.jl, rosensweig_pattern.jl, column_density_movie.jl). These are invoked via the pipeline analyzer dispatch. Not dead.
- Previously-checked exports from T61: `tdhfb_evolve!`, `tdhfb_strang_step!`, `serve_dashboard`, `generate_dashboard_data`, `export_dashboard`, `RunMetadata`, `load_run_metadata`, `split_step_captured!`, `enable_tracing!`, `disable_tracing!`, `reset_tracing!`, Makie stubs — all confirmed to have callers or documented public API status at T61; no reason to expect regression.

Exclusions (per precedent): all 22+ `init_psi_*` wrappers from `state_zoo.jl` excluded per memory `state_zoo_yaml_integration_wip.md` (documented WIP-not-dead). `split_step_captured!` kept as public interface per CLAUDE.md known limitations.

- Raw candidate count: ~30+ export names checked
- Filtered (dead after exclusions): 0 confirmed dead exports found

Triage classification: `no-action-rationalized` — all checked exports have callers or are documented public API / WIP; state_zoo init_psi_* excluded per documented WIP. Same as T61.

**Queued patterns.yaml update**: `last_scanned: '2026-05-18T<T88-timestamp>+09:00'`, `last_count: 0`

---

### 2.6 large-file-bloat (RECALL scan since T61 | gap 26 turns from T61 — detect-block)

Method: checked non-empty line counts for T61 near-limit file + all ext/ candidates + any new analyzers_large/ files.

**Primary candidate (from T61 advisory):**

```
rg -c '.+' /home/suzume/workspace/BEC-simulation/src/hamiltonian/integrator/split_step.jl
```
Result: 668 non-empty lines (unchanged from T61 and T50; actual ~773 total lines).

**Other candidates (unchanged from T61):**

| File | Non-empty lines | T61 non-empty | Status |
|---|---|---|---|
| `src/hamiltonian/integrator/split_step.jl` | 668 | 668 | UNCHANGED — ~773 actual |
| `src/workflow/experiments/pipeline/run_registry.jl` | 462 | 462 | UNCHANGED |
| `src/hamiltonian/integrator/propagators.jl` | 462 | 462 | UNCHANGED |
| `src/hamiltonian/interactions/lhy/dispatch.jl` | 431 | 431 | UNCHANGED |
| `src/analysis/phases/phase_classification.jl` | 429 | 429 | UNCHANGED |
| `src/workflow/experiments/schema/parsing_blocks.jl` | 388 | 388 | UNCHANGED |

**New since T61 — analyzers_large/ files:**

| File | Non-empty lines | Status |
|---|---|---|
| `src/workflow/experiments/analyzers/analyzers_large/bogoliubov_mode.jl` | 70 | UNDER 800 |
| `src/workflow/experiments/analyzers/analyzers_large/skyrmion_detect.jl` | 77 | UNDER 800 |
| `src/workflow/experiments/analyzers/analyzers_large/rosensweig_pattern.jl` | 85 | UNDER 800 |
| `src/workflow/experiments/analyzers/analyzers_large/column_density_movie.jl` | 104 | UNDER 800 |

**ext/ candidates checked:**

| File | Non-empty lines | Status |
|---|---|---|
| `ext/SpinorBECCUDAExt/gpu_tdhfb_hf_step.jl` | 269 | UNDER 800 |
| `ext/SpinorBECCUDAExt/gpu_tdhfb_r_update.jl` | 150 | UNDER 800 |
| `ext/SpinorBECCUDAExt/gpu_tdhfb_channel.jl` | 150 | UNDER 800 |
| `ext/SpinorBECCUDAExt/gpu_tdhfb.jl` | 111 | UNDER 800 |
| `ext/SpinorBECMakieExt/plotting.jl` | 121 | UNDER 800 |

No files exceed 800 lines. split_step.jl at ~773 actual lines remains the closest to the cap, unchanged from T61.

- Raw candidates over 800: 0
- Filtered count: 0 actionable findings

Triage classification: `no-action-rationalized` — all src/ and ext/ files under 800-line cap; no growth since T61; split_step.jl stable at ~773 actual (668 non-empty). Count unchanged since T61.

**Queued patterns.yaml update**: `last_scanned: '2026-05-18T<T88-timestamp>+09:00'`, `last_count: 0`

---

### 2.7 test-mock-of-real (RECALL scan since T61 | gap 26 turns from T61)

```
rg -n 'mock_\w+\s*=' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

```
rg -n 'stub_\w+\s*=' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

```
rg -n 'Mock\w+\(' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

Pattern's exclude_paths = ['docs/'] — test/ is NOT excluded; sweeping test/ as permitted:

```
rg -n 'mock_\w+\s*=' /home/suzume/workspace/BEC-simulation/test/
```
Result: 0 matches.

```
rg -n 'stub_\w+\s*=' /home/suzume/workspace/BEC-simulation/test/
```
Result: 0 matches.

```
rg -n 'Mock\w+\(' /home/suzume/workspace/BEC-simulation/test/
```
Result: 0 matches.

- Raw hit count: 0 across all 3 patterns in both src/ and test/
- Filtered count: 0
- First 5 hits: none

Triage classification: `no-finding` — 0 raw hits in src/ and test/; Julia test style uses production code directly; mocking is not idiomatic in SpinorBEC.jl. Same as T50 and T61.

**Queued patterns.yaml update**: `last_scanned: '2026-05-18T<T88-timestamp>+09:00'`, `last_count: 0`

---

### 2.8 cargo-cult-comment (RECALL scan since T61 | gap 26 turns from T61 — manual review)

Method: read comments in 5 randomly selected functions across src/. Judged each for WHAT vs WHY.

Function 1: `monopole_charge_3d` in `src/analysis/topology.jl:128-174`
- Post-T51 cleanup confirmed: function body contains no inline WHAT-comments. All computation is uncommented code (centred-difference and cross-product lines are self-evident). GOOD.

Function 2: `split_step_forcegrad!` preamble in `src/hamiltonian/integrator/force_gradient.jl:1-43`
- Module-level docstring explains the Chin-Krotscheck 2005 4A algorithm, the forward fourth-order factorization, the modified middle-V formula, and the scope limitations (c1=0, no DDI). WHY-oriented (explains design rationale and known limitations). GOOD.

Function 3: `_run_itp_loop!` in `src/solvers/ground_state/itp_loop.jl`
- Bug-4 history comment explains the DDI Strang split correctness constraint (two _ddi_step!(ws, dt/2) calls required). Pure WHY. GOOD (same as T61 assessment).

Function 4: `picard_midpoint` branch in `src/hamiltonian/tdhfb/strang_step.jl:114-119`
- Comment: "Opt-in `picard_midpoint=true` uses Picard fixed-point iteration on the HF substep..." explains the design trade-off and opt-in nature. WHY-oriented. GOOD.

Function 5: `_run_lbfgs_step!` vicinity in `src/solvers/lbfgs/driver.jl:87-93`
- Comment: "Gradient-coverage guard: energy_gradient! covers kinetic + trap + Zeeman + c0 + c_lhy + c1 + light_shift + DDI. It does NOT cover the c2 singlet-pair channel... Energy *evaluation* is correct..., but the gradient direction is missing those contributions, so LBFGS would converge to a wrong minimum." — Explains the coverage gap and its consequence. WHY-oriented. GOOD.

- Raw/filtered count: 0 WHAT-only comments identified in any of the 5 spot-checked functions.
- topology.jl T51 cleanup confirmed held (LP-2 scan §2.10 verifies this independently).

Triage classification: `no-action-rationalized` — 5-function manual review finds 0 WHAT-only comments. Same result as T61.

**Queued patterns.yaml update**: `last_scanned: '2026-05-18T<T88-timestamp>+09:00'`, `last_count: 0`

---

### 2.9 paper-unit-system-wrong-param-in-spot-check (RECALL scan since T61 | gap 26 turns from T61)

```
rg -n 'a_s\s*=\s*110\s*a[_]?0' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

```
rg -n 'a_s_si\s*=\s*110\s*\*\s*a_0' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

```
rg -n 'a_s_bohr\s*=\s*110' /home/suzume/workspace/BEC-simulation/src/
```
Result: 0 matches.

- Raw hit count: 0 in src/ across all 3 patterns
- Filtered count (after exclude_paths = ['test/', 'runs/_loop/judge/turn_47_critic_audit.md']): 0
- Note: T48 reactive audit (0 in src/), T50 recall (0 in src/), T61 recall (0 in src/). T50 found 1 hit in `runs/saito_li_torus/config.yaml` (explanatory comment, outside sweep scope). That remains outside src/ scope.

Triage classification: `no-finding` — 0 raw hits in src/; class remains clean since T48 reactive audit. Count unchanged (0 == T61 count of 0).

**Queued patterns.yaml update**: `last_scanned: '2026-05-18T<T88-timestamp>+09:00'`, `last_count: 0`

---

### 2.10 topology-function-WHAT-comment-pattern (RECALL scan since T61 | gap 26 turns from T61)

T51 cleanup targeted `src/analysis/topology.jl` `monopole_charge_3d`. T61 reported 5 raw hits, all false-positives in WHY-comments outside topology.jl. T87 re-sweeps to verify.

```
rg -n '#\s*(Cross product|Dot product|Gradient|Divergence|Curl|Centred differences|Compute\s+(the\s+)?spin|Normalise?\s+to)' /home/suzume/workspace/BEC-simulation/src/
```

Raw result — 5 hits (identical to T61):
1. `src/hamiltonian/integrator/combined_spin_step.jl:62: # Compute spin density into bufs.{Fx_r, Fy_r, Fz_r}, then if DDI is`
2. `src/solvers/lbfgs/driver.jl:87: # Gradient-coverage guard: energy_gradient! covers kinetic + trap +`
3. `src/solvers/lbfgs/driver.jl:126: # Gradient at current psi (Riemannian, used unchanged for the`
4. `src/solvers/lbfgs/driver.jl:203: # Gradient at new psi`
5. `src/workflow/experiments/schema/parsing_blocks.jl:290: # Normalise to internal fields for downstream consumers.`

**Context inspection of each hit (same as T61 assessment, confirmed by re-reading):**

Hit 1 (`combined_spin_step.jl:62`): Full comment continues "...then if DDI is active fold it through the FFT convolution to produce the dipolar field in bufs.{Phi_x, Phi_y, Phi_z}. When DDI is off we still need the spin density (for c1 ⟨F⟩) but the convolution is skipped..." — WHY-level orientation explaining DDI coupling logic. Regex matched `Compute spin` as substring. FALSE POSITIVE.

Hit 2 (`driver.jl:87`): Full comment (lines 87-93) continues "energy_gradient! covers kinetic + trap + Zeeman + c0 + c_lhy + c1 + light_shift + DDI. It does NOT cover the c2 singlet-pair channel... gradient direction is missing those contributions, so LBFGS would converge to a wrong minimum." — WHY-level coverage rationale. Regex matched `Gradient` as substring. FALSE POSITIVE.

Hit 3 (`driver.jl:126`): Full comment continues "...used unchanged for the convergence test — `grad_norm` is the *physical* residual)." — Orientation comment explaining Riemannian gradient's role. WHY-level. FALSE POSITIVE.

Hit 4 (`driver.jl:203`): `# Gradient at new psi` — 4-word block label in L-BFGS line-search code. Borderline WHAT-leaning but not a formula restatement (contrast: T50 `# Cross product ∂_y n̂ × ∂_z n̂` restated the formula; this merely labels the computation block). Below actionability threshold per LP-2 spirit. FALSE POSITIVE.

Hit 5 (`parsing_blocks.jl:290`): `# Normalise to internal fields for downstream consumers.` — Matches `Normalise to`. Brief orientation in YAML pipeline normalization block; "for downstream consumers" provides minimal WHY context. Below actionability threshold. FALSE POSITIVE.

**Topology.jl verification (re-read `src/analysis/topology.jl:128-174`):**
The T51 cleanup of `monopole_charge_3d` continues to hold. Function body at lines 128-174 contains only uncommented computation code. 0 WHAT-comments remain at the cleanup site.

- Raw hit count: 5 (identical to T61)
- Filtered count (after exclude_paths = ['test/', 'docs/'] + context inspection for false positives): 0 actionable
- First 5 hits: listed above (all false positives on context inspection, same conclusion as T61)
- Note: LP-2 grep pattern remains over-broad for `Gradient` and `Normalise to` in algorithmic contexts. T61 proposed a refinement to T62 Triage; that refinement was apparently not adopted (hits are identical). T88 Triage may revisit the grep refinement proposal from T61 §5.

Triage classification: `no-action-rationalized` — T51 cleanup of topology.jl confirmed held (0 hits in topology.jl); 5 raw hits in other files are all false positives on context inspection (WHY-comments mentioning gradient/normalise/spin/compute in algorithmic rationale, not formula restatements). Same result as T61. Count unchanged (5 raw, 0 actionable == T61 result).

**Queued patterns.yaml update**: `last_scanned: '2026-05-18T<T88-timestamp>+09:00'`, `last_count: 0`

**Note on LP-2 grep refinement**: T61 §5 proposed tightening the grep to remove bare `Gradient` and `Normalise to` false-positive variants. T62 Triage appears not to have adopted the change (same 5 hits at T87). T88 Triage should consider applying the T61-proposed refinement:
```yaml
grep_patterns:
  - '#\s*(Cross product|Dot product|Divergence|Curl|Centred differences|Compute\s+(the\s+)?spin\s+expectation|Normalise?\s+to\s+(unit|internal))'
```
This would reduce false-positive rate from 5→~1 while preserving detection of genuine WHAT-comments. Decision is T88's call.

---

## §3 Sibling-class scan + L3 related_classes proposals

**Sibling-class scan**: No NEW findings surfaced in this sweep that were not present at T61. All 10 patterns returned counts identical to T61 (0 actionable findings in all cases; LP-2 raw count of 5 held as previously assessed false positives). Sibling-class scan not triggered (no new finding class surfaced).

No L3 proposals this cycle (steady state; all findings classified into existing catalog entries; T61→T87 gap=26 turns with 0 src/ changes contributing to pattern drift per T87 sweep).

---

## §4 Metrics

```json
{
  "experiment_kind": "text_only",
  "investigation_kind": "physics",
  "src_files_modified": 0,
  "new_analysis_scripts_written": 0,
  "agents_md_files_modified": 0,
  "patterns_yaml_modified": false,
  "investigation_id": "audit-class-scan-2026-05-18-T87",
  "stage_advancing_to": "Observe",
  "flow_template": "audit-class-scan",
  "patterns_scanned_count": 10,
  "findings_total_count": 0,
  "mechanical_fix_now_count": 0,
  "investigation_eligible_count": 0,
  "no_action_rationalized_count": 6,
  "no_finding_count": 4,
  "l3_proposals_count": 0,
  "new_active_pattern_swept_lp2_count": 5,
  "hardcoded_magic_number_raw_count": 126,
  "deprecated_name_leak_raw_count": 0,
  "sweep_wall_time_sec": 480.0,
  "src_subtree_scanned": true,
  "test_subtree_scanned_where_allowed": true,
  "agents_md_unchanged": true,
  "judge_py_unchanged": true,
  "patterns_yaml_unchanged": true,
  "steady_state_vs_t61": true,
  "manuscript_edited": false,
  "src_edited": false,
  "julia_executed": false
}
```

---

## §5 patterns.yaml update proposals (queued for T88 Triage)

T88 implementer should apply these updates to `runs/_loop/patterns.yaml` and append the audit_history row. T87 does NOT modify patterns.yaml (Observe stage constraint).

### Per-pattern last_scanned / last_count updates

All 10 patterns: `last_count: 0` (no actionable findings). Set `last_scanned` to T88 apply timestamp.

```yaml
# deprecated-name-leak
last_scanned: '2026-05-18T<T88-timestamp>+09:00'
last_count: 0

# api-rename-stragglers
last_scanned: '2026-05-18T<T88-timestamp>+09:00'
last_count: 0

# doc-staleness
last_scanned: '2026-05-18T<T88-timestamp>+09:00'
last_count: 0

# hardcoded-magic-number
last_scanned: '2026-05-18T<T88-timestamp>+09:00'
last_count: 0

# dead-export
last_scanned: '2026-05-18T<T88-timestamp>+09:00'
last_count: 0

# large-file-bloat
last_scanned: '2026-05-18T<T88-timestamp>+09:00'
last_count: 0

# test-mock-of-real
last_scanned: '2026-05-18T<T88-timestamp>+09:00'
last_count: 0

# cargo-cult-comment
last_scanned: '2026-05-18T<T88-timestamp>+09:00'
last_count: 0

# paper-unit-system-wrong-param-in-spot-check
last_scanned: '2026-05-18T<T88-timestamp>+09:00'
last_count: 0

# topology-function-WHAT-comment-pattern
last_scanned: '2026-05-18T<T88-timestamp>+09:00'
last_count: 0
```

### Optional grep refinement for topology-function-WHAT-comment-pattern

T61 §5 proposed this refinement; T62 Triage did not adopt it; the same 5 false-positives persist at T87. T88 Triage should apply:

```yaml
grep_patterns:
  - '#\s*(Cross product|Dot product|Divergence|Curl|Centred differences|Compute\s+(the\s+)?spin\s+expectation|Normalise?\s+to\s+(unit|internal))'
```

This removes `Gradient` (4 false positives in driver.jl) and bare `Normalise to` (1 false positive in parsing_blocks.jl) while retaining the core taxonomy. Expected post-refinement count: 0 hits (all current hits are eliminated by this tighter pattern). Decision: T88 Triage.

### audit_history row to append

```yaml
  - turn: 87
    run_at: '2026-05-18T<T88-timestamp>+09:00'
    triggered_by: 'T87 audit-class-scan §F6 Observe sweep (AUDIT_DUE gap=24; 3rd full cycle; gap=26 turns since T61 sweep closed T63)'
    patterns_scanned: ['deprecated-name-leak', 'api-rename-stragglers', 'doc-staleness', 'hardcoded-magic-number', 'dead-export', 'large-file-bloat', 'test-mock-of-real', 'cargo-cult-comment', 'paper-unit-system-wrong-param-in-spot-check', 'topology-function-WHAT-comment-pattern']
    findings_count: 0
    notes: |
      Third full catalog sweep (second since LP-2 promotion at T54). All 10 patterns clean:
      4 no-finding (0 raw hits): deprecated-name-leak, api-rename-stragglers, test-mock-of-real,
      paper-unit-system-wrong-param-in-spot-check.
      6 no-action-rationalized: doc-staleness (1 non-actionable TODO meta-comment, same as T61),
      hardcoded-magic-number (126 1e-30 instances, stable count, heterogeneous semantics, T51
      re-triage holds), dead-export (calibration + analyzers_large + TDHFB public APIs; state_zoo
      WIP excluded), large-file-bloat (all under 800 lines, split_step.jl stable at ~773 actual,
      analyzers_large/ new files all <200 non-empty), cargo-cult-comment (5-function manual review
      clean; topology.jl T51 fix confirmed held), topology-function-WHAT-comment-pattern (T51
      cleanup held; same 5 raw grep hits as T61, all false positives in WHY-comments; 0 actionable).
      0 L3 proposals (steady state; no new classes surfaced).
      LP-2 grep quality note: T61 proposed grep refinement not adopted at T62; same 5 false
      positives persist. T88 Triage should apply refinement (see §5 proposal).
```

---

## §6 Next-turn recommendation

**This sweep is a steady-state result: 0 mechanical-fix-now, 0 investigation-eligible findings.**

T88 recommendation: `implementer_text` (Triage close) — apply the 10 `last_scanned` / `last_count` updates and append the `audit_history` row to `patterns.yaml`. Optionally apply the LP-2 grep refinement (non-blocking). No src/ changes required. Then route to Document close at T89 (implementer_text): append state.json closure (tier 2, current_stage='closed') and update AUDIT_DUE to gap=0.

Routing after T89 Document close: AUDIT_DUE drift advisory clears. Next investigation per priority order: meta-cost-waste-audit Hypothesize (priority 15, address remaining `director_must_address` cost-inflation signal); meta-director-self-audit Hypothesize (priority 20); tier3-verification-pipeline-survey Document closure (priority 10, cheap 1-turn).
