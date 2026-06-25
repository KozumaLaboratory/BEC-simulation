# Issue #58 — comprehensive K₃ / trap-shaping maps (dense parameter scans).
#
# Builds on the corrected conclusion (lower density = loosen trap = less K₃ loss; the
# subtlety is the ω̄–T_c coupling). The 0-D model is ms-scale per run, so we sweep dense
# 2-D grids. Five maps, all written as CSVs for figs/k3_trap_maps/plot.py:
#   M1  clean oracle surface     : held-BEC survival over (ν̄ × hold time)
#   M2  decompress-after-BEC     : N0_final over (final ν̄ × decompression duration)
#   M3  regime map               : N0_final over (T0/η_start × final-power scale)
#   M4  K₃ robustness            : N0_final of {baseline, timing, decompress} vs K₃
#   M5  adiabatic tracking       : T/T_c through decompression at several rates

using SpinorBEC
using Printf

const U = SpinorBEC.Units
const HBAR = U.HBAR
const KB = U.KB
const OUTDIR = joinpath(@__DIR__, "..", "figs", "k3_trap_maps")
mkpath(OUTDIR)

const D = euv3_defaults()
const TRAP = euv3_evap_trap()
const PARAMS = EvapParams(; a_s=D.a_s, tau_bg=D.tau_bg, K3=D.K3)
const BASE = euv3_evaporation_ramp()
const M = TRAP.mass
const BEAM_MAX = [6.0, 5.5, 2.0]
const TIMING_MULTS = [2.58, 3.09, 4.0, 2.78, 1.47]   # the form-late seed from the main driver

tf_peak(N0, ω, as=PARAMS.a_s) = (N0 <= 0 || ω <= 0) ? 0.0 : begin
    aho = sqrt(HBAR / (M * ω))
    μ = 0.5 * HBAR * ω * (15 * N0 * as / aho)^(2 / 5)
    μ / (4π * HBAR^2 * as / M)
end
final_nu(ramp) = trap_at(TRAP, ramp.powers_W[:, end])[2] / 2π

function scale_backhalf(ramp, mults)
    pw = copy(ramp.powers_W)
    off = size(pw, 2) - length(mults)
    for (k, i) in enumerate((off + 1):size(pw, 2)), b in 1:size(pw, 1)
        pw[b, i] = min(pw[b, i] * mults[k], BEAM_MAX[b])
    end
    FortRamp(ramp.times, pw)
end
append_decomp(ramp, f, τ) = FortRamp(vcat(ramp.times, ramp.times[end] + τ),
    hcat(ramp.powers_W, Float64(f) .* ramp.powers_W[:, end]))
const SEED = scale_backhalf(BASE, TIMING_MULTS)   # forms ~1.1e4 condensate

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

# ---- M1: clean held-condensate survival over (ν̄ × hold) -------------------
function map1()
    νs = collect(range(10.0, 250.0; length=40))
    holds = collect(range(0.1, 3.0; length=30))
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
    write_grid(joinpath(OUTDIR, "m1_clean_survival.csv"), "nu_Hz", νs, "hold_s", holds, Z)
    @printf("M1 clean survival: %.0f×%.0f grid\n", length(νs), length(holds))
end

# ---- M2: decompress-after-BEC, N0_final over (final ν̄ × decompression τ) ----
function map2()
    fs = collect(range(0.01, 1.0; length=34))     # endpoint power factor → final ν̄
    τs = collect(range(0.05, 3.0; length=30))      # decompression+hold duration
    Z = Matrix{Float64}(undef, length(fs), length(τs))
    νcol = Float64[]
    for (i, f) in enumerate(fs)
        push!(νcol, final_nu(append_decomp(SEED, f, 1.0)))
        for (j, τ) in enumerate(τs)
            r = run_evaporation_bec(TRAP, append_decomp(SEED, f, τ), PARAMS; N0=D.N0, T0=D.T0)
            Z[i, j] = r.N0_final
        end
    end
    write_grid(joinpath(OUTDIR, "m2_decompress.csv"), "power_factor", fs, "tau_s", τs, Z)
    write_cols(joinpath(OUTDIR, "m2_nu_axis.csv"), ["power_factor", "final_nu_Hz"], (fs, νcol))
    @printf("M2 decompress-after-BEC: %.0f×%.0f grid  (best N0=%.2e)\n",
        length(fs), length(τs), maximum(Z))
