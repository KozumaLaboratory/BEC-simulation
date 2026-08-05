using SpinorBEC
using Printf, Random
const BOHR = 5.29177210903e-11
const OUT = ARGS[1]; mkpath(OUT)

# --- thesis-calibrated (Miyazawa 2021) parameters ---
alpha = 5.88e-37                          # confirmed (α_s = 189 a.u.)
a_s   = 135 * BOHR                        # measured (ε_dd = 0.44), not 110
wH    = sqrt(26e-6 * 30e-6)               # elliptic hODT → effective circular waist 27.9 µm
wV    = 47e-6
N0, T0 = 1.4e6, 50e-6                     # into ODT (PSD 5e-6)
# hODT ∥ x (confines y,z), vODT ∥ z (confines x,y), gravity ∥ z
trap = euv3_evap_trap(; waists=[wH, wV, wV], alpha=alpha,
    directions=[(1.0,0.0,0.0),(0.0,0.0,1.0),(0.0,1.0,0.0)])

# thesis evaporation ramp (Fig 7.3): hODT 10→0.1 (down), vODT 0.15→6→1.3 (up then ¼)
times = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 6.7, 7.4]
hODT  = [10.0, 5.0, 3.0, 2.0, 1.2, 0.7, 0.35, 0.18, 0.10]
vODT  = [0.15, 1.2, 2.5, 3.5, 4.5, 5.5, 6.0, 3.0, 1.30]
sODT  = zeros(length(times))
base  = FortRamp(times, permutedims(hcat(hODT, vODT, sODT)))
nb = length(times)

pfor(K3) = EvapParams(; a_s=a_s, tau_bg=15.0, K3=K3)
finalN0(ramp, K3) = run_evaporation_bec(trap, ramp, pfor(K3); N0=N0, T0=T0)

# ---- 1) validation: thesis base ramp across the K3 band ----
band = [1e-42, 3e-42, 1e-41, 3e-41, 1e-40]
println("=== thesis base ramp vs K3 band (target BEC ~1.5e4) ===")
for K3 in band
    r = finalN0(base, K3)
    @printf("K3=%.0e : N0_final=%.3e  T_final=%.0fnK  t_bec=%.2fs  eta_f=%.0f\n",
        K3, r.N0_final, r.T_final*1e9, r.t_bec, r.eta[end])
end

# ---- 2) optimize interior breakpoints (endpoints fixed) at nominal K3=1e-41 ----
K3nom = 1e-41
Pstart = base.powers_W[:,1]; Pend = base.powers_W[:,nb]
Pmax = [11.5, 7.4, 0.0]
interior = [(b,i) for b in 1:2 for i in 2:(nb-1)]     # beams 1,2 ; SFORT off
mk(P) = FortRamp(times, P)
score(P) = run_evaporation_bec(trap, mk(P), pfor(K3nom); N0=N0, T0=T0).N0_final

function descend(P0; n_line=15, n_sweeps=8)
    P = copy(P0); best = score(P)
    for _ in 1:n_sweeps
        improved = false
        for (b,i) in interior
            lb, lv = best, P[b,i]
            for v in range(0.02, Pmax[b]; length=n_line)
                P[b,i] = v; sc = score(P)
                sc > lb && (lb=sc; lv=v)
            end
            P[b,i] = lv
            lb > best && (best=lb; improved=true)
        end
        improved || break
    end
    (P, best)
end
bestP, bestsc = descend(copy(base.powers_W))
rng = MersenneTwister(1)
for _ in 1:4
    P = copy(base.powers_W)
    for (b,i) in interior; P[b,i] = 0.02 + rand(rng)*(Pmax[b]-0.02); end
    P[:,1]=Pstart; P[:,nb]=Pend
    Pf, sc = descend(P)
    sc > bestsc && (global bestsc=sc; global bestP=Pf)
end
opt = mk(bestP)

println("\n=== optimized ramp (endpoints fixed) vs K3 band ===")
for K3 in band
    r = finalN0(opt, K3)
    @printf("K3=%.0e : N0_final=%.3e  T_final=%.0fnK  t_bec=%.2fs\n",
        K3, r.N0_final, r.T_final*1e9, r.t_bec)
end

# dump trajectories + ramps at nominal K3
function dump(r, name)
    open(joinpath(OUT,"bec_$name.csv"),"w") do io
        println(io,"t,N,N0,Nth,T,eta")
        for i in eachindex(r.t)
            @printf(io,"%.6e,%.6e,%.6e,%.6e,%.6e,%.6e\n", r.t[i],r.N[i],r.N0[i],r.Nth[i],r.T[i],r.eta[i])
        end
    end
end
dump(finalN0(base,K3nom),"lab"); dump(finalN0(opt,K3nom),"opt")
for (rmp,nm) in ((base,"lab"),(opt,"opt"))
    tt=range(times[1],times[end];length=400)
    open(joinpath(OUT,"ramp_$nm.csv"),"w") do io
        println(io,"t,HFORT,VFORT,SFORT")
        for t in tt; pw=fort_power_at(rmp,Float64(t)); @printf(io,"%.6e,%.6e,%.6e,%.6e\n",t,pw[1],pw[2],pw[3]); end
    end
end
rb = finalN0(base,K3nom); ro = finalN0(opt,K3nom)
open(joinpath(OUT,"summary_thesis.txt"),"w") do io
    @printf(io,"THESIS-CALIBRATED (a_s=135a0, wH=27.9um, wV=47um, N0=1.4e6, T0=50uK, alpha=5.88e-37)\n")
    @printf(io,"K3nom=%.0e  measured BEC ~1.5e4 (thesis) / 5.0e4 (2022)\n", K3nom)
    cf(r)=r.N0_final/max(r.N[end],1)
    @printf(io,"LAB  base ramp: N0_final=%.3e  T_final=%.0fnK  cond_frac=%.3f (pure? %s)  t_bec=%.2fs\n",
        rb.N0_final, rb.T_final*1e9, cf(rb), cf(rb)>0.95 ? "YES" : "no", rb.t_bec)
    @printf(io,"OPT  ramp     : N0_final=%.3e  T_final=%.0fnK  cond_frac=%.3f (pure? %s)  t_bec=%.2fs\n",
        ro.N0_final, ro.T_final*1e9, cf(ro), cf(ro)>0.95 ? "YES" : "no", ro.t_bec)
    @printf(io,"factor(opt/lab)=%.2fx\n", ro.N0_final/rb.N0_final)
    @printf(io,"opt HFORT bkpts: %s\n", join([@sprintf("%.3f",x) for x in bestP[1,:]]," "))
    @printf(io,"opt VFORT bkpts: %s\n", join([@sprintf("%.3f",x) for x in bestP[2,:]]," "))
end
println("\n"*read(joinpath(OUT,"summary_thesis.txt"),String))
