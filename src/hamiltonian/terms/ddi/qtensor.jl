# --- DDI Q-tensor builders (k-space + quasi-2D erfcx kernel) ---

"""
    _build_q_tensor!(Q_xx, Q_xy, Q_xz, Q_yy, Q_yz, Q_zz, k_vectors, k_squared, n_pts; secular=false)

Shared Q tensor construction for both padded and unpadded DDI.
Q_αβ(k) = k̂_α k̂_β - δ_αβ/3 (or secular approximation).
"""
function _build_q_tensor!(
    Q_xx,
    Q_xy,
    Q_xz,
    Q_yy,
    Q_yz,
    Q_zz,
    kx,
    ky,
    kz,
    k_squared,
    n_pts::NTuple{N, Int};
    secular::Bool=false,
) where {N}
    T = eltype(Q_xx)
    third = T(1) / T(3)
    half = T(1) / T(2)
    @inbounds for I in CartesianIndices(n_pts)
        k2 = k_squared[I]
        if iszero(k2)
            Q_xx[I] = zero(T);
            Q_yy[I] = zero(T);
            Q_zz[I] = zero(T)
            Q_xy[I] = zero(T);
            Q_xz[I] = zero(T);
            Q_yz[I] = zero(T)
            continue
        end

        kv_x = kx[I[1]]
        kv_y = N >= 2 ? ky[I[2]] : zero(T)
        kv_z = N >= 3 ? kz[I[3]] : zero(T)

        inv_k2 = one(T) / k2

        if secular
            qzz = kv_z * kv_z * inv_k2 - third
            Q_zz[I] = qzz
            Q_xx[I] = -qzz * half
            Q_yy[I] = -qzz * half
        else
            Q_xx[I] = kv_x * kv_x * inv_k2 - third
            Q_yy[I] = kv_y * kv_y * inv_k2 - third
            Q_zz[I] = kv_z * kv_z * inv_k2 - third
            Q_xy[I] = kv_x * kv_y * inv_k2
            Q_xz[I] = kv_x * kv_z * inv_k2
            Q_yz[I] = kv_y * kv_z * inv_k2
        end
    end

    # Enforce rfft Hermitian symmetry at kx = Nyquist (last rfft bin, index n_pts[1]).
    # Q_xy and Q_xz are antisymmetric there: Q_αβ[Nyq,j,k] = −Q_αβ[Nyq,−j,−k].
    # This violates irfft's conjugate-symmetry assumption and injects a systematic
    # chiral bias into the DDI potential (manifests as a fixed -45° spin texture
    # direction that is independent of the random seed). Zeroing the Nyquist slice
    # removes the artifact; the mode carries no physical energy in a properly
    # dealiased simulation. The secular and quasi-2D paths already set these to
    # zero everywhere, so no fix is needed for those branches.
    if !secular
        nyq_ix = n_pts[1]  # rfft_output_shape[1] = grid_n[1] ÷ 2 + 1
        fill!(selectdim(Q_xy, 1, nyq_ix), zero(T))
        if N >= 3
            fill!(selectdim(Q_xz, 1, nyq_ix), zero(T))
        end
    end

    nothing
end

"""
    _quasi_2d_kernel(k_perp, l_z) → Float64

Quasi-2D DDI kernel h(k⊥ l_z) from z-integrated dipolar interaction.

    h(u) = 2/3 - u√(π/2) erfcx(u/√2)

where u = k⊥ · l_z.

Limits: h(0) = 2/3 (repulsive), h(∞) → -1/3 (attractive).
"""
function _quasi_2d_kernel(k_perp::T, l_z::T) where {T <: AbstractFloat}
    u = k_perp * l_z
    two_thirds = T(2) / T(3)
    u < T(1e-15) && return two_thirds
    two_thirds - u * sqrt(T(π) / T(2)) * erfcx(u / sqrt(T(2)))
end
_quasi_2d_kernel(k_perp::AbstractFloat, l_z::AbstractFloat) = _quasi_2d_kernel(
    promote(k_perp, l_z)...
)

"""
Build Q tensor for quasi-2D DDI (secular approximation) on a 2D grid.

Q_zz = h(k⊥ l_z), Q_xx = Q_yy = -Q_zz/2, off-diagonal = 0.
"""
function _build_q_tensor_quasi2d!(
    Q_xx,
    Q_xy,
    Q_xz,
    Q_yy,
    Q_yz,
    Q_zz,
    kx,
    ky,
    k_squared,
    n_pts::NTuple{2, Int},
    l_z,
)
    T = eltype(Q_xx)
    l_z_t = T(l_z)
    half = T(1) / T(2)
    @inbounds for I in CartesianIndices(n_pts)
        k2 = k_squared[I]
        k_perp = sqrt(k2)
        qzz = _quasi_2d_kernel(k_perp, l_z_t)
        Q_zz[I] = qzz
        Q_xx[I] = -qzz * half
        Q_yy[I] = -qzz * half
        Q_xy[I] = zero(T)
        Q_xz[I] = zero(T)
        Q_yz[I] = zero(T)
    end
    nothing
end
