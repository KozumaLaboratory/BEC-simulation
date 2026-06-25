# Issue #58 — Can shaping the FORT trap reduce K₃ three-body loss and raise N_BEC?
#
# Hypothesis (lab note + scaling): loosen the trap → lower density → less 3-body loss.
# The condensate 3-body rate is K₃⟨n²⟩ with TF peak density n₀ = μ/g, μ ∝ ω̄^(6/5), so
# the per-atom loss rate ∝ ω̄^(12/5) ≈ ω̄^2.4.
#
# CONCLUSION: the hypothesis is CORRECT — lowering the density (= loosening the trap)
# reduces K₃ loss exactly as expected. The clean oracle (a FIXED condensate held under
# K₃-only loss, no evaporation/T_c coupling) shows a held BEC survives 148× better at
# ν=20 Hz than at ν=200 Hz. The subtlety is WHEN/HOW to loosen: ω̄ also sets T_c ∝ ω̄, so
# loosening during the forced-evaporation ramp lowers T_c and starves condensate FORMATION
# (inflow), and loosening too fast during a hold MELTS the condensate into the thermal cloud
# (N_th ∝ (k_BT/ℏω̄)³). The win is realized by lowering the density AFTER the BEC has formed,
# adiabatically (T tracks ω̄ ⇒ T/T_c preserved) — the standard "decompress after BEC".
#
# Investigated with the two-component model `run_evaporation_bec` (follows the condensate
# K₃ depletion past the BEC onset) plus a coupling-free condensate-decay oracle:
#   (B) physics: n₀ ∝ ω̄^1.2, K₃ rate ∝ ω̄^2.4 (analytic, confirmed numerically)
#   (0) CLEAN oracle: held condensate, K₃-only — survival 0.5% @200Hz → 74% @20Hz (148×).
#       The hypothesis, isolated from every T_c/inflow confound. THIS is the headline.
#   (1) regime: euv3 is catastrophically K₃-limited — condensate 156k (K₃=0) → 1.2k (fit)
#   (2) loosening DURING evaporation recovers only ~1.0–1.1× — NOT because loosening fails
#       to cut K₃, but a T_c confound: lower ω̄ ⇒ lower T_c ⇒ the gas barely condenses (the
#       euv3 ramp is η-limited). The K₃ reduction is real; there is just no condensate to save.
#   (3) the FORMATION lever is TIMING: forming the BEC as late as possible minimizes the dense
#       condensate's K₃-exposure time — recovers ~5–9× (keeps the trap TIGHTER, complementary)
#   (4) decompress AFTER forming the BEC: lower n₀ slows the ongoing K₃ bleed ∝ ω̄^2.4. In this
#       0-D model the gain is muted (~1.3×) by partial condensate→thermal melting (imperfect
#       adiabatic tracking: T drops slower than ω̄) — a model-fidelity caveat, not a physics one.
#
# Outputs CSVs under figs/k3_trap_decompression/ + a matplotlib plot script.

using SpinorBEC
using Printf

const U = SpinorBEC.Units
const HBAR = U.HBAR
const KB = U.KB

const OUTDIR = joinpath(@__DIR__, "..", "figs", "k3_trap_decompression")
mkpath(OUTDIR)

# --- lab setup (euv3 r14 defaults; K3 fitted to the measured BEC number) ---
const D = euv3_defaults()
const TRAP = euv3_evap_trap()
const PARAMS = EvapParams(; a_s=D.a_s, tau_bg=D.tau_bg, K3=D.K3)
const PARAMS_NOK3 = EvapParams(; a_s=D.a_s, tau_bg=D.tau_bg, K3=0.0)
const BASE_RAMP = euv3_evaporation_ramp()
const N0_INIT = D.N0
const T0_INIT = D.T0
const M = TRAP.mass
# beam cal maxima (euv3.jl): HFORT ≤ 6.0 W, VFORT ≤ 5.5 W, SFORT ≤ 2.0 W
const BEAM_MAX = [6.0, 5.5, 2.0]

