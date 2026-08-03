# Does the KZ protocol cross a transition at all?
#
# The driver holds mu = 15 and ramps T from 30 to 2, with a comment asserting
# "the transition is crossed by cooling rather than by pumping atoms in". That
# was never checked. In a grand-canonical classical field mu = 15 sits far above
# eps_0 = 1.5, and the only thing that can destroy the condensate at fixed mu is
# the thermal cloud's mean-field shift 2 c0 n_th exceeding mu - V. So there IS a
# possible T_c -- the question is where it is relative to 30.
#
# Self-consistent Hartree-Fock for the classical (Rayleigh-Jeans) field, local
# density, on a radial grid:
#     c0 n_0(r)  = max(mu - V(r) - 2 c0 n_th(r), 0)
#     n_th(r)    = (T/pi^2) [K - sqrt(2D) atan(K/sqrt(2D))],
#     D(r) = V + 2 c0 n - mu   (>= 0),   K(r) = sqrt(2 (eps_cut - V - 2 c0 n))
# with eps_cut = mu + n_T T, the same tracking cutoff the runs use.
using Printf

const c0, ω = 0.19, 1.0
V(r) = 0.5 * ω^2 * r^2

function nth_local(T, Δ, K)
    (K <= 0 || Δ < 0) && return 0.0
    Δ < 1e-12 && return T * K / π^2
    s = sqrt(2Δ)
    (T / π^2) * (K - s * atan(K / s))
end

function solve(T, mu; n_T=1.0, rmax=12.0, nr=1200, iters=400)
    eps_cut = mu + n_T * T
    r = range(0, rmax; length=nr)
    n0 = zeros(nr);
    nth = zeros(nr)
    for _ in 1:iters
        n0_new = similar(n0);
        nth_new = similar(nth)
        for i in 1:nr
            Vi = V(r[i])
            n0i = max(mu - Vi - 2c0 * nth[i], 0.0) / c0
            ntot = n0i + nth[i]
            Δ = Vi + 2c0 * ntot - mu
            K2 = 2 * (eps_cut - Vi - 2c0 * ntot)
            nth_new[i] = nth_local(T, max(Δ, 0.0), K2 > 0 ? sqrt(K2) : 0.0)
            n0_new[i] = n0i
        end
        n0 .= n0_new
        nth .= 0.5 .* nth .+ 0.5 .* nth_new          # damped, or it oscillates
    end
    dr = step(r)
    N0 = 4π * sum(n0 .* r .^ 2) * dr
    Nth = 4π * sum(nth .* r .^ 2) * dr
    (; N0, Nth, n0_center=n0[1], nth_center=nth[1])
end

@printf("mu = 15, c0 = 0.19, eps_cut = mu + T  (the tracking cutoff the runs use)\n\n")
@printf("%-8s %-12s %-12s %-12s %-10s\n", "T", "N_0", "N_th", "N_0/N", "2c0*nth(0)")
for T in (2.0, 5.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 80.0, 100.0)
    s = solve(T, 15.0)
    @printf("%-8.1f %-12.4g %-12.4g %-12.4f %-10.3f\n",
        T, s.N0, s.Nth, s.N0 / (s.N0 + s.Nth), 2c0 * s.nth_center)
end

# Bisect for the T where the central condensate density vanishes.
lo, hi = 2.0, 400.0
for _ in 1:50
    mid = 0.5 * (lo + hi)
    solve(mid, 15.0).n0_center > 0 ? (global lo = mid) : (global hi = mid)
end
@printf("\nT_c (n_0(0) -> 0 at fixed mu = 15) = %.2f\n", 0.5 * (lo + hi))
@printf("the ramp runs T = 30 -> 2, i.e. %s\n",
    0.5 * (lo + hi) > 30 ? "ENTIRELY BELOW T_c: no transition is crossed" :
    "across T_c: the protocol is sound")
