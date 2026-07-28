#!/usr/bin/env julia
# docs/guides/figures/eu_evaporation_spgpe.jl
#
# SECOND-SCALE evaporation of ¹⁵¹Eu run as a full SPGPE (growth + energy-damping
# reservoirs), rather than as a mechanical energy knife on a millisecond ramp.
#
# The problem this solves. A closed c-field cannot evaporate: something has to
# take the hot atoms away. Earlier runs did that with a shrinking radial knife,
# which works but has to be swept in ~25 ms of internal time to stay affordable —
# ~60× faster than the real ~1–2 s Eu evaporation. At 60× the removal outruns
# rethermalisation, so the result is non-adiabatic spilling and cannot be read
# quantitatively (see docs/guides/eu_shape_finite_t.md).
#
# The full SPGPE removes the need for the knife. The thermal cloud is not
# simulated at all — it is the reservoir, and the 0-D truncated-Boltzmann model
# already describes it on the experimental timescale. The c-field is coupled to
# that reservoir through the two processes of Rooney/Blakie/Bradley (PRA 86,
# 053634): growth, which exchanges atoms and drives condensation, and scattering,
# which exchanges only energy. Cooling the reservoir over the real 1–2 s makes
# the condensate form for the physical reason, at the physical rate.
#
# What is actually predicted here. Below T_c the reservoir μ is pinned by the
# condensate, so prescribing μ(t) from the 0-D N₀ ties the c-field's EQUILIBRIUM
# population to the 0-D answer by construction — the absolute N₀ is not an
# independent measurement. What is independent is the LAG: growth proceeds at a
# finite rate γ, so a ramp faster than 1/γ leaves the condensate behind its
# quasi-static value. That gap is invisible to the 0-D model and is exactly what
# decides whether an "optimised" fast ramp actually delivers atoms.
#
# Run (CPU smoke, every code path, ≤ ~2 min):
#   julia --project=. docs/guides/figures/eu_evaporation_spgpe.jl --smoke
# Run (GPU):
#   LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'import CUDA;
#     include("docs/guides/figures/eu_evaporation_spgpe.jl"); main("production")'
#
# Provenance:
# - shows: DRIVER — computes the CSV behind eu_evap_spgpe.png
# - referenced by: docs/guides/eu_evaporation_optimization.md

include(joinpath(@__DIR__, "eu_shape_optimization.jl"))   # EuUnits, a_ho, k3_tilde, …

using SpinorBEC
using Printf
using DelimitedFiles

# CSV destination. Defaults to the repo's figs/ dir; `SPINORBEC_FIGS_ROOT`
# redirects it, which is what the TSUBAME submit script sets — the group's /gs/fs
# allocation is nearly exhausted (994/1000 GB) while $HOME has 22 GB and the work
# area 100 GB free, and a run that cannot write its own output is a wasted run.
const OUTDIR = get(ENV, "SPINORBEC_FIGS_ROOT",
    joinpath(@__DIR__, "..", "..", "..", "figs", "eu_evaporation_optimization"))

# norm-N couplings: the SPGPE noise amplitude assumes |ψ|² is the PHYSICAL
# density, so N must NOT be folded into c₀ (see eu_shape_finite_t.md).
c0_norm_n(u::EuUnits) = 4π * (u.a_s / a_ho(u))
k3_norm_n(u::EuUnits) = k3_tilde(u)

# Single stretched component ⇒ c₁ never enters and any F gives identical physics;
# F=1 (D=3) is 4.3× cheaper than Eu's D=13. Eu lives in the explicit c₀, K₃.
const SPGPE_ATOM = Rb87

# ---------------------------------------------------------------------------
# 0-D trajectory + the window a c-field can represent
# ---------------------------------------------------------------------------

"""
    zero_d_trajectory(; N0_load, T0_load, K3) -> (; r, trap, ramp, omega_of)

The euv3 two-component evaporation, plus `ω̄(t)` reconstructed on the same grid
`spgpe_reservoir` uses.
"""
function zero_d_trajectory(; N0_load=3.5e6, T0_load=50e-6, K3=1.61e-40, save_every=2)
    trap = euv3_evap_trap()
    ramp = euv3_evaporation_ramp()
    p = EvapParams(; a_s=Eu151.a_s, tau_bg=15.0, K3=K3)
    r = run_evaporation_bec(trap, ramp, p; N0=N0_load, T0=T0_load, save_every)
    g = evap_trap_grid(trap, ramp)
    tg, ωg, dtg, ng = g.tg, g.ωg, g.dtg, length(g.tg)
    omega_of = function (tq)
        tq <= tg[1] && return ωg[1]
        tq >= tg[end] && return ωg[ng]
        j = clamp(floor(Int, (tq - tg[1]) / dtg) + 1, 1, ng - 1)
        f = (tq - (tg[1] + (j - 1) * dtg)) / dtg
        ωg[j] * (1 - f) + ωg[j + 1] * f
    end
    (; r, trap, ramp, omega_of)