end

# ---- M3: condensate K₃ lifetime τ = 1/(K₃⟨n²⟩) over (ν̄ × N₀) ---------------
# Analytic: how long before three-body loss e-folds a condensate of N₀ atoms in a trap
# of mean frequency ν̄. Directly visualises "loosen the trap → longer-lived BEC".
function map3()
    νs = collect(range(10.0, 250.0; length=60))
    N0s = 10 .^ collect(range(3, 6; length=60))     # 1e3 … 1e6 condensate atoms
    Z = Matrix{Float64}(undef, length(νs), length(N0s))
    for (i, ν) in enumerate(νs), (j, N0) in enumerate(N0s)
        n0 = tf_peak(N0, 2π * ν)
        rate = PARAMS.K3 * (4 / 7) * n0^2          # per-atom 1/e loss rate
        Z[i, j] = rate > 0 ? 1.0 / rate : Inf      # lifetime [s]
    end
    write_grid(joinpath(OUTDIR, "m3_k3_lifetime.csv"), "nu_Hz", νs, "N0", N0s, Z)
    @printf("M3 K₃ lifetime: %.0f×%.0f grid  (range %.1e … %.1e s)\n",
        length(νs), length(N0s), minimum(Z), maximum(Z))
end

# ---- M4: K₃ robustness of the three levers ---------------------------------
function map4()
    K3s = 10 .^ collect(range(-42, -39.3; length=30))
    base, timing, decomp = Float64[], Float64[], Float64[]
    decomp_ramp = append_decomp(SEED, 0.1, 1.0)
    for K3 in K3s
        p = EvapParams(; a_s=D.a_s, tau_bg=D.tau_bg, K3=K3)
        push!(base, run_evaporation_bec(TRAP, BASE, p; N0=D.N0, T0=D.T0).N0_final)
        push!(timing, run_evaporation_bec(TRAP, SEED, p; N0=D.N0, T0=D.T0).N0_final)
        push!(decomp, run_evaporation_bec(TRAP, decomp_ramp, p; N0=D.N0, T0=D.T0).N0_final)
    end
    write_cols(joinpath(OUTDIR, "m4_k3_robustness.csv"),
        ["K3_m6_s", "N0_baseline", "N0_timing", "N0_decompress"], (K3s, base, timing, decomp))
    @printf("M4 K₃ robustness: %d points over K₃ ∈ [%.0e, %.0e]\n", length(K3s), K3s[1], K3s[end])
end

# ---- M5: adiabatic tracking — T/T_c through decompression at several rates --
function map5()
    cols = Dict{String, Vector{Float64}}()
    tgrid = nothing
    for τ in (0.2, 1.0, 3.0)
        r = run_evaporation_bec(TRAP, append_decomp(SEED, 0.06, τ), PARAMS;
            N0=D.N0, T0=D.T0, save_every=3)
        # restrict to the decompression window (after the seed ends)
        t0 = SEED.times[end]
        idx = findall(t -> t >= t0, r.t)
        ts = [r.t[k] - t0 for k in idx]
        ratio = Float64[]
        for k in idx
            ωk = 2π * 100.0   # placeholder, recomputed below
            ωk = trap_at(TRAP, fort_power_at(append_decomp(SEED, 0.06, τ), r.t[k]))[2]
            Tc = r.N[k] > 0 ? bec_critical_temperature(r.N[k], ωk) : NaN
            push!(ratio, Tc > 0 ? r.T[k] / Tc : NaN)
        end
        cols["t_tau$(τ)"] = ts
        cols["ratio_tau$(τ)"] = ratio
    end
    # write each rate as its own CSV (uneven lengths)
    for τ in (0.2, 1.0, 3.0)
        write_cols(joinpath(OUTDIR, "m5_tracking_tau$(τ).csv"),
            ["t_s", "T_over_Tc"], (cols["t_tau$(τ)"], cols["ratio_tau$(τ)"]))
    end
    @printf("M5 adiabatic tracking: 3 decompression rates\n")
end

println("="^60)
println("Issue #58 — comprehensive K₃ / trap-shaping maps")
println("="^60)
@time map1()
@time map2()
@time map3()
@time map4()
@time map5()
println("\nall CSVs → $OUTDIR")
