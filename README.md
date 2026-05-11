# SpinorBEC.jl

[![CI](https://github.com/anko9801/BEC-simulation/actions/workflows/ci.yml/badge.svg)](https://github.com/anko9801/BEC-simulation/actions/workflows/ci.yml)

A general-purpose solver for the spinor Gross–Pitaevskii equation: arbitrary
spin $F$, 1D/2D/3D, contact + dipolar + LHY + Raman/Zeeman, on CPU or CUDA,
driven entirely from YAML.

## What it does well

- **Arbitrary $F$.** The whole stack (spin matrices, Clebsch–Gordan, tensor
  interactions, observables) works for any $F$, not just $F=1$ or $F=2$.
  Tested through $F=8$ (¹⁶⁴Dy, 17 components) and routinely run for ¹⁵¹Eu
  ($F=6$).
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
web/    React + WebGPU dashboard
ext/    CUDA and Makie extensions
bench/  Benchmarks
```

`CLAUDE.md` is the full YAML schema reference and internal conventions.
`docs/index.md` is the documentation map; subsystem design notes live
under `docs/design/`.

## Tests

```bash
SPINORBEC_TEST_TIER=fast julia --project=. -e 'using Pkg; Pkg.test()'
```

Tiers are `fast`, `ci`, `full`. CI runs all of them.
