# --- Dipolar magnetic field from a magnetization / density distribution ---
#
# The field a spin-polarised cloud radiates is the magnetostatic analogue of
# the DDI mean-field potential: same k-space convolution with the dipole
# kernel `Q_αβ = k̂_α k̂_β − δ_αβ/3`, only the prefactor differs (μ₀·moment
# for a field, μ₀·moment² for an energy). We reuse the validated DDI Q-tensor
# builder + k-contraction so the convolution math has a single source.
#
#     B_α(r) = -μ₀ · ℱ⁻¹{ Σ_β Q_αβ(k) M̃_β(k) }
#
# `Q(k=0)=0` drops the uniform/contact (Fermi δ) part automatically — the same
# term the MATLAB reference (Kishor Kumar et al., CPC 195 (2015) 117) discards
# by hand. The kernel is scale-free (depends only on the direction of k), so
# the field comes out in tesla as long as the magnetisation is in A/m; the
# grid length scale only matters for turning a normalised density into a
# physical one.

export dipole_magnetic_field, magnetic_field_from_density, magnetic_field_from_spinor

function _dipole_q_tensor(grid::Grid{3}, work_shape::NTuple{3, Int})
    dx = grid.dx
    rk_shape = rfft_output_shape(work_shape)
    # n·dk = 2π/dx is the sampling frequency fed to {r,}fftfreq — identical for
    # the unpadded and the doubled (padded) grid, so this works for both.
    kx = collect(Float64, rfftfreq(work_shape[1], 2π / dx[1]))
    ky = collect(Float64, fftfreq(work_shape[2], 2π / dx[2]))
    kz = collect(Float64, fftfreq(work_shape[3], 2π / dx[3]))

    Q_xx = zeros(Float64, rk_shape)
    Q_xy = zeros(Float64, rk_shape)
    Q_xz = zeros(Float64, rk_shape)
    Q_yy = zeros(Float64, rk_shape)
    Q_yz = zeros(Float64, rk_shape)
    Q_zz = zeros(Float64, rk_shape)

    k_sq = zeros(Float64, rk_shape)
    @inbounds for I in CartesianIndices(rk_shape)
        k_sq[I] = kx[I[1]]^2 + ky[I[2]]^2 + kz[I[3]]^2
    end

    _build_q_tensor!(
        Q_xx, Q_xy, Q_xz, Q_yy, Q_yz, Q_zz,
        kx, ky, kz, k_sq, rk_shape; secular=false, full_n=work_shape,
    )
    (Q_xx, Q_xy, Q_xz, Q_yy, Q_yz, Q_zz)
end

"""
    dipole_magnetic_field(grid, Mx, My, Mz; mu0=Units.MU_0, padded=true)

Magnetic field `B(r)` [tesla] produced by a magnetisation density
`M(r) = (Mx, My, Mz)` [A/m] sampled on `grid`, via the magnetic dipole–dipole
kernel with the contact (δ-function) term excluded:

    B_α(r) = -μ₀ · ℱ⁻¹{ Σ_β Q_αβ(k) M̃_β(k) },   Q_αβ = k̂_α k̂_β − δ_αβ/3.

Returns `(Bx, By, Bz)` as real arrays the size of `grid`.

`padded=true` zero-pads to a doubled grid → linear (open-boundary) convolution,
matching `convn(..., 'same')`; `padded=false` is the cheaper periodic form,
acceptable when the cloud sits well inside the box. The long-range 1/r³ tail
makes the padded form the safer default for a radiated field.
"""
function dipole_magnetic_field(
    grid::Grid{3},
    Mx::AbstractArray,
    My::AbstractArray,
    Mz::AbstractArray;
    mu0::Float64=Units.MU_0,
    padded::Bool=true,
)
    n_pts = grid.config.n_points
    for (name, M) in (("Mx", Mx), ("My", My), ("Mz", Mz))
        size(M) == n_pts ||
            throw(ArgumentError("$name size $(size(M)) ≠ grid points $(n_pts)"))
    end

    work_shape = padded ? ntuple(d -> 2 * n_pts[d], 3) : n_pts
    Q_xx, Q_xy, Q_xz, Q_yy, Q_yz, Q_zz = _dipole_q_tensor(grid, work_shape)
    plans = make_rfft_plans(work_shape, CPUBackend(); flags=FFTW.MEASURE, dtype=Float64)
    rk_shape = plans.rk_shape
    corner = CartesianIndices(n_pts)

    Mx_r = zeros(Float64, work_shape)
    My_r = zeros(Float64, work_shape)
    Mz_r = zeros(Float64, work_shape)
    @views Mx_r[corner] .= Mx
    @views My_r[corner] .= My
    @views Mz_r[corner] .= Mz

    Mx_rk = zeros(ComplexF64, rk_shape)
    My_rk = zeros(ComplexF64, rk_shape)
    Mz_rk = zeros(ComplexF64, rk_shape)
    mul!(Mx_rk, plans.forward, Mx_r)
    mul!(My_rk, plans.forward, My_r)
    mul!(Mz_rk, plans.forward, Mz_r)

    Bx_rk = zeros(ComplexF64, rk_shape)
    By_rk = zeros(ComplexF64, rk_shape)
    Bz_rk = zeros(ComplexF64, rk_shape)
    # C = -μ₀ folds the leading sign of B_α = -μ₀ ℱ⁻¹{Σ Q M̃} into the contraction.
    _ddi_k_contraction_core!(
        Bx_rk, By_rk, Bz_rk, Mx_rk, My_rk, Mz_rk,
        Q_xx, Q_xy, Q_xz, Q_yy, Q_yz, Q_zz,
        -mu0, rk_shape, true,
    )

    Bx_r = zeros(Float64, work_shape)
    By_r = zeros(Float64, work_shape)
    Bz_r = zeros(Float64, work_shape)
    mul!(Bx_r, plans.inverse, Bx_rk)
    mul!(By_r, plans.inverse, By_rk)
    mul!(Bz_r, plans.inverse, Bz_rk)

    (Float64.(Bx_r[corner]), Float64.(By_r[corner]), Float64.(Bz_r[corner]))
