using SpinorBEC
using Printf, Random

const OUT = ARGS[1]; mkpath(OUT)
d = euv3_defaults()
trap = euv3_evap_trap(; waists=d.waists, alpha=d.alpha)
p = EvapParams(; a_s=d.a_s, tau_bg=d.tau_bg, K3=d.K3)
base = euv3_evaporation_ramp()
N0, T0 = d.N0, d.T0
nbeam, nb = size(base.powers_W)

# fixed endpoints: column 1 = loaded start, column nb = physical final trap (0.14/0.09 W)
Pstart = base.powers_W[:, 1]
Pend   = base.powers_W[:, nb]
# interior breakpoints (2..nb-1) of the active beams are the free variables
interior = [(b, i) for b in 1:nbeam if Pstart[b] > 0 for i in 2:(nb-1)]

powers_from(P) = FortRamp(base.times, P)
score(P) = run_evaporation_bec(trap, powers_from(P), p; N0=N0, T0=T0).N0_final

# build a monotone-decreasing interior from Pstart..Pend (log-linear as the warm start)
function init_powers()
    P = copy(base.powers_W)
    for b in 1:nbeam
        Pstart[b] <= 0 && continue
        for i in 1:nb
            f = (i - 1) / (nb - 1)
            P[b, i] = Pstart[b] * (Pend[b] / Pstart[b])^f   # log-linear monotone
        end
        P[b, 1] = Pstart[b]; P[b, nb] = Pend[b]
    end
    P
end

# coordinate descent: each interior breakpoint line-searched within [P[b,i+1], P[b,i-1]]
# (keeps monotone; endpoints never move)
function descend(P0; n_line=25, n_sweeps=12)
    P = copy(P0); best = score(P)
    for _ in 1:n_sweeps
        improved = false
        for (b, i) in interior
            lo, hi = P[b, i+1], P[b, i-1]          # monotone window from current neighbors
            hi <= lo && continue
            lb, lv = best, P[b, i]
            for v in range(lo, hi; length=n_line)
                P[b, i] = v; sc = score(P)
                sc > lb && (lb = sc; lv = v)
            end
            P[b, i] = lv
            lb > best && (best = lb; improved = true)
        end
        improved || break
    end
    (P, best)
end

bestP, bestsc = descend(init_powers())
rng = MersenneTwister(1)
for _ in 1:8
    # random monotone interior start between the fixed endpoints
    P = copy(base.powers_W)
    for b in 1:nbeam
        Pstart[b] <= 0 && continue
        us = sort(rand(rng, nb-2); rev=true)       # decreasing fractions in (0,1)
        for (k, i) in enumerate(2:(nb-1))
            P[b, i] = Pend[b] + us[k] * (Pstart[b] - Pend[b])
        end
        P[b, 1] = Pstart[b]; P[b, nb] = Pend[b]
    end
    Pf, sc = descend(P)
    sc > bestsc && (global bestsc = sc; global bestP = Pf)
end
opt_ramp = powers_from(bestP)

lab = run_evaporation_bec(trap, base, p; N0=N0, T0=T0)
opt = run_evaporation_bec(trap, opt_ramp, p; N0=N0, T0=T0)

function dump(r, name)
    open(joinpath(OUT, "bec_$name.csv"), "w") do io
        println(io, "t,N,N0,Nth,T,eta")
        for i in eachindex(r.t)
            @printf(io, "%.6e,%.6e,%.6e,%.6e,%.6e,%.6e\n",
                r.t[i], r.N[i], r.N0[i], r.Nth[i], r.T[i], r.eta[i])
        end
    end
end
dump(lab, "lab"); dump(opt, "opt")
function dump_ramp(ramp, name)
    tt = range(ramp.times[1], ramp.times[end]; length=400)
    open(joinpath(OUT, "ramp_$name.csv"), "w") do io
        println(io, "t,HFORT,VFORT,SFORT")
        for t in tt
            pw = fort_power_at(ramp, Float64(t))
            @printf(io, "%.6e,%.6e,%.6e,%.6e\n", t, pw[1], pw[2], pw[3])
        end
    end
end
dump_ramp(base, "lab"); dump_ramp(opt_ramp, "opt")

open(joinpath(OUT, "summary_final.txt"), "w") do io
    @printf(io, "model=LRW 2-component CONSTRAINED-endpoint (T0=%.0fuK, K3=%.1e)  measured N_BEC=%.2e @ %.0fnK\n",
        d.T0*1e6, d.K3, d.measured_N_BEC, d.measured_T_BEC*1e9)
    @printf(io, "fixed endpoints: start(H,V)=(%.3f,%.3f)W  final(H,V)=(%.3f,%.3f)W\n",
        Pstart[1], Pstart[2], Pend[1], Pend[2])
    for (nm, r) in (("LAB", lab), ("OPT", opt))
        @printf(io, "%s: N0_final=%.4e  T_final=%.1fnK  N_total_final=%.4e  cond_frac=%.3f  t_bec=%.2fs  eta_final=%.1f\n",
            nm, r.N0_final, r.T_final*1e9, r.N[end], r.N0_final/max(r.N[end],1), r.t_bec, r.eta[end])
    end
    @printf(io, "N0_final factor (opt/lab) = %.2fx\n", opt.N0_final/lab.N0_final)
    @printf(io, "opt HFORT breakpoints: %s\n", join([@sprintf("%.4f", x) for x in bestP[1, :]], " "))
    @printf(io, "opt VFORT breakpoints: %s\n", join([@sprintf("%.4f", x) for x in bestP[2, :]], " "))
end
println(read(joinpath(OUT, "summary_final.txt"), String))
