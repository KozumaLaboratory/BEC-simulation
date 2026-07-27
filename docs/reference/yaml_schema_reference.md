# YAML schema — full parameter reference

Authoritative source: `src/workflow/experiments/schema/schema.jl` (canonical
`FieldSpec` declarations) + `src/workflow/experiments/schema/parsing_blocks.jl`
+ `src/workflow/experiments/schema/B_block.jl` (legacy-alias rejection +
unified `B:` resolution). Last regenerated 2026-05-23 alongside the
**full nested-schema coverage + legacy alias removal** sweep.

Conventions:
- A key marked **required** triggers an error if absent under strict
  mode (default for `run_yaml`).
- A key marked **rejected** is intercepted by
  `_reject_unknown_step_keys!` with an `ArgumentError` and a migration
  hint. There is no `[ALIAS]` rescue.
- Range / enum brackets come straight from the schema declarations.

## Top-level keys

| key | type | meaning |
|---|---|---|
| `pipeline` | list of steps | **required** — the actual computation |
| `scan` | dict | scan over override paths |
| `calibration` | dict | single CalibrationSet for lab-control rewrites |
| `calibration_history` | list of dated calibrations | weekly drift, interpolated by `target_date` |
| `target_date` | "YYYY-MM-DD" | which calibration to interpolate to |
| `units` | dict {B,ω,t,length,energy: unit-name} | opt-in: bare Reals → quantity strings |
| `defaults` | dict | seeded into every step's inner block (lookup fallback) |
| `mixins` | dict {name: param-set} | named param bundles; pulled in via `use:` |
| `accuracy` | Real | seeds `epsilon:` on rotating_basis steps |
| `auto_grid` | bool | enable TF-radius grid auto-derivation |
| `metadata`, `name`, `notes`, `version` | free-form | provenance, ignored at runtime |

Any other top-level key triggers a typo warning (strict-mode error). The
warning suggests the closest known key via Levenshtein distance.

## Pipeline-step envelope

Each pipeline entry is a single-key dict mapping a step kind to its params:

```yaml
pipeline:
  - ground_state: {atom: Eu151, grid: {n: 32, box: 8.0}, ...}
  - dynamics:     {duration: 5.0, dt: 0.001, ...}
  - analyze:      [{tomography: {...}}, {summary_json: {path: ...}}]
```

Step kinds: `ground_state`, `dynamics`, `analyze`. Anything else triggers
a typo warning.

## `ground_state` step

| key | type / enum | default | notes |
|---|---|---|---|
| `kind` | spinor / binary / rotating_basis | spinor | which solver |
| `atom` | string | — | Eu151 / Dy164 / Rb87 / Cr52 / Er168 / ... |
| `dtype` | f32 / f64 | f64 | mixed precision |
| `backend` | cpu / gpu | cpu | `gpu` requires CUDA-loaded session |
| `method` | itp / lbfgs | itp | ground-state solver |
| `dt` | Real [1e-8, 1.0] | 0.001 | imaginary-time step |
| `n_steps` | Real [0, 1e9] | 100000 | ITP step cap |
| `tol` | Real [1e-16, 1.0] | 1e-8 | convergence threshold (`grad_norm`) |
| `m_lbfgs` | Real [1, 100] | 10 | LBFGS history length |
| `init_m_idx` | Int [1, 25] | — | which m to seed |
| `init_sigma` | Real [0, 100] | — | Gaussian seed σ |
| `initial_state` | enum (22 names) | polar | named state builder |
| `init_state_params` | dict | — | extra args for state builder |
| `gauge_fix` | bool | true | rotating_basis only |
| `target_magnetization` | Real | — | constrained-Mz GS |
| `temperature_ratio` | Real [0, 1] | 0 | thermal noise as fraction of T_c |
| `cache` | string path | — | reuse precomputed GS |
| `quasi_2d` | bool | — | quasi-2D mode |
| `l_z` | Real [0, 100] | — | quasi-2D harmonic length |
| `noise_seed` | Number | random | RNG seed |
| `rotating_frame_omega` | Real | 0 | spatial rotating frame |
| `B_direction` | dict | — | rotating_basis only: B̂ direction |
| `F` | Int [0, 12] | — | rotating_basis only: explicit F override |
| `species_A`, `species_B` | dict | — | binary path only |
| `grid` | dict | — | see `grid` block below |
| `interactions` | dict | — | see `interactions` block below |
| `ddi` | dict / bool | — | see `ddi` block below |
| `B` | dict | — | see `B` block below |
| `lhy` | dict | — | see `lhy` block below |
| `light_shift` | dict | — | see `light_shift` block below |
| `raman` | dict | — | see `raman` block below |
| `potential` | dict / vector | — | see `potential` block below |

