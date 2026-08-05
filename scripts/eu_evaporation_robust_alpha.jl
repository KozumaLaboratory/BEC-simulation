# Robust FORT-ramp optimization for ¹⁵¹Eu evaporation: maximize the worst-case BEC
# atom number over the apparatus operating envelope (absolute FORT-power / α
# calibration, beam imbalance, loaded N₀/T₀, timing). Emits the comparison CSVs the
# figure driver (eu_evaporation_robust_alpha.py) turns into the two-panel deliverable:
#   A) N_BEC vs common power/α calibration factor for lab / nominal-opt / robust ramps
#      (the "optimized AND robust" cliff plot; power ≡ α since the depth is ∝ αP),
#   B) the H/V power schedules of the three ramps.
#
# Usage: julia --project=. scripts/eu_evaporation_robust_alpha.jl
using SpinorBEC, DelimitedFiles
using SpinorBEC: Eu151, EvapParams, euv3_evap_trap, euv3_evaporation_ramp, euv3_defaults,
    FortRamp, run_evaporation, fort_power_at, _EUV3_ALPHA,
    optimize_ramp_monotone, robustness_scenarios, optimize_ramp_robust, robustness_report

const OUT = joinpath(@__DIR__, "..", "docs", "guides", "figures")

# --- Operational-error tolerances (worst-plausible; cited error budget) ---
# power/α is the combined absolute-DEPTH budget: absolute power at the atoms ~3%
# (Huntemann arXiv:1602.03908) ⊕ waist→depth ~4–6% (Sr arXiv:2606.00242 quotes 3.8%
# on U₀; depth ∝ 1/w²) ⇒ ~10% worst-plausible. Since depth ∝ αP this axis IS the α
# axis. Imbalance: crossed-ODT beam ratio held to ~0.5–1% (μXODT arXiv:2408.07187
# "0.998 power ratio"), 2% conservative. T₀/N₀: 2–4% / 2–3% shot-to-shot
# (Szmuk arXiv:1502.03864). Timing is DROPPED: ns ARTIQ grain over a 2.7 s ramp is
# ~1e-8 fractional — 6–8 orders below every other axis, never a real error source.
const POWER_FRAC = 0.10
const IMBALANCE_FRAC = 0.02
const T0_FRAC = 0.04
const N0_FRAC = 0.03
const TIME_FRAC = 0.0

d = euv3_defaults()
trap = euv3_evap_trap()
p = EvapParams(; a_s=Eu151.a_s, tau_bg=d.tau_bg, K3=d.K3)
lab = euv3_evaporation_ramp()
N0, T0 = d.N0, d.T0

scs = robustness_scenarios(trap, p; N0=N0, T0=T0,
    power_frac=POWER_FRAC, imbalance_frac=IMBALANCE_FRAC,
    T0_frac=T0_FRAC, N0_frac=N0_FRAC, time_frac=TIME_FRAC)

println("Optimizing (nominal)…");
flush(stdout)
nom = optimize_ramp_monotone(trap, p, lab; N0=N0, T0=T0)
println("  nominal N_BEC = ", round(nom.N_BEC))
println("Optimizing (robust over ", length(scs), " operational scenarios)…");
flush(stdout)
rob = optimize_ramp_robust(trap, p, lab; N0=N0, T0=T0, scenarios=scs)
println("  robust nominal N_BEC = ", round(rob.N_BEC), "  worst-case = ", round(rob.worst))

# --- Panel A: N_BEC vs common power/α calibration factor (the cliff) ---
nbec(t, r) = (rr=run_evaporation(t, r, p; N0=N0, T0=T0); rr.reached_bec ? rr.N_BEC : 0.0)
facs = collect(0.75:0.025:1.30)
A = zeros(length(facs), 4)
for (i, f) in enumerate(facs)
    t = euv3_evap_trap(; alpha=_EUV3_ALPHA * f)
    A[i, :] = [f, nbec(t, lab), nbec(t, nom.ramp), nbec(t, rob.ramp)]
end
writedlm(joinpath(OUT, "eu_evap_robust_alpha_cliff.csv"), A, ',')

# --- Panel B: H/V power schedules (dense sampling of the piecewise-linear ramps) ---
tmax = maximum(r -> r.times[end], (lab, nom.ramp, rob.ramp))
tg = collect(range(0.0, tmax; length=400))
B = zeros(length(tg), 7)
for (i, t) in enumerate(tg)
    pl = fort_power_at(lab, t);
    pn = fort_power_at(nom.ramp, t);
    pr = fort_power_at(rob.ramp, t)
    B[i, :] = [t, pl[1], pl[2], pn[1], pn[2], pr[1], pr[2]]
end
writedlm(joinpath(OUT, "eu_evap_robust_alpha_ramps.csv"), B, ',')

# --- Per-scenario breakdown table (stdout + CSV) ---
println("\nPer-scenario N_BEC (lab / nominal-opt / robust):")
labrep = robustness_report(trap, p, lab; N0=N0, T0=T0, scenarios=scs)
nomrep = robustness_report(trap, p, nom.ramp; N0=N0, T0=T0, scenarios=scs)
robrep = robustness_report(trap, p, rob.ramp; N0=N0, T0=T0, scenarios=scs)
open(joinpath(OUT, "eu_evap_robust_alpha_scenarios.csv"), "w") do io
    println(io, "scenario,lab,nominal_opt,robust")
    for k in eachindex(labrep)
        nb(r) = r.reached_bec ? round(Int, r.N_BEC) : 0
        println(io, labrep[k].label, ",", nb(labrep[k]), ",", nb(nomrep[k]), ",", nb(robrep[k]))
        println("  ", rpad(labrep[k].label, 26), "  ", lpad(nb(labrep[k]), 8),
            "  ", lpad(nb(nomrep[k]), 8), "  ", lpad(nb(robrep[k]), 8))
    end
end

# worst-case summary
wc(rep) = minimum(r -> r.reached_bec ? r.N_BEC : 0.0, rep)
println("\nWORST-CASE N_BEC:  lab=", round(Int, wc(labrep)),
    "  nominal-opt=", round(Int, wc(nomrep)), "  robust=", round(Int, wc(robrep)))
println("wrote CSVs to ", OUT)
