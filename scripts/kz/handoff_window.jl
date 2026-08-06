# Where can the c-field take over from the 0-D model?
#
# The c-field only describes modes with occupation of order one, so it cannot start at
# 50 uK: internal T = 1762 there, eps_cut ~ 5290, k_cut = 103, and a grid resolving
# that needs ~520^3 — 1300x the cost of the 48^3 that already runs at 460 ms/step.
#
# So the handoff is somewhere later in the ramp. Print the trajectory in INTERNAL
# units and the grid each point would need, and let the affordable window be read off
# rather than guessed.
using SpinorBEC, Printf
include(joinpath(@__DIR__, "..", "..", "docs", "guides", "figures",
    "eu_evaporation_spgpe.jl"))
traj = zero_d_trajectory()
r = traj.r
ω_ref = traj.omega_of(r.t[1])
@printf("omega_ref = %.4g rad/s   (a_ho = %.4g um)\n", ω_ref,
    1e6 * sqrt(Units.HBAR / (Eu151.mass * ω_ref)))
@printf("\n%-8s %-10s %-11s %-9s %-9s %-8s %-10s\n",
    "t (s)", "N", "T (nK)", "T_int", "k_cut", "n@box16", "cost/step")
for i in 1:max(1, length(r.t) ÷ 22):length(r.t)
    T_int = r.T[i] * Units.KB / (Units.HBAR * ω_ref)
    eps_cut = 1.5 + 3 * T_int
    k_cut = sqrt(2 * eps_cut)
    n_need = ceil(Int, 2 * k_cut * 16.0 / π)          # k_max = pi n/box > k_cut, x2 margin
    # 48^3 D=1 no DDI measured at ~24 ms/step (D=13 with DDI was 460); scale as n^3 log n
    cost = 24.0 * (n_need / 48)^3 * log(n_need) / log(48)
    @printf("%-8.3f %-10.4g %-11.4g %-9.4g %-9.2f %-8d %-10s\n",
        r.t[i] - r.t[1], r.N[i], 1e9 * r.T[i], T_int, k_cut, n_need,
        cost < 1e4 ? @sprintf("%.0f ms", cost) : @sprintf("%.1g s", cost / 1e3))
end
@printf("\n0-D final: N0=%.4g  T=%.4g nK  t_bec=%.4g s\n",
    r.N0_final, 1e9 * r.T_final, r.t_bec)
