# Unified ramp + tightness-axis optimization for the Eu evaporation (continues issue #75).
# Stage A: optimize the FORT power ramp alone (m_ω ≡ 1) — the ramp-only baseline.
# Stage B: on that best ramp, optimize an independent tightness multiplier m_ω(t)
#          (piecewise-linear waist axis) that decouples ω̄ from the power-set value.
# Objective: maximize N₀ subject to T ≤ T_target AND cf ≥ purity AND T < T_c (melt floor).
# The two stages isolate the pure gain from the waist axis on an already-optimal ramp.

using SpinorBEC
using Printf, Random
const BOHR = 5.29177210903e-11
const OUT = length(ARGS) >= 1 ? ARGS[1] : "unified_out"
mkpath(OUT)
const NSTART = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 24

alpha = 5.88e-37; a_s = 135 * BOHR; wH = sqrt(26e-6 * 30e-6); wV = 47e-6
N0 = 1.4e6; T0 = 50e-6
trap = euv3_evap_trap(; waists=[wH, wV, wV], alpha=alpha,
    directions=[(1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0)])
p = EvapParams(; a_s=a_s, tau_bg=15.0, K3=1e-41, heating_rate=0.05)
cf(r) = r.N0_final / max(r.N[end], 1)

const NB = 13; const SPAN = 7.4; const PSTART = [10.0, 6.0]; const PENDLO = [0.02, 0.05]
const TTARGET = 50.0            # nK
const PURITY = 0.90             # cf ≥ 0.90 (handoff)
base_t = collect(range(0.0, SPAN; length=NB))
warp_t(s, γ) = [s * SPAN * ((t / SPAN)^γ) for t in base_t]
mono_ramp(P, s, γ) = (pw = zeros(3, NB); pw[1:2, :] = P; FortRamp(warp_t(s, γ), pw))

# effective final ω̄ (rad/s) = m_ω(t_end)·ω̄_ramp(t_end); drives the melt-floor T_c.
function omega_end(ramp, mend)
    _, ω = SpinorBEC.trap_at(trap, SpinorBEC.fort_power_at(ramp, ramp.times[end]))
    mend * ω
end
Tc_end(ramp, r, mend) = bec_critical_temperature(round(Int, max(r.N[end], 1)), omega_end(ramp, mend)) * 1e9

# soft-penalised objective shared by both stages (mvals = tightness control points; ≡1 ⇒ ramp-only)
# grid: optional precomputed EvapTrapGrid (fixed-ramp Stage B) → skips the per-node trap solve.
function score(ramp, om, mend; grid=nothing)
    r = run_evaporation_bec(trap, ramp, p; N0=N0, T0=T0, omega_mult=om, trap_grid=grid)
    N0f = r.N0_final; c = cf(r); T = r.T_final * 1e9
    margin = Tc_end(ramp, r, mend) - T                       # T_c − T at the effective final ω̄
    pen_cf = c >= PURITY ? 1.0 : (c / PURITY)^3
    pen_T = T <= TTARGET ? 1.0 : (TTARGET / max(T, 1e-6))^6
    pen_Tc = margin >= 5.0 ? 1.0 : (max(margin, 0.0) / 5.0)^2 # explicit melt-floor barrier (5 nK)
    (N0f * pen_cf * pen_T * pen_Tc, r)
end

# ---------- Stage A: ramp-only optimum (m_ω ≡ 1) ----------
const NA = min(NSTART, 6)       # Stage A rebuilds the trap grid each eval ⇒ keep starts modest
const ONE = (t -> 1.0)
objA(P, s, γ) = score(mono_ramp(P, s, γ), ONE, 1.0)[1]
function descendA(P0, s0, γ0; n_line=7, n_sweeps=4)
    P = copy(P0); s = s0; γ = γ0; best = objA(P, s, γ)
    for _ in 1:n_sweeps
        imp = false
        for b in 1:2, i in 2:NB
            hiv = P[b, i-1]; lov = i < NB ? P[b, i+1] : PENDLO[b]
            hiv <= lov && continue
            lb, lv = best, P[b, i]
            for v in range(lov, hiv; length=n_line)
                P[b, i] = v; sc = objA(P, s, γ); sc > lb && (lb = sc; lv = v)
            end
            P[b, i] = lv; lb > best && (best = lb; imp = true)
        end
        lb, lv = best, s
        for v in range(0.3, 3.0; length=17)
            sc = objA(P, v, γ); sc > lb && (lb = sc; lv = v)
        end
        s = lv; lb > best && (best = lb; imp = true)
        lb, lv = best, γ
        for v in range(0.5, 2.0; length=15)
            sc = objA(P, s, v); sc > lb && (lb = sc; lv = v)
        end
        γ = lv; lb > best && (best = lb; imp = true)
        imp || break
    end
    (P, s, γ, best)