### `initial_state` enum

`polar`, `m_plus_F`, `m_minus_F`, `uniform`, `antiferromagnetic`,
`random`, `spin_coherent`, `radial_spin_vortex`, `flower`, `spin_helix`, `cyclic`,
`biaxial_nematic`, `polar_core_vortex`, `bright_soliton`, `dark_soliton`,
`skyrmion`, `gaussian_wavepacket`, `domain_wall`, `two_packets`,
`chiral_spin_vortex`, `magnetic_domain`, `vortex_lattice`,
`skyrmion_lattice`, `from_jld2` (load ψ from prior `result.jld2`).

## `dynamics` step

| key | type / enum | default | notes |
|---|---|---|---|
| `duration` | Real [0, 1e6] | **required** | physical-time length of the step |
| `dt` | Real [1e-8, 1.0] | **required** | integrator timestep |
| `save` | dict | — | see `save` block below |
| `rotating_frame_omega` | Real | 0 | spatial rotating-bucket Ω |
| `temperature_ratio` | Real [0, 1] | 0 | thermal seed at step start |
| `seed_amplitude` | Real [0, 1] | — | broadband random-mode seed |
| `seed_k_cut` | Real [0, 1e6] | — | low-pass cut for `seed_amplitude` |
| `seed_mode` | dict | — | deterministic single-k seed; see block below |
| `hard_polarize` | Real [-12, 12] | — | force `<F_z>=value` at step start |
| `noise_seed` | Number | random | RNG seed for thermal / mode noise |
| `integrator` | strang / yoshida / adaptive / richardson / yoshida4 / yoshida6 / cfet4 | strang | standard path uses first four; rotating_basis uses last four |
| `backend` | cpu / gpu | inherited | per-step override |
| `kind` | binary / rotating_basis | inherited | per-step solver override |
| `B_direction` | dict | — | rotating_basis only |
| `epsilon` | Real [1e-15, 1.0] | — | rotating_basis adaptive accuracy |
| `interactions` | dict | — | per-step interaction override |
| `ddi` | dict / bool | — | per-step DDI on/off |
| `B` | dict | — | unified Zeeman block |
| `potential` | dict / vector | — | trap override |
| `raman` | dict | — | Raman drive; see block below |
| `magnetic_gradient` | dict | — | see block below |
| `light_shift` | dict | — | see block below |
| `absorbing_boundary` | dict | — | see block below |
| `loss` | dict / bool / Real | — | see block below |
| `twa` | dict | — | TWA ensemble; see block below |
| `sgpe` | dict / bool | — | stochastic projected GPE; see block below |
| `projected_gp` | dict / bool | — | projected-GP on-step; see block below |
| `photon_scattering` | dict / bool | — | phase-diffusion on-step; see block below |
| `live_monitor` | dict / bool | — | live JSON status export |
| `pulse_sequence` | list of `PulseEvent` | — | see block below |
| `couplings` | dict | — | binary GP intra/inter couplings |

Semantic details + interactions live in `docs/reference/dynamics.md`.

## Nested blocks

### `grid`

| key | type | required |
|---|---|---|
| `n` | Vector{Int} or Int | yes |
| `box` | Vector{Real} or Real | yes |

### `interactions`

| key | type | range / notes |
|---|---|---|
| `N_atoms` | Number | — |
| `omega_ref` | Number | [0, 1e10] rad/s |
| `c_total` | Number | dimless `4πN(a_s/a_ho)` |
| `c0` | Number | dimless contact |
| `c1` | Number | dimless spin-mixing |
| `c1_ratio` | Number | [-1, 1]; F-tightened to `> -1/F²` post-parse |
| `c_extra` | Vector | tensor `c2, c3, c4, ...` |
| `c2..c12` | Number | sparse-key alternative to `c_extra`; routed into the vector |

### `ddi` — dipolar interactions

