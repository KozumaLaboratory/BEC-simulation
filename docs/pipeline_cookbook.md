# Pipeline cookbook

Common YAML patterns. Each block is a self-contained excerpt — combine
them in your own configs. For complete runnable scenarios see
`runs/samples/` and `runs/eu151_*/config.yaml`.

## Basic ground state

```yaml
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [64, 64, 64], box: [20.0, 20.0, 20.0]}
      interactions: {N_atoms: 50000, omega_ref: 691.15, c1_ratio: 0.028}
      ddi: {enabled: true}
      zeeman: {p: 1.0, q: 0.1}
      potential: {type: harmonic, omega: [1.0, 1.0, 1.1818]}
      dt: 0.005
      n_steps: 10000
      tol: 1.0e-7
      initial_state: polar          # or any state_zoo type
      backend: cuda
```

## Two-stage GS: ITP → LBFGS polish

```yaml
pipeline:
  - ground_state:
      method: itp
      atom: Eu151
      ...
      n_steps: 10000
  - ground_state:
      method: lbfgs
      n_steps: 300
      tol: 1.0e-9
```

## Real-time dynamics with multi-knob composition

```yaml
- dynamics:
    duration: 10.0
    dt: 0.005
    save_every: 100
    save_psi_snapshots: true
    save_snapshot_precision: "f32"
    interactions: {omega_ref: 691.15}      # required when zeeman uses Level 1/2
    zeeman: {p: {from: 1.0, to: 0.5}, q: 0.1}
    sgpe:              {gamma: 0.05, T: 0.1, every: 1, seed: 42}
    projected_gp:      {k_cut: 6.0, every: 1}
    photon_scattering: {Gamma_sc: 0.01, seed: 42}
    loss:              {gamma_dr: 0.02, K3_per_m_si: ["1.5e-30 m^6/s"] × D}
    pulse_sequence:    [...]
    live_monitor:      {every: 50}            # writes <run>/_live_status.json
```

All `on_step` callbacks (sgpe / projected_gp / photon_scattering /
pulse_sequence / live_monitor) compose freely; `_compose_callbacks`
chains them per dynamics step.

## Live monitoring (dashboard hook)

```yaml
- dynamics:
    duration: 30.0
    dt: 0.005
    save_every: 100
    live_monitor: {every: 50}      # or simply `live_monitor: true`
```

Each `every`-th step the runner atomically writes
`<run_dir>/_live_status.json` (step, t, energy, norm, populations).
The dashboard polls `/api/live/list` to surface the run and
`/api/live/<run>` to stream the JSON; in the React UI the
`LiveStatusPanel` in the App header renders it. Disable with
`live_monitor: false` (or omit).

## Symmetry-breaking seed (EdH)

```yaml
- dynamics:
    seed_amplitude: 1.0e-4
    seed_k_cut: 0.6              # k-space lowpass — concentrates noise
                                  # in long-wavelength unstable modes
```

`seed_k_cut` is optional. Without it the seed is unfiltered white
noise; with it, FFT components above `|k| = seed_k_cut` are zeroed
before injecting into the dominant transverse component. For Eu151 EdH
a typical choice is `seed_k_cut ≈ 1/ξ_h`. Used in `runs/eu151_edh/`.

## 1D scan over a YAML path

```yaml
pipeline:
  - ground_state: ...
  - analyze:
      - phase_classify: {}

scan:
  product:
    pipeline.0.zeeman.p: [0.0, 0.5, 1.0, 2.0, 5.0, 10.0]
  continuation: false
```

## 2D phase diagram

```yaml
scan:
  product:
    pipeline.0.zeeman.p: [0.0, 0.1, 1.0, 10.0]
    pipeline.0.zeeman.q: [-1.0, -0.3, 0.0, 0.3, 1.0]
```

`product` takes the Cartesian product. Use `zip` for paired axes of equal
length.

## Ensemble at fixed point (different noise seeds)

```yaml
scan:
  comparison_runs:
    - {name: seed_a, override: {pipeline.1.noise_seed: 11011}}
    - {name: seed_b, override: {pipeline.1.noise_seed: 22022}}
    - {name: seed_c, override: {pipeline.1.noise_seed: 33033}}
```

## Multi-step movie (Klaus 2022 style)

```yaml
pipeline:
  - ground_state: ...
  - dynamics: {duration: 6.28,  ...}        # tilt
  - dynamics: {duration: 15.7,  ...}        # spin-up
  - dynamics: {duration: 314.0, ...}        # magnetostir
  - analyze:
      - column_density_movie:
          axis: 3
          output_dir: runs/foo/frames
          multi_step: true                   # walk every dynamics step
```

Output (PlotlyJS removed 2026-04-26):

- `<output_dir>/columns.jld2` — one Float32 2D array per frame keyed
  `frame_NNNNN` (global frame counter across all phases).
- `<output_dir>/manifest.json` — `n_frames`, `n_phases`, `axis`,
  `frame_keys`, `times` (with each phase's t offset added),
  `phase_indices`, `archive` (basename of the JLD2). The dashboard /
  external notebooks render PNGs on demand from this archive.

## Calibration: lab-unit YAML

```yaml
calibration_history:
  - date: "2026-04-01"
    coil_strong: {gauss_per_mv: 0.40, gauss_offset: 0.05}
    fort:        {sqrt_coeffs_hz: [450, 450, 600]}
  - date: "2026-04-15"
    coil_strong: {gauss_per_mv: 0.42, gauss_offset: 0.04}
    fort:        {sqrt_coeffs_hz: [445, 445, 595]}

target_date: "2026-04-08"   # optional, defaults to today

pipeline:
  - ground_state:
      atom: Eu151
      ...
      zeeman:
        p_mv: 2.5             # → strong coil → "X Gauss" → bfield_to_p
        coil_mode: strong
        q: 0.1
      potential:
        type: harmonic
        fort_power_mw: [50, 50, 100]   # → omega: ["X Hz", ...]
```

## Self-bound droplet (LHY + DDI, no trap)

```yaml
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [64, 64, 64], box: [30.0, 30.0, 30.0]}
      interactions: {N_atoms: 50000, omega_ref: 691.15, c1_ratio: 0.0, c_lhy: 1135.0}
      ddi: {enabled: true}
      zeeman: {p: 0.0, q: 0.0}
      potential: {type: none}            # ← key: no external trap
      initial_state: polar
      ...
  - analyze:
      - droplet_profile: {}
```

## Topology / texture observables

```yaml
- analyze:
    - winding_field:    {component: 1, threshold: 1.0e-6}
    - monopole_charge:  {smooth: false}
    - non_abelian_homotopy:
        loop_pts: [[6, 8], [10, 8], [10, 10], [6, 10], [6, 8]]
        component: 1
    - skyrmion_detect:  {threshold: 0.05, radius: 2}
    - synthetic_dim:    {}
    - bogoliubov:       {k_max: 8.0, n_k: 100, directions: auto}
    - bogoliubov_mode:  {k_max: 8.0, n_k: 200}   # eigenvector + per-m weight
```

## Resumable scan

`run_yaml` writes one `point_NNN.jld2` per scan point. Re-running the
same YAML skips already-written points. Delete an individual file to
force that point to recompute. Partial-failure resilience: each scan
point's GS+dynamics is independent; one failure doesn't poison neighbours.

## Dry-run preview

```julia
yaml_str = run_yaml("path/to/config.yaml"; dry_run = true)
```

Prints the post-calibration / post-validation YAML to stdout **and
returns it as a String** without touching the GPU. Useful to capture
the expanded YAML for diff'ing or to assert in tests.
