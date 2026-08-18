# Gate 1, part 2: the paper's unit system, rebuilt from the repo's own constants.
#
# Yan-Li-Saito 2026 (arXiv:2605.11670) normalizes by
#   L0 = a_s N,  T0 = M a_s^2 N^2 / hbar,  D0 = 1/(a_s^3 N^2),
#   B0 = hbar^2 / (M a_s^2 N^2 g mu_B).
# Every one of those is checked here against the values the paper quotes for
# 151Eu, because a reproduction that gets the unit system wrong prints clean
# numbers forever.
#
# The mapping used by the whole campaign: choose the internal reference
# frequency so that a_ho == L0. Then the repo's dimensionless eGPE IS the
# paper's Eq. (S3) --- same -1/2 grad^2, same norm 1, same 4pi contact
# coefficient --- and the dictionary is the identity:
#   length  [a_ho]      == [L0]
#   time    [1/omega]   == [T0]
#   density |psi|^2     == n / D0
#   p_z     [hbar*omega]== B_tilde
# so `max |psi|^2` is directly comparable to the paper's 13000 D0.

using SpinorBEC
using Printf

const a0 = SpinorBEC.Units.BOHR_RADIUS
const hbar = SpinorBEC.Units.HBAR
const muB = SpinorBEC.Units.BOHR_MAGNETON

"Paper unit system for a given atom-like parameter set."
function paper_units(; mass, mu_total, a_s, N)
    L0 = a_s * N
    T0 = mass * L0^2 / hbar
    D0 = 1.0 / (a_s^3 * N^2)
    omega_ref = hbar / (mass * L0^2)          # == 1/T0, and makes a_ho == L0
    a_ho = sqrt(hbar / (mass * omega_ref))
    # B0 straight from the paper's definition, with g*mu_B the moment per unit
    # spin. `mu_total = g*mu_B*F`, so g*mu_B = mu_total/F is supplied by caller.
    (; L0, T0, D0, omega_ref, a_ho)
end

"eps_dd = a_dd/a_s with a_dd built from the TOTAL moment (see note below)."
a_dd_of(mass, mu_total) = SpinorBEC.Units.MU_0 * mu_total^2 * mass / (12π * hbar^2)

function report(label, atom; N::Int, eps_dd_target=nothing)
    F = atom.F
    mass = atom.mass
    mu_total = atom.mu_mag
    a_dd = a_dd_of(mass, mu_total)
    # a_s: either the atom's own (physical cell) or the one that hits a target
    # eps_dd (paper cell).
    a_s = eps_dd_target === nothing ? atom.a_s : a_dd / eps_dd_target
    eps_dd = a_dd / a_s
    u = paper_units(; mass, mu_total, a_s, N)
    g_muB = mu_total / F                       # moment per unit spin
    B0_selfconsistent = hbar^2 / (mass * a_s^2 * N^2 * g_muB)
    B0_no_g = hbar^2 / (mass * a_s^2 * N^2 * muB)

    println("="^72)
    println(label)
    println("="^72)
    @printf("  F                    = %d   (D = %d components)\n", F, 2F + 1)
    @printf("  mu_total             = %.4f mu_B      (g_F = %.4f)\n", mu_total / muB, g_muB / muB)
    @printf("  a_dd (total moment)  = %.3f a0\n", a_dd / a0)
    @printf("  a_s                  = %.3f a0%s\n", a_s / a0,
        eps_dd_target === nothing ? "  (registry / measured)" : "  (set to hit eps_dd target)")
    @printf("  eps_dd = a_dd/a_s    = %.4f\n", eps_dd)
    println()
    @printf("  L0 = a_s N           = %.3f um\n", u.L0 * 1e6)
    @printf("  T0 = M L0^2/hbar     = %.4f s\n", u.T0)
    @printf("  D0 = 1/(a_s^3 N^2)   = %.4f um^-3\n", u.D0 * 1e-18)
    @printf("  omega_ref (a_ho=L0)  = %.5f rad/s  (= %.5f Hz)\n",
        u.omega_ref, u.omega_ref / 2π)
    @printf("  B0 (paper's formula, g*mu_B) = %.5f uG = %.4f nT\n",
        B0_selfconsistent * 1e10, B0_selfconsistent * 1e9)
    @printf("  B0 (same but with mu_B only) = %.5f uG = %.4f nT\n",
        B0_no_g * 1e10, B0_no_g * 1e9)
    (; F, mass, mu_total, a_s, a_dd, eps_dd, u..., B0=B0_selfconsistent, B0_no_g)
end

println()
println("Gate 1 / part 2 --- paper unit system rebuilt from repo constants")
println("paper anchors for 151Eu F=1, eps_dd=1.2, N=15000:")
println("  L0 = 16.35 um   T0 = 0.64 s   D0 = 3.43 um^-3   B0 = 0.2 uG")
println()

N = 15000
f1 = report("CELL P (positive control): Eu151_f1_effective at the paper's eps_dd",
    SpinorBEC.Eu151_f1_effective; N=N, eps_dd_target=1.2)
f6phys = report("CELL A (physical Eu): Eu151, registry a_s = 110 a0",
    SpinorBEC.Eu151; N=N)
f6paper = report("CELL B (F=6 at the paper's eps_dd): Eu151 with a_s tuned to eps_dd=1.2",
    SpinorBEC.Eu151; N=N, eps_dd_target=1.2)

println("="^72)
println("PAPER-ANCHOR CHECK (cell P against the four quoted numbers)")
println("="^72)
for (name, got, want, unit) in (
    ("L0", f1.L0 * 1e6, 16.35, "um"),
    ("T0", f1.T0, 0.64, "s"),
    ("D0", f1.D0 * 1e-18, 3.43, "um^-3"),
    ("B0", f1.B0 * 1e10, 0.2, "uG"),
)
    rel = abs(got - want) / want
    @printf("  %-3s  ours = %10.4f %-6s  paper = %7.3f  rel dev = %6.2f %%  %s\n",
        name, got, unit, want, 100rel, rel < 0.02 ? "OK" : "<-- MISMATCH")
end
@printf("\n  B0 ratio paper/ours = %.3f   (g_F of the F=1 effective atom = %.3f)\n",
    0.2 / (f1.B0 * 1e10), f1.mu_total / muB / f1.F)

println()
println("="^72)
println("SYSTEMATICS BEFORE RESIDUALS --- the Fig. 2(c) field axis in lab units")
println("="^72)
println("Fig. 2(c) scans B_y from 0 to 1000 (in B0 units).")
for (tag, B0v) in (("B0 self-consistent (g*mu_B)", f1.B0), ("B0 as quoted, 0.2 uG", 0.2e-10))
    @printf("  %-28s : B_y = 1000 B0 = %8.3f nT\n", tag, 1000 * B0v * 1e9)
end
println()
println("  Published field-offset systematic on the Eu apparatus: +/- 10 nT")
println("  (Matsui et al. 2026; the number that killed six GPU arms on 2026-08-04).")
for (tag, B0v) in (("self-consistent", f1.B0), ("as quoted", 0.2e-10))
    Bmax = 1000 * B0v
    @printf("  -> full scan range / systematic = %.2f  (%s)\n", Bmax * 1e9 / 10.0, tag)
end
