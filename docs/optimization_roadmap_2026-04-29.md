# Optimisation roadmap — 2026-04-29

## Done today

- **DDI rotation cache `cis_PD` scratch + in-place 5-stage fused Euler.**
  `apply_euler_5stage_fused!` writes phase factors into a pre-allocated
  N×D Complex buffer instead of materialising a fresh CuArray per
  `cis.(...)` line. Five per-rotation broadcasts × 14 rotations per Y6
  step → zero GPU temporaries when caller supplies `cis_PD=`.
- **Kinetic / spatial-diagonal step phase scratches**
  (`kspace_phase_buf`, `xspace_phase_buf` on `RotatingBasisWS`) so
  `cis.(-dt·k²/2)` and `cis/exp(-(V+c0·n+γ·n^{3/2})·dt)` reuse a single
  device buffer. D-fold reduction in inner-loop temporaries.
- **R^T per-call alloc fix** in `_apply_rotation_to_spin_axis!` via
  `_ROTATION_RT_CACHE` (objectid-keyed, per-scratch-buffer).

The `split_step_rotating!` hot path now has **zero per-step CUDA
allocations** for rotating_basis; only the small (D×D) host-side
matrix work in `apply_local_spin_step!` remains, which is allocation-
free for D ≤ 32 via StaticArrays.

## Outstanding — actually feasible (1–3 day projects each)

### 1. CUDA Graph capture re-enable

Now that the per-step alloc churn is gone, `split_step_captured!`
should reach measure-bench parity with `split_step!` and beat it on
kernel-launch-bound regimes. Steps:

1. Run `bench_split_step_capture(ws; n_warmup=20, n_bench=200)` on the
   refactored code. Compare `t_plain_ms` vs `t_captured_ms`.
2. If captured ≥ plain, add a CUDA.jl version note to
   `ext/SpinorBECCUDAExt/gpu_graph.jl` and remove the `split_step_captured!`
   fallback.
3. If captured < plain still: profile via `nvprof` or `nsys` to find the
   remaining alloc site. Likely candidates:
   - DDI convolution path (`compute_ddi_potential!`) — currently uses
     pre-allocated `bufs.Phi_x/y/z`, but the rfft itself may allocate.
   - `apply_lab_spin_step!` (Phase III ref only, not in production).

ROI: 2–5× kernel-launch reduction on Klaus-scale runs (D=17, ε=1e-6).

### 2. Mixed precision F32 (Phase 3)

Phase 1 (`Grid{N,T}`) + Phase 2 (`make_fft_plans dtype=`) already in
tree. What's left: propagate `T` into `Workspace{...,T}` and 20+
downstream structs. For the rotating_basis path specifically, this
is more contained:

- `RotatingBasisWS{T, ...}` already has `T` parameter
- `make_rotating_basis_ws` already accepts `T`
- The blocker: GS / dynamics result Dicts use `Float64` everywhere
  (`Vector{Float64}`, `Array{ComplexF64,4}`)

**Quickest path** (rotating_basis only):
1. Add `dtype` kwarg to YAML schema for `kind: rotating_basis` ground
   state, default `f64`, accept `f32`.
2. Plumb to `make_rotating_basis_ws(grid, F, V_trap; …, dtype=Float64)`.
3. Verify GS converges to within `Float32` precision (~1e-6 in dE).
4. Verify dynamics conserves norm at ε=1e-6 (where dt is small enough
   to mask Float32 round-off).

ROI on H100: 2× memory bandwidth, ~2× FFT throughput on Tensor Cores
(if cuFFT's Tensor-Core path triggers, depends on grid alignment).
Risk: ε threshold for Klaus regime may need tightening to ε=1e-7 to
compensate for F32 step accumulation; offset by 2× per-step speed.

### 3. Multi-GPU per run

Single 64³ run = ~2.4× the per-step cost of 48³. Splitting across
2 GPUs would balance against the single-H100 wall budget and let us
push to 96³ if needed.

**Design (CUDA.jl + MPI.jl)**:
- Use `CUDA.devices()` to enumerate GPUs in the f_node
- Distribute spatial axis: each GPU owns a slab `psi[:, :, z_lo:z_hi, :]`
- FFT distribution via cuFFTMp (NVIDIA's multi-GPU FFT) — needed for
  the global FFT in kinetic + DDI steps
- Halo exchange not needed for FFT-based kinetic (each GPU does local
  data → cuFFTMp distributes across GPUs internally)
- Snapshot collection: `MPI.Gather!` to rank 0 for save

**Blockers**:
- cuFFTMp wrapper in CUDA.jl is preliminary; may need direct ccall
- Lab-frame Φ (DDI mean field) needs to be assembled across GPUs
- Snapshot output needs careful coordination (rank-0 writes; others
  send via MPI to avoid duplicate writes)

ROI: 4× wall time reduction with f_node 4× H100, but 1–2 weeks of
CUDA.jl work + testing.

## Outstanding — research-level (multi-week)

### 4. Higher-order integrator with regime-aware ε

Y6 ε-formula `dt = 0.1·(ε/T)^(1/6)` empirically fails for `p·F·dt > 300`
(audit 2026-04-28). The real fix isn't more order — it's a regime-aware
prefactor that tightens when commutator scales explode. Open question:

- Magnus-expansion-based pre-step adjustment (treats fast Larmor
  exactly within each step)
- Split the Hamiltonian as H = H₀(p, q) + H₁(everything else); use
  exact propagator for H₀ (already done by `apply_local_spin_step!`
  eigen-exact) and lower-order Trotter for H₁ vs H₀ commutator
- Verify against Phase III lab-vs-γ test (must keep overlap > 0.9999)

### 5. F=6 LHY closed-form

Current `SpinorLHYTable` covers (S=0, S=2) only — incomplete for F=6
(S=0..12). No published Lima-Pelster-style elliptic-integral form.
Multi-week research project to derive + validate.

## Reading order for the next session

1. `docs/thesis_batch_audit_2026-04-28.md` — ε threshold finding
2. `memory/eps_threshold_finding.md` — concise rule
3. This file
4. Run `julia --project=. -e 'using SpinorBEC; bench_split_step_capture(ws_klaus_scale)'`
   to measure where #1 actually stands now
