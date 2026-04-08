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

**YAML schema**: every parameter variation is expressed as a **config path override** — a dotted path into the raw YAML dict (e.g. `system.ddi.c_dd`, `ground_state.zeeman.p`) mapped to a new value. The runner applies the override, re-parses the experiment dict, and builds a fresh workspace.

```yaml
scan:
  zip:                                  # 1D sweep (all paths must agree on length)
    system.ddi.c_dd:      [0.0, 4000.0, 7647.0]
    ground_state.zeeman.p: [100.0, 10.0, 1.0]
  product:                              # N-dim Cartesian product
    system.interactions.c1_ratio:     [-0.02, -0.01, 0.0]
    ground_state.target_magnetization: [-6.0, -3.0, 0.0]
  comparison_runs:                      # run multiple recipes at every point
    - name: fl_vortex
      override: {ground_state.initial_state: spin_coherent, ...}
  continuation: true                    # reuse previous psi as initial condition
  auto_rotate_on_mz: true               # rotate by Δα when target Mz changes
```

Dynamics phases use the same override mechanism to switch DDI / interactions / etc between phases:

```yaml
sequence:
  - name: dynamics
    duration: 3.0
    dt: 0.0002
    override:
      system.ddi.enabled: true
      ground_state.zeeman.p: {from: 2.0, to: 0.0}   # ramp → TimeDependentZeeman
```

Phase-level `zeeman:` and `potential:` at the top of a phase block are auto-migrated into the override map at parse time for convenience. `ConstrainedJzScan` is the one exception to the override model (bisects on Ω at runtime).

**Noise**: both GS (`ground_state.temperature_ratio`) and phase noise (`phase.temperature_ratio` or `perturbation.temperature_ratio`) use Bose-Einstein thermal noise with `T/T_c ∈ (0, 1)`, driving `add_thermal_noise(psi, F; T_over_Tc, seed)`.

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
