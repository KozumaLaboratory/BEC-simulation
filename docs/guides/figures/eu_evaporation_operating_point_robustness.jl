# Robustness of the CONFIRMED operating point (issue #75 §4.8): evaluate the FIXED
# balanced ramp across the uncertainty ranges of the unmeasured parameters
# (heating rate, K₃, τ_bg) and report the spread of N₀, T_final, condensate fraction.

using SpinorBEC
using Printf
const BOHR=5.29177210903e-11
const OUT = length(ARGS)>=1 ? ARGS[1] : "opr_out"; mkpath(OUT)
alpha=5.88e-37; a_s=135*BOHR; wH=sqrt(26e-6*30e-6); wV=47e-6; N0=1.4e6; T0=50e-6
trap=euv3_evap_trap(; waists=[wH,wV,wV], alpha=alpha,
    directions=[(1.0,0.0,0.0),(0.0,0.0,1.0),(0.0,1.0,0.0)])
# the confirmed monotone operating-point ramp (§4.8)
tt=[0.000,0.132,0.456,0.941,1.573,2.342,3.244,3.950,4.718]
H =[10.0000,10.0000,6.0642,4.3341,2.8770,1.7322,0.8884,0.6072,0.0200]
V =[6.0000,0.5539,0.5138,0.3836,0.3451,0.3153,0.2538,0.1306,0.0500]
ramp=FortRamp(tt, permutedims(hcat(H,V,zeros(9))))
cf(r)=r.N0_final/max(r.N[end],1)
ev(K3,heat,tau)=run_evaporation_bec(trap,ramp,EvapParams(;a_s=a_s,tau_bg=tau,K3=K3,heating_rate=heat);N0=N0,T0=T0)

heats=[0.02,0.05,0.10,0.20]; K3s=[1e-42,3e-42,1e-41]; taus=[10.0,15.0,30.0]
N0v=Float64[]; Tv=Float64[]; cfv=Float64[]
open(joinpath(OUT,"grid.csv"),"w") do io
    println(io,"heat,K3,tau,N0,T,cf")
    for heat in heats, K3 in K3s, tau in taus
        r=ev(K3,heat,tau); push!(N0v,r.N0_final); push!(Tv,r.T_final*1e9); push!(cfv,cf(r))
        @printf(io,"%.3f,%.1e,%.0f,%.4e,%.2f,%.4f\n",heat,K3,tau,r.N0_final,r.T_final*1e9,cf(r))
    end
end
open(joinpath(OUT,"summary.txt"),"w") do io
    @printf(io,"OPERATING-POINT ROBUSTNESS (fixed ramp, %d param combos)\n",length(N0v))
    @printf(io,"heating∈%s /s, K3∈%s m⁶/s, tau_bg∈%s s\n",heats,K3s,taus)
    @printf(io,"N0     : min=%.2e  median=%.2e  max=%.2e   (max/min=%.1f×)\n",minimum(N0v),sort(N0v)[end÷2],maximum(N0v),maximum(N0v)/minimum(N0v))
    @printf(io,"T [nK] : min=%.0f   median=%.0f   max=%.0f\n",minimum(Tv),sort(Tv)[end÷2],maximum(Tv))
    @printf(io,"cond.f : min=%.3f  median=%.3f  max=%.3f  (pure≥0.95: %d/%d)\n",minimum(cfv),sort(cfv)[end÷2],maximum(cfv),count(>=(0.95),cfv),length(cfv))
    @printf(io,"nominal (heat0.05,K3 1e-42,tau15): N0=%.3e T=%.0fnK cf=%.3f\n",ev(1e-42,0.05,15.0).N0_final,ev(1e-42,0.05,15.0).T_final*1e9,cf(ev(1e-42,0.05,15.0)))
    # sensitivity to each axis (hold others nominal)
    @printf(io,"\n--- sensitivity (others nominal) ---\n")
    for h in heats; r=ev(1e-42,h,15.0); @printf(io,"heating=%.2f/s : N0=%.2e T=%.0fnK cf=%.3f\n",h,r.N0_final,r.T_final*1e9,cf(r)); end
    for k in K3s;   r=ev(k,0.05,15.0); @printf(io,"K3=%.0e      : N0=%.2e T=%.0fnK cf=%.3f\n",k,r.N0_final,r.T_final*1e9,cf(r)); end
    for t in taus;  r=ev(1e-42,0.05,t); @printf(io,"tau_bg=%.0fs    : N0=%.2e T=%.0fnK cf=%.3f\n",t,r.N0_final,r.T_final*1e9,cf(r)); end
end
println(read(joinpath(OUT,"summary.txt"),String))
