# GPU DDI spin rotation: exp(z·Φ·F) per voxel, z = -i·dt (RT) / -dt (IT).
#
# Two exact realizations of the SAME operator, selected by the per-step rotation
# angle R = dt·max|Φ|·F:
#
#  * Adaptive tridiagonal Taylor-Horner (default) — the shared
#    `_apply_spin_rotation_taylor!` in gpu_spin_rotation_taylor.jl, which the
#    spin-mixing substep also uses (same operator, different v).
#  * Exact Euler 5-stage (`apply_ddi_euler_fused_kernel!`) — used when R exceeds
#    `_SPIN_TAYLOR_RMAX[]` (never reached in production). Machine precision at
#    all R, and the reference the Taylor path is parity-gated against.

# --- Euler fallback eigenvector cache (Fy diagonalization) ---
mutable struct GPUDDIRotCache{D, T <: AbstractFloat}
    V::CuArray{Complex{T}, 2}        # D×D Fy eigenvectors
    conj_V::CuArray{Complex{T}, 2}   # D×D conj(V)
    m_row::CuArray{T, 2}             # (1,D)  [F, F-1, …, -F]
    λ_row::CuArray{T, 2}             # (1,D)  Fy eigenvalues ascending
end

const _GPU_DDI_ROT_CACHE = Dict{UInt64, Any}()

function _get_gpu_ddi_rot_cache(
    psi::CuArray{Complex{T}}, sm::SpinorBEC.SpinMatrices{D}, ndim::Int
) where {D, T <: AbstractFloat}
    N = prod(ntuple(d -> size(psi, d), ndim))
    key = hash((objectid(sm), N, D, T))
    cache = get(_GPU_DDI_ROT_CACHE, key, nothing)
    cache !== nothing && return cache::GPUDDIRotCache{D, T}

    F = T(sm.system.F)
    m_vals = T[F - T(c - 1) for c in 1:D]
    λ_host = T.(sm.Fy_eigvals)
    V_host = Matrix{Complex{T}}(sm.Fy_eigvecs)

    cache = GPUDDIRotCache{D, T}(
        CuArray(V_host),
        CuArray(conj.(V_host)),
        CuArray(reshape(m_vals, 1, D)),
        CuArray(reshape(λ_host, 1, D)),
    )
    _GPU_DDI_ROT_CACHE[key] = cache
    cache
end

# Crop a (possibly padded) dipolar field to the spatial corner and flatten to
# (N,). Unpadded (size == n_pts, every production run) is a zero-copy reshape.
@inline function _gpu_phi_vec(phi::CuArray, n_pts::NTuple{M, Int}, N::Int) where {M}
    size(phi) == n_pts && return reshape(phi, N)
    reshape(phi[CartesianIndices(n_pts)], N)
end

# --- Dispatcher: Taylor (adaptive) with exact-Euler fallback ---
function SpinorBEC._apply_ddi_rotation!(
    psi::CuArray{Complex{T}},
    phi_x::CuArray,
    phi_y::CuArray,
    phi_z::CuArray,
    sm::SpinorBEC.SpinMatrices{D},
    dt_frac::Float64,
    ndim::Int;
    imaginary_time::Bool=false,
) where {T <: AbstractFloat, D}
    n_pts = ntuple(d -> size(psi, d), ndim)
    N = prod(n_pts)
    P = reshape(psi, N, D)
    px = _gpu_phi_vec(phi_x, n_pts, N)
    py = _gpu_phi_vec(phi_y, n_pts, N)
    pz = _gpu_phi_vec(phi_z, n_pts, N)

    plan = _spin_taylor_plan(psi, sm, px, py, pz, T(dt_frac), imaginary_time)
    if plan !== nothing
        coef, z, K = plan
        _apply_spin_rotation_taylor!(P, px, py, pz, coef, z, K, Val(D))
        return nothing
    end

    # Fallback: exact Euler 5-stage (large/unknown R).
    cache = _get_gpu_ddi_rot_cache(psi, sm, ndim)
    apply_ddi_euler_fused_kernel!(
        P, px, py, pz, cache.m_row, cache.λ_row, cache.V, cache.conj_V, dt_frac;
        imaginary_time=imaginary_time,
    )
    nothing
end
