# What the #361 DDI-block fix moves in quantities NO test pins.
#
# CI answered the gated half: every physics gate passed unchanged. This driver
# answers the rest — the outputs that are consumed but never asserted, so a
# coefficient change moves them while the suite stays green:
#
#   1. `instability_angular_map` — max growth rate and the most unstable
#      direction. `triple_point` (`src/solvers/continuation/triple_point.jl`)
#      depends on the fix ONLY through `bogoliubov_spectrum.max_growth_rate`,
#      so this covers it without paying for its L-BFGS solves.
#   2. the phonon and lowest spin branch at fixed k, along and across z.
#   3. `full_bdg` ε_LHY with the DDI active — the `_lhy_bdg_stiffness` path.
#
# Run the SAME file against two checkouts (pre- and post-fix) and diff:
#
#   julia --project=<worktree> runs/bdg_ddi_verdict_delta/measure_ungated.jl
#
# Production-shaped Eu fixture: N = 5e4, ω_ref = 2π·116 Hz, c1_ratio = 1/36,
# c_dd from the atom, n₀ the Thomas-Fermi peak.

using SpinorBEC
using SpinorBEC: interaction_params_from_constraint, compute_c_total,
                 compute_c_dd_dimless, _lhy_bdg_energy_density
using Printf

const F = 6
const D = 13
const N_ATOMS = 50_000
const OMEGA_REF = 2π * 116.0

c_total = compute_c_total(Eu151; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
c_dd = compute_c_dd_dimless(Eu151; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
mu_tf = 0.5 * (15 * c_total / (4π))^(2 / 5)
n0 = mu_tf / c_total
ip = interaction_params_from_constraint(; c_total=c_total, c1_ratio=1 / 36, F=F)
zee = ZeemanParams(0.0, 0.0)

stretched = zeros(ComplexF64, D);
stretched[1] = 1.0;
polar = zeros(ComplexF64, D);
polar[7] = 1.0;

println("# git: ", strip(read(`git rev-parse HEAD`, String)))
@printf("c_total = %.6f   c_dd = %.6f   n0 = %.8e\n", c_total, c_dd, n0)

for (name, sp) in (("stretched", stretched), ("polar", polar))
    imap = instability_angular_map(; spinor=sp, n0=n0, F=F, interactions=ip,
        zeeman=zee, c_dd=c_dd, k_max=6.0, n_k=40, n_theta=13, n_phi=24)
    g = imap.growth_map
    @printf("%-10s angular_map: max=%.10e  mean=%.10e  argmax=(θ=%.4f, φ=%.4f)\n",
        name, maximum(g), sum(g) / length(g),
        imap.theta[argmax(g)[1]], imap.phi[argmax(g)[2]])

    for (dir, dname) in (((0.0, 0.0, 1.0), "k∥z"), ((1.0, 0.0, 0.0), "k⊥z"))
        res = bogoliubov_spectrum(; spinor=sp, n0=n0, F=F, interactions=ip,
            zeeman=zee, c_dd=c_dd, k_max=2.0, n_k=3, k_direction=dir)
        w = sort(real.(res.omega[:, 2]))
        pos = filter(>(1e-9), w)
        @printf("%-10s %s branches(k=1): %s   max_growth=%.10e\n", name, dname,
            join((@sprintf("%.8f", x) for x in pos[1:min(4, end)]), " "),
            res.max_growth_rate)
    end

    eps_lhy = _lhy_bdg_energy_density(sp, n0, F, ip, zee, c_dd, 200.0, 250, 160)
    @printf("%-10s full_bdg eps_LHY (c_dd on)  = %.10e\n", name, eps_lhy)
    eps_c = _lhy_bdg_energy_density(sp, n0, F, ip, zee, 0.0, 200.0, 250, 1)
    @printf("%-10s full_bdg eps_LHY (c_dd off) = %.10e  [control: must not move]\n",
        name, eps_c)
end
