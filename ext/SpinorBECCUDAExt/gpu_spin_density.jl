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
# exactly (single physics declaration).
#
# The zero-padded DDI case writes the same voxels into the `[1:n_pts...]` corner
# of a larger buffer. That used to fall back to the broadcast form — and since
# `DDI_PADDED_DEFAULT` flipped to `true` (9c117c05) that fallback is what every
# production run takes, so the fused kernel was reaching almost nothing. It is
# the same reduction either way; only the destination index differs, which is
# what `dst` carries (`nothing` = contiguous, a `CartesianIndices` = corner).

using StaticArrays: SVector

@inline function _spin_density_kernel!(Fx, Fy, Fz, P, m_vals, fp, ::Val{D}, dst) where {D}
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
        j = _voxel_index(dst, i)
        Fx[j] = fxr
        Fy[j] = fyi
        Fz[j] = fz
    end
    return nothing
end

# Reference broadcast form (≈37 launches at D=13), kept as the parity target for
# the fused corner kernel above — see test/gpu/test_gpu_padded_corner_parity.jl.
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
    Ns = prod(n_pts)
    m_vals = SVector{D, T}(ntuple(c -> T(F - (c - 1)), Val(D)))
    fp = SVector{D, T}(SpinorBEC.fp_ladder_coeffs(T, F, Val(D)))
    P = reshape(psi, Ns, D)
    # Two call sites, not one with a Union-typed tuple: each launches a
    # concretely-typed kernel. Contiguous flattens and indexes linearly; padded
    # keeps the buffers in their own shape and maps voxel → corner index.
    if size(fx) == n_pts && size(fy) == n_pts && size(fz) == n_pts
        _launch_spin_density!(
            reshape(fx, Ns), reshape(fy, Ns), reshape(fz, Ns), P, m_vals, fp,
            Val(D), nothing, Ns)
    else
        _launch_spin_density!(
            fx, fy, fz, P, m_vals, fp, Val(D), CartesianIndices(n_pts), Ns)
    end
    nothing
end

function _launch_spin_density!(Fx, Fy, Fz, P, m_vals, fp, ::Val{D}, dst, Ns) where {D}
    threads = min(Ns, 256)
    blocks = cld(Ns, threads)
    CUDA.@cuda threads = threads blocks = blocks _spin_density_kernel!(
        Fx, Fy, Fz, P, m_vals, fp, Val(D), dst)
    nothing
end
