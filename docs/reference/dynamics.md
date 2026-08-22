# `dynamics:` block reference

Every key accepted under a YAML `dynamics:` step. Multiple knobs that return `on_step` callbacks compose freely (`_compose_callbacks` chains them). For `ground_state:` knobs see `../guides/pipeline_cookbook.md`; for hardware/dashboard plumbing see `architecture.md`.

## Required

| key       | type       | meaning                                          |
|-----------|------------|--------------------------------------------------|
| `duration`| Float      | total simulated time (in `ω_ref⁻¹`)              |
| `dt`      | Float      | time step (Strang split-step)                    |

## Spin-step splitting — `spin_step:`

| value          | V half-step                                                        |
|----------------|--------------------------------------------------------------------|
| `"sequential"` | (default) `diag · SM(dt/4) · DDI(dt/2) · SM(dt/4) · diag`            |
| `"combined"`   | `diag · exp(-i dt (c₁⟨F⟩ + Φ_DDI)·F̂) · diag`                        |

The spin-mixing and DDI substeps are the same operator `exp(-i dt (v·F̂))` with
different `v`, so they can be applied as one rotation instead of three. Both
splittings are $O(dt^2)$ and converge to the same continuum limit; they differ
at $O(dt^3)$, the combined form carrying no $[\mathrm{SM},[\mathrm{SM},
\mathrm{DDI}]]$ commutator error.

Measured on one H100, ¹⁵¹Eu F=6 (D=13), F64, DDI + c₀ + c₁, midpoint on
(`bench/rtp_gpu_ab.jl`, same process / same initial ψ for every arm):

| grid | sequential | combined | |
|------|-----------:|---------:|--:|
| 64³  |  4.40 ms/step | 2.58 ms/step | 1.70× |
| 128³ | 29.99 ms/step | 17.51 ms/step | 1.71× |

The `sequential` column is the shipping default, i.e. with the shared
Taylor-Horner rotation (`_SPIN_TAYLOR_ENABLED` defaults to `true`), so these
ratios are what choosing `combined` actually buys you. The bench prints a third
arm and two speedup columns of its own, both against the 5-stage Euler kernel —
at 128³ its `sp(comb)` reads 2.84×. Do not quote that against `spin_step:`:
Euler is not selectable through this key, and the extra factor is the Taylor
rotation, which `sequential` already has.

`combined` is **not** the default: switching a run to it changes its numbers at
$O(dt^3)$, so an existing result will not reproduce bitwise. Pick it
deliberately, and do not mix it with `sequential` across phases of one study.

The selector silently keeps `sequential` for any workspace the combined form
cannot represent — `c₂ ≠ 0`, tensor channels, Raman, light shift, a spatial or
**tilted** field, and padded or absent DDI. (A tilted field is excluded because
the combined step folds only the linear `-(b⊥·F̂)` into the rotation and leaves a
lab-`z` `q F_z²` in the diagonal step, while the sequential path applies the
whole tilted Zeeman as one eigen-exact matrix; those agree only for an axial
field or `q = 0`.)

## Output cadence

| key                          | type     | default | meaning                                   |
|------------------------------|----------|---------|-------------------------------------------|
| `save.every`                 | Int      | 1       | record observables / snapshots every N steps |
| `save.n_snapshots`           | Int      | —       | OR fix the snapshot count instead of the stride |
| `save.psi`                   | Bool     | false   | stream ψ to scratch JLD2 (`frame_NNNNN`)    |
| `save.precision`             | "f32"\|"f64" | "f32" | downcast precision for streamed snapshots  |
| `save.compression`           | Bool     | false   | zlib-compress streamed snapshots            |

All five live inside one `save:` mapping (`SAVE_SCHEMA`). The flat spellings
`save_every` / `save_psi_snapshots` / `save_snapshot_precision` /
`save_snapshot_compression` are unknown keys and abort a strict-mode load.

Snapshots land at `dynamics/psi_snapshots_streamed/frame_NNNNN`. Set `SPINORBEC_SCRATCH_DIR` to redirect the scratch `.tmp`.

## Progress and ETA (#408)

Every dynamics path — standard, `binary`, `rotating_basis`, `scalar_egpe` —
prints a wall-clock-throttled progress line, **on by default**:

```
[scalar_egpe]  t = 0.44/1.10 (40.0 %)  step 176000/440000  elapsed 44m01s  left 1h06m  ETA 18:32:07
```

| variable | default | meaning |
|---|---|---|
| `SPINORBEC_PROGRESS` | on | set to `quiet` / `off` / `0` / `false` / `no` / `none` to silence. Any other value leaves it on |
| `SPINORBEC_PROGRESS_INTERVAL` | `60` | seconds between lines. A malformed or non-positive value falls back to 60 rather than throwing |

