# `dynamics:` block reference

Every key accepted under a YAML `dynamics:` step. Multiple knobs that
return `on_step` callbacks compose freely (`_compose_callbacks` chains
them). For `ground_state:` knobs see `../guides/pipeline_cookbook.md`; for
hardware/dashboard plumbing see `architecture.md`.

## Required

| key       | type       | meaning                                          |
|-----------|------------|--------------------------------------------------|
| `duration`| Float      | total simulated time (in `ω_ref⁻¹`)              |
| `dt`      | Float      | time step (Strang split-step)                    |

## Output cadence

| key                          | type     | default | meaning                                   |
|------------------------------|----------|---------|-------------------------------------------|
| `save_every`                 | Int      | 1       | record observables / snapshots every N steps |
| `save_psi_snapshots`         | Bool     | false   | stream ψ to scratch JLD2 (`frame_NNNNN`)    |
| `save_snapshot_precision`    | "f32"\|"f64" | "f32" | downcast precision for streamed snapshots  |
| `save_snapshot_compression`  | Bool     | false   | zlib-compress streamed snapshots            |

Snapshots land at `dynamics/psi_snapshots_streamed/frame_NNNNN`. Set
`SPINORBEC_SCRATCH_DIR` to redirect the scratch `.tmp`.

## Hamiltonian overrides (per phase)

Each of these falls back to the previous step's value if omitted:

- `interactions:` — `c0` / `c1` / `c1_ratio` / `N_atoms` / `omega_ref` /
  per-channel `c_extra` / `c_lhy`. Time-dependent `c0` / `c1` produce
  `TimeDependentInteractions`.
- `zeeman:` — Level 0 (`p`/`q`/`bx`/`by`), Level 1 (`Bx`/`By`/`Bz` in
  Gauss strings), Level 2 (`B_mag`/`theta_deg`/`phi_deg`). Mixing levels
  in one block raises `ArgumentError`. Ramps via `{from: …, to: …}` are
  expanded to a `TimeDependentZeeman`.
- `ddi:` — `enabled`, `c_dd` (with optional `{from, to}` ramp),
  `secular`, `quasi_2d`, `l_z`.
- `potential:` — single dict or list (composite). Same syntax as the
  ground-state block.
- `raman:` — Rabi pulses (rectangular / Gaussian envelopes).
- `magnetic_gradient:` — Stern-Gerlach-style ∇B along an axis.

## Stochastic + open-system callbacks

These return `on_step` closures and compose freely:

| knob                | fields                                  | semantics                                            |
|---------------------|------------------------------------------|------------------------------------------------------|
| `sgpe:`             | `gamma`, `T`, `mu`, `k_cut`, `every`, `seed` | stochastic projected GPE (finite-T relaxation)        |
| `projected_gp:`     | `k_cut`, `smooth`, `every`               | hard truncated-projected GP                          |
| `photon_scattering:`| `Gamma_sc`, `seed`                       | spontaneous-emission heating (Lindblad jumps)         |
| `loss:`             | `gamma_dr` and/or `K3_per_m_si: ["1.5e-30 m^6/s", …] × D` | one-body + spin-dependent three-body loss             |
| `pulse_sequence:`   | list of pulse spec dicts                 | composes Zeeman / Raman / interactions for the phase  |
| `live_monitor:`     | `true` \| `{every: N}`                   | atomically writes `<run>/_live_status.json` every N steps for `/api/live/*` |

`K3_per_m_si` accepts Unitful strings; if exactly one entry is given it
is broadcast across all `D = 2F+1` components.

## Initial-condition perturbations

Applied **once** at the start of the dynamics phase, after ψ is copied
from the previous step:

| key                  | type   | meaning                                                  |
|----------------------|--------|----------------------------------------------------------|
| `temperature_ratio`  | Float  | `T/T_c ∈ (0,1)` Bose-Einstein thermal noise              |
| `noise_seed`         | Int    | RNG seed for `temperature_ratio` and `seed_amplitude`    |
| `seed_amplitude`     | Float  | symmetry-breaking seed on the dominant ±1 component      |
| `seed_k_cut`         | Float  | optional k-space lowpass on the seed (`grid` auto-fed)   |

`seed_k_cut` zeroes FFT modes above `|k| = seed_k_cut`, concentrating
noise in long-wavelength unstable bands (e.g. EdH spin-wave manifold
below `1/ξ_h`). Without it the seed is unfiltered white noise. Used in
`runs/eu151_edh/config.yaml`.

## Worked example — multi-knob composition

```yaml
- dynamics:
    duration: 30.0
    dt: 0.005
    save_every: 100
    save_psi_snapshots: true
    save_snapshot_precision: "f32"
    interactions: {omega_ref: 691.15}
    zeeman: {p: {from: 1.0, to: 0.39}, q: 0.0}
    sgpe:              {gamma: 0.05, T: 0.1, every: 1, seed: 42}
    photon_scattering: {Gamma_sc: 0.01, seed: 42}
    loss:              {gamma_dr: 0.02}
    seed_amplitude:    1.0e-4
    seed_k_cut:        0.6
    live_monitor:      {every: 50}
```

The runner builds `cb_sgpe`, `cb_pgp`, `cb_photon`, `cb_live` and pipes
them through `_compose_callbacks` into a single `on_step`.
