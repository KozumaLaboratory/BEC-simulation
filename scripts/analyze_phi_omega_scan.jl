# Aggregate the phi_omega scan results into a single summary table.
#
# Reads runs/phi_omega_scan/*/result.jld2 (the multi-phase canonical save
# produced by save_rotating_basis_result!) and reports for each
# phi_omega: full-timeline Lz_max, m=+F start vs end, Fz drift,
# integrator metadata.
#
# Usage:  julia --project=. scripts/analyze_phi_omega_scan.jl

using JLD2
using Printf

const ROOT = "runs/phi_omega_scan"

const PHI_OMEGA_POINTS = [1.0, 2.0, 3.0, 4.524, 6.0, 8.0, 12.0, 18.0]

function _name_for(ω)
    "eu151_phi$(replace(string(ω), "." => "_"))_500ms"
end

function _summarise(path)
    JLD2.jldopen(path, "r") do f
        haskey(f, "dynamics/Lz") || return nothing

        Lz = f["dynamics/Lz"]::Vector{Float64}
        Fz = f["dynamics/Fz"]::Vector{Float64}
        times = f["dynamics/times"]::Vector{Float64}
        pm = f["dynamics/per_m_history"]   # D × T

        D = size(pm, 1)
        T = size(pm, 2)

        # Normalise per-m at first and last frames (in case norms drifted).
        col1_sum = sum(view(pm, :, 1))
        colT_sum = sum(view(pm, :, T))
        m_F_init = pm[1, 1] / max(col1_sum, 1e-30)
        m_F_final = pm[1, T] / max(colT_sum, 1e-30)

        # Largest-|m| populations at end (gives qualitative spectrum).
        col_T = view(pm, :, T) ./ max(colT_sum, 1e-30)

        meta = Dict{String, Any}()
        for k in ("dt_used", "epsilon_target", "p_zeeman", "F_atom",
            "larmor_phase_per_step", "phi_omega")
            mk = "dynamics/integrator_meta/$k"
            haskey(f, mk) && (meta[k] = f[mk])
        end

        (
            n_frames=T,
            duration=times[end] - times[1],
            Lz_min=minimum(Lz), Lz_max=maximum(Lz),
            Fz_init=Fz[1], Fz_final=Fz[end], Fz_drift=Fz[end] - Fz[1],
            m_F_init=m_F_init, m_F_final=m_F_final,
            spectrum_top3=collect(
                zip(sortperm(col_T; rev=true)[1:min(3, D)],
                    round.(sort(col_T; rev=true)[1:min(3, D)]; digits=4)),
            ),
            meta=meta,
        )
    end
end

function main()
    println("=" ^ 78)
    println("phi_omega scan summary — runs/phi_omega_scan/")
    println("=" ^ 78)

    for ω in PHI_OMEGA_POINTS
        name = _name_for(ω)
        path = joinpath(ROOT, name, "result.jld2")
        if !isfile(path)
            println("  $name  (phi_omega = $ω)  — NOT YET COMPLETED")
            continue
        end
        s = _summarise(path)
        s === nothing && (println("  $name  no /dynamics/Lz key in result"); continue)

        @printf "  phi_omega = %-7.3f  | frames=%-4d  duration=%.1f\n" ω s.n_frames s.duration
        @printf "    m=+F: %.4f → %.4f  (Δ = %+.4f)\n" s.m_F_init s.m_F_final (
            s.m_F_final - s.m_F_init
        )
        @printf "    Lz range:  [%+.3f, %+.3f]\n" s.Lz_min s.Lz_max
        @printf "    Fz drift:  %+.4f  (init %.3f → final %.3f)\n" s.Fz_drift s.Fz_init s.Fz_final
        @printf "    end-spectrum top: "
        for (idx, val) in s.spectrum_top3
            m_val = (s.meta["F_atom"] - (idx - 1))
            @printf " m=%+d:%.4f" m_val val
        end
        println()
        if !isempty(s.meta)
            @printf "    larmor_phase/step = %.1f  dt = %.4g  ε = %.0e\n" (
                get(s.meta, "larmor_phase_per_step", NaN)
            ) (
                get(s.meta, "dt_used", NaN)
            ) (
                get(s.meta, "epsilon_target", NaN)
            )
        end
        println()
    end

    println("=" ^ 78)
    println("Lz_max vs phi_omega summary table:")
    println("phi_omega | Lz_max  | m=+F final")
    println("---------|---------|----------")
    for ω in PHI_OMEGA_POINTS
        path = joinpath(ROOT, _name_for(ω), "result.jld2")
        isfile(path) || (println(@sprintf("  %-7.3f | (pending)", ω)); continue)
        s = _summarise(path)
        s === nothing && continue
        @printf "  %-7.3f | %+.4f | %.4f\n" ω s.Lz_max s.m_F_final
    end
end

main()
