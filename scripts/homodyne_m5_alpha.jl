# Evaporation efficiency α ≡ −dln(PSD)/dln(N) as the control variable for the m=-5
# homodyne readout. At fixed load (N0,T0) and BEC-onset PSD = ζ(3), a ramp's N_BEC is
# a monotone function of its run-averaged α:  N_BEC = N0·(ρ_load/ζ(3))^(1/α). Since the
# m=-5 homodyne readout is detection-floor-dominated over the whole evaporation range
# (SNR ∝ N), the readout sensitivity is set directly by α.
#
# Emits the (ds×fs) ramp ensemble {α=gamma_eff, N_BEC, N_final} and the nominal
# trajectory's running α to figs/homodyne_m5_evap/; plot with viz_homodyne_m5_alpha.py.

using SpinorBEC
using DelimitedFiles

const OUT = get(ENV, "HOMODYNE_OUT", "figs/homodyne_m5_evap")
mkpath(OUT)

d    = euv3_defaults()
trap = euv3_evap_trap()
p    = EvapParams(; a_s=d.a_s, tau_bg=d.tau_bg, K3=d.K3)
base = euv3_evaporation_ramp()
N0, T0 = d.N0, d.T0

# --- ramp ensemble: capture efficiency α (gamma_eff) alongside N_BEC ---
ds = collect(range(0.5, 3.0; length=34))
fs = collect(range(0.3, 2.0; length=34))
open(joinpath(OUT, "alpha_ensemble.csv"), "w") do io
    println(io, "ds,fs,alpha,N_BEC,N_final,rho_load,reached")
    for v1 in ds, v2 in fs
        res = run_evaporation(trap, ramp_from_params([v1, v2, 1.0], base), p; N0=N0, T0=T0)
        Nf   = isempty(res.N) ? N0 : res.N[end]
        nbec = res.reached_bec ? res.N_BEC : NaN
        rho0 = isempty(res.psd) ? NaN : res.psd[1]
        println(io, join((v1, v2, res.gamma_eff, nbec, Nf, rho0,
            res.reached_bec ? 1 : 0), ","))
    end
end

# --- nominal trajectory: running α = −dln(ρ)/dln(N) from the load point ---
r = run_euv3_evaporation()
sm = evaporation_summary(r)
n = length(r.t)
α_run = fill(NaN, n)
for i in 2:n
    dlnN = log(r.N[i]) - log(r.N[1])
    dlnρ = log(r.psd[i]) - log(r.psd[1])
    α_run[i] = abs(dlnN) > 1e-9 ? -dlnρ / dlnN : NaN
end
open(joinpath(OUT, "alpha_trajectory.csv"), "w") do io
    println(io, "t,N,psd,alpha_running")
    writedlm(io, hcat(r.t, r.N, r.psd, α_run), ',')
end

println("nominal ramp: α=$(sm.gamma_eff)  N_BEC=$(sm.N_BEC)  ρ_load=$(r.psd[1])  ρ_BEC=1.202")
println("wrote alpha CSVs to $(OUT)")
