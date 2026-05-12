# Nambu R = [[ρ, κ]; [-κ̄, I + ρ̄]] update on GPU — Phase 5c piece 3/3.
#
# Per CPU code at `src/hamiltonian/tdhfb/strang_step.jl:287-319`:
#   1. Build R = [[ρ, κ]; [-κ̄, I + ρ̄]]  (2D × 2D per voxel)
#   2. Compute M^{-1} via batched LU + inversion
#   3. R_new = M · R · M^{-1} via two batched gemms
#   4. Read back ρ and κ with Hermitian / symmetric projection.
#
# GPU plan:
#   1. `_build_R_nambu!`     — CUDA kernel, one pass over (r, c, v).
#   2. `_batched_matinv!`    — wrap `CUBLAS.getrf_strided_batched!` +
#                              `CUBLAS.getri_strided_batched!`.
#   3. `_apply_mrm!`         — two `CUBLAS.gemm_strided_batched!` calls.
#   4. `_project_R_to_rho_kappa!` — CUDA kernel with Hermitian projection.

# ----- 1. Nambu R block assembly -----
#
# R[c, c', v]       = ρ[v, c, c']
# R[c, D+c', v]     = κ[v, c, c']
# R[D+c, c', v]     = +conj(κ[v, c, c'])    (same (c, c') order, NO sign flip)
# R[D+c, D+c', v]   = δ_{c, c'} + conj(ρ[v, c, c'])
#
# Convention follows the bosonic-HFB Nambu form used in the CPU code at
# `src/hamiltonian/tdhfb/strang_step.jl:299-306` (note: the docstring on
# the CPU R_subupdate refers to `-conj(κ̄)` style, but the production code
# uses `+conj(κ)` — match the production code, not the docstring).

function _kernel_build_R!(R, rho, kappa, D::Int, twoD::Int, N_vox::Int)
    r = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    c = (CUDA.blockIdx().y - 1) * CUDA.blockDim().y + CUDA.threadIdx().y
    v = (CUDA.blockIdx().z - 1) * CUDA.blockDim().z + CUDA.threadIdx().z
    if r <= twoD && c <= twoD && v <= N_vox
        @inbounds begin
            if r <= D && c <= D
                R[r, c, v] = rho[v, r, c]
            elseif r <= D && c > D
                R[r, c, v] = kappa[v, r, c - D]
            elseif r > D && c <= D
                R[r, c, v] = conj(kappa[v, r - D, c])
            else
                R[r, c, v] = (r - D == c - D ? one(eltype(R)) : zero(eltype(R))) +
                             conj(rho[v, r - D, c - D])
            end
        end
    end
    return nothing
end

"""
    _build_R_nambu!(R, state, D) -> R

Assemble the 2D × 2D Nambu density matrix R per voxel from (ρ, κ).
`R::(2D, 2D, N_voxels)`. state.rho and state.kappa are (spatial..., D, D);
they are interpreted as (N_voxels, D, D) on the device.
"""
function _build_R_nambu!(
    R::CuArray{TC, 3},
    state::SpinorBEC.TDHFBState{N, A, B, T},
    D::Int,
) where {N, A <: CuArray, B <: CuArray, T, TC <: Complex}
    twoD = size(R, 1)
    @assert twoD == 2 * D
    N_vox = size(R, 3)
    spatial = size(state.rho)[1:end-2]
    @assert prod(spatial) == N_vox
    rho_v = reshape(state.rho, N_vox, D, D)
    kappa_v = reshape(state.kappa, N_vox, D, D)

    threads_r = min(twoD, 8)
    threads_v = min(N_vox, 8)
    blocks_r = cld(twoD, threads_r)
    blocks_v = cld(N_vox, threads_v)
    CUDA.@cuda(
        threads=(threads_r, threads_r, threads_v),
        blocks=(blocks_r, blocks_r, blocks_v),
        _kernel_build_R!(R, rho_v, kappa_v, D, twoD, N_vox),
    )
    R
end

# ----- 2. Batched matrix inversion via LU -----
#
# CUBLAS API requires (D, D, batch_size) — strided batch with row-major LU.
# Our M is (2D, 2D, N_voxels); same layout.

