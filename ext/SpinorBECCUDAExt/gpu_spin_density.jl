# Fused GPU spin-density kernel.
#
# The generic broadcast path issues ~1+(D-1) launches for F_z and ~2+2(D-2)
# for F_x/F_y (≈37 at D=13), each round-tripping ψ-components and an
# accumulator through HBM. This single kernel reads the D components of each
# voxel ONCE from registers and writes the three real fields once:
#
#   F_z = Σ_c m_c |ψ_c|² ,  F_x = Σ_c g_c Re(ψ̄_{c-1} ψ_c) ,  F_y = Σ_c g_c Im(…)
#
# m_c and g_c (= fp_ladder_coeffs) match the CPU `_compute_spin_density!(::Array)`
# exactly (single physics declaration). Only the contiguous (unpadded) case is
# fused; the zero-padded DDI corner write falls back to the broadcast form.

using StaticArrays: SVector

@inline function _spin_density_kernel!(Fx, Fy, Fz, P, m_vals, fp, ::Val{D}) where {D}
    i = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    i > size(P, 1) && return nothing
    Tr = real(eltype(P))
    fz = zero(Tr)
    fxr = zero(Tr)
    fyi = zero(Tr)
    prev = @inbounds P[i, 1]
    fz += m_vals[1] * abs2(prev)
    @inbounds for c in 2:D
        cur = P[i, c]
        fz += m_vals[c] * abs2(cur)
        pr = conj(prev) * cur
        fxr += fp[c] * real(pr)
        fyi += fp[c] * imag(pr)
        prev = cur
    end
    @inbounds begin
        Fx[i] = fxr
        Fy[i] = fyi
        Fz[i] = fz
    end
    return nothing
end

# Broadcast fallback for the zero-padded DDI case (F buffers larger than n_pts):
# write only the spatial corner via views — matches the generic AbstractArray path.
function _spin_density_corner_bcast!(fx, fy, fz, psi, F, ::Val{D}, ndim, n_pts) where {D}
    m_vals = ntuple(c -> Float64(F - (c - 1)), Val(D))
    fp = SpinorBEC.fp_ladder_coeffs(F, Val(D))
    spatial_idx = ntuple(d -> 1:n_pts[d], ndim)
    fz_v = view(fz, spatial_idx...)
    fx_v = view(fx, spatial_idx...)
    fy_v = view(fy, spatial_idx...)
    psi1 = view(psi, SpinorBEC._component_slice(ndim, n_pts, 1)...)
    @. fz_v = m_vals[1] * abs2(psi1)
    for c in 2:D
        psi_c = view(psi, SpinorBEC._component_slice(ndim, n_pts, c)...)
        @. fz_v += m_vals[c] * abs2(psi_c)
    end
    psi_p = view(psi, SpinorBEC._component_slice(ndim, n_pts, 1)...)
    psi_c = view(psi, SpinorBEC._component_slice(ndim, n_pts, 2)...)
    @. fx_v = fp[2] * (real(psi_p) * real(psi_c) + imag(psi_p) * imag(psi_c))
    @. fy_v = fp[2] * (real(psi_p) * imag(psi_c) - imag(psi_p) * real(psi_c))
    for c in 3:D
        psi_p = view(psi, SpinorBEC._component_slice(ndim, n_pts, c - 1)...)
        psi_c = view(psi, SpinorBEC._component_slice(ndim, n_pts, c)...)
        @. fx_v += fp[c] * (real(psi_p) * real(psi_c) + imag(psi_p) * imag(psi_c))
        @. fy_v += fp[c] * (real(psi_p) * imag(psi_c) - imag(psi_p) * real(psi_c))
    end
    nothing
end

function SpinorBEC._compute_spin_density!(
    fx::CuArray, fy::CuArray, fz::CuArray,
    psi::CuArray{Complex{T}}, sm, ::Val{D}, ndim, n_pts,
) where {T, D}
    F = sm.system.F
    if !(size(fx) == n_pts && size(fy) == n_pts && size(fz) == n_pts)
        # zero-padded DDI: write the n_pts corner via broadcast.
        return _spin_density_corner_bcast!(fx, fy, fz, psi, F, Val(D), ndim, n_pts)
    end
    Ns = prod(n_pts)
    m_vals = SVector{D, T}(ntuple(c -> T(F - (c - 1)), Val(D)))
    fpc = SpinorBEC.fp_ladder_coeffs(T, F, Val(D))
    fp = SVector{D, T}(fpc)
    P = reshape(psi, Ns, D)
    Fx = reshape(fx, Ns)
    Fy = reshape(fy, Ns)
    Fz = reshape(fz, Ns)
    threads = min(Ns, 256)
    blocks = cld(Ns, threads)
    CUDA.@cuda threads = threads blocks = blocks _spin_density_kernel!(
        Fx, Fy, Fz, P, m_vals, fp, Val(D))
    nothing
end
