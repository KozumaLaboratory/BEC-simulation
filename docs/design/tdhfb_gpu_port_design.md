# TDHFB GPU port — design document (Phase 5)

> **FROZEN 2026-05-12.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

**Date**: 2026-05-12
**Status**: design — implementation post-修論 / D-thesis Year 1 Q3 candidate.
**Predecessors**:
  - `docs/design/tdhfb_pilot_design.md` (formalism + 6-phase plan)
  - `docs/design/dthesis_year1_roadmap.md` (Year 1 Q3 schedule)
  - `docs/design/mixed_precision_design.md` (F32 plumbing pattern)
**Current implementation** (CPU production, commit `1412e49`):
  - `src/foundation/types/tdhfb_state.jl` — `TDHFBState{N, A, B, T}` (mutable, 5 fields)
  - `src/hamiltonian/tdhfb/strang_step.jl` — `tdhfb_strang_step!` (V/2 → HF/2 → K → HF/2 → V/2)
  - `src/hamiltonian/tdhfb/hartree_fock_matrix_generic.jl` — `hf_matrix_generic!`
  - `src/hamiltonian/tdhfb/channel_kernel.jl` — rank-4 V tensor builder
  - `src/hamiltonian/tdhfb/pair_potential.jl` — Δ pair source
  - `src/hamiltonian/tdhfb/y4_midpoint_step.jl` — Y4-midpoint outer integrator

This document is the **Phase 5** addendum (= the missing GPU port lane in the original
`tdhfb_pilot_design.md`). It is a design-only artifact; no source files are modified.

---

## 1. Performance target + cost model

### 1.1 Current CPU measurements (commit `1412e49`)

Per-step wall clock for `tdhfb_strang_step!` on F=6 Eu151 (D = 13), single CPU thread:

| Grid | Per-step (s) | Dominant cost          | Notes |
|------|--------------|------------------------|-------|
| F=1  16³ | 0.065     | HF substep (Padé `exp`) | 2D = 6, BdG cost negligible |
| F=6  16³ | 1.9       | HF substep              | 2D = 26, BdG dominates by 20× |
| F=6  32³ | ~16       | HF substep              | linear extrapolation (8× voxels) |
| F=6  64³ | ~130      | HF substep              | 64× voxels |

Empirical scaling: per-step cost is `O(N_voxels × D³)` for the HF substep,
`O(N_voxels × D × log N_voxels)` for the kinetic step (D parallel FFTs). At
F=6 16³ the BdG matrix-exp dominates the FFT by ≈ 30×.

### 1.2 Production targets

Three target regimes:

| Regime              | Grid     | T (ω⁻¹) | dt    | Steps   | CPU wall            |
|---------------------|----------|---------|-------|---------|---------------------|
| F=6 Eu post-quench  | 16³      | 5       | 0.001 | 5 000   | 2.6 hr              |
| F=6 Eu post-quench  | 32³      | 10      | 0.001 | 10 000  | **44 hr** ← critical |
| F=6 Eu post-quench  | 64³      | 10      | 0.001 | 10 000  | 360 hr (= 15 days)  |
| Scenario sweep      | 32³ × 10 | 10      | 0.001 | 100 000 | **18 days CPU**     |

The 32³ × 10-config sweep is the production blocker for the TDHFB pilot in
`tdhfb_pilot_design.md` §"Expected outcomes" (three scenarios: stabilize /
renormalize / diverge). 18 days serial CPU is incompatible with the D-thesis
Year 1 Q3 schedule.

### 1.3 GPU speedup target

| Stage                      | CPU 32³ F=6 | GPU 32³ F=6 target | Source of speedup                |
|----------------------------|-------------|--------------------|----------------------------------|
| K (kinetic)                | ~0.4 s      | 15 ms              | cuFFT batched mode               |
| V (trap)                   | ~0.05 s     | 0.5 ms             | trivial elementwise              |
| HF substep — channel build | ~3 s        | 50 ms              | rho/kappa-as-CuArray broadcasts  |
| HF substep — BdG exp       | ~12 s       | 250 ms             | per-voxel Padé in shared mem     |
| HF substep — R update      | ~0.5 s      | 20 ms              | batched gemm (2D × 2D × N_vox)   |
| **Total / step**           | **~16 s**   | **~0.34 s**        | ≈ **47×**                        |

Equivalent ensemble cost:
  - 32³ × 10 000 steps × 0.34 s/step ≈ **1.0 hr / run** (vs 44 hr CPU)
  - 32³ × 10-config sweep ≈ **10–15 hr / ensemble** (vs 18 days CPU)

The 30–60× speedup target is conservative; the optimistic case (well-fused
Padé on RTX 4090, F32) approaches **100×**. For the design budget we plan
against **40× minimum, 60× target**.

### 1.4 Cost model derivation (for capacity planning)

Per voxel per step, the BdG matrix-exp is the cost driver:

  - `expm(-i W dt)` on a `2D × 2D` complex matrix
  - Padé(13,13) with scaling-and-squaring: ~6 matrix-matrix products at `2D × 2D`
  - Each matmul: `(2D)³ = 17 576` flops complex (D = 13) → ~70 K real flops
  - Total per voxel: ~6 × 70 K + LU solve (~ 4 × 70 K) ≈ **0.7 Mflops**

Across 32³ = 32 768 voxels × 2 calls per step (φ and R updates) = **46 GFLOP / step**.

Real flop budget vs RTX 4090 (≈ 165 TFLOP/s F32, ≈ 80 TFLOP/s F64):
  - 32³ F32: 46 × 10⁹ / (165 × 10¹²) = **0.28 ms compute-bound**.
  - But we'll be **memory-bound** for the channel-build / R-update stages.
  - Realistic per-step 250–500 ms accounts for kernel launch overhead,
    shared-memory occupancy limits, and the Padé scaling-and-squaring control flow.

64³ at F=6 F32: 46 GFLOP × 8 = 368 GFLOP/step → 2.2 ms compute-bound,
realistic 1.5–3 s/step (memory traffic at 8× larger state).

---

## 2. Memory layout

### 2.1 State sizes

Per `TDHFBState{N, A, B, T}` instance:

  - `phi`:   `(Nx, …, D)`           — `Complex{T}`
  - `rho`:   `(Nx, …, D, D)`        — `Complex{T}`  (NEW for GPU)
  - `kappa`: `(Nx, …, D, D)`        — `Complex{T}`  (NEW for GPU)

For F=6 (D = 13) at three grid sizes, F64 vs F32:

