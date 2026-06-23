# GPU DDI spin rotation: exp(z·Φ·F) per voxel, z = -i·dt (RT) / -dt (IT).
#
# Two exact realizations of the SAME operator, selected by the per-step
# rotation angle R = dt·max|Φ|·F:
#
#  * Adaptive tridiagonal Taylor–Horner (default). The generator A = Φ·F is
#    Hermitian tridiagonal in the F_z basis (F_z diagonal, F_x/F_y ladder
#    bands), built directly from `sm.Fx/Fy/Fz` (single physics declaration).
#    `exp(zA)ψ` is evaluated as w←ψ; for k=K..1: w←ψ+(z/k)(A·w), where A·w is a
#    nearest-neighbour shfl matvec (warp-cooperative, one component per lane —
#    no local-memory spill, no Fy-eigenvector matrices, no atan/acos). The
#    degree K is chosen per step from the backward-error bound
#    R^{K+1}/(K+1)! ≤ tol; in the Eu EdH regime (R≈0.03–0.2) K≈5–9 reaches
#    machine precision. Imaginary time uses real z=-dt → genuine exp(-dt Φ·F)
#    weight, no overflow shift needed.
#  * Exact Euler 5-stage (`apply_ddi_euler_fused_kernel!`) — used as a fallback
#    when R exceeds `_DDI_TAYLOR_RMAX[]` (never reached in production). Machine
#    precision at all R.

using StaticArrays: SVector

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

# --- Taylor tridiagonal-generator coefficients (DEVICE arrays) ---
# Held as small CuArrays, NOT by-value SVectors: each lane loads only its own
# (mz_c, sxu_c, syu_c) via a cached global read. A by-value SVector indexed by
# the lane-dependent component would stage all D entries into per-thread local
# memory and was measured ~4× slower (gotcha_warp_kernel_byvalue_svector…).
struct GPUDDITaylorCoef{T}
    mz::CuArray{T, 1}               # F_z diagonal m_c
    sxu::CuArray{Complex{T}, 1}     # F_x super-diagonal [c,c+1] (0 at c=D)
    syu::CuArray{Complex{T}, 1}     # F_y super-diagonal [c,c+1] (0 at c=D)
end

const _GPU_DDI_TAYLOR_CACHE = Dict{UInt64, Any}()

function _get_taylor_coef(
    ::CuArray{Complex{T}}, sm::SpinorBEC.SpinMatrices{D},
) where {D, T <: AbstractFloat}
    key = hash((objectid(sm), D, T))
    c = get(_GPU_DDI_TAYLOR_CACHE, key, nothing)
    c !== nothing && return c::GPUDDITaylorCoef{T}
    Fx = sm.Fx
    Fy = sm.Fy
    Fz = sm.Fz
    mz = T[T(real(Fz[i, i])) for i in 1:D]
    sxu = Complex{T}[i < D ? Complex{T}(Fx[i, i + 1]) : zero(Complex{T}) for i in 1:D]
    syu = Complex{T}[i < D ? Complex{T}(Fy[i, i + 1]) : zero(Complex{T}) for i in 1:D]
    coef = GPUDDITaylorCoef{T}(CuArray(mz), CuArray(sxu), CuArray(syu))
    _GPU_DDI_TAYLOR_CACHE[key] = coef
    coef
end

# Crop a (possibly padded) dipolar field to the spatial corner and flatten to
# (N,). Unpadded (size == n_pts, every production run) is a zero-copy reshape.
@inline function _gpu_phi_vec(phi::CuArray, n_pts::NTuple{M, Int}, N::Int) where {M}
    size(phi) == n_pts && return reshape(phi, N)
    reshape(phi[CartesianIndices(n_pts)], N)
end

# --- Adaptive degree selection ---
# Adaptive tridiagonal Taylor–Horner DDI rotation. With the band coefficients in
# device memory (not by-value SVector) it measured ~2× FASTER than the warp
# Euler at production R≈0.012 (K=6) on H100, matching Euler to ~1e-15. Euler is
# the exact-to-roundoff fallback (R > _DDI_TAYLOR_RMAX[]). Set false to force it.
const _DDI_USE_TAYLOR = Ref(true)
const _DDI_TAYLOR_RMAX = Ref(1.0)     # R above which we fall back to Euler
const _DDI_TAYLOR_TOL = Ref(1.0e-13)  # backward-error target
const _DDI_R_OVERRIDE = Ref(NaN)      # set to skip the max|Φ| reduction

