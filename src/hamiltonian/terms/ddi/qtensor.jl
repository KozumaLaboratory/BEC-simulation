# --- DDI Q-tensor builders (k-space + quasi-2D erfcx kernel) ---

"""
    _build_q_tensor!(Q_xx, Q_xy, Q_xz, Q_yy, Q_yz, Q_zz, kx, ky, kz, k_squared, rk_shape;
                     secular=false, full_n=nothing)

Shared Q tensor construction for both padded and unpadded DDI.
Q_αβ(k) = k̂_α k̂_β - δ_αβ/3 (or secular approximation), built on the
rfft half-grid `rk_shape`.

`full_n` is the full (un-halved) spatial grid size per axis. When given,
the three off-diagonals — each ODD in two axes — are zeroed on the
Nyquist plane(s) of the axes they are odd in. At a Nyquist mode the
discrete grid folds ±k_Nyq onto one bin, and the continuum value of an
odd kernel there is 0. Production stores +k_Nyq on the rfft axis 1 but
−k_Nyq on the full-fft axes (rfftfreq vs fftfreq), so keeping the raw
signed representative gives an x↔y(↔z) ASYMMETRIC off-diagonal kernel —
a z-polarized cloud then relaxes into a spuriously squished shape even
though the trap, field and dipole axis are all symmetric. Zeroing on
every odd-axis Nyquist plane restores the symmetry to machine precision
(`scripts/ddi_nyquist_xy_asymmetry_probe.jl`). The diagonals are even in
every axis and are untouched; the secular branch never writes the
off-diagonals (they stay 0).
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
    rk_shape::NTuple{N, Int};
    secular::Bool=false,
    full_n::Union{Nothing, NTuple{N, Int}}=nothing,
) where {N}
    T = eltype(Q_xx)
    third = T(1) / T(3)
    half = T(1) / T(2)
    # Nyquist index per axis (0 = axis has no Nyquist mode, i.e. odd full_n
    # or full_n not supplied). Axis 1 lives on the rfft half-grid so its
    # Nyquist sits at the last stored index full_n[1]÷2+1.
    nyq = full_n === nothing ? ntuple(_ -> 0, Val(N)) :
        ntuple(d -> iseven(full_n[d]) ? full_n[d] ÷ 2 + 1 : 0, Val(N))
    @inbounds for I in CartesianIndices(rk_shape)
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

            x_nyq = nyq[1] != 0 && I[1] == nyq[1]
            y_nyq = N >= 2 && nyq[2] != 0 && I[2] == nyq[2]
            z_nyq = N >= 3 && nyq[3] != 0 && I[3] == nyq[3]

            Q_xy[I] = (x_nyq || y_nyq) ? zero(T) : kv_x * kv_y * inv_k2
            Q_xz[I] = (x_nyq || z_nyq) ? zero(T) : kv_x * kv_z * inv_k2
            Q_yz[I] = (y_nyq || z_nyq) ? zero(T) : kv_y * kv_z * inv_k2
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
