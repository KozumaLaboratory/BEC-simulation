# GPU DDI Euler rotation via the single-launch phi-angle kernel.
#
# The generic `SpinorBEC._apply_ddi_rotation!(::AbstractArray, …)` drove the
# GPU through the broadcast-+-cuBLAS chain (~4 gemms + ~9 elementwise launches
# + W HBM round-trips, twice per step). This override computes the per-voxel
# Euler angles from the dipolar field IN the rotation kernel
# (`apply_ddi_euler_fused_kernel!`, gpu_euler_kernel.jl) — one launch, no
# separate angle-broadcast pass, no α/β/θ scratch round-trip.
#
# Math matches the CPU batched path to machine epsilon and the prior GPU
# broadcast path (Step1 +m·α, Ry(β), Dz ∓m·θ, Ry(-β), Step5 -m·α). Padded-DDI
# fields are cropped to the spatial corner first (matches `_ddi_crop_phi`).

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
    cache = _get_gpu_ddi_rot_cache(psi, sm, ndim)

    P = reshape(psi, N, D)
    px = _gpu_phi_vec(phi_x, n_pts, N)
    py = _gpu_phi_vec(phi_y, n_pts, N)
    pz = _gpu_phi_vec(phi_z, n_pts, N)

    apply_ddi_euler_fused_kernel!(
        P, px, py, pz, cache.m_row, cache.λ_row, cache.V, cache.conj_V, dt_frac;
        imaginary_time=imaginary_time,
    )
    nothing
end
