# YAML schema — full parameter reference

Generated 2026-04-30 from `src/workflow/experiments/schema.jl` and the
pre-parse stages. Use this to spot aliases, redundancies, and inconsistent
naming. Marked with `[ALIAS]` are fields that overlap semantically with
others — candidates for cleanup.

## Top-level keys

| key | type | meaning |
|---|---|---|
| `pipeline` | list of steps | required, the actual computation |
| `scan` | dict | scan over override paths |
| `calibration` | dict | single CalibrationSet for lab-control rewrites |
| `calibration_history` | list of dated calibrations | weekly drift, interpolated by `target_date` |
| `target_date` | "YYYY-MM-DD" | which calibration to interpolate to |
| `units` | dict {B,ω,t,length,energy: unit-name} | opt-in: bare Reals → quantity strings |
| `defaults` | dict | seeded into every step's inner block (lookup fallback) |
| `mixins` | dict {name: param-set} | named param bundles; pulled in via `use:` |
| `template` | string | named protocol expander (currently none registered) |
| `parameters` | dict | input to template |
| `accuracy` | Real | seeds `epsilon:` on rotating_basis steps |
| `auto_grid` | bool | enable TF-radius grid auto-derivation |
| `metadata`, `name`, `notes`, `version` | free-form | provenance, ignored at runtime |

## ground_state step

| key | type / enum | default | notes |
|---|---|---|---|
| `kind` | spinor / binary / rotating_basis / option_gamma | spinor | which solver |
| `atom` | string | required | Eu151 / Dy164 / Rb87 / Cr52 / Er168 |
| `N_atoms` | Real | — | atom count |
| `omega_ref` | Real (rad/s) | — | trap reference angular freq |
| `dtype` | f32 / f64 | f64 | mixed precision |
| `backend` | cpu / cuda / **gpu** | cpu | `gpu` is alias for `cuda` `[ALIAS]` |
| `method` | itp / lbfgs | itp | ground-state solver |
| `dt` | Real | 0.001 | imaginary-time step |
| `n_steps` | Real | 100000 | ITP step cap |
| `tol` | Real | 1e-8 | convergence threshold (gradient norm) |
| `m_lbfgs` | Real | 10 | LBFGS history length |
| `init_m_idx` | Int 1..2F+1 | — | which m to seed (1 = m=+F) |
| `init_sigma` | Real | — | Gaussian seed σ in dimless / a_ho units |
| `initial_state` | enum (22 names) | polar | named state builder |
| `init_state_params` | dict | — | extra args for state builder |
| `gauge_fix` | bool | true (false for rotating_basis) | gauge fixing |
| `target_magnetization` | Real | — | constrained-Mz GS |
| `temperature_ratio` | Real 0..1 | 0 | thermal noise as fraction of T_c |
| `spinor_lhy` | two_channel / table / scalar | scalar | LHY correction model |
| `cache` | string path | — | reuse precomputed GS |
| `quasi_2d` | bool | false | 2D DDI mode |
| `l_z` | Real | — | quasi-2D harmonic length |
| `noise_seed` | Int | random | RNG seed |
| `rotating_frame_omega` | Real | 0 | spatial rotating frame |
| `adaptive_dt` | bool | false | adaptive ITP timestep |
| `dt_max` | Real | — | adaptive cap |
| `light_shift` | dict | — | optical AC Stark shift |
| `raman` | dict | — | Raman coupling |
| `B_hat` | dict | — | rotating_basis only: B̂ direction (see B_hat block) |
| `F` | Int 0..12 | — | rotating_basis only: explicit F override |
| `species_A`, `species_B` | dict | — | binary path only |

### sub-blocks

#### `grid`
| key | type | required |
|---|---|---|
| `n` | Vector{Int} or Int | yes |
| `box` | Vector{Real} or Real | yes |
| `auto` | bool | (with `auto_grid: true` at top level) |

#### `interactions`
| key | type | notes |
|---|---|---|
| `N_atoms` | Real | also accepted at top level of step `[ALIAS]` |
| `omega_ref` | Real (rad/s) | also accepted at top level `[ALIAS]` |
| `c_total` | Real | dimless 4πN(a_s/a_ho) `[ALIAS for c0+spin auto]` |
| `c0` | Real | dimless contact strength (per-component) |
| `c1` | Real | dimless spin-mixing |
| `c1_ratio` | Real -1..1 | c1/c0 ratio (exclusive with c1) |
| `c_lhy` | Real | dimless LHY |
| `c_extra` | Vector | tensor c2, c3, c4, ... |

