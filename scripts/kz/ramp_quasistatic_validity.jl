# Is the 0-D model still quasi-static at the ramps its own scan recommends?
#
# The design scan says the peak equilibrium N_0 is best at 0.3-0.5x — 6.0e4 against 4.4e4
# for the current ramp, and above the measured 5.02e4. It also returns a NON-MONOTONE fast
# end: 3.29e4 / 1.85e4 / 1.64e4 / 3.41e4 at 0.05 / 0.10 / 0.15 / 0.20x, where physics
# should be smooth. That is the signature of a model being asked a question outside its
# assumptions, and condensate.jl states the assumption in its header: "standard
# quasi-static two-component evaporation" — the gas is taken to stay in thermal
# equilibrium throughout.
#
# The condition is that the trap depth changes slowly against the elastic collision rate.
# gamma_el is on EvapResult (the thermal-only solver), so run that along each stretched
# ramp and report collisions per e-folding of the depth. A recommendation the model cannot
# support is worse than no recommendation.
using SpinorBEC, Printf
include(joinpath(@__DIR__, "../../docs/guides/figures/eu_evaporation_spgpe.jl"))

stretch(r::FortRamp, s::Real) = FortRamp(r.times .* s, r.powers_W)

@printf("%-7s %-10s %-12s %-12s %-12s %-10s\n",
    "slow", "duration", "min coll/ef", "median", "gamma_el max", "verdict")
for s in (0.05, 0.1, 0.2, 0.3, 0.5, 1.0, 2.0)
    trap = euv3_evap_trap()
    ramp = stretch(euv3_evaporation_ramp(), s)
    p = EvapParams(; a_s=Eu151.a_s, tau_bg=15.0, K3=1.61e-40)
    r = run_evaporation(trap, ramp, p; N0=3.5e6, T0=50e-6, save_every=2)
    # collisions per e-folding of the trap depth: gamma_el / |d ln U / dt|
    coll = Float64[]
    for i in 2:length(r.t)
        dt = r.t[i] - r.t[i - 1]
        (dt > 0 && r.U_depth[i] > 0 && r.U_depth[i - 1] > 0) || continue
        rate = abs(log(r.U_depth[i] / r.U_depth[i - 1])) / dt
        rate > 0 && push!(coll, r.gamma_el[i] / rate)
    end
    isempty(coll) && (push!(coll, NaN))
    sort!(coll)
    med = coll[max(1, length(coll) ÷ 2)]
    # The conventional requirement is a few elastic collisions per e-folding; below ~1 the
    # cloud cannot re-thermalise between steps and the quasi-static split is fiction.
    v = coll[1] >= 3 ? "OK" : coll[1] >= 1 ? "MARGINAL" : "INVALID"
    @printf("%-7.2f %-10.3g %-12.3g %-12.3g %-12.3g %-10s\n",
        s, r.t[end] - r.t[1], coll[1], med, maximum(r.gamma_el), v)
    flush(stdout)
end
@printf("\nA recommendation at a slowdown marked INVALID is a statement about the model,\n")
@printf("not about the experiment.\n")
