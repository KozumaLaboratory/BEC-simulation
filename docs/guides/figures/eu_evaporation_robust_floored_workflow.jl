# Distributionally-robust Eu evaporation optimization WITH PHYSICAL FLOORS.
#
# Adds the two floors missing from the bare 0-D model, which the unconstrained
# optimizer was exploiting (issue #75 §4.5):
#   (1) HEATING floor  — technical/photon heating `heating_rate` (dT/T per s); without
#       it deep evaporation runs to T→0. Banded (unknown) in the ensemble.
#   (2) RETHERMALIZATION floor — evaporative cooling needs collisions. A ramp is
#       feasible only if the collisions-per-atom over the whole ramp, ∫γ_el dt with
#       γ_el = n_pk σ v̄, exceeds N_COLL_MIN. This kills the unphysical "arbitrarily
#       fast" ramps that hit the duration lower bound.
#
# Optimizes powers + duration s + warp γ for the worst-case pure-BEC N₀ over the
# unknown-parameter ensemble (K₃, heating), subject to the rethermalization floor.

using SpinorBEC
using Printf, Random
const BOHR=5.29177210903e-11; const KB=SpinorBEC.Units.KB; const HBAR=SpinorBEC.Units.HBAR
const OUT = length(ARGS)>=1 ? ARGS[1] : "robust_floored_out"; mkpath(OUT)

alpha=5.88e-37; a_s=135*BOHR; wH=sqrt(26e-6*30e-6); wV=47e-6
N0,T0=1.4e6,50e-6; m=Eu151.mass
trap=euv3_evap_trap(; waists=[wH,wV,wV], alpha=alpha,
    directions=[(1.0,0.0,0.0),(0.0,0.0,1.0),(0.0,1.0,0.0)])
base_times=[0.0,1.0,2.0,3.0,4.0,5.0,6.0,6.7,7.4]
Pbase=permutedims(hcat([10.0,5.0,3.0,2.0,1.2,0.7,0.35,0.18,0.10],
                       [0.15,1.2,2.5,3.5,4.5,5.5,6.0,3.0,1.30],zeros(9)))
nb=length(base_times); span=base_times[end]

# floors
N_COLL_MIN = 150.0          # min collisions-per-atom for valid evaporative cooling
# ensemble over the two unknown floors/loss params
ENSEMBLE=[(K3,heat) for K3 in (1e-42,1e-41) for heat in (0.02,0.10)]
NOMINAL=(1e-42,0.05)
pf(K3,heat)=EvapParams(; a_s=a_s, tau_bg=15.0, K3=K3, heating_rate=heat)

warp_times(s,γ)=[s*span*((t/span)^γ) for t in base_times]
mk(P,s,γ)=FortRamp(warp_times(s,γ),P)
run1(P,s,γ,K3,heat)=run_evaporation_bec(trap,mk(P,s,γ),pf(K3,heat); N0=N0,T0=T0)

# collisions-per-atom over the ramp (rethermalization budget), recomputing ω̄(t)
function collisions(P,s,γ)
    r=run1(P,s,γ,NOMINAL...); ramp=mk(P,s,γ); tot=0.0
    for i in 2:length(r.t)
        T=r.T[i]; N=r.N[i]; (T<=0||N<=0) && continue
        _,ω=SpinorBEC._trap_at_time(trap,ramp,r.t[i])
        n=thermal_peak_density(N,T,ω,m)
        k2a2=2*m*KB*T/HBAR^2*a_s^2; σ=8π*a_s^2/(1+k2a2); v̄=sqrt(8*KB*T/(π*m))
        tot += n*σ*v̄*(r.t[i]-r.t[i-1])
    end
    tot
end

Pmax=[11.5,7.4]
lo(b,i)= i==nb ? (b==1 ? 0.05 : 0.20) : 0.02
hi(b,i)= i==nb ? (b==1 ? 0.50 : 2.00) : Pmax[b]
freevars=[(b,i) for b in 1:2 for i in 2:nb]
PURITY=0.95
function pureN0(P,s,γ,K3,heat)
    r=run1(P,s,γ,K3,heat); N0f=r.N0_final; cf=N0f/max(r.N[end],1)
    cf>=PURITY ? N0f : N0f*(cf/PURITY)^3
end
# robust objective WITH rethermalization feasibility floor
function robust(P,s,γ)
    nc=collisions(P,s,γ)
    feas = nc>=N_COLL_MIN ? 1.0 : (nc/N_COLL_MIN)^4        # smooth penalty below the floor
    feas*minimum(pureN0(P,s,γ,K3,heat) for (K3,heat) in ENSEMBLE)
end