| Grid | φ (F64)  | ρ (F64)  | κ (F64)  | Total F64 | Total F32 |
|------|----------|----------|----------|-----------|-----------|
| 16³  | 0.81 MB  | 10.6 MB  | 10.6 MB  | **22 MB** | **11 MB** |
| 32³  | 6.5 MB   | 84 MB    | 84 MB    | **175 MB**| **88 MB** |
| 64³  | 52 MB    | 711 MB   | 711 MB   | **1.5 GB**| **0.75 GB**|
| 128³ | 415 MB   | 5.5 GB   | 5.5 GB   | 11.5 GB   | 5.7 GB    |

Targets fit comfortably on 16 GB GPU (RTX 4090, A100-40, H100):
  - 32³ F64: 175 MB state + scratch buffers (~2× state) ≈ 525 MB total → **~3 % of 16 GB**
  - 64³ F64: 1.5 GB state + ~3 GB scratch ≈ 4.5 GB → **28 % of 16 GB**
  - 64³ F32: 0.75 GB state + ~2 GB scratch ≈ 2.75 GB → **17 % of 16 GB**

128³ F64 (11.5 GB state) becomes infeasible on 16 GB and requires either
F32, A100-80, or sharded execution. Not on the Phase 5 critical path.

### 2.2 Scratch / workspace fields

In addition to (φ, ρ, κ), the HF substep needs per-voxel scratch:

  - `U_phi`, `Delta_phi`: `(N_voxels, D, D)` complex — built once per substep
  - `W_phi`: `(N_voxels, 2D, 2D)` complex — assembled from U/Δ blocks
  - `M_phi`: `(N_voxels, 2D, 2D)` complex — output of `expm(-i W dt)`
  - `U_R`, `Delta_R`, `W_R`, `M_R`: same shapes (R sub-update)
  - `R_batch`: `(N_voxels, 2D, 2D)` complex — Nambu R = [[ρ, κ]; [κ̄, I + ρ̄]]
  - `M_inv`: `(N_voxels, 2D, 2D)` complex — output of batched `inv(M_R)`
  - `R_new`: same as `R_batch` — output of `M · R · M⁻¹`

Total scratch ≈ 4 × `(N_voxels, 2D, 2D)` = 4 × (4 × ρ size) = **16 × ρ size**.

For 32³ F=6 F64: 16 × 84 MB = 1.34 GB scratch. Still fits comfortably.

**Critical observation**: the `(N_voxels, 2D, 2D)` batched layout (CUBLAS
gemm_strided_batched-native) costs ~7× the (ρ, κ) state by itself. This is
the dominant GPU memory footprint and what sets the 16 GB headroom margin.

### 2.3 Allocation policy

Following the existing `_GPU_SM_CACHE` pattern in `ext/SpinorBECCUDAExt/gpu_spin_mixing.jl`:

  - Allocate scratch lazily on first `tdhfb_strang_step!` call.
  - Key cache by `hash((objectid(state), N_voxels, D, T))` to share across
    repeated calls with the same state size.
  - Reclaim via `CUDA.reclaim()` hook (see existing `_cuda_reclaim_callback`
    pattern in `ext/SpinorBECCUDAExt/SpinorBECCUDAExt.jl`) after each
    scan-point completes.

---

## 3. Kernel decomposition

The Strang step `V(dt/2) HF(dt/2) K(dt) HF(dt/2) V(dt/2)` decomposes into
five GPU kernel groups. Mapping to the existing CPU code in
`src/hamiltonian/tdhfb/strang_step.jl`:

### 3a. K-step — batched FFT kinetic (per `_tdhfb_kinetic_step!`)

CPU code (lines 322–349): per-component loop `for m in 1:D` doing
`fft(phi_m); phi_k .*= kinetic_phase; phi_m .= ifft(phi_k)`. D = 13 separate
FFTs per step.

GPU plan:
  - **cuFFT batched mode**: treat `phi` as a `(Nx, Ny, Nz, D)` array and call
    `plan_fft(phi, 1:N_spatial)` once. cuFFT internally batches over the
    trailing `D` axis. One launch instead of D launches → eliminates D-1
    kernel-launch overheads (~50 µs each).
  - **Persistent plan**: cache `(forward_plan, inverse_plan)` keyed by
    `(size(phi), eltype(phi))`. Reuse across all Strang steps.
  - **Fused phase multiply**: `phi_k .*= cis.(-0.5 .* k_squared .* dt)`
    where `k_squared` is broadcast over spatial dims. Single elementwise
    kernel.

Reuse: pattern matches existing `apply_kinetic_step_batched!` (in
`src/hamiltonian/integrator/kinetic.jl`); the TDHFB kinetic step can dispatch
to the same helper after promoting `phi` to a 4D `(Nx, Ny, Nz, D)` view.

Expected cost (32³ F=6 F32): 1 forward FFT + 1 multiply + 1 inverse FFT
≈ **5–10 ms** on RTX 4090.

### 3b. V-step — per-voxel elementwise (per `_tdhfb_v_step!`)

CPU code (lines 128–136): `phi[idx, m] *= cis(-V_ext[idx, m] * dt)` over
all (idx, m).

GPU plan: trivial broadcast. `phi .*= cis.(-V_ext .* dt)` where V_ext is
already on the device (existing `_to_device(::CUDABackend, V_ext)` pattern).
Single CUDA kernel, < 1 ms.

Note: V_ext is `(spatial..., D)`-shaped per the CPU implementation. The
broadcast aligns naturally with phi's shape.

### 3c. HF substep — channel kernel V·(...) tensor contraction

CPU code (`_tdhfb_phi_subupdate!` lines 177–240, `_tdhfb_R_subupdate!` lines
244–313): per voxel, build `U_phi`, `Delta_phi`, `U_R`, `Delta_R` from the
rank-4 channel kernel V via:

```julia
for c in 1:D, c_p in 1:D
    for c2 in 1:D, c2_p in 1:D
        Vk = V[c, c_p, c2, c2_p]
        Vk == 0.0 && continue
        # accumulate into U[c, c_p] and Delta[c, c_p]
    end
end
```

This is an `(N_voxels, D, D, D, D)` contraction with the rank-4 V.

GPU plan — **two reformulations**:

**Option A: gemm with reshape (preferred)**:
  - Reshape V to a (D², D²) matrix V_flat with index `(c, c_p) ↔ row`,
    `(c2, c2_p) ↔ col`.
  - Stack `(φ*φ + 2ρ)[idx, c2, c2_p]` and `κ[idx, c2, c2_p]` as `(D², N_voxels)`
    matrices (transpose of conventional voxel-leading layout).
  - U_phi and Delta_phi become a single `gemm`:
    `U_phi_flat = V_flat * (φ*φ + 2ρ)_flat` shape `(D², N_voxels)`.
  - Reshape back to `(N_voxels, D, D)` for downstream W assembly.
  - One CUBLAS `gemm` call per (U_phi, Delta_phi, U_R, Delta_R) = 4 gemms.

