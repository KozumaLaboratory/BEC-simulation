# Issue #58 — dense K₃ / trap-shaping data, all four directions in one driver.
#
# Extends scripts/evaporation_k3_trap_maps.jl (M1–M5) with (1) higher-resolution /
# wider-range versions of the existing maps, (2) new parameter axes not previously
# swept, (3) a denser condensation-TIMING optimization, and (4) two-component
# N0_final lever-combo surfaces. 0-D model, ~40 ms / run, so the grids are dense.
#
# Run:  julia --project=. scripts/evaporation_k3_dense_maps.jl [--smoke]
#   --smoke uses tiny grids (every code path in < 1 min) for pre-launch validation.
#
# Outputs CSVs → figs/k3_dense_maps/ + plot.py for the multi-panel figure.

using SpinorBEC
using Printf

const U = SpinorBEC.Units
const HBAR = U.HBAR
const KB = U.KB
const OUTDIR = joinpath(@__DIR__, "..", "figs", "k3_dense_maps")
mkpath(OUTDIR)
const SMOKE = "--smoke" in ARGS
res(full, smoke) = SMOKE ? smoke : full

const D = euv3_defaults()
const TRAP = euv3_evap_trap()
const PARAMS = EvapParams(; a_s=D.a_s, tau_bg=D.tau_bg, K3=D.K3)
const BASE = euv3_evaporation_ramp()
const M = TRAP.mass
const BEAM_MAX = [6.0, 5.5, 2.0]
const U0 = trap_at(TRAP, BASE.powers_W[:, 1])[1]     # loaded depth (for η_start)

# --- shared model helpers (mirror the existing drivers) ---------------------
tf_peak(N0, ω, as=PARAMS.a_s) = (N0 <= 0 || ω <= 0) ? 0.0 : begin
    aho = sqrt(HBAR / (M * ω))
    μ = 0.5 * HBAR * ω * (15 * N0 * as / aho)^(2 / 5)
    μ / (4π * HBAR^2 * as / M)
end
final_nu(ramp) = trap_at(TRAP, ramp.powers_W[:, end])[2] / 2π
N0f(ramp, p=PARAMS; T0=D.T0) = run_evaporation_bec(TRAP, ramp, p; N0=D.N0, T0=T0).N0_final

# scale the last K back-half breakpoint powers, clamped to the beam maxima
function scale_backhalf(ramp, mults)
    pw = copy(ramp.powers_W)
    off = size(pw, 2) - length(mults)
    for (k, i) in enumerate((off + 1):size(pw, 2)), b in 1:size(pw, 1)
        pw[b, i] = min(pw[b, i] * mults[k], BEAM_MAX[b])
    end
    FortRamp(ramp.times, pw)
end
# append a decompression segment: endpoint powers × f held for τ
append_decomp(ramp, f, τ) = FortRamp(vcat(ramp.times, ramp.times[end] + τ),
    hcat(ramp.powers_W, Float64(f) .* ramp.powers_W[:, end]))

function write_grid(path, xname, xs, yname, ys, Z)
    open(path, "w") do io
        println(io, join([xname, yname, "value"], ","))
        for (i, x) in enumerate(xs), (j, y) in enumerate(ys)
            println(io, join([x, y, Z[i, j]], ","))
        end
    end
    @info "wrote $path"
end
function write_cols(path, header, cols)
    open(path, "w") do io
        println(io, join(header, ","))
        for row in zip(cols...)
            println(io, join(row, ","))
        end
    end
    @info "wrote $path"
end

# ===========================================================================
# DIRECTION 3 (run first — its result seeds directions 2 & 4):
# condensation TIMING — dense coordinate descent over the back-half breakpoint
# power multipliers vs the two-component N0_final. Records the descent history
# and the optimized schedule.
# ===========================================================================
function optimize_timing(; K=6, n_line=res(48, 8), n_sweeps=res(14, 3))
    mults = ones(K)
    line = collect(range(0.05, 4.0; length=n_line))
    f(m) = N0f(scale_backhalf(BASE, m))
    best = f(mults)
    history = [best]
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
        push!(history, best)
        improved || break
    end
    (mults=mults, N0=best, ramp=scale_backhalf(BASE, mults), history=history)
end

# ===========================================================================
# DIRECTION 1: densified / widened versions of the existing maps.
# ===========================================================================
function d1_clean_survival()   # analytic (cheap) → very dense, wider ν & hold
    νs = collect(range(10.0, 400.0; length=res(120, 10)))
    holds = collect(range(0.1, 6.0; length=res(90, 8)))
    Z = Matrix{Float64}(undef, length(νs), length(holds))
    for (i, ν) in enumerate(νs), (j, th) in enumerate(holds)
        ω = 2π * ν
        N0 = 1.0e5
        dt = th / 2000
        for _ in 1:2000
            n0 = tf_peak(N0, ω)
            N0 = max(N0 + dt * (-PARAMS.K3 * (4 / 7) * n0^2 * N0 - N0 / PARAMS.tau_bg), 0.0)
        end
        Z[i, j] = N0 / 1.0e5
    end
    write_grid(joinpath(OUTDIR, "d1_clean_survival.csv"), "nu_Hz", νs, "hold_s", holds, Z)
