# Monte-Carlo spread of the BEC atom number under RANDOM operational errors, for box plots.
# Unlike the worst-case (a min over a few one-axis extremes), here every axis is perturbed
# SIMULTANEOUSLY by a Gaussian draw of 1σ = ε on each of: power/α (common-mode depth), beam
# imbalance (H×(1+δ), V×(1−δ)), T₀, N₀. We draw M realizations at each ε and record N_BEC for
# BOTH the lab ramp and the (ε-invariant) optimum, so a box/whisker plot shows the real
# shot-to-shot distribution — the "many points" view. The optimum ramp is computed once.
#
# Usage: julia --project=. scripts/eu_evaporation_mc_boxplot.jl
using SpinorBEC, DelimitedFiles, Random
using SpinorBEC: Eu151, EvapParams, euv3_evap_trap, euv3_evaporation_ramp, euv3_defaults,
    FortRamp, run_evaporation, optimize_ramp_monotone, _EUV3_ALPHA

const OUT = joinpath(@__DIR__, "..", "docs", "guides", "figures")
const LEVELS = [0.0, 0.01, 0.02, 0.03, 0.05, 0.07, 0.10]   # 1σ operational-error levels
const NDRAW = 400

d = euv3_defaults()
trap = euv3_evap_trap()
p = EvapParams(; a_s=Eu151.a_s, tau_bg=d.tau_bg, K3=d.K3)
lab = euv3_evaporation_ramp()
N0, T0 = d.N0, d.T0

println("optimizing the (ε-invariant) nominal ramp…")
flush(stdout)
opt = optimize_ramp_monotone(trap, p, lab; N0=N0, T0=T0, restarts=4).ramp

# N_BEC for `ramp` under one operational-error realization (δp,δi,δT,δN)
function draw_nbec(ramp::FortRamp, δp, δi, δT, δN)
    t = euv3_evap_trap(; alpha=_EUV3_ALPHA * (1 + δp))       # common-mode depth ≡ α (αP degeneracy)
    pw = copy(ramp.powers_W)
    pw[1, :] .*= (1 + δi)                                    # H beam
    size(pw, 1) >= 2 && (pw[2, :] .*= (1 - δi))              # V beam (opposite ⇒ imbalance)
    r2 = FortRamp(ramp.times, pw)
    rr = run_evaporation(t, r2, p; N0=N0 * (1 + δN), T0=T0 * (1 + δT))
    rr.reached_bec ? rr.N_BEC : 0.0
end

rng = MersenneTwister(20260719)
rows = Vector{Any}[]
for ε in LEVELS
    for _ in 1:NDRAW
        δp, δi, δT, δN = ε .* randn(rng, 4)
        push!(rows, [Int(round(100ε)), draw_nbec(lab, δp, δi, δT, δN),
            draw_nbec(opt, δp, δi, δT, δN)])
    end
end
M = permutedims(hcat(rows...))
open(joinpath(OUT, "eu_evap_mc_boxplot.csv"), "w") do io
    println(io, "eps_pct,lab_NBEC,opt_NBEC")
    writedlm(io, M, ',')
end

# quick text summary (median + 5/95 pct of the optimum, and BEC-miss fraction)
println("\nε%   opt median   opt 5–95%          miss(opt)")
for ε in LEVELS
    v = [r[3] for r in rows if r[1] == Int(round(100ε))]
    sv = sort(v)
    q(f) = sv[clamp(round(Int, f * length(sv)), 1, length(sv))]
    miss = count(==(0.0), v) / length(v)
    println("  ", lpad(Int(round(100ε)), 2), "   ", lpad(round(Int, q(0.5)), 8),
        "   ", lpad(round(Int, q(0.05)), 7), "–", rpad(round(Int, q(0.95)), 7),
        "   ", round(100miss, digits=1), "%")
end
println("\nwrote ", joinpath(OUT, "eu_evap_mc_boxplot.csv"), "  (", size(M, 1), " draws)")
