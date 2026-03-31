# SpinorBEC.jl

[![CI](https://github.com/anko9801/BEC-simulation/actions/workflows/ci.yml/badge.svg)](https://github.com/anko9801/BEC-simulation/actions/workflows/ci.yml)

Spin- $F$ Bose-Einstein condensate simulator solving the spinor Gross-Pitaevskii equation in 1D/2D/3D via split-step Fourier method. Arbitrary spin $F$ , N-dimensional, 21 built-in atom species ( $F{=}0$ to $8$ ).

## Quick Start

```bash
# Install
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Run a YAML config → JLD2 output → interactive HTML dashboard
julia --project=. examples/run.jl examples/configs/li7_ferromagnetic_quench.yaml
julia --project=. examples/visualize_dashboard.jl examples/configs/output/li7_ferromagnetic_quench.jld2

# Tests
julia --project=. -e 'using Pkg; Pkg.test()'
```

```julia
using SpinorBEC

grid = make_grid(GridConfig((128,), (20.0,)))
ip = InteractionParams(10.0, -0.5)   # c0, c1
trap = HarmonicTrap((1.0,))

# Ground state via imaginary-time propagation
gs = find_ground_state(; grid, atom=Rb87, interactions=ip, potential=trap,
    dt=0.005, n_steps=5000, tol=1e-10, initial_state=:polar)

# Real-time dynamics
ws = make_workspace(; grid, atom=Rb87, interactions=ip, potential=trap,
    zeeman=ZeemanParams(0.0, 0.1), sim_params=SimParams(dt=0.001, n_steps=5000),
    psi_init=gs.workspace.state.psi)
run_simulation!(ws)
```

## Physical Model

$$H = \sum_m \int \psi_m^{*} \left[ -\frac{\nabla^2}{2} + V - pm + qm^2 + c_0 n + c_1 \langle\mathbf{F}\rangle \cdot \mathbf{F} + H_{\mathrm{ddi}} + c_{\mathrm{LHY}} n^{5/2} + H_{\mathrm{Raman}} \right] \psi_m \, d\mathbf{r}$$

Dimensionless units: $\hbar = m = \omega_{\mathrm{ref}} = 1$ . Physical quantities via `Units` module.

| Term | Implementation |
|------|----------------|
| $c_0 n + c_1 \langle\mathbf{F}\rangle\cdot\mathbf{F}$ | Spin-independent + spin-dependent contact. $c_0, c_1$ from $a_0, a_2$ . Constraint mode $c_0 + F^2 c_1 = c_{\mathrm{total}}$ for unknown channels. |
| General- $F$ tensor | CG-based mean-field for all channels $S{=}0,2,\ldots,2F$ . Higher-rank $c_k$ ( $k{=}4,6,\ldots$ ) via 6j transform. Replaces $c_0/c_1$ /nematic when active. |
| DDI | $k$-space $Q_{\alpha\beta} = \hat{k}_\alpha\hat{k}_\beta - \delta/3$ convolution (6 FFTs). Zero-padded or quasi-2D (erfcx kernel). |
| LHY | Beyond-mean-field $\propto n^{5/2}$ with Lima-Pelster $Q_5(\varepsilon_{\mathrm{dd}})$ correction. |
| Raman / Losses | Two-photon coupling. $m$-dependent dipolar relaxation ( $m{=}{-}F$ stable). |

## Numerical Methods

**Split-step (Strang)**: `diag(dt/4) → SM(dt/4) → tensor(dt/4) → Raman(dt/4) → DDI(dt/2) → [mirror]` + full kinetic FFT. Substeps auto-skip when coupling $\approx 0$ . Leapfrog fusion merges adjacent half-steps in time loops.

**Spin mixing**: Rodrigues ( $D{=}3$ ), Euler angle decomposition with $F_y$ eigencache + cis recurrence ( $D{>}3$ ). **DDI**: Euler rotation for spin projection; quasi-2D via erfcx $z$-integrated kernel. **Tensor**: Per-point Hermitian $h_{mm'}$ → eigendecomposition → $e^{-ih\,dt}$ . **Kinetic**: Batched FFT for all $D$ components.

**Higher order**: Yoshida 4th-order ( $S_4 = S_2 \circ S_2 \circ S_2$ , 1.94x cost), embedded error estimator, PI controller adaptive $\Delta t$ . 2-5x speedup over adaptive Strang.

**Ground state**: ITP with energy + wavefunction convergence. Multistart (multiple initial states), constrained $\langle F_z \rangle$ (Lagrange), parameter continuation, phase boundary bisection.

**Large- $D$** ( $D{=}13$ , Eu151): `MVector`/`Matrix` instead of `SMatrix`, $O(D)$ raising/lowering. 167 GiB → 43 MiB alloc, 5.7x speedup on $32^3$ .

## Examples (`examples/configs/`)

| Config | Physics | Grid |
|--------|---------|------|
| `eu151_edh.yaml` | Einstein-de Haas: DDI spin relaxation, $J_z$ conservation (Matsui 2026) | 3D $64^3$ |
| `eu151_phase_diagram.yaml` | Phase diagram: quasi-2D DDI, $c_1/c_0$ sweep | 2D $64^2$ |
| `li7_ferromagnetic_quench.yaml` | Polar→ferro quench: strong $c_1$ spin mixing | 3D $32^3$ |
| `cr52_dipolar_spinor.yaml` | Tensor interactions: channel-resolved $c_4, c_6$ + DDI | 2D $32^2$ |
| `dy164_quantum_droplet.yaml` | DDI + LHY quantum droplet, $F{=}8$ (17 components) | 2D $32^2$ |

Pipeline: `run.jl` (YAML → JLD2) → `visualize_dashboard.jl` (JLD2 → HTML dashboard with 3D isosurface, populations, conservation).
