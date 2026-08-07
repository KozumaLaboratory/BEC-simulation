# Is the total-number constraint continuous in mu?
#
# The round-trip returns 2.34 for 2.5, which is 6% off — too large for a bisection
# that ran 200 iterations, so the function it is inverting is not continuous. The
# suspect: N_0(mu) is Thomas-Fermi and smooth, while coherent_population drops every
# level with eps < mu outright, so each time mu crosses a level that level's
# contribution vanishes at once and the total jumps. A bisection cannot cross a jump;
# it stops at the near side, which is what a 6% shortfall looks like.
#
# Print the total on a fine grid through the region and let the jumps be visible
# rather than argued about.
using SpinorBEC, Printf
T, eps_cut, c0, ω = 5.5, 18.0, 0.02, 1.0
ε0 = 1.5ω
tf(mu) = mu > ε0 ? (R = sqrt(2 * (mu - ε0));
                    max((4π / c0) * ((mu - ε0) * R^3 / 3 - R^5 / 10), 0.0)) : 0.0
total(mu) = tf(mu) + coherent_population(mu, T, eps_cut) +
            incoherent_population(mu, T, eps_cut)
@printf("%-9s %-13s %-13s %-13s %-13s %-9s\n",
    "mu", "N_0(TF)", "N_C^th", "N_I", "total", "jump")
prev = NaN
for mu in 1.0:0.125:7.0
    t = total(mu)
    j = isnan(prev) ? 0.0 : (t - prev) / max(abs(prev), 1)
    @printf("%-9.3f %-13.5g %-13.5g %-13.5g %-13.6g %-9.4f%s\n",
        mu, tf(mu), coherent_population(mu, T, eps_cut),
        incoherent_population(mu, T, eps_cut), t, j,
        abs(j) > 0.05 ? "   <-- JUMP" : "")
    prev = t
end
@printf("\nlevels: eps_n = (n+1.5) for n=1..5 -> %s\n",
    join((@sprintf("%.1f", (n + 1.5)) for n in 1:5), ", "))
