# Channel kernel V·source contraction on GPU — Phase 5c piece 1/3.
#
# Per CPU code at `src/hamiltonian/tdhfb/strang_step.jl:200-219`, the HF
# substep builds three (D, D, N_voxels) batched matrices via the rank-4
# channel kernel V[c, c', c2, c2']:
#   U[c, c'] = Σ_{c2, c2'} V[c, c', c2, c2'] · (φ*_{c2'} φ_{c2} + ρ_{c2, c2'})
#   Δ_phi[c, c'] = Σ_{c2, c2'} V[c, c', c2, c2'] · κ_{c2, c2'}
#   Δ_R[c, c'] = Σ_{c2, c2'} V[c, c', c2, c2'] · (φ_{c2} φ_{c2'} + κ_{c2, c2'})
#
# GPU plan (design §3c Approach A — gemm reshape):
#   - V_flat: (D², D²) CuArray reshape of V[c, c', c2, c2'].
#       row index (c + (c'-1)·D), col index (c2 + (c2'-1)·D).
#   - source: per-voxel (D, D, N_voxels) reshape to (D², N_voxels).
#   - Contraction = single `CUBLAS.gemm!('N', 'N', 1, V_flat, source, 0, out)`.
# Sources are built via CUDA broadcast kernels (per-voxel outer product + add).
#
# V_flat is cached in `_GPU_TDHFB_V_CACHE` keyed by `(F, hash(g_S), precision)`.

const _GPU_TDHFB_V_CACHE = Dict{UInt64, Any}()

"""
Return the (D², D²) CuArray flat-channel-kernel matrix for (F, g_S) at the
given complex precision. First call builds it on CPU via `channel_kernel`
and ships to device; subsequent calls hit the cache.
"""
function _get_or_build_V_flat(
    F::Int,
    g_S::AbstractDict{Int, Float64},
    ::Type{TC},
) where {TC <: Complex}
    key = hash((F, g_S, TC))
    cached = get(_GPU_TDHFB_V_CACHE, key, nothing)
    cached !== nothing && return cached::CuArray{TC, 2}
    V_cpu = SpinorBEC.channel_kernel(F, g_S)
    D = size(V_cpu, 1)
    @assert size(V_cpu) == (D, D, D, D)
    V_flat_cpu = reshape(V_cpu, D * D, D * D)
    V_flat_gpu = CuArray{TC}(V_flat_cpu)
    _GPU_TDHFB_V_CACHE[key] = V_flat_gpu
    return V_flat_gpu
end

# ----- CUDA kernels building per-voxel source arrays -----
#
# All three source builders write into source[c2, c2', v] = (D, D, N_voxels).
# φ is (spatial..., D); ρ, κ are (spatial..., D, D). We pass them as
# linearized views (N_voxels, D) / (N_voxels, D, D).

function _kernel_source_U!(source, phi, rho, D::Int, N_vox::Int)
    c2 = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    c2p = (CUDA.blockIdx().y - 1) * CUDA.blockDim().y + CUDA.threadIdx().y
    v = (CUDA.blockIdx().z - 1) * CUDA.blockDim().z + CUDA.threadIdx().z
    if c2 <= D && c2p <= D && v <= N_vox
        @inbounds source[c2, c2p, v] =
            conj(phi[v, c2p]) * phi[v, c2] + rho[v, c2, c2p]
    end
    return nothing
end

function _kernel_source_kappa!(source, kappa, D::Int, N_vox::Int)
    c2 = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    c2p = (CUDA.blockIdx().y - 1) * CUDA.blockDim().y + CUDA.threadIdx().y
    v = (CUDA.blockIdx().z - 1) * CUDA.blockDim().z + CUDA.threadIdx().z
    if c2 <= D && c2p <= D && v <= N_vox
        @inbounds source[c2, c2p, v] = kappa[v, c2, c2p]
    end
    return nothing
end