end

function d1_k3_lifetime()      # analytic → dense, wider ν & N0 (1e3…1e7)
    νs = collect(range(10.0, 400.0; length=res(120, 10)))
    N0s = 10 .^ collect(range(3, 7; length=res(120, 10)))
    Z = Matrix{Float64}(undef, length(νs), length(N0s))
    for (i, ν) in enumerate(νs), (j, N0) in enumerate(N0s)
        n0 = tf_peak(N0, 2π * ν)
        rate = PARAMS.K3 * (4 / 7) * n0^2
        Z[i, j] = rate > 0 ? 1.0 / rate : Inf
    end
    write_grid(joinpath(OUTDIR, "d1_k3_lifetime.csv"), "nu_Hz", νs, "N0", N0s, Z)
end

function d1_decompress(seed)   # ODE → denser (power_factor × decompression τ)
    fs = collect(range(0.01, 1.0; length=res(50, 6)))
    τs = collect(range(0.05, 4.0; length=res(45, 6)))
    Z = Matrix{Float64}(undef, length(fs), length(τs))
    νcol = Float64[]
    for (i, f) in enumerate(fs)
        push!(νcol, final_nu(append_decomp(seed, f, 1.0)))
        for (j, τ) in enumerate(τs)
            Z[i, j] = N0f(append_decomp(seed, f, τ))
        end
    end
    write_grid(joinpath(OUTDIR, "d1_decompress.csv"), "power_factor", fs, "tau_s", τs, Z)
    write_cols(joinpath(OUTDIR, "d1_decompress_nu_axis.csv"),
        ["power_factor", "final_nu_Hz"], (fs, νcol))
    maximum(Z)
end

# ===========================================================================
# DIRECTION 2: new axes.
#   (a) η_start (via initial T0) sweep — baseline vs timing-seed
#   (b) η_start × K₃ surface
#   (c) adiabatic model-fidelity through decompression (T vs ideal T∝ω̄)
# ===========================================================================
function d2_eta_start_1d(seed)
    T0s = collect(range(20e-6, 120e-6; length=res(80, 10)))
    ηcol = [U0 / (KB * T0) for T0 in T0s]
    base = [N0f(BASE; T0=T0) for T0 in T0s]
    timing = [N0f(seed; T0=T0) for T0 in T0s]
    write_cols(joinpath(OUTDIR, "d2_eta_start_1d.csv"),
        ["T0_uK", "eta_start", "N0_baseline", "N0_timing"],
        (T0s .* 1e6, ηcol, base, timing))
end

function d2_eta_k3(seed)
    T0s = collect(range(20e-6, 120e-6; length=res(40, 6)))
    K3s = 10 .^ collect(range(-42, -39.3; length=res(30, 6)))
    Z = Matrix{Float64}(undef, length(T0s), length(K3s))
    ηcol = [U0 / (KB * T0) for T0 in T0s]
    for (i, T0) in enumerate(T0s), (j, K3) in enumerate(K3s)
        p = EvapParams(; a_s=D.a_s, tau_bg=D.tau_bg, K3=K3)
        Z[i, j] = run_evaporation_bec(TRAP, seed, p; N0=D.N0, T0=T0).N0_final
    end
    write_grid(joinpath(OUTDIR, "d2_eta_k3.csv"), "T0_uK", T0s .* 1e6, "K3_m6_s", K3s, Z)
    write_cols(joinpath(OUTDIR, "d2_eta_k3_axis.csv"),
        ["T0_uK", "eta_start"], (T0s .* 1e6, ηcol))
end

# Adiabatic-tracking fidelity: during decompression, an adiabatic thermal gas keeps
# T ∝ ω̄ (so T/T_c is preserved). Compare the model's T(t) to that ideal to expose
# the spurious condensate→thermal melting flagged in the K₃ memory.
function d2_adiabatic(seed)
    t0 = seed.times[end]
    for τ in (0.2, 1.0, 3.0)
        ramp = append_decomp(seed, 0.06, τ)
        r = run_evaporation_bec(TRAP, ramp, PARAMS; N0=D.N0, T0=D.T0, save_every=res(2, 20))
        idx = findall(t -> t >= t0, r.t)
        isempty(idx) && continue
        ω0 = trap_at(TRAP, fort_power_at(ramp, r.t[idx[1]]))[2]
        T_start = r.T[idx[1]]
        rows = NamedTuple[]
        for k in idx
            ωk = trap_at(TRAP, fort_power_at(ramp, r.t[k]))[2]
            Tc = r.N[k] > 0 ? bec_critical_temperature(r.N[k], ωk) : NaN
            T_ideal = T_start * ωk / ω0
            push!(rows, (t=r.t[k] - t0, nu=ωk / 2π, T=r.T[k], T_ideal=T_ideal,
                T_over_Tc=Tc > 0 ? r.T[k] / Tc : NaN,
                cond_frac=r.N[k] > 0 ? r.N0[k] / r.N[k] : NaN))
        end
        write_cols(joinpath(OUTDIR, "d2_adiabatic_tau$(τ).csv"),
            ["t_s", "nu_Hz", "T_K", "T_ideal_K", "T_over_Tc", "cond_frac"],
            ([r.t for r in rows], [r.nu for r in rows], [r.T for r in rows],
                [r.T_ideal for r in rows], [r.T_over_Tc for r in rows],
                [r.cond_frac for r in rows]))
    end
