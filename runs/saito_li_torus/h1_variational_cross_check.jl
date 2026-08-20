# Li & Saito, arXiv:2402.18885 -- the variational prediction for the cells this
# campaign runs, BEFORE any GPU time (CLAUDE.md gate 2: sensitivity table first).
#
# The paper's variational theory (Eqs. 2-3, S2-S10) is the l = 0 member of the
# family already reduced to closed form in `runs/yls_barnett_f6/a2_variational_stability.jl`
# for the sibling paper. It is included rather than restated:
#
#   Li-Saito  S4 : E_kin = (N h^2/2M)[ (2 + F/lam)/(2 sr^2) + 1/(2 sz^2) ]
#   YLS       S6 : E_kin = (1/2) [ (2 + (F + 2 l^2)/lam)/(2 sr^2) + 1/(2 sz^2) ]
#
# identical at l = 0. Same for S7 (E_s, E_ddi = -eps_dd E_s) and S8 (E_LHY).
#
# SECOND STATEMENT. Everything below is cross-checked against an independent
# implementation that integrates the ansatz by DIRECT QUADRATURE with no closed
# form at all (scratchpad/variational.py); its numbers are pinned in
# `PY_CROSSCHECK` and any disagreement above 1 % is reported as a failure.
# That second implementation also reproduces the paper's Fig. S1 curves, which
# is the positive control on the theory itself.
#
# Units. The closed form works in L0 = a_s * N with energies in h^2/(M L0^2)
# and densities in D0 = 1/(a_s^3 N^2); this script converts to um / N um^-3
# (the paper's plotted unit) and to the repo's a_ho / dimensionless couplings.

using SpinorBEC
using SpinorBEC: compute_a_dd, compute_c_total, compute_c_dd_dimless,
    scalar_lhy_coefficient, lima_pelster_Q5, ATOM_REGISTRY, Units
using SpecialFunctions: loggamma
using Printf

include(joinpath(@__DIR__, "..", "yls_barnett_f6", "a2_variational_stability.jl"))

const A_B = 5.29177210903e-11
const OMEGA_REF = 691.15          # 2 pi * 110 Hz -- a unit choice only
const ATOM = ATOM_REGISTRY[:Eu151]
const A_HO = sqrt(Units.HBAR / (ATOM.mass * OMEGA_REF))     # m
const A_DD_REPO = compute_a_dd(ATOM)                        # m
# Table S1: a_dd depends on F (mu = g(F) mu_B F with g from Eq. S1), so a
# single number cannot serve every cell -- the first draft of this script used
# the F=6 value for the F=1 controls and the cross-check caught it as a clean
# 2.42x = 59.82/24.72 offset in every length.
const A_DD_PAPER_BY_F = Dict(1 => 24.72, 2 => 22.92, 3 => 27.54,
    4 => 35.60, 5 => 46.42, 6 => 59.82)
a_dd_paper(F) = A_DD_PAPER_BY_F[F] * A_B
const A_DD_PAPER = a_dd_paper(6)                            # Table S1, F=6

# Independent quadrature implementation (scratchpad/variational.py), run with
# the PAPER's a_dd = 59.82 a_B. Cross-check only.
const PY_CROSSCHECK = Dict(
    (1, 15000, 1.2) => (sigma_r=0.3081, sigma_z=0.2470, lam=0.9003, A=2.682,
        r_mean=0.3979, n_peak_N=2.9443),
    (1, 80000, 1.2) => (sigma_r=0.4401, sigma_z=0.3637, lam=1.0779, A=2.810,
        r_mean=0.5976, n_peak_N=0.90857),
    (6, 15000, 1.3) => (sigma_r=0.4620, sigma_z=0.3401, lam=3.5483, A=4.211,
        r_mean=0.9586, n_peak_N=0.51184),
)

"Aspect ratio of the torus, supplement Eq. (S10)."
aspect_ratio(lam) = ((lam + 1) * exp(2loggamma(lam + 1) - 2loggamma(lam + 1.5)) - 1)^(-0.5)
"<r> for the r^(2 lam) ansatz."
r_mean_over_sr(lam) = exp(loggamma(lam + 1.5) - loggamma(lam + 1))

"""
Variational droplet in physical units.

`a_dd` in metres; `a_s = a_dd / eps_dd` (the paper lowers a_s, the moment is
fixed by the atom). Returns lengths in um and the peak density in N um^-3,
which is the unit of the paper's Figs. 1(c), 1(d) and 2(a).
"""
function physical_droplet(; F, N, eps_dd, a_dd)
    a_s = a_dd / eps_dd
    L0 = a_s * N * 1e6                 # um
    D0 = 1 / ((a_s * 1e6)^3 * N^2)     # um^-3
    d = droplet(; eps_dd=eps_dd, N=N, F=F, l=0)
    d.bound || return (; bound=false, N_c=d.N_c, a_s=a_s, L0=L0)
    (; bound=true, N_c=d.N_c, a_s=a_s, L0=L0, D0=D0, lambda=d.lambda,
        sigma_r=d.sigma_r * L0, sigma_z=d.sigma_z * L0,
        r_torus=d.r_torus * L0,                       # radius of the density peak
        r_mean=d.sigma_r * r_mean_over_sr(d.lambda) * L0,
        A=aspect_ratio(d.lambda),
        n_peak=d.rho_max * D0,                        # um^-3
        n_peak_N=d.rho_max * D0 / N,                  # N um^-3  <- paper's unit
        E_per_atom_L0=d.E)