Three things about it are deliberate. The cadence is **wall-clock, not step
count** — a step cadence floods at 32³ and goes silent at 128³, and 128³ is
where the silence costs something. The ETA is a **clock time**, because `h_rt`
is a clock time and "66 minutes left" has to be added to now by hand before the
two can be compared. And it is **not** a YAML key and not tied to
`live_monitor:`: `live_monitor` is documented as the thing batch runs switch
off, which is exactly the hand-submitted `qsub` job that ran 110 minutes in
silence and then died on `h_rt`.

## Hamiltonian overrides (per phase)

Each of these falls back to the previous step's value if omitted:

- `interactions:` — `c0` / `c1` / `c1_ratio` / `N_atoms` / `omega_ref` / `c_total` / per-channel `cN` (N = 2…12).
  Time-dependent `c0` / `c1` produce `TimeDependentInteractions`.
  **Not `c_lhy`** — it moved to the `lhy:` block (`lhy: {kind: …, c_lhy: …}`) and
  `interactions.c_lhy` is now rejected as an unknown key. Listed here until 2026-08-04.
- `B:` — unified Zeeman block. Three coord systems auto-detected from keys: `:dimless` (`p`/`q`/`bx`/`by`), `:cartesian` (`Bx`/`By`/`Bz`, Gauss or `"X Gauss"` strings), `:spherical` (`B_mag`/`theta_deg`/`phi_deg`). Mixing coord systems in one block raises `ArgumentError`. `q` is coord-orthogonal and may be combined with any. Ramps via `{from: …, to: …}` expand to a `TimeDependentZeeman`. The legacy step-level `zeeman:` / `B_hat:` keys are rejected.
- `ddi:` — `enabled`, `c_dd` (with optional `{from, to}` ramp), `secular`, `quasi_2d`, `l_z`.
- `potential:` — single dict or list (composite). Same syntax as the ground-state block.
- `raman:` — Rabi pulses (rectangular / Gaussian envelopes).
- `magnetic_gradient:` — Stern-Gerlach-style ∇B along an axis.

## Stochastic + open-system callbacks

These return `on_step` closures and compose freely:

| knob                | fields                                  | semantics                                            |
|---------------------|------------------------------------------|------------------------------------------------------|
| `sgpe:`             | `gamma`, `T`, `mu`, `k_cut`, `every`, `seed` | stochastic projected GPE (finite-T relaxation)        |
| *(SPGPE)*           | Julia-only: `SPGPEReservoir` + `spgpe_callback` | **full** SPGPE — growth AND energy-damping reservoirs, γ/ℳ̄ derived from (μ, T, ε_cut); accepts ramped `T(t)`, `μ(t)`. See [spgpe.md](../guides/spgpe.md). No YAML key yet. |
| `projected_gp:`     | `k_cut`, `smooth`, `every`               | hard truncated-projected GP                          |
| `photon_scattering:`| `Gamma_sc`, `seed`                       | spontaneous-emission heating (Lindblad jumps)         |
| `loss:`             | `gamma_dr` and/or `K3_per_m_si: ["1.5e-30 m^6/s", …] × D` | one-body + spin-dependent three-body loss             |
| `pulse_sequence:`   | list of pulse spec dicts                 | composes Zeeman / Raman / interactions for the phase  |
| `live_monitor:`     | `true` \| `{every: N}`                   | atomically writes `<run>/_live_status.json` every N steps for `/api/live/*` |

### Three-body loss `K3_per_m_si`

`K3_per_m_si` accepts Unitful strings (`m^6/s`); the SI value is converted to
the dimensionless rate via `K3_dimless = K3_SI · n0² / ω_ref`, where
`n0 = N_atoms / a_ho³` and `a_ho = √(ℏ / (m·ω_ref))`. The conversion needs
`atom + N_atoms + omega_ref`, so dynamics steps using `K3_per_m_si` MUST
have those reachable in their `interactions:` block. The idiomatic way is
the top-level `defaults:` block:

```yaml
defaults:
  interactions: {N_atoms: 10000, omega_ref: 691.15}   # propagated to every step

pipeline:
  - ground_state:
      interactions: {c0: 1.5e3, c1_ratio: 0.028, ...}
      ...
  - dynamics:
      duration: 1.0
      dt: 1.0e-4
      loss:
        gamma_dr: 0.02
        K3_per_m_si:                                   # one per m_F, length 2F+1
          ["1.0e-41 m^6/s", "1.0e-41 m^6/s", ..., "1.0e-41 m^6/s"]
      save: {every: 200}
```