**Option B: per-voxel CUDA kernel** (fallback):
  - One thread block per voxel (or one warp per voxel for small D).
  - Channel kernel V loaded once into shared memory per block (V = 28 KB at
    F=6 F64, fits in 48 KB shared mem).
  - Per-block: build U, Δ blocks in shared memory.
  - Bandwidth-bound; less efficient than the gemm reformulation.

**Recommendation**: Option A. CUBLAS `gemm` is hardware-tuned and benefits
from tensor cores at F32. The reshape boundary is a virtual no-op (column-major
strides line up).

Expected cost (32³ F=6 F32, 4 gemms at D² × N_voxels = 169 × 32 768):
  - Per gemm: `O(D⁴ × N_voxels) = 169² × 32 768 = 9.4 × 10⁸ flops`
  - At ~50 TFLOP/s effective (gemm efficiency 30%): **20 ms / 4 gemms**
  - Plus 4 reshape/copy passes (memory-bound): ~10 ms
  - **Total per HF substep channel build: ~30 ms**

### 3c'. HF substep — BdG matrix exponential (CRITICAL KERNEL — see §4)

CPU code (line 226): `M = exp(-1im * W * dt)` via Julia's `Base.exp` (Padé +
scaling-and-squaring, LAPACK underneath). Single 26×26 matrix-exp per voxel
× 32 768 voxels = critical path.

This is the **most challenging GPU piece**; full design in §4.

### 3d. HF substep — R update `R ← M · R · M⁻¹`

CPU code (`_tdhfb_R_subupdate!` lines 290–310): build R from (ρ, κ) at this
voxel, compute `Minv = inv(M)`, then `R_new = M * R * Minv`, then read
back into ρ and κ slots with Hermitian/symmetric projection.

GPU plan:
  - Build R_batch `(N_voxels, 2D, 2D)` by elementwise assembly:
    `R[..., c, c_p] = rho[...]`, `R[..., c, D+c_p] = kappa[...]`,
    `R[..., D+c, c_p] = conj(kappa[..., c_p, c])`,
    `R[..., D+c, D+c_p] = (c==c_p) + conj(rho[..., c, c_p])`.
    → one fused elementwise kernel, < 1 ms.
  - Batched `inv(M_R)`:
    - **Option A**: `LU` via `CUSOLVER.getrfBatched!` + `getriBatched!` —
      handles 26×26 efficiently at large batch counts.
    - **Option B**: bypass — note that the Padé `expm` natively yields
      `M⁻¹` as a byproduct (the denominator polynomial Q satisfies
      `expm(A) = Q(A)⁻¹ P(A)`, so `expm(-A) = Q(-A)⁻¹ P(-A) ≈ Q(A) Q⁻¹` ...
      this requires care, see §4 detailed design).
    - **Recommendation**: Option A for safety; investigate Option B once
      Padé kernel is stable.
  - Batched `M * R * M⁻¹`: two `CUBLAS.gemm_strided_batched!` calls.
    Reuses the existing pattern in `ext/SpinorBECCUDAExt/gpu_tensor.jl`
    lines 109–121.
  - Read back to ρ and κ with Hermitian/symmetric projection:
    `rho[..., c, c_p] = 0.5 * (R_new[..., c, c_p] + conj(R_new[..., c_p, c]))`.
    Single fused kernel.

Expected cost (32³ F=6 F32):
  - R_batch assembly: 1 ms
  - Batched LU + inv (26×26 × 32 768 batch): 5–10 ms (CUSOLVER tuned)
  - 2 × gemm_strided_batched: 5–10 ms (CUBLAS tuned)
  - Read-back projection: 1 ms
  - **Total per R sub-update: ~20 ms**

### 3e. Hermitization projection — per-voxel elementwise

Already covered in 3d as part of the read-back step. Standalone kernel
(< 1 ms) can also be invoked between HF substeps as a numerical safety
net if drift accumulates beyond `tdhfb_hermiticity_check` tolerance.

### 3f. Summary — per-step kernel budget

For 32³ F=6 F32 target:

| Substep         | GPU time | Notes                                  |
|-----------------|----------|----------------------------------------|
| V(dt/2)         | < 1 ms   | broadcast                              |
| HF(dt/2)        | 130 ms   | channel build + Padé + R update + R/W |
| K(dt)           | 10 ms    | batched FFT                            |
| HF(dt/2)        | 130 ms   | same as above                          |
| V(dt/2)         | < 1 ms   |                                        |
| **Step total**  | **~270 ms** | within target 0.3–0.5 s/step       |

64³ F=6 F32 target: scale × 8 (voxel count) → 2.2 s/step, within 1.5–3 s
production target.

---

## 4. BdG matrix-exp on GPU — critical kernel

This is the hardest piece of the Phase 5 port and warrants its own section.
The CPU code uses `Base.exp` (LAPACK Padé) which is not directly available
batched on GPU. Several options exist:

### 4.1 Option A — eigendecomposition per voxel

Algorithm: `expm(W) = V · diag(exp(λ)) · V⁻¹` where `V` are eigenvectors
of `W`.

**Status: not viable**:
  - W is **non-Hermitian** (it is pseudo-Hermitian with `σ_z W σ_z = W†`
    where `σ_z = diag(I, -I)`). Standard CUSOLVER `heevjBatched!`
    (used in `ext/SpinorBECCUDAExt/gpu_tensor.jl` for the tensor step)
    requires Hermitian inputs and would crash silently or produce garbage.
  - CUSOLVER has no batched general-eigenvalue (`geev`-equivalent) routine
    as of CUDA 12. Batched Schur (`geesh`-like) is also absent.
  - Unbatched `geev` per voxel: would require a separate CUSOLVER call per
    of 32 768 voxels → kernel launch overhead alone (50 µs × 32 768 = 1.6 s)
    > target step time.

Eliminated.

### 4.2 Option B — Padé approximation + scaling-and-squaring (RECOMMENDED)

Algorithm (Higham 2005 / `expm` standard):

1. **Scaling**: pick `s` such that `||W dt / 2ˢ||_∞ ≤ θ` where θ is a safe
   bound for Padé degree m (typical: θ = 5.4 for m = 13).
