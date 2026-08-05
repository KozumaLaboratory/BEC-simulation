using SpinorBEC
using Printf, Random
const BOHR = 5.29177210903e-11
const OUT = ARGS[1]; mkpath(OUT)

# thesis-calibrated params
alpha=5.88e-37; a_s=135*BOHR; wH=sqrt(26e-6*30e-6); wV=47e-6
N0,T0 = 1.4e6, 50e-6
trap = euv3_evap_trap(; waists=[wH,wV,wV], alpha=alpha,
    directions=[(1.0,0.0,0.0),(0.0,0.0,1.0),(0.0,1.0,0.0)])
times = [0.0,1.0,2.0,3.0,4.0,5.0,6.0,6.7,7.4]
hODT  = [10.0,5.0,3.0,2.0,1.2,0.7,0.35,0.18,0.10]
vODT  = [0.15,1.2,2.5,3.5,4.5,5.5,6.0,3.0,1.30]
base  = FortRamp(times, permutedims(hcat(hODT,vODT,zeros(9))))
nb = length(times)
K3nom = 1e-42
pf(K3)=EvapParams(; a_s=a_s, tau_bg=15.0, K3=K3)
run_(ramp,K3)=run_evaporation_bec(trap,ramp,pf(K3); N0=N0,T0=T0)

# free variables: interior breakpoints 2..nb-1 (both beams) in [0.02,Pmax]
#   + final breakpoint nb bounded to a physical shallow trap (no trap-off exploit)
Pmax=[11.5,7.4]
lo(b,i)= i==nb ? (b==1 ? 0.05 : 0.20) : 0.02
hi(b,i)= i==nb ? (b==1 ? 0.50 : 2.00) : Pmax[b]
freevars=[(b,i) for b in 1:2 for i in 2:nb]     # includes final, START fixed
mk(P)=FortRamp(times,P)
PURITY=0.95
function score(P)
    r=run_(mk(P),K3nom)
    N0f=r.N0_final; cf=N0f/max(r.N[end],1)
    cf>=PURITY ? N0f : N0f*(cf/PURITY)^3          # penalize non-pure endpoints
end
function descend(P0; n_line=15, n_sweeps=8)
    P=copy(P0); best=score(P)
    for _ in 1:n_sweeps
        improved=false
        for (b,i) in freevars
            lb,lv=best,P[b,i]
            for v in range(lo(b,i),hi(b,i);length=n_line)
                P[b,i]=v; sc=score(P)
                sc>lb && (lb=sc; lv=v)
            end
            P[b,i]=lv
            lb>best && (best=lb; improved=true)
        end
        improved || break
    end
    (P,best)
end
bestP,bestsc=descend(copy(base.powers_W))
rng=MersenneTwister(1)
for _ in 1:4
    P=copy(base.powers_W)
    for (b,i) in freevars; P[b,i]=lo(b,i)+rand(rng)*(hi(b,i)-lo(b,i)); end
    Pf,sc=descend(P)
    sc>bestsc && (global bestsc=sc; global bestP=Pf)
end
opt=mk(bestP)

# report base + opt across K3 band
band=[1e-42,3e-42,1e-41]
rb=run_(base,K3nom); ro=run_(opt,K3nom)
cf(r)=r.N0_final/max(r.N[end],1)
function dump(r,name)
    open(joinpath(OUT,"bec_$name.csv"),"w") do io
        println(io,"t,N,N0,Nth,T,eta")
        for i in eachindex(r.t); @printf(io,"%.6e,%.6e,%.6e,%.6e,%.6e,%.6e\n",r.t[i],r.N[i],r.N0[i],r.Nth[i],r.T[i],r.eta[i]); end
    end
end
dump(rb,"lab"); dump(ro,"opt")
for (rmp,nm) in ((base,"lab"),(opt,"opt"))
    tt=range(times[1],times[end];length=400)
    open(joinpath(OUT,"ramp_$nm.csv"),"w") do io
        println(io,"t,HFORT,VFORT,SFORT")
        for t in tt; pw=fort_power_at(rmp,Float64(t)); @printf(io,"%.6e,%.6e,%.6e,%.6e\n",t,pw[1],pw[2],pw[3]); end
    end
end
open(joinpath(OUT,"summary_pure.txt"),"w") do io
    @printf(io,"PURE-BEC-CONSTRAINED opt (thesis-calibrated, K3=%.0e, purity>=%.2f)\n",K3nom,PURITY)
    @printf(io,"LAB thesis ramp: N0=%.3e T=%.0fnK cond_frac=%.3f (pure? %s)\n",rb.N0_final,rb.T_final*1e9,cf(rb),cf(rb)>=PURITY ? "YES" : "no")
    @printf(io,"OPT ramp       : N0=%.3e T=%.0fnK cond_frac=%.3f (pure? %s)\n",ro.N0_final,ro.T_final*1e9,cf(ro),cf(ro)>=PURITY ? "YES" : "no")
    @printf(io,"factor(opt/lab N0)=%.2fx\n",ro.N0_final/rb.N0_final)
    @printf(io,"--- opt ramp across K3 band ---\n")
    for K3 in band; r=run_(opt,K3); @printf(io,"K3=%.0e: N0=%.3e T=%.0fnK cond_frac=%.3f\n",K3,r.N0_final,r.T_final*1e9,cf(r)); end
    @printf(io,"opt HFORT: %s\n",join([@sprintf("%.3f",x) for x in bestP[1,:]]," "))
    @printf(io,"opt VFORT: %s\n",join([@sprintf("%.3f",x) for x in bestP[2,:]]," "))
end
println(read(joinpath(OUT,"summary_pure.txt"),String))