function _kernel_source_DeltaR!(source, phi, kappa, D::Int, N_vox::Int)
    c2 = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    c2p = (CUDA.blockIdx().y - 1) * CUDA.blockDim().y + CUDA.threadIdx().y
    v = (CUDA.blockIdx().z - 1) * CUDA.blockDim().z + CUDA.threadIdx().z
    if c2 <= D && c2p <= D && v <= N_vox
        @inbounds source[c2, c2p, v] =
            phi[v, c2] * phi[v, c2p] + kappa[v, c2, c2p]
    end
    return nothing
end

# Launch helper — picks reasonable thread/block partition for (D, D, N_vox).
function _launch_3d_kernel(kernel, args, D::Int, N_vox::Int)
    threads_c = min(D, 4)
    threads_v = min(N_vox, 32)
    blocks_c = cld(D, threads_c)
    blocks_v = cld(N_vox, threads_v)
    CUDA.@cuda(
        threads=(threads_c, threads_c, threads_v),
        blocks=(blocks_c, blocks_c, blocks_v),
        kernel(args...),
    )
    nothing
end

"""
Build the source matrix `source = (D², N_voxels)` for the U contraction:
`source[c2 + (c2'-1)·D, v] = conj(φ[v, c2']) · φ[v, c2] + ρ[v, c2, c2']`.
"""
function _build_source_U!(
    source_flat::CuArray{TC, 2},
    phi::CuArray{TC, M},
    rho::CuArray{TC, M_rho},
    D::Int,
) where {TC, M, M_rho}
    spatial = size(phi)[1:(end - 1)]
    N_vox = prod(spatial)
    phi_v = reshape(phi, N_vox, D)
    rho_v = reshape(rho, N_vox, D, D)
    source_3d = reshape(source_flat, D, D, N_vox)
    _launch_3d_kernel(_kernel_source_U!, (source_3d, phi_v, rho_v, D, N_vox), D, N_vox)
    source_flat
end

"""Build `source[c2, c2', v] = κ[v, c2, c2']` for the Δ_phi contraction."""
function _build_source_kappa!(
    source_flat::CuArray{TC, 2},
    kappa::CuArray{TC, M_kappa},
    D::Int,
) where {TC, M_kappa}
    spatial = size(kappa)[1:(end - 2)]
    N_vox = prod(spatial)
    kappa_v = reshape(kappa, N_vox, D, D)
    source_3d = reshape(source_flat, D, D, N_vox)
    _launch_3d_kernel(_kernel_source_kappa!, (source_3d, kappa_v, D, N_vox), D, N_vox)
    source_flat
end

"""Build `source[c2, c2', v] = φ[v, c2] · φ[v, c2'] + κ[v, c2, c2']` for Δ_R."""
function _build_source_DeltaR!(
    source_flat::CuArray{TC, 2},
    phi::CuArray{TC, M},
    kappa::CuArray{TC, M_kappa},
    D::Int,
) where {TC, M, M_kappa}
    spatial = size(phi)[1:(end - 1)]
    N_vox = prod(spatial)
    phi_v = reshape(phi, N_vox, D)
    kappa_v = reshape(kappa, N_vox, D, D)
    source_3d = reshape(source_flat, D, D, N_vox)
    _launch_3d_kernel(_kernel_source_DeltaR!, (source_3d, phi_v, kappa_v, D, N_vox), D, N_vox)
    source_flat
end

"""
Contract V·source via batched gemm. Both inputs are `(D², N_voxels)`-shaped;
`out_flat[(c + (c'-1)·D), v] = Σ V_flat[..., col] · source_flat[col, v]`.
After this, reshape `out_flat` to (D, D, N_voxels) to recover the per-voxel
D×D matrix structure.
"""
function _contract_V_source!(
    out_flat::CuArray{TC, 2},
    V_flat::CuArray{TC, 2},
    source_flat::CuArray{TC, 2},
) where {TC <: Complex}
    CUDA.CUBLAS.gemm!(
        'N', 'N',
        one(TC), V_flat, source_flat,
        zero(TC), out_flat,
    )
    out_flat
end
