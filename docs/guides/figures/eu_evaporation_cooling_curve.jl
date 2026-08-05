# Smooth N₀-vs-T tradeoff ("cooling curve") for the Eu evaporation (issue #75).
# Fixes a monotone ramp SHAPE and sweeps the final trap depth finely — each depth gives
# one (T_final, N₀) point, so the curve is smooth by construction (evaluations, not
# per-point optimization). K₃ = 1e-41 fixed.

using SpinorBEC
using Printf
const BOHR=5.29177210903e-11
const OUT = length(ARGS)>=1 ? ARGS[1] : "cc_out"; mkpath(OUT)
alpha=5.88e-37; a_s=135*BOHR; wH=sqrt(26e-6*30e-6); wV=47e-6; N0=1.4e6; T0=50e-6
K3=1e-41; HEAT=0.01
trap=euv3_evap_trap(; waists=[wH,wV,wV], alpha=alpha,
    directions=[(1.0,0.0,0.0),(0.0,0.0,1.0),(0.0,1.0,0.0)])
p=EvapParams(; a_s=a_s, tau_bg=15.0, K3=K3, heating_rate=HEAT)
base_times=[0.0,1.0,2.0,3.0,4.0,5.0,6.0,7.0,7.9]; nb=length(base_times)
PSTART=[10.0,6.0]
cf(r)=r.N0_final/max(r.N[end],1)

# monotone log-linear ramp from PSTART to a variable final depth (both beams)
function ramp_to(finalH,finalV)
    P=zeros(3,nb)
    for (b,(ps,pf)) in enumerate(((PSTART[1],finalH),(PSTART[2],finalV)))
        for i in 1:nb; f=(i-1)/(nb-1); P[b,i]=ps*(pf/ps)^f; end
    end
    FortRamp(base_times,P)
end
# sweep the final depth: hODT 0.5→0.004 W (vODT scaled proportionally), 60 fine points
finals=10 .^ range(log10(0.5),log10(0.004);length=60)
open(joinpath(OUT,"cooling.csv"),"w") do io
    println(io,"finalH,N0,T,cf")
    for fh in finals
        fv=max(0.01*fh/0.5*0.4+0.008, 0.01)   # vODT final scales gently with hODT final
        r=run_evaporation_bec(trap,ramp_to(fh,fv),p; N0=N0,T0=T0)
        @printf(io,"%.5f,%.5e,%.3f,%.4f\n",fh,r.N0_final,r.T_final*1e9,cf(r))
    end
end
d=readlines(joinpath(OUT,"cooling.csv"))[2:end]
Ts=[parse(Float64,split(l,",")[3]) for l in d]
@printf("swept %d final depths; T range %.0f–%.0f nK\n",length(d),minimum(Ts),maximum(Ts))
println("wrote cooling.csv")
