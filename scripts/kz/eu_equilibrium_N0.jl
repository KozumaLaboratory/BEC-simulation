# What does the CONSTRAINT say the condensate should be, along the euv3 ramp?
#
# The field reports N_0 = 0 through the first 5% of the c-field window while mu sits
# near 4.6 and the total falls 1.4e4 -> 1.1e4. Two readings: the cloud genuinely has
# no condensate at those (N, T), or the field is lagging. The constraint answers the
# first directly — it returns the equilibrium N_0 at each (N_total, T) — and it costs
# seconds, so there is no reason to infer it from a trajectory.
#
# This is also the 0-D model's claim restated in the c-field's own variables, so
# disagreement between them is informative either way.
using SpinorBEC, Printf
include(joinpath(@__DIR__, "..", "..", "docs", "guides", "figures",
    "eu_evaporation_spgpe.jl"))
traj = zero_d_trajectory()
r = traj.r
ω = traj.omega_of(r.t[1])
c0 = 0.02
@printf("%-8s %-11s %-9s %-9s %-11s %-11s %-11s %-8s\n",
    "t (s)", "N_total", "T (nK)", "T_int", "mu_eq", "N0_eq", "Nth_C", "f0")
for i in 1:max(1, length(r.t) ÷ 18):length(r.t)
    tsec = r.t[i] - r.t[1]
    tsec < 1.5 && continue                       # the c-field window only
    T_int = r.T[i] * Units.KB / (Units.HBAR * ω)
    eps_cut = 1.5 + 3 * T_int
    g = mu_from_total_lda(r.N[i]; T=T_int, c0, eps_cut)
    @printf("%-8.3f %-11.4g %-9.4g %-9.4g %-11.4g %-11.4g %-11.4g %-8.4f\n",
        tsec, r.N[i], 1e9 * r.T[i], T_int, g.mu, g.N0, g.Nth_C,
        isnan(g.N0) ? NaN : g.N0 / r.N[i])
    flush(stdout)
end
@printf("\n0-D model's own final: N0=%.4g  T=%.4g nK\n", r.N0_final, 1e9 * r.T_final)
@printf("measured (PRL 129, 223401): N0 = 5.02e4\n")