end

"""
    cfield_window(traj; f_start=1.2) -> (; t_start, omega_ref, T_max, mu_max, k_cut_min)

The part of the ramp a classical field can represent. The C region has to contain
the thermal cloud, so `ϵ_cut ≳ μ + T` in internal units — at the 50 µK start
`T = k_BT/ℏω̄ ≈ 3.7×10³` and `k_cut ≈ 86`, which no grid resolves. The c-field
description becomes affordable only near degeneracy; `f_start` is the `T/T_c` at
which to pick it up.

`ω_ref` is the trap at the window start, so internal time is 1/ω̄ there.
"""
function cfield_window(traj; f_start::Float64=1.2)
    r, omega_of = traj.r, traj.omega_of
    idx = findfirst(eachindex(r.t)) do i
        r.T[i] <= f_start * bec_critical_temperature(r.N[i], omega_of(r.t[i]))
    end
    idx === nothing && error(
        "cfield_window: T never drops below $f_start·T_c on this ramp — the 0-D " *
        "run never approaches degeneracy, so there is nothing for a c-field to do.")
    t_start = r.t[idx]
    ωref = omega_of(t_start)
    m = traj.trap.mass
    T_max = maximum(Units.KB * r.T[i] / (Units.HBAR * ωref) for i in idx:length(r.t))
    mu_max = maximum(
        reservoir_chemical_potential(r.N[i], r.T[i], omega_of(r.t[i]), m, Eu151.a_s)
        for i in idx:length(r.t)) / (Units.HBAR * ωref)
    (; t_start, omega_ref=ωref, T_max, mu_max,
        k_cut_min=sqrt(2 * (mu_max + T_max)), idx)
end

# ---------------------------------------------------------------------------
# One SPGPE trajectory over the ramp
# ---------------------------------------------------------------------------

"""
    spgpe_trajectory!(...)

One realisation. The trap follows `ω̄(t)` from the same 0-D ramp that produced the
reservoir; `TimeDependentTrap` is NOT refreshed by the standard dynamics path, so
the potential is driven by overwriting `ws.potential_values` in `on_step` (the
2026-07-26 gotcha).
"""
function spgpe_trajectory!(
    u::EuUnits, grid, psi0, reservoir, omega_internal_of, T_internal, dt, save_every,
    spgpe_every, backend, seed, accum, D,
)
    n_steps = round(Int, T_internal / dt)
    interactions = InteractionParams(Dict{Int, Float64}(0 => c0_norm_n(u)))
    loss = LossParams(; K3_cubic=k3_norm_n(u))
    sp = SimParams(; dt, n_steps, imaginary_time=false, normalize_every=0, save_every)
    ws = make_workspace(; grid, atom=SPGPE_ATOM, interactions,
        potential=HarmonicTrap{3}((1.0, 1.0, 1.0)), sim_params=sp,
        psi_init=copy(psi0), loss, backend)
    seed_device_rng!(backend, seed)

    dV = cell_volume(grid)
    sidx = Ref(0)
    ω_prev = Ref(-1.0)
    rates_log = Tuple{Float64, Float64, Float64, Float64, Float64}[]
    # Two DIFFERENT things the projector removes, kept apart: atoms the shrinking
    # cutoff swept out of the C region (physical, into the I region), and the part
    # of each step's fresh noise that landed above the cutoff (bookkeeping). The
    # second is ~10³× the first per step, so a single total measures only the noise.
    proj_cut = Ref(0.0)
    proj_noise = Ref(0.0)

    cb = SimulationCallbacks(
        on_step=(w, step, times, energies) -> begin
            t = w.state.t
            # trap follows the ramp (rebuild only when ω̄ actually moved)
            ω = omega_internal_of(t)
            if abs(ω - ω_prev[]) > 1e-6 * max(ω, 1.0)
                copyto!(w.potential_values,
                    evaluate_potential(HarmonicTrap{3}((ω, ω, ω)), grid))
                ω_prev[] = ω
            end
            if step % spgpe_every == 0
                rr = apply_spgpe_step!(w, reservoir, dt * spgpe_every;
                    t=t, seed=seed + step)
                # scalar model: keep the empty spin channels empty so reservoir
                # noise cannot fill them.
                @views for c in 1:(D - 1)
                    w.state.psi[:, :, :, c] .= 0
                end
                proj_cut[] += rr.cutoff_outflow
                proj_noise[] += rr.noise_truncated
                push!(rates_log, (t, rr.T, rr.mu, rr.gamma, rr.M))
            end
            if step % save_every == 0
                sidx[] += 1
                i = sidx[]
                i <= length(accum.psi_sum) || return nothing
                ψc = Array(view(w.state.psi, :, :, :, D))
                phase = angle(sum(ψc) * dV)              # global-phase gauge fix
                @. accum.psi_sum[i] += ψc * cis(-phase)
                @. accum.dens_sum[i] += abs2(ψc)
                accum.n_sum[i] += real(sum(abs2, w.state.psi)) * dV
                accum.times[i] = t
            end
            nothing
        end,
    )
    run_simulation!(ws; callbacks=cb)
    (; rates_log, cutoff_outflow=proj_cut[], noise_truncated=proj_noise[])