#### `ddi`
| key | type | default |
|---|---|---|
| `enabled` | bool | false |
| `c_dd` | Real or dict | (auto from atom if not given) |
| `secular` | bool | false |
| `quasi_2d` | bool | false |
| `l_z` | Real | — |

#### `zeeman` (3 levels — pick ONE per block, `q` always allowed)
- **Level 0** (legacy): `p`, `q`, `bx`, `by` (dimless)
- **Level 1** (Cartesian Gauss): `Bx`, `By`, `Bz` + optional `omega_ref_hz`
- **Level 2** (spherical Gauss): `B_mag`, `theta_deg`, `phi_deg`
- `sources: [...]` (multi-source additive composition)
- `level: <0|1|2>` (vestigial; never write — auto-detect from keys)
- `q` (quadratic Zeeman) always allowed alongside any level
- Calibration rewrite: `p_mv` + `coil_mode` → `p: "X Gauss"` `[via calibration block]`

#### `potential`
- `type: harmonic` + `omega: [ωx, ωy, ωz]` (Real or "X Hz")
- `type: gaussian_dimple` + `depth, waist, position`
- `type: plug` + `strength, waist`
- `type: composite` + `components: [...]`
- `type: optical` + beam params
- `type: shaken_lattice` + `depth, period, shake`
- `type: magnetic_gradient` + `gradient, axis, g_F`
- Calibration: `fort_power_mw: [...]` → `omega: ["X Hz", ...]`

## dynamics step

| key | type | default | notes |
|---|---|---|---|
| `kind` | binary / rotating_basis / option_gamma | spinor (default) | |
| `duration` | Real or "X ms" | required | total time |
| `dt` | Real or "X ms" | required (or use `epsilon`) | step size |
| `epsilon` | Real | — | accuracy budget; derives dt for rotating_basis Y6 |
| `integrator` | strang / yoshida(4/6) / cfet4 / adaptive / richardson | strang or yoshida6 | |
| `backend` | cpu / cuda / gpu | inherited | |
| `save_every` | Int | — | step stride for saves `[ALIAS for n_snapshots]` |
| `n_snapshots` | Int | — | total frames (dt-invariant) `[ALIAS for save_every]` |
| `save_psi_snapshots` | bool | false | save full ψ per frame |
| `save_snapshot_compression` | bool | false | zlib/zstd JLD2 |
| `save_snapshot_precision` | f32 / f64 | f32 | |
| `temperature_ratio` | Real 0..1 | 0 | thermal noise at phase start |
| `seed_amplitude` | Real 0..1 | 0 | Bose-Einstein noise |
| `seed_k_cut` | Real | — | k-space lowpass for noise |
| `noise_seed` | Int | random | |
| `rotating_frame_omega` | Real | 0 | spatial rotating frame |
| `spin_rotating_frame_omega` | Real | 0 | spin Larmor frame |
| `live_monitor` | bool or dict | false | write `_live_status.json` |
| `B_hat` | dict | — | rotating_basis path (see below) |

### `dynamics` per-step physics ramps (all optional, override GS-derived)
- `interactions`, `zeeman`, `potential`, `ddi` — same shapes as in `ground_state`
- `loss`, `sgpe`, `projected_gp`, `photon_scattering` — bool/dict, callbacks
- `magnetic_gradient`, `pulse_sequence`, `raman`, `absorbing_boundary`,
  `light_shift`, `twa`, `couplings` — dicts

## B_hat (rotating_basis B̂(t) trajectory)

Canonical form — axis × motion cleanly split, no aliases:

```yaml
B_hat:
  theta:  <waveform>           # angle θ(t)
  phi:    <waveform>           # angle φ(t) — see motion forms below
```

`theta` motion forms:
| form | parametrization |
|---|---|
| `<scalar>` | const θ |
| `{from, to, duration}` | linear ramp θ |

`phi` motion forms (`{rate: ...}` for rotation; absolute-angle ramp not supported):
| form | parametrization |
|---|---|
| `{rate: <scalar>}` | const dφ/dt (uniform rotation) |
| `{rate: {from, to, duration}}` | linear ramp dφ/dt (chirp) |

In `ground_state.B_hat`, `theta` and `phi` are scalars (initial direction
at t=0). The `{rate: ...}` form is for dynamics steps only.

The legacy flat form (`theta_const` / `theta_ramp` / `phi_omega` /
`phi_chirp` / `phi_dot`) is removed. Writing those keys now raises
`ArgumentError` with a migration hint.

