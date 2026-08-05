# Colder-BEC optimization: N₀-vs-T_final tradeoff (Pareto front).
# For each target temperature, maximize the pure-BEC condensate N₀ subject to
# T_final ≤ T_target (and cond.frac ≥ 0.95), thesis-calibrated, with the heating
# floor on. Shows how cold the BEC can be pushed and the atom-number cost. (issue #75)

using SpinorBEC
using Printf, Random
const BOHR=5.29177210903e-11; const KB=SpinorBEC.Units.KB; const HBAR=SpinorBEC.Units.HBAR
const OUT = length(ARGS)>=1 ? ARGS[1] : "cold_out"; mkpath(OUT)

alpha=5.88e-37; a_s=135*BOHR; wH=sqrt(26e-6*30e-6); wV=47e-6
N0,T0=1.4e6,50e-6; m=Eu151.mass
trap=euv3_evap_trap(; waists=[wH,wV,wV], alpha=alpha,
    directions=[(1.0,0.0,0.0),(0.0,0.0,1.0),(0.0,1.0,0.0)])
base_times=[0.0,1.0,2.0,3.0,4.0,5.0,6.0,6.7,7.4]
Pbase=permutedims(hcat([10.0,5.0,3.0,2.0,1.2,0.7,0.35,0.18,0.10],
                       [0.15,1.2,2.5,3.5,4.5,5.5,6.0,3.0,1.30],zeros(9)))
nb=length(base_times); span=base_times[end]
K3=1e-41; HEAT=0.05
p=EvapParams(; a_s=a_s, tau_bg=15.0, K3=K3, heating_rate=HEAT)
warp_times(s,γ)=[s*span*((t/span)^γ) for t in base_times]
mk(P,s,γ)=FortRamp(warp_times(s,γ),P)
run1(P,s,γ)=run_evaporation_bec(trap,mk(P,s,γ),p; N0=N0,T0=T0)

# final endpoint allowed SHALLOWER now (to reach colder T): hODT∈[0.02,0.5], vODT∈[0.05,2.0]
Pmax=[11.5,7.4]
lo(b,i)= i==nb ? (b==1 ? 0.003 : 0.01) : 0.02
hi(b,i)= i==nb ? (b==1 ? 0.50 : 2.00) : Pmax[b]
freevars=[(b,i) for b in 1:2 for i in 2:nb]
PURITY=0.95
cf(r)=r.N0_final/max(r.N[end],1)

# objective: maximize N0 s.t. cond.frac≥0.95 AND T_final ≤ Ttar (nK). Pure BEC only.
function obj(P,s,γ,Ttar)
    r=run1(P,s,γ); N0f=r.N0_final; c=cf(r); T=r.T_final*1e9
    N0f*(c>=PURITY ? 1.0 : (c/PURITY)^3)*(T<=Ttar ? 1.0 : (Ttar/max(T,1e-6))^6)
end
function descend(P0,s0,γ0,Ttar; n_line=9,n_sweeps=6)
    P=copy(P0);s=s0;γ=γ0;best=obj(P,s,γ,Ttar)
    for _ in 1:n_sweeps
        imp=false
        for (b,i) in freevars
            lb,lv=best,P[b,i]
            for v in range(lo(b,i),hi(b,i);length=n_line); P[b,i]=v; sc=obj(P,s,γ,Ttar); sc>lb&&(lb=sc;lv=v);end
            P[b,i]=lv; lb>best&&(best=lb;imp=true)
        end
        lb,lv=best,s; for v in range(0.3,3.0;length=15); sc=obj(P,v,γ,Ttar); sc>lb&&(lb=sc;lv=v);end; s=lv; lb>best&&(best=lb;imp=true)
        lb,lv=best,γ; for v in range(0.5,2.0;length=13); sc=obj(P,s,v,Ttar); sc>lb&&(lb=sc;lv=v);end; γ=lv; lb>best&&(best=lb;imp=true)
        imp||break
    end
    (P,s,γ)
end

# fine, denser near the low-T knee (warm-started from the previous, colder solution)
Ttargets=round.(reverse(10 .^ range(log10(18.0),log10(200.0);length=30)); digits=1)
open(joinpath(OUT,"pareto.csv"),"w") do io
    println(io,"T_target,N0,T_final,cond_frac,duration,warp")
    prevP,prevs,prevγ=copy(Pbase),1.0,1.0
    for Ttar in Ttargets
        P,s,γ=descend(prevP,prevs,prevγ,Ttar)          # warm-start from previous (colder) solution
        r=run1(P,s,γ)
        @printf(io,"%.0f,%.4e,%.2f,%.4f,%.2f,%.2f\n",Ttar,r.N0_final,r.T_final*1e9,cf(r),s*span,γ)
        @printf("T_target=%3.0fnK -> N0=%.3e T=%.1fnK cf=%.3f dur=%.1fs\n",Ttar,r.N0_final,r.T_final*1e9,cf(r),s*span); flush(stdout)
        prevP,prevs,prevγ=P,s,γ
    end
end
println("\n"*read(joinpath(OUT,"pareto.csv"),String))
