# GPU performance architecture — P0-P5

> **FROZEN 2026-06-06.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

Status: adopted 2026-06-06. The speed layer over the frozen correctness
core (`hamiltonian_layered_architecture.md`). Per the freeze
discipline, every P-stage decision below is either (a) decided
analytically where analysis suffices (P0), or (b) a hypothesis gated on
the measured baseline — never a vibe.

Correctness gates for this layer (arch doc §4): dt-valley slopes
(propagator), fused == unfused tight-tol, F32 == F64 (~1e-5),
CPU == GPU tolerance parity per term, alloc == 0 in hot loops,
resume == straight. **Correctness gates ⊥ performance gates** (≤
baseline +2% for replacements; improvement targets per stage below).

## Measured baseline (2026-06-06)

`bench/baseline_hamiltonian_faces.jl` — Eu preset 24³ × D=13, secular
DDI, RT, RTX 5070 Ti (WSL2) + CPU. Median of 20:

| face | CPU | GPU | reading |
|---|---|---|---|
| `energy_decomposition` | 9.5 ms / **16.3 MB alloc** | 7.9 ms / 8.2 MB host | GPU path is the audited host-copy fork — barely 1.2× CPU |
| `energy_gradient!` | 25.4 ms / **33.9 MB alloc** | 13.0 ms / 9.4 MB host | 33.9 MB/call ≈ the audit's static estimate (~2.9 MB × ~12 terms) — confirmed by measurement |
| `split_step!` | 32.3 ms / 3.4 KB | **8.4 ms** / 1.1 MB host | legacy propagator is alloc-clean on CPU; GPU only 3.8× — launch-overhead dominated (consistent with the 11-13% util memo) |

Ranked implications:

1. **LBFGS is the measured hot spot with a pure-win fix.** One LBFGS
   iteration ≈ gradient + energy ≈ 21 ms GPU but ~18 MB/call host
   churn (CPU: 50 MB/call) — at M1-scale 15 000-step sweeps this is
   GC-pressure dominated. Registry faces, not the propagator, are
   where the allocation tax lives.
2. **GPU split-step at 24³ is launch-bound, not compute-bound.** 8.4
   ms/step with ~1 ms-class FFT work ⇒ the fix is batching (P3), not
   kernel micro-optimization.
3. **Device-resident energy kills the fork AND the copy** — the
   correctness goal (one energy orchestrator) and the speed goal point
   at the same change (P2).

## P0 — memory layout: CONFIRMED `(nx, ny, nz, 13[, N_cells])`

Spatial-first is the existing codebase-wide convention; the burden of
proof is on migration, and the analysis gives migration nothing:

- **FFT**: each component transform is unit-stride; cuFFT batches over
  the trailing spin axis (batch = 13, dist = N). Spin-fastest would
  make every FFT stride-13 or cost two transpose passes per FFT pair.
- **Uniform spin transforms** (spatially-constant 13×13 U): reshape
  `(N × 13)` ⇒ `ψ · Uᵀ` — a **single dense GEMM**, BLAS3, no batching
  machinery at all.
- **Site-varying spin ops** (DDI Euler rotation, fused diagonal,
  Raman): one thread per site; thread t loads `ψ[t + c·N]` — for
  fixed c, consecutive threads hit consecutive addresses = fully
  coalesced.
- **N_cells**: trailing cell axis extends every pattern with zero
  migration (FFT batch 13·N_cells; GEMM (N·cells × 13); per-site
  kernels thread over N·cells). Runtime axis, never a type parameter.

Honest constraint: **register pressure at D=13** — a per-site kernel
holding the full spinor needs ~26 F64 registers for ψ alone; in/out +
matrix application pushes 50-100 regs/thread ⇒ occupancy-limited.
This motivates (i) F32 stepping (halves it, P5), (ii) shared-memory
staging of 13×13 matrices / spin-tiling in kernel design (P4).

## P1 — allocation elimination in the registry faces

Measured: 33.9 MB/call (gradient) + 16.3 MB/call (energy) on CPU.
Cause (audited): 9/14 terms lack ctx-aware `add_gradient!` (per-call
`similar(psi)` ≈ 2.9 MB each at 24³×13, including inactive terms that
allocate before short-circuiting); `EnergyContext` is dead scaffolding
with zero callers; Kinetic ctx path does an uncached `_to_device` H2D
copy per call.