The kernel applies `exp(-K_3 · n_tot² · dt / 2)` per component, i.e. the
**true 3-body** form `dn_m/dt = -K_3 n² n_m`. For polarized BECs near the
roton-instability boundary this acts as a soft cap on density spikes —
the rate scales as `n²`, biting hardest at the runaway core. EdH magnetic-
vortex-core simulations were the motivating use case
(`runs/eu151_edh_k3_compare/`).

If you want the **legacy 2-body-shape** rate (`dn_m/dt = -γ n n_m`,
linear in n; sometimes used for calibration against measured `L3_eff·n0`
constants), use `L3` / `L3_per_m`. The name is historical — same loss
struct, different application form.

Routing summary:

| YAML key                                 | LossParams field    | Application form              |
|------------------------------------------|---------------------|-------------------------------|
| `L3`, `L3_per_m`                         | `L3` / `L3_per_m`   | `exp(-γ n dt / 2)`   (linear) |
| `K3_cubic`, `K3_per_m_cubic` | `K3_per_m_cubic`    | `exp(-K_3 n² dt / 2)` (true 3-body) |
| `K3_per_m_si`                            | `K3_per_m_cubic` (via `n0²/ω_ref`) | same as above |

Pre-2026-05-13 the SI input was mis-routed into `L3_per_m` (linear-in-n);
fix in commit `6bfe9d9`. Regression test in `test/workflow/test_pipeline.jl`.

## Initial-condition perturbations

Applied **once** at the start of the dynamics phase, after ψ is copied from the previous step:

| key                  | type   | meaning                                                  |
|----------------------|--------|----------------------------------------------------------|
| `temperature_ratio`  | Float  | `T/T_c ∈ (0,1)` Bose-Einstein thermal noise              |
| `noise_seed`         | Int    | RNG seed for `temperature_ratio` and `seed_amplitude`    |
| `seed_amplitude`     | Float  | symmetry-breaking seed on the dominant ±1 component      |
| `seed_k_cut`         | Float  | optional k-space lowpass on the seed (`grid` auto-fed)   |

`seed_k_cut` zeroes FFT modes above `|k| = seed_k_cut`, concentrating noise in long-wavelength unstable bands (e.g. EdH spin-wave manifold below `1/ξ_h`). Without it the seed is unfiltered white noise. Used in `runs/eu151_edh/config.yaml`.

## Worked example — multi-knob composition

```yaml
- dynamics:
    duration: 30.0
    dt: 0.005
    save: {every: 100, psi: true, precision: f32}
    interactions: {omega_ref: 691.15}
    B:                                          # NOT `zeeman:` — see below
      Bz: {from: 0.0104, to: -2.0e-4, duration: 0.1037}
      theta: 0.0
      phi: 0.0
      q: 0.00909116
    sgpe:              {gamma: 0.05, T: 0.1, every: 1, seed: 42}
    photon_scattering: {Gamma_sc: 0.01, seed: 42}
    loss:              {gamma_dr: 0.02}
    seed_amplitude:    1.0e-4
    seed_k_cut:        0.6
    live_monitor:      {every: 50}
```

The runner builds `cb_sgpe`, `cb_pgp`, `cb_photon`, `cb_live` and pipes them through `_compose_callbacks` into a single `on_step`.

> **Two dead keys were removed from this example on 2026-08-04**, both verified
> against the live schema by feeding the block itself to `inspect_config_string`.
>
> **`save:`, not three flat keys.** `save_every` / `save_psi_snapshots` /
> `save_snapshot_precision` were folded into one `save:` block
> (`every` / `psi` / `precision` / `n_snapshots` / `compression`, per
> `SAVE_SCHEMA`). The flat spellings are rejected as unknown keys.
>
> **`B:`, not `zeeman:`.** This example carried `zeeman: {p: …, q: …}` until
> 2026-08-04. A step-level `zeeman:` key is refused by the schema outright —
> `step has step-level \`zeeman:\` key — not a valid user-facing field. Magnetic
> field belongs in the unified \`B:\` block` — so anyone who copied this block
> into a config got an error at load. The form above is taken from a config that
> runs (`runs/matsui_fig4b/fig4b_gsddioff_n35k_n32.yaml:115-122`), and it ramps
> the FIELD rather than `p`: magnitude (`Bz` / `B_mag` / `p_mv`) plus direction
> (`theta` / `phi`), with `q` auto-derived from |B|² unless given. The `p ≡ -g_F
> μ_B B` conversion lives once in `Units.bfield_to_p`.
