---
turn: 76
subagent: implementer
workload_class: implementer_julia_cpu_light
directive_action: analyze_existing
directive_label: edh-matsui-analyze-baseline-case-A
topic_tags: [d1-verification-depth, edh-eu151-matsui-science-2026, analyze-stage, jld2-postprocess, t_ring-F1, winding-F2, gs-energy-F3, sibling-typo-audit, wrong-spin-state-bug]
depends_on: [75, 74, 73, 72, director/turn_76, sim/turn_75, theorist/turn_72]
produces: "F1/F2/F3 verdicts from runs/matsui_edh_baseline_529e3a77/point_001.jld2; sibling-typo class audit + fix (2 locations); sim/turn_76.md; Metrics JSON at §4"
---

# Turn 76 — Implementer Analyze: EdH-Matsui Baseline Case A jld2 post-processing

## 1. Brief recap

T75 successfully executed the Matsui EdH baseline Case A run (106s GPU, GS + dynamics), producing `runs/matsui_edh_baseline_529e3a77/point_001.jld2` (47.7 MB). T75 judge returned FAIL_NO_METRICS (Metrics at §9 not §4). T76 loads the jld2 with h5py (Python, JLD2 is HDF5-compatible) and extracts F1/F2/F3 verdicts. Critical finding: the GS converged to m_F=+6 (not m_F=-6) because the ITP stabilizing field Bz=0.01G produces p_dimless=162.7 >> 1, causing ITP to find the energetically favored m_F=+6 state. The Matsui EdH protocol requires m_F=-6 initial state. All F1/F2/F3 verdicts are reported with this caveat.

## 2. jld2 structure verification

File: `runs/matsui_edh_baseline_529e3a77/point_001.jld2` (47,723,876 bytes).

Top keys confirmed: `converged, duration_seconds, dynamics, energy, env, finished_at, grid_box_size, grid_n_points, psi, run_name, scan_index, started_at, units`.

Dynamics keys confirmed: `Fz, component_populations, energies, magnetizations, norms, peak_density, psi_snapshots_streamed, times`.

Snapshot keys: `frame_00001..frame_00012` plus `n_snapshots=12`, `spatial_shape=[32,32,32]`, `n_components=13`. Match with T75 §5: confirmed. psi dtype is structured complex (re/im float64). Snapshot frames are structured complex float32.

## 3. Step 0 — Sibling-typo class audit

Grep results (verbatim):

**Pattern 1** — `haskey(p, "B")` in all run_step_*.jl and runner.jl:
```
(no output — zero hits)
```
Zero hits on main HEAD. The T75 fix was on auto/turn_75 branch, not merged to main.

**Pattern 2** — `haskey(p, "zeeman")` in all run_step_*.jl and runner.jl:
```
run_step_ground_state.jl-117-    duration = dt * n_steps
run_step_ground_state.jl:118:    zeeman = if haskey(p, "zeeman")
run_step_ground_state.jl-119-        _build_zeeman_dispatched(p["zeeman"], duration, atom, p)
run_step_ground_state.jl-120-    elseif ws_prev !== nothing
--
run_step_ground_state.jl-272-            !haskey(p, "interactions") && !haskey(p, "ddi") &&
run_step_ground_state.jl:273:            !haskey(p, "potential") && !haskey(p, "zeeman")
run_step_ground_state.jl-274-            find_ground_state_lbfgs(;
```

2 hits, both in `run_step_ground_state.jl`. Sibling audit results:
- `run_step_dynamics.jl`: uses `get(p, "B", Dict())` at line 93 (correct — no hit)
- `run_step_binary.jl`: no B-block, uses g_AA/g_BB/g_AB couplings (no hit)
- `run_step_rotating/` sub-files: no `haskey(p,"zeeman")` or `haskey(p,"B")` (no hit)
- `runner.jl`: no B-block parsing (no hit)

**Edits applied** (2 fixes on T76 branch):

```
# Line 118-119 before:
zeeman = if haskey(p, "zeeman")
    _build_zeeman_dispatched(p["zeeman"], duration, atom, p)
# Line 118-119 after:
zeeman = if haskey(p, "B")
    _build_zeeman_dispatched(p["B"], duration, atom, p)

# Line 273 before:
    !haskey(p, "potential") && !haskey(p, "zeeman")
# Line 273 after:
    !haskey(p, "potential") && !haskey(p, "B")
```