2. **Padé(m, m)**: evaluate `P_m(A) / Q_m(A) ≈ exp(A)` where `A = W dt / 2ˢ`.
   - Padé(13, 13) uses 6 matrix-matrix products + 1 LU solve for `Q⁻¹ P`.
3. **Squaring**: `expm(W dt) = (expm(W dt / 2ˢ))^(2ˢ)` via `s` repeated
   squarings.

For F=6 (2D = 26), W dt magnitude ~ O(g · n · dt) ~ O(0.001) at typical
production settings → `s = 0` or `s = 1`, Padé only.

**Per-voxel flop budget**:
  - 6 × matmul(26 × 26 complex): 6 × 26³ × 4 flop = 422 K real flops
  - 1 × LU solve(26): ~ 4 × 26³ / 3 = 23 K flops
  - **Total ~450 K flops / voxel × 32 768 voxels = 14.8 GFLOP per HF substep**

At RTX 4090 effective 50 TFLOP/s for small-matrix BLAS:
  - 14.8 / 50 000 = **0.3 ms compute** for the matmul work
  - LU solve at small N=26: ~ memory-bound, expect 5–10 ms

**Realistic estimate**: 100–250 ms per HF substep accounting for kernel
launch overhead and shared-memory occupancy.

#### 4.2.1 Implementation strategy

**Approach 1 — Per-voxel CUDA kernel with shared memory**:

  - One CUDA thread block per voxel (or one warp per voxel for D ≤ 6).
  - Load W into shared memory (26 × 26 ComplexF32 = 5.4 KB, well within
    48 KB shared limit).
  - Implement Padé(13,13) coefficients as constant memory (13 Float64s).
  - Matmul accumulation in registers; LU solve via in-place Gaussian
    elimination in shared memory.
  - Output M and M⁻¹ to global memory.

Pseudocode sketch (CUDA.jl):

```julia
@inline function _pade_expm_kernel!(
    M_out, Minv_out, W_global,
    ::Val{TwoD}, ::Val{P}, dt
) where {TwoD, P}
    voxel_idx = (CUDA.blockIdx().x - 1) * CUDA.blockDim().y + CUDA.threadIdx().y
    voxel_idx > size(W_global, 1) && return

    # Shared memory for W, A_powers, P_pade, Q_pade — D² complex each
    shmem_W = CUDA.CuStaticSharedArray(ComplexF32, (TwoD, TwoD))
    shmem_A2 = CUDA.CuStaticSharedArray(ComplexF32, (TwoD, TwoD))
    # ... A4, A6, P, Q

    # Load W from global, scaling included
    @inbounds for c in 1:TwoD, r in 1:TwoD
        shmem_W[r, c] = -1im * W_global[voxel_idx, r, c] * dt
    end
    sync_threads()

    # Compute A², A⁴, A⁶ via thread-level matmul (one thread per (r,c))
    matmul_shared!(shmem_A2, shmem_W, shmem_W)
    matmul_shared!(shmem_A4, shmem_A2, shmem_A2)
    matmul_shared!(shmem_A6, shmem_A4, shmem_A2)

    # P_13 = b1·I + b3·A² + b5·A⁴ + b7·A⁶ + A⁶·(b9·A² + b11·A⁴ + b13·A⁶)
    # Q_13 = b0·I + b2·A² + b4·A⁴ + b6·A⁶ + A⁶·(b8·A² + b10·A⁴ + b12·A⁶)
    # ... per the Higham 2005 recipe.

    # Solve Q·M = P (LU in shared) → M = expm(...)
    lu_solve_shared!(M_local, Q, P)

    # Write back
    @inbounds for c in 1:TwoD, r in 1:TwoD
        M_out[voxel_idx, r, c] = M_local[r, c]
    end
    return nothing
end
```

Block configuration: 1 voxel per block, 26 × 26 = 676 threads per block
(one per matrix entry). On RTX 4090 with 1024-thread blocks, this gives
~50% occupancy — acceptable for memory-bound BLAS.

Alternative: 4 voxels per block (block.y = 4), 6 × 26 = 156 threads/voxel
(one row per thread, 6 voxels × 26 rows). This reduces shared-memory
pressure per voxel and improves occupancy at the cost of less parallelism
per voxel.

**Approach 2 — Batched gemm + per-step host LU (fallback)**:

  - Build A, A², A⁴, A⁶ via 3 batched gemm calls (CUBLAS).
  - Build P and Q via batched gemm (linear combinations of A powers).
  - Batched LU solve via `getrsBatched!` (CUSOLVER): solves
    `Q[batch] · M[batch] = P[batch]` for all batches simultaneously.

This is simpler to implement and avoids hand-tuning a CUDA kernel, but
launches 6+ kernels per voxel batch. Likely **20–50% slower** than
Approach 1 but **3× less risky to implement**.

**Recommendation**: Start with Approach 2 (lower risk, faster to validate).
Switch to Approach 1 only if Approach 2 misses the 0.3-0.5 s/step target.

### 4.3 Option C — Taylor series with truncation control

Algorithm: `expm(A) = I + A + A²/2! + ... + Aᴺ/N!` truncated at N where
`||Aᴺ||/N! < tol`.

For W dt magnitude ~ 0.001, only N ≈ 5–6 terms are needed to reach
single-precision accuracy. This is **simpler** than Padé but **less
accurate per flop** at larger norms.

**Status**: useful as a fallback / sanity check. Not the primary plan
because production runs may include larger dt regimes (Y4-midpoint
asks for sub-substep evaluations).

### 4.4 Option D — Hybrid CPU/GPU

GPU only for the K (FFT) + V (trap) + channel build stages; CPU for the
per-voxel BdG matrix-exp via Threads.@threads.

**Status**: rejected. The BdG matrix-exp is 80% of the per-step cost on
CPU at 32³. A partial GPU port that leaves the exp on CPU would yield only
~5× speedup, not the 40-60× target. Eliminated.

### 4.5 Recommended path

**Phase 5c implementation order**:

1. **Step 1** (smoke test): Implement Approach 2 (batched gemm + batched LU)
   on a single F=1 voxel (2D = 6) to validate correctness against CPU
   `expm(-i W dt)` at 1e-6 relative tolerance.
2. **Step 2** (production scale): Extend Approach 2 to F=6 (2D = 26) at
   32³ batch size. Measure wall clock.
3. **Step 3** (if needed): If Step 2 wall clock > 500 ms / HF substep,
   migrate to Approach 1 (hand-rolled CUDA kernel) for the inner Padé
   loop. Keep Approach 2 as the reference for validation.

### 4.6 Precision considerations for the matrix-exp

