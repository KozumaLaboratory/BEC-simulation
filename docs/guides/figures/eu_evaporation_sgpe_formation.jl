#!/usr/bin/env julia
# docs/guides/figures/eu_evaporation_sgpe_formation.jl
#
# RESERVOIR-DRIVEN formation check (the "full-gain" 3D test the post-formation A/B in
# eu_evaporation_sgpe_protocol_check.jl could not do). Instead of prepping ONE condensate
# and running a closed post-formation ramp, here the condensate FORMS dynamically as the
# reservoir cools, so the formation-phase three-body loss is captured too.
#
# NON-CIRCULAR design. The FORT power ramp P(t) is IDENTICAL between the two protocols —
# only the waist (ω̄) differs — so the evaporative cooling is COMMON. We drive BOTH
# protocols with the SAME reservoir T(t), μ(t) (from the ramp-only 0-D run, μ via the TF
# formula μ=½ω̄(15 N₀ a_s/a_ho)^{2/5}) and vary ONLY the trap ω̄(t). The condensate that
# emerges, the T_c melt, and the K₃ loss are then all SGPE-computed from the trap shape —
# the ratio is not fed in. Bath ON throughout (γ>0): the classical field tracks the
# instantaneous (μ(t),T(t)) equilibrium while the trap opens.
#
# VALIDATION GATE: the ramp-only SGPE N₀(final) must land near the 0-D ramp-only N₀
# (≈1.26e5) for the (μ,T) calibration to be trustworthy; printed as PASS/CHECK. Only then
# is the unified/ramp-only ratio meaningful. Same cutoff caveats as eu_shape_finite_t.jl.
#
# Run (CPU smoke):  julia --project=. docs/guides/figures/eu_evaporation_sgpe_formation.jl smoke
# Run (GPU):        SBEC_FT_BACKEND=gpu LD_LIBRARY_PATH=/usr/lib/wsl/lib \
#                     julia --project=. docs/guides/figures/eu_evaporation_sgpe_formation.jl run

include(joinpath(@__DIR__, "eu_evaporation_sgpe_protocol_check.jl"))  # brings in eu_shape_finite_t.jl

using Printf

const TRAJ_CSV = joinpath(@__DIR__, "..", "..", "..",
    "figs", "eu_evaporation_unified_smooth", "unified_traj.csv")
const T_START = 1.76      # s — just after BEC onset (N₀>0), start of the formation window
const T_END = 2.22        # s
const N0_0D_RAMPONLY = 1.264e5   # 0-D ramp-only final condensate (validation target)
const N0_0D_UNIFIED = 1.610e5    # 0-D unified final condensate

# piecewise-linear interpolator over ascending xs
function _interp(xs, ys, x)
    x <= xs[1] && return ys[1]
    x >= xs[end] && return ys[end]
    j = findlast(v -> v <= x, xs)
    f = (x - xs[j]) / (xs[j+1] - xs[j])
    ys[j] * (1 - f) + ys[j+1] * f
end

# Load the common reservoir (ramp-only 0-D) + both traps, all as functions of physical t.
function _load_reservoir()
    # ramp-only trajectory: t_s, N, N0, Nth, T_nK
    ts, Ns, N0s, Ts = Float64[], Float64[], Float64[], Float64[]
    for (i, ln) in enumerate(eachline(TRAJ_CSV))
        i == 1 && continue
        p = split(ln, ",")
        p[1] == "ramp_only" || continue
        push!(ts, parse(Float64, p[2]))
        push!(Ns, parse(Float64, p[3]))
        push!(N0s, parse(Float64, p[4]))
        push!(Ts, parse(Float64, p[6]))
    end
    # traps: t_s, m_omega, omega_ramp_hz, omega_eff_hz
    st, ωr, ωe = Float64[], Float64[], Float64[]
    for (i, ln) in enumerate(eachline(SHAPE_CSV))
        i == 1 && continue
        p = split(ln, ",")
        push!(st, parse(Float64, p[1]))
        push!(ωr, parse(Float64, p[3]))
        push!(ωe, parse(Float64, p[4]))
    end
    ωref_hz = _interp(st, ωr, T_START)
    (T_nK=(t -> _interp(ts, Ts, t)), N0_0D=(t -> _interp(ts, N0s, t)),
        N_0D=(t -> _interp(ts, Ns, t)),
        w_ramp=(t -> _interp(st, ωr, t)), w_eff=(t -> _interp(st, ωe, t)),
        ωref_hz=ωref_hz)
end