end

"""
    magnetic_field_from_density(grid, density; atom, a_ho, n_atoms=1.0,
                                polarization=(0,0,1), padded=true)

Field of a fully spin-polarised cloud. `density` is the dimensionless density
on the internal grid (∫ density dV = 1, i.e. `total_density(psi, 3)` of a
normalised state); `a_ho` [m] is the harmonic-oscillator length the grid is
expressed in, and `n_atoms` the total atom number. Each atom carries the
saturation moment `atom.mu_mag` (= g_F·F·μ_B) along the unit vector
`polarization`. Returns `(Bx, By, Bz)` in tesla.

Physical density `n(r) = density · n_atoms / a_ho³` [m⁻³]; magnetisation
`M = atom.mu_mag · n · p̂` [A/m].
"""
function magnetic_field_from_density(
    grid::Grid{3},
    density::AbstractArray;
    atom::AtomSpecies,
    a_ho::Float64,
    n_atoms::Real=1.0,
    polarization::NTuple{3, <:Real}=(0.0, 0.0, 1.0),
    padded::Bool=true,
)
    pn = sqrt(sum(abs2, polarization))
    p̂ = pn == 0 ? (0.0, 0.0, 1.0) : polarization ./ pn
    Mabs = (atom.mu_mag * n_atoms / a_ho^3) .* density   # |M| if fully polarised [A/m]
    dipole_magnetic_field(grid, Mabs .* p̂[1], Mabs .* p̂[2], Mabs .* p̂[3]; padded)
end

"""
    magnetic_field_from_spinor(psi, grid, sm, atom; a_ho, n_atoms=1.0, padded=true)

General (not necessarily polarised) version: the magnetisation follows the
local spin-density vector `⟨F_α⟩(r)` of `psi`, so a textured spinor radiates
the correct anisotropic field. `M_α = (g_F μ_B) · ⟨F_α⟩ · n_atoms / a_ho³`,
with `g_F μ_B = atom.mu_mag / atom.F`. Reduces to
[`magnetic_field_from_density`](@ref) for a stretched state. Returns
`(Bx, By, Bz)` in tesla.
"""
function magnetic_field_from_spinor(
    psi::AbstractArray{<:Complex},
    grid::Grid{3},
    sm::SpinMatrices{D},
    atom::AtomSpecies;
    a_ho::Float64,
    n_atoms::Real=1.0,
    padded::Bool=true,
) where {D}
    fx, fy, fz = spin_density_vector(psi, sm, 3)
    scale = atom.mu_mag / atom.F * n_atoms / a_ho^3   # (g_F μ_B) · n_atoms / a_ho³
    dipole_magnetic_field(grid, fx .* scale, fy .* scale, fz .* scale; padded)
end
