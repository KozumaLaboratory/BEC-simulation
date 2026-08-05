# RE-OPTIMIZATION WORKFLOW — run this once the unknown parameters are measured.
#
# Finds the balanced operating point: the ramp that maximizes the pure-BEC condensate
# N₀ subject to a temperature ceiling T_target (the "keep atoms while staying cold"
# knee of the N₀–T tradeoff, issue #75 §4.7), over a REALIZABLE ramp family.
#
# Realizability: both beams are MONOTONE NON-INCREASING (the trap is only ever lowered)
# from the loaded crossed trap — no jagged/oscillating schedules. Free: the per-beam
# drop profile + total duration + time-warp.
#
# ALL currently-unknown parameters are inputs (env vars); plug in measured values:
#   EU_HEATING [1/s] (MEASURE — sets coldest T)  EU_K3 [m⁶/s]  EU_TAUBG [s]
#   EU_TTARGET [nK] (operating point; default 50) EU_N0 EU_T0 EU_WH EU_WV EU_ALPHA
#   usage:  EU_HEATING=0.02 EU_TTARGET=40 julia --project=. eu_evaporation_reoptimize.jl OUTDIR
# NOTE (2026-08-04): `a_s = 135 a_B` below is the SUPERSEDED thesis value.
# `docs/guides/eu_evaporation_calibration.md:37` records the refinement —
# "a_s = 135 a_B (thesis) -> 110(4) a_B (PRL refined)" — and the atom registry
# ships 110 (`initialization/atoms.jl:198`, Matsui et al. Science 2026). Every
# number this script produced was computed at 135, so its outputs are of that
# vintage; a_s enters the elastic rate linearly and the collision rate as a_s^2,
# so the difference is not cosmetic. Left as it stands rather than silently
# re-run: re-running changes published-adjacent numbers and is a decision, not
# a doc fix.

using SpinorBEC
using Printf, Random
const BOHR=5.29177210903e-11
envf(k,d)=haskey(ENV,k) ? parse(Float64,ENV[k]) : d
const OUT = length(ARGS)>=1 ? ARGS[1] : "reopt_out"; mkpath(OUT)

HEATING=envf("EU_HEATING",0.05); K3=envf("EU_K3",1e-42); TAUBG=envf("EU_TAUBG",15.0)
TTARGET=envf("EU_TTARGET",50.0); N0=envf("EU_N0",1.4e6); T0=envf("EU_T0",50e-6)
wH=envf("EU_WH",sqrt(26e-6*30e-6)); wV=envf("EU_WV",47e-6); alpha=envf("EU_ALPHA",5.88e-37)
a_s=135*BOHR; m=Eu151.mass
@printf("INPUTS: heating=%.3f/s K3=%.1e tau_bg=%.0fs T_target=%.0fnK N0=%.2e T0=%.0fµK\n",HEATING,K3,TAUBG,TTARGET,N0,T0*1e6)

trap=euv3_evap_trap(; waists=[wH,wV,wV], alpha=alpha,
    directions=[(1.0,0.0,0.0),(0.0,0.0,1.0),(0.0,1.0,0.0)])
# 9 breakpoints; loaded crossed trap start (both beams high), monotone lowered
base_times=[0.0,1.0,2.0,3.0,4.0,5.0,6.0,6.7,7.4]
nb=length(base_times); span=base_times[end]
PSTART=[10.0, 6.0]                      # loaded crossed-trap powers (hODT, vODT) [W]
PENDLO=[0.02, 0.05]                     # shallowest physical final
p=EvapParams(; a_s=a_s, tau_bg=TAUBG, K3=K3, heating_rate=HEATING)
warp_times(s,γ)=[s*span*((t/span)^γ) for t in base_times]
function mk(P,s,γ); pw=zeros(3,nb); pw[1:2,:]=P; FortRamp(warp_times(s,γ),pw); end
run1(P,s,γ)=run_evaporation_bec(trap,mk(P,s,γ),p; N0=N0,T0=T0)
PURITY=0.95; cf(r)=r.N0_final/max(r.N[end],1)
function obj(P,s,γ)
    r=run1(P,s,γ); N0f=r.N0_final; c=cf(r); T=r.T_final*1e9
    N0f*(c>=PURITY ? 1.0 : (c/PURITY)^3)*(T<=TTARGET ? 1.0 : (TTARGET/max(T,1e-6))^4)
