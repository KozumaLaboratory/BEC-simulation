using SpinorBEC
using DelimitedFiles
using Printf

const OUT = ARGS[1]
mkpath(OUT)

d = euv3_defaults()
@info "euv3 defaults" N0=d.N0 T0=d.T0 K3=d.K3 alpha=d.alpha measured_N_BEC=d.measured_N_BEC

trap = euv3_evap_trap(; waists=d.waists, alpha=d.alpha)
p = EvapParams(; a_s=d.a_s, tau_bg=d.tau_bg, K3=d.K3)
base = euv3_evaporation_ramp()

# --- baseline lab ramp ---
lab = run_evaporation(trap, base, p; N0=d.N0, T0=d.T0)
@info "LAB ramp" reached=lab.reached_bec N_BEC=lab.N_BEC T_BEC=lab.T_BEC gamma_eff=lab.gamma_eff

# --- optimize over realizable monotone family ---
t0 = time()
opt = optimize_ramp_monotone(trap, p, base; N0=d.N0, T0=d.T0,
    frac_bounds=(0.02, 1.0), n_sweeps=12, n_line=25, restarts=16, seed=1)
@info "OPT monotone" reached=opt.result.reached_bec N_BEC=opt.N_BEC score=opt.score elapsed=round(time()-t0, digits=1)

optr = opt.result
factor = opt.N_BEC / lab.N_BEC
@info "IMPROVEMENT" lab_N_BEC=lab.N_BEC opt_N_BEC=opt.N_BEC factor=factor

# --- dump trajectories ---
function dump_traj(r, name)
    open(joinpath(OUT, "traj_$name.csv"), "w") do io
        println(io, "t,N,T,eta,psd,omega_bar,U_depth")
        for i in eachindex(r.t)
            @printf(io, "%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e\n",
                r.t[i], r.N[i], r.T[i], r.eta[i], r.psd[i], r.omega_bar[i], r.U_depth[i])
        end
    end
end
dump_traj(lab, "lab")
dump_traj(optr, "opt")

# --- dump ramps (dense sample of piecewise-linear power schedules) ---
function dump_ramp(ramp, name)
    tt = range(ramp.times[1], ramp.times[end]; length=400)
    open(joinpath(OUT, "ramp_$name.csv"), "w") do io
        println(io, "t,HFORT,VFORT,SFORT")
        for t in tt
            pw = fort_power_at(ramp, Float64(t))
            @printf(io, "%.6e,%.6e,%.6e,%.6e\n", t, pw[1], pw[2], length(pw) >= 3 ? pw[3] : 0.0)
        end
    end
end
dump_ramp(base, "lab")
dump_ramp(opt.ramp, "opt")

# --- summary ---
open(joinpath(OUT, "summary.txt"), "w") do io
    @printf(io, "model=LRW_first_principles (T0=%.1fuK, K3=%.2e, alpha=%.3e)\n", d.T0*1e6, d.K3, d.alpha)
    @printf(io, "N0=%.3e  measured_N_BEC=%.3e\n", d.N0, d.measured_N_BEC)
    @printf(io, "LAB : reached=%s N_BEC=%.4e T_BEC=%.3e (nK=%.1f) gamma_eff=%.3f\n",
        lab.reached_bec, lab.N_BEC, lab.T_BEC, lab.T_BEC*1e9, lab.gamma_eff)
    @printf(io, "OPT : reached=%s N_BEC=%.4e T_BEC=%.3e (nK=%.1f) gamma_eff=%.3f\n",
        optr.reached_bec, opt.N_BEC, optr.T_BEC, optr.T_BEC*1e9, optr.gamma_eff)
    @printf(io, "improvement factor = %.3fx\n", factor)
    @printf(io, "opt fracs (per-beam step ratios):\n")
    for b in 1:size(opt.fracs, 1)
        @printf(io, "  beam %d: %s\n", b, join([@sprintf("%.3f", x) for x in opt.fracs[b, :]], " "))
    end
end
println(read(joinpath(OUT, "summary.txt"), String))
@info "DONE" out=OUT
