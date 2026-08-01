#!/usr/bin/env julia
# docs/guides/figures/eu_kz_exponent.jl
#
# Kibble–Zurek exponent from the full SPGPE: spontaneous vortices left behind by
# a finite-rate quench through the condensation transition,
#
#     N_v ∝ τ_Q^(−α)
#
# and α is what gets reported. The absolute N_v is NOT reported.
#
# WHY AN EXPONENT. Absolute condensate numbers are not an output of this method:
# in a grand-canonical SPGPE, μ below ε₀ forbids a condensate and μ above it sets
# the equilibrium size via μ = ε₀ + c₀n₀, so prescribing μ prescribes N₀ (see
# docs/guides/spgpe.md). A scaling exponent has none of that dependence — it is a
# ratio, measured at FIXED cutoff with only the quench rate varying, which is the
# regime the guide already flags as the clean one for a c-field.
#
# PROTOCOL. Hold the reservoir at (T_hot, μ) with the thermal cloud dominant,
# equilibrate, then ramp T linearly to T_cold over τ_Q at fixed μ, hold briefly,
# and count phase singularities. γ and ℳ̄ are FIXED, not reservoir-derived, so the
# quench rate is the only thing that varies between points — a reservoir-derived γ
# would drift with T and confound the exponent with its temperature dependence.
#
# SCALAR LIMIT FIRST. This driver runs c₁ = 0 with no DDI: a positive control
# against a known scalar exponent, and the run that tells us the measurable τ_Q
# window (too fast ⇒ no condensate, too slow ⇒ zero vortices) before any Eu
# result is attempted.
#
# Run (CPU smoke): julia --project=. docs/guides/figures/eu_kz_exponent.jl --smoke
#
# Provenance:
# - shows: DRIVER — computes the CSV behind eu_kz_exponent.png
# - depends on: the vortex counter gate, test/analysis/test_vortex_counter_control.jl

using SpinorBEC
using FFTW
using Printf
using Statistics

const OUTDIR = get(ENV, "SPINORBEC_FIGS_ROOT",
    joinpath(@__DIR__, "..", "..", "..", "figs", "eu_kz_exponent"))

const KZ_ATOM = Rb87                      # F=1; only the stretched component is used