end

"""
    run_spgpe_ensemble(...) -> NamedTuple

`M` trajectories; the condensate is the bias-corrected phase-fixed ensemble mean
`n_c = |⟨ψ⟩|² − (⟨|ψ|²⟩ − |⟨ψ⟩|²)/(M−1)` (Penrose–Onsager consistent — the raw
`|⟨ψ⟩|²` over-counts by the residual thermal variance and would depend on `M`).
"""
function run_spgpe_ensemble(
    u::EuUnits, grid, psi0, reservoir, omega_internal_of;
    n_traj::Int, T_internal::Float64, dt::Float64, save_every::Int, spgpe_every::Int,
    backend=CPUBackend(), seed0::Int=2024, on_trajectory=nothing, verbose::Bool=false,
)
    n_steps = round(Int, T_internal / dt)
    n_save = max(1, fld(n_steps, save_every))
    D = SpinSystem(SPGPE_ATOM.F).n_components
    gpts = grid.config.n_points
    # The ensemble accumulators are the memory footprint: n_save full spatial
    # arrays of ComplexF64 + Float64. At 80³ × 40 saves that is ~0.5 GB of HOST
    # memory, which dominates the process RSS — report it rather than surprise
    # the machine.
    bytes = n_save * prod(gpts) * (sizeof(ComplexF64) + sizeof(Float64))
    verbose && @printf("  accumulators    %.2f GB host (%d saves × %d³)\n",
        bytes / 2^30, n_save, gpts[1])
    accum = (
        psi_sum=[zeros(ComplexF64, gpts...) for _ in 1:n_save],
        dens_sum=[zeros(Float64, gpts...) for _ in 1:n_save],
        n_sum=zeros(Float64, n_save),
        times=zeros(Float64, n_save),
    )
    dV = cell_volume(grid)
    rates = nothing
    out = nothing
    for tr in 1:n_traj
        tj = spgpe_trajectory!(u, grid, psi0, reservoir, omega_internal_of,
            T_internal, dt, save_every, spgpe_every, backend,
            seed0 + tr * 1_000_003, accum, D)
        tr == 1 && (rates = tj.rates_log)
        verbose && @printf("  trajectory %d: %.4g atoms swept out by the shrinking cutoff (noise truncated: %.4g)\n",
            tr, tj.cutoff_outflow, tj.noise_truncated)
        # Reduce and hand over after EVERY trajectory: a long ensemble that is
        # killed part-way then still leaves a valid (smaller-M) result on disk
        # instead of nothing.
        out = _reduce_ensemble(accum, tr, dV, rates)
        on_trajectory === nothing || on_trajectory(tr, out)
        verbose && @printf("  trajectory %d/%d  N_C %.4g → %.4g,  N₀ → %.4g\n",
            tr, n_traj, out.N_C[1], out.N_C[end], out.N0[end])
        verbose && flush(stdout)
    end
    out
end