end
function rand_mono(rng)
    P = zeros(2, NB)
    for b in 1:2
        fr = sort(rand(rng, NB - 1); rev=true); P[b, 1] = PSTART[b]
        for i in 2:NB
            P[b, i] = max(PENDLO[b], PSTART[b] * prod(fr[1:i-1]))
        end
    end
    P
end
rng = MersenneTwister(1); bestP = nothing; bests = 1.0; bestγ = 1.0; bestscA = -Inf
t0 = time()
for k in 1:NA
    P0 = k == 1 ?
        (Q = zeros(2, NB); for b in 1:2, i in 1:NB
            f = (i - 1) / (NB - 1); Q[b, i] = PSTART[b] * ((0.1 * PSTART[b]) / PSTART[b])^f
        end; Q) : rand_mono(rng)
    s0 = k == 1 ? 1.0 : 0.3 + rand(rng) * 2.7
    γ0 = k == 1 ? 1.0 : 0.5 + rand(rng) * 1.5
    P, s, γ, sc = descendA(P0, s0, γ0)
    if sc > bestscA
        global bestscA = sc; global bestP = P; global bests = s; global bestγ = γ
    end
    @printf("A: %d/%d starts, best=%.3e\n", k, NA, bestscA); flush(stdout)
end
ramp_best = mono_ramp(bestP, bests, bestγ)
rA = run_evaporation_bec(trap, ramp_best, p; N0=N0, T0=T0)
@printf("\n[A] ramp-only: N0=%.4e T=%.1fnK cf=%.3f dur=%.2fs\n",
    rA.N0_final, rA.T_final * 1e9, cf(rA), bests * SPAN)

# ---------- Stage B: tightness axis m_ω(t) on the best ramp ----------
const KW = length(ARGS) >= 4 ? parse(Int, ARGS[4]) : 6   # piecewise-linear control pts over τ∈[0,1]
const MFLOOR = length(ARGS) >= 5 ? parse(Float64, ARGS[5]) : 0.40
const MCEIL = 2.0
const MONO = length(ARGS) >= 3 ? parse(Bool, ARGS[3]) : false  # constrain m_ω non-increasing (smooth waist opening)
grid_best = evap_trap_grid(trap, ramp_best)   # fixed ramp ⇒ build the trap grid once, reuse for all m_ω
dur = ramp_best.times[end] - ramp_best.times[1]
τnodes = collect(range(0.0, 1.0; length=KW))
function build_mω(mv)
    t0r = ramp_best.times[1]
    function (t)
        τ = clamp((t - t0r) / dur, 0.0, 1.0)
        j = clamp(searchsortedlast(τnodes, τ), 1, KW - 1)
        f = (τ - τnodes[j]) / (τnodes[j+1] - τnodes[j])
        mv[j] * (1 - f) + mv[j+1] * f
    end
end
objB(mv) = score(ramp_best, build_mω(mv), mv[end]; grid=grid_best)[1]
function descendB(m0; n_line=13, n_sweeps=8)
    m = copy(m0); best = objB(m)
    for _ in 1:n_sweeps
        imp = false
        for i in 1:KW
            # MONO ⇒ keep m non-increasing: bound coordinate i by its neighbours (smooth waist opening)
            lov = MONO && i < KW ? max(MFLOOR, m[i+1]) : MFLOOR
            hiv = MONO && i > 1 ? min(MCEIL, m[i-1]) : MCEIL
            lb, lv = best, m[i]
            for v in range(lov, hiv; length=n_line)
                m[i] = v; sc = objB(m); sc > lb && (lb = sc; lv = v)
            end
            m[i] = lv; lb > best && (best = lb; imp = true)
        end
        imp || break
    end
    (m, best)
