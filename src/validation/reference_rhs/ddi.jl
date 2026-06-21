# --- Reference Hψ: dipole-dipole interaction (DDI) ---
#
# Production path: src/hamiltonian/terms/ddi/qtensor.jl,
# convolution.jl; src/hamiltonian/terms/ddi/rotation.jl. We re-derive the same operator from
# scratch on a fresh rfft plan, with no precomputed Q-tensor cache
# and no reuse of production DDIBuffers, so any bug in the production
# cache or buffer plumbing shows up as a diff.
#
# Conventions (matched to production + parameter contract §4):
#   c_dd = μ₀ μ²                         (no 4π)
#   Q_αβ(k) = k̂_α k̂_β − δ_αβ/3          (no 1/(4π); secular collapses
#                                          to Q_zz = k̂_z²−1/3, Q_xx = Q_yy = −Q_zz/2)
#   Q(k=0) = 0
#   Mean-field action: (H_DDI ψ)_c(r) = c_dd Σ_α Φ_α(r) (F_α ψ)_c(r)
#     where Φ_α(r) = IFFT[Σ_β Q_αβ(k) · FFT[f_β(r)]] and
#           f_β(r) = ⟨ψ(r)|F_β|ψ(r)⟩.
#   Energy: E_DDI = (c_dd / 2) ∫ Φ·f dV (c_dd carried outside Phi here;
#                                         production folds it inside the
#                                         k-space contraction buffer).
#
# Uses real FFT (rfft) for the first axis, matching production's grid.
# rfftfreq stores +k_Nyquist on axis 1 while fftfreq stores −k_Nyquist on
# the full-complex axes, so the odd-in-k off-diagonal Q_αβ would acquire
# an axis-asymmetric sign at the Nyquist planes. The continuum kernel of
# an odd function at a folded Nyquist mode is 0, so we zero the off-diagonals
# there (every odd-axis Nyquist plane) — this is what keeps the DDI mean
# field x↔y(↔z) symmetric and matches production `_build_q_tensor!`.
# Independence is preserved by building a fresh plan and Q-tensor here.

export reference_ddi_apply!, reference_ddi_energy
export reference_ddi_potentials

"""
    reference_ddi_potentials(psi, sm, grid; secular=false) → (Phi_x, Phi_y, Phi_z)

Compute the three DDI mean-field potentials `Φ_α(r)` (without the
`c_dd` prefactor; multiply outside).

`secular=true` keeps only the rotating-frame-averaged piece (Q_zz
nonzero; Q_xx = Q_yy = -Q_zz/2; off-diagonal Q zero).
"""
function reference_ddi_potentials(
    psi::AbstractArray{<:Complex},
    sm::SpinMatrices{D},
    grid::Grid{N};
    secular::Bool=false,
) where {D, N}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    rk_shape = rfft_output_shape(n_pts)
    fx, fy, fz = spin_density_vector(psi, sm, N)

    rp = make_rfft_plans(n_pts)
    Fx_rk = rp.forward * fx
    Fy_rk = rp.forward * fy
    Fz_rk = rp.forward * fz

    kx_r = collect(Float64, rfftfreq(n_pts[1], n_pts[1] * grid.dk[1]))
    ky = N >= 2 ? grid.k[2] : Float64[]
    kz = N >= 3 ? grid.k[3] : Float64[]

    # Nyquist index per axis (0 = none). The off-diagonal Q components are
    # odd in their two axes; their continuum value at a folded Nyquist mode
    # is 0, and keeping the asymmetric rfft(+k_Nyq)/fft(−k_Nyq) representative
    # would break x↔y(↔z) symmetry. Zero them on every odd-axis Nyquist plane
    # (matches production `_build_q_tensor!`).
    nyq = ntuple(d -> iseven(n_pts[d]) ? n_pts[d] ÷ 2 + 1 : 0, Val(N))

    Phi_x_rk = zeros(ComplexF64, rk_shape)
    Phi_y_rk = zeros(ComplexF64, rk_shape)
    Phi_z_rk = zeros(ComplexF64, rk_shape)

    @inbounds for I in CartesianIndices(rk_shape)
        kv_x = kx_r[I[1]]
        kv_y = N >= 2 ? ky[I[2]] : 0.0
        kv_z = N >= 3 ? kz[I[3]] : 0.0
        k2 = kv_x * kv_x + kv_y * kv_y + kv_z * kv_z
        if k2 == 0.0
            continue
        end
        inv_k2 = 1.0 / k2
        Q_zz = kv_z * kv_z * inv_k2 - 1.0 / 3.0
        if secular
            Q_xx = -0.5 * Q_zz
            Q_yy = -0.5 * Q_zz
            Q_xy = 0.0
            Q_xz = 0.0
            Q_yz = 0.0
        else
            Q_xx = kv_x * kv_x * inv_k2 - 1.0 / 3.0
            Q_yy = kv_y * kv_y * inv_k2 - 1.0 / 3.0
            x_nyq = nyq[1] != 0 && I[1] == nyq[1]
            y_nyq = N >= 2 && nyq[2] != 0 && I[2] == nyq[2]
            z_nyq = N >= 3 && nyq[3] != 0 && I[3] == nyq[3]
            Q_xy = (x_nyq || y_nyq) ? 0.0 : kv_x * kv_y * inv_k2
            Q_xz = (x_nyq || z_nyq) ? 0.0 : kv_x * kv_z * inv_k2
            Q_yz = (y_nyq || z_nyq) ? 0.0 : kv_y * kv_z * inv_k2
        end
        fxk = Fx_rk[I]
        fyk = Fy_rk[I]
        fzk = Fz_rk[I]
        Phi_x_rk[I] = Q_xx * fxk + Q_xy * fyk + Q_xz * fzk
        Phi_y_rk[I] = Q_xy * fxk + Q_yy * fyk + Q_yz * fzk
        Phi_z_rk[I] = Q_xz * fxk + Q_yz * fyk + Q_zz * fzk
    end

    Phi_x = rp.inverse * Phi_x_rk
    Phi_y = rp.inverse * Phi_y_rk
    Phi_z = rp.inverse * Phi_z_rk
    (Phi_x, Phi_y, Phi_z)
