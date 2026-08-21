# Size the paper's OWN F=1 cells before spending GPU (CLAUDE.md gate 2).
#
# The F=6 field-axis work in this directory is an extrapolation: the paper
# publishes Figs. 3 and 4 at F = 1, ε_dd = 1.2. Running those cells turns the
# extrapolation into a type-C reproduction with numbers to compare against:
#
#   Fig. 3(b,c)  N = 50000 : bistable over B_z ≃ 0.03 … 0.17 mG,
#                            energies cross at B_z ≃ 0.14 mG
#   Fig. 4       N = 15000 : B_z = 0.05 and 0.1 mG switched on at t = 0
#   Fig. 5       N = 4e5, ε_dd = 1.4, trap 2π×(100, 1500, 6000) Hz
#
# The atom is already in the registry: `Eu151_f1_effective` carries the paper's
# own μ = 9/2 μ_B (Table S1, F=1) and a_s = 21 a₀, i.e. ε_dd ≈ 1.2 natural.
# That is checked here rather than assumed.
#
#   julia --project=. runs/saito_li_torus/h8_f1_sizing.jl

using SpinorBEC
using SpinorBEC: compute_a_dd, compute_c_total, compute_c_dd_dimless,
    scalar_lhy_coefficient, effective_eps_dd, ATOM_REGISTRY, Units
using SpecialFunctions: loggamma
using Printf

include(joinpath(@__DIR__, "..", "yls_barnett_f6", "a2_variational_stability.jl"))

const A_B = Units.BOHR_RADIUS
const OMEGA_REF = 691.15                     # same unit choice as the F=6 cells

aspect_ratio(lam) = ((lam + 1) * exp(2loggamma(lam + 1) - 2loggamma(lam + 1.5)) - 1)^(-0.5)
r_mean_over_sr(lam) = exp(loggamma(lam + 1.5) - loggamma(lam + 1))

"Radius / half-height at which the ansatz density falls to `frac` of its peak."
function extents(sr, sz, lam; frac=1e-4)
    xs = range(1e-6, 40; length=200_000)
    lg = @. 2lam * log(xs) - xs^2
    lg .-= maximum(lg)
    idx = findlast(>(log(frac)), lg)
    (r_out=sr * xs[idx], z_out=sz * sqrt(-log(frac)))
end

function cell(atom, N, eps_dd, label)
    a_dd = compute_a_dd(atom)
    a_s = a_dd / eps_dd
    a_ho = sqrt(Units.HBAR / (atom.mass * OMEGA_REF))
    L0 = a_s * N * 1e6
    D0 = 1 / ((a_s * 1e6)^3 * N^2)
    d = droplet(; eps_dd=eps_dd, N=N, F=atom.F, l=0)
    println("-"^74)
    @printf("%s   F=%d  N=%d  eps_dd=%.2f\n", label, atom.F, N, eps_dd)
    @printf("  a_dd = %.3f a_B   a_s = %.3f a_B   a_ho = %.5f um\n",
        a_dd / A_B, a_s / A_B, a_ho * 1e6)
    if !d.bound
        @printf("  UNBOUND (N_c = %.4g)\n", d.N_c)
        return nothing
    end
    sr, sz = d.sigma_r * L0, d.sigma_z * L0        # um
    ex = extents(sr, sz, d.lambda)
    ah = a_ho * 1e6
    ct = compute_c_total(atom; N_atoms=N, omega_ref=OMEGA_REF) * (a_s / atom.a_s)
    cdd = compute_c_dd_dimless(atom; N_atoms=N, omega_ref=OMEGA_REF)
    clhy = scalar_lhy_coefficient(a_s / a_ho, N; eps_dd=eps_dd)
    @printf("  N_c = %.0f   N/N_c = %.2f   lambda = %.3f   A = %.3f\n",
        d.N_c, N / d.N_c, d.lambda, aspect_ratio(d.lambda))
    @printf("  sigma_r = %.4f um = %.3f a_ho    sigma_z = %.4f um = %.3f a_ho\n",
        sr, sr / ah, sz, sz / ah)
    @printf("  <r> = %.4f um = %.3f a_ho    n_peak = %.4f N um^-3\n",
        d.sigma_r * r_mean_over_sr(d.lambda) * L0,
        d.sigma_r * r_mean_over_sr(d.lambda) * L0 / ah, d.rho_max * D0 / N)
    @printf("  box_xy >= %.2f a_ho   box_z >= %.2f a_ho   (1e-4 of peak)\n",
        2ex.r_out / ah, 2ex.z_out / ah)
    @printf("  couplings: c_total = %.4f   c_dd = %.4f   c_lhy = %.4f   eps_dd_chk = %.6f\n",
        ct, cdd, clhy, effective_eps_dd(atom.F, ct, cdd))
    # p per mG, for the field ladders
    p_per_mG = SpinorBEC.Units.bfield_to_p_gauss(1e-3, atom.g_F, OMEGA_REF)
    @printf("  p per mG = %+.5f   (H = -p F_z)\n", p_per_mG)
    (; sr, sz, lam=d.lambda, ah, ct, cdd, clhy, box_xy=2ex.r_out / ah,
        box_z=2ex.z_out / ah, p_per_mG)