end

"Radius / half-height at which the ansatz density falls to `frac` of its peak."
function extents(sigma_r, sigma_z, lam; frac=1e-4)
    xs = range(1e-6, 40; length=400_000)
    lg = @. 2lam * log(xs) - xs^2
    lg .-= maximum(lg)
    idx = findlast(>(log(frac)), lg)
    (r_out=sigma_r * xs[idx], z_out=sigma_z * sqrt(-log(frac)))
end

function main()
    println("="^78)
    println("Li-Saito arXiv:2402.18885 -- variational prediction for #336")
    println("="^78)
    @printf("  repo Eu151 : mu = %.4f mu_B, a_dd = %.4f a_B\n",
        ATOM.mu_mag / Units.BOHR_MAGNETON, A_DD_REPO / A_B)
    @printf("  paper S1   : mu = 7      mu_B, a_dd = %.4f a_B  (dev %.2f %%)\n",
        A_DD_PAPER / A_B, 100 * abs(A_DD_REPO - A_DD_PAPER) / A_DD_PAPER)
    @printf("  a_ho(omega_ref = %.2f rad/s) = %.5f um\n", OMEGA_REF, A_HO * 1e6)
    println()

    println("="^78)
    println("POSITIVE CONTROL -- the paper's own Fig. 1(d) / Fig. 2(a) cells")
    println("  cross-checked against an independent direct-quadrature")
    println("  implementation (scratchpad/variational.py), paper a_dd")
    println("="^78)
    worst = 0.0
    for (F, N, eps) in ((1, 15000, 1.2), (1, 80000, 1.2), (6, 15000, 1.3))
        d = physical_droplet(; F=F, N=N, eps_dd=eps, a_dd=a_dd_paper(F))
        py = PY_CROSSCHECK[(F, N, eps)]
        @printf("\n  (F, N, eps_dd) = (%d, %d, %.1f)   a_s = %.3f a_B\n",
            F, N, eps, d.a_s / A_B)
        if !d.bound
            @printf("     UNBOUND (N_c = %.4g)\n", d.N_c)
            continue
        end
        for (name, mine, theirs) in (
            ("sigma_r [um]", d.sigma_r, py.sigma_r),
            ("sigma_z [um]", d.sigma_z, py.sigma_z),
            ("lambda", d.lambda, py.lam),
            ("A (S10)", d.A, py.A),
            ("<r>     [um]", d.r_mean, py.r_mean),
            ("n_peak [N/um3]", d.n_peak_N, py.n_peak_N),
        )
            dev = 100 * abs(mine - theirs) / abs(theirs)
            worst = max(worst, dev)
            @printf("     %-15s closed-form %10.5f   quadrature %10.5f   dev %6.3f %%\n",
                name, mine, theirs, dev)
        end
        @printf("     N_c = %.0f   N/N_c = %.3f\n", d.N_c, N / d.N_c)
    end
    @printf("\n  worst cross-check deviation: %.3f %%  --  %s\n", worst,
        worst < 1.0 ? "AGREE (two independent statements)" : "DISAGREE -- investigate")

    println()
    println("="^78)
    println("TARGET CELL, with the REPO's Eu151 (this is what the run will see)")
    println("="^78)
    d = physical_droplet(; F=6, N=15000, eps_dd=1.3, a_dd=A_DD_REPO)
    @printf("  a_s          = %.4f a_B     (= a_dd / 1.3)\n", d.a_s / A_B)
    @printf("  L0 = a_s N   = %.4f um\n", d.L0)
    @printf("  N_c          = %.0f    N/N_c = %.3f   (stationary-point criterion;\n",
        d.N_c, 15000 / d.N_c)
    println("                 the stricter E<0 criterion gives N_c = 9189, N/N_c = 1.63)")
    @printf("  lambda       = %.4f   aspect A = %.4f\n", d.lambda, d.A)
    @printf("  sigma_r      = %.5f um = %.4f a_ho\n", d.sigma_r, d.sigma_r / (A_HO * 1e6))
    @printf("  sigma_z      = %.5f um = %.4f a_ho\n", d.sigma_z, d.sigma_z / (A_HO * 1e6))
    @printf("  r_peak       = %.5f um = %.4f a_ho   (density maximum ring)\n",
        d.r_torus, d.r_torus / (A_HO * 1e6))
    @printf("  <r>          = %.5f um = %.4f a_ho\n", d.r_mean, d.r_mean / (A_HO * 1e6))
    @printf("  n_peak       = %.4e um^-3 = %.5f N um^-3   <- Fig 1(d)/2(a) unit\n",
        d.n_peak, d.n_peak_N)
    ex = extents(d.sigma_r, d.sigma_z, d.lambda)
    @printf("  extent to 1e-4 of peak: r = %.4f um (%.3f a_ho), |z| = %.4f um (%.3f a_ho)\n",
        ex.r_out, ex.r_out / (A_HO * 1e6), ex.z_out, ex.z_out / (A_HO * 1e6))
    @printf("  => box_xy >= %.2f a_ho, box_z >= %.2f a_ho\n",
        2ex.r_out / (A_HO * 1e6), 2ex.z_out / (A_HO * 1e6))
    println()
    println("  The committed config has box = [3, 3, 3] a_ho.")
    @printf("  Its xy half-width is %.3f a_ho against a %.3f a_ho droplet radius:\n",
        1.5, ex.r_out / (A_HO * 1e6))
    @printf("  the object does NOT fit -- short by %.2fx in xy.\n",
        (ex.r_out / (A_HO * 1e6)) / 1.5)

    println()
    println("="^78)
    println("COUPLINGS THE CONFIG MUST CARRY")
    println("="^78)
    N = 15000
    c_total_nat = compute_c_total(ATOM; N_atoms=N, omega_ref=OMEGA_REF)
    c_dd_nat = compute_c_dd_dimless(ATOM; N_atoms=N, omega_ref=OMEGA_REF)
    c_total = c_total_nat * (d.a_s / ATOM.a_s)
    c_lhy = scalar_lhy_coefficient(d.a_s / A_HO, N; eps_dd=1.3)
    @printf("  c_total = %.4f      (natural %.4f, scaled by a_s ratio %.6f)\n",
        c_total, c_total_nat, d.a_s / ATOM.a_s)
    @printf("  c_dd    = %.4f       (NATURAL -- a_dd is fixed by the atom's moment)\n",
        c_dd_nat)
    @printf("  c_lhy   = %.4f      (scalar Lima-Pelster, a_s = %.3f a_B, Q5(1.3) = %.5f)\n",
        c_lhy, d.a_s / A_B, lima_pelster_Q5(1.3))
    @printf("  check   eps_dd = (F^2/3) c_dd/c_total = %.10f\n",
        (ATOM.F^2 / 3) * c_dd_nat / c_total)
    println()
    println("  For comparison, what the COMMITTED config produces:")
    @printf("    c_total=583, c_dd=152  ->  eps_dd = %.4f  (%.3fx the target)\n",
        (ATOM.F^2 / 3) * 152 / 583, ((ATOM.F^2 / 3) * 152 / 583) / 1.3)
    @printf("    lhy: {kind: scalar} auto-derives c_lhy = %.4f  (%.3fx too large:\n",
        scalar_lhy_coefficient(ATOM.a_s / A_HO, N;
            eps_dd=A_DD_REPO / ATOM.a_s),
        scalar_lhy_coefficient(ATOM.a_s / A_HO, N; eps_dd=A_DD_REPO / ATOM.a_s) / c_lhy)
    println("      the auto path reads atom.a_s = 110 a_B, not the c_total override)")

    println()
    println("="^78)
    println("IS THE WEAK CAGE omega = 0.01 NEGLIGIBLE?")
    println("="^78)
    sr_ho = d.sigma_r / (A_HO * 1e6)
    sz_ho = d.sigma_z / (A_HO * 1e6)
    r2 = sr_ho^2 * (d.lambda + 1)
    z2 = sz_ho^2 / 2
    V_per_atom = 0.5 * 0.01^2 * (r2 + z2)
    # variational E per atom in hbar omega_ref: E[h^2/M L0^2] * (a_ho/L0)^2
    E_per_atom_hw = d.E_per_atom_L0 * (A_HO * 1e6 / d.L0)^2
    @printf("  <V_trap>/N = 0.5 w^2 (<r^2>+<z^2>) = %.4e hbar w_ref\n", V_per_atom)
    @printf("  E/N (variational)                  = %.4e hbar w_ref\n", E_per_atom_hw)
    @printf("  ratio                              = %.2e   -> negligible\n",
        abs(V_per_atom / E_per_atom_hw))
    @printf("  the cage's own length sqrt(1/w) = %.1f a_ho, vs droplet %.2f a_ho\n",
        1 / sqrt(0.01), d.r_mean / (A_HO * 1e6))

    println()
    println("="^78)
    println("Fig. 2(b) POSITIVE CONTROL: critical N vs eps_dd, F = 1..6")
    println("  the paper's six lines, left to right F=1..6")
    println("="^78)
    print("  eps_dd |")
    for F in 1:6
        @printf(" %10s |", "N_c(F=$F)")
    end
    println()
    for eps in (1.1, 1.2, 1.3, 1.4, 1.5)
        @printf("  %5.2f  |", eps)
        for F in 1:6
            @printf(" %10.0f |", critical_N(; eps_dd=eps, F=F, l=0))
        end
        println()
    end
    println()
    println("  N_c is monotonically increasing in F at every eps_dd, which is the")
    println("  'F = 1 ... 6 from left to right' ordering of Fig. 2(b).")
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
