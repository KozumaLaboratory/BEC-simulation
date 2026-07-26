#!/usr/bin/env julia
# docs/guides/figures/eu_evaporation_sgpe_protocol_check.jl
#
# SGPE verification of the 0-D unified evaporation optimum (issue #75). The 0-D two-
# component model predicts a +27% condensate gain from an independent tightness axis
# m_ω(t) (the waist): hold the trap through cooling, then open the waist ~2.5× during
# BEC formation to dilute the condensate and cut three-body loss. This driver hands the
# TWO post-formation ω̄(t) trajectories — ramp-only (m_ω≡1) vs unified (smooth m_ω(t)) —
# to the verified finite-T Stoof-SGPE (eu_shape_finite_t.jl, PR#82) for a 3D dynamical
# check with real K₃ loss and a thermal cloud.
#
# HONEST SCOPE (inherited from eu_shape_finite_t.jl): the classical field is cutoff-
# dependent; only the COMPARISON at a FIXED k_cut between the two schedules is cutoff-
# clean. The reservoir (μ, T) is prescribed for prep, and the ramp is a CLOSED system —
# this is NOT ab-initio evaporation, it is a controlled A/B of the two ω̄(t) shapes on
# the SAME prepared finite-T condensate. Question answered: does the unified schedule's
# extra loosening retain MORE condensate in 3D, and by how much vs the 0-D +27%?
#
# Run (CPU smoke):  julia --project=. docs/guides/figures/eu_evaporation_sgpe_protocol_check.jl smoke
# Run (GPU):        SBEC_FT_BACKEND=gpu LD_LIBRARY_PATH=/usr/lib/wsl/lib \
#                     julia --project=. docs/guides/figures/eu_evaporation_sgpe_protocol_check.jl run

include(joinpath(@__DIR__, "eu_shape_finite_t.jl"))

using Printf

const SHAPE_CSV = joinpath(@__DIR__, "..", "..", "..",
    "figs", "eu_evaporation_unified_smooth", "unified_shape.csv")
const T_FORM = 1.78    # s — BEC formation time in the 0-D unified run

# Read the 0-D optimum's ω̄(t) and build the two post-formation schedules, normalised to
# the power-ramp ω̄ at formation (so ω=1 is the formation trap the SGPE preps in).
function _load_schedules(; csv=SHAPE_CSV, t_form=T_FORM)
    rows = Tuple{Float64, Float64, Float64}[]  # (t, ω_ramp, ω_eff)
    for (i, ln) in enumerate(eachline(csv))
        i == 1 && continue
        p = split(ln, ",")
        push!(rows, (parse(Float64, p[1]), parse(Float64, p[3]), parse(Float64, p[4])))
    end
    tend = rows[end][1]
    lininterp(xs, ys, x) = begin
        x <= xs[1] && return ys[1]
        x >= xs[end] && return ys[end]
        j = findlast(v -> v <= x, xs)
        f = (x - xs[j]) / (xs[j+1] - xs[j])
        ys[j] * (1 - f) + ys[j+1] * f
    end
    ts = [r[1] for r in rows]
    ωr = [r[2] for r in rows]
    ωe = [r[3] for r in rows]
    ωref_hz = lininterp(ts, ωr, t_form)              # ω̄_ramp at formation — column is ALREADY in Hz
    dur = tend - t_form
    # τ ∈ [0,1] over the post-formation window → normalised ω(τ) for each protocol
    ramp_only(τ) = lininterp(ts, ωr, t_form + clamp(τ, 0, 1) * dur) / ωref_hz
    unified(τ) = lininterp(ts, ωe, t_form + clamp(τ, 0, 1) * dur) / ωref_hz
    (ramp_only=ramp_only, unified=unified, ωref_hz=ωref_hz, dur_s=dur,
        endpoints=(ro=ramp_only(1.0), un=unified(1.0), un0=unified(0.0)))
end