"""
    _reduce_ensemble(accum, M, dV, rates) -> (; t_internal, N_C, N0, rates)

Ensemble reduction over the first `M` trajectories. The condensate uses the
bias-corrected estimator; with `M = 1` no correction is possible, so `N0` is the
raw coherent density and is an OVER-estimate (it still contains the full thermal
variance) — the printed value for trajectory 1 should be read that way.
"""
function _reduce_ensemble(accum, M::Int, dV::Float64, rates)
    N_C = accum.n_sum ./ M
    N0 = map(eachindex(accum.n_sum)) do i
        coh = abs2.(accum.psi_sum[i] ./ M)
        meandens = accum.dens_sum[i] ./ M
        nc = M > 1 ? coh .- (meandens .- coh) ./ (M - 1) : coh
        max(sum(nc) * dV, 0.0)
    end
    (; t_internal=accum.times, N_C, N0, rates, M)
end

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

"""
    evap_spgpe(; …) -> NamedTuple

Full pipeline: 0-D ramp → c-field window → reservoir → equilibrated seed →
SPGPE ensemble over the real ramp → CSV.
"""
function evap_spgpe(;
    grid_n::Int=48, box_scale::Float64=2.6, n_traj::Int=4, dt::Float64=0.002,
    spgpe_every::Int=5, f_start::Float64=1.2, equilibrate::Float64=40.0,
    cutoff_n_T::Float64=1.0,
    n_save::Int=120, backend=CPUBackend(), tag::String="spgpe",
    duration_cap::Float64=Inf,
)
    traj = zero_d_trajectory()
    win = cfield_window(traj; f_start)
    ωref = win.omega_ref

    # Box holds the thermal cloud (R_th = √(2T) in a_ho units at the hottest point).
    box = box_scale * sqrt(2 * win.T_max)
    k_max = π / (box / grid_n)

    # The cutoff TRACKS the reservoir (ϵ_cut − μ = cutoff_n_T·k_BT). It is largest
    # at the start, where T is largest, so that is what the grid must resolve.
    resv = spgpe_reservoir(traj.r, traj.trap, traj.ramp;
        omega_ref=ωref, a_s=Eu151.a_s, cutoff_n_T=cutoff_n_T, t_start=win.t_start)
    k_cut = resv.k_cut_max
    if k_max < k_cut
        n_req = ceil(Int, k_cut * box / π / 2) * 2
        error("grid_n=$grid_n cannot resolve the classical region: k_max=" *
              "$(round(k_max; digits=2)) < max k_cut=$(round(k_cut; digits=2)) at box=" *
              "$(round(box; digits=1)). Need grid_n ≥ $n_req. Silently lowering " *
              "k_cut would make the GRID define the C region instead of the " *
              "physics; pinning it would decouple the reservoir as T falls.")
    end

    T_internal = min(resv.duration_internal, duration_cap)
    @printf("=== SPGPE evaporation ===\n")
    @printf("  window          t = %.3f → %.3f s  (%.3f s of REAL evaporation)\n",
        win.t_start, win.t_start + resv.duration_s, resv.duration_s)
    @printf("  ω_ref/2π        %.1f Hz   ⇒ %.0f internal units", ωref / 2π,
        resv.duration_internal)
    T_internal < resv.duration_internal &&
        @printf("  (CAPPED to %.0f)", T_internal)
    @printf("\n")
    @printf("  reservoir       T %.2f → %.2f,  μ %.2f → %.2f  (internal)\n",
        resv.T_int[1], resv.T_int[end], resv.mu_int[1], resv.mu_int[end])
    # Growth budget BEFORE spending the GPU hour. Two production runs were
    # already lost to a reservoir that could not deliver the condensate; the
    # number that decides it costs milliseconds. See `growth_budget`.
    G = let t = resv.t_internal, ω = resv.omega_bar ./ ωref
        acc = 0.0
        for i in 1:(length(t) - 1)
            a = spgpe_rates(resv.reservoir, t[i])
            b = spgpe_rates(resv.reservoir, t[i + 1])
            acc += 0.5 * (2 * a.gamma * max(a.mu - 1.5 * ω[i], 0.0) +
                          2 * b.gamma * max(b.mu - 1.5 * ω[i + 1], 0.0)) *
                   (t[i + 1] - t[i])
        end
        acc
    end
    G > 1.0 || error(
        "growth budget G = $(round(G; sigdigits=3)) ≤ 1: the reservoir cannot grow a " *
        "condensate in this window, so the run would return N₀ ≈ 0 no matter how " *
        "correct the code is. Lower cutoff_n_T (currently $cutoff_n_T) or widen the " *
        "window; run mode `growth_budget` to see the trade-off.")
    G > 3.0 || @warn "growth budget is marginal — expect a large lag, not a saturated condensate" G

    r0 = spgpe_rates(resv.reservoir, 0.0)
    r1 = spgpe_rates(resv.reservoir, resv.duration_internal)
    @printf("  rates           γ %.3g → %.3g,  ℳ̄ %.3g → %.3g\n",
        r0.gamma, r1.gamma, r0.M, r1.M)
    @printf("  cutoff          k_cut %.2f → %.2f (ϵ_cut−μ = %.1f k_BT, occupation %.2f)\n",
        resv.k_cut[1], resv.k_cut[end], cutoff_n_T, 1 / cutoff_n_T)
    @printf("  growth budget   G = ∫2γ(μ−μ̃)dt = %.2f  (%s)\n",
        G, G > 3 ? "forms" : "marginal")
    @printf("  grid            %d³, box %.1f, max k_cut %.2f (k_max %.2f)\n",
        grid_n, box, k_cut, k_max)
    @printf("  steps           %.3g × %d trajectories\n", T_internal / dt, n_traj)
    flush(stdout)

    grid = make_grid(GridConfig((grid_n, grid_n, grid_n), (box, box, box)))
    u = EuUnits(; omega_ref=ωref, a_s=Eu151.a_s, K3_si=1.61e-40,
        N=traj.r.N[win.idx])
    D = SpinSystem(SPGPE_ATOM.F).n_components

    # Seed: an empty C region equilibrated against the reservoir held at its
    # t=0 value. Starting from vacuum rather than from a condensate is the point
    # — the condensate has to GROW from the reservoir.
    psi_seed = zeros(ComplexF64, grid.config.n_points..., D)
    static_res = SPGPEReservoir(; T=resv.T_int[1], mu=resv.mu_int[1],
        a_s=Eu151.a_s / a_ho(u), k_cut=resv.k_cut[1])
    eq = run_spgpe_ensemble(u, grid, psi_seed, static_res, (_ -> 1.0);
        n_traj=1, T_internal=equilibrate, dt=dt,
        save_every=max(1, round(Int, equilibrate / dt / 4)),
        spgpe_every=spgpe_every, backend=backend, seed0=99)
    @printf("  seed            N_C = %.4g after %.0f units of equilibration\n",
        eq.N_C[end], equilibrate)
    flush(stdout)

    # ω̄(t)/ω_ref along the window, as a function of INTERNAL time.
    omega_internal_of = let t0 = win.t_start, om = traj.omega_of, ωr = ωref
        (t_int) -> om(t0 + t_int / ωr) / ωr
    end

    mkpath(OUTDIR)
    csv = joinpath(OUTDIR, "eu_evap_$(tag).csv")

    # Write after every trajectory, not only at the end: a multi-hour ensemble
    # that gets killed (machine pressure, wall clock) then still leaves a valid
    # result at whatever M it reached, instead of nothing.
    write_csv = function (M, o)
        t_s = win.t_start .+ o.t_internal ./ ωref
        open(csv, "w") do io
            println(io, "# M_trajectories=$M")
            println(io, "t_s,t_internal,N0_spgpe,N_C_spgpe,N0_0d,N_total_0d,T_internal,mu_internal")
            for i in eachindex(o.t_internal)
                ti = o.t_internal[i]
                @printf(io, "%.6f,%.4f,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g\n",
                    t_s[i], ti, o.N0[i], o.N_C[i],
                    _interp(resv.t_internal, resv.N0_ref, ti),
                    _interp(resv.t_internal, resv.N_ref, ti),
                    _interp(resv.t_internal, resv.T_int, ti),
                    _interp(resv.t_internal, resv.mu_int, ti))
            end
        end
    end

    save_every = max(1, round(Int, T_internal / dt / n_save))
    out = run_spgpe_ensemble(u, grid, psi_seed, resv.reservoir, omega_internal_of;
        n_traj, T_internal, dt, save_every, spgpe_every, backend,
        verbose=true, on_trajectory=write_csv)

    t_s = win.t_start .+ out.t_internal ./ ωref
    N0_0d = [_interp(resv.t_internal, resv.N0_ref, t) for t in out.t_internal]
    N_0d = [_interp(resv.t_internal, resv.N_ref, t) for t in out.t_internal]
    @printf("  wrote           %s\n", csv)
    @printf("  final           N₀ SPGPE %.4g   vs 0-D quasi-static %.4g   (ratio %.3f)\n",
        out.N0[end], N0_0d[end], out.N0[end] / max(N0_0d[end], eps()))

    (; csv, out, resv, win, N0_0d, N_0d, t_s, grid, k_cut, box, u)