W is non-Hermitian; Padé(13,13) on F32 inputs is accurate to ~1e-7
(machine eps × m × condition number). For F=6 at typical g·n·dt ~ 1e-3:
  - Condition number of `Q_13(A)` ≈ 10²
  - Effective F32 error: ~10⁻⁵

This is adequate for short runs but accumulates over 10⁴ steps to ~10⁻¹
relative drift. For **production runs** (T = 10 ω⁻¹), recommend:

  - **F64 for the BdG matrix-exp** (the 700 K flops per voxel is the
    bottleneck whether F32 or F64; F32 saves memory but not time at this
    scale).
  - **F32 acceptable for the FFT + channel build** (lots of memory traffic,
    benefits from F32 bandwidth × 2).
  - **Mixed-precision policy**: store ρ, κ in F32 to halve memory; promote
    to F64 only inside the Padé kernel. Validates the
    `mixed_precision_design.md` pattern at the kernel level.

This is a per-kernel decision and should be benchmarked in Phase 5e
(production tuning).

---

## 5. Type stability + extension pattern

### 5.1 Backend dispatch

Following `ext/SpinorBECCUDAExt/backend.jl` pattern:

```julia
# In ext/SpinorBECCUDAExt/tdhfb/state.jl (NEW file):
function SpinorBEC.init_tdhfb_vacuum(psi::CuArray)
    # GPU-native vacuum init: ρ = κ = 0 as CuArrays
    sz = size(psi)
    spatial_dims = sz[1:end-1]
    D = sz[end]
    N = length(spatial_dims)
    T_real = real(eltype(psi))
    T_complex = eltype(psi)

    rho_shape = (spatial_dims..., D, D)
    rho = CUDA.zeros(T_complex, rho_shape)
    kappa = CUDA.zeros(T_complex, rho_shape)

    return TDHFBState{N, typeof(psi), typeof(rho), T_real}(
        psi, rho, kappa, zero(T_real), 0
    )
end
```

The struct `TDHFBState{N, A, B, T}` already parameterizes on container types
A and B, so the existing CPU constructor signature works for `A = CuArray`,
`B = CuArray` without modification.

### 5.2 Method dispatch

Each kernel gets a CUDA-specific method via `Array → CuArray` dispatch:

```julia
# CPU (existing, in src/hamiltonian/tdhfb/strang_step.jl):
function _tdhfb_hf_step!(state::TDHFBState{N}, ...) where {N}
    # generic CPU loop
end

# GPU (NEW, in ext/SpinorBECCUDAExt/tdhfb/strang_step.jl):
function SpinorBEC._tdhfb_hf_step!(
    state::TDHFBState{N, <:CuArray, <:CuArray}, ...
) where {N}
    # GPU kernel dispatch
end
```

The dispatch happens at the leaf-method level (e.g., `_tdhfb_hf_step!`,
`_tdhfb_kinetic_step!`, `_tdhfb_v_step!`), so the top-level
`tdhfb_strang_step!` is shared between backends. This matches the
established pattern for `apply_spin_mixing_step!`, `apply_tensor_interaction_step!`, etc.

### 5.3 Type stability discipline

Per CLAUDE.md "Type stability boundaries":

1. **No `Dict{Symbol, Any}` flowing into `TDHFBState` construction**.
   The existing constructor takes typed `phi::A, rho::B, kappa::B, t::T, step::Int`
   so this is already safe. YAML parsing must produce concrete-typed
   constructor arguments via a helper boundary
   (`_parse_tdhfb_block(raw::Dict)::NamedTuple{(:rho_init, :kappa_init, ...)}`).

2. **No closures stored in TDHFBState**. The struct has no `::Function`
   field; this is structurally enforced.

3. **`g_S::AbstractDict{Int, Float64}` is generic**. In the GPU port, we
   precompute the channel kernel V once as a `Float64` rank-4 array of
   size (D, D, D, D) and ship it to the device as a `CuArray{Float32, 4}`
   or `CuArray{Float64, 4}` depending on the workspace precision. The
   `g_S` dict itself never crosses the GPU boundary.

4. **`hfb_mode::Symbol` is a Val-promoted parameter**. The existing
   `hfb_mode === :popov` branch in `_tdhfb_phi_subupdate!` is a runtime
   compare. For the GPU port, lift it to a `Val{hfb_mode}` type parameter
   on the kernel to enable compile-time specialization:

   ```julia
   function _tdhfb_phi_subupdate_gpu!(state, ..., ::Val{Mode}) where {Mode}
       drop_anomalous = Mode === :popov
       # ... kernel uses `drop_anomalous` as a compile-time constant
   end
   ```

### 5.4 File layout

New files under `ext/SpinorBECCUDAExt/tdhfb/`:

  - `state.jl`        — GPU-aware `init_tdhfb_vacuum` + scratch cache
  - `strang_step.jl`  — `_tdhfb_v_step!`, `_tdhfb_kinetic_step!`,
                        `_tdhfb_hf_step!` GPU methods
  - `pade_expm.jl`    — batched BdG matrix-exp kernel (§4)
  - `channel_build.jl` — V·ρ contraction via gemm reshape (§3c Option A)
  - `r_update.jl`     — batched M · R · M⁻¹ + Hermitian projection

Mirrors the CPU layout under `src/hamiltonian/tdhfb/`. Loaded from
`SpinorBECCUDAExt.jl` after the existing files:

```julia
# In ext/SpinorBECCUDAExt/SpinorBECCUDAExt.jl, after gpu_graph.jl:
include("tdhfb/state.jl")
include("tdhfb/channel_build.jl")
include("tdhfb/pade_expm.jl")
include("tdhfb/r_update.jl")
include("tdhfb/strang_step.jl")
```

### 5.5 F32 vs F64 plumbing

Per `mixed_precision_design.md`, the `T` type parameter on
`TDHFBState{N, A, B, T}` already propagates precision (since `T = real(eltype(phi))`).
The GPU port adds:

  - F32 storage path: `init_tdhfb_vacuum(::CuArray{ComplexF32})` →
    `TDHFBState{N, CuArray{ComplexF32, N+1}, CuArray{ComplexF32, N+2}, Float32}`.
  - F64 path: same with `ComplexF64`/`Float64`.
  - **Padé kernel internal**: configurable via a Val parameter:
    `_pade_expm_kernel!(..., ::Val{:f32_compute})` vs `Val{:f64_compute}`.

The decision matrix (per §4.6):
  - **State arrays**: F32 for memory savings (especially 64³+)
  - **Padé compute**: F64 for accuracy (especially long-time runs)
  - **FFT plans**: match state precision (F32 batched cuFFT is well tuned)
  - **CUBLAS gemms**: match state precision (tensor cores at F32, also F64
    supported)

