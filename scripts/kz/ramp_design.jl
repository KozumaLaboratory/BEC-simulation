# Sizing the CORRECTED ramp. T_c = 49.0 at mu = 15 (self-consistent HF, classical
# field, tracking cutoff), so a ramp must start above it -- the old one ran
# 30 -> 2, entirely inside the condensed phase.
using SpinorBEC, Printf
const mu = 15.0
@printf("%-7s %-9s %-11s %-11s %-11s %-8s\n",
    "T", "eps_cut", "gamma", "1/(2g*mu)", "Mbar", "k_cut")
for T in (100.0, 80.0, 60.0, 49.0, 40.0, 30.0, 20.0, 10.0, 5.0, 2.0)
    ec = mu + T
    g = spgpe_growth_rate(; T, mu, eps_cut=ec, a_s=0.01)
    M = spgpe_scattering_rate(; T, mu, eps_cut=ec, a_s=0.01)
    @printf("%-7.1f %-9.1f %-11.4g %-11.4g %-11.4g %-8.2f\n",
        T, ec, g, 1 / (2g * mu), M, sqrt(2ec))
end
# Grid: dx <= 0.8 xi AND the grid must resolve the LARGEST k_cut, at T_hot.
for (Th, box, n) in ((80.0, 20.1, 138), (80.0, 20.1, 200), (60.0, 20.1, 138))
    kc = sqrt(2 * (mu + Th));
    dx = box / n
    @printf("\nT_hot=%.0f box=%.1f n=%d: k_cut=%.2f  k_max=%.2f  dx/xi=%.2f  %s\n",
        Th, box, n, kc, π / dx, dx / (1 / sqrt(2mu)),
        π / dx > kc ? "resolved" : "NOT RESOLVED")
end
