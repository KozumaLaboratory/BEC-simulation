# Multi-start global optimization of the Eu evaporation ramp (issue #75).
# Runs coordinate descent from MANY independent random starts; if they converge to the
# same optimum, it is (near-)global — not a local trap. Returns the best SMOOTH ramp
# (dense monotone breakpoints) + the distribution of local optima as the evidence. K₃=1e-41.

using SpinorBEC
using Printf, Random
const BOHR=5.29177210903e-11
const OUT=length(ARGS)>=1 ? ARGS[1] : "ms_out"; mkpath(OUT)
const NSTART=length(ARGS)>=2 ? parse(Int,ARGS[2]) : 80
alpha=5.88e-37; a_s=135*BOHR; wH=sqrt(26e-6*30e-6); wV=47e-6; N0=1.4e6; T0=50e-6
trap=euv3_evap_trap(; waists=[wH,wV,wV], alpha=alpha,
    directions=[(1.0,0.0,0.0),(0.0,0.0,1.0),(0.0,1.0,0.0)])
p=EvapParams(; a_s=a_s, tau_bg=15.0, K3=1e-41, heating_rate=0.05)
cf(r)=r.N0_final/max(r.N[end],1)
const NB=13; const SPAN=7.4; const PSTART=[10.0,6.0]; const PENDLO=[0.02,0.05]
const TTARGET=50.0; const PURITY=0.95
base_t=collect(range(0.0,SPAN;length=NB))
warp_t(s,γ)=[s*SPAN*((t/SPAN)^γ) for t in base_t]
function mono_ramp(P,s,γ); pw=zeros(3,NB); pw[1:2,:]=P; FortRamp(warp_t(s,γ),pw); end
run1(P,s,γ)=run_evaporation_bec(trap,mono_ramp(P,s,γ),p; N0=N0,T0=T0)
function obj(P,s,γ)
    r=run1(P,s,γ); N0f=r.N0_final; c=cf(r); T=r.T_final*1e9
    N0f*(c>=PURITY ? 1.0 : (c/PURITY)^3)*(T<=TTARGET ? 1.0 : (TTARGET/max(T,1e-6))^6)
end
lo(b,i)= i<NB ? 0.0 : 0.0
hi(b,i)= P->P[b,i-1]   # monotone: ≤ previous
# coordinate descent keeping both beams monotone non-increasing
function descend(P0,s0,γ0; n_line=9,n_sweeps=6)
    P=copy(P0);s=s0;γ=γ0;best=obj(P,s,γ)
    for _ in 1:n_sweeps
        imp=false
        for b in 1:2, i in 2:NB
            hiv=P[b,i-1]; lov=i<NB ? P[b,i+1] : PENDLO[b]
            hiv<=lov && continue
            lb,lv=best,P[b,i]
            for v in range(lov,hiv;length=n_line); P[b,i]=v; sc=obj(P,s,γ); sc>lb&&(lb=sc;lv=v);end
            P[b,i]=lv; lb>best&&(best=lb;imp=true)
        end
        lb,lv=best,s; for v in range(0.3,3.0;length=17); sc=obj(P,v,γ); sc>lb&&(lb=sc;lv=v);end; s=lv; lb>best&&(best=lb;imp=true)
        lb,lv=best,γ; for v in range(0.5,2.0;length=15); sc=obj(P,s,v); sc>lb&&(lb=sc;lv=v);end; γ=lv; lb>best&&(best=lb;imp=true)
        imp||break
    end
    (P,s,γ,best)
end
function rand_mono(rng)
    P=zeros(2,NB)
    for b in 1:2
        fr=sort(rand(rng,NB-1);rev=true); P[b,1]=PSTART[b]
        for i in 2:NB; P[b,i]=max(PENDLO[b], PSTART[b]*prod(fr[1:i-1])); end
    end
    P
end

rng=MersenneTwister(1); scores=Float64[]; bestP=nothing; bests=1.0; bestγ=1.0; bestsc=-Inf
t0=time()
for k in 1:NSTART
    P0=k==1 ? begin  # one physical warm start (log-linear) + rest random
            Q=zeros(2,NB); for b in 1:2,i in 1:NB; f=(i-1)/(NB-1); Q[b,i]=PSTART[b]*((0.1*PSTART[b])/PSTART[b])^f; end; Q
        end : rand_mono(rng)
    s0=k==1 ? 1.0 : 0.3+rand(rng)*2.7; γ0=k==1 ? 1.0 : 0.5+rand(rng)*1.5
    P,s,γ,sc=descend(P0,s0,γ0)
    push!(scores,sc)
    if sc>bestsc; global bestsc=sc; global bestP=P; global bests=s; global bestγ=γ; end
    k%10==0 && (@printf("%d/%d starts, best=%.3e\n",k,NSTART,bestsc); flush(stdout))
end
r=run1(bestP,bests,bestγ)
@printf("\n=== MULTISTART GLOBAL (%d starts, %.0fs) ===\n",NSTART,time()-t0)
@printf("BEST: N0=%.4e T=%.1fnK cf=%.3f dur=%.2fs\n",r.N0_final,r.T_final*1e9,cf(r),bests*SPAN)
sc=sort(scores;rev=true)
@printf("top-5 local optima: %s\n", join([@sprintf("%.3e",x) for x in sc[1:min(5,end)]],", "))
@printf("%% of starts within 5%% of best: %.0f%%\n", 100*count(x->x>=0.95*bestsc,scores)/NSTART)
open(joinpath(OUT,"scores.csv"),"w") do io; println(io,"score"); for x in scores; @printf(io,"%.5e\n",x); end; end
# dump best smooth ramp + trajectory
tt=warp_t(bests,bestγ); P=mono_ramp(bestP,bests,bestγ).powers_W
open(joinpath(OUT,"operating_point.txt"),"w") do io
    @printf(io,"MULTISTART-GLOBAL operating point, K3=1e-41, T<=%.0fnK, %d starts\n",TTARGET,NSTART)
    @printf(io,"N0=%.4e T_final=%.1fnK cond_frac=%.3f duration=%.2fs\n",r.N0_final,r.T_final*1e9,cf(r),bests*SPAN)
    println(io,"\nbreakpoints (t[s], hODT[W], vODT[W]):")
    for i in 1:NB; @printf(io,"  %6.3f  %8.4f  %8.4f\n",tt[i],P[1,i],P[2,i]); end
end
open(joinpath(OUT,"bec_opt.csv"),"w") do io
    println(io,"t,N,N0,Nth,T,eta")
    for i in eachindex(r.t); @printf(io,"%.6e,%.6e,%.6e,%.6e,%.6e,%.6e\n",r.t[i],r.N[i],r.N0[i],r.Nth[i],r.T[i],r.eta[i]); end
end
tsg=range(tt[1],tt[end];length=600)
open(joinpath(OUT,"ramp_opt.csv"),"w") do io
    println(io,"t,HFORT,VFORT,SFORT")
    for t in tsg; pw=fort_power_at(mono_ramp(bestP,bests,bestγ),Float64(t)); @printf(io,"%.6e,%.6e,%.6e,%.6e\n",t,pw[1],pw[2],pw[3]); end
end
println(read(joinpath(OUT,"operating_point.txt"),String))
