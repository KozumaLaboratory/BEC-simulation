# Performance tuning guide

> **FROZEN 2026-05-20.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

When to reach for which knob.

## Mixed precision (Float32 vs Float64)

`dtype: f32` halves VRAM and ~doubles GPU FFT throughput. Use it when the grid is VRAM-bound (≥ 96³) and ITP tolerance is ≥ 1e-5. Stay on F64 for publication numbers, LBFGS polish, and Bogoliubov near instabilities. Full rollout plan + scalar boundaries in `../design/mixed_precision_design.md`; operational constraints (rotating_basis path) in `CLAUDE.md` "Mixed precision". Regression: `test/test_mixed_precision_phase3.jl`.

## Projected GP (k_cut)

Add `dynamics.projected_gp: {k_cut: K}` when:

- High-k aliasing artefacts are visible in the FFT spectrum (long dynamics, attractive interactions, droplet collapse onset)
- You want to suppress the thermal-cloud region of phase space and keep the simulation in the classical-field regime

Side effect: norm decreases as removed-mode mass leaks out. Track `norms[end] / norms[1]` for sanity.

## Save_every / snapshot streaming

Snapshot every Nth step:

- `save_every: 5000` — minimal, ~30 frames per typical run
- `save_every: 1000` — ~150 frames, ~6 ms cadence on Klaus-style runs
- `save_every: 100`  — ~1500 frames, very dense (movie-quality)

Snapshot in-memory vs streamed:

- `save: {psi: false}` (default) — snapshots accumulate in host RAM during dynamics. Caps you at ~100 frames for 64³ × 13-component Eu151 (~3.5 GB).
- `save: {psi: true, precision: "f32"}` — one frame at a time streamed to a scratch JLD2. Peak RAM ≈ one frame (~30 MB). Use this for long stir runs.
- `column_density_movie` reads both paths.

## DDI on/off

`ddi: {enabled: false}` cuts wall-clock per step by ~40-60% on Eu151 because the FFT-based convolution dominates. Drop DDI for setups where the dipolar contribution is physically irrelevant (low-density, weak ε_dd cases).

## `dt` rule of thumb

For DDI-strong species (ε_dd > 1, e.g. Dy164 / Eu151 native):

- ITP: `dt ≤ 0.001` (NaN at 0.005 due to overflow)
- Real time: `dt ≤ 0.002`

For weakly dipolar / scalar:

- ITP: `dt = 0.005-0.01`
- Real time: `dt = 0.005-0.01`

## Scan-loop GPU memory

If a long scan OOMs after ~100 points: confirm `SpinorBEC._cuda_reclaim_callback[]` is set (via the CUDA extension's __init__). Fix landed in commit 7769d84.

## Loss / SGPE callbacks

Each `dynamics.{sgpe,projected_gp,photon_scattering,loss}` block adds ~5-15% wall-clock per step. Composing all four ≈ 1.5x baseline. Drop any unused block.

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
