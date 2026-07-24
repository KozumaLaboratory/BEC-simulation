# Monte-Carlo uncertainty propagation for the optimized Eu evaporation ramp (issue #75).
# Samples every uncertain parameter (unmeasured + calibration) from its range and pushes
# the FIXED optimized ramp through the model → the distribution of N₀ and T_final, i.e.
# honest confidence bands on the prediction. Reads the ramp from <OUT>/ramp_opt.csv.

using SpinorBEC
using Printf, Random, Statistics
const BOHR=5.29177210903e-11
const OUT=length(ARGS)>=1 ? ARGS[1] : "gopt_out"; mkpath(OUT)
const NS=length(ARGS)>=2 ? parse(Int,ARGS[2]) : 4000

# load the optimized ramp (dense piecewise-linear) → FortRamp
rows=readlines(joinpath(OUT,"ramp_opt.csv"))[2:end]
ts=Float64[]; hs=Float64[]; vs=Float64[]
for l in rows; a=split(l,","); push!(ts,parse(Float64,a[1])); push!(hs,parse(Float64,a[2])); push!(vs,parse(Float64,a[3])); end
ramp=FortRamp(ts, permutedims(hcat(hs,vs,zeros(length(ts)))))
cf(r)=r.N0_final/max(r.N[end],1)

# uncertain parameters and their sampling ranges (see issue §2c)
rng=MersenneTwister(20240724)
logu(a,b)=exp(log(a)+rand(rng)*(log(b)-log(a)))
unif(a,b)=a+rand(rng)*(b-a)
N0v=Float64[]; Tv=Float64[]; cfv=Float64[]
for _ in 1:NS
    K3   = logu(1e-42,1e-40)              # three-body: unmeasured, 2 decades
    heat = unif(0.01,0.20)                # heating rate: unmeasured
    tau  = unif(10.0,40.0)                # background lifetime: unmeasured
    a_s  = (135 + 15*randn(rng))*BOHR     # scattering length 135±15 a_B (12° tilt syst.)
    fw   = 1.0 + 0.10*randn(rng)          # waists ±10%
    alpha= 5.88e-37*(1+0.05*randn(rng))   # polarizability ±5%
    N0   = 1.4e6*(1+0.20*randn(rng))      # loaded number ±20%
    T0   = 50e-6*(1+0.10*randn(rng))      # loaded temperature ±10%
    trap=euv3_evap_trap(; waists=[sqrt(26e-6*30e-6)*fw, 47e-6*fw, 47e-6*fw], alpha=alpha,
        directions=[(1.0,0.0,0.0),(0.0,0.0,1.0),(0.0,1.0,0.0)])
    p=EvapParams(; a_s=a_s, tau_bg=tau, K3=K3, heating_rate=heat)
    r=run_evaporation_bec(trap,ramp,p; N0=max(N0,1e5), T0=max(T0,1e-6))
    push!(N0v,r.N0_final); push!(Tv,r.T_final*1e9); push!(cfv,cf(r))
end
open(joinpath(OUT,"mc.csv"),"w") do io
    println(io,"N0,T,cf"); for i in eachindex(N0v); @printf(io,"%.5e,%.3f,%.4f\n",N0v[i],Tv[i],cfv[i]); end
end
q(x,p)=sort(x)[clamp(round(Int,p*length(x)),1,length(x))]
@printf("N=%d samples\n",NS)
@printf("N0 : median=%.2e  68%%=[%.2e,%.2e]  95%%=[%.2e,%.2e]\n",
    median(N0v),q(N0v,0.16),q(N0v,0.84),q(N0v,0.025),q(N0v,0.975))
@printf("T  : median=%.0fnK 68%%=[%.0f,%.0f] 95%%=[%.0f,%.0f]\n",
    median(Tv),q(Tv,0.16),q(Tv,0.84),q(Tv,0.025),q(Tv,0.975))
@printf("pure (cf>=0.95): %.0f%%\n",100*count(>=(0.95),cfv)/NS)
println("wrote mc.csv")