"""
    _batched_matinv!(Minv, M_work) -> Minv

Compute Minv[v] = inv(M_work[v]) for all voxels v. `M_work` is OVERWRITTEN
(used as LU storage). Returns Minv (same shape as M).

Uses `CUBLAS.getrf_strided_batched!` (LU factorization) + `getri_strided_batched!`
(inverse-from-LU) — both are available in CUDA.jl 12+.
"""
function _batched_matinv!(
    Minv::CuArray{TC, 3},
    M_work::CuArray{TC, 3},
) where {TC <: Complex}
    @assert size(Minv) == size(M_work)
    twoD = size(M_work, 1)
    N_vox = size(M_work, 3)

    # LU factorization in-place on M_work.
    # Returns pivots (Int32 array of size (twoD, N_vox))
    pivots, info = CUDA.CUBLAS.getrf_strided_batched!(M_work, true)
    # info[v] == 0 → success; nonzero → singular pivot at row info[v].
    # We don't check info per-voxel in production (cost), but a CPU sync
    # diagnostic check could be added in dev mode.

    # Invert using LU.
    CUDA.CUBLAS.getri_strided_batched!(M_work, Minv, pivots)
    Minv
end

# ----- 3. Apply M·R·M† via two batched gemms -----
#
# Bosonic Bogoliubov: M is pseudo-unitary (σ_z M† σ_z = M⁻¹). The Heisenberg
# evolution of the bosonic Nambu density R_{ab} = ⟨ψ_b† ψ_a⟩ is M·R·M†, NOT
# M·R·M⁻¹. M·R·M† preserves Hermiticity and the Nambu structure exactly, so
# the downstream Hermitian/symmetric projection is no longer required.

"""
    _apply_mrm!(R_new, M, R, R_tmp) -> R_new

Compute R_new[v] = M[v] · R[v] · M[v]† for all voxels using two batched
gemms. `R_tmp` is scratch.
"""
function _apply_mrm!(
    R_new::CuArray{TC, 3},
    M::CuArray{TC, 3},
    R::CuArray{TC, 3},
    R_tmp::CuArray{TC, 3},
) where {TC <: Complex}
    # R_tmp = M · R
    CUDA.CUBLAS.gemm_strided_batched!(
        'N', 'N', one(TC), M, R, zero(TC), R_tmp,
    )
    # R_new = R_tmp · M†  (use 'C' = conjugate-transpose on M)
    CUDA.CUBLAS.gemm_strided_batched!(
        'N', 'C', one(TC), R_tmp, M, zero(TC), R_new,
    )
    R_new
end

# ----- 4. Read back ρ, κ from R_new -----
#
# Because M·R·M† preserves Hermiticity and Nambu form exactly, no projection
# is needed — read R_new directly:
#   rho_new[v, c, c']   = R_new[c,   c', v]
#   kappa_new[v, c, c'] = R_new[c, D+c', v]

function _kernel_project_R!(rho, kappa, R_new, D::Int, N_vox::Int)
    c = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    cp = (CUDA.blockIdx().y - 1) * CUDA.blockDim().y + CUDA.threadIdx().y
    v = (CUDA.blockIdx().z - 1) * CUDA.blockDim().z + CUDA.threadIdx().z
    if c <= D && cp <= D && v <= N_vox
        @inbounds begin
            rho[v, c, cp] = R_new[c, cp, v]
            kappa[v, c, cp] = R_new[c, D + cp, v]
        end
    end
    return nothing
end

"""
    _project_R_to_rho_kappa!(state, R_new, D) -> state

Read back rho and kappa from R_new. With the M·R·M† update, R_new is already
Hermitian / Nambu-symmetric by construction, so no averaging is required.
"""
function _project_R_to_rho_kappa!(
    state::SpinorBEC.TDHFBState{N, A, B, T},
    R_new::CuArray{TC, 3},
    D::Int,
) where {N, A <: CuArray, B <: CuArray, T, TC <: Complex}
    N_vox = size(R_new, 3)
    spatial = size(state.rho)[1:end-2]
    @assert prod(spatial) == N_vox
    rho_v = reshape(state.rho, N_vox, D, D)
    kappa_v = reshape(state.kappa, N_vox, D, D)

    threads_c = min(D, 8)
    threads_v = min(N_vox, 8)
    blocks_c = cld(D, threads_c)
    blocks_v = cld(N_vox, threads_v)
    CUDA.@cuda(
        threads=(threads_c, threads_c, threads_v),
        blocks=(blocks_c, blocks_c, blocks_v),
        _kernel_project_R!(rho_v, kappa_v, R_new, D, N_vox),
    )
    state
end
