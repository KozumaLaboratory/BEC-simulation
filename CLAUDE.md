# CLAUDE.md

Spin-F BEC simulator (split-step Fourier, 1D/2D/3D). Primary target: ¹⁵¹Eu (F=6, 13 components). Dimensionless units: ℏ=m=ω_ref=1.

## Commands

```bash
julia --project=. -e 'using Pkg; Pkg.test()'                     # all tests (~8600, ~5 min)
julia --project=. -e 'using SpinorBEC; include("test/test_X.jl")' # single test
julia --project=. -e 'using Pkg; Pkg.instantiate()'               # install deps
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=.                # GPU (WSL2)
```

## Project Structure

```
src/
├── foundation/      # types.jl, backend.jl, grid, spin matrices, CG coefficients
├── hamiltonian/     # interactions, potentials (zeeman, trap, DDI, raman, LHY)
├── solvers/         # ground_state (ITP), simulation (RTP), continuation, adaptive
├── workflow/        # experiments (YAML config), initialization, io, monitoring
└── analysis/        # energy, observables, phases, stability, diagnostics, TOF, vorticity
```

## Key Architecture

**Wavefunction**: `psi[x, y, ..., c]` — spatial dims first, spinor last. c=1→m=F, c=D→m=−F.

**Split-step** (`split_step.jl`): `V(dt/2) Coriolis(dt/2) K(dt) Coriolis(dt/2) V(dt/2)`.
Inner V is symmetric: `diag SM nematic tensor raman DDI raman tensor nematic SM diag`.
All substeps auto-skip when coupling ≈ 0.

**Two interaction paths** (auto-selected in `make_workspace`):
- **c₀/c₁ path**: diagonal(c₀) + spin_mixing(c₁) + nematic(c₂) + tensor(residual c₄,c₆,...)
- **Scattering-lengths path** (Cr52 etc.): tensor handles ALL channels, c₀=c₁=0

**Entry points**:
- `find_ground_state(;...)` — ITP (imaginary time propagation)
- `make_workspace(;...) |> run_simulation!` — RTP (real time propagation)
- `run_yaml("x.yaml")` — resumable YAML-driven experiment (directory-per-config, one jld2 per point, skips cached files on re-run)
- `load_config("x.yaml") |> run_config` — in-memory YAML run (no resume)
- `scan_continuation(; make_params, ...)` — parameter sweep with continuation
- `scan_phase_diagram_2d(; make_params, ...)` — 2D phase diagram

**YAML schema**: every parameter variation is expressed as a **config path override** — a dotted path into the raw YAML dict (e.g. `pipeline.0.ddi.c_dd`, `pipeline.0.zeeman.p`) mapped to a new value. The runner applies the override, re-parses the experiment dict, and builds a fresh workspace.

```yaml
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [64, 64, 64], box: [20.0, 20.0, 20.0]}
      interactions: {c_total: 4689, c1_ratio: 0.028}
      ddi: {c_dd: 7647, enabled: true}
      zeeman: {p: 100, q: 0}
      trap: [1.0, 1.0, 1.182]
      dt: 0.005
      n_steps: 20000
      tol: 1.0e-10
      backend: cuda

  - dynamics:                           # each phase is a separate step
      duration: 3.0
      dt: 0.001
      ddi: true
      zeeman: {p: {from: 100, to: 0.39}, q: 0}   # ramp → TimeDependentZeeman
      save_every: 50
      temperature_ratio: 0.1            # T/T_c thermal noise at phase start

  - analyze:                            # post-processing (any number of entries)
      - tomography: {axis: y, n_angles: 19}
      - faraday: {detuning: -64, axis: 3}
      - phase_classify: {}

scan:                                   # orthogonal to pipeline
  zip:                                  # 1D sweep (all paths must agree on length)
    pipeline.0.ddi.c_dd:    [0.0, 4000.0, 7647.0]
    pipeline.0.zeeman.p:    [100.0, 10.0, 1.0]
  product:                              # N-dim Cartesian product
    pipeline.0.interactions.c1_ratio:       [-0.02, -0.01, 0.0]
    pipeline.0.target_magnetization:        [-6.0, -3.0, 0.0]
  comparison_runs:                      # run multiple recipes at every point
    - name: fl_vortex
      override: {pipeline.0.initial_state: spin_coherent, ...}
  continuation: true                    # reuse previous psi as initial condition
  auto_rotate_on_mz: true              # rotate by Δα when target Mz changes
```

**Noise**: both GS (`temperature_ratio`) and phase noise (`dynamics.temperature_ratio`) use Bose-Einstein thermal noise with `T/T_c ∈ (0, 1)`, driving `add_thermal_noise(psi, F; T_over_Tc, seed)`.

**Continuation API** (direct-Julia, for benches/tests): `make_params(val) → NamedTuple` overrides any `find_ground_state` kwargs per sweep point. Legacy `make_interactions(val) → InteractionParams` also supported.

**GPU**: `import CUDA` before `using SpinorBEC` to load CUDA extension. Pass `backend=CUDABackend()`. WSL2 needs `LD_LIBRARY_PATH=/usr/lib/wsl/lib`.

## Conventions (do NOT "fix")

- **DDI**: c_dd=μ₀μ² (no 4π), Q_αβ=k̂_αk̂_β−δ_αβ/3 (no 1/(4π)), Q(k=0)=0. Chain self-consistent.
- **ITP Zeeman shift**: subtracts min(E_m) to prevent overflow. Not a bug.
- **Scalar LHY**: `@warn` present. Known approximation.
- **`save_state` elseif branch** (`ddi_padded.ddi.C_dd`): unreachable dead code (ddi_padded only exists when ddi≠nothing).
- **Odd-rank c_extra ignored**: `@warn` present. KU's c₃≠rank-3 tensor.
- **`compute_interaction_params_general_f` returns (0,0)**: by design (tensor_cache handles all).
- **`_YOSHIDA_W0 < 0`**: correct (backward middle substep, all operators time-reversible).

## ¹⁵¹Eu

F=6, g_J=1.9934, g_F≈1.163, μ≈6.977μ_B, a_s≈110a₀. 7 unknown scattering channels (S=0,2,...,12). Constraint: c₀+36c₁=4π(a_s/a_ho)N.

## Constraints

- All structs in `types.jl` (included first). New structs go there.
- Workspace has 18+ type params — never write explicit type params.
- D=13 (Eu): SMatrix heap-allocates. Use Matrix/MVector in hot loops.
- `Val(N)` from type parameter, not `Val(ndim::Int)`.