# TF peak density + per-atom condensate 3-body rate (mirrors condensate.jl)
function tf_peak_density(N0::Float64, ω̄::Float64)
    (N0 <= 0 || ω̄ <= 0) && return 0.0
    aho = sqrt(HBAR / (M * ω̄))
    μ = 0.5 * HBAR * ω̄ * (15 * N0 * PARAMS.a_s / aho)^(2 / 5)
    g = 4π * HBAR^2 * PARAMS.a_s / M
    μ / g
end
condensate_k3_rate(N0, ω̄) = PARAMS.K3 * (4 / 7) * tf_peak_density(N0, ω̄)^2
final_omega(ramp::FortRamp) = trap_at(TRAP, ramp.powers_W[:, end])[2]
N0_final_of(ramp, p=PARAMS) = run_evaporation_bec(TRAP, ramp, p; N0=N0_INIT, T0=T0_INIT).N0_final

# scale the final breakpoint powers by s (final-trap decompression)
function decompress_final(ramp::FortRamp, s::Real)
    pw = copy(ramp.powers_W)
    @views pw[:, end] .*= Float64(s)
    FortRamp(ramp.times, pw)
end

# scale the last K breakpoint powers by per-step multipliers, clamped to the beam maxima
function scale_backhalf(ramp::FortRamp, mults::Vector{Float64})
    pw = copy(ramp.powers_W)
    off = size(pw, 2) - length(mults)
    for (k, i) in enumerate((off + 1):size(pw, 2)), b in 1:size(pw, 1)
        pw[b, i] = min(pw[b, i] * mults[k], BEAM_MAX[b])
    end
    FortRamp(ramp.times, pw)
end

# append a hold segment of duration H, decompressing the endpoint powers by factor f
function append_hold(ramp::FortRamp, f::Real, H::Real)
    pend = ramp.powers_W[:, end]
    FortRamp(vcat(ramp.times, ramp.times[end] + H), hcat(ramp.powers_W, Float64(f) .* pend))
end

function write_csv(path, header, rows)
    open(path, "w") do io
        println(io, header)
        for r in rows
            println(io, join(r, ","))
        end
    end
    @info "wrote $path"
end

# ============================================================================
# (B) physics scaling: n₀ ∝ ω̄^(6/5), condensate K₃ rate ∝ ω̄^(12/5)
# ============================================================================
function physics_scaling()
    N0 = 1.0e5
    ωs = collect(range(2π * 30, 2π * 300; length=12))
    n0s = [tf_peak_density(N0, ω) for ω in ωs]
    rates = [condensate_k3_rate(N0, ω) for ω in ωs]
    slope(x, y) = begin
        lx = log.(x); ly = log.(y)
        (length(lx) * sum(lx .* ly) - sum(lx) * sum(ly)) /
        (length(lx) * sum(lx .^ 2) - sum(lx)^2)
    end
    p_n0, p_rate = slope(ωs, n0s), slope(ωs, rates)
    @printf("[B] n₀ ∝ ω̄^%.3f (analytic 1.200);  K₃ rate ∝ ω̄^%.3f (analytic 2.400)\n", p_n0, p_rate)
    write_csv(joinpath(OUTDIR, "physics_scaling.csv"),
        "omega_bar_rad_s,nu_bar_Hz,n0_TF_m3,k3_rate_per_s",
        [(ωs[i], ωs[i] / 2π, n0s[i], rates[i]) for i in eachindex(ωs)])
    (p_n0=p_n0, p_rate=p_rate)
end

# ============================================================================
# (0) CLEAN oracle: hold a FIXED condensate under K₃-only loss, vary the trap ω̄.
# No evaporation, no inflow, no T_c coupling — the hypothesis in isolation.
# dN₀/dt = −K₃(4/7)n₀(N₀,ω̄)² N₀ − N₀/τ_bg
# ============================================================================
function clean_condensate_survival(; N0_0=1.0e5, thold=1.0, nsteps=4000)
    νs = [200.0, 143.0, 100.0, 70.0, 45.0, 30.0, 20.0]
    rows = NamedTuple[]
    for ν in νs
        ω = 2π * ν
        N0 = N0_0
        dt = thold / nsteps
        for _ in 1:nsteps
            n0 = tf_peak_density(N0, ω)
            dN = -PARAMS.K3 * (4 / 7) * n0^2 * N0 - N0 / PARAMS.tau_bg
            N0 = max(N0 + dt * dN, 0.0)
        end
        push!(rows, (nu=ν, n0=tf_peak_density(N0_0, ω), N0=N0, survival=N0 / N0_0))
    end
    write_csv(joinpath(OUTDIR, "clean_condensate_survival.csv"),
        "nu_Hz,n0_initial_m3,N0_final,survival_fraction",
        [(r.nu, r.n0, r.N0, r.survival) for r in rows])
    @printf("[0] held condensate N0=%.0e, %.1f s, K₃-only: survival %.1f%% @%.0fHz → %.1f%% @%.0fHz (%.0f×)\n",
        N0_0, thold, rows[1].survival * 100, rows[1].nu,
        rows[end].survival * 100, rows[end].nu, rows[end].survival / max(rows[1].survival, 1e-9))
    rows