end
rand_m(rng) = MONO ? sort(MFLOOR .+ (MCEIL - MFLOOR) .* rand(rng, KW); rev=true) :
              MFLOOR .+ (MCEIL - MFLOOR) .* rand(rng, KW)
bestm = fill(1.0, KW); bestscB = objB(bestm)   # includes the m_ω≡1 start (= Stage A point)
for k in 1:NSTART
    m0 = k == 1 ? fill(1.0, KW) : rand_m(rng)
    m, sc = descendB(m0)
    if sc > bestscB
        global bestscB = sc; global bestm = m
    end
    k % 8 == 0 && (@printf("B: %d/%d starts, best=%.3e\n", k, NSTART, bestscB); flush(stdout))
end
om_best = build_mω(bestm)
rB = run_evaporation_bec(trap, ramp_best, p; N0=N0, T0=T0, omega_mult=om_best, trap_grid=grid_best)
@printf("[B] unified:   N0=%.4e T=%.1fnK cf=%.3f Tc=%.1fnK\n",
    rB.N0_final, rB.T_final * 1e9, cf(rB), Tc_end(ramp_best, rB, bestm[end]))
gain = rB.N0_final / max(rA.N0_final, 1)
@printf("\n=== UNIFIED vs RAMP-ONLY (%.0fs) ===  N0 gain = %.2f×  (%.4e → %.4e)\n",
    time() - t0, gain, rA.N0_final, rB.N0_final)
@printf("optimal m_ω control points (τ=0→1): %s\n", join([@sprintf("%.3f", x) for x in bestm], ", "))

# ---------- dump comparison data ----------
# effective ω̄(t)/2π for both runs (Hz)
ωramp_hz(t) = (SpinorBEC.trap_at(trap, SpinorBEC.fort_power_at(ramp_best, Float64(t)))[2]) / (2π)
open(joinpath(OUT, "unified_traj.csv"), "w") do io
    println(io, "which,t_s,N,N0,Nth,T_nK")
    for (lab, r) in (("ramp_only", rA), ("unified", rB))
        for k in eachindex(r.t)
            @printf(io, "%s,%.6e,%.6e,%.6e,%.6e,%.4f\n",
                lab, r.t[k], r.N[k], r.N0[k], r.Nth[k], r.T[k] * 1e9)
        end
    end
end
tg = range(0.0, dur; length=400)
open(joinpath(OUT, "unified_shape.csv"), "w") do io
    println(io, "t_s,m_omega,omega_ramp_hz,omega_eff_hz")
    for t in tg
        wr = ωramp_hz(t); mω = om_best(Float64(t))
        @printf(io, "%.6e,%.5f,%.4f,%.4f\n", t, mω, wr, mω * wr)
    end
end
open(joinpath(OUT, "unified_summary.txt"), "w") do io
    @printf(io, "UNIFIED ramp + tightness-axis optimization (K3=1e-41, T<=%.0fnK, cf>=%.2f, %d starts)\n",
        TTARGET, PURITY, NSTART)
    @printf(io, "[A] ramp-only (m_ω≡1): N0=%.4e T=%.1fnK cf=%.3f dur=%.2fs\n",
        rA.N0_final, rA.T_final * 1e9, cf(rA), bests * SPAN)
    @printf(io, "[B] unified (m_ω(t)):  N0=%.4e T=%.1fnK cf=%.3f Tc=%.1fnK\n",
        rB.N0_final, rB.T_final * 1e9, cf(rB), Tc_end(ramp_best, rB, bestm[end]))
    @printf(io, "N0 gain = %.2f×\n", gain)
    @printf(io, "m_ω control points (τ=0→1): %s\n", join([@sprintf("%.3f", x) for x in bestm], ", "))
end
println(read(joinpath(OUT, "unified_summary.txt"), String))