Work: complete ctx-aware overloads for the 9 terms; gate-then-allocate
ordering; revive `EnergyContext` (or fold energy into one
GradientContext-style pass); cache the device k² array.
Target: ≤ 100 KB/call on both faces. Gate: identity-class agreement
with current outputs + the shipped FD/driver pins.

**SHIPPED 2026-06-06 (CPU)** — measured after:

| face | before | after |
|---|---|---|
| `energy_decomposition` | 9.5 ms / 16.3 MB | **5.5 ms / 0.99 MB** (1.75× / 16×) |
| `energy_gradient!` | 25.4 ms / 33.9 MB | **10.8 ms / 1.28 MB** (2.35× / 26×) |
| LBFGS iteration (E + ∇E) | ~35 ms | **~16 ms** (2.1×) |

Mechanism: derived (`similar(psi)` + `apply_operator!` + `dot`) face
bodies replaced by fused zero-alloc loops / direct broadcast
accumulation — **legitimised by the master oracle** (267 per-term
identity assertions); the device-generic derived bodies remain as the
`AbstractArray` methods (GPU parity 133/133). Gate-before-allocate for
TransverseZeeman / MagneticGradient / LightShift / DDI. `EnergyContext`
revived scratch-backed and wired into `energy_breakdown_via_registry`
(its struct definition was latently broken — `psi_host` typed at the
spatial dimension count — undetectable while it had zero callers).
Residual ~1 MB/call (registry rebuild + Coriolis/LHY non-ctx energies)
left for a follow-up pass; the ≤100 KB target stands. GPU faces
unchanged (P2). Incidentally fixed: App. A defect 7 (GPU energy
NamedTuple lacked `:loss` — every GPU run of the per-term parity gate
had been failing at the shape assertion, masking an unreachable
`LinearAlgebra.I` import bug in the test itself; both fixed, parity
expanded 98 → 133 assertions).

## P2 — device-resident energy (one orchestrator, no copy)

`_energy_decomposition_gpu` copies ψ to host and recomputes on CPU
(7.9 ms) — the same parallel-statement fork the 2026-06-04 freeze came
from. Device-generic energy bodies (broadcast/mapreduce, the 9
NOT-YET scalar loops from cb3cd764) delete `ext gpu_energy.jl` and the
PCIe round-trip. Target: ≤ 2 ms GPU. Gate: per-term CPU == GPU parity
(existing test) + dumb-vs-fast when the dumb reference lands.

## P3 — N_cells batching (Lever 1)

The measured launch-bound regime (8.4 ms/step at ~1 ms compute) is the
known 11-13% util problem; the fix is amortizing launches over cells,
not faster kernels. Design exists (`lever1_batched_cell_sweep_design`):
N_cells runtime axis on ψ/density/zeeman/Ω, per-cell θ. Expected
3-4× sweep throughput (30-cell sweep 3 h → ~50 min). Gate:
batched == per-cell-loop identity + per-cell conservation.

## P4 — alloc == 0 hot loops + KernelAbstractions single-sourcing

GPU split-step churns 1.1 MB host/step (registry rebuild, waveform
evals, scalar paths) — audit + eliminate (alloc == 0 gate per step).
KA migration of the hand-rolled CUDA kernels (order: Euler → spin
mixing → singlet → Raman), each behind its kernel-parity gate —
collapses the most expensive duplication (CPU-vs-GPU), bringing the
effective statement count per term to ~2 (dumb + KA kernel).

## P5 — F32 stepping + F64 reductions on the main path

Extend the rotating-basis mixed-precision pattern (`docs/design/
mixed_precision_design.md`) to the main split-step: F32 state +
pointwise ops, F64 for reductions / conserved quantities / oracle
evaluation. Doubles effective memory bandwidth and halves the P0
register pressure. Gates: F32 == F64 trajectory parity (~1e-5),
conserved quantities in F64, all correctness oracles stay F64.

## Priority by measured ROI

**P1 → P2 → P3 → P4 → P5.** P1 is the M1-critical pure win (sweeps
are LBFGS-bound); P2 aligns correctness and speed in one change; P3 is
the only fix for the launch-bound regime; P4/P5 compound on top.
Re-run `bench/baseline_hamiltonian_faces.jl` after each stage and
record the table here — numbers in this doc are the gate references.
