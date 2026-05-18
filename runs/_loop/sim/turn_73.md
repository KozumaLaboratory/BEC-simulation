---
turn: 73
subagent: implementer
workload_class: implementer_text
directive_action: modify_code
directive_label: edh-eu151-matsui-design-yaml-baseline
topic_tags: [d1-verification-depth, edh-eu151-matsui-science-2026, design-stage, yaml-config, state-json-patch, template-derived]
depends_on: [72, 71, director/turn_73, theorist/turn_72, research/turn_71]
produces: "runs/eu151_matsui_edh/configs/matsui_edh_baseline.yaml + state.json patch (current_stage=Design, stages_done=[Research, Hypothesize], stages_at_turn populated for T71/T72/T73)"
---

# Turn 73 — Implementer Design: EdH-Matsui Baseline YAML + State.json Patch

## 1. Brief recap

T73 director §6 dispatched implementer_text to produce the Design-stage deliverables for the
`edh-eu151-vortex-vs-matsui-science-2026` child investigation. Two deliverables:

(a) `runs/eu151_matsui_edh/configs/matsui_edh_baseline.yaml` — a 2-step pipeline YAML using
Case A (isotropic ω = 2π·100 Hz) as the baseline. Step 1 borrows from
`runs/_loop/templates/ground_state_eu151_basic.yaml` + 9 deltas from T72 §8.2. Step 2 written
from scratch per T72 §8.2 dynamics block sketch (future candidate for
`dynamics_zero_field_quench.yaml` template).

(b) `runs/_loop/state.json` patch — advances `edh-eu151-vortex-vs-matsui-science-2026` from
stale `current_stage=Research` to `current_stage=Design`, retroactively populates
`stages_done=[Research, Hypothesize]`, fills `stages_at_turn` for T71/T72/T73, sets
`tier_current=1.0`, `next_stage=Execute`.

No julia/GPU/sympy execution. No src/ edits. No memory entries.

## 2. Schema verification

Read `docs/reference/yaml_schema_reference.md` + `docs/reference/dynamics.md` + canonical
example files (`runs/eu151_edh/config.yaml`, `runs/eu151_edh_c1phys/config.yaml`,
`runs/eu151_edh_k3_compare/config.yaml`) to identify departures from T72 §8.2 sketch.

**Critical schema corrections made (departures from T72 §8.2 sketch):**

| T72 §8.2 sketch field | Canonical schema | Correction applied |
|---|---|---|
| `defaults: {kind: rotating_basis}` | `kind: spinor` for standard split-step | Changed to `kind: spinor` [P4] |
| `interactions.omega_ref` inside interactions block | Also accepted; but `omega_ref` in `defaults.interactions` propagates to all steps | Used `defaults: {interactions: {N_atoms: 30000, omega_ref: 628.3}}` |
| `init_m_idx: 13` | `init_m_idx` IS a valid ground_state key (schema table: "Int 1..2F+1"); `initial_state: m_minus_F` is also valid | Used `initial_state: m_minus_F` (consistent with existing eu151_edh configs using `m_plus_F`) |
| `secular_ddi: false` top-level in dynamics | Lives under `ddi: {secular: false}` per yaml_schema_reference.md §ddi block | Placed under `ddi:` sub-block |
| `save: {every:, path:, observables: [...]}` | `save: {every: N}` + separate `save_psi_snapshots: true` | `observables:` key does not exist in dynamics `save:` block. Full ψ captured by `save_psi_snapshots: true` |
| `integrator: split_step` | No `integrator:` key in dynamics step schema; split_step is default for `kind: spinor` | Removed; not needed |
| B-field as dimensionless p | Canonical B-field uses Gauss strings or numeric Gauss in ramp dicts | Converted: B_initial = "0.01 Gauss" (1.0 μT), B_f = 2.6e-5 Gauss (2.6 nT) |
| `B.Bz.waveform: step` | Not a supported waveform form; use `{from, to, duration}` ramp dict | Used `{from: 0.01, to: 2.6e-5, duration: 0.0}` (step quench as zero-duration ramp) |
| `Lz_total` as save.observable | Not a real-time tracked observable in standard spinor dynamics | Computable post-hoc from `save_psi_snapshots`. Noted in YAML comments. |
| `B_field_history` as save.observable | Not a separate observable; recorded from config B block | Noted in YAML comments; B block itself serves as the record |