end

# ===========================================================================
# DIRECTION 4: two-component N0_final lever-combo surfaces.
#   timing strength s ∈ [0,1] blends baseline (s=0) → optimized mults (s=1).
#   (a) timing s × decompress factor f  (the headline optimization surface)
#   (b) K₃ × timing s × decompress f    (robustness 3D, written as (K3,s,f) rows)
# ===========================================================================
timing_ramp(opt_mults, s) = scale_backhalf(BASE, 1 .+ s .* (opt_mults .- 1))
lever(opt_mults, s, f) = append_decomp(timing_ramp(opt_mults, s), f, 1.0)

function d4_timing_decompress(opt_mults)
    ss = collect(range(0.0, 1.0; length=res(40, 6)))
    fs = collect(range(0.05, 1.0; length=res(40, 6)))
    Z = Matrix{Float64}(undef, length(ss), length(fs))
    for (i, s) in enumerate(ss), (j, f) in enumerate(fs)
        Z[i, j] = N0f(lever(opt_mults, s, f))
    end
    write_grid(joinpath(OUTDIR, "d4_timing_decompress.csv"),
        "timing_strength", ss, "decompress_factor", fs, Z)
    maximum(Z)
end

function d4_k3_timing_decompress(opt_mults)
    K3s = 10 .^ collect(range(-42, -39.3; length=res(20, 4)))
    ss = collect(range(0.0, 1.0; length=res(12, 3)))
    fs = collect(range(0.1, 1.0; length=res(12, 3)))
    open(joinpath(OUTDIR, "d4_k3_timing_decompress.csv"), "w") do io
        println(io, "K3_m6_s,timing_strength,decompress_factor,N0_final")
        for K3 in K3s
            p = EvapParams(; a_s=D.a_s, tau_bg=D.tau_bg, K3=K3)
            for s in ss, f in fs
                n0 = run_evaporation_bec(TRAP, lever(opt_mults, s, f), p;
                    N0=D.N0, T0=D.T0).N0_final
                println(io, join([K3, s, f, n0], ","))
            end
        end
    end
    @info "wrote $(joinpath(OUTDIR, "d4_k3_timing_decompress.csv"))"
end

# ===========================================================================
function main()
    println("="^72)
    println("Issue #58 — dense K₃ / trap-shaping maps (4 directions)" * (SMOKE ? "  [SMOKE]" : ""))
    @printf("euv3 r14: N0=%.2e @ %.0f µK, K3=%.2e, τ_bg=%.0f s, U0/kB=%.1f µK\n",
        D.N0, D.T0 * 1e6, PARAMS.K3, PARAMS.tau_bg, U0 / KB * 1e6)
    println("="^72)

    println("\n[3] condensation-timing coordinate descent …")
    @time to = optimize_timing()
    @printf("    optimized N0=%.3e  (baseline %.3e, %.2f×)  mults=%s\n",
        to.N0, N0f(BASE), to.N0 / max(N0f(BASE), 1), string(round.(to.mults, digits=2)))
    # optimized schedule + descent history
    off = size(BASE.powers_W, 2) - length(to.mults)
    opt = scale_backhalf(BASE, to.mults)
    write_cols(joinpath(OUTDIR, "d3_timing_schedule.csv"),
        ["breakpoint", "time_s", "H_base_W", "V_base_W", "H_opt_W", "V_opt_W"],
        (1:size(BASE.powers_W, 2), BASE.times,
            BASE.powers_W[1, :], BASE.powers_W[2, :], opt.powers_W[1, :], opt.powers_W[2, :]))
    write_cols(joinpath(OUTDIR, "d3_timing_convergence.csv"),
        ["sweep", "best_N0"], (0:(length(to.history)-1), to.history))
    seed = to.ramp

    println("\n[1] densified existing maps …")
    d1_clean_survival()
    d1_k3_lifetime()
    @time bestdec = d1_decompress(seed)
    @printf("    best decompress-after-BEC N0=%.3e\n", bestdec)

    println("\n[2] new axes (η_start, η×K₃, adiabatic fidelity) …")
    @time d2_eta_start_1d(seed)
    @time d2_eta_k3(seed)
    d2_adiabatic(seed)

    println("\n[4] two-component N0_final lever-combo surfaces …")
    @time best4 = d4_timing_decompress(to.mults)
    @printf("    best timing×decompress N0=%.3e (%.2f× baseline)\n",
        best4, best4 / max(N0f(BASE), 1))
    @time d4_k3_timing_decompress(to.mults)

    println("\nall CSVs → $OUTDIR")
end

main()