end

function _interp(xs::AbstractVector, ys::AbstractVector, x::Real)
    x <= xs[1] && return Float64(ys[1])
    x >= xs[end] && return Float64(ys[end])
    j = searchsortedlast(xs, x)
    j >= length(xs) && return Float64(ys[end])
    f = (x - xs[j]) / (xs[j + 1] - xs[j])
    Float64(ys[j]) * (1 - f) + Float64(ys[j + 1]) * f
end

"""
    growth_budget(; n_Ts, f_start) -> Vector

The decisive number, computed ANALYTICALLY before spending a GPU hour: how many
e-foldings of condensate growth the ramp actually affords.

Number damping drives `dN₀/dt = 2γ(μ − μ̃)N₀` (Rooney Eq. 23). For a condensate
just nucleating, `μ̃` is the trap ground-state energy `3/2·ω̄(t)`, so the growth
the window can deliver is

    G = ∫ 2γ(t)·max(μ(t) − 3/2·ω̄(t), 0) dt      (internal time)

`G ≫ 1` ⇒ the condensate forms; `G ≲ 1` ⇒ it cannot, however correct the code is.

This is worth its own entry point because the two failed production runs were
both decided by a number of this kind — one that costs milliseconds to evaluate
and an hour of H100 to discover. `γ` depends on the cutoff depth `n_T` through
`(ln(1−e^{−n_T}))²`, which swings by ~14× between `n_T = 0.5` and `1.5`, so `G`
is scanned over `n_T` rather than quoted at one value.
"""
function growth_budget(; n_Ts=(0.5, 0.75, 1.0, 1.5, 2.0), f_start::Float64=1.05)
    traj = zero_d_trajectory()
    win = cfield_window(traj; f_start)
    ωref = win.omega_ref
    @printf("window starts %.3f s, ω_ref/2π = %.1f Hz\n", win.t_start, ωref / 2π)
    println("n_T   k_cut(0)→k_cut(T)   γ(0)→γ(T)        G=∫2γ(μ−μ̃)dt   verdict   n_grid")
    out = []
    for nT in n_Ts
        resv = spgpe_reservoir(traj.r, traj.trap, traj.ramp;
            omega_ref=ωref, a_s=Eu151.a_s, cutoff_n_T=nT, t_start=win.t_start)
        t = resv.t_internal
        # ω̄(t)/ω_ref along the window, for the ground-state energy 3/2·ω̄.
        ω = resv.omega_bar ./ ωref
        G = 0.0
        for i in 1:(length(t) - 1)
            r1 = spgpe_rates(resv.reservoir, t[i])
            r2 = spgpe_rates(resv.reservoir, t[i + 1])
            d1 = 2 * r1.gamma * max(r1.mu - 1.5 * ω[i], 0.0)
            d2 = 2 * r2.gamma * max(r2.mu - 1.5 * ω[i + 1], 0.0)
            G += 0.5 * (d1 + d2) * (t[i + 1] - t[i])
        end
        r0 = spgpe_rates(resv.reservoir, t[1])
        r1 = spgpe_rates(resv.reservoir, t[end])
        box = 2.6 * sqrt(2 * win.T_max)
        n_req = ceil(Int, resv.k_cut_max * box / π / 2) * 2
        verdict = G > 3 ? "FORMS" : G > 1 ? "marginal" : "CANNOT FORM"
        @printf("%.2f  %5.2f → %5.2f      %.3g → %.3g   %8.2f      %-11s %d\n",
            nT, resv.k_cut[1], resv.k_cut[end], r0.gamma, r1.gamma, G, verdict, n_req)
        push!(out, (; n_T=nT, G, k_cut=resv.k_cut[1], gamma0=r0.gamma, n_req))
    end
    println("\nG ≫ 1 forms, G ≲ 1 cannot. Occupation at the cutoff is 1/n_T, so the")
    println("standard c-field range is n_T ≈ 0.5–1.5; anything outside is not a free choice.")
    out