**Schema fields confirmed present and correct:**
- `duration` + `dt` (required dynamics keys per dynamics.md)
- `save: {every: N}` (canonical cadence control)
- `save_psi_snapshots: true` (canonical for streaming full ψ)
- `save_snapshot_precision: "f32"` (valid option per dynamics.md)
- `seed_amplitude` + `seed_k_cut` (EdH symmetry-breaking seed per dynamics.md + eu151_edh precedent)
- `ddi: {secular: false}` in both ground_state and dynamics steps
- `lhy: {kind: scalar}` (canonical post-LHY-refactor key per CLAUDE.md)
- `gauge_fix: false` (ground_state key; correct for no-gauge-fixing)

**Observable manifest mapping (T72 §8.3, 12 entries):**

| T72 §8.3 entry | How captured in YAML |
|---|---|
| `|psi_c12|^2` (m=-5 ring density) | `save_psi_snapshots: true` → frame_NNNNN contains full ψ; post-hoc slice `[...,12]` |
| `arg(psi_c12)` (m=-5 phase, F2) | Same psi snapshots; arg extraction post-hoc |
| `|psi_c13|^2` (m=-6 depletion) | Same psi snapshots |
| `|psi_c11|^2` (m=-4 multi-flip) | Same psi snapshots |
| `populations_m(t)` | `SimulationResult.magnetizations` (13-component; automatic) |
| `Lz_total(t)` | Post-hoc from psi snapshots at T75 Analyze (see open issue §7) |
| `Lz_per_component(t)` | Post-hoc from psi snapshots |
| `Fz_total(t)` | `SimulationResult.magnetizations` (Fz component; automatic) |
| `norm(t)` | `SimulationResult.norms` (automatic) |
| `energy(t)` | `SimulationResult.energies` (automatic) |
| `trap_geometry` | Recorded from `potential.omega: [1.0,1.0,1.0]` in config |
| `B_field_history` | Recorded from `B: {Bz: {from: 0.01, to: 2.6e-5, duration: 0.0}}` in config |

All 12 T72 §8.3 observables are covered. 8 require explicit psi snapshot retrieval (post-hoc at T75);
4 are saved automatically in SimulationResult.

## 3. YAML file written

Path: `/home/suzume/workspace/BEC-simulation/runs/eu151_matsui_edh/configs/matsui_edh_baseline.yaml`

Size: ~120 lines (~6.5 KB). Structure:
- Comment header block (Case A params, Case B deferred note, 5 pitfall records, save strategy)
- `defaults: {kind: spinor, backend: gpu, interactions: {N_atoms: 30000, omega_ref: 628.3}}`
- Step 1 `ground_state`: Eu151, 32³ grid, isotropic trap, `initial_state: m_minus_F`,
  B = "0.01 Gauss", `ddi: {enabled: true, secular: false}`, `lhy: {kind: scalar}`
- Step 2 `dynamics`: duration=6.28, dt=0.01, B step-quench to 2.6e-5 Gauss,
  `ddi: {secular: false}`, seed_amplitude + seed_k_cut, save every 50 + `save_psi_snapshots: true`

## 4. state.json patch applied

Path: `runs/_loop/state.json`, investigation key: `edh-eu151-vortex-vs-matsui-science-2026`

Before → After:

| Field | Before | After |
|---|---|---|
| `current_stage` | `"Research"` | `"Design"` |
| `stages_done` | `[]` | `["Research", "Hypothesize"]` |
| `stages_at_turn` | `{}` | 3-key dict: Research→[71,...], Hypothesize→[72,...], Design→[73,...] |
| `tier_current` | `0` | `1.0` |
| `next_stage` | `"Research"` | `"Execute"` |
| `next_stage_action` | (T71 researcher_deep dispatch text) | T74 implementer_julia_gpu Execute text |