YAML knob (Phase 5d):
```yaml
dynamics:
  duration: 10.0
  dt: 0.001
  tdhfb:
    enabled: true
    storage_precision: f32   # ρ, κ, φ as ComplexF32 on device
    compute_precision: f64   # Padé matrix-exp in F64 (promoted per voxel)
```

---

## 6. Validation plan

### 6.1 Conservation tests on GPU vs CPU

The CPU pilot validation (C1–C5 from `test/hamiltonian/test_tdhfb_conservation.jl`)
is the ground truth. Phase 5d acceptance criteria:

| Test | CPU result        | GPU target (F32)   | GPU target (F64)   |
|------|-------------------|--------------------|--------------------|
| C1: ρ Hermiticity drift over 100 steps | < 1e-10 | < 1e-5 | < 1e-10 |
| C2: κ symmetry drift over 100 steps    | < 1e-10 | < 1e-5 | < 1e-10 |
| C3: Particle number N drift over T=2  | < 1e-8  | < 1e-4 | < 1e-8  |
| C4: Total energy E drift over T=5     | < 1e-6  | < 1e-3 | < 1e-6  |
| C5: ρ=κ=0 reduces to GP                | bit-exact | bit-exact | bit-exact |

The F32 tolerances are relaxed by ~5 orders of magnitude per F32 unit
roundoff (1.2e-7). If F32 fails C4 in production, fall back to F64 per §4.6.

### 6.2 Reproduce CPU pilot v3 results

The CPU pilot (commit `1412e49`) achieved 5/6 PASS on the validation
matrix. Phase 5e must reproduce these results on GPU within tolerance:

1. Energy conservation at T = 5 ω⁻¹ (F=6 Eu, 16³) — match CPU to 1e-5
2. F=1 GP limit (ρ=κ=0) — bit-exact match to existing GP solver
3. Bogoliubov mode reconstruction from κ — match within 1e-3 relative
4. Hugenholtz-Pines theorem (Popov mode) — gap < 1e-4 at uniform BEC
5. Anomalous density growth rate (post-quench) — match CPU to 1e-4

### 6.3 Performance benchmark

Phase 5e production benchmark on F=6 Eu post-quench at 32³:

  - **Baseline**: CPU, single thread, `tdhfb_strang_step!` × 1000 steps
  - **Target**: GPU (RTX 4090 or A100), same 1000 steps
  - **Acceptance**: GPU wall < 1/30 of CPU wall = 30× speedup minimum
  - **Stretch**: 60× speedup (= matches §1.3 target)

Benchmark script template (Phase 5e):

```julia
# scripts/bench_tdhfb_gpu.jl
using BenchmarkTools, SpinorBEC, CUDA

function bench_tdhfb(grid_size, F; backend, n_steps=100)
    D = 2F + 1
    psi = backend isa CUDABackend ?
        CUDA.zeros(ComplexF32, grid_size..., D) :
        zeros(ComplexF64, grid_size..., D)
    # ... initialize, run n_steps, return median ms/step
end

@show bench_tdhfb((32, 32, 32), 6; backend=CPUBackend(), n_steps=10)
@show bench_tdhfb((32, 32, 32), 6; backend=CUDABackend(), n_steps=100)
```

### 6.4 Long-time conservation + memory leak

Phase 5e long-running test:

  - 32³ F=6 Eu, T = 10 ω⁻¹, dt = 0.001 → 10 000 steps
  - Track: energy E(t), particle number N(t), GPU memory `CUDA.memory_status()`
    every 100 steps
  - Acceptance: ΔE/E < 1e-5 (F32) or 1e-7 (F64); GPU memory flat after
    initial warmup; no leak in scratch caches.

### 6.5 Multi-GPU consideration (out of scope, mention for completeness)

A single 32³ run fits on one GPU. The scan sweep (10 configs) can trivially
parallelize across multiple GPUs via existing scan-loop infrastructure
(`SpinorBEC._cuda_reclaim_callback`). For larger grids (64³+ or 128³ F32),
domain-decomposition multi-GPU is out of scope for Phase 5; see
`docs/design/multi_gpu_design.md` for the longer-term plan.

---

## 7. Implementation roadmap

### Phase 5a — GPU state + memory layout (1 week)

**Deliverables**:
  - `ext/SpinorBECCUDAExt/tdhfb/state.jl`: GPU `init_tdhfb_vacuum`
  - Lazy scratch cache (per §2.3) for (U_phi, Delta_phi, W, M, etc.)
  - `_tdhfb_v_step!(::CuArray, ...)` GPU method (trivial; §3b)
  - Smoke test: allocate F=6 32³ TDHFBState on GPU, verify memory < 200 MB,
    verify Hermiticity check passes on initial state.

**Exit criteria**: state allocates, V-step runs, no memory leak across 10 calls.

### Phase 5b — Batched cuFFT kinetic (1 week)

**Deliverables**:
  - `_tdhfb_kinetic_step!(::CuArray, ...)` GPU method using cached
    forward/inverse cuFFT plans (§3a).
  - Persistent plan cache keyed by `(size, eltype)`.
  - Unit test: GPU vs CPU kinetic step agree to 1e-6 (F32) / 1e-13 (F64)
    on F=1 32³ random ψ.

**Exit criteria**: K-step < 15 ms at 32³ F=6 F32.

### Phase 5c — BdG matrix-exp CUDA kernel (2 weeks)

This is the **critical path** — see §4 for full design.

**Week 1 deliverables**:
  - Approach 2 (batched gemm + CUSOLVER LU): working at F=1 (2D = 6) first
  - Validate against CPU `Base.exp(-i W dt)` to 1e-6 relative

**Week 2 deliverables**:
  - Extend to F=6 (2D = 26) at 32³ batch
  - Measure wall clock; decide whether to migrate to Approach 1 (custom
    CUDA kernel) for the inner Padé loop
  - Integrate channel-build (§3c Option A) + R-update (§3d) kernels
  - `_tdhfb_hf_step!(::CuArray, ...)` complete

**Exit criteria**: HF step < 150 ms at 32³ F=6 F32, conservation tests C1–C5
pass at F32 tolerance.

### Phase 5d — Integration + YAML knob + conservation suite (1 week)