"""
    kz_trajectory(; …) -> (; n_vortices, N_C, N0_proxy)

One quench realisation. Returns the vortex-line count on the populated component
after the hold, plus `N_C` so a run that failed to condense can be told apart
from one that condensed without defects — those are opposite outcomes and a bare
`N_v = 0` conflates them.
"""
function kz_trajectory(;
    grid, c0, mu, T_hot, T_cold, tau_Q, t_equil, t_hold, gamma, M, k_cut,
    dt, seed, backend, min_density_frac=0.05, c1=0.0, spinor::Bool=false,
)
    D = SpinSystem(KZ_ATOM.F).n_components
    sp = SimParams(; dt, n_steps=1, imaginary_time=false, save_every=1, normalize_every=0)
    ws = make_workspace(; grid, atom=KZ_ATOM,
        interactions=InteractionParams(Dict{Int, Float64}(0 => c0, 1 => c1)),
        potential=HarmonicTrap{3}((1.0, 1.0, 1.0)), sim_params=sp, backend)
    seed_device_rng!(backend, seed)
    fill!(ws.state.psi, 0)

    # T(t): hold hot, linear ramp over tau_Q, hold cold. mu fixed throughout, so
    # the transition is crossed by cooling rather than by pumping atoms in.
    T_of = PiecewiseLinearWaveform(
        [0.0, t_equil, t_equil + tau_Q, t_equil + tau_Q + t_hold],
        [T_hot, T_hot, T_cold, T_cold])
    res = SPGPEReservoir(; T=T_of, mu=mu, a_s=0.01, k_cut=k_cut, gamma=gamma, M=M)

    n_steps = round(Int, (t_equil + tau_Q + t_hold) / dt)
    t = 0.0
    for s in 1:n_steps
        split_step!(ws)
        apply_spgpe_step!(ws, res, dt; t=t, seed=seed + s)
        # Scalar limit keeps the empty spin channels empty so reservoir noise
        # cannot fill them. With `spinor=true` every component evolves — that is
        # the point — so the zeroing must NOT happen.
        if !spinor
            @views for c in 1:(D - 1)
                ws.state.psi[:, :, :, c] .= 0
            end
        end
        t += dt
    end

    psi = Array(ws.state.psi)
    dV = cell_volume(grid)
    # Coherence length alongside the count. g1 needs HOST plans; psi is already
    # on the host here. Computing it inline avoids saving snapshots just to
    # post-process them.
    hplans = make_fft_plans(grid.config.n_points; flags=FFTW.ESTIMATE)
    rr, g1 = first_order_correlation(psi, grid, hplans)
    _cl = coherence_length(rr, g1)
    ξ_hat = _cl.xi

    lines = extract_vortex_lines_per_m(psi, grid; min_density_frac)
    # Per-component counts. In a spinor the defect need not live on one component,
    # and which components carry it is exactly what step 1 is asking — so the
    # counter's own per-m breakdown is reported rather than collapsed to a scalar.
    F = KZ_ATOM.F
    per_m = Dict(m => (haskey(lines, m >= 0 ? "+$m" : "$m") ?
                       length(lines[m >= 0 ? "+$m" : "$m"]) : 0) for m in (-F):F)
    pops = [real(sum(abs2, view(psi, :, :, :, c))) * dV for c in 1:size(psi, 4)]
    (; n_vortices=per_m[-F], per_m, pops, xi_hat=ξ_hat, f_inf=_cl.f_inf,
        N_C=real(sum(abs2, psi)) * dV)
end