| key | type | default |
|---|---|---|
| `enabled` | Bool | true |
| `c_dd` | Number or Dict | (auto from atom) |
| `secular` | Bool | false |
| `quasi_2d` | Bool | false |
| `l_z` | Real [0, 100] | — |
| `trunc_radius` | Number or `"auto"`/`"box_half"` | off |
| `padded` | Bool | false |
| `pad_factor` | Number or per-axis Vector | 2 |

**`padded`** (Tier B) enables the zero-padded, image-free convolution
(Vico–Greengard): combined with `trunc_radius: auto` it removes the periodic
images *exactly* (not just suppresses them), giving near-machine accuracy at
fixed resolution. Cost: ~`prod(pad_factor)`× the grid FFT work + memory (≈8× at
the default 2× pad in 3D). **`pad_factor`** sets the zero-pad multiple — a scalar
or a per-axis vector. Use a smaller factor on thin axes for **anisotropic
padding** (e.g. `pad_factor: [2.73, 2.73, 1.5]` for a pancake) to cut memory; the
auto `trunc_radius` caps R at `(pad_factor_d − 1)·L_d` per axis to stay
wrap-around-free. Only meaningful with `padded: true`.

**`trunc_radius`** applies the spherically-truncated DDI kernel
(Ronen–Bortolotti–Bohn cutoff; Vico–Greengard–Ferrando spectral form). Every
k-space tensor component is multiplied by `h(|k|R) = 1 + 3cos(x)/x² − 3sin(x)/x³`
(`x = |k|R`), the Fourier transform of the dipolar kernel truncated in real
space at radius `R`. This kills the lattice-anisotropy main term — the angular
discontinuity of `k̂_α k̂_β` at the origin and the periodic-image tails of the
un-padded convolution — with spectral accuracy at *fixed* resolution, rather than
trying to converge it away by refining the grid. `h(0)=0` keeps the `Q(k=0)=0`
spherical-cavity convention (no contact / −δ term is introduced); `h(x)→1` for
`|k|R ≫ 1` leaves the bulk physics intact. A number sets `R` (in `a_ho` units);
`"auto"`/`"box_half"` uses half the smallest box extent (the largest cutoff that
avoids wrap-around in the periodic convolution). The quasi-2D kernel is the
analytically z-integrated form and is already smooth, so `trunc_radius` does not
apply there. Off by default (backward-compatible). Diagnostic:
`scripts/ddi_truncation_isotropy_probe.jl`.

### `B` — unified Zeeman block

**Replaces** the legacy `zeeman:` and step-level `B_hat:` keys. Writing
either of those triggers an `ArgumentError` with a migration hint.

The Zeeman Hamiltonian has two mathematically independent contributions:

    H_Zeeman = -(g_F μ_B B · F) + q F_z²
               ↑ vector (chooses coord system)   ↑ scalar (orthogonal)

The vector term `B · F` accepts three input coord systems, auto-detected
from keys (`b_block_builders.jl:_detect_b_coord`):

| coord | keys | semantics |
|---|---|---|
| `:dimless` | `p`, `bx`, `by` | linear / transverse Zeeman, already in ℏω_ref units (`bz ≡ p`) |
| `:cartesian` | `Bx`, `By`, `Bz` | Gauss, converted via `g_F·μ_B/(ℏω_ref)` |
| `:spherical` | `B_mag`, `theta_deg`, `phi_deg` | Gauss magnitude + polar/azimuthal angle |

Internally `:cartesian` and `:spherical` reduce to a single dimensionless
Cartesian triple `(bx_wf, by_wf, bz_wf)` via the same canonicalizer; the
coord choice is purely an input convenience. Mixing keys across coord
systems (e.g. `p:` with `B_mag:`) raises `ArgumentError`.

Scalar `q` (quadratic Zeeman) is allowed alongside any coord system:

| key | semantics |
|---|---|
| `q` | explicit override (Number or waveform dict) |
| (omitted) | auto-derived from `p(t)²` via Breit-Rabi if the atom has hyperfine; `q = 0` for bosonic I=0 atoms |

Lab-units calibration mode (rewritten by the calibration preprocess
into `B_mag: "X Gauss"` before reaching the parser):

| key | type | notes |
|---|---|---|
| `p_mv` | Number | coil setpoint (millivolts) |
| `coil_mode` | "strong" / "weak" | calibration table lookup |

