# Fused Euler 5-stage rotation kernels (single launch).
#
# The sign-bearing 5-stage body lives in ONE device function
# `_euler_apply_voxel!` (single declaration — the codebase forbids
# duplicating sign-bearing physics). Two kernels call it:
#   * `_euler_5stage_kernel!`  — angles supplied as (N,1) arrays
#     (spin_mixing, raman: angles come from spin density / Raman field).
#   * `_ddi_euler_kernel!`     — angles computed in-register from the dipolar
#     field Φ(r), so DDI rotation pays no separate angle broadcast pass.
#
# Each holds the spinor in a thread-local MVector and reads the two D×D Fy
# eigenvector matrices once per block into SHARED memory. A full `@nexprs`
# unroll of the 13×13 matvecs EXPLODES register pressure (measured 3.5×
# slower) — the looped MVector is the sweet spot. `ntuple(f, Val(D))` does
# NOT unroll for D>10 (Base caps at 10 → dynamic jl_f_tuple, illegal on GPU).
#
# Layout: `psi` (N, D) column-major; `conj_V[c,j] = conj(V[c,j])`; shared
# V/conj_V linear column-major, element [c,j] at (j-1)*D + c.

using StaticArrays: MVector

@inline function _load_shared_eigvecs!(shV, shCV, V, conj_V, ::Val{DD}) where {DD}
    tid = CUDA.threadIdx().x
    nth = CUDA.blockDim().x
    k = tid
    @inbounds while k <= DD
        shV[k] = V[k]
        shCV[k] = conj_V[k]
        k += nth
    end
    CUDA.sync_threads()
    nothing
end

# Apply R_z(α) R_y(β) D_z(θ) R_y(-β) R_z(-α) to row i of psi in place.
# `shV`/`shCV` are the block-shared Fy eigenvector matrices (already loaded).
# ITP Dz uses exp(-m·θ) (NOT exp(-(m-F)·θ): the overflow shift is a spatially
# varying density reweighting that biases the ITP fixed point — CPU fix
# 2026-06-15, mistake_itp_imaginary_time_euler_stage3_density_bias).
@inline function _euler_apply_voxel!(
    psi, i, α_i, β_i, θ_i, m_gpu, λ_gpu, shV, shCV, ::Val{D}, ::Val{IT},
) where {D, IT}
    T = real(eltype(psi))
    CT = Complex{T}

    s = MVector{D, CT}(undef)
    @inbounds for c in 1:D
        s[c] = psi[i, c]
    end

    # Step 1: R_z(-α) → s_c *= cis(+m_c·α)
    @inbounds for c in 1:D
        s[c] *= cis(m_gpu[1, c] * α_i)
    end

    # Step 2: R_y(-β) = V·diag(cis(+βλ))·conj(V)ᵀ
    tmp = MVector{D, CT}(undef)
    @inbounds for j in 1:D
        acc = zero(CT)
        base = (j - 1) * D
        for c in 1:D
            acc += s[c] * shCV[base + c]
        end
        tmp[j] = acc * cis(β_i * λ_gpu[1, j])
    end
    @inbounds for c in 1:D
        acc = zero(CT)
        for j in 1:D
            acc += tmp[j] * shV[(j - 1) * D + c]
        end
        s[c] = acc
    end

    # Step 3: D_z(θ)
    if IT
        @inbounds for c in 1:D
            s[c] *= exp(-m_gpu[1, c] * θ_i)
        end
    else
        @inbounds for c in 1:D
            s[c] *= cis(-m_gpu[1, c] * θ_i)
        end
    end

    # Step 4: R_y(β)
    @inbounds for j in 1:D
        acc = zero(CT)
        base = (j - 1) * D
        for c in 1:D
            acc += s[c] * shCV[base + c]
        end
        tmp[j] = acc * cis(-β_i * λ_gpu[1, j])
    end
    @inbounds for c in 1:D
        acc = zero(CT)
        for j in 1:D
            acc += tmp[j] * shV[(j - 1) * D + c]
        end
        s[c] = acc
    end

    # Step 5: R_z(α) → s_c *= cis(-m_c·α)
    @inbounds for c in 1:D
        s[c] *= cis(-m_gpu[1, c] * α_i)
    end

    @inbounds for c in 1:D
        psi[i, c] = s[c]
    end
    nothing
end

# --- Array-angle kernel (spin_mixing, raman) ---
@inline function _euler_5stage_kernel!(
    psi, α, β, θ, m_gpu, m_shift, λ_gpu, V, conj_V, ::Val{D}, ::Val{IT},
) where {D, IT}
    CT = Complex{real(eltype(psi))}
    shV = CUDA.CuStaticSharedArray(CT, D * D)
    shCV = CUDA.CuStaticSharedArray(CT, D * D)
    _load_shared_eigvecs!(shV, shCV, V, conj_V, Val(D * D))
    i = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    i > size(psi, 1) && return nothing
    _euler_apply_voxel!(psi, i, (@inbounds α[i, 1]), (@inbounds β[i, 1]),
        (@inbounds θ[i, 1]), m_gpu, λ_gpu, shV, shCV, Val(D), Val(IT))
    return nothing
