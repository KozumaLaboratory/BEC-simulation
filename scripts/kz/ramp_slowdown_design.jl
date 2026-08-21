# What does a genuinely slower ramp buy, once its extra loss is paid?
#
# The c-field runs say slowing helps: the same (N, T) path traversed 3x more slowly
# multiplies N_0 by 7x and 2.9x at the two points measured, with N_C essentially
# unchanged — more coherence, not more atoms. But that is a NUMERICAL experiment. A real
# slower ramp spends longer at every density, so three-body loss eats more, and
# N_total(t) is lower everywhere.
#
# So there should be an optimum, and the 0-D model can find it in seconds: stretch the
# FortRamp time axis (same beam powers, more time), re-run the evaporation, and read the
# peak equilibrium N_0 from the same LDA constraint used for the 4.0e4 verdict.
#
# What this does NOT settle: whether the c-field reaches the peak the constraint names.
# That is the dynamics question and it needs the field. This locates the target.
using SpinorBEC, Printf
include(joinpath(@__DIR__, "../../docs/guides/figures/eu_evaporation_spgpe.jl"))

"""Stretch a FortRamp's time axis by `s`, holding the beam powers."""
stretch(r::FortRamp, s::Real) = FortRamp(r.times .* s, r.powers_W)

@printf("%-7s %-11s %-11s %-9s %-11s %-11s %-9s\n",
    "slow", "duration", "N at peak", "T (nK)", "mu_eq", "N0_peak", "t_peak")
for s in (0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 5.0)
    trap = euv3_evap_trap()
    ramp = stretch(euv3_evaporation_ramp(), s)
    p = EvapParams(; a_s=Eu151.a_s, tau_bg=15.0, K3=1.61e-40)
    r = run_evaporation_bec(trap, ramp, p; N0=3.5e6, T0=50e-6, save_every=2)
    # The trajectory's OWN trap frequency. A fixed reference looked like the way to keep
    # mu_eq comparable across slowdowns and was simply wrong: 2pi*100 puts T_int at 10450
    # where the real omega_bar gives 1762, six times too hot, and the constraint then
    # reports N_0 = 0 at every point of every ramp. The trap ramp is identical across
    # slowdowns — only the time axis is stretched — so omega_bar carries no bias here.
    # From the trap and ramp, the way zero_d_trajectory does it. EvapBecResult has no
    # omega_bar — that field is on EvapResult, a different return type, and reaching for
    # it threw. Same mistake as reading r.t_BEC when the field is r.t_bec: the two result
    # types are easy to confuse and neither name is wrong on its own.
    ω = evap_trap_grid(trap, ramp).ωg[1]
    # -1 rather than 0, so a trajectory that never condenses reports N0_peak = 0 with
    # its own first point rather than silently looking like a peak of zero.
    best = (N0=-1.0, t=NaN, N=NaN, T=NaN, mu=NaN)
    for i in eachindex(r.t)
        r.N[i] > 0 && r.T[i] > 0 || continue
        T_int = r.T[i] * Units.KB / (Units.HBAR * ω)
        T_int > 1e-3 || continue
        g = mu_from_total_lda(r.N[i]; T=T_int, c0=0.02, eps_cut=1.5 + 3 * T_int)
        (isnan(g.N0) || g.N0 <= best.N0) && continue
        best = (N0=g.N0, t=r.t[i] - r.t[1], N=r.N[i], T=r.T[i], mu=g.mu)
    end
    @printf("%-7.2f %-11.3g %-11.4g %-9.4g %-11.4g %-11.4g %-9.3f\n",
        s, r.t[end] - r.t[1], best.N, 1e9 * best.T, best.mu, best.N0, best.t)
    flush(stdout)
end
@printf("\nN0_peak rising with slow  => slower is better, loss has not caught up\n")
@printf("N0_peak turning over      => the optimum is where the two cross\n")