Sample-grid / `ω_ref` overrides for the Gauss-valued paths:

| key | type | notes |
|---|---|---|
| `n_samples` | Int | force `_ZEEMAN_SAMPLE_N` override (default 1024; auto-bumped per Nyquist for sinusoidal / chirped specs) |
| `omega_ref_hz` | Number | Hz override of the `interactions.omega_ref` lookup |

Each scalar field accepts either a Number, a "X unit" string, or a
waveform dict (see Waveform spec) so the field can vary in time.

Multi-source additive composition via `sources: [...]` — each entry is
an independent B sub-block (any coord); the parent `q` applies once at
the top of the aggregated waveform.

### `lhy` — Lee-Huang-Yang correction

**Replaces** the split `interactions.c_lhy:` + `ground_state.spinor_lhy:`
(both removed). Single block inside `ground_state`.

| key | type / enum | default | notes |
|---|---|---|---|
| `kind` | `none` / `scalar` / `quasi_2d` / `polar_two_channel` / `full_bdg` / `polar_contact` / `polar_dipolar` / `fm_contact` / `fm_dipolar` / `icosahedral` | none | — |
| `c_lhy` | Number | auto | `scalar` / `quasi_2d` Lima-Pelster auto-derivation |
| `n_max` | Number | `3 × max(\|ψ_init\|²)` | LHY table density-cap |
| `n_points` | Int [3, 10000] | 200 | tabulation resolution |

### `loss` — three- / two-body loss, evaporation

Accepts a Number / Bool (scalar shortcut) or a Dict with these keys:

| key | type | range |
|---|---|---|
| `gamma_dr` | Number | [0, 1e10] — linear-in-n damping |
| `L3` | Number | [0, 1e10] — m-independent K3 |
| `L3_per_m` | Vector | per-component L3 (legacy linear-in-n) |
| `K3_cubic` | Number | [0, 1e10] — m-independent true 3-body |
| `K3_per_m_cubic` | Vector | per-component true 3-body (dimless) |
| `K3_per_m` | Vector | dimless alias of `K3_per_m_cubic` |
| `K3_per_m_si` | Vector | SI-unit strings (`"3.5e-30 cm^6/s"`) |
| `evap_energy_cutoff` | Number | [0, 1e10] — single-particle ε cutoff |
| `evap_rate` | Number | [0, 1e10] — rate coefficient |

Routing footgun caught 2026-05-13: `K3_per_m` / `K3_per_m_si` now route to
`LossParams.K3_per_m_cubic` (quadratic-in-n true 3-body), NOT the legacy
linear-in-n field. Pre-fix runs need re-verification (see memory).

### `save` (dynamics output sub-block)

| key | type | notes |
|---|---|---|
| `every` | Int [0, 1e9] | save every N steps |
| `n_snapshots` | Int [0, 1e6] | OR fix the snapshot count |
| `psi` | Bool | include ψ in the snapshot (large) |
| `compression` | Bool / String | jld2 compression mode |
| `precision` | "f32" / "f64" | snapshot precision |

### `seed_mode` — deterministic single-mode seed

`add_deterministic_mode_seed!` (`thermal_noise.jl`). Companion to the
broadband `seed_amplitude` / `seed_k_cut` pair.

| key | type | range | required |
|---|---|---|---|
| `k_vec` | Vector | ndim-length wavevector | yes |
| `amplitude` | Number | [0, 1] | yes |
| `phase` | Number | radians | — |

### `magnetic_gradient`

| key | type | required |
|---|---|---|
| `gradient` | Number or waveform dict | yes |
| `axis` | Int [1, 3] | — |
| `g_F` | Number | — |

### `raman`

| key | type |
|---|---|
| `Omega_R` | Number |
| `delta` | Number |
| `k_eff` | Vector |
| `omega_wf` | Dict (waveform) |
| `delta_wf` | Dict (waveform) |

### `absorbing_boundary`

| key | type | range | required |
|---|---|---|---|
| `strength` | Number | [0, 1e10] | yes |
| `width` | Number | [0, 1e6] | yes |
| `power` | Int | [1, 16] | — |

### `light_shift`

Parser path `_parse_light_shift`. Supported branch is `eta_tensor`
(+ optional `eta_vector`, `polarization`); the `alpha_*` / `profile`
keys are accepted at schema level but currently raise `ArgumentError`
at parse time.

