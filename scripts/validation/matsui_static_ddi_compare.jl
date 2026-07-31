#!/usr/bin/env julia
# Static comparison of the dipolar drive against Matsui et al., with no dynamics.
#
#     julia --project=. scripts/validation/matsui_static_ddi_compare.jl
#
# The Fig. 4B residual is not a simple coupling error: our transfer is ~20 %
# larger than theirs while our resonance offset is ~16 % smaller. Both scale with
# c_dd·n, so a coupling or density error moves them the same way. This checks the
# two static inputs that a 5 ms run would otherwise hide — the dimensionless DDI
# coefficient and the ground-state peak density — against their Fortran's own
# expressions, and then converts the resulting effective field to nT so it can be
# put next to the measured dip centres directly.

using SpinorBEC
using Printf

const HBAR = 1.054571817e-34
const MU_B = 9.27400949e-24
const A_B = 5.291772108e-11
const MU_0 = 4π * 1e-7

const N_ATOMS = 50_000
const OMEGA_REF = 691.1504          # 2π · 110 Hz
const KAPPA = 1.181818              # ω_z / ω_x
const A0_EU = 110 * A_B

atom = Eu151
a_ho = sqrt(HBAR / (atom.mass * OMEGA_REF))
aHO = a_ho / sqrt(2)                # theirs: sqrt(hbar / (2 m ω))
gF = atom.g_F
mu = gF * MU_B

println("="^78)
println("units")
println("="^78)
@printf("  a_ho (ours)  = %.6e m\n", a_ho)
@printf("  aHO (theirs) = %.6e m   ratio %.6f\n", aHO, a_ho / aHO)

println()
println("="^78)
println("DDI coefficient — their expression vs ours, reduced to the same units")
println("="^78)
# time.f90:263  cdd = 1.d-7 * (gF*muB/hbar)**2 * 2.d0*mass*Ntot / aHO
cdd_theirs = 1e-7 * (gF * MU_B / HBAR)^2 * 2 * atom.mass * N_ATOMS / aHO
# their kernel is 4π·Q where ours is Q, so the physical object is cdd·4π·Q.
# Converting an energy density from their length unit to ours divides by 2√2
# (the same factor that maps their 8πNa/aHO onto our 4πNa/a_ho).
cdd_theirs_in_our_units = cdd_theirs * 4π / (2 * sqrt(2))
cdd_ours = compute_c_dd_dimless(atom; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

@printf("  theirs, their units      cdd      = %.6f\n", cdd_theirs)
@printf("  theirs × 4π / 2√2        →        = %.6f\n", cdd_theirs_in_our_units)
@printf("  ours, compute_c_dd_dimless        = %.6f\n", cdd_ours)
@printf("  ratio ours/theirs                 = %.6f\n", cdd_ours / cdd_theirs_in_our_units)

println()
println("="^78)
println("Contact coupling, for reference")
println("="^78)
cc0_theirs = 8π * N_ATOMS * A0_EU / aHO
@printf("  theirs 8πN a0/aHO                 = %.4f\n", cc0_theirs)
@printf("  /2√2 → our units                  = %.4f\n", cc0_theirs / (2 * sqrt(2)))
@printf("  ours compute_c_total              = %.4f\n",
    compute_c_total(atom; N_atoms=N_ATOMS, omega_ref=OMEGA_REF))

println()
println("="^78)
println("Peak density and the field it radiates")
println("="^78)
# Thomas-Fermi, our units (kinetic ½, V = ½(x²+y²+κ²z²)), c_total since the
# ground state is polarised and feels only c0 + F²c1.
c_tot = compute_c_total(atom; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
wbar = (1.0 * 1.0 * KAPPA)^(1 / 3)
mu_tf = 0.5 * wbar * (15 * c_tot / (4π))^(2 / 5)
n_peak = mu_tf / c_tot
R_x = sqrt(2 * mu_tf)
@printf("  µ_TF        = %.4f  ħω_ref\n", mu_tf)
# ψ is normalised to 1, so the DIMENSIONLESS n is a probability density: the
# physical density carries the extra factor N.
@printf("  n_peak      = %.6e  a_ho^-3     (= %.4e m^-3, physical)\n",
    n_peak, n_peak * N_ATOMS / a_ho^3)
@printf("  R_TF,x      = %.4f a_ho\n", R_x)
@printf("  healing ξ   = %.4f a_ho   (dx = 0.5 at 32³, 0.25 at 64³)\n",
    1 / sqrt(2 * mu_tf))

# A uniform fully polarised sample has zero net dipolar field (∫Q = 0); what sets
# the EdH resonance shift is the density-weighted diagonal component, which for a
# spheroid is c_dd·n·(a geometry factor of order Q_zz ~ ±1/3).
B_scale_tu = cdd_ours * n_peak
p_per_nT = gF * MU_B * 1e-9 / (HBAR * OMEGA_REF)
@printf("\n  c_dd·n_peak = %.6f  ħω_ref  (the natural scale of the dipolar shift)\n",
    B_scale_tu)
@printf("  p per nT    = %.6f  ħω_ref\n", p_per_nT)
@printf("  ⇒ c_dd·n_peak expressed as a field = %.3f nT\n", B_scale_tu / p_per_nT)
@printf("     measured dip centres:  ours -2.14 nT,  Matsui -2.55 nT\n")

println()
println("="^78)
println("Larmor vs dipolar rate at the HELD field (the secular-regime question)")
println("="^78)
for B_nT in (2.6, 10.0, 1040.0)
    omega_L = abs(gF * MU_B * B_nT * 1e-9 / (HBAR * OMEGA_REF))
    @printf("  B = %8.1f nT   ω_L = %10.4f   ω_L/(c_dd·n_peak) = %8.3f\n",
        B_nT, omega_L, omega_L / B_scale_tu)
end
