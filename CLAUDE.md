# CLAUDE.md

Spin-F BEC simulator (split-step Fourier, 1D/2D/3D). Primary target: ¹⁵¹Eu (F=6, 13 components). Dimensionless units: ℏ=m=ω_ref=1.

## Commands

```bash
julia --project=. -e 'using Pkg; Pkg.test()'                     # all tests
julia --project=. -e 'using SpinorBEC; include("test/test_X.jl")' # single test
julia --project=. -e 'using Pkg; Pkg.instantiate()'               # install deps
```

## Key Architecture

**Wavefunction**: `psi[x, y, ..., c]` — spatial dims first, spinor last. c=1→m=F, c=D→m=−F.

**Split-step** (`split_step.jl`): `V(dt/2) Coriolis(dt/2) K(dt) Coriolis(dt/2) V(dt/2)`.
Inner V is symmetric: `diag SM nematic tensor raman DDI raman tensor nematic SM diag`.
All substeps auto-skip when coupling ≈ 0.

**Two interaction paths** (auto-selected in `make_workspace`):
- **c₀/c₁ path**: diagonal(c₀) + spin_mixing(c₁) + nematic(c₂) + tensor(residual c₄,c₆,...)
- **Scattering-lengths path** (Cr52 etc.): tensor handles ALL channels, c₀=c₁=0

**Entry points**: `find_ground_state(;...)` (ITP), `make_workspace(;...) |> run_simulation!` (RTP), `load_config("x.yaml") |> run_config`.

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