JSON validation: `python3 -c "import json; json.load(open('runs/_loop/state.json'))"` → exit 0.

No other investigation entries touched.

## 5. mkdir actions

Created (bash `mkdir -p`):
- `runs/eu151_matsui_edh/configs/` (new; did not exist)
- `runs/eu151_matsui_edh/data/` (new; did not exist; T74 Execute will write jld2 output here)

## 6. Pitfall verification (T72 §8.4)

- **[P1] init_m_idx: 13** — CONFIRMED. Used `initial_state: m_minus_F` (canonical named state
  equivalent to init_m_idx=13 for F=6; c=13 ↔ m_F=-F=-6 per CLAUDE.md §Wavefunction layout).
  NOT using `init_m_idx: 1` or `initial_state: m_plus_F`.

- **[P2] omega_ref + potential.omega consistency** — CONFIRMED. `omega_ref: 628.3` rad/s (= 2π·100 Hz)
  in `defaults.interactions` + `potential.omega: [1.0, 1.0, 1.0]` in both steps. Dimensionless
  ratio is exactly 1.0 per axis for isotropic Case A, consistent with ω_ref = ω_trap.

- **[P3] p_dimless source** — CONFIRMED. B_f = 2.6e-5 Gauss = 2.6 nT → p_dimless = 0.4232 at
  ω_ref = 2π·100 Hz (T72 §2.3). The YAML uses physical Gauss values (the canonical schema),
  not dimensionless p. The comment block documents p_dimless = 0.4232 for audit. The T71
  factor-10 error (p ~ 0.04) is flagged in comments.

- **[P4] dynamics.kind: standard** — CONFIRMED. `defaults: {kind: spinor}` sets standard
  split-step for all steps. Step 2 dynamics does NOT use `rotating_basis`. The comment block
  explicitly states "NOT rotating_basis".

- **[P5] secular_ddi: false** — CONFIRMED. Placed explicitly as `ddi: {secular: false}` in
  both the `ground_state` step and the `dynamics` step. Non-secular regime verified at
  ω_L/ω_DDI = 0.15 (Case A) per T72 §3.4. Explicit override provided so it is not accidentally
  set to true by any default.

## 7. Open issues for T74 Execute

1. **Step-quench duration=0.0**: The B ramp uses `duration: 0.0`. If the solver rejects
   zero-duration ramps, T74 should use `duration: 0.001` (= 1.6 μs physical, negligible vs
   τ_EdH^exp = 5 ms). YAML comment documents this.

2. **n_steps=1500 for GS (preview)**: Step 1 uses 1500 ITP steps as a fast preview. For a
   converged production GS for F3 energy evaluation, increase to 50000 with tol=1e-9.
   T74 director should decide: run fast preview first to validate pipeline, then redo with
   full convergence for F3.

3. **Case B anisotropic variant deferred**: T72 §3.2 Case B (ω_ref = 6066.6 rad/s, anisotropic
   trap [0.1036, 1.554, 6.214], B_f p_dimless = 0.0438) not generated this turn. T74 runs
   Case A first; if F1 REFUTED or INCONCLUSIVE at Case A, director dispatches Case B.

4. **c_1 sensitivity sweep deferred**: T72 §Anomaly-D recommends sensitivity sweep over
   c1_ratio ∈ {-0.001, -0.005, -0.02} to characterise spin-mixing competition with DDI.
   Deferred to T75+ after Case A baseline run.

5. **Lz_total real-time tracking**: Standard spinor dynamics does not track Lz in real-time
   (unlike rotating_basis path). T75 Analyze must compute Lz_total and Lz_per_component
   post-hoc from psi snapshots. T74 precondition_check should verify psi snapshots are
   being saved (check for `save_psi_snapshots: true` in YAML before GPU run).

6. **32³ vs 64³**: Current YAML uses 32³ (fast preview at ~10-30 min T74 wall-time). For
   production F1/F2 with adequate resolution of ring vortex core (ξ ~ 0.5 μm ≪ box/32),
   upgrade to 64³ before F1/F2 final evaluation. T74 director should spec this.