end

"""
    reference_ddi_apply!(out, psi, sm, grid, c_dd; secular=false)

Write the DDI GP nonlinear term:
`(H_DDI ψ)_c(r) = c_dd Σ_α Φ_α(r) (F_α ψ)_c(r)`.
"""
function reference_ddi_apply!(
    out::AbstractArray{<:Complex},
    psi::AbstractArray{<:Complex},
    sm::SpinMatrices{D},
    grid::Grid{N},
    c_dd::Real;
    secular::Bool=false,
) where {D, N}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    Phi_x, Phi_y, Phi_z = reference_ddi_potentials(psi, sm, grid; secular=secular)
    Fx = sm.Fx
    Fy = sm.Fy
    Fz = sm.Fz
    @inbounds for I in CartesianIndices(n_pts)
        PxI = Phi_x[I]
        PyI = Phi_y[I]
        PzI = Phi_z[I]
        for c in 1:D
            s = zero(ComplexF64)
            for cp in 1:D
                s += (PxI * Fx[c, cp] + PyI * Fy[c, cp] + PzI * Fz[c, cp]) * psi[I, cp]
            end
            out[I, c] = c_dd * s
        end
    end
    out
end

"""
    reference_ddi_energy(psi, sm, grid, c_dd; secular=false) → Float64

`E_DDI = (c_dd / 2) ∫ Φ(r)·f(r) dV`. Matches `_ddi_energy` (note the
production buffers fold `c_dd` into `Phi_*` so the explicit `c_dd` lives
in `compute_ddi_potential!`; we keep them separated here).
"""
function reference_ddi_energy(
    psi::AbstractArray{<:Complex},
    sm::SpinMatrices{D},
    grid::Grid{N},
    c_dd::Real;
    secular::Bool=false,
) where {D, N}
    Phi_x, Phi_y, Phi_z = reference_ddi_potentials(psi, sm, grid; secular=secular)
    fx, fy, fz = spin_density_vector(psi, sm, N)
    dV = cell_volume(grid)
    s = 0.0
    @inbounds for i in eachindex(fx, fy, fz)
        s += Phi_x[i] * fx[i] + Phi_y[i] * fy[i] + Phi_z[i] * fz[i]
    end
    0.5 * c_dd * s * dV
end