"""
    kz_scan(; …) -> NamedTuple

`N_v` vs `τ_Q`, ensemble-averaged, and the fitted exponent `α` from a
least-squares line through `log N_v` vs `log τ_Q`.

Points with `N_v = 0` across the whole ensemble are EXCLUDED from the fit and
reported separately: a log fit cannot take them, and silently dropping them would
turn "the slow end saturates at zero defects" into a steeper apparent exponent.
"""
function kz_scan(;
    grid_n::Int=138, box::Float64=20.1, c0::Float64=0.19,
    mu::Float64=15.0, T_hot::Float64=30.0, T_cold::Float64=2.0,
    # Window found by the scalar control, not guessed: at 48³ the first scan used
    # τ_Q = 20…320 and every point came back with ZERO vortices at healthy N_C —
    # condensed, but too slowly to trap defects. The smoke at τ_Q = 8 had 12.5.
    # So the measurable band is the FAST side, and 32 is kept as the bridge to the
    # zero-defect regime whose upper edge the first scan established.
    tau_Qs=(2.0, 4.0, 8.0, 16.0, 32.0),
    t_equil::Float64=40.0, t_hold::Float64=20.0,
    gamma::Float64=0.002, M::Float64=0.0, dt::Float64=0.002,
    n_seed::Int=8, backend=CPUBackend(), tag::String="kz_scalar",
    k_cut_mult::Float64=1.0, c1::Float64=0.0, spinor::Bool=false,
)
    grid = make_grid(GridConfig((grid_n, grid_n, grid_n), (box, box, box)))
    # C region holds the hot cloud. `k_cut_mult` moves the boundary WITHOUT
    # touching the physics, which is the only way to show that a reported exponent
    # is a property of the quench and not of where the classical region was cut.
    k_cut = k_cut_mult * sqrt(2 * (mu + T_hot))
    k_max = π / (box / grid_n)
    k_max > k_cut || error("grid_n=$grid_n cannot resolve k_cut=$(round(k_cut; digits=2)) " *
                           "(k_max=$(round(k_max; digits=2))) at box=$box")

    # TWO preconditions, both measured rather than guessed (see
    # test/analysis/test_vortex_counter_control.jl):
    #
    #  (i) dx ≤ 0.8ξ or the COUNTER invents defects. On a noisy vortex-free field
    #      it returned 13 at dx/ξ = 1.44 and 0 at 1.01 and 0.76 — and a 24³ smoke
    #      "measured" 12.5 in exactly that regime.
    # (ii) R_TF/ξ = 2μ must be large enough to host defects at all. At 2μ = 10 the
    #      quench produced ZERO at every rate, converged across 24³/48³/64³, which
    #      is a real zero and not a resolution artefact. Defects need 2μ ≳ 30.
    ξ = 1 / sqrt(2 * mu)
    dx = box / grid_n
    dx <= 0.8ξ || error(
        "dx/ξ = $(round(dx / ξ; digits=2)) > 0.8: the vortex counter invents defects " *
        "here (13 on a vortex-FREE field at 1.44). Need grid_n ≥ " *
        "$(ceil(Int, box / (0.8ξ))) at box=$box, or a larger μ.")
    R_over_ξ = 2 * mu
    R_over_ξ >= 25 || @warn "R_TF/ξ = 2μ is small; at 10 the quench gave zero defects " *
                            "at every rate (converged). Expect no signal." R_over_ξ
    @printf("  dx/ξ = %.2f (need ≤0.80)   R_TF/ξ = 2μ = %.0f (need ≳30)\n", dx / ξ, R_over_ξ)
    # Header must state the configuration ACTUALLY running. It was hardcoded to
    # "scalar limit: c₁=0, no DDI" and printed that while the spinor step ran with
    # c₁ = -0.0095 — a log that disagrees with the run is how a wrong setting
    # survives review.
    @printf("=== KZ scan (%s) ===\n",
        spinor ? "SPINOR: c₁=$(c1), all components evolve, no DDI" :
        "scalar limit: c₁=0, no DDI")
    @printf("  grid %d³ box %.1f   k_cut %.2f (k_max %.2f)   μ=%.1f  T %.1f→%.1f\n",
        grid_n, box, k_cut, k_max, mu, T_hot, T_cold)
    @printf("  γ=%.3g (FIXED) ℳ̄=%.3g   τ_Q %s   %d seeds\n",
        gamma, M, string(tau_Qs), n_seed)
    flush(stdout)

    means = Float64[]
    sems = Float64[]
    ncs = Float64[]
    xihats = Float64[]
    xisems = Float64[]
    fmeans = Float64[]
    nfins = Int[]
    @printf("\n  %-8s %-10s %-10s %-10s %-9s %-8s %-6s %-8s\n",
        "τ_Q", "⟨N_v⟩", "sem", "⟨N_C⟩", "⟨ξ̂⟩", "sem", "n_fin", "⟨f_∞⟩")
    for τ in tau_Qs
        vs = Int[]
        ncl = Float64[]
        xis = Float64[]
        fis = Float64[]
        for s in 1:n_seed
            r = kz_trajectory(; grid, c0, mu, T_hot, T_cold, tau_Q=τ,
                t_equil, t_hold, gamma, M, k_cut, dt,
                seed=10_000 + Int(round(τ)) * 100 + s, backend, c1, spinor)
            spinor && s == 1 && @printf("    [m-breakdown τ=%.0f seed1] %s  pops %s\n",
                τ, string(sort(collect(r.per_m))),
                string(round.(r.pops; sigdigits=3)))
            push!(vs, r.n_vortices)
            push!(ncl, r.N_C)
            isfinite(r.xi_hat) && push!(xis, r.xi_hat)
            isfinite(r.f_inf) && push!(fis, r.f_inf)
        end
        m = mean(vs)
        push!(means, m)
        push!(sems, n_seed > 1 ? std(vs) / sqrt(n_seed) : 0.0)
        push!(ncs, mean(ncl))
        ξm = isempty(xis) ? NaN : mean(xis)
        ξs = length(xis) > 1 ? std(xis) / sqrt(length(xis)) : 0.0
        push!(xihats, ξm); push!(xisems, ξs)
        push!(fmeans, isempty(fis) ? NaN : mean(fis))
        push!(nfins, length(xis))
        # n_fin and f_inf are printed because their absence hid a broken ξ̂: the
        # scan once reported sem = 0.000 at every τ_Q, which is what a single
        # contributing seed (or a constant condensate fraction read as a length)
        # looks like. Zero scatter across independent stochastic seeds is a bug
        # signal, not a tight measurement.
        @printf("  %-8.0f %-10.3f %-10.3f %-10.4g %-9.3f %-8.3f %-6d %-8.3f\n",
            τ, m, sems[end], ncs[end], ξm, ξs, length(xis), fmeans[end])
        flush(stdout)
    end

    keep = findall(m -> m > 0, means)
    α, α_err = NaN, NaN
    if length(keep) >= 3
        x = log.(collect(tau_Qs)[keep])
        y = log.(means[keep])
        n = length(x)
        x̄, ȳ = mean(x), mean(y)
        Sxx = sum((x .- x̄) .^ 2)
        slope = sum((x .- x̄) .* (y .- ȳ)) / Sxx
        resid = y .- (ȳ .+ slope .* (x .- x̄))
        α, α_err = -slope, sqrt(sum(resid .^ 2) / max(n - 2, 1) / Sxx)
        @printf("\n  α = %.3f ± %.3f   (N_v ∝ τ_Q^-α, %d of %d points)\n",
            α, α_err, length(keep), length(tau_Qs))
    else
        @printf("\n  too few non-zero points (%d) to fit — widen the τ_Q window\n",
            length(keep))
    end
    length(keep) == length(tau_Qs) ||
        @printf("  EXCLUDED (⟨N_v⟩=0): τ_Q = %s\n",
            string(collect(tau_Qs)[setdiff(eachindex(means), keep)]))

    mkpath(OUTDIR)
    csv = joinpath(OUTDIR, "$(tag).csv")
    open(csv, "w") do io
        println(io, "# alpha=$(α) alpha_err=$(α_err) gamma=$gamma mu=$mu k_cut=$k_cut grid=$grid_n")
        println(io, "tau_Q,N_v_mean,N_v_sem,N_C_mean,xi_hat_mean,xi_hat_sem,n_finite,f_inf_mean")
        for (i, τ) in enumerate(tau_Qs)
            @printf(io, "%.4f,%.6f,%.6f,%.6g,%.6f,%.6f,%d,%.6f\n",
                τ, means[i], sems[i], ncs[i], xihats[i], xisems[i], nfins[i], fmeans[i])
        end
    end
    @printf("  wrote %s\n", csv)
    (; tau_Qs=collect(tau_Qs), means, sems, ncs, alpha=α, alpha_err=α_err, csv, k_cut)
