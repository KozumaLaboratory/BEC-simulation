# Sanity check for the independent tightness axis m_ω(t) added to run_evaporation_bec.
# Reuses the verified-cooling issue-#75 euv3 setup (same trap + FORT ramp as
# eu_evaporation_tradeoff.jl) and drives a CONSTANT tightness multiplier m_ω over a range.
# Expected tension (the whole point of the waist axis):
#   m_ω ↑ (tighter) → denser condensate → 3-body loss ↑ → N₀ ↓, but T_c ↑ (BEC safe).
#   m_ω ↓ (looser)  → 3-body ↓ but T_c ∝ ω̄ collapses → T > T_c → BEC melts (cf → 0).
#   ⇒ N₀ peaks at an intermediate m_ω. m_ω = 1 recovers issue #75 exactly.

using SpinorBEC
using Printf
const BOHR = 5.29177210903e-11
const OUT = length(ARGS) >= 1 ? ARGS[1] : "omega_mult_out"
mkpath(OUT)

alpha = 5.88e-37; a_s = 135 * BOHR; wH = sqrt(26e-6 * 30e-6); wV = 47e-6
N0 = 1.4e6; T0 = 50e-6
trap = euv3_evap_trap(; waists=[wH, wV, wV], alpha=alpha,
    directions=[(1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0)])
p = EvapParams(; a_s=a_s, tau_bg=15.0, K3=1e-41, heating_rate=0.05)

# Working #75 base ramp: log-linear hODT + vODT decay to a deep final depth that reaches BEC.
NB = 41; SPAN = 2.2; PST = [10.0, 6.0]
times = collect(range(0.0, SPAN; length=NB))
function ramp_to(fH, fV)
    P = zeros(3, NB)
    for (b, pf) in ((1, fH), (2, fV))
        for i in 1:NB
            f = (i - 1) / (NB - 1); P[b, i] = PST[b] * (pf / PST[b])^f
        end
    end
    FortRamp(times, P)
end
fH = 0.02; fV = max(0.06 * fH, 0.01)          # a BEC-forming operating point at m_ω = 1
ramp = ramp_to(fH, fV)

cf(r) = r.N0_final / max(r.N[end], 1)
# T_c at the final effective ω̄ (= m_ω · ω̄_ramp,end): the melt-margin the loosening must respect.
ωbar_end(mω) = begin
    r = run_evaporation_bec(trap, ramp, p; N0=N0, T0=T0, omega_mult=(t -> mω))
    Nend = r.N[end]
    Tc = bec_critical_temperature(round(Int, Nend), _final_omega(trap, ramp, mω)) * 1e9
    (r, Tc)
end
# effective final ω̄ (rad/s): the power-ramp ω̄ at t_end times m_ω.
function _final_omega(trap, ramp, mω)
    U, ω = SpinorBEC.trap_at(trap, SpinorBEC.fort_power_at(ramp, ramp.times[end]))
    mω * ω
end

# ---- (1) constant-m_ω sweep: the tension curve ----
mωs = collect(range(0.45, 2.2; length=60))
open(joinpath(OUT, "omega_mult_sweep.csv"), "w") do io
    println(io, "m_omega,N0,T_nK,Tc_nK,cf,margin_nK")
    for mω in mωs
        r, Tc = ωbar_end(mω)
        T = r.T_final * 1e9
        @printf(io, "%.4f,%.5e,%.4f,%.4f,%.5f,%.4f\n", mω, r.N0_final, T, Tc, cf(r), Tc - T)
    end
end

# ---- (2) three representative constant trajectories (the 2-3 point manual check) ----
open(joinpath(OUT, "omega_mult_traj.csv"), "w") do io
    println(io, "label,t_s,N,N0,Nth,T_nK")
    for (lab, mω) in (("loose_0.6", 0.6), ("baseline_1.0", 1.0), ("tight_1.6", 1.6))
        r = run_evaporation_bec(trap, ramp, p; N0=N0, T0=T0, omega_mult=(t -> mω))
        for k in eachindex(r.t)
            @printf(io, "%s,%.5f,%.5e,%.5e,%.5e,%.4f\n",
                lab, r.t[k], r.N[k], r.N0[k], r.Nth[k], r.T[k] * 1e9)
        end
    end
end

# summary to stdout
d = readlines(joinpath(OUT, "omega_mult_sweep.csv"))[2:end]
rows = [split(l, ",") for l in d]
N0v = [parse(Float64, r[2]) for r in rows]
best = argmax(N0v)
@printf("m_ω sweep: %d pts, N₀ peak %.3e at m_ω=%.3f (T=%.0f nK, Tc=%.0f nK, cf=%.2f)\n",
    length(d), N0v[best], parse(Float64, rows[best][1]),
    parse(Float64, rows[best][3]), parse(Float64, rows[best][4]),
    parse(Float64, rows[best][5]))
