# Smooth N₀-vs-T tradeoff for the Eu evaporation (issue #75). A SMOOTH monotone base ramp
# (log-linear hODT + smoothly-lowered vODT) with the final trap depth swept finely (150
# points) → a clean continuous curve. K₃ = 1e-41, heating = 0.05 (nominal).

using SpinorBEC
using Printf
const BOHR=5.29177210903e-11
const OUT=length(ARGS)>=1 ? ARGS[1] : "tr_out"; mkpath(OUT)
alpha=5.88e-37; a_s=135*BOHR; wH=sqrt(26e-6*30e-6); wV=47e-6; N0=1.4e6; T0=50e-6
trap=euv3_evap_trap(; waists=[wH,wV,wV], alpha=alpha,
    directions=[(1.0,0.0,0.0),(0.0,0.0,1.0),(0.0,1.0,0.0)])
p=EvapParams(; a_s=a_s, tau_bg=15.0, K3=1e-41, heating_rate=0.05)
cf(r)=r.N0_final/max(r.N[end],1)

# SMOOTH monotone base ramp: dense breakpoints on a log-linear decay to a variable final
NB=41; SPAN=2.2; PST=[10.0,6.0]
times=collect(range(0.0,SPAN;length=NB))
function ramp_to(fH,fV)                       # log-linear from PST to (fH,fV), smooth
    P=zeros(3,NB)
    for (b,pf) in ((1,fH),(2,fV))
        for i in 1:NB; f=(i-1)/(NB-1); P[b,i]=PST[b]*(pf/PST[b])^f; end
    end
    FortRamp(times,P)
end

finals=10 .^ range(log10(0.6),log10(2e-4);length=220)    # final hODT depth, fine, down to ~0
open(joinpath(OUT,"tradeoff.csv"),"w") do io
    println(io,"finalH,N0,T,cf")
    for fH in finals
        fV=max(0.06*fH,0.01)                  # vODT final scales with hODT final
        r=run_evaporation_bec(trap,ramp_to(fH,fV),p; N0=N0,T0=T0)
        @printf(io,"%.6f,%.5e,%.3f,%.4f\n",fH,r.N0_final,r.T_final*1e9,cf(r))
    end
end
d=readlines(joinpath(OUT,"tradeoff.csv"))[2:end]
Ts=[parse(Float64,split(l,",")[3]) for l in d]
@printf("%d points; T %.0f–%.0f nK\n",length(d),minimum(Ts),maximum(Ts))