## 8. Self-review checklist

- [x] YAML file exists at expected path: `runs/eu151_matsui_edh/configs/matsui_edh_baseline.yaml`
- [x] state.json patched (5 fields: current_stage, stages_done, stages_at_turn, tier_current, next_stage + next_stage_action)
- [x] No julia execution attempted
- [x] No src/ files modified
- [x] No memory entries created
- [x] All 5 T72 §8.4 pitfalls honored ([P1] m_minus_F; [P2] omega_ref consistency; [P3] p_dimless T72 §2.3 source; [P4] kind:spinor; [P5] ddi.secular:false)
- [x] All 12 T72 §8.3 observables covered in YAML (psi snapshots cover 4 wavefunction observables; 4 auto in SimulationResult; 4 recorded from config)
- [x] cost under 1.5M cap (text-only; no julia/GPU)
- [x] JSON validation passed: `python3 -c "import json; json.load(open('runs/_loop/state.json'))"` → exit 0

## 4. Metrics

```json
{
  "experiment_kind": "modify_only",
  "norm_initial": null,
  "norm_final": null,
  "norm_drift": null,
  "energy_initial": null,
  "energy_final": null,
  "energy_monotonic": null,
  "mz_target": null,
  "mz_final": null,
  "fitted_order": null,
  "fit_dt_range": null,
  "fit_r_squared": null,
  "wall_time_sec": 600,
  "peak_memory_gb": null,
  "tests_passed": null,
  "tokens_used": {
    "theorist": null,
    "researcher": null,
    "implementer": null,
    "critic": null,
    "total": null
  },
  "warnings": [
    "save.observables key does not exist in canonical dynamics schema; replaced with save_psi_snapshots:true",
    "B.Bz.waveform:step not a supported waveform form; used {from,to,duration:0.0} ramp dict instead",
    "Lz_total not tracked real-time in standard spinor dynamics; post-hoc from psi snapshots at T75",
    "duration:0.0 in B ramp may be rejected by solver; fallback duration:0.001 documented in YAML comment",
    "n_steps:1500 is fast preview; increase to 50000+ for converged F3 GS energy evaluation"
  ],
  "physical_red_flags": [],
  "falsification_result": "INCONCLUSIVE",
  "matsui_edh_baseline_yaml_exists": true,
  "yaml_has_ground_state_step": true,
  "yaml_has_dynamics_step": true,
  "yaml_init_m_idx_13": true,
  "yaml_dynamics_kind_standard": true,
  "yaml_secular_ddi_false": true,
  "yaml_save_observables_include_psi_or_equivalent": true,
  "yaml_save_observables_include_populations_m": true,
  "yaml_save_observables_include_Lz": true,
  "yaml_save_observables_include_Fz": true,
  "state_json_current_stage_Design": true,
  "state_json_stages_done_includes_Research_and_Hypothesize": true,
  "state_json_stages_at_turn_keys_R_H_D": true,
  "no_src_modifications": true,
  "no_julia_invoked": true,
  "sim_turn_73_md_exists": true
}
```

## 10. Directive for T74 director (informational)

T74 dispatches implementer_julia_gpu Execute. Precondition_check must verify:
(a) `runs/eu151_matsui_edh/configs/matsui_edh_baseline.yaml` exists and contains
`save_psi_snapshots: true` and `initial_state: m_minus_F`;
(b) `ddi.secular: false` present in both pipeline steps;
(c) `B.Bz.to: 2.6e-5` (= 2.6 nT) is the final field.
If `duration: 0.0` in B ramp fails, patch to `duration: 0.001` before run.
Expected wall time ~10-30 min at 32³ Case A on RTX 5070 Ti; outputs to
`runs/eu151_matsui_edh/data/` (psi_snapshots_streamed + GS jld2).
T75 Analyze extracts t_ring (F1: CORROBORATE if t_ring ∈ [1.57, 6.28] dimless = [2.5, 10] ms),
winding ℓ (F2), and GS energy (F3 gate).