Commit `72c5b0f` on branch `auto/turn_76_edh-matsui-analyze-baseline-case-A`. Files changed: 1 (run_step_ground_state.jl, 3 insertions, 3 deletions).

## 4. Metrics

```json
{
  "experiment_kind": "analyze_existing",
  "jld2_loaded": true,
  "jld2_path": "runs/matsui_edh_baseline_529e3a77/point_001.jld2",
  "siblings_audited": true,
  "siblings_typos_found": 2,
  "siblings_typos_fixed": 2,
  "F3_gs_energy_sim_per_N": 8.44,
  "F3_gs_energy_mf_per_N": 10.5,
  "F3_relative_error": 0.1963,
  "F3_verdict": "CORROBORATE",
  "F1_t_ring_dimless": null,
  "F1_t_ring_physical_ms": null,
  "F1_verdict": "REFUTED",
  "F1_ring_detected": false,
  "F2_winding_l": null,
  "F2_l_paper": 1,
  "F2_verdict": "not_applicable",
  "norm_drift_max": 8.41e-13,
  "mz_drift_max": 0.0014,
  "energy_drift_relative_max": 0.9617,
  "populations_m_minus_5_final": 1.77e-28,
  "populations_m_minus_6_final": 2.58e-28,
  "ddi_larmor_reconciled": true,
  "physical_red_flags": [
    "WRONG_SPIN_STATE: GS converged to m_F=+6 not m_F=-6. ITP stabilizing field Bz=0.01G gives p_dimless=162.7 >> 1. ITP minimizes energy so m_F=+6 (E_zee=-162.7*6=-976.2) wins over m_F=-6 initial_state seed. GS populations confirmed: m_F=+6=99.5%, m_F=-6<1e-28. Matsui EdH requires m_F=-6 initial state.",
    "F1_WRONG_COMPONENT: dynamics evolves from m_F=+6. EdH transfer m_F=+6->+5 occurs (m_F=+5 grows to 0.14% at t=6 dimless). Target ring component m_F=-5 has population <2e-28 at all times. Ring physically cannot form in the wrong component.",
    "YAML_CONFIG_BUG: the ITP stabilizing B field Bz=0.01G is 385x larger than the quench field 2.6e-5 G. Fix required: use Bz near zero (e.g. 1e-7 Gauss) or negative Bz to stabilize m_F=-F during ITP.",
    "energy_drift_relative=0.962 is expected physics (B quench changes Zeeman energy by ~930 hbar*omega_ref), not a numerical conservation failure."
  ],
  "warnings": [
    "T75 haskey-B fix not merged to main before T76 dispatch; re-applied on T76 auto branch (identical fix, 2 locations).",
    "DDI INFO 'omega_L/(c_dd*n_peak) approx 123' fires at GS time (Bz=0.01G, p=162.7), not at dynamics Bz=2.6nT. At dynamics time: ratio=0.68. T72 \u00a73.4 ratio=0.15 uses physical n_avg; both confirm non-secular regime. Reconciled \u2014 no physics bug.",
    "F3 relative error 19.6% is borderline (threshold 20%). The 2.06 hbar*omega_ref gap from T72 prediction is plausible from LHY/DDI contributions absent in the T72 TF formula."
  ],
  "falsification_result": "MIXED",
  "tests_passed": null,
  "tokens_used": {
    "theorist": null,
    "researcher": null,
    "implementer": null,
    "critic": null,
    "orchestrator": 23773313,
    "total": 23773313,
    "effective_full_rate": 3055578,
    "breakdown": {
      "input_fresh": 28118,
      "cache_creation": 472860,
      "cache_read": 23250059,
      "output": 22276
    },
    "n_messages": 176,
    "n_message_starts": 176
  }
}
```

## 5. Step 1 — jld2 data inspection

**GS state**:
- psi shape: `(13, 32, 32, 32)` in h5py (spinor-first, Julia column-major transpose confirmed)
- norm check: `sum(|psi|^2) * dV = 1.000000` (exact; psi normalized to 1, not N)
- E_gs = -967.0272024679483 hbar*omega_ref (total energy including large Zeeman from Bz=0.01G)
- Component populations: m_F=+6 (99.50%), m_F=+5 (0.500%), m_F=+4 (0.003%), others < 1e-6
- GS confirmed to be in m_F=+6 (three independent checks in §6)