end

# --- DDI phi-angle kernel: angles from the dipolar field, no broadcast pass ---
@inline function _ddi_euler_kernel!(
    psi, phi_x, phi_y, phi_z, m_gpu, λ_gpu, V, conj_V, dt::T, ::Val{D}, ::Val{IT},
) where {T, D, IT}
    CT = Complex{T}
    shV = CUDA.CuStaticSharedArray(CT, D * D)
    shCV = CUDA.CuStaticSharedArray(CT, D * D)
    _load_shared_eigvecs!(shV, shCV, V, conj_V, Val(D * D))
    i = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    i > size(psi, 1) && return nothing
    px = @inbounds phi_x[i]
    py = @inbounds phi_y[i]
    pz = @inbounds phi_z[i]
    pm = sqrt(px * px + py * py + pz * pz)
    α_i = atan(py, px)
    β_i = acos(clamp(pz / max(pm, floatmin(T)), -one(T), one(T)))
    θ_i = pm * dt
    _euler_apply_voxel!(psi, i, α_i, β_i, θ_i, m_gpu, λ_gpu, shV, shCV, Val(D), Val(IT))
    return nothing
end

"""
    apply_euler_5stage_fused_kernel!(psi_2d, α, β, θ, m_gpu, m_shift, λ_gpu, V, conj_V; imaginary_time)

Single-launch fused Euler rotation with angles supplied as `(N,1)` arrays.
"""
function apply_euler_5stage_fused_kernel!(
    psi_2d::CuArray{Complex{T}, 2},
    α::CuArray{T, 2}, β::CuArray{T, 2}, θ::CuArray{T, 2},
    m_gpu::CuArray{T, 2}, m_shift::CuArray{T, 2}, λ_gpu::CuArray{T, 2},
    V::CuArray{Complex{T}, 2}, conj_V::CuArray{Complex{T}, 2};
    imaginary_time::Bool=false,
) where {T <: AbstractFloat}
    N = size(psi_2d, 1)
    D = size(psi_2d, 2)
    threads = min(N, 256)
    blocks = cld(N, threads)
    CUDA.@cuda threads = threads blocks = blocks _euler_5stage_kernel!(
        psi_2d, α, β, θ, m_gpu, m_shift, λ_gpu, V, conj_V, Val(D), Val(imaginary_time))
    nothing
end

# --- Warp-cooperative DDI euler kernel ---
#
# The one-thread-per-voxel `_ddi_euler_kernel!` holds the full spinor in two
# MVector{D} (s + tmp). At D=13 these spill to local memory (464 B/thread F64,
# measured) and the four dense D×D matvecs read/write that spilled vector — the
# kernel is local-memory/occupancy bound, not arithmetic bound (F32 == F64
# wall). This variant maps ONE spin component to ONE warp lane: the spinor
# lives across lanes in registers (no spill), and each D×D matvec is a
# shfl-broadcast reduction. Two voxels share a 32-lane warp via width-16
# subgroups (lanes 13–15 / 29–31 idle). The sign-bearing 5-stage body is the
# SAME math as `_euler_apply_voxel!` (single physics declaration preserved).
const _DDI_EULER_WARP = Ref(true)

# Broadcast lane `src` (1-based) within this lane's width-W subgroup.
@inline function _shfl_c(z::Complex{T}, src::Integer, ::Val{W}) where {T, W}
    re = CUDA.shfl_sync(0xffffffff, real(z), src, W)
    im = CUDA.shfl_sync(0xffffffff, imag(z), src, W)
    Complex{T}(re, im)
end

# v_out[c] = Σ_k M[linear(c,k)] · s_k, with s_k broadcast from lane k of the
# subgroup. `lin(c,k)` returns the column-major linear index into the shared
# D×D matrix for output row `c`, source `k`.
@inline function _warp_matvec(s::Complex{T}, sh, cc::Int, ::Val{D}, ::Val{W}, lin::F) where {T, D, W, F}
    acc = zero(Complex{T})
    @inbounds for k in 1:D
        a = _shfl_c(s, k, Val(W))
        acc += sh[lin(cc, k)] * a
    end
    acc
end

