# Robust FORT-ramp optimization at several uniform operational-error levels ε ∈ {0, 1, 5, 10}%.
# For each ε the tolerance on EVERY operational axis (power/α, beam imbalance, T₀, N₀) is set to ε,
# `optimize_ramp_robust` maximizes the worst-case N_BEC over that set (ε=0 ⇒ the nominal optimum),
# and we record the optimal ramp shape + nominal/worst-case N_BEC. Shows how the schedule and the
# guaranteed atom number move as the error budget grows. One process → load once, optimize ×4.
#
# Usage: julia --project=. scripts/eu_evaporation_robust_levels.jl
using SpinorBEC, DelimitedFiles
using SpinorBEC: Eu151, EvapParams, euv3_evap_trap, euv3_evaporation_ramp, euv3_defaults,
    FortRamp, run_evaporation, fort_power_at, evaporation_summary,
    robustness_scenarios, optimize_ramp_robust, robustness_report

const OUT = joinpath(@__DIR__, "..", "docs", "guides", "figures")
const LEVELS = [0.0, 0.01, 0.05, 0.10]

d = euv3_defaults()
trap = euv3_evap_trap()
p = EvapParams(; a_s=Eu151.a_s, tau_bg=d.tau_bg, K3=d.K3)
lab = euv3_evaporation_ramp()
N0, T0 = d.N0, d.T0

lab_res = run_evaporation(trap, lab, p; N0=N0, T0=T0)
lab_NBEC = lab_res.reached_bec ? lab_res.N_BEC : 0.0
println("lab ramp N_BEC = ", round(Int, lab_NBEC))

results = NamedTuple[]
for ε in LEVELS
    scs = robustness_scenarios(trap, p; N0=N0, T0=T0,
        power_frac=ε, imbalance_frac=ε, T0_frac=ε, N0_frac=ε)   # ε=0 ⇒ empty ⇒ nominal optimum
    out = optimize_ramp_robust(trap, p, lab; N0=N0, T0=T0, scenarios=scs,
        n_sweeps=8, n_line=17, restarts=3, seed=1)
    worst = isempty(scs) ? out.N_BEC : out.worst
    push!(results, (ε=ε, ramp=out.ramp, N_BEC=out.N_BEC, worst=worst, nscen=length(scs)))
    println("ε=", Int(round(100ε)), "%  scenarios=", length(scs),
        "  nominal N_BEC=", round(Int, out.N_BEC),
        "  worst-case=", round(Int, worst),
        "  (×lab ", round(worst / lab_NBEC; digits=2), ")")
end

# --- levels table ---
open(joinpath(OUT, "eu_evap_robust_levels.csv"), "w") do io
    println(io, "eps_pct,nominal_NBEC,worst_NBEC,ratio_worst_vs_lab")
    for r in results
        println(io, Int(round(100r.ε)), ",", round(Int, r.N_BEC), ",",
            round(Int, r.worst), ",", round(r.worst / lab_NBEC; digits=3))
    end
end

# --- ramp shapes (H,V) per level, on a shared dense grid ---
tmax = maximum(r -> r.ramp.times[end], results)
tg = collect(range(0.0, tmax; length=400))
M = zeros(length(tg), 1 + 2 * (length(results) + 1))
M[:, 1] = tg
for (i, t) in enumerate(tg)
    pl = fort_power_at(lab, t)
    M[i, 2], M[i, 3] = pl[1], pl[2]                       # lab H, V
    for (k, r) in enumerate(results)
        pr = fort_power_at(r.ramp, t)
        M[i, 2 + 2k], M[i, 3 + 2k] = pr[1], pr[2]        # ε_k H, V
    end
end
writedlm(joinpath(OUT, "eu_evap_robust_levels_ramps.csv"), M, ',')

# --- per-scenario breakdown at the largest ε (10%) ---
scs10 = robustness_scenarios(trap, p; N0=N0, T0=T0,
    power_frac=0.10, imbalance_frac=0.10, T0_frac=0.10, N0_frac=0.10)
println("\nPer-scenario N_BEC at ε=10% (nominal-opt ramp vs ε=10%-robust ramp):")
nom_ramp = results[1].ramp          # ε=0 optimum
rob_ramp = results[end].ramp        # ε=10% optimum
for (a, b) in zip(robustness_report(trap, p, nom_ramp; N0=N0, T0=T0, scenarios=scs10),
    robustness_report(trap, p, rob_ramp; N0=N0, T0=T0, scenarios=scs10))
    nb(x) = x.reached_bec ? round(Int, x.N_BEC) : 0
    println("  ", rpad(a.label, 26), "  ε0-opt=", lpad(nb(a), 8), "   ε10-opt=", lpad(nb(b), 8))
end
println("\nwrote CSVs to ", OUT)
