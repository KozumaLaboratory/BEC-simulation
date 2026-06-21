# SpinorBEC.jl

[![CI](https://github.com/anko9801/BEC-simulation/actions/workflows/ci.yml/badge.svg)](https://github.com/anko9801/BEC-simulation/actions/workflows/ci.yml)

A general-purpose solver for the spinor Gross–Pitaevskii equation: arbitrary
spin $F$, 1D/2D/3D, contact + dipolar + LHY + Raman/Zeeman, on CPU or CUDA,
driven entirely from YAML.

## What it does well

- **Arbitrary $F$.** The whole stack (spin matrices, Clebsch–Gordan, tensor
  interactions, observables) works for any $F$, not just $F=1$ or $F=2$.
  Polyhedral state classification verified through $F=12$ (Paper #3);
  routine production runs are ¹⁵¹Eu ($F=6$) and ¹⁶⁴Dy ($F=8$).
- **Dipolar interactions are first-class.** $k$-space convolution in 6 FFTs,
  zero-padded or quasi-2D (erfcx kernel), with the spin-orbital coupling
  needed for Einstein–de Haas dynamics.
- **A rotating-basis solver for fast magnetostir.** When the magnetic-field
  direction $\hat B(t)$ varies on a timescale comparable to the Larmor
  precession, the standard spinor split-step blows up unless $\Delta t$ is
  pushed to absurd values. The `kind: rotating_basis` path co-rotates with
  $\hat B(t)$ and absorbs the Larmor phase analytically, so Klaus-2022-style
  protocols just work.
- **YAML in, results out.** A run is one YAML file: `pipeline:` (ground
  state → dynamics → analysis), `scan:` for sweeps, optional
  `calibration_history:` so lab-deck values (mV, mW) are written verbatim
  and parsed into physical units. Re-running a YAML resumes from the last
  completed point.
- **GPU is not an afterthought.** Both kinetic and DDI paths are CUDA-native
  (CUFFT, in-place broadcasts), with a mixed-precision F32 path for large
  grids.
- **A live dashboard.** `serve_dashboard` exposes runs in a React + WebGPU
  UI: 3D volume raymarch, per-component column densities, scan heatmaps,
  and a status panel for in-progress runs.

## Usage

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Run
julia --project=. -e 'using CUDA, SpinorBEC; run_yaml("runs/eu151_edh/config.yaml")'

# Browse
julia --project=. -e 'using SpinorBEC; serve_dashboard(8765; base_dir="runs")'
```

WSL2 GPU users: prepend `LD_LIBRARY_PATH=/usr/lib/wsl/lib`.

## Physics

$$H = \sum_m \int \psi_m^\ast \left[ -\tfrac{\nabla^2}{2} + V - p\,m + q\,m^2 + c_0 n + c_1 \langle\mathbf{F}\rangle \cdot \mathbf{F} + H_{\mathrm{ddi}} + c_{\mathrm{LHY}} n^{5/2} + H_{\mathrm{Raman}} \right] \psi_m \, d\mathbf{r}$$

Internal units are dimensionless ($\hbar = m = \omega_{\mathrm{ref}} = 1$);
the `Units` module handles physical conversion. Higher-rank tensor
interactions ($S = 4, 6, \ldots$) are built from Clebsch–Gordan coefficients,
and LHY uses the Lima–Pelster correction.

The solver dispatches on `kind:`:

- `spinor` — standard spinor GP. Static fields, weak-field phase transitions.
- `rotating_basis` — Larmor-following frame, for fast magnetostir and any
  protocol where $\hat B$ rotates faster than $1/\omega_{\mathrm{ref}}$.
- `binary` — two-component GP.

Ground states use imaginary-time propagation or LBFGS; dynamics use
Strang/Yoshida integrators, with Truncated Wigner sampling, SGPE,
photon scattering, and three-body loss available as composable per-step
callbacks.

## Repository layout

```
src/    Solvers, Hamiltonian terms, workflow, analysis
runs/   YAML configs (Klaus magnetostir, Einstein–de Haas, phase diagrams, …)
docs/   guides/ reference/ design/ theory/ research_notes/ (see docs/index.md)
test/   ~8600 tests, tiered (fast / ci / full)
dashboard/  React + WebGPU dashboard frontend
ext/    CUDA and Makie extensions
bench/  Benchmarks
```

`docs/reference/yaml_schema_reference.md` is the full YAML schema.
`CLAUDE.md` documents the internal conventions and architectural
boundaries used by the code. `docs/index.md` is the documentation map;
subsystem design notes live under `docs/design/`.

## Tests

```bash
SPINORBEC_TEST_TIER=fast julia --project=. -e 'using Pkg; Pkg.test()'

# Parallel across CPU cores (files split into N independent julia processes).
# ~2× faster on a 4-core box, more on bigger ones.
SPINORBEC_TEST_WORKERS=auto SPINORBEC_TEST_TIER=fast \
    julia --project=. -e 'using Pkg; Pkg.test()'
```

Tiers: `fast` (unit tests only), `ci` (fast + ITP/RTP integration),
`full` (everything; default), `physics` (analytic-validation only).
Per-push CI runs `fast`; the nightly workflow runs `full` with
`SPINORBEC_RUN_HEAVY_YAML=true` to also cover the gated YAML integration
blocks (see CLAUDE.md "Current cascade cost").

Runner knobs (all read by `test/runtests.jl`):

- `SPINORBEC_TEST_WORKERS` — `1` (default, serial in-process) or `N` / `auto`
  (parallel: files split into N independent julia processes — `run_chunk.jl`
  per chunk — aggregated by exit code; `auto` = one process per CPU thread).
  Both modes share one per-file run/fail path (`test/_run_files.jl`): every
  file runs under its own testset, all files run (one failure never hides
  another), and the run exits non-zero iff anything failed.
- `SPINORBEC_TEST_SKIP` — comma-separated relative paths to omit (e.g.
  CUDA-importing oracles on a machine whose driver probe crashes the
  precompiler).
- `SPINORBEC_TEST_TIMING=quiet` — suppress the per-file timing table that
  otherwise prints at the end of every run.
- `SPINORBEC_TEST_TIMEOUT` — per-chunk wall-clock cap in seconds under
  parallelism (default 1800; `0` disables). A hung chunk is killed and
  reported as failed (exit 124) rather than stalling the whole suite.
