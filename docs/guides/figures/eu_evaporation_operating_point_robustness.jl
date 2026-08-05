# Robustness of the CONFIRMED operating point (issue #75): evaluate the FIXED balanced
# ramp along each unknown parameter (fine 1-D sweeps, others at nominal) and report the
# spread of N₀, T_final, condensate fraction. K₃ swept over the full [1e-42, 1e-40].

using SpinorBEC
using Printf
const BOHR=5.29177210903e-11
const OUT = length(ARGS)>=1 ? ARGS[1] : "opr_out"; mkpath(OUT)
alpha=5.88e-37; a_s=135*BOHR; wH=sqrt(26e-6*30e-6); wV=47e-6; N0=1.4e6; T0=50e-6
trap=euv3_evap_trap(; waists=[wH,wV,wV], alpha=alpha,
    directions=[(1.0,0.0,0.0),(0.0,0.0,1.0),(0.0,1.0,0.0)])
# confirmed monotone operating-point ramp
tt=[0.000,0.132,0.456,0.941,1.573,2.342,3.244,3.950,4.718]
H =[10.0000,10.0000,6.0642,4.3341,2.8770,1.7322,0.8884,0.6072,0.0200]
V =[6.0000,0.5539,0.5138,0.3836,0.3451,0.3153,0.2538,0.1306,0.0500]
ramp=FortRamp(tt, permutedims(hcat(H,V,zeros(9))))
cf(r)=r.N0_final/max(r.N[end],1)
ev(K3,heat,tau)=run_evaporation_bec(trap,ramp,EvapParams(;a_s=a_s,tau_bg=tau,K3=K3,heating_rate=heat);N0=N0,T0=T0)

# nominal (K₃ central = 1e-41)
K3n,heatn,taun = 1e-41, 0.05, 15.0
logspace(a,b,n)=10 .^ range(log10(a),log10(b);length=n)
heats=collect(range(0.01,0.30;length=41))
K3s  =collect(logspace(1e-42,1e-40,61))         # full two decades, dense & smooth
taus =collect(range(5.0,40.0;length=41))

open(joinpath(OUT,"sweep.csv"),"w") do io
    println(io,"axis,x,N0,T,cf")
    for h in heats; r=ev(K3n,h,taun); @printf(io,"heat,%.5f,%.4e,%.3f,%.4f\n",h,r.N0_final,r.T_final*1e9,cf(r)); end
    for k in K3s;   r=ev(k,heatn,taun); @printf(io,"K3,%.5e,%.4e,%.3f,%.4f\n",k,r.N0_final,r.T_final*1e9,cf(r)); end
    for t in taus;  r=ev(K3n,heatn,t); @printf(io,"tau,%.3f,%.4e,%.3f,%.4f\n",t,r.N0_final,r.T_final*1e9,cf(r)); end
end
rn=ev(K3n,heatn,taun)
@printf("nominal: N0=%.3e T=%.0fnK cf=%.3f\n",rn.N0_final,rn.T_final*1e9,cf(rn))
@printf("K3 range: N0 %.2e (1e-42) -> %.2e (1e-40)  = %.0fx drop\n",ev(1e-42,heatn,taun).N0_final,ev(1e-40,heatn,taun).N0_final,ev(1e-42,heatn,taun).N0_final/ev(1e-40,heatn,taun).N0_final)
println("wrote sweep.csv (", length(heats)+length(K3s)+length(taus), " points)")
