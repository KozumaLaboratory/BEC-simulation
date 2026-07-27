# SHOWS: the ACTUAL lab evaporation ramp (from 基底状態MOT_20201210更新.js) vs the 3-axis optimum
#        on the same 0-D model — grounds the "evaporation is the base, shaping is the finish" claim in real data.
# DOC:   docs/guides/eu_evaporation_optimization.md ("Experimental campaign" — real-ramp check).
# REPLACES: nothing (new; the experiment-facing sanity check on the real lab ramp).
#
# The JS sequence's hFORT evaporation (vhFORTpower calibration P=10^(-3.72+0.496 V)):
#   10 W (20 ms hold) → 1 W over 6 s (vFORT 0→10 simultaneously) → 0.5 W (0.4 s) → 0.25 W (0.5 s)
#   → 0.2 W (0.25 s) → 0.135 W (0.2 s). Total ~7.35 s. Miyazawa 2020-12 epoch (NOT the 2022 euv3 ramp).
# We run this literal ramp through run_evaporation_bec and overlay it with the 3-axis optimum
# (waist + Feshbach) to show, in real units, that the shaping lever sits on TOP of the evaporation.

using SpinorBEC, Printf
const BOHR = 5.29177210903e-11
const OUT = length(ARGS) >= 1 ? ARGS[1] : "jsramp_out"; mkpath(OUT)

# Miyazawa-epoch trap geometry (thesis Table 6.2): hODT 26×30 µm ellipse, vODT 47 µm.
alpha = 5.88e-37; wH = sqrt(26e-6 * 30e-6); wV = 47e-6
trap = euv3_evap_trap(; waists=[wH, wV, wV], alpha=alpha,
    directions=[(1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0)])
p = EvapParams(; a_s=135 * BOHR, tau_bg=15.0, K3=1.2e-41, heating_rate=0.05)  # direct-measured K3
N0load = 1.4e6; T0 = 50e-6
cf(r) = r.N0_final / max(r.N[end], 1)

# the literal JS ramp: breakpoints [s] and per-beam powers [W] (hFORT, vFORT, sFORT)
tms = [0.0, 0.02, 6.02, 6.42, 6.92, 7.17, 7.37]
hF = [10.0, 10.0, 1.0, 0.5, 0.25, 0.2, 0.135]
vF = [0.0, 0.0, 10.0, 10.0, 10.0, 10.0, 10.0]
# vFORT calibration unknown from JS (only hFORT has vhFORTpower); treat vFORT "10" as ~its max ≈ 7.4 W
# (thesis vODT max 7.4 W). Scale the analog "10" to 7.4 W.
vF = vF .* (7.4 / 10.0)
sF = zeros(length(tms))
ramp_js = FortRamp(tms, permutedims(hcat(hF, vF, sF)))

r_js = run_evaporation_bec(trap, ramp_js, p; N0=N0load, T0=T0)
@printf("JS lab ramp (7.37 s): N_BEC=%.4e  T=%.1f nK  cf=%.3f  t_bec=%.2f s\n",
    r_js.N0_final, r_js.T_final * 1e9, cf(r_js), r_js.t_bec)

# dump the JS trajectory + the ramp shape for plotting
open(joinpath(OUT, "js_traj.csv"), "w") do io
    println(io, "t_s,N,N0,Nth,T_nK,eta")
    for k in eachindex(r_js.t)
        @printf(io, "%.5f,%.6e,%.6e,%.6e,%.4f,%.4f\n",
            r_js.t[k], r_js.N[k], r_js.N0[k], r_js.Nth[k], r_js.T[k] * 1e9, r_js.eta[k])
    end
end
tg = range(0.0, tms[end]; length=300)
open(joinpath(OUT, "js_ramp.csv"), "w") do io
    println(io, "t_s,hFORT_W,vFORT_W,wbar_Hz")
    for t in tg
        pw = fort_power_at(ramp_js, Float64(t))
        _, ω = SpinorBEC.trap_at(trap, pw)
        @printf(io, "%.5f,%.5f,%.5f,%.3f\n", t, pw[1], pw[2], ω / 2π)
    end
end
println("done → ", OUT)
