# Li-Saito (arXiv:2402.18885) torus droplet -- unit / coupling audit.
#
# Answers the three arithmetic questions gate 1 raises about
# `runs/saito_li_torus/config.yaml`:
#   1. what eps_dd does the pair (c_total, c_dd) actually realise?
#   2. what does the LHY auto-derivation use for a_s and eps_dd when
#      c_total is overridden?
#   3. does the repo's lima_pelster_Q5 agree with the paper's chi(eps_dd)?
#
# Pure arithmetic on the coefficient layer -- no grid, no solver.

using SpinorBEC
using SpinorBEC: compute_c_total, compute_c_dd_dimless, compute_a_dd,
    scalar_lhy_coefficient, lima_pelster_Q5, ATOM_REGISTRY, Units

const N_ATOMS = 15000
const OMEGA_REF = 691.15
const EPS_DD_TARGET = 1.3

atom = ATOM_REGISTRY[:Eu151]
a_ho = sqrt(Units.HBAR / (atom.mass * OMEGA_REF))
a_B = 5.29177210903e-11

println("="^74)
println("ATOM  Eu151")
println("="^74)
println("  F         = ", atom.F)
println("  mass      = ", atom.mass, " kg")
println("  mu_mag    = ", atom.mu_mag / Units.BOHR_MAGNETON, " mu_B   (paper Table S1: 7)")
println("  a_s       = ", atom.a_s / a_B, " a_B")
a_dd = compute_a_dd(atom)
println("  a_dd      = ", a_dd / a_B, " a_B   (paper Table S1: 59.82)")
eps_nat = a_dd / atom.a_s
println("  eps_dd    = ", eps_nat, "   (natural)")
println("  a_ho      = ", a_ho * 1e6, " um  at omega_ref = ", OMEGA_REF)
println()

c_total_nat = compute_c_total(atom; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
c_dd_nat = compute_c_dd_dimless(atom; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
println("="^74)
println("NATURAL dimensionless couplings at N=$N_ATOMS, omega_ref=$OMEGA_REF")
println("="^74)
println("  c_total (natural) = ", c_total_nat)
println("  c_dd    (natural) = ", c_dd_nat)
println("  c_dd / c_total    = ", c_dd_nat / c_total_nat)
println("  3*eps_dd/F^2      = ", 3 * eps_nat / atom.F^2,
    "   <- analytic prediction of that ratio")
println()
println("  => eps_dd = (F^2/3) * c_dd/c_total = ",
    (atom.F^2 / 3) * c_dd_nat / c_total_nat)
println()

println("="^74)
println("WHAT THE COMMITTED CONFIG ACTUALLY SETS  (c_total=583, c_dd=152)")
println("="^74)
cfg_c_total, cfg_c_dd = 583.0, 152.0
eps_cfg = (atom.F^2 / 3) * cfg_c_dd / cfg_c_total
println("  c_dd/c_total   = ", cfg_c_dd / cfg_c_total)
println("  eps_dd_eff     = ", eps_cfg, "   (target was ", EPS_DD_TARGET, ")")
println("  overshoot      = ", eps_cfg / EPS_DD_TARGET, "x")
println()

println("="^74)
println("CORRECT COUPLINGS FOR eps_dd = $EPS_DD_TARGET")
println("="^74)
println("  The paper holds a_dd fixed (set by the atom's moment) and lowers")
println("  a_s. So c_dd stays NATURAL and only c_total moves.")
a_s_target = a_dd / EPS_DD_TARGET
c_total_target = c_total_nat * (a_s_target / atom.a_s)
println("  a_s target     = ", a_s_target / a_B, " a_B  (paper: 59.82/1.3 = ",
    59.82 / 1.3, ")")
println("  c_total target = ", c_total_target)
println("  c_dd    target = ", c_dd_nat, "  (unchanged, natural)")
println("  check eps_dd   = ", (atom.F^2 / 3) * c_dd_nat / c_total_target)
println()

println("="^74)
println("LHY: what `lhy: {kind: scalar}` AUTO-DERIVES vs what it should be")
println("="^74)
println("  parsing_blocks.jl:291 sets eps_dd = compute_a_dd(atom)/atom.a_s,")
println("  and :359 calls scalar_lhy_coefficient(atom.a_s/a_ho, N).")
println("  Both use the ATOM's a_s -- the c_total override is invisible here.")
c_lhy_auto = scalar_lhy_coefficient(atom.a_s / a_ho, N_ATOMS; eps_dd=eps_nat)
c_lhy_right = scalar_lhy_coefficient(a_s_target / a_ho, N_ATOMS;
    eps_dd=EPS_DD_TARGET)
println()
println("  auto-derived c_lhy (a_s=", round(atom.a_s / a_B; digits=2),
    " a_B, eps_dd=", round(eps_nat; digits=4), ") = ", c_lhy_auto)
println("  correct     c_lhy (a_s=", round(a_s_target / a_B; digits=2),
    " a_B, eps_dd=", EPS_DD_TARGET, ")  = ", c_lhy_right)
println("  auto / correct = ", c_lhy_auto / c_lhy_right, "x")
println()
println("  breakdown:")
println("    (a_s_nat/a_s_target)^(5/2) = ",
    (atom.a_s / a_s_target)^2.5)
println("    Q5(", round(eps_nat; digits=4), ") / Q5(", EPS_DD_TARGET, ") = ",
    lima_pelster_Q5(eps_nat) / lima_pelster_Q5(EPS_DD_TARGET))
println()

println("="^74)
println("CROSS-CHECK: repo lima_pelster_Q5 vs the paper's chi(eps_dd)")
println("  paper: chi = Re (1/2) int_0^pi dth sin(th) [1+e(3cos^2 th -1)]^(5/2)")
println("  independently quadratured in scratchpad/variational.py:")
println("    chi(0)=1.0  chi(0.5)=1.3899  chi(1.0)=2.5981")
println("    chi(1.2)=3.3116  chi(1.3)=3.7164  chi(1.4)=4.1536  chi(1.5)=4.6238")
println("="^74)
for e in (0.0, 0.5, 1.0, 1.2, 1.3, 1.4, 1.5)
    println("  Q5($e) = ", lima_pelster_Q5(e))
end
