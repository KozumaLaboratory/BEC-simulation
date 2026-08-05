using SpinorBEC
using DelimitedFiles, Printf, Random

const OUT = ARGS[1]; mkpath(OUT)
d = euv3_defaults()
trap = euv3_evap_trap(; waists=d.waists, alpha=d.alpha)
p = EvapParams(; a_s=d.a_s, tau_bg=d.tau_bg, K3=d.K3)
base = euv3_evaporation_ramp()
N0, T0 = d.N0, d.T0

nbeam, nb = size(base.powers_W)
base1 = base.powers_W[:, 1]
active = [(b, s) for b in 1:nbeam if base1[b] > 0 for s in 1:(nb-1)]
function mono_ramp(fr)
    pw = copy(base.powers_W)
    for b in 1:nbeam
        acc = 1.0
        for i in 2:nb
            acc *= fr[b, i-1]; pw[b, i] = base1[b]*acc
        end
    end
    FortRamp(base.times, pw)
end
score(fr) = run_evaporation_bec(trap, mono_ramp(fr), p; N0=N0, T0=T0).N0_final

function baseline_fracs()
    fr = ones(nbeam, nb-1)
    for b in 1:nbeam, s in 1:(nb-1)
        p0 = base.powers_W[b, s]
        r = p0 > 0 ? base.powers_W[b, s+1]/p0 : 1.0
        fr[b, s] = isfinite(r) ? clamp(r, 0.02, 1.0) : 1.0
    end
    fr
end
line = collect(range(0.02, 1.0; length=21))
function descend(start)
    fr = copy(start); best = score(fr)
    for _ in 1:10
        improved = false
        for (b, s) in active
            lb, lv = best, fr[b, s]
            for v in line
                fr[b, s] = v; sc = score(fr)
                sc > lb && (lb = sc; lv = v)
            end
            fr[b, s] = lv
            lb > best && (best = lb; improved = true)
        end
        improved || break
    end
    (fr, best)
end

best_fr, best_sc = descend(baseline_fracs())
rng = MersenneTwister(1)
for _ in 1:8
    st = ones(nbeam, nb-1)
    for (b, s) in active; st[b, s] = 0.02 + rand(rng)*0.98; end
    fr, sc = descend(st)
    sc > best_sc && (global best_sc = sc; global best_fr = fr)
end
opt_ramp = mono_ramp(best_fr)

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
    @printf(io, "model=LRW 2-component (T0=%.0fuK, K3=%.1e)  measured N_BEC=%.2e @ %.0fnK\n",
        d.T0*1e6, d.K3, d.measured_N_BEC, d.measured_T_BEC*1e9)
    for (nm, r) in (("LAB", lab), ("OPT", opt))
        @printf(io, "%s: N0_final=%.4e  T_final=%.1fnK  N_total_final=%.4e  cond_frac=%.3f  t_bec=%.2fs\n",
            nm, r.N0_final, r.T_final*1e9, r.N[end], r.N0_final/max(r.N[end],1), r.t_bec)
    end
    @printf(io, "N0_final factor (opt/lab) = %.2fx\n", opt.N0_final/lab.N0_final)
end
println(read(joinpath(OUT, "summary_final.txt"), String))
