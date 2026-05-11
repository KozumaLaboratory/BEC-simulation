# Performance tuning guide

When to reach for which knob.

## Mixed precision (Float32 vs Float64)

Use `dtype = Float32` (kwarg to `make_grid`, `make_workspace`,
`find_ground_state`, ...; YAML knob coming) when:

- Grid ≥ 96³ and you're VRAM-bound on the GPU (F32 = ½ the memory)
- ITP convergence target is ≥ 1e-5 (F32 epsilon ~6e-8 sets a floor)
- You're prototyping a parameter sweep and the bias is acceptable

Stay on Float64 when:

- Final-result precision matters (publication numbers, supersolid critical
  point, etc.)
- LBFGS polish (sensitive to gradient noise at F32)
- Bogoliubov spectra near the instability boundary

Memory has the F32 / F64 regression test
(`test/test_mixed_precision_phase3.jl`) which asserts ITP energies agree
to ~1e-3 relative.

## Projected GP (k_cut)

Add `dynamics.projected_gp: {k_cut: K}` when:

- High-k aliasing artefacts are visible in the FFT spectrum (long
  dynamics, attractive interactions, droplet collapse onset)
- You want to suppress the thermal-cloud region of phase space and keep
  the simulation in the classical-field regime

Side effect: norm decreases as removed-mode mass leaks out. Track
`norms[end] / norms[1]` for sanity.

## Save_every / snapshot streaming

Snapshot every Nth step:

- `save_every: 5000` — minimal, ~30 frames per typical run
- `save_every: 1000` — ~150 frames, ~6 ms cadence on Klaus-style runs
- `save_every: 100`  — ~1500 frames, very dense (movie-quality)

Snapshot in-memory vs streamed:

- `save_psi_snapshots: false` (default) — snapshots accumulate in host
  RAM during dynamics. Caps you at ~100 frames for 64³ × 13-component
  Eu151 (~3.5 GB).
- `save_psi_snapshots: true` + `save_snapshot_precision: "f32"` — one
  frame at a time streamed to a scratch JLD2. Peak RAM ≈ one frame
  (~30 MB). Use this for long stir runs.
- `column_density_movie` reads both paths.

## DDI on/off

`ddi: {enabled: false}` cuts wall-clock per step by ~40-60% on Eu151
because the FFT-based convolution dominates. Drop DDI for setups where
the dipolar contribution is physically irrelevant (low-density, weak
ε_dd cases).

## `dt` rule of thumb

For DDI-strong species (ε_dd > 1, e.g. Dy164 / Eu151 native):

- ITP: `dt ≤ 0.001` (NaN at 0.005 due to overflow)
- Real time: `dt ≤ 0.002`

For weakly dipolar / scalar:

- ITP: `dt = 0.005-0.01`
- Real time: `dt = 0.005-0.01`

## Scan-loop GPU memory

If a long scan OOMs after ~100 points: confirm
`SpinorBEC._cuda_reclaim_callback[]` is set (via the CUDA extension's
__init__). Fix landed in commit 7769d84.

## Loss / SGPE callbacks

Each `dynamics.{sgpe,projected_gp,photon_scattering,loss}` block adds
~5-15% wall-clock per step. Composing all four ≈ 1.5x baseline.
Drop any unused block.

## Useful diagnostics

```julia
estimate_run_budget("path/to/config.yaml")
# Reports: VRAM, host RAM, disk per scan point, total disk
```

```julia
print_run_summary("runs/foo/")
# Per-point: energy, Mz, snapshot count, analyzers run
```

```julia
compare_runs("runs/baseline/", "runs/perturbed/"; tol = 1e-6)
# Diff energies / Mz across two scan dirs
```