end

function main()
    f1 = ATOM_REGISTRY[:Eu151_f1_effective]
    a_dd_f1 = compute_a_dd(f1)
    println("="^74)
    println("Eu151_f1_effective vs the paper's Table S1 (F=1)")
    println("="^74)
    @printf("  mu     = %.4f mu_B   (paper: 9/2 = 4.5)\n",
        f1.mu_mag / Units.BOHR_MAGNETON)
    @printf("  a_dd   = %.4f a_B     (paper: 24.72)   dev %.2f %%\n",
        a_dd_f1 / A_B, 100 * abs(a_dd_f1 / A_B - 24.72) / 24.72)
    @printf("  a_s    = %.4f a_B  ⇒  eps_dd = %.5f  (paper's Figs. 1-4 use 1.2)\n",
        f1.a_s / A_B, a_dd_f1 / f1.a_s)
    println()

    println("="^74)
    println("THE PAPER'S OWN CELLS")
    println("="^74)
    cell(f1, 15000, 1.2, "Fig. 1(a-c) / Fig. 4  (EdH)")
    cell(f1, 50000, 1.2, "Fig. 3(b,c)  (bistability; paper: 0.03-0.17 mG, cross 0.14)")
    cell(f1, 80000, 1.2, "Fig. 1(d) middle panel")
    cell(f1, 400000, 1.4, "Fig. 5  (supersolid, but TRAPPED — free-space size only)")

    println()
    println("="^74)
    println("Fig. 3 field scale, predicted before scanning")
    println("="^74)
    d = droplet(; eps_dd=1.2, N=50000, F=1, l=0)
    a_ho = sqrt(Units.HBAR / (f1.mass * OMEGA_REF))
    L0 = (a_dd_f1 / 1.2) * 50000
    sr_ho = d.sigma_r * L0 / a_ho
    winding = (1 / 2) / (d.lambda * sr_ho^2)      # <S_z^2>/r^2 with <S_z^2> = F/2
    p_per_mG = SpinorBEC.Units.bfield_to_p_gauss(1e-3, f1.g_F, OMEGA_REF)
    @printf("  spin-winding cost (F/2)/(lam sigma_r^2) = %.4f hbar w_ref/atom\n",
        winding)
    @printf("  |p| F per mG = %.4f  ⇒  equality at B = %.4f mG\n",
        abs(p_per_mG) * 1, winding / (abs(p_per_mG) * 1))
    println("  paper's bistable window is 0.03-0.17 mG with the crossing at 0.14 mG,")
    println("  so a ladder over 0.02 … 0.20 mG brackets everything it reports.")
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