end

# --smoke: every code path on a small grid and a short quench. NOT physics —
# 2 seeds and 3 rates cannot resolve an exponent.
function smoke(; backend=CPUBackend())
    # Smoke must satisfy dx ≤ 0.8ξ like anything else, or the counter invents
    # defects and the smoke "passes" on fiction — which is what the first one did.
    kz_scan(; grid_n=32, box=6.0, mu=5.0, T_hot=12.0, T_cold=1.0,
        tau_Qs=(4.0, 8.0, 16.0), t_equil=8.0, t_hold=4.0, n_seed=2,
        backend, tag="kz_smoke")
end

"""
    kz_merge(; dir=OUTDIR) -> (; tau_Qs, means, sems, alpha, alpha_err)

Merge the per-rate CSVs written by the `rate<τ>` jobs and fit
`N_v ∝ τ_Q^{-α}`. Split across jobs because one rate at 138³ is ~2 h and five do
not fit a single walltime; the fit has to happen after the fact rather than inside
the scan.

Zero-mean rates are excluded from the fit and named, for the same reason as in
`kz_scan`: a log fit cannot take them and dropping them quietly steepens the
apparent exponent.
"""
function kz_merge(; dir::String=OUTDIR)
    files = filter(f -> startswith(f, "kz_rate") && endswith(f, ".csv"), readdir(dir))
    isempty(files) && error("kz_merge: no kz_rate*.csv in $dir")
    τs, ms, ss, ncs = Float64[], Float64[], Float64[], Float64[]
    for f in files
        for ln in readlines(joinpath(dir, f))
            (isempty(ln) || startswith(ln, "#") || startswith(ln, "tau_Q")) && continue
            p = split(ln, ",")
            push!(τs, parse(Float64, p[1]));  push!(ms, parse(Float64, p[2]))
            push!(ss, parse(Float64, p[3]));  push!(ncs, parse(Float64, p[4]))
        end
    end
    o = sortperm(τs)
    τs, ms, ss, ncs = τs[o], ms[o], ss[o], ncs[o]
    @printf("%-8s %-10s %-10s %-10s\n", "τ_Q", "⟨N_v⟩", "sem", "⟨N_C⟩")
    for i in eachindex(τs)
        @printf("%-8.0f %-10.3f %-10.3f %-10.4g\n", τs[i], ms[i], ss[i], ncs[i])
    end
    keep = findall(>(0), ms)
    α, αe = NaN, NaN
    if length(keep) >= 3
        x, y = log.(τs[keep]), log.(ms[keep])
        x̄, ȳ = mean(x), mean(y)
        Sxx = sum((x .- x̄) .^ 2)
        sl = sum((x .- x̄) .* (y .- ȳ)) / Sxx
        r = y .- (ȳ .+ sl .* (x .- x̄))
        α, αe = -sl, sqrt(sum(r .^ 2) / max(length(x) - 2, 1) / Sxx)
        @printf("\nα = %.3f ± %.3f   (N_v ∝ τ_Q^-α, %d of %d rates)\n",
            α, αe, length(keep), length(τs))
    else
        @printf("\nonly %d non-zero rates — cannot fit\n", length(keep))
    end
    length(keep) == length(τs) ||
        @printf("EXCLUDED (⟨N_v⟩=0): τ_Q = %s\n", string(τs[setdiff(eachindex(ms), keep)]))
    (; tau_Qs=τs, means=ms, sems=ss, alpha=α, alpha_err=αe)