**Deliverables**:
  - `tdhfb_strang_step!(::CuArray, ...)` end-to-end (composes 5a–c)
  - YAML knob `dynamics.tdhfb.enabled` + `storage_precision` /
    `compute_precision` knobs (§5.5)
  - Full conservation suite (`test/hamiltonian/test_tdhfb_conservation_gpu.jl`):
    GPU mirror of existing CPU conservation tests
  - Y4-midpoint outer wrapper on GPU (mirror `y4_midpoint_step.jl`)

**Exit criteria**: all 5/6 CPU validation results reproduced on GPU.

### Phase 5e — Eu production benchmark + tuning (1 week)

**Deliverables**:
  - Full 32³ F=6 Eu post-quench production run (T = 10 ω⁻¹, dt = 0.001,
    10 000 steps)
  - Benchmark vs CPU: 30–60× speedup verified
  - Memory leak audit (no growth across 10 000 steps)
  - Tune F32 vs F64 trade-off (per §4.6)
  - Docs update (`docs/architecture.md` § "CUDA extension" + this file
    promoted from design to status)

**Exit criteria**: 32³ F=6 Eu post-quench production run completes in
< 2 hr GPU wall, conservation tolerances per §6.4 satisfied.

### Total: ~6 weeks

Aligns with the D-thesis Year 1 Q3 schedule in
`docs/design/dthesis_year1_roadmap.md`.

---

## 8. Risks + fallback plans

### Risk 1 — Padé matrix-exp doesn't vectorize well

**Symptom**: Approach 2 (batched gemm + CUSOLVER) HF step > 500 ms / step
at 32³ F=6.

**Cause**: small-matrix batched BLAS is launch-overhead dominated; 6+ gemm
launches per Padé evaluation × 1 evaluation per voxel × 32 768 voxels
generates ≥ 200 K kernel launches per HF substep.

**Fallback**: Approach 1 (custom CUDA kernel) — implement Padé inside a
single kernel using shared memory for the matrix-power chain. Cost: +1 week
implementation, +1 week debug. Already budgeted as "Step 3" in §4.5.

If Approach 1 also misses, last-resort fallback:
  - **Hybrid CPU/GPU**: HF substep on CPU via Threads.@threads, FFT + V on
    GPU. Yields 5–10× speedup vs pure CPU. Disappointing but ships.
  - Or: cap grid at 16³ (where HF substep is already < 100 ms CPU at F=6)
    and rely on TWA ensembles for higher resolution.

### Risk 2 — GPU memory pressure at 64³ + sweeps

**Symptom**: 10-config sweep at 64³ overruns 16 GB GPU mid-run.

**Cause**: scratch cache accumulates across configs without `CUDA.reclaim()`.

**Mitigation (already designed in §2.3)**:
  - Reclaim hook between scan points (existing `_cuda_reclaim_callback`)
  - Lazy scratch allocation per config (no inter-config sharing)
  - F32 storage by default at 64³+ (halves footprint)

**Fallback**: out-of-core streaming — write ρ, κ to host (or NVMe) between
HF substeps, stream back per substep. ~10× slowdown but unlimited grid.
Implementation: post-Phase 5; mirror the `dynamics/psi_snapshots_streamed`
pattern for state arrays.

### Risk 3 — F32 precision insufficient for long-time conservation

**Symptom**: F32 production run at T = 10 ω⁻¹ shows ΔE/E > 1e-3 (C4
acceptance < 1e-3 violated).

**Cause**: Padé in F32 accumulates 10⁻⁵ per step × 10⁴ steps = 10⁻¹ drift.

**Mitigation (already designed in §4.6)**:
  - Mixed precision: F32 storage, F64 Padé compute
  - This is a per-kernel decision; cost is ~2× memory traffic during
    promotion but still 4× faster than full F64 storage

**Fallback**: full F64 at reduced grid (32³ instead of 64³). Accepts
slower per-step but maintains correctness.

### Risk 4 — Custom CUDA kernel debugging complexity

**Symptom**: Approach 1 kernel produces garbage at certain block sizes /
voxel counts.

**Cause**: shared memory race conditions or register spilling at 26 × 26 = 676
threads per block.

**Mitigation**:
  - Develop with `CUDA.allowscalar(false)` strict mode
  - Reference implementation (Approach 2) always available for diff testing
  - Per-voxel sanity check: compare M_gpu vs CPU `Base.exp(-i W dt)` at
    100 random voxels per step

**Fallback**: stick with Approach 2 + accept 200–300 ms per HF substep.
Still meets the 0.3–0.5 s/step target at 32³.

### Risk 5 — CUSOLVER batched LU instability for non-Hermitian Q

**Symptom**: `CUSOLVER.getrfBatched!` reports singular pivots on certain
W configurations (rare; condition number > 10⁸).

**Cause**: Padé denominator Q_13(A) can become ill-conditioned when
A is near a Padé pole.

**Mitigation**: scale-and-square more aggressively — pick `s` such that
`||A / 2ˢ|| < 1` always. Costs +1 squaring per voxel but eliminates
ill-conditioning.

**Detection**: per-voxel residual check `||M·M⁻¹ - I||` < 1e-3 (cheap
batched verification step).

---

## 9. Connection to existing infrastructure

### 9.1 `make_workspace(..., backend=CUDABackend())` analog

The existing `Workspace{...}` is the GPU activation point for the mean-field
solver. For TDHFB, the analog is:

```julia
# CPU:
state_cpu = init_tdhfb_vacuum(workspace.state.psi)  # workspace.state.psi::Array

# GPU:
import CUDA
workspace_gpu = make_workspace(...; backend=CUDABackend())
state_gpu = init_tdhfb_vacuum(workspace_gpu.state.psi)  # ::CuArray → dispatches to GPU init
```

The `init_tdhfb_vacuum(::CuArray)` dispatch (§5.1) handles the backend
selection. No new kwarg needed on `TDHFBState`.

### 9.2 Reuse `apply_kinetic_step_batched!`

The existing GPU kinetic step in `src/hamiltonian/integrator/kinetic.jl`
already implements batched cuFFT over the D spinor axis. TDHFB's K-step
on φ can call this verbatim. See §3a — the `_tdhfb_kinetic_step!(::CuArray)`
method should be a 3-line wrapper around `apply_kinetic_step_batched!`.

### 9.3 Reuse `CUDA.CUBLAS.gemm_strided_batched!`

The existing `ext/SpinorBECCUDAExt/gpu_tensor.jl` lines 109–121 already
demonstrates the batched-gemm pattern for V† ψ → phase → V ψ. The TDHFB
R-update (§3d) uses the same pattern:
  - `M · R` → `gemm_strided_batched!('N', 'N', 1, M, R, 0, tmp)`
  - `tmp · Minv` → `gemm_strided_batched!('N', 'N', 1, tmp, Minv, 0, R_new)`

