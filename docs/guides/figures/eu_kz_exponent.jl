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
    dt, seed, backend, min_density_frac=0.05,
)
    D = SpinSystem(KZ_ATOM.F).n_components
    sp = SimParams(; dt, n_steps=1, imaginary_time=false, save_every=1, normalize_every=0)
    ws = make_workspace(; grid, atom=KZ_ATOM,
        interactions=InteractionParams(Dict{Int, Float64}(0 => c0)),
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
        @views for c in 1:(D - 1)
            ws.state.psi[:, :, :, c] .= 0
        end
        t += dt
    end

    psi = Array(ws.state.psi)
    dV = cell_volume(grid)
    lines = extract_vortex_lines_per_m(psi, grid; min_density_frac)
    key = "-$(KZ_ATOM.F)"
    (; n_vortices=haskey(lines, key) ? length(lines[key]) : 0,
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
    gamma::Float64=0.02, M::Float64=0.0, dt::Float64=0.002,
    n_seed::Int=8, backend=CPUBackend(), tag::String="kz_scalar",
)
    grid = make_grid(GridConfig((grid_n, grid_n, grid_n), (box, box, box)))
    k_cut = sqrt(2 * (mu + T_hot))          # C region holds the hot cloud
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
    @printf("=== KZ scan (scalar limit: c₁=0, no DDI) ===\n")
    @printf("  grid %d³ box %.1f   k_cut %.2f (k_max %.2f)   μ=%.1f  T %.1f→%.1f\n",
        grid_n, box, k_cut, k_max, mu, T_hot, T_cold)
    @printf("  γ=%.3g (FIXED) ℳ̄=%.3g   τ_Q %s   %d seeds\n",
        gamma, M, string(tau_Qs), n_seed)
    flush(stdout)

    means = Float64[]
    sems = Float64[]
    ncs = Float64[]
    @printf("\n  %-8s %-10s %-10s %-10s\n", "τ_Q", "⟨N_v⟩", "sem", "⟨N_C⟩")
    for τ in tau_Qs
        vs = Int[]
        ncl = Float64[]
        for s in 1:n_seed
            r = kz_trajectory(; grid, c0, mu, T_hot, T_cold, tau_Q=τ,
                t_equil, t_hold, gamma, M, k_cut, dt,
                seed=10_000 + Int(round(τ)) * 100 + s, backend)
            push!(vs, r.n_vortices)
            push!(ncl, r.N_C)
        end
        m = mean(vs)
        push!(means, m)
        push!(sems, n_seed > 1 ? std(vs) / sqrt(n_seed) : 0.0)
        push!(ncs, mean(ncl))
        @printf("  %-8.0f %-10.3f %-10.3f %-10.4g\n", τ, m, sems[end], ncs[end])
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
        println(io, "tau_Q,N_v_mean,N_v_sem,N_C_mean")
        for (i, τ) in enumerate(tau_Qs)
            @printf(io, "%.4f,%.6f,%.6f,%.6g\n", τ, means[i], sems[i], ncs[i])
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

function main(mode::String="smoke"; backend=CPUBackend())
    if mode == "smoke"
        smoke(; backend)
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