| key | type | notes |
|---|---|---|
| `eta_tensor` | Number | tensor-shift coefficient (uses trap as profile) |
| `eta_vector` | Number | vector-shift coefficient |
| `polarization` | Vector | length-3 unit vector |
| `alpha_tensor` | Number | parser-error path (needs `profile:` array) |
| `alpha_vector` | Number | parser-error path |
| `profile` | Vector | parser-error path (YAML profile not supported) |

### `twa` — Truncated Wigner ensemble

| key | type | range | required |
|---|---|---|---|
| `n_trajectories` | Int | [1, 1e9] | yes |
| `seed_base` | Int | — | — |
| `cutoff_energy` | Number | — | — |
| `observables` | Vector | — | — |
| `store_trajectories` | Bool | — | — |

### `sgpe` — Stochastic projected GPE

| key | type | range | required |
|---|---|---|---|
| `gamma` | Number | [0, 1e10] | yes |
| `T` | Number | [0, 1e10] | yes |
| `mu` | Number | — | — |
| `k_cut` | Number | [0, 1e10] | — |
| `every` | Int | [1, 1e9] | — |
| `seed` | Int | — | — |

### `projected_gp`

| key | type | range | required |
|---|---|---|---|
| `k_cut` | Number | [0, 1e10] | yes |
| `smooth` | Bool | — | — |
| `every` | Int | [1, 1e9] | — |

### `photon_scattering`

Either `Gamma_sc` (canonical) or `gamma_sc` (lowercase alias accepted by
the parser) is required.

| key | type | range |
|---|---|---|
| `Gamma_sc` | Number | [0, 1e10] |
| `gamma_sc` | Number | [0, 1e10] |
| `seed` | Int | — |

### `live_monitor`

`live_monitor: false / null / true / {every: 50}`. Writes a JSON status
snapshot every `every` steps to the run dir.

| key | type | range |
|---|---|---|
| `every` | Int | [1, 1e9] |

### `pulse_sequence` — per-event schema

| key | type | required |
|---|---|---|
| `t` | Number [0, 1e6] | yes |
| `apply` | "B" / "raman" / "interactions" / "trap" | yes |
| `duration` | Number [0, 1e6] | — |

Per-target params (left permissive; `_apply_pulse_sequence` validates):

| target | params |
|---|---|
| `B` | `p`, `q`, `bx`, `by` |
| `raman` | `Omega`, `delta`, `k_eff` |
| `interactions` | `c0`, `c1` |
| `trap` | `omega`, `center` |

### `potential`

Dict-keyed by `type`, or a vector of components.

| `type` | params |
|---|---|
| `harmonic` | `omega: [ωx, ωy, ωz]` (Number or "X Hz") |
| `gaussian_dimple` | `depth, waist, position` |
| `plug` | `strength, waist` |
| `composite` | `components: [...]` |
| `optical` | beam params |
| `shaken_lattice` | `depth, period, shake` |
| `magnetic_gradient` | `gradient, axis, g_F` |

Calibration shortcut: `fort_power_mw: [...]` rewrites to
`omega: ["X Hz", ...]` via the FORT calibration table.

## Waveform spec

Used by every field that accepts time dependence (`B.{Bx, By, Bz, ...}`,
`raman.{omega_wf, delta_wf}`, `magnetic_gradient.gradient`, etc.):

| form | shape |
|---|---|
| scalar Real or `"X unit"` | constant value |
| `{from, to, duration}` | linear ramp |
| `{sinusoidal: {center, amplitude, frequency, phase}}` | sinusoid |
| `{chirped_sinusoidal: {center, amplitude, freq_start, freq_end, duration, phase}}` | linear-chirp sinusoid |
| `{gaussian_pulse: {center, amplitude, t_center, sigma}}` | Gaussian pulse |
| `{piecewise: {times, values}}` | piecewise-linear |
| `{interpolated: {times, values}}` | smooth interpolation |
| `{csv: <path>}` | load from file |
| existing `Waveform` | passthrough |

**`frequency` convention** (Klaus-2022 footgun, memory
`gotcha_waveform_frequency_convention.md`): for `sinusoidal`, YAML
`frequency` is `f_phys / (2π · f_ref)`, not `f_phys / f_ref`. Pass
`"X Hz"` (string with units) for unambiguous lab-unit input.

