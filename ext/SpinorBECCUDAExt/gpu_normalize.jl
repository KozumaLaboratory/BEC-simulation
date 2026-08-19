# GPU-native normalization and constrained normalization
#
# Key optimization: compute all D component norms in a single GPU reduction
# instead of D separate sum(abs2, view(psi, ..., c)) calls that each require
# a GPU→CPU sync point.

"""
GPU-native normalize: one GPU reduction, and the norm never leaves the device.

`sum(abs2, psi)` returns a HOST scalar, so it ends in a device-to-host copy —
i.e. a full stream drain. ITP normalises on EVERY step (`normalize_every = 1`
whenever the magnetisation is unconstrained), so that was one host round-trip
per step: measured 61 µs at 32³ and 152 µs at 64³ on an H100, which is 12 % of
a 32³ ITP step and, at 8× the data for 2.5× the time, plainly latency and not
bandwidth. Reducing with `dims` leaves the result in a `(1,1,…,1)` device array
that broadcasts against ψ, so nothing is transferred and nothing waits.

Same failure mode the Taylor rotation's per-voxel degree was introduced to
avoid (gpu_spin_rotation_taylor.jl, "Accuracy contract"): a scalar read back to
the host is a stream drain wearing a reduction's clothes.

Not bit-identical to the scalar form — a `dims` reduction need not sum in the
same order — but it is the same quantity to within reduction round-off, and it
is a normalisation constant.
"""
function SpinorBEC._normalize_psi!(psi::CuArray{<:Complex}, grid, n_components, ndim)
    dV = SpinorBEC.cell_volume(grid)
    norm_sq = sum(abs2, psi; dims=ntuple(identity, ndims(psi)))  # stays on device
    psi ./= sqrt.(norm_sq .* dV)
    nothing
end

"""
GPU-native constrained normalization.

Instead of D separate sum(abs2, view(psi,...,c)) calls per Newton iteration
(each causing a GPU sync), we compute all D norms in a single GPU reduction
and transfer the D-element vector once.
"""
function SpinorBEC._normalize_psi_constrained!(
    psi::CuArray{<:Complex}, grid, n_components, ndim, target_Mz, F
)
    dV = SpinorBEC.cell_volume(grid)
    D = n_components
    N_spatial = prod(ntuple(d -> size(psi, d), ndim))

    # First normalize
    SpinorBEC._normalize_psi!(psi, grid, n_components, ndim)

    # Compute base norms (one GPU reduction for all components)
    psi_2d = reshape(psi, N_spatial, D)
    base_norms_gpu = sum(abs2, psi_2d; dims=1)  # 1×D on GPU
    base_norms = vec(Array(base_norms_gpu)) .* dV  # single transfer

    # Newton iteration on host using pre-computed base norms
    # norms[c] = base_norms[c] * exp(2λm_c), so we don't need to touch GPU
    lambda = 0.0
    m_vals = Float64[F - (c - 1) for c in 1:D]

    for _iter in 1:20
        norms = similar(base_norms)
        for c in 1:D
            w = exp(lambda * m_vals[c])
            norms[c] = base_norms[c] * w^2
        end
        total = sum(norms)
        total < COUPLING_TOL && break

        Mz = sum(m_vals[c] * norms[c] for c in 1:D) / total
        abs(Mz - target_Mz) < 1e-12 && break

        dMz = 0.0
        for c in 1:D
            dMz += 2 * m_vals[c] * (m_vals[c] - Mz) * norms[c] / total
        end
        abs(dMz) < COUPLING_TOL && break

        lambda -= (Mz - target_Mz) / dMz
        lambda = clamp(lambda, -10.0, 10.0)
    end

    # Apply weights on GPU (one kernel per component, no sync needed until done)
    for c in 1:D
        w = exp(lambda * m_vals[c])
        view(psi_2d, :, c) .*= w
    end

    SpinorBEC._normalize_psi!(psi, grid, n_components, ndim)
    nothing
end