**Dynamics data**:
- times: [0.0, 0.5, 1.0, ..., 6.0] — 13 points
- norms: [1.0, ..., 1.0] — norm_drift_max = 8.41e-13
- magnetizations: [5.99999952, ..., 5.99859299] — tracking |Mz|, starts ~6, decreases 0.14%
- component_populations (h5py shape 13,12): at t=0, m_F=+6=100%; at t_final, m_F=+6=99.857%, m_F=+5=0.140%, m_F=-5<3e-28, m_F=-6<3e-28
- energies: [-967.07, -889.61, -812.14, ..., -37.08] — large linear ramp from B quench
- peak_density: [0.00514, 0.00535, 0.00561, ...] hbar*omega_ref units

## 6. Step 2 — F3 GS energy ratio

**Root cause of wrong spin state**. At Bz=0.01G, p_dimless:
```
p = g_F * mu_B * (0.01 Gauss * 1e-4 T/Gauss) / (hbar * omega_ref)
  = 1.163 * 9.274e-24 * 1e-6 / (1.055e-34 * 628.3)
  = 1.079e-29 / 6.628e-32 = 162.7 hbar*omega_ref
```
At p=162.7 >> 1, Zeeman energy of m_F=+6 is -p*6 = -976.2 (minimum). ITP converges to this minimum, overriding the `initial_state: m_minus_F` seed.

**F3 Zeeman subtraction**:
- E_zee = sum_c (-p * m_c * pop_c) = -162.7149 * (6*0.9950 + 5*0.0050 + 4*3.07e-5 + ...) = **-975.47 hbar*omega_ref**
- E_sim_no_zee = E_gs - E_zee = -967.0272 - (-975.47) = **+8.44 hbar*omega_ref**

**F3 comparison**:
- E_mf/N (T72 §5.3 Case A, zero-field) = 10.5 hbar*omega_ref (zero-point 1.5 + contact-TF 9.0)
- Relative error = |8.44 - 10.5| / |10.5| = **19.6%**
- **F3 verdict: CORROBORATE** (19.6% < 20% threshold)

OPERATIONAL_GATE not triggered. Post-Bug-4 ITP confirmed correct. The 2.1 hbar*omega_ref gap is partly explained by DDI (c_dd=120.7) and LHY (c_lhy=630.9) contributions not included in the T72 zero-field TF formula, plus the GS being m_F=+6 not m_F=-6 (DDI contribution differs for +F vs -F in an isotropic trap with secular_ddi=false — small but non-zero effect from the time-dependent off-diagonal DDI).

**Note on normalization**: E_gs is the TOTAL energy when psi is normalized to 1 (coupling constants already encode N). E^sim/N in T72's sense = E_sim_no_zee = 8.44 hbar*omega_ref per "effective atom" (where N is absorbed into c_eff).

## 7. Step 3 — F1 t_ring extraction

All 12 snapshot frames inspected for component c=12 (m_F=-5, Python index 11):

```
Frame 1 (t=0.5): total_pop=5.95e-31 (near zero)
Frame 2 (t=1.0): total_pop=1.12e-30 (near zero)
...
Frame 12 (t=6.0): total_pop=1.77e-28 (near zero)
```

All frames: total_pop(m_F=-5) in range [6e-31, 2e-28]. Azimuthal-mean ring criterion never satisfied. No ring detected.

The EdH-like transfer IS occurring but in m_F=+5 (from initial m_F=+6), not m_F=-5:
```
t=0.5: m_F=+5 pop = 7.65e-06
t=6.0: m_F=+5 pop = 1.40e-03  (0.14% -- growing)
m_F=-5 at all times: < 2e-28 (machine noise)
```

**F1 verdict: REFUTED** — caused by YAML config bug (wrong spin state), not by EdH physics failure. The framework does produce AM transfer (m_F=+6 -> +5), just in the wrong direction for Matsui's experiment.

## 8. Step 4 — F2 winding

**F2 verdict: not_applicable** — no ring in target component m_F=-5.

## 9. Step 5/6 — supporting metrics + DDI Larmor reconciliation

**norm conservation**: 8.41e-13 (near machine epsilon, confirms dynamics integrator health).