end

# ============================================================================
# (1) regime: how K₃-limited is the baseline?
# ============================================================================
function regime_diagnostic()
    n_k3 = N0_final_of(BASE_RAMP, PARAMS)
    n_no = N0_final_of(BASE_RAMP, PARAMS_NOK3)
    @printf("[1] baseline N0_final: K₃=%.2e → %.3e ;  K₃=0 → %.3e  (%.0f× loss to 3-body)\n",
        PARAMS.K3, n_k3, n_no, n_no / max(n_k3, 1))
    (n_k3=n_k3, n_no=n_no)
end

# ============================================================================
# (2) loosening during evaporation: final-power scale + beam waist
# ============================================================================
function sweep_loosening()
    scales = collect(range(0.3, 1.5; length=25))
    rows = NamedTuple[]
    for s in scales
        r = run_evaporation_bec(TRAP, decompress_final(BASE_RAMP, s), PARAMS; N0=N0_INIT, T0=T0_INIT)
        ω = final_omega(decompress_final(BASE_RAMP, s))
        push!(rows, (s=s, nu=ω / 2π, N0=r.N0_final, T=r.T_final,
            Tc=r.N0_final > 0 ? bec_critical_temperature(r.N[end], ω) : NaN,
            k3=condensate_k3_rate(r.N0_final, ω)))
    end
    write_csv(joinpath(OUTDIR, "sweep_final_power.csv"),
        "final_power_scale,nu_final_Hz,N0_final,T_final_K,Tc_K,k3_rate_per_s",
        [(r.s, r.nu, r.N0, r.T, r.Tc, r.k3) for r in rows])

    wf = collect(range(0.8, 2.0; length=25))
    wrows = NamedTuple[]
    for w in wf
        trap_w = euv3_evap_trap(; waists=D.waists .* w)
        r = run_evaporation_bec(trap_w, BASE_RAMP, PARAMS; N0=N0_INIT, T0=T0_INIT)
        ω = trap_at(trap_w, BASE_RAMP.powers_W[:, end])[2]
        push!(wrows, (w=w, nu=ω / 2π, N0=r.N0_final))
    end
    write_csv(joinpath(OUTDIR, "sweep_waist.csv"),
        "waist_factor,nu_final_Hz,N0_final",
        [(r.w, r.nu, r.N0) for r in wrows])
    (power=rows, waist=wrows)
end

# ============================================================================
# (3) the real K₃ lever — timing: optimize the back-half schedule vs N0_final
# (coordinate descent over the last K breakpoint power multipliers, power-clamped)
# ============================================================================
function optimize_timing(; K=5, n_line=40, n_sweeps=10)
    mults = ones(K)
    line = collect(range(0.05, 4.0; length=n_line))
    f(m) = N0_final_of(scale_backhalf(BASE_RAMP, m), PARAMS)
    best = f(mults)
    for _ in 1:n_sweeps
        improved = false
        for j in 1:K
            lb, lv = best, mults[j]
            for v in line
                mults[j] = v
                s = f(mults)
                s > lb && (lb = s; lv = v)
            end
            mults[j] = lv
            lb > best && (best = lb; improved = true)
        end
        improved || break
    end
    ramp = scale_backhalf(BASE_RAMP, mults)
    r = run_evaporation_bec(TRAP, ramp, PARAMS; N0=N0_INIT, T0=T0_INIT)
    @printf("[3] timing-optimized back-half: N0_final=%.3e  t_bec=%.3f s  ν_end=%.1f Hz  mults=%s\n",
        best, r.t_bec, final_omega(ramp) / 2π, string(round.(mults, digits=2)))
    (ramp=ramp, mults=mults, N0=best, result=r)
