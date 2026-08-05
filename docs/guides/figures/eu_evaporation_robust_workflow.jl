# Distributionally-robust ¹⁵¹Eu evaporation-ramp optimization.
#
# Optimizes the FULL ramp — per-beam powers AND the time axis (total duration scale
# `s` + warp exponent `γ`) — to maximize the WORST-CASE pure-BEC condensate number
# over an uncertainty ensemble of the unmeasured parameters (K₃, τ_bg). The result
# is a schedule that produces a large, fully-condensed BEC across the whole
# uncertainty set, not one tuned to a single (unknown) parameter point.
#
# Calibration: Miyazawa 2021 thesis (α_s=189 a.u.→5.88e-37, a_s=135 a_B, wH=27.9µm,
# wV=47µm, N0=1.4e6 @ 50µK). Unknowns swept: K₃ (order 1e-42, ±factor few),
# τ_bg (unmeasured, 10–30 s). See issue #75.

using SpinorBEC
using Printf, Random
const BOHR = 5.29177210903e-11
const OUT = length(ARGS) >= 1 ? ARGS[1] : "robust_out"; mkpath(OUT)

# ---- calibrated (STABLE + 2021 EPOCH) ----
alpha=5.88e-37; a_s=135*BOHR; wH=sqrt(26e-6*30e-6); wV=47e-6
N0,T0 = 1.4e6, 50e-6
trap = euv3_evap_trap(; waists=[wH,wV,wV], alpha=alpha,
    directions=[(1.0,0.0,0.0),(0.0,0.0,1.0),(0.0,1.0,0.0)])
base_times = [0.0,1.0,2.0,3.0,4.0,5.0,6.0,6.7,7.4]
Pbase = permutedims(hcat([10.0,5.0,3.0,2.0,1.2,0.7,0.35,0.18,0.10],
                         [0.15,1.2,2.5,3.5,4.5,5.5,6.0,3.0,1.30], zeros(9)))
nb=length(base_times); span=base_times[end]

# ---- uncertainty ensemble (the axes that move the optimal ramp shape) ----
ENSEMBLE = [(K3, tau) for K3 in (1e-42, 1e-41) for tau in (10.0, 30.0)]
NOMINAL  = (1e-42, 15.0)
pf(K3,tau)=EvapParams(; a_s=a_s, tau_bg=tau, K3=K3)

warp_times(s,γ) = [s*span*((t/span)^γ) for t in base_times]
mk(P,s,γ)=FortRamp(warp_times(s,γ), P)
run1(P,s,γ,K3,tau)=run_evaporation_bec(trap,mk(P,s,γ),pf(K3,tau); N0=N0,T0=T0)

Pmax=[11.5,7.4]
lo(b,i)= i==nb ? (b==1 ? 0.05 : 0.20) : 0.02
hi(b,i)= i==nb ? (b==1 ? 0.50 : 2.00) : Pmax[b]
freevars=[(b,i) for b in 1:2 for i in 2:nb]
PURITY=0.95

# pure-BEC-penalized condensate number for ONE (K3,τ_bg)
function pureN0(P,s,γ,K3,tau)
    r=run1(P,s,γ,K3,tau); N0f=r.N0_final; cf=N0f/max(r.N[end],1)
    cf>=PURITY ? N0f : N0f*(cf/PURITY)^3
end
# ROBUST objective: worst-case over the ensemble
robust(P,s,γ)=minimum(pureN0(P,s,γ,K3,tau) for (K3,tau) in ENSEMBLE)

function descend(P0,s0,γ0,obj; n_line=9, n_sweeps=6)
    P=copy(P0); s=s0; γ=γ0; best=obj(P,s,γ)
    for _ in 1:n_sweeps
        improved=false
        for (b,i) in freevars
            lb,lv=best,P[b,i]
            for v in range(lo(b,i),hi(b,i);length=n_line)
                P[b,i]=v; sc=obj(P,s,γ); sc>lb && (lb=sc; lv=v)
            end
            P[b,i]=lv; lb>best && (best=lb; improved=true)
        end
        lb,lv=best,s
        for v in range(0.3,3.0;length=15); sc=obj(P,v,γ); sc>lb && (lb=sc; lv=v); end
        s=lv; lb>best && (best=lb; improved=true)
        lb,lv=best,γ
        for v in range(0.5,2.0;length=13); sc=obj(P,s,v); sc>lb && (lb=sc; lv=v); end
        γ=lv; lb>best && (best=lb; improved=true)
        improved || break
    end
    (P,s,γ,best)
end

function optimize(obj; restarts=2, seed=1)
    bP,bs,bγ,bsc = descend(copy(Pbase),1.0,1.0,obj)
    rng=MersenneTwister(seed)
    for _ in 1:restarts
        P=copy(Pbase)
        for (b,i) in freevars; P[b,i]=lo(b,i)+rand(rng)*(hi(b,i)-lo(b,i)); end
        Pf,sf,γf,sc=descend(P,0.3+rand(rng)*2.7,0.5+rand(rng)*1.5,obj)
        sc>bsc && (bsc=sc; bP=Pf; bs=sf; bγ=γf)
    end
    (bP,bs,bγ)