end

function main(mode::String="smoke"; backend=CPUBackend())
    if mode == "smoke"
        smoke(; backend)
    elseif startswith(mode, "xi")
        # Re-measure the SAME scalar quench with the coherence length instead of
        # the defect count. PREDICTION, recorded before running: in 3D the number
        # of vortex lines through the cloud goes as (R/ξ̂)², so N_v ∝ ξ̂^-2 and
        #
        #     b = alpha/2 = 0.47 ± 0.04     from alpha = 0.93 ± 0.08
        #
        # Agreement means two independent observables on the same physics. A miss
        # means one of them is measuring something else, and the count is the one
        # already known to be fragile.
        τ = parse(Float64, mode[3:end])
        kz_scan(; tau_Qs=(τ,), t_hold=1.0, n_seed=8, backend,
            tag="kz_xi_r$(replace(string(τ), "." => "p"))")
    elseif mode == "spinor1"
        # Step 1 of the ladder: c1 ON, DDI still off, F=1. Cheapest possible change
        # from the validated scalar case, and it settles the question every later
        # step depends on — in a spinor the counter reports per-m, and which
        # components carry the defect is undefined until measured. Counting the
        # stretched component alone (what the scalar runs did) is an assumption,
        # not a result. One rate: tau_Q = 4, where the scalar gave 86.75.
        kz_scan(; tau_Qs=(4.0,), t_hold=1.0, n_seed=8, c1=-0.0095, spinor=true,
            backend, tag="kz_spinor1")
    elseif startswith(mode, "kcut")
        # Cutoff-robustness of alpha. The whole justification for reporting an
        # exponent instead of a defect count is that a ratio at FIXED cutoff is
        # clean where an absolute number is not — which is worth nothing until
        # alpha is shown to survive moving the cutoff. Mode carries rate and
        # multiplier: "kcut8_1.2" -> tau_Q = 8 at 1.2x k_cut.
        body = mode[5:end]
        rs, ms = split(body, "_")
        τ, km = parse(Float64, rs), parse(Float64, ms)
        kz_scan(; tau_Qs=(τ,), t_hold=1.0, n_seed=8, k_cut_mult=km, backend,
            tag="kz_kcut$(replace(ms, "." => "p"))_r$(replace(rs, "." => "p"))")
    elseif startswith(mode, "rate")
        # One rate per job: at 138³ a single rate with 8 seeds is ~2 h, and five of
        # them in one job does not fit h_rt. Mode string carries the rate, e.g.
        # "rate8" -> tau_Q = 8. Results are merged by kz_merge over the CSVs.
        τ = parse(Float64, mode[5:end])
        kz_scan(; tau_Qs=(τ,), t_hold=1.0, n_seed=8, backend,
            tag="kz_rate$(replace(string(τ), "." => "p"))")
    elseif mode == "probe_lowgamma"
        # gamma is the last suspect, and the arithmetic says it should have been the
        # first. Damping removes a defect in ~1/(2 gamma dmu) ~ 1/(2*0.02*13) ~ 2
        # internal units, against a quench lasting tau_Q = 8: damping wins
        # throughout, so nothing can freeze in. KZ needs the opposite ordering.
        # gamma/10 puts the damping time at ~19 > 8.
        #
        # Three things are already excluded at healthy N_C: system size (R/xi 10 and
        # 30 both gave zero), and the post-quench hold (removing it changed nothing).
        kz_scan(; tau_Qs=(8.0,), t_hold=1.0, gamma=0.002, n_seed=4, backend,
            tag="kz_probe_lowgamma")
    elseif mode == "probe_nohold"
        # t_hold is the suspect. mu=15 / R_TF/xi=30 / 138^3 returned zero defects at
        # healthy N_C (2.45e4), and so did mu=5 / R/xi=10 — tripling the system size
        # changed nothing, which is hard to explain by "no room for a frozen
        # correlation length". The protocol here held the field for 20 internal units
        # AFTER the quench, and damping anneals defects away in that window; Weiler
        # et al. measure with the hold minimised. Same cost as the probe, and it is
        # the more upstream cause.
        kz_scan(; tau_Qs=(8.0,), t_hold=1.0, n_seed=4, backend, tag="kz_probe_nohold")
    elseif mode == "probe"
        # ONE rate before committing ~25 GPU-hours to five. The scan is only worth
        # running if a defect appears at all at this system size: mu = 5 gave zero
        # everywhere (converged), and mu = 15 buys R/xi = 30 but costs 24x. If this
        # comes back empty, the remaining four rates would be spent confirming it.
        kz_scan(; tau_Qs=(8.0,), n_seed=4, backend, tag="kz_probe")
    elseif mode == "merge"
        kz_merge()
    elseif mode == "scalar"
        kz_scan(; backend, tag="kz_scalar")
    else
        error("unknown mode: $mode (smoke | scalar)")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    mode = "--smoke" in ARGS ? "smoke" : (isempty(ARGS) ? "smoke" : ARGS[1])
    want_gpu = get(ENV, "SBEC_KZ_BACKEND", "cpu") == "gpu"
    want_gpu && @eval import CUDA
    main(mode; backend=want_gpu ? CUDABackend() : CPUBackend())
end