function ft_reservoir_formation_compare(; grid_n::Int=48, box::Float64=20.0,
    dt::Float64=0.02, gs_steps::Int=2500, gamma::Float64=0.2, n_traj::Int=8,
    backend=CPUBackend(), csv_prefix::String=joinpath(@__DIR__, "eu_sgpe_formation"))
    res = _load_reservoir()
    u = EuUnits(; omega_ref=2π * res.ωref_hz, N=2.0e5,
        a_s=135.0 * Units.BOHR_RADIUS, K3_si=1.0e-41)
    print_units(u)
    as_over_aho = u.a_s / a_ho(u)                       # dimensionless a_s/a_ho at ω_ref
    kB, ħ = Units.KB, Units.HBAR
    dur_phys = T_END - T_START
    T_internal = dur_phys * u.omega_ref                 # dimensionless window length
    t_phys(t_sgpe) = T_START + t_sgpe / u.omega_ref     # SGPE clock → physical time
    # reservoir T(t), μ(t) — COMMON to both protocols (shared evaporative cooling)
    T_of_t = t -> kB * (res.T_nK(t_phys(t)) * 1e-9) / (ħ * u.omega_ref)
    function μ_of_t(t)
        tp = t_phys(t)
        ωdl = res.w_ramp(tp) / res.ωref_hz              # trap in units of ω_ref
        N0 = max(res.N0_0D(tp), 1.0)
        0.5 * ωdl * (15 * N0 * as_over_aho * sqrt(ωdl))^(2 / 5)  # TF μ of the instantaneous condensate
    end
    # trap schedules (only difference between protocols): ω̄(t)/ω_ref
    sched_ramp = harmonic_schedule(t -> res.w_ramp(t_phys(t)) / res.ωref_hz)
    sched_unif = harmonic_schedule(t -> res.w_eff(t_phys(t)) / res.ωref_hz)
    s = _setup(u, grid_n, box, gs_steps, backend)
    # cutoff at the START conditions (fixed through the run so the comparison is cutoff-clean)
    T0 = T_of_t(0.0)
    k_cut = min(kcut_for(s.mu, T0), 0.95 * s.k_max)
    @printf "window %.2f–%.2f s (%.0f dimless), ω_ref=2π·%.0f Hz, T: %.1f→%.1f, μ0=%.2f, k_cut=%.2f\n" T_START T_END T_internal res.ωref_hz T0 T_of_t(T_internal) μ_of_t(0.0) k_cut

    out = Dict{Symbol, Any}()
    for (name, sched) in ((:ramp_only, sched_ramp), (:unified, sched_unif))
        print("$name (reservoir-driven formation) ... ")
        t0 = time()
        r = run_ensemble(u, s.grid, s.psi0; potential_of_t=sched, gamma_of_t=(_ -> gamma),
            T=T_of_t, k_cut, mu=μ_of_t(0.0), μ_of_t=μ_of_t, loss_on=true,
            n_traj, T_internal, dt, backend)
        @printf "%.1f s | N₀ %.4g→%.4g, N %.4g→%.4g\n" (time() - t0) r.N0[1] r.N0[end] r.N[1] r.N[end]
        out[name] = r
        open("$(csv_prefix)_$(name).csv", "w") do io
            println(io, "t_ms,N,N0")
            for i in 1:length(r.t_ms)
                @printf io "%.5f,%.6g,%.6g\n" r.t_ms[i] r.N[i] r.N0[i]
            end
        end
    end
    n0_ro, n0_un = out[:ramp_only].N0[end], out[:unified].N0[end]
    gain = n0_un / max(n0_ro, eps())
    valid = 0.5 * N0_0D_RAMPONLY <= n0_ro <= 2.0 * N0_0D_RAMPONLY
    println("\n=== Reservoir-driven formation verdict (final condensate N₀) ===")
    @printf "  ramp-only: SGPE N₀=%.4g   0-D N₀=%.4g   %s (calibration gate: within 2×)\n" n0_ro N0_0D_RAMPONLY (valid ? "PASS" : "CHECK")
    @printf "  unified:   SGPE N₀=%.4g   0-D N₀=%.4g\n" n0_un N0_0D_UNIFIED
    @printf "  SGPE N₀ gain = %.2f×   (0-D predicted %.2f×)\n" gain (N0_0D_UNIFIED / N0_0D_RAMPONLY)
    (u=u, out=out, gain=gain, valid=valid)
end

ft_formation_smoke(; backend=CPUBackend()) = ft_reservoir_formation_compare(;
    grid_n=24, box=16.0, dt=0.03, gs_steps=600, gamma=0.2, n_traj=2, backend)

if abspath(PROGRAM_FILE) == @__FILE__
    mode = isempty(ARGS) ? "smoke" : ARGS[1]
    want_gpu = get(ENV, "SBEC_FT_BACKEND", "cpu") == "gpu"
    want_gpu && @eval import CUDA
    bk = want_gpu ? CUDABackend() : CPUBackend()
    mode == "run" ? ft_reservoir_formation_compare(; backend=bk) : ft_formation_smoke(; backend=bk)
end