end

log_(x)=(println(x); flush(stdout))
log_("optimizing ROBUST (worst-case over $(length(ENSEMBLE)) members)...")
rP,rs,rγ = optimize(robust)
log_("optimizing NOMINAL (K3=1e-42, τ_bg=15) for comparison...")
nP,ns,nγ = optimize((P,s,γ)->pureN0(P,s,γ,NOMINAL...))

cf(r)=r.N0_final/max(r.N[end],1)
# full-ensemble evaluation table
function eval_table(name,P,s,γ)
    log_("=== $name ramp (duration=$(round(s*span;digits=1))s, warp=$(round(γ;digits=2))) ===")
    for (K3,tau) in vcat(ENSEMBLE,[NOMINAL])
        r=run1(P,s,γ,K3,tau)
        @printf("  K3=%.0e τbg=%4.0f : N0=%.3e T=%3.0fnK cf=%.3f\n",K3,tau,r.N0_final,r.T_final*1e9,cf(r))
    end
end
eval_table("ROBUST",rP,rs,rγ); eval_table("NOMINAL",nP,ns,nγ)

# ---- robustness grid: N0/T over a FINE (K3 × τ_bg) grid for each ramp ----
grid_K3  = [1e-42, 3e-42, 1e-41, 3e-41, 1e-40]
grid_tau = [10.0, 15.0, 30.0]
open(joinpath(OUT,"robustness_grid.csv"),"w") do io
    println(io,"ramp,K3,tau,N0,T,cf")
    for (name,P,s,γ) in (("lab",Pbase,1.0,1.0),("nominal",nP,ns,nγ),("robust",rP,rs,rγ))
        for K3 in grid_K3, tau in grid_tau
            r=run1(P,s,γ,K3,tau)
            @printf(io,"%s,%.3e,%.1f,%.6e,%.6e,%.4f\n",name,K3,tau,r.N0_final,r.T_final*1e9,cf(r))
        end
    end
end

# worst-case comparison (the headline)
wc_robust=robust(rP,rs,rγ); wc_nominal=robust(nP,ns,nγ)
lab_wc=robust(Pbase,1.0,1.0)
open(joinpath(OUT,"robust_summary.txt"),"w") do io
    @printf(io,"ROBUST EVAPORATION WORKFLOW (thesis-calibrated). Ensemble: K3∈{1e-42,1e-41}×τbg∈{10,30}\n")
    @printf(io,"Objective = worst-case pure-BEC N0 over the ensemble.\n\n")
    @printf(io,"worst-case pure-BEC N0:\n")
    @printf(io,"  lab thesis ramp   : %.3e\n", lab_wc)
    @printf(io,"  NOMINAL-opt ramp  : %.3e  (worst-case; tuned only to K3=1e-42)\n", wc_nominal)
    @printf(io,"  ROBUST-opt ramp   : %.3e  (%.1fx lab worst-case)\n", wc_robust, wc_robust/max(lab_wc,1))
    rn=run1(rP,rs,rγ,NOMINAL...)
    @printf(io,"\nROBUST ramp at nominal (K3=1e-42,τ15): N0=%.3e T=%.0fnK cf=%.3f dur=%.1fs warp=%.2f\n",
        rn.N0_final, rn.T_final*1e9, cf(rn), rs*span, rγ)
end
# dump robust + lab trajectories/ramps at nominal for plotting
rlab=run1(Pbase,1.0,1.0,NOMINAL...); ropt=run1(rP,rs,rγ,NOMINAL...)
function dump(r,name); open(joinpath(OUT,"bec_$name.csv"),"w") do io
    println(io,"t,N,N0,Nth,T,eta")
    for i in eachindex(r.t); @printf(io,"%.6e,%.6e,%.6e,%.6e,%.6e,%.6e\n",r.t[i],r.N[i],r.N0[i],r.Nth[i],r.T[i],r.eta[i]); end
end; end
dump(rlab,"lab"); dump(ropt,"opt")
for (P,s,γ,nm) in ((Pbase,1.0,1.0,"lab"),(rP,rs,rγ,"opt"))
    ts=warp_times(s,γ); tt=range(ts[1],ts[end];length=400); rmp=mk(P,s,γ)
    open(joinpath(OUT,"ramp_$nm.csv"),"w") do io
        println(io,"t,HFORT,VFORT,SFORT")
        for t in tt; pw=fort_power_at(rmp,Float64(t)); @printf(io,"%.6e,%.6e,%.6e,%.6e\n",t,pw[1],pw[2],pw[3]); end
    end
end
println("\n"*read(joinpath(OUT,"robust_summary.txt"),String))
