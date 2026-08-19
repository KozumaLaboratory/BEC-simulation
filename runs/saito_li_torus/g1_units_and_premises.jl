# Gate 1 for issue #336 — Saito & Li, arXiv:2402.18885.
#
# Every number the config asserts, recomputed from the repo's own constants and
# checked against the paper. Nothing here launches a simulation; it is the
# cheap check that must pass before GPU time is spent.
#
# The paper reaches eps_dd by LOWERING a_s at fixed physical moment (mu is a
# property of the atom, not a knob), so exactly ONE contact knob moves.

using SpinorBEC
using Printf

const A0 = 5.29177210903e-11        # Bohr radius, m
const UM = 1e-6

atom = SpinorBEC.ATOM_REGISTRY[:Eu151]
N = 15000
omega_ref = 691.15
a_ho = sqrt(SpinorBEC.Units.HBAR / (atom.mass * omega_ref))
F = atom.F

println("="^72)
println("Gate 1 — units and premises  (Saito & Li, arXiv:2402.18885)")
println("="^72)
@printf("atom            : %s   F = %d\n", atom.name, F)
@printf("mu_mag          : %.4f mu_B\n", atom.mu_mag / SpinorBEC.Units.BOHR_MAGNETON)
@printf("a_s (registry)  : %.2f a_0\n", atom.a_s / A0)
@printf("omega_ref       : %.2f rad/s  = 2pi x %.1f Hz\n", omega_ref, omega_ref / 2pi)
@printf("a_ho            : %.5f um\n", a_ho / UM)

a_dd = SpinorBEC.compute_a_dd(atom)
@printf("a_dd            : %.3f a_0   (mu0 mu^2 M / 12 pi hbar^2)\n", a_dd / A0)

c_total_nat = SpinorBEC.compute_c_total(atom; N_atoms=N, omega_ref=omega_ref)
c_dd_nat = SpinorBEC.compute_c_dd_dimless(atom; N_atoms=N, omega_ref=omega_ref)
eps_nat_atom = a_dd / atom.a_s

println()
println("-- natural (registry a_s) --")
@printf("c_total         : %.2f\n", c_total_nat)
@printf("c_dd            : %.2f\n", c_dd_nat)
@printf("eps_dd (a_dd/a_s)          : %.4f\n", eps_nat_atom)
@printf("eps_dd (c_dd F^2/(3 c_tot)): %.4f   <- dimensionless form\n",
    c_dd_nat * F^2 / (3 * c_total_nat))

# ---------------------------------------------------------------- config as committed
c_total_cfg = 583.0
c_dd_cfg = 152.0
println()
println("-- config as committed (c_total: 583, c_dd: 152) --")
@printf("eps_dd          : %.4f   <-- TARGET IS 1.3\n", c_dd_cfg * F^2 / (3 * c_total_cfg))
@printf("  ratio to target: %.3f x\n", (c_dd_cfg * F^2 / (3 * c_total_cfg)) / 1.3)

# ---------------------------------------------------------------- corrected
eps_target = 1.3
c_total_fix = c_dd_nat * F^2 / (3 * eps_target)
a_s_target = c_total_fix * a_ho / (4pi * N)
println()
println("-- corrected: keep c_dd natural, lower a_s only (the paper's route) --")
@printf("c_dd            : %.2f  (natural, NOT overridden)\n", c_dd_nat)
@printf("c_total         : %.2f\n", c_total_fix)
@printf("implied a_s     : %.2f a_0   (vs registry %.1f a_0)\n",
    a_s_target / A0, atom.a_s / A0)
@printf("eps_dd check    : %.4f\n", c_dd_nat * F^2 / (3 * c_total_fix))

# ---------------------------------------------------------------- LHY
Q5_nat = SpinorBEC.lima_pelster_Q5(eps_nat_atom)
Q5_tgt = SpinorBEC.lima_pelster_Q5(eps_target)
c_lhy_auto = SpinorBEC.scalar_lhy_coefficient(atom.a_s / a_ho, N; eps_dd=eps_nat_atom)
c_lhy_fix = SpinorBEC.scalar_lhy_coefficient(a_s_target / a_ho, N; eps_dd=eps_target)
println()
println("-- scalar LHY (Lima-Pelster Q5), paper Eq. 1 --")
@printf("Q5(%.4f) = %.4f     Q5(%.2f) = %.4f\n", eps_nat_atom, Q5_nat, eps_target, Q5_tgt)
@printf("c_lhy auto-derived by schema : %.4e   <- uses registry a_s AND eps_dd=%.2f\n",
    c_lhy_auto, eps_nat_atom)
@printf("c_lhy correct for this run   : %.4e\n", c_lhy_fix)
@printf("  auto / correct             : %.2f x\n", c_lhy_auto / c_lhy_fix)

# ---------------------------------------------------------------- paper anchors -> internal units
println()
println("-- Fig 2(a) anchors, F=6 N=15000 eps_dd=1.3, into internal units --")
rho_peak_paper = 0.50            # N um^-3, read off Fig 2(a) cyan curve
r_peak_paper = 0.85              # um
r_outer_paper = 1.45             # um, where the curve returns to ~0
n_peak_int = rho_peak_paper * (a_ho / UM)^3
@printf("peak rho/N      : %.2f um^-3  ->  n = %.4f  (internal, int|psi|^2 dV = 1)\n",
    rho_peak_paper, n_peak_int)
@printf("torus radius    : %.2f um     ->  %.3f a_ho\n", r_peak_paper, r_peak_paper * UM / a_ho)
@printf("cloud edge      : %.2f um     ->  %.3f a_ho\n", r_outer_paper, r_outer_paper * UM / a_ho)

println()
println("-- box adequacy --")
for box in (3.0, 5.0, 6.0, 8.0)
    half = box / 2 * a_ho / UM
    @printf("box %.1f a_ho: full %.2f um, half-width %.2f um  %s   dx(64)=%.4f um dx(128)=%.4f um\n",
        box, box * a_ho / UM, half,
        half > r_outer_paper ? "OK " : "CLIPS",
        box * a_ho / UM / 64, box * a_ho / UM / 128)
end

println()
println("-- trap: is omega=0.01 negligible? --")
for om in (0.01, 0.0)
    E_trap = 0.5 * om^2 * (r_outer_paper * UM / a_ho)^2
    @printf("omega=%.3f: (1/2)w^2 r_edge^2 = %.3e hbar w_ref  (= %.4f Hz trap)\n",
        om, E_trap, om * omega_ref / 2pi)
end
println("compare against |E_total|/N from the run; must be far below it.")