@inline function _euler_apply_warp!(
    psi, vox, in_range, active, cc, α, β, θ, m_c, λ_c, shV, shCV, ::Val{D}, ::Val{IT},
) where {D, IT}
    T = real(eltype(psi))
    CT = Complex{T}
    W = 16
    # conjV[k, j] (j=cc) → (cc-1)*D + k ;  V[c, k] (c=cc) → (k-1)*D + cc
    cvlin = (c, k) -> (c - 1) * D + k
    vlin  = (c, k) -> (k - 1) * D + c

    s = (active && in_range) ? (@inbounds psi[vox, cc]) : zero(CT)

    # Step 1: R_z(-α) → s_c *= cis(+m_c α)
    s *= cis(m_c * α)
    # Step 2: R_y(-β) = V·diag(cis(+βλ))·conj(V)ᵀ
    s = _warp_matvec(s, shCV, cc, Val(D), Val(W), cvlin) * cis(β * λ_c)
    s = _warp_matvec(s, shV, cc, Val(D), Val(W), vlin)
    # Step 3: D_z(θ)
    s *= IT ? exp(-m_c * θ) : cis(-m_c * θ)
    # Step 4: R_y(β)
    s = _warp_matvec(s, shCV, cc, Val(D), Val(W), cvlin) * cis(-β * λ_c)
    s = _warp_matvec(s, shV, cc, Val(D), Val(W), vlin)
    # Step 5: R_z(α) → s_c *= cis(-m_c α)
    s *= cis(-m_c * α)

    if active && in_range
        @inbounds psi[vox, cc] = s
    end
    nothing
end

@inline function _ddi_euler_warp_kernel!(
    psi, phi_x, phi_y, phi_z, m_gpu, λ_gpu, V, conj_V, dt::T, ::Val{D}, ::Val{IT},
) where {T, D, IT}
    CT = Complex{T}
    shV = CUDA.CuStaticSharedArray(CT, D * D)
    shCV = CUDA.CuStaticSharedArray(CT, D * D)
    _load_shared_eigvecs!(shV, shCV, V, conj_V, Val(D * D))

    tib = CUDA.threadIdx().x
    lane0 = (tib - 1) & 31
    sg = lane0 >> 4            # 0 or 1 — subgroup (voxel within warp)
    sl = lane0 & 15           # 0..15 — local lane = component index
    warp_in_block = (tib - 1) >> 5
    gwarp = (CUDA.blockIdx().x - 1) * (CUDA.blockDim().x >> 5) + warp_in_block
    vox = gwarp * 2 + sg + 1
    N = size(psi, 1)
    active = sl < D
    in_range = vox <= N
    cc = active ? sl + 1 : 1
    m_c = active ? (@inbounds m_gpu[1, cc]) : zero(T)
    λ_c = active ? (@inbounds λ_gpu[1, cc]) : zero(T)

    # Angles are voxel-uniform: compute the transcendentals (atan/acos/sqrt)
    # ONCE on the subgroup's lane 0 and broadcast — not 13× redundantly.
    α = zero(T); β = zero(T); θ = zero(T)
    if sl == 0 && in_range
        px = @inbounds phi_x[vox]
        py = @inbounds phi_y[vox]
        pz = @inbounds phi_z[vox]
        pm = sqrt(px * px + py * py + pz * pz)
        α = atan(py, px)
        β = acos(clamp(pz / max(pm, floatmin(T)), -one(T), one(T)))
        θ = pm * dt
    end
    α = CUDA.shfl_sync(0xffffffff, α, 1, 16)
    β = CUDA.shfl_sync(0xffffffff, β, 1, 16)
    θ = CUDA.shfl_sync(0xffffffff, θ, 1, 16)
    _euler_apply_warp!(psi, vox, in_range, active, cc, α, β, θ,
        m_c, λ_c, shV, shCV, Val(D), Val(IT))
    return nothing
end

"""
    apply_ddi_euler_fused_kernel!(psi_2d, phi_x, phi_y, phi_z, m_gpu, λ_gpu, V, conj_V, dt; imaginary_time)

DDI rotation: per-voxel Euler angles computed in-register from the dipolar
field `Φ` (N-vectors `phi_x/y/z`) then the 5-stage rotation — one launch, no
separate angle-broadcast pass. Uses the warp-cooperative kernel (one component
per lane, no local-memory spill) unless `_DDI_EULER_WARP[]` is disabled.
"""
function apply_ddi_euler_fused_kernel!(
    psi_2d::CuArray{Complex{T}, 2},
    phi_x::CuArray{T}, phi_y::CuArray{T}, phi_z::CuArray{T},
    m_gpu::CuArray{T, 2}, λ_gpu::CuArray{T, 2},
    V::CuArray{Complex{T}, 2}, conj_V::CuArray{Complex{T}, 2},
    dt::Real;
    imaginary_time::Bool=false,
) where {T <: AbstractFloat}
    N = size(psi_2d, 1)
    D = size(psi_2d, 2)
    if _DDI_EULER_WARP[]
        voxels_per_block = 16        # 256 threads / 32 × 2 voxels per warp
        threads = 256
        blocks = cld(N, voxels_per_block)
        CUDA.@cuda threads = threads blocks = blocks _ddi_euler_warp_kernel!(
            psi_2d, phi_x, phi_y, phi_z, m_gpu, λ_gpu, V, conj_V, T(dt),
            Val(D), Val(imaginary_time))
    else
        threads = min(N, 256)
        blocks = cld(N, threads)
        CUDA.@cuda threads = threads blocks = blocks _ddi_euler_kernel!(
            psi_2d, phi_x, phi_y, phi_z, m_gpu, λ_gpu, V, conj_V, T(dt),
            Val(D), Val(imaginary_time))
    end
    nothing
end