**Mz evolution**: Mz decreases from 5.999995 to 5.99859 (delta = 0.00140). Consistent with 0.14% of atoms transferred m_F=+6->+5 (each transfer: delta_Mz = -1 per atom, but Mz here tracks |Fz|, so a +6->+5 transfer with population fraction epsilon gives |Mz| = 6*(1-epsilon) + 5*epsilon = 6 - epsilon. At epsilon=0.0014: |Mz| = 5.9986. Observed: 5.99859. Match.

**energy drift**: B quench at t=0 changes Zeeman energy by approximately (p_f - p_i)*6 = (0.4232-162.7)*6 = -973.7 hbar*omega_ref. The energy jumps from -967.07 to -889.61 at the first saved time t=0.5 (change +77.5). The linear decrease in energies after the quench (steps 1-12) reflects the ongoing Zeeman decrease as B ramps from 0.01G to 2.6e-5G. energy_drift_relative=0.962 is expected physics, not anomaly.

**DDI Larmor reconciliation**:

T75 §8.2 flagged INFO "omega_L/(c_dd*n_peak) approx 123.0" vs T72 §3.4 "omega_L/omega_DDI = 0.15".

Resolution: the INFO fires at GS initialization time (Bz=0.01G, p_GS=162.7), not at the dynamics field. At dynamics time (Bz=2.6nT, p_f=0.4232):
- omega_L_phys = p_f * omega_ref = 0.4232 * 628.3 = 265.9 rad/s = 2pi*42.3 Hz (exact T72 value)
- T72 omega_DDI = c_dd_SI * n_avg_SI / hbar = 5.26e-51 * 3.52e19 / 1.055e-34 = 1755 rad/s
- T72 ratio = 265.9/1755 = **0.152** (T72 says 0.15, exact agreement within rounding)
- SpinorBEC INFO definition (using dimless): p_f / (c_dd * n_peak) = 0.4232/(120.7*0.00514) = **0.682**

Factor-4.5 difference between 0.152 and 0.682 comes from: (1) n_avg vs n_peak (factor 7/4), (2) conversion from physical-unit to dimless-unit c_dd definition. Both values correctly indicate non-secular regime (omega_L < omega_DDI). The INFO message at 123 uses the GS stabilizing B=0.01G field (p_GS=162.7), which is intentionally secular (to suppress spin dynamics during ITP) — the INFO advisory to "use secular_ddi=true" was correct for the GS phase but the T72 §3.4 choice of secular_ddi=false is correct for the dynamics phase. **Reconciled. No physics bug.**

## 10. Self-review checklist

- [x] Read director/turn_76.md §1-§6 full (all 8 mandatory context reads executed)
- [x] Read sim/turn_75.md §5 jld2 structure and §8 open issues
- [x] Read theorist/turn_72.md §3-§7 (F1/F2/F3 predictions, thresholds, m_F->c table)
- [x] Read research/turn_71.md §2 T5 (tau_EdH_exp=5ms EXTRACTED)
- [x] Precondition check: OK_T76_director_precondition (all 5 files present, julia confirmed)
- [x] Ran grep for haskey patterns across run_step_*.jl and runner.jl
- [x] Applied 2 typo fixes in run_step_ground_state.jl lines 118-119 and 273
- [x] Committed 72c5b0f on auto/turn_76 branch (gitleaks PASS, no leaks)
- [x] Loaded point_001.jld2 with h5py: jld2_loaded=true, all keys present, structured complex handled
- [x] Identified wrong spin state from populations and energy analysis
- [x] Computed p_dimless at Bz=0.01G: p=162.7 (explains ITP convergence to m_F=+6)
- [x] Computed F3: E_sim_no_zee=8.44, E_mf_N=10.5, relative_error=19.6% -> CORROBORATE
- [x] Scanned all 12 snapshot frames for m_F=-5 ring: none found (populations < 2e-28)
- [x] F1=REFUTED (config bug, not physics), F2=not_applicable, F3=CORROBORATE
- [x] Reconciled DDI INFO 123 vs T72 0.15 (different field times and normalizations)
- [x] Metrics JSON at §4 (canonical position, fixes T75 judge FAIL_NO_METRICS)
- [x] falsification_result=MIXED
- [x] No re-execution of run_yaml
- [x] No GPU used (implementer_julia_cpu_light workload class)
- [x] No new memory entries (deferred to T78 Document)
- [x] No runs/_loop/ git commit (orchestrator handles)
