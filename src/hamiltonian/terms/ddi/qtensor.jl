# --- DDI Q-tensor builders (k-space + quasi-2D erfcx kernel) ---

"""
    _zero_odd_offdiag_at_nyquist!(Q_xy, Q_xz, Q_yz, full_n)

Enforce the x↔y(↔z) symmetry of the DDI kernel by zeroing the off-diagonal
Q components on the Nyquist plane(s) of the axes they are ODD in
(Q_xy: axes 1,2 · Q_xz: axes 1,3 · Q_yz: axes 2,3).

A Nyquist mode is its own mirror under k → −k (the grid folds ±k_Nyq onto
one bin), so an ODD kernel must vanish there — exactly as an odd function
vanishes at 0. Production stores +k_Nyq on the rfft axis but −k_Nyq on the
full-fft axes, so the raw representative is nonzero and axis-asymmetric; a
z-polarized cloud then relaxes into a spuriously squished shape despite a
symmetric trap, field and dipole axis. See
`scripts/ddi_nyquist_xy_asymmetry_probe.jl` and the regression test
`test/hamiltonian/test_ddi_nyquist_xy_symmetry.jl`.
"""
function _zero_odd_offdiag_at_nyquist!(Q_xy, Q_xz, Q_yz, full_n::NTuple{N, Int}) where {N}
    odd_axes = ((Q_xy, (1, 2)), (Q_xz, (1, 3)), (Q_yz, (2, 3)))
    for d in 1:N
        iseven(full_n[d]) || continue          # odd length ⇒ no self-mirror mode
        idx = full_n[d] ÷ 2 + 1                 # rfft last bin = fft Nyquist bin
        for (Q, axes) in odd_axes
            d in axes && fill!(selectdim(Q, d, idx), zero(eltype(Q)))
        end
    end
    return nothing
end

"""
    ddi_trunc_factor(x) → T

Radial modifier `h(x)` of the spherically-truncated DDI kernel
(Ronen–Bortolotti–Bohn, PRA 74, 013623 (2006); the spectral-accuracy
analysis is Vico–Greengard–Ferrando, JCP 323, 191 (2016)). Cutting the
real-space dipolar interaction at radius `R` multiplies its k-space tensor
kernel `k̂_α k̂_β − δ_αβ/3` by

    h(x) = 1 + 3cos(x)/x² − 3sin(x)/x³,   x = |k| R.

`h(0) = 0` (consistent with the existing `Q(k=0) = 0` spherical-cavity
convention) and `h(x) → 1` for `x ≫ 1` (bulk physics unchanged). Because
`h` multiplies the *whole* traceless tensor it preserves tracelessness and
is completely independent of the spinor DDI rotation machinery.

A small-`x` series (`h(x) ≈ x²/10 − x⁴/280 + …`) guards the `3cos/x² −
3sin/x³` catastrophic cancellation (both terms ~`3/x²`). On an FFT grid the
smallest nonzero `x = 2πR/L ≥ π` for any sane `R`, so the series branch is
defensive only (it matters for pathologically small `R` or Float32).
"""
@inline function ddi_trunc_factor(x::T) where {T <: AbstractFloat}
    if x < T(1)                      # defensive: FFT grid has x ≥ π in practice
        x2 = x * x
        return x2 * (T(1) / 10 + x2 * (-T(1) / 280 + x2 * (T(1) / 15120 - x2 / T(1330560))))
    else
        return one(T) + T(3) * cos(x) / (x * x) - T(3) * sin(x) / (x * x * x)
    end
end

"""
    _build_q_tensor!(Q_xx, Q_xy, Q_xz, Q_yy, Q_yz, Q_zz, kx, ky, kz, k_squared, rk_shape;
                     secular=false, full_n=nothing, trunc_radius=nothing)

Shared Q tensor construction for both padded and unpadded DDI:
`Q_αβ(k) = k̂_α k̂_β - δ_αβ/3` (or the secular approximation), on the rfft
half-grid `rk_shape`. Pass `full_n` (the un-halved spatial grid size per
axis) to enforce kernel symmetry at the Nyquist planes via
[`_zero_odd_offdiag_at_nyquist!`](@ref). The diagonals are even in every
axis (Nyquist-safe); the secular branch leaves the off-diagonals at 0.

`trunc_radius` (a physical length, or `nothing` to disable) applies the
spherically-truncated kernel: every component is multiplied by
[`ddi_trunc_factor`](@ref)`(|k|·R)`. This kills the lattice-anisotropy main
term (the angular discontinuity of `k̂_α k̂_β` at the origin) with spectral
accuracy at fixed resolution, instead of trying to converge it away by
refining the grid. The `k=0` bin stays `0` (matching the spherical-cavity
convention; `h(0)=0`), so no contact/local-field term is introduced.
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
    trunc_radius::Union{Nothing, Float64}=nothing,
) where {N}
    T = eltype(Q_xx)
    third = T(1) / T(3)
    half = T(1) / T(2)
    R = trunc_radius === nothing ? zero(T) : T(trunc_radius)
    do_trunc = trunc_radius !== nothing
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
        # Radial mollifier of the truncated kernel (1 when disabled).
        hx = do_trunc ? ddi_trunc_factor(sqrt(k2) * R) : one(T)

        if secular
            qzz = (kv_z * kv_z * inv_k2 - third) * hx
            Q_zz[I] = qzz
            Q_xx[I] = -qzz * half
            Q_yy[I] = -qzz * half
        else
            Q_xx[I] = (kv_x * kv_x * inv_k2 - third) * hx
            Q_yy[I] = (kv_y * kv_y * inv_k2 - third) * hx
            Q_zz[I] = (kv_z * kv_z * inv_k2 - third) * hx
            Q_xy[I] = kv_x * kv_y * inv_k2 * hx
            Q_xz[I] = kv_x * kv_z * inv_k2 * hx
            Q_yz[I] = kv_y * kv_z * inv_k2 * hx
        end
    end
    secular || full_n === nothing || _zero_odd_offdiag_at_nyquist!(Q_xy, Q_xz, Q_yz, full_n)
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
