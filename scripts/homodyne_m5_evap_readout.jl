# Homodyne readout of the m=-5 spin component during the euv3 evaporation ramp.
#
# Physics. The m=-6 condensate (atom number N) is the local-oscillator reservoir.
# A weak Raman pulse (pulse area θ, Δm=+1 via F_+) coherently injects a fraction of
# it into m=-5 as a phase-reference amplitude a_LO = sinθ·√N. A pre-existing m=-5
# signal a_s = √(εN)·e^{iφ} (ε = fixed small spin-dynamics/thermal fraction) then
# interferes WITH IT inside the m=-5 channel:
#
#   N_meas = |a_LO + a_s e^{iφ}|² = sin²θ·N  +  εN  +  2 sinθ √ε · N cosφ
#                                   └ carrier ┘ └DC┘  └─ homodyne fringe ─┘
#
# The homodyne term S_hom = 2 sinθ √ε · N is LINEAR in the small signal amplitude √ε
# (vs the direct-imaging εN, quadratic in amplitude) and grows ∝ N. With a detection
# floor σ_det (atoms), SNR_hom = S_hom/√(sin²θ·N + σ_det²) → 2√ε·√N at large N: the
# strong LO carrier lifts the tiny m=-5 signal above the floor that buries direct
# imaging. So a ramp that maximizes the final atom number ALSO maximizes the m=-5
# homodyne sensitivity — the effect we visualize across the evaporation optimization.
#
# Emits CSVs to figs/homodyne_m5_evap/; render with scripts/viz_homodyne_m5_evap.py.
# 0-D evaporation model is ms/run, so the (duration × final-power) surface is dense.

using SpinorBEC
using DelimitedFiles

const OUT = get(ENV, "HOMODYNE_OUT", "figs/homodyne_m5_evap")
mkpath(OUT)

# --- homodyne readout model (phase-locked, cosφ = 1; best case) ---
const EPS_M5 = parse(Float64, get(ENV, "HOMODYNE_EPS", "1e-3"))   # m=-5 signal fraction
const THETA = parse(Float64, get(ENV, "HOMODYNE_THETA", "0.15")) # Raman pulse area [rad]
const SIG_DET = parse(Float64, get(ENV, "HOMODYNE_SIGDET", "300")) # detection floor [atoms]

carrier(N) = sin(THETA)^2 * N
s_hom(N) = 2 * sin(THETA) * sqrt(EPS_M5) * N
s_dir(N) = EPS_M5 * N
snr_hom(N) = s_hom(N) / sqrt(carrier(N) + SIG_DET^2)
snr_dir(N) = s_dir(N) / sqrt(s_dir(N) + SIG_DET^2)

d = euv3_defaults()
trap = euv3_evap_trap()
p = EvapParams(; a_s=d.a_s, tau_bg=d.tau_bg, K3=d.K3)
base = euv3_evaporation_ramp()
N0, T0 = d.N0, d.T0

println("euv3 defaults: N0=$(N0)  T0=$(T0*1e6) µK  K3=$(d.K3)")
println("homodyne model: ε=$(EPS_M5)  θ=$(THETA) rad  σ_det=$(SIG_DET) atoms")

# --- Panel A: signal & SNR vs atom number ---
Ngrid = 10.0 .^ range(3.0, 6.4; length=240)
A = hcat(Ngrid, s_hom.(Ngrid), s_dir.(Ngrid), snr_hom.(Ngrid), snr_dir.(Ngrid))
open(joinpath(OUT, "signal_vs_N.csv"), "w") do io
    println(io, "N,s_hom,s_dir,snr_hom,snr_dir")
    writedlm(io, A, ',')
end

# --- Panel B: readout along the nominal euv3 evaporation trajectory ---
r = run_euv3_evaporation()
sm = evaporation_summary(r)
println("nominal ramp: reached_bec=$(sm.reached_bec)  N_BEC=$(sm.N_BEC)  T_BEC=$(sm.T_BEC_uK) µK")
B = hcat(r.t, r.N, r.T .* 1e6, r.psd, snr_hom.(r.N), snr_dir.(r.N))
open(joinpath(OUT, "ramp_trajectory.csv"), "w") do io
    println(io, "t,N,T_uK,psd,snr_hom,snr_dir")
    writedlm(io, B, ',')
end

# --- Panel C: (duration_scale × final_power_scale) optimization surface ---
ds = collect(range(0.5, 3.0; length=44))   # index 1 of ramp_from_params
fs = collect(range(0.3, 2.0; length=44))   # index 2
rows = Vector{NTuple{6, Float64}}()
for v1 in ds, v2 in fs
    ramp = ramp_from_params([v1, v2, 1.0], base)
    res = run_evaporation(trap, ramp, p; N0=N0, T0=T0)
    Nf = isempty(res.N) ? N0 : res.N[end]
    nbec = res.reached_bec ? res.N_BEC : NaN
    push!(rows, (v1, v2, Nf, nbec, res.reached_bec ? 1.0 : 0.0, snr_hom(Nf)))
end
open(joinpath(OUT, "opt_surface.csv"), "w") do io
    println(io, "ds,fs,N_final,N_BEC,reached,snr_hom")
    for row in rows
        println(io, join(row, ","))
    end
end
writedlm(joinpath(OUT, "opt_axes.csv"), [permutedims(ds); permutedims(fs)], ',')

# --- Panel D: lab ramp vs monotone-optimized ramp ---
r_lab = run_evaporation(trap, base, p; N0=N0, T0=T0)
opt = optimize_ramp_monotone(trap, p, base; N0=N0, T0=T0, restarts=3)
N_lab = isempty(r_lab.N) ? N0 : r_lab.N[end]
N_opt = isempty(opt.result.N) ? N0 : opt.result.N[end]
println("lab ramp:  N_final=$(N_lab)  N_BEC=$(r_lab.reached_bec ? r_lab.N_BEC : NaN)")
println("opt ramp:  N_final=$(N_opt)  N_BEC=$(opt.N_BEC)")
open(joinpath(OUT, "ramp_compare.csv"), "w") do io
    println(io, "label,N_final,N_BEC,snr_hom")
    println(io, "lab,$(N_lab),$(r_lab.reached_bec ? r_lab.N_BEC : NaN),$(snr_hom(N_lab))")
    println(io, "optimized,$(N_opt),$(opt.N_BEC),$(snr_hom(N_opt))")
end

open(joinpath(OUT, "meta.csv"), "w") do io
    println(io, "key,value")
    println(io, "eps,$(EPS_M5)")
    println(io, "theta,$(THETA)")
    println(io, "sig_det,$(SIG_DET)")
    println(io, "N0,$(N0)")
    println(io, "T0_uK,$(T0*1e6)")
    println(io, "t_BEC,$(sm.t_BEC_s)")
    println(io, "N_BEC_nominal,$(sm.N_BEC)")
end

println("wrote CSVs to $(OUT)")