## `scan` block

| key | type | notes |
|---|---|---|
| `zip` | dict { override_path → values_or_range } | 1D sweep, all axes same length |
| `product` | dict { override_path → values_or_range } | Cartesian product |
| `comparison_runs` | list | multiple recipes per point |
| `continuation` | bool | reuse previous ψ |
| `auto_rotate_on_mz` | bool | rotate by Δα when target Mz changes |

`override_path` is a dotted path into a pipeline step's raw YAML dict,
e.g. `pipeline.0.ddi.c_dd`.

### Range form

- list `[v1, v2, ...]` — literal values
- `{from, to, n, scale}` — `scale ∈ {linear, log, sqrt, geom, cosine, reverse_log}`
- `{from, to, step}` — arithmetic progression
- `from` / `to` may be Quantity strings (`"50 Hz"`, `"0.1 G"`) for
  unit-aware ranges (linear / log only)

## Calibration block

```yaml
calibration_history:
  - date: "2026-04-15"
    coil_strong: {gauss_per_mv, gauss_offset}
    coil_weak:   {gauss_per_mv, gauss_offset}
    fort:        {sqrt_coeffs_hz: [ωx, ωy, ωz]}
    microwave:   {rad_per_s_per_mw}
target_date: "2026-04-15"
```

Drives lab-unit fields:
- `B: {p_mv, coil_mode: strong|weak}` → `B: {B_mag: "X Gauss"}`
- `potential: {fort_power_mw: [...]}` → `potential: {omega: ["X Hz", ...]}`
- `microwave: {power_mw}` → angular-frequency strings

`target_date` interpolates between the bracketing entries of
`calibration_history` (weekly drift).

## `analyze` step

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
- `trap_population` (radius, center) — inside-vs-outside-trap norm split; tracks atoms spilling toward the absorbing boundary
- `cloud_shape` — center of mass, per-axis RMS widths, principal-axis widths, aspect ratio, in-plane tilt; quantifies cloud deformation across a snapshot series
- `superfluid_fraction` (directions, method) — per-axis $f_s$ from the phase-twist free energy: `leggett` (plane-average bound), `relaxed` (full variational minimum), or `both` (default). Rigid-density, so both are upper bounds; a cloud that does not span the periodic box legitimately reports ≈ 0

Full list in `src/workflow/experiments/analyzers/`.

## Legacy aliases — removed

These keys used to be accepted via `[ALIAS]` rescues; they now raise
`ArgumentError` at parse time:

| removed key | replacement | rejection site |
|---|---|---|
| `zeeman:` (step-level) | unified `B:` block | `B_block.jl:_reject_unknown_step_keys!` |
| `B_hat:` (step-level) | unified `B:` block (`:spherical` coord) or `B_direction` for rotating_basis | same |
| `interactions.c_lhy` | `lhy.c_lhy` | `parsing_blocks.jl` |
| `ground_state.spinor_lhy` | `lhy.kind` | same |
| `phi_omega` / `phi_dot` (flat B_hat) | `B: {phi: <waveform>}` or `B_direction: {phi: {rate: ...}}` | `B_block.jl` |
| `theta_const`, `theta_ramp`, `phi_chirp` (flat B_hat) | `B: {theta: <waveform>}` | same |
| `initial_state: ferromagnetic` | `m_plus_F` or `m_minus_F` | schema enum |
| `kind: option_gamma` | `kind: rotating_basis` | schema enum |
| `backend: cuda` | `backend: gpu` | `foundation/backend.jl:_resolve_backend` |
| `B: {level: <0|1|2>}` | (drop the key; coord auto-detects from `p` vs `Bx` vs `B_mag`) | `B_block.jl` |
| `B: {magnitude: ...}` | `B: {B_mag: ...}` | `B_block.jl` |
| `loss: {K3_per_m: ...}` | `loss: {K3_per_m_cubic: ...}` (or `K3_per_m_si`) | `parsing_blocks.jl` |
| `photon_scattering: {gamma_sc: ...}` | `photon_scattering: {Gamma_sc: ...}` | `pipeline_callbacks.jl` |

Adding a removed key to a config triggers a strict-mode error with a
one-line migration hint. The error message names the exact replacement
form so config authors can fix it in seconds.
