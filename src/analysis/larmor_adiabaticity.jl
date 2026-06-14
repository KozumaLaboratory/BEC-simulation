# --- Larmor precession + adiabatic-following analysis ---
#
# Once the field in a cloud is non-uniform (the self-field of a magnetised
# condensate plus a ramped external bias), the LOCAL quantisation axis rotates
# in time. The spin follows it adiabatically only while its Larmor precession is
# fast compared to that rotation: ω_Larmor ≫ ω_rot. That criterion is the point.
#
# The self-field itself is NOT computed here — it IS the DDI convolution. Get B
# [tesla] from the existing DDI term (no wrapper needed): build the kernel with
# the coupling set to μ₀, feed the magnetisation M [A/m] into the spin-density
# slot, and negate the potential —
#
#     ddi  = make_ddi_params(grid, atom; c_dd = Units.MU_0)
#     bufs = make_ddi_buffers(grid.config.n_points)
#     copyto!(bufs.Fz_r, M_z); compute_ddi_potential!(ddi, bufs)
#     B_z = -bufs.Phi_z            # B_α = -μ₀ ℱ⁻¹{Σ_β Q_αβ M̃_β}
#
# (FT of the dipole kernel is -4πQ; Q(k=0)=0 drops the contact δ-term. For a
# fully polarised cloud M = atom.mu_mag · n, n = density · n_atoms / a_ho³.)

export larmor_frequency, field_tilt, adiabaticity_trajectory

"""
    larmor_frequency(B, atom) -> ω_L [rad/s]

Larmor precession angular frequency `ω_L = g_F μ_B |B| / ℏ` in field `B`
[tesla]: the Zeeman splitting between adjacent sublevels over ℏ, the rate the
transverse spin precesses — **independent of F**. `g_F μ_B = atom.mu_mag /
atom.F`. `B` is a scalar `|B|`, a `(Bx,By,Bz)` tuple, or an array of magnitudes.
"""
function larmor_frequency(Bmag::Real, atom::AtomSpecies)
    atom.F == 0 && throw(ArgumentError("Larmor frequency undefined for F=0 (no spin)"))
    (atom.mu_mag / atom.F) * Bmag / Units.HBAR   # = g_F μ_B |B| / ℏ
end
larmor_frequency(B::NTuple{3, <:Real}, atom::AtomSpecies) =
    larmor_frequency(sqrt(sum(abs2, B)), atom)
larmor_frequency(Bmag::AbstractArray, atom::AtomSpecies) =
    larmor_frequency.(Bmag, Ref(atom))

"""
    field_tilt(Bx, By, Bz; axis=3) -> angle [rad]

Angle of the field away from `axis` (default ẑ): `acos(B_axis / |B|)`,
elementwise. Zero where `B` aligns with the axis, `π` where anti-aligned.
"""
function field_tilt(Bx, By, Bz; axis::Int=3)
    comp = (Bx, By, Bz)[axis]
    Btot = @. sqrt(Bx^2 + By^2 + Bz^2)
    @. acos(clamp(comp / Btot, -1, 1))
end

"""
    adiabaticity_trajectory(B_self, atom; B_ini, B_fin, T_ramp, n=1000) -> NamedTuple

Track adiabatic following at a fixed point as a z-bias is ramped linearly from
`B_ini` to `B_fin` [tesla] over `T_ramp` [s]. `B_self = (Bx, By, Bz)` [tesla]
is the cloud's self-field there (the transverse part tilts the local axis as
the bias shrinks).

Returns `(times, B_ext, tilt, omega_rot, omega_larmor, ratio)`:
- `tilt(t) = acos(B_z(t)/|B(t)|)` with `B_z = Bz_self + B_ext(t)`,
- `omega_rot = d(tilt)/dt` — how fast the local axis turns,
- `omega_larmor = g_F μ_B |B(t)| / ℏ`,
- `ratio = omega_larmor / omega_rot` — adiabatic while ≫ 1; `min(ratio)` is the
  worst-case point of the ramp (`ratio[1]=Inf`, ω_rot=0 at t=0).
"""
function adiabaticity_trajectory(
    B_self::NTuple{3, <:Real},
    atom::AtomSpecies;
    B_ini::Real,
    B_fin::Real,
    T_ramp::Real,
    n::Int=1000,
)
    n >= 2 || throw(ArgumentError("n must be ≥ 2, got $n"))
    bx, by, bz = B_self
    times = collect(range(0.0, Float64(T_ramp); length=n))
    dt = Float64(T_ramp) / (n - 1)
    # Linear ramp: B_ext(0) = B_ini, B_ext(T_ramp) = B_fin.
    B_ext = @. B_fin + (B_fin - B_ini) / T_ramp * (times - T_ramp)

    Bz_t = bz .+ B_ext
    Btot = @. sqrt(bx^2 + by^2 + Bz_t^2)
    tilt = @. acos(clamp(Bz_t / Btot, -1, 1))

    omega_rot = similar(tilt)
    omega_rot[1] = 0.0
    @inbounds for i in 2:n
        omega_rot[i] = (tilt[i] - tilt[i - 1]) / dt
    end
    omega_larmor = larmor_frequency(Btot, atom)
    ratio = omega_larmor ./ omega_rot   # ratio[1] = Inf (ω_rot=0 at t=0) by design

    (; times, B_ext, tilt, omega_rot, omega_larmor, ratio)
end
