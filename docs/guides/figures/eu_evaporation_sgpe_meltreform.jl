#!/usr/bin/env julia
# docs/guides/figures/eu_evaporation_sgpe_meltreform.jl
#
# Does a deliberate MELT-and-REFORM beat the no-melt adiabatic optimum? Tests the "story":
# loosen so hard the condensate melts into a dilute cloud (low density ⇒ low 3-body), park
# there, then re-tighten to re-condense. Prediction: it LOSES, because (i) an incoherent
# cloud has the 3! = 6× three-body bunching enhancement (g₃: 1→6) and (ii) reforming costs
# re-compression (density + loss return). The winner should be adiabatic dilution — stay
# coherent (g₃=1) and just spread out.
#
# CLOSED system (bath off during the ramp) so N changes ONLY by loss — NO grand-canonical
# atom-drawing artifact (unlike the reservoir-driven formation run). One prepared finite-T
# condensate, four ω̄(t) schedules, physical post-formation ramp, K₃ loss on. Compare N₀.
#
# Run (CPU smoke): julia --project=. docs/guides/figures/eu_evaporation_sgpe_meltreform.jl smoke
# Run (GPU):       SBEC_FT_BACKEND=gpu LD_LIBRARY_PATH=/usr/lib/wsl/lib \
#                    julia --project=. docs/guides/figures/eu_evaporation_sgpe_meltreform.jl run

include(joinpath(@__DIR__, "eu_evaporation_sgpe_protocol_check.jl"))

using Printf

# melt schedules (τ ∈ [0,1] post-formation progress → ω̄/ω_form multiplier). Start at the
# unified formation value 0.876, drop fast to ω_lo (sudden decompression ⇒ dephase/melt),
# hold dilute, then (reform variant) re-tighten to ω_hi.
const ΩLO = 0.12; const ΩHI = 0.35; const ΤDROP = 0.08; const ΤREFORM = 0.70; const Ω0 = 0.876
melt_stay(τ) = τ < ΤDROP ? Ω0 + (ΩLO - Ω0) * (τ / ΤDROP) : ΩLO
function melt_reform(τ)
    τ < ΤDROP && return Ω0 + (ΩLO - Ω0) * (τ / ΤDROP)
    τ < ΤREFORM && return ΩLO
    ΩLO + (ΩHI - ΩLO) * ((τ - ΤREFORM) / (1 - ΤREFORM))
end

function ft_meltreform_compare(; grid_n::Int=40, box::Float64=22.0, T_over_Tc::Float64=0.6,
    prep_time::Float64=30.0, dt::Float64=0.02, gs_steps::Int=2500, gamma::Float64=0.1,
    n_traj::Int=8, backend=CPUBackend(),
    csv_prefix::String=joinpath(@__DIR__, "eu_sgpe_meltreform"))
    sch = _load_schedules()
    u = EuUnits(; omega_ref=2π * sch.ωref_hz, N=3.1e5,
        a_s=135.0 * Units.BOHR_RADIUS, K3_si=1.0e-41)
    ramp_time = sch.dur_s * u.omega_ref
    print_units(u)
    s = _setup(u, grid_n, box, gs_steps, backend)
    Tc = Tc_harmonic(u.N)
    T = T_over_Tc * Tc
    k_cut = min(kcut_for(s.mu, T), 0.95 * s.k_max)
    @printf "μ=%.2f T=%.2f (T/Tc=%.2f) k_cut=%.2f ramp=%.0f (%.2fs)\n" s.mu T T_over_Tc k_cut ramp_time sch.dur_s
    Tot = prep_time + ramp_time
    gamma_of_t = t -> t < prep_time ? gamma : 0.0
    τ_of(t) = clamp((t - prep_time) / ramp_time, 0.0, 1.0)
    hs(f) = harmonic_schedule(t -> t < prep_time ? 1.0 : f(τ_of(t)))
    schedules = (
        ramp_only=hs(sch.ramp_only),
        optimum=hs(sch.unified),
        melt_stay=hs(melt_stay),
        melt_reform=hs(melt_reform),
    )
    out = Dict{Symbol, Any}()
    for name in (:ramp_only, :optimum, :melt_stay, :melt_reform)
        print("$name ... ")
        t0 = time()
        r = run_ensemble(u, s.grid, s.psi0; potential_of_t=schedules[name], gamma_of_t,
            T, k_cut, mu=s.mu, loss_on=true, n_traj, T_internal=Tot, dt, backend)
        @printf "%.1f s | N₀ %.4g→%.4g, N %.4g→%.4g\n" (time() - t0) r.N0[1] r.N0[end] r.N[1] r.N[end]
        out[name] = r
        open("$(csv_prefix)_$(name).csv", "w") do io
            println(io, "t_ms,N,N0")
            for i in 1:length(r.t_ms)
                @printf io "%.5f,%.6g,%.6g\n" r.t_ms[i] r.N[i] r.N0[i]
            end
        end
    end
    println("\n=== Melt-and-reform verdict (final condensate N₀, closed, fixed k_cut) ===")
    base = out[:optimum].N0[end]
    for name in (:ramp_only, :optimum, :melt_stay, :melt_reform)
        n0 = out[name].N0[end]
        @printf "  %-12s N₀=%.4g  (%.2f× optimum)  N=%.4g\n" name n0 (n0 / base) out[name].N[end]
    end
    win = argmax(Dict(k => out[k].N0[end] for k in keys(out)))
    @printf "  WINNER: %s\n" win
    (u=u, out=out)
end

ft_meltreform_smoke(; backend=CPUBackend()) = ft_meltreform_compare(;
    grid_n=24, box=16.0, prep_time=8.0, dt=0.03, gs_steps=600, n_traj=2, backend)

if abspath(PROGRAM_FILE) == @__FILE__
    mode = isempty(ARGS) ? "smoke" : ARGS[1]
    want_gpu = get(ENV, "SBEC_FT_BACKEND", "cpu") == "gpu"
    want_gpu && @eval import CUDA
    bk = want_gpu ? CUDABackend() : CPUBackend()
    mode == "run" ? ft_meltreform_compare(; backend=bk) : ft_meltreform_smoke(; backend=bk)
end