end

# monotone init: log-linear from PSTART to a mid final
function init_mono()
    P=zeros(2,nb)
    for b in 1:2, i in 1:nb
        f=(i-1)/(nb-1); P[b,i]=PSTART[b]*((0.1*PSTART[b])/PSTART[b])^f
    end
    P
end
# coordinate descent keeping BOTH beams monotone non-increasing (search each breakpoint
# between its neighbors) + free duration/warp
function descend(P0,s0,γ0; n_line=13,n_sweeps=8)
    P=copy(P0);s=s0;γ=γ0;best=obj(P,s,γ)
    for _ in 1:n_sweeps
        imp=false
        for b in 1:2, i in 2:nb
            hi = P[b,i-1]                        # ≤ previous (monotone)
            lo = i<nb ? P[b,i+1] : PENDLO[b]     # ≥ next (monotone); final floor
            hi<=lo && continue
            lb,lv=best,P[b,i]
            for v in range(lo,hi;length=n_line); P[b,i]=v; sc=obj(P,s,γ); sc>lb&&(lb=sc;lv=v);end
            P[b,i]=lv; lb>best&&(best=lb;imp=true)
        end
        lb,lv=best,s; for v in range(0.3,3.0;length=17); sc=obj(P,v,γ); sc>lb&&(lb=sc;lv=v);end; s=lv; lb>best&&(best=lb;imp=true)
        lb,lv=best,γ; for v in range(0.5,2.0;length=15); sc=obj(P,s,v); sc>lb&&(lb=sc;lv=v);end; γ=lv; lb>best&&(best=lb;imp=true)
        imp||break
    end
    (P,s,γ)
end
bP,bs,bγ=descend(init_mono(),1.0,1.0); best=obj(bP,bs,bγ)
rng=MersenneTwister(1)
for _ in 1:4
    # random monotone start
    P=zeros(2,nb)
    for b in 1:2
        fr=sort(rand(rng,nb-1);rev=true); P[b,1]=PSTART[b]
        for i in 2:nb; P[b,i]=max(PENDLO[b], PSTART[b]*prod(fr[1:i-1])); end
    end
    Pf,sf,γf=descend(P,0.3+rand(rng)*2.7,0.5+rand(rng)*1.5); sc=obj(Pf,sf,γf)
    sc>best&&(global best=sc;global bP=Pf;global bs=sf;global bγ=γf)
end

r=run1(bP,bs,bγ); tt=warp_times(bs,bγ)
open(joinpath(OUT,"operating_point.txt"),"w") do io
    @printf(io,"=== CONFIRMED OPERATING POINT (realizable monotone ramp; max N0 s.t. T<=%.0fnK) ===\n",TTARGET)
    @printf(io,"predicted: N0=%.3e  T_final=%.1f nK  cond_frac=%.3f  duration=%.2f s\n",r.N0_final,r.T_final*1e9,cf(r),bs*span)
    @printf(io,"inputs: heating=%.3f/s K3=%.1e tau_bg=%.0fs (MEASURE heating & K3 to firm up)\n",HEATING,K3,TAUBG)
    @printf(io,"\nramp schedule (time[s], HFORT[W], VFORT[W]) — monotone, %d breakpoints:\n",nb)
    for i in 1:nb; @printf(io,"  %5.3f  %8.4f  %8.4f\n",tt[i],bP[1,i],bP[2,i]); end
end
open(joinpath(OUT,"bec_opt.csv"),"w") do io
    println(io,"t,N,N0,Nth,T,eta")
    for i in eachindex(r.t); @printf(io,"%.6e,%.6e,%.6e,%.6e,%.6e,%.6e\n",r.t[i],r.N[i],r.N0[i],r.Nth[i],r.T[i],r.eta[i]); end
end
ramp=mk(bP,bs,bγ); ts=range(tt[1],tt[end];length=400)
open(joinpath(OUT,"ramp_opt.csv"),"w") do io
    println(io,"t,HFORT,VFORT,SFORT")
    for t in ts; pw=fort_power_at(ramp,Float64(t)); @printf(io,"%.6e,%.6e,%.6e,%.6e\n",t,pw[1],pw[2],pw[3]); end
end
println("\n"*read(joinpath(OUT,"operating_point.txt"),String))