# smallest K with R^K/K! ≤ tol (⇒ omitted term R^{K+1}/(K+1)! < tol), K ≥ 2.
function _taylor_degree(R::Real, tol::Real)
    t = 1.0
    k = 0
    while k < 40
        k += 1
        t *= R / k
        t <= tol && return max(k, 2)
    end
    return 40
end

function _ddi_spectral_R(px, py, pz, dt::T, F::T) where {T <: AbstractFloat}
    pm2 = maximum(px .* px .+ py .* py .+ pz .* pz)
    dt * sqrt(pm2) * F
end

# --- Taylor–Horner warp kernel (one spin component per lane) ---
@inline function _ddi_taylor_warp_kernel!(
    P, px, py, pz, mz, sxu, syu, z::Complex{T}, K::Int32, ::Val{D},
) where {T, D}
    CT = Complex{T}
    W = 16
    tib = CUDA.threadIdx().x
    lane0 = (tib - 1) & 31
    sg = lane0 >> 4
    sl = lane0 & 15
    warp_in_block = (tib - 1) >> 5
    gwarp = (CUDA.blockIdx().x - 1) * (CUDA.blockDim().x >> 5) + warp_in_block
    vox = gwarp * 2 + sg + 1
    N = size(P, 1)
    active = sl < D
    in_range = vox <= N
    c = active ? sl + 1 : 1

    Px = in_range ? (@inbounds px[vox]) : zero(T)
    Py = in_range ? (@inbounds py[vox]) : zero(T)
    Pz = in_range ? (@inbounds pz[vox]) : zero(T)

    diag_c = Pz * (@inbounds mz[c])                       # real F_z diagonal
    b_c = Px * (@inbounds sxu[c]) + Py * (@inbounds syu[c])  # A[c,c+1]
    # lower coupling conj(A[c-1,c]) = conj(b_{c-1}); b_{c-1} from lane c-1
    cdn = c > 1 ? c - 1 : 1
    bm_raw = _shfl_c(b_c, cdn, Val(W))
    bm = c > 1 ? bm_raw : zero(CT)

    psi0 = (active && in_range) ? (@inbounds P[vox, c]) : zero(CT)
    w = psi0
    k = K
    while k >= one(Int32)
        wup = _shfl_c(w, c + 1, Val(W))                  # w_{c+1} (idle→0 at c=D)
        wdn_raw = _shfl_c(w, cdn, Val(W))
        wdn = c > 1 ? wdn_raw : zero(CT)
        Aw = diag_c * w + b_c * wup + conj(bm) * wdn
        w = psi0 + (z / T(k)) * Aw
        k -= one(Int32)
    end

    if active && in_range
        @inbounds P[vox, c] = w
    end
    nothing
end

function _apply_ddi_taylor!(
    P, px, py, pz, coef::GPUDDITaylorCoef{T}, z::Complex{T}, K::Integer, ::Val{D},
) where {T, D}
    N = size(P, 1)
    voxels_per_block = 16
    threads = 256
    blocks = cld(N, voxels_per_block)
    CUDA.@cuda threads = threads blocks = blocks _ddi_taylor_warp_kernel!(
        P, px, py, pz, coef.mz, coef.sxu, coef.syu, z, Int32(K), Val(D))
    nothing
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

    if _DDI_USE_TAYLOR[]
        F = T(sm.system.F)
        R = isnan(_DDI_R_OVERRIDE[]) ?
            _ddi_spectral_R(px, py, pz, T(dt_frac), F) : T(_DDI_R_OVERRIDE[])
        if R <= T(_DDI_TAYLOR_RMAX[])
            K = _taylor_degree(R, _DDI_TAYLOR_TOL[])
            coef = _get_taylor_coef(psi, sm)
            z = imaginary_time ? Complex{T}(-T(dt_frac), zero(T)) :
                Complex{T}(zero(T), -T(dt_frac))
            _apply_ddi_taylor!(P, px, py, pz, coef, z, K, Val(D))
            return nothing
        end
    end

    # Fallback: exact Euler 5-stage (large/unknown R).
    cache = _get_gpu_ddi_rot_cache(psi, sm, ndim)
    apply_ddi_euler_fused_kernel!(
        P, px, py, pz, cache.m_row, cache.λ_row, cache.V, cache.conj_V, dt_frac;
        imaginary_time=imaginary_time,
    )
    nothing
end