function descend(P0,s0,γ0,obj; n_line=9,n_sweeps=6)
    P=copy(P0);s=s0;γ=γ0;best=obj(P,s,γ)
    for _ in 1:n_sweeps
        imp=false
        for (b,i) in freevars
            lb,lv=best,P[b,i]
            for v in range(lo(b,i),hi(b,i);length=n_line); P[b,i]=v; sc=obj(P,s,γ); sc>lb&&(lb=sc;lv=v); end
            P[b,i]=lv; lb>best&&(best=lb;imp=true)
        end
        lb,lv=best,s
        for v in range(0.3,3.0;length=15); sc=obj(P,v,γ); sc>lb&&(lb=sc;lv=v); end
        s=lv; lb>best&&(best=lb;imp=true)
        lb,lv=best,γ
        for v in range(0.5,2.0;length=13); sc=obj(P,s,v); sc>lb&&(lb=sc;lv=v); end
        γ=lv; lb>best&&(best=lb;imp=true)
        imp || break
    end
    (P,s,γ,best)
end
function optimize(obj; restarts=2, seed=1)
    bP,bs,bγ,bsc=descend(copy(Pbase),1.0,1.0,obj)
    rng=MersenneTwister(seed)
    for _ in 1:restarts
        P=copy(Pbase)
        for (b,i) in freevars; P[b,i]=lo(b,i)+rand(rng)*(hi(b,i)-lo(b,i)); end
        Pf,sf,γf,sc=descend(P,0.3+rand(rng)*2.7,0.5+rand(rng)*1.5,obj)
        sc>bsc&&(bsc=sc;bP=Pf;bs=sf;bγ=γf)
    end
    (bP,bs,bγ)
end

println("optimizing ROBUST+FLOORS..."); flush(stdout)
rP,rs,rγ=optimize(robust)
cf(r)=r.N0_final/max(r.N[end],1)
# grid over K3 × heat for lab / robust
grid_K3=[1e-42,3e-42,1e-41,3e-41,1e-40]; grid_heat=[0.02,0.05,0.10]
open(joinpath(OUT,"robustness_grid.csv"),"w") do io
    println(io,"ramp,K3,heat,N0,T,cf")
    for (name,P,s,γ) in (("lab",Pbase,1.0,1.0),("robust",rP,rs,rγ))
        for K3 in grid_K3, heat in grid_heat
            r=run1(P,s,γ,K3,heat)
            @printf(io,"%s,%.3e,%.3f,%.6e,%.6e,%.4f\n",name,K3,heat,r.N0_final,r.T_final*1e9,cf(r))
        end
    end
end
rl=run1(Pbase,1.0,1.0,NOMINAL...); ro=run1(rP,rs,rγ,NOMINAL...)
function dump(r,nm); open(joinpath(OUT,"bec_$nm.csv"),"w") do io
    println(io,"t,N,N0,Nth,T,eta"); for i in eachindex(r.t); @printf(io,"%.6e,%.6e,%.6e,%.6e,%.6e,%.6e\n",r.t[i],r.N[i],r.N0[i],r.Nth[i],r.T[i],r.eta[i]); end
end; end
dump(rl,"lab"); dump(ro,"opt")
for (P,s,γ,nm) in ((Pbase,1.0,1.0,"lab"),(rP,rs,rγ,"opt"))
    ts=warp_times(s,γ);tt=range(ts[1],ts[end];length=400);rmp=mk(P,s,γ)
    open(joinpath(OUT,"ramp_$nm.csv"),"w") do io
        println(io,"t,HFORT,VFORT,SFORT"); for t in tt; pw=fort_power_at(rmp,Float64(t)); @printf(io,"%.6e,%.6e,%.6e,%.6e\n",t,pw[1],pw[2],pw[3]); end
    end
end
open(joinpath(OUT,"summary.txt"),"w") do io
    @printf(io,"ROBUST+FLOORS (heating band {0.02,0.1}/s, rethermalization floor N_coll>=%.0f)\n",N_COLL_MIN)
    @printf(io,"collisions-per-atom: lab=%.0f  robust=%.0f\n",collisions(Pbase,1.0,1.0),collisions(rP,rs,rγ))
    @printf(io,"robust ramp: duration=%.1fs warp=%.2f\n",rs*span,rγ)
    @printf(io,"at nominal (K3=1e-42,heat=0.05): lab N0=%.3e T=%.0fnK cf=%.3f | robust N0=%.3e T=%.0fnK cf=%.3f\n",
        rl.N0_final,rl.T_final*1e9,cf(rl),ro.N0_final,ro.T_final*1e9,cf(ro))
    @printf(io,"factor=%.2fx\n",ro.N0_final/rl.N0_final)
end
println("\n"*read(joinpath(OUT,"summary.txt"),String))