## Waveform spec (used in B_hat axes, zeeman.{Bx,By,Bz,B_mag,theta_deg,phi_deg}, q, etc.)

| form | shape |
|---|---|
| scalar Real or "X unit" | constant value |
| `{from, to, duration}` | linear ramp |
| `{linear: {from, to, duration}}` | `[ALIAS for ramp]` |
| `{sinusoidal: {center, amplitude, frequency, phase}}` | sin |
| `{chirped_sinusoidal: {center, amplitude, freq_start, freq_end, duration, phase}}` | chirp |
| `{gaussian_pulse: {center, amplitude, t_center, sigma}}` | bell |
| `{piecewise: {times, values}}` | piecewise linear |
| `{interpolated: {times, values}}` | smooth interp |
| `{csv: <path>}` | load from file |
| existing Waveform | passthrough |

## scan block

| key | type | notes |
|---|---|---|
| `zip` | dict { override_path → values_or_range } | 1D sweep, all axes same length |
| `product` | dict { override_path → values_or_range } | Cartesian product |
| `comparison_runs` | list | multiple recipes per point |
| `continuation` | bool | reuse previous psi |
| `auto_rotate_on_mz` | bool | rotate by Δα when target Mz changes |

### scan range form
- list `[v1, v2, ...]` literal values
- `{from, to, n, scale}` where scale ∈ {linear, log, sqrt, geom, cosine, reverse_log}
- `{from, to, step}` arithmetic progression
- from/to may be Quantity strings ("50 Hz", "0.1 G") for unit-aware ranges (linear/log only)

## Calibration block

```yaml
calibration_history:
  - date: "2026-04-15"
    coil_strong: {gauss_per_mv, gauss_offset}
    coil_weak: {gauss_per_mv, gauss_offset}
    fort: {sqrt_coeffs_hz: [ωx, ωy, ωz]}
    microwave: {rad_per_s_per_mw}
target_date: "2026-04-15"
```

Drives lab-unit fields:
- `zeeman: {p_mv, coil_mode: strong|weak}` → `zeeman: {p: "X Gauss"}`
- `potential: {fort_power_mw: [...]}` → `potential: {omega: ["X Hz", ...]}`
- `microwave: {power_mw}` → angular-freq strings

## analyze step

A list of analyzers, each `{<name>: <params>}`. Names include:
- `tomography` (n_angles, axis)
- `faraday` (detuning, axis)
- `phase_classify`
- `summary_json` (path)
- `bogoliubov` (k_max, n_k, ...)
- `vortex_detect`, `monopole_charge`, `defect_density`
- `column_density_movie` (axis, multi_step)
- `larmor_phase`, `berry_connection`
- `population_history`

(Full list in `src/workflow/experiments/pipeline_analyzers.jl`.)

## Known aliases / cleanup candidates

| key A | key B | reason | cleanup direction |
|---|---|---|---|
| `phi_omega` (B_hat) | `phi_dot` | clearer name | drop `phi_omega`, keep `phi_dot` |
| `theta_const`, `theta_ramp` | `theta: <scalar/dict>` | flat vs nested | drop legacy, keep `theta:` axis-keyed |
| `phi_chirp` | `phi_dot: {from, to, duration}` | flat vs nested | drop `phi_chirp` |
| `cuda` / `gpu` (backend) | — | both accepted, same | pick one |
| `bx`/`by` (Level 0) | `Bx`/`By` (Level 1) | Cartesian conventions | level auto-detects, keep both |
| `omega_ref` (interactions) | `omega_ref` (top of step) | same field two locations | keep at top of step, deprecate inside interactions |
| `omega_ref_hz` (zeeman_levels) | `omega_ref` (rad/s elsewhere) | unit suffix inconsistent | normalize to `omega_ref` (rad/s) |
| `c_total` | `c0` | related but different scope | document the difference |
| `level: <N>` (zeeman) | (auto-detect) | redundant flag | drop entirely |
| `linear` (waveform) | `{from, to, duration}` (top-level ramp) | two ways | drop the `linear:` wrapper |
| `interpolated` | `piecewise` | almost identical | document difference |
| `save_every` | `n_snapshots` | step vs frame count | keep both, prefer `n_snapshots` |
| `dt` (rotating_basis) | `epsilon` | manual vs derived | prefer `epsilon` |
| `kind: gpu` | `kind: cuda` | enum aliases | pick `cuda` |

Read this and tell me which aliases to actually remove vs keep. I'll then enforce a one-true-form via deprecation warnings + migration of remaining configs.