# Prepare a finite-T condensate at the formation trap (ω=1, bath on), then run each
# protocol's CLOSED ω̄(τ) ramp (bath off, K₃ loss on). Compare the surviving N₀.
function ft_protocol_compare(; grid_n::Int=48, box::Float64=22.0, T_over_Tc::Float64=0.6,
    prep_time::Float64=30.0, ramp_time::Union{Float64, Symbol}=:physical, dt::Float64=0.02,
    gs_steps::Int=3000, gamma::Float64=0.1, n_traj::Int=8, backend=CPUBackend(),
    u::Union{Nothing, EuUnits}=nothing,
    csv_prefix::String=joinpath(@__DIR__, "eu_sgpe_protocol"))
    sch = _load_schedules()
    @printf "0-D optimum: formation ω̄=2π·%.0f Hz, window %.2f s;  endpoints ω/ω_form: ramp-only→%.3f, unified %.3f→%.3f\n" sch.ωref_hz sch.dur_s sch.endpoints.ro sch.endpoints.un0 sch.endpoints.un
    # formation trap ω̄ and N from the 0-D run; a_s + K₃ match the optimiser
    u === nothing && (u = EuUnits(; omega_ref=2π * sch.ωref_hz, N=3.1e5,
        a_s=135.0 * Units.BOHR_RADIUS, K3_si=1.0e-41))
    # :physical ⇒ match the 0-D post-formation window (dur_s in real units × ω_ref) so the
    # 3-body loss is integrated over the true ramp duration (a too-fast ramp under-counts it).
    ramp_time isa Symbol && (ramp_time = sch.dur_s * u.omega_ref)
    print_units(u)
    s = _setup(u, grid_n, box, gs_steps, backend)
    Tc = Tc_harmonic(u.N)
    T = T_over_Tc * Tc
    k_cut = min(kcut_for(s.mu, T), 0.95 * s.k_max)
    @printf "μ=%.3f, T=%.2f (T/Tc=%.2f), k_cut=%.2f, ramp_time=%.0f (=%.2fs phys), k_max=%.2f\n" s.mu T T_over_Tc k_cut ramp_time sch.dur_s s.k_max
    Tot = prep_time + ramp_time
    gamma_of_t = t -> t < prep_time ? gamma : 0.0
    τ_of(t) = clamp((t - prep_time) / ramp_time, 0.0, 1.0)
    schedules = (
        ramp_only=harmonic_schedule(t -> t < prep_time ? 1.0 : sch.ramp_only(τ_of(t))),
        unified=harmonic_schedule(t -> t < prep_time ? 1.0 : sch.unified(τ_of(t))),
    )
    out = Dict{Symbol, Any}()
    for name in (:ramp_only, :unified)
        print("$name (prep $prep_time + ramp $ramp_time) ... ")
        t0 = time()
        res = run_ensemble(u, s.grid, s.psi0; potential_of_t=schedules[name], gamma_of_t,
            T, k_cut, mu=s.mu, loss_on=true, n_traj, T_internal=Tot, dt, backend)
        @printf "%.1f s | N₀ %.4g→%.4g, N %.4g→%.4g\n" (time() - t0) res.N0[1] res.N0[end] res.N[1] res.N[end]
        out[name] = res
        open("$(csv_prefix)_$(name).csv", "w") do io
            println(io, "t_ms,N,N0")
            for i in 1:length(res.t_ms)
                @printf io "%.5f,%.6g,%.6g\n" res.t_ms[i] res.N[i] res.N0[i]
            end
        end
    end
    n0_ro = out[:ramp_only].N0[end]
    n0_un = out[:unified].N0[end]
    gain = n0_un / max(n0_ro, eps())
    println("\n=== SGPE protocol verdict (final condensate N₀, fixed k_cut) ===")
    @printf "  ramp-only (m_ω≡1):  N₀=%.4g  (N=%.4g)\n" n0_ro out[:ramp_only].N[end]
    @printf "  unified   (m_ω(t)): N₀=%.4g  (N=%.4g)\n" n0_un out[:unified].N[end]
    @printf "  SGPE N₀ gain = %.2f×   (0-D predicted 1.27×)\n" gain
    (u=u, out=out, gain=gain)
end

# Small, fast CPU logic smoke — NOT physical resolution.
ft_protocol_smoke(; backend=CPUBackend()) = ft_protocol_compare(;
    grid_n=24, box=16.0, T_over_Tc=0.6, prep_time=6.0, ramp_time=12.0,
    dt=0.02, gs_steps=600, gamma=0.1, n_traj=2, backend)

if abspath(PROGRAM_FILE) == @__FILE__
    mode = isempty(ARGS) ? "smoke" : ARGS[1]
    want_gpu = get(ENV, "SBEC_FT_BACKEND", "cpu") == "gpu"
    want_gpu && @eval import CUDA
    bk = want_gpu ? CUDABackend() : CPUBackend()
    if mode == "run"
        ft_protocol_compare(; backend=bk)
    else
        ft_protocol_smoke(; backend=bk)
    end
end
