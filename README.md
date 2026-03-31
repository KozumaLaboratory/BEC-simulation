# SpinorBEC.jl

[![CI](https://github.com/anko9801/BEC-simulation/actions/workflows/ci.yml/badge.svg)](https://github.com/anko9801/BEC-simulation/actions/workflows/ci.yml)

Spin- $F$ Bose-Einstein condensate simulator solving the spinor Gross-Pitaevskii equation in 1D/2D/3D via split-step Fourier method. Arbitrary spin $F$ , N-dimensional, fully parameterized.

## Features

| Category | Capabilities |
|----------|-------------|
| **Dynamics** | 2nd-order Strang splitting, Yoshida 4th-order, adaptive $\Delta t$ (PI controller), leapfrog fusion, checkpoint/restart |
| **Ground state** | Imaginary-time propagation, multistart search, constrained magnetization (Lagrange), parameter continuation, phase boundary bisection |
| **Contact** | $c_0 n + c_1 \langle\mathbf{F}\rangle\cdot\mathbf{F}$ , nematic $c_2\lvert A_{00}\rvert^2$ , general- $F$ tensor (CG-based, all $S{=}0,2,\ldots,2F$ channels, 6j transform for $c_k$ ) |
| **DDI** | $k$-space $Q_{\alpha\beta}$ convolution (6 FFTs), zero-padded, quasi-2D kernel (erfcx), secular approximation |
| **Other terms** | LHY $\propto n^{5/2}$ (Lima-Pelster $Q_5$ for DDI), Raman coupling, dipolar relaxation losses |
| **Potentials** | Harmonic, gravity, crossed dipole (Gaussian beams), laser beams, composites; ABCD optics |
| **Observables** | Density, magnetization, spin vector, energy decomposition, pair amplitudes $A_{SM}$ , phase classification, nematic tensor, structure factor $S(k)$ , multipole spectrum, BdG dispersion, TOF/Stern-Gerlach imaging, Berry curvature, vorticity, skyrmion charge, Majorana stars, $Q_6$ |
| **Diagnostics** | Conservation validation, splitting error (Richardson), healing lengths, power spectrum, stability analysis |
| **Infrastructure** | YAML configs (declarative multi-phase), 21 built-in atoms, Unitful.jl support, JLD2 I/O, Makie/PlotlyJS extensions, TimerOutputs profiling |

## Installation

```julia
using Pkg; Pkg.develop(path="path/to/BEC-simulation")
```

Julia 1.10+. Dependencies: FFTW, StaticArrays, JLD2, YAML, SpecialFunctions, TimerOutputs, Unitful.

## Quick Start

### Julia API

```julia
using SpinorBEC

grid = make_grid(GridConfig((128,), (20.0,)))

# Ground state (imaginary-time propagation)
gs = find_ground_state(;
    grid, atom=Rb87,
    interactions=InteractionParams(10.0, -0.5),
    potential=HarmonicTrap((1.0,)),
    dt=0.005, n_steps=5000, tol=1e-10, initial_state=:polar,
)

# Real-time dynamics
ws = make_workspace(;
    grid, atom=Rb87,
    interactions=InteractionParams(10.0, -0.5),
    potential=HarmonicTrap((1.0,)),
    zeeman=ZeemanParams(0.0, 0.1),
    sim_params=SimParams(dt=0.001, n_steps=5000),
    psi_init=gs.workspace.state.psi,
)
run_simulation!(ws)
```

### YAML Config

```yaml
experiment:
  version: 3
  name: "Li7 ferromagnetic quench"
  type: dynamics

  system:
    atom: Li7
    grid: { n_points: [32, 32, 32], box_size: [8.0, 8.0, 8.0] }
    interactions: { c0: 30.0, c1: -100.0 }

  ground_state:
    dt: 0.005
    n_steps: 5000
    tol: 1.0e-10
    initial_state: polar
    zeeman: { p: 0.0, q: 20.0 }
    potential: { type: harmonic, omega: [1.0, 1.0, 1.0] }

  sequence:
    - name: quench
      duration: 0.5
      dt: 0.001
      save_every: 25
      zeeman: { p: 0.0, q: { from: 20.0, to: 0.0 } }
    - name: hold
      duration: 5.0
      dt: 0.001
      save_every: 100
      integrator: adaptive
      zeeman: { p: 0.0, q: 0.0 }
```

```bash
# Run single config or entire directory
julia --project=. examples/run.jl examples/configs/li7_ferromagnetic_quench.yaml
julia --project=. examples/run.jl examples/configs/  # runs all .yaml files

# Generate interactive HTML dashboard from JLD2 output
julia --project=. examples/visualize_dashboard.jl examples/configs/output/li7_ferromagnetic_quench.jld2
```

## Physical Model

$$H = \sum_m \int \psi_m^{*} \left[ -\frac{\nabla^2}{2} + V - pm + qm^2 + c_0 n + c_1 \langle\mathbf{F}\rangle \cdot \mathbf{F} + H_{\mathrm{ddi}} + c_{\mathrm{LHY}} n^{5/2} + H_{\mathrm{Raman}} \right] \psi_m \, d\mathbf{r}$$

Dimensionless units: $\hbar = m = \omega_{\mathrm{ref}} = 1$ throughout. Physical quantities via `Units` module and `DimensionlessScales`.

**Interaction parameters**: $c_0, c_1$ from $s$-wave scattering lengths ( $a_0, a_2$ ). General $F$ : channel couplings $g_S = c_0 + c_1[S(S{+}1) - 2F(F{+}1)]/2$ , with optional higher-rank $c_k$ ($k{=}4,6,\ldots$) via 6j transform. Constraint mode: $c_0 + F^2 c_1 = c_{\mathrm{total}}$ with `c1_ratio` for unknown-channel atoms (Eu151).

## Numerical Methods

**Split-step (Strang)**: Symmetric nested splitting — `diag(dt/4) → SM(dt/4) → nematic/tensor(dt/4) → Raman(dt/4) → DDI(dt/2) → [mirror]` — sandwiching full kinetic FFT step. Tensor step replaces SM + nematic when `TensorInteractionCache` is active. Substeps auto-skip when coupling ≈ 0.

**Spin mixing**: Rodrigues ( $D{=}3$ ), Euler angle decomposition with $F_y$ eigencache + cis recurrence ( $D{>}3$ ).

**DDI**: $Q_{\alpha\beta}(\mathbf{k}) = \hat{k}_\alpha\hat{k}_\beta - \delta_{\alpha\beta}/3$ , Euler rotation for spin projection. Optional zero-padding (2x per dim). Quasi-2D: erfcx-based $z$-integrated kernel.

**Tensor**: CG-based $h_{mm'} = \sum_{S,M} g_S \langle m|SM\rangle\langle m'|SM\rangle^* \rho_{SM}$ per grid point → eigendecomposition → $e^{-ih\,dt}$ .

**Yoshida 4th-order**: $S_4 = S_2(w_1 dt) \circ S_2(w_0 dt) \circ S_2(w_1 dt)$ , 1.94x cost, embedded Strang error estimator. Adaptive: PI controller, 2-5x speedup over adaptive Strang.

**Kinetic**: Batched FFT (single FFT/IFFT for all $D$ components).

**Large- $D$ optimizations** ( $D{=}13$ , Eu151): `MVector` scratch + `Matrix` eigen (not `SMatrix`), $O(D)$ raising/lowering for $\langle\mathbf{F}\rangle$ . Result: 167 GiB → 43 MiB alloc, 5.7x speedup on $32^3$ .

## Examples

| Config | Physics | Grid |
|--------|---------|------|
| `eu151_edh.yaml` | Einstein-de Haas effect: DDI-driven spin relaxation, $J_z$ conservation (Matsui et al. 2026) | 3D $64^3$ |
| `eu151_phase_diagram.yaml` | Phase diagram: quasi-2D DDI, $c_1/c_0$ sweep with continuation | 2D $64^2$ |
| `li7_ferromagnetic_quench.yaml` | Polar→ferro quench: strong $c_1$ spin mixing, domain formation | 3D $32^3$ |
| `cr52_dipolar_spinor.yaml` | Tensor interactions: channel-resolved $c_4, c_6$ + DDI | 2D $32^2$ |
| `dy164_quantum_droplet.yaml` | Quantum droplet: DDI + LHY stabilization, $F{=}8$ (17 components) | 2D $32^2$ |

**Pipeline**: `run.jl` (YAML → JLD2) → `visualize_dashboard.jl` (JLD2 → interactive HTML with 3D isosurface, population dynamics, conservation plots).

**Benchmarks** (`examples/bench/`): `bench_eu151.jl` (3D profiling), `bench_yoshida.jl` (integrator comparison), `convergence_test.jl` (dt/dx convergence).

## Testing

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```