end

# --smoke: exercise every code path in ≤ ~2 min. NOT physics.
#
# The real problem CANNOT be shrunk into a smoke: the C region has to hold the
# thermal cloud (box ≈ 23 a_ho) AND resolve the cutoff (k_cut ≈ 10.6), and those
# two together force grid_n ≳ 80 — there is no small grid that represents this
# physics. Faking one by lowering k_cut would put ϵ_cut below μ, where the
# reservoir formulas are undefined (the driver refuses, by design).
#
# So the smoke splits: the 0-D → window → reservoir bridge runs on the REAL
# trajectory (it touches no grid and costs nothing), and the c-field machinery
# runs on a deliberately synthetic, small, warm reservoir. Together they cover
# every line; neither is a physics result.
function smoke(; backend=CPUBackend())
    traj = zero_d_trajectory()
    win = cfield_window(traj; f_start=1.05)
    resv = spgpe_reservoir(traj.r, traj.trap, traj.ramp;
        omega_ref=win.omega_ref, a_s=Eu151.a_s,
        t_start=win.t_start)
    @printf("[smoke] bridge OK: %.3f s of real ramp = %.0f internal units, T %.1f→%.1f, μ %.2f→%.2f, k_cut %.2f→%.2f\n",
        resv.duration_s, resv.duration_internal,
        resv.T_int[1], resv.T_int[end], resv.mu_int[1], resv.mu_int[end],
        resv.k_cut[1], resv.k_cut[end])

    # Synthetic small reservoir: same code path, toy numbers.
    u = EuUnits(; omega_ref=win.omega_ref, a_s=Eu151.a_s, K3_si=1.61e-40, N=1e4)
    k_cut = 4.0
    box = 8.0
    grid_n = 16
    @assert π / (box / grid_n) > k_cut
    grid = make_grid(GridConfig((grid_n, grid_n, grid_n), (box, box, box)))
    D = SpinSystem(SPGPE_ATOM.F).n_components
    toy = SPGPEReservoir(;
        T=PiecewiseLinearWaveform([0.0, 8.0], [3.0, 1.0]),
        mu=PiecewiseLinearWaveform([0.0, 8.0], [-1.0, 2.0]),
        a_s=Eu151.a_s / a_ho(u), k_cut=k_cut)
    psi_seed = zeros(ComplexF64, grid.config.n_points..., D)
    out = run_spgpe_ensemble(u, grid, psi_seed, toy, (_ -> 1.0);
        n_traj=2, T_internal=8.0, dt=0.004, save_every=100, spgpe_every=4,
        backend=backend)
    @printf("[smoke] c-field OK: %d saves, N_C %.4g → %.4g, N₀ %.4g → %.4g\n",
        length(out.N_C), out.N_C[1], out.N_C[end], out.N0[1], out.N0[end])
    @assert all(isfinite, out.N_C) && all(isfinite, out.N0)
    @assert out.N_C[end] > 0     # the reservoir actually filled the C region
    println("[smoke] PASS")
    (; resv, out)