### 9.4 Reuse `_GPU_*_CACHE` pattern

The cache pattern in `ext/SpinorBECCUDAExt/gpu_spin_mixing.jl` lines 30–66
(per-workspace cache keyed by `hash((objectid, N, D, T))`) directly applies
to TDHFB scratch:

```julia
mutable struct GPUTDHFBCache{N, D, T <: AbstractFloat}
    V_channel::CuArray{T, 4}         # (D, D, D, D) channel kernel
    U_phi::CuArray{Complex{T}, 3}    # (N_voxels, D, D)
    Delta_phi::CuArray{Complex{T}, 3}
    U_R::CuArray{Complex{T}, 3}
    Delta_R::CuArray{Complex{T}, 3}
    W_phi::CuArray{Complex{T}, 3}    # (N_voxels, 2D, 2D)
    W_R::CuArray{Complex{T}, 3}
    M_phi::CuArray{Complex{T}, 3}
    M_R::CuArray{Complex{T}, 3}
    Minv_R::CuArray{Complex{T}, 3}
    R_batch::CuArray{Complex{T}, 3}
    R_new::CuArray{Complex{T}, 3}
    # Pade scratch
    A_pow2::CuArray{Complex{T}, 3}
    A_pow4::CuArray{Complex{T}, 3}
    A_pow6::CuArray{Complex{T}, 3}
    P_pade::CuArray{Complex{T}, 3}
    Q_pade::CuArray{Complex{T}, 3}
end

const _GPU_TDHFB_CACHE = Dict{UInt64, Any}()

function _get_gpu_tdhfb_cache(state::TDHFBState{N, A, B, T}) where {N, A <: CuArray, B <: CuArray, T}
    sz = size(state.phi)
    spatial = sz[1:end-1]
    D = sz[end]
    N_vox = prod(spatial)
    key = hash((N_vox, D, T))
    cache = get(_GPU_TDHFB_CACHE, key, nothing)
    cache !== nothing && return cache::GPUTDHFBCache{N, D, T}
    # ... allocate scratch
end
```

### 9.5 Type stability discipline (CLAUDE.md)

The existing CLAUDE.md "Type stability boundaries" applies:

  - No `Dict{Symbol, Any}` flows into the kernel — YAML parsing extracts
    typed values via a helper.
  - No closures in `TDHFBState` (structurally enforced — struct has no
    `::Function` field).
  - `hfb_mode::Symbol` → `Val{Mode}` lifted at the GPU kernel boundary.
  - All GPU methods dispatch on `<:CuArray` rather than abstract `AbstractArray`
    to keep specialization narrow.

### 9.6 Connection to integrator modernization (Ch.3)

Phase 5 connects to the Ch.3 integrator work (commit chain `98213f6` →
`de0b51e`) in two ways:

  - **Y4-midpoint outer wrapper**: the CPU `y4_midpoint_step.jl` wraps the
    inner Strang step. The GPU port automatically inherits Y4 by calling
    the GPU Strang at the Y4 substeps.
  - **Energy drift target**: the Ch.3 Phase 5 result (machine-precision
    energy drift T = 20 ω⁻¹ on Y4-mid) sets the bar for TDHFB GPU
    conservation. The TDHFB pilot's CPU result (ΔE/E < 1e-6 at T = 5)
    is consistent with this; the GPU port must not regress.

### 9.7 Connection to other Phase 5 / Year 1 Q3 work

  - **Multi-GPU**: out of scope for TDHFB Phase 5; see
    `docs/design/multi_gpu_design.md`.
  - **Mixed precision plumbing**: TDHFB Phase 5 validates the F32 storage
    + F64 compute kernel pattern from `mixed_precision_design.md` at the
    kernel level (not just Workspace level).
  - **Dashboard ensemble panel**: TDHFB scenario sweeps (3 scenarios from
    `tdhfb_pilot_design.md`) feed directly into the dashboard ensemble panel
    (see `docs/design/dashboard_ensemble_panel.md`).

---

## 10. Open questions

1. **Y4-midpoint integration timing**: should Y4-midpoint be GPU-ported in
   Phase 5d (alongside Strang) or deferred to Phase 6? The Y4 wrapper adds
   ~6× cost over Strang at the same dt (5 substeps + 1 midpoint correction),
   so Phase 5 GPU benchmarks should use Strang + larger dt to match Y4
   accuracy. Recommendation: **defer Y4 GPU port to Phase 6**.

2. **Anomalous-coupling regularization**: the CPU pilot found rare cases
   where `||κ||` grew beyond unphysical bounds (per `tdhfb_pilot_design.md`
   §Risk 1). The CPU code does not currently include damping. Should the
   GPU port add an optional damping term in Phase 5d? Recommendation:
   **Phase 6 follow-up**, not blocker for 5d.

3. **Comparison with TWA on GPU**: the pilot design §"TWA → TDHFB upgrade
   path" envisions side-by-side TWA and TDHFB runs on the same configs.
   TWA on GPU is already supported via the existing `twa.jl` GPU path.
   Phase 5e benchmark should include a TWA-vs-TDHFB head-to-head at 32³
   F=6 Eu to validate the §5 speedup claim. Cost: +1 day in Phase 5e.

4. **Bogoliubov initial state**: thermal initial state with
   `init_kappa = :bogoliubov_modes` (per `tdhfb_pilot_design.md` Phase 4
   YAML) requires a Bogoliubov ground-state mode solver. CPU pilot uses
   vacuum init (`kappa = 0`) only. Bogoliubov GS modes on GPU is a
   separate sub-project; recommendation: **out of scope for Phase 5**,
   stick with vacuum init.

---

## 11. Summary

Phase 5 GPU port of the CPU TDHFB infrastructure (commit `1412e49`):
  - **Target**: 30–60× speedup at 32³ F=6 Eu → 0.3–0.5 s/step (vs 16 s CPU)
  - **Critical path**: batched BdG matrix-exp via Padé(13,13) +
    scaling-and-squaring (§4) — 2 weeks
  - **Total schedule**: 6 weeks (Phase 5a–5e) — aligns with D-thesis
    Year 1 Q3
  - **Risk profile**: medium; primary risk is the batched Padé kernel,
    fallback to batched gemm + CUSOLVER LU (Approach 2) always available

Once shipped, Phase 5 unlocks the 10-config × 32³ F=6 Eu post-quench
production sweep in ~15 hr GPU wall (vs 18 days CPU), which is the
deliverable for the D-thesis TDHFB chapter (Paper #5 target).