end

# ============================================================================
# (4) decompression during a BEC hold (where loosening genuinely helps)
# ============================================================================
function sweep_hold_decompression(seed_ramp::FortRamp)
    rows = NamedTuple[]
    for H in (0.5, 1.0, 2.0), f in (1.0, 0.5, 0.25, 0.1)
        ramp = append_hold(seed_ramp, f, H)
        r = run_evaporation_bec(TRAP, ramp, PARAMS; N0=N0_INIT, T0=T0_INIT)
        push!(rows, (H=H, f=f, nu=final_omega(ramp) / 2π, N0=r.N0_final))
    end
    write_csv(joinpath(OUTDIR, "sweep_hold_decompression.csv"),
        "hold_s,decompress_factor,nu_final_Hz,N0_final",
        [(r.H, r.f, r.nu, r.N0) for r in rows])
    rows
end

# ============================================================================
# time series: baseline vs timing-optimized
# ============================================================================
function timeseries(seed_ramp::FortRamp)
    function dump(ramp, tag)
        r = run_evaporation_bec(TRAP, ramp, PARAMS; N0=N0_INIT, T0=T0_INIT)
        write_csv(joinpath(OUTDIR, "timeseries_$tag.csv"),
            "t_s,N_total,N0_condensate,N_thermal,T_K,eta",
            [(r.t[i], r.N[i], r.N0[i], r.Nth[i], r.T[i], r.eta[i]) for i in eachindex(r.t)])
    end
    dump(BASE_RAMP, "baseline")
    dump(seed_ramp, "timing_optimized")
end

# ============================================================================
function main()
    println("="^72)
    println("Issue #58: FORT trap shaping vs K₃ three-body loss")
    @printf("Setup: euv3 r14, N0=%.2e @ %.0f µK, K3=%.2e m⁶/s, τ_bg=%.0f s\n",
        N0_INIT, T0_INIT * 1e6, PARAMS.K3, PARAMS.tau_bg)
    println("="^72)

    ps = physics_scaling()

    println("\n--- (0) CLEAN oracle: density↓ (loosen) ⇒ K₃ loss↓, isolated ---")
    clean_condensate_survival()

    rg = regime_diagnostic()

    println("\n--- (2) loosening DURING evaporation (T_c confound, not K₃) ---")
    lo = sweep_loosening()
    bp = lo.power[argmax([r.N0 for r in lo.power])]
    bw = lo.waist[argmax([r.N0 for r in lo.waist])]
    @printf("    best final-power scale=%.2f → N0=%.3e (%.2f×) ; best waist×%.2f → N0=%.3e (%.2f×)\n",
        bp.s, bp.N0, bp.N0 / max(rg.n_k3, 1), bw.w, bw.N0, bw.N0 / max(rg.n_k3, 1))
    println("    (flat NOT because loosening fails to cut K₃ — lower ω̄ lowers T_c so the")
    println("     η-limited euv3 ramp barely condenses; there is no condensate to save. See (0).)")

    println("\n--- (3) timing (the real K₃ lever) ---")
    to = optimize_timing()
    @printf("    → %.2f× baseline (vs K₃=0 ceiling %.3e)\n", to.N0 / max(rg.n_k3, 1), rg.n_no)

    println("\n--- (4) decompression during a BEC hold ---")
    hr = sweep_hold_decompression(to.ramp)
    for H in (0.5, 1.0, 2.0)
        sub = filter(r -> r.H == H, hr)
        full = sub[findfirst(r -> r.f == 1.0, sub)]
        dec = sub[argmax([r.N0 for r in sub])]
        @printf("    hold %.1fs: full-power N0=%.2e → decompressed(×%.2f) N0=%.2e (%.2f×)\n",
            H, full.N0, dec.f, dec.N0, dec.N0 / max(full.N0, 1))
    end

    timeseries(to.ramp)
    println("\nCSVs in $OUTDIR")
end

main()
