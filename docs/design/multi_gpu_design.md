# Multi-GPU per-run design — rotating_basis (Option γ)

**Status**: design only, no implementation. Multi-week project.

## Why

Single-H100 wall time at thesis-grade resolution:
- 48³ × 1000 ms × ε=1e-6 ≈ 4–5h
- 64³ × 200 ms × ε=1e-6 ≈ 4–5h
- 96³ × 200 ms × ε=1e-6 ≈ ~12h (extrapolated)

TSUBAME f_node has 4× H100 with NVLink. Splitting one large run across those GPUs collapses wall time by ~3.5× (linear scaling minus halo / collective overhead).

## Architecture

### Spatial decomposition

z-axis slabs across GPUs:
- GPU 0 owns `psi[:, :, 1:Nz/4, :]`
- GPU 1 owns `psi[:, :, Nz/4+1:Nz/2, :]`
- ...

(Rationale: z is the smallest spatial dim in pancake traps, so balances slabs evenly. For isotropic 64³, any axis works; pick z by convention.)

### Operators per substep

| substep | distribution behaviour |
|---|---|
| **Kinetic** (FFT) | needs all-axis FFT → cuFFTMp distributes data internally |
| **Spatial diagonal** (V + c0·n) | local to slab; halo not needed |
| **Local spin** (eigen-exact) | local; uniform D×D unitary, applied per-voxel |
| **DDI convolution** | global FFT-based → cuFFTMp again; mean-field Φ assembled per-rank |
| **Gauge** | local (uniform spin rotation, all voxels equivalent) |

Only the FFT-based substeps (kinetic + DDI) need cross-GPU communication.

### cuFFTMp wrapper

CUDA.jl's `cuFFTMp` exposure is preliminary (CUDA.jl 5+ partial). May need direct ccall via `CUDA.CUFFT.cufftMpCreate` etc. Reference: NVIDIA's cuFFTMp 11.x docs.

Alternative: roll our own slab→pencil decomposition with manual `MPI.Alltoall` between transforms (more code, less black-box).

### Mean-field assembly (DDI)

DDI convolution `Φ_α(r) = c_dd · ∫ Q_αβ(r-r') f_β(r') dr'` is naturally global. After cuFFTMp gives us `Φ̂(k)` distributed across GPUs, each rank holds its slab of `Φ`. The subsequent `apply_euler_5stage_fused!` uses local data only — no halo.

### Snapshot collection

Dashboard expects `psi` as a single array. Two options:
1. **Rank-0 gather**: `MPI.Gather!(local_psi → rank0_full_psi)` per snapshot; rank 0 writes JLD2.
2. **Distributed save**: each rank writes its slab to a separate JLD2 (`result_rank_NN.jld2`), dashboard reader concatenates on demand. More disk-efficient (no central serialisation), but requires dashboard-side re-assembly. Defer to future.

Recommend (1) for first implementation.

## Implementation plan

### Phase 1: Setup (1 week)

1. Add `multi_gpu: true` / `n_gpus: 4` to YAML schema for `kind: rotating_basis`.
2. `make_rotating_basis_ws_multi(grid, F, V_trap; n_gpus, comm)` — parallel sibling of the single-GPU constructor. Allocates per-GPU slab buffers via `MPI.Comm` rank-aware distribution.
3. Test: single-GPU mode reproduces `make_rotating_basis_ws` exactly.

### Phase 2: Operators (1 week)

4. `apply_kinetic_step_rotating_multi!` via cuFFTMp.
5. `apply_spatial_diagonal_step_multi!` (trivially parallel — local slab broadcast, no comm).
6. `apply_local_spin_step_multi!` (trivially parallel).
7. `apply_ddi_step_rotating_multi!` via cuFFTMp + local euler rotation.

### Phase 3: Validation (3 days)

8. Single-GPU vs multi-GPU comparison: at end of dynamics, gather `psi`s from both runs, compute overlap. Should be > 1 - ε_round.
9. Bench: 64³ × 200 ms, 1× vs 4× GPUs, measure wall + interconnect bandwidth utilisation.
10. Edge cases: prime number grids (`Nz % n_gpus ≠ 0`) — slab sizes must accommodate uneven split.

### Phase 4: Production (2 days)

11. SBATCH template for `f_node=1, n_gpus=4` runs.
12. Update `scripts/tsubame/generate_hires_scan.jl` to use multi-GPU when `n: [96, 96, 48]` or larger.
13. Snapshot collection via rank-0 gather.

## Open questions

- **NVLink vs PCIe**: cuFFTMp performance is sensitive to interconnect. TSUBAME f_node uses NVLink between H100 — should be near-optimal.
- **MPI.jl version**: TSUBAME may not have MPI module pre-loaded, may need bundled PMI / Slurm srun integration.
- **Memory budget**: at 4× H100 80GB = 320GB total. Should fit even 256³ × D=17 if needed (but those runs are 1-day scope, separate question).
- **Communication-vs-computation balance**: for small grids the cuFFTMp overhead may dominate. Empirical crossover likely around 64³ (educated guess).

## Reference

- cuFFTMp docs: https://docs.nvidia.com/cuda/cufft/cufftmp.html
- CUDA.jl multi-GPU patterns: https://cuda.juliagpu.org/stable/usage/multigpu/
- Cluster-side example: see PencilFFTs.jl + MPI.jl integration