end

function main(mode::String="smoke"; backend=CPUBackend())
    if mode == "smoke"
        smoke(; backend)
    elseif mode == "production"
        evap_spgpe(; grid_n=72, n_traj=4, f_start=1.05, n_save=40, cutoff_n_T=1.0,
            backend, tag="spgpe")
    elseif mode == "growth_budget"
        growth_budget()
    elseif mode == "preflight"
        traj = zero_d_trajectory()
        for f in (1.05, 1.2, 1.5)
            w = cfield_window(traj; f_start=f)
            @printf("f=%.2f: t_start=%.3f s  ω_ref/2π=%.0f Hz  T_max=%.1f  μ_max=%.2f  k_cut≥%.2f\n",
                f, w.t_start, w.omega_ref / 2π, w.T_max, w.mu_max, w.k_cut_min)
        end
    else
        error("unknown mode: $mode (smoke | production | preflight)")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    mode = "--smoke" in ARGS ? "smoke" : (length(ARGS) >= 1 ? ARGS[1] : "smoke")
    # Same env convention as eu_shape_finite_t.jl: SBEC_SPGPE_BACKEND=gpu loads
    # the CUDA extension and selects CUDABackend.
    want_gpu = get(ENV, "SBEC_SPGPE_BACKEND", "cpu") == "gpu"
    want_gpu && @eval import CUDA
    main(mode; backend=want_gpu ? CUDABackend() : CPUBackend())
end
