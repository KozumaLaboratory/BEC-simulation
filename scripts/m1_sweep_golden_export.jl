#!/usr/bin/env julia
# scripts/m1_sweep_golden_export.jl
#
# Convert M1 sweep partial.jld2 files into SweepResult and emit golden
# per-cell tables (JSON) for `to_viewspec` regression gating. NO image
# output here — the golden = resolved per-cell hex + dominant-m + decision
# gap + clip values is the load-bearing artefact (per the design
# discussion: image renderers differ in AA / font metrics / tick layout
# so gating on PNG is brittle; gating on the per-cell value table is
# both stricter and more meaningful).
#
# Run: julia --project=. scripts/m1_sweep_golden_export.jl
#
# Writes:
#   runs/sprint5_M1_*/golden/per_cell_table.json   (one per M1 run)

using SpinorBEC
using SpinorBEC: SweepAxis, SweepObservable, SweepResult,
    write_golden_per_cell_table
using JLD2
using JSON
using Dates
using Printf

const M1_RUNS = [
    ("runs/sprint5_M1_ITP_omega_sweep", "m1_itp_sweep.jld2", "partial.jld2"),
    ("runs/sprint5_M1_ITP_omega_sweep_polished", "partial.jld2", nothing),
    ("runs/sprint5_M1_ITP_cpu_scout", "partial.jld2", nothing),
    ("runs/sprint5_M1_ITP_omega_sweep_converged", "partial.jld2", nothing),
]

function load_partial(run_dir::String, preferred::String,
    fallback::Union{Nothing, String})
    for name in (preferred, fallback)
        name === nothing && continue
        path = joinpath(run_dir, name)
        isfile(path) || continue
        d = JLD2.load(path)
        for key in ("partial", "snapshot")
            haskey(d, key) && return d[key]
        end
    end
    return nothing
end

function build_m1_sweep_result(partial::Vector)
    # Axes — unique sorted B_nT / omega across cells.
    omegas = sort(unique(get(c, "omega", 0.0) for c in partial))
    B_vals = sort(unique(get(c, "B_nT", 0.0) for c in partial))

    axes = SweepAxis[
        SweepAxis(:B_nT, "nT", :log, collect(Float64.(B_vals))),
        SweepAxis(:omega, "ω_⊥", :linear, collect(Float64.(omegas))),
    ]

    observables = [
        SweepObservable(; key=:fz_total, label="⟨F_z⟩", kind=:signed,
            center=0.0, oracle=0.24,
            oracle_label="F·Barnett/Zeeman @ B=100, Ω=0.6"),
        SweepObservable(; key=:Lz, label="⟨L_z⟩", kind=:signed, center=0.0),
        SweepObservable(; key=:fx_total, label="⟨F_x⟩", kind=:signed, center=0.0),
        SweepObservable(; key=:fy_total, label="⟨F_y⟩", kind=:signed, center=0.0),
        SweepObservable(; key=:E, label="Energy", kind=:positive, scale=:linear),
        SweepObservable(; key=:grad_norm, label="‖∇E‖", kind=:wide,
            scale=:log, role=:quality),
        SweepObservable(; key=:f_max, label="|F|_max", kind=:positive),
        SweepObservable(; key=:m_dist, label="|c_m|²", kind=:spectrum, index=:m),
    ]

    # Tidy rows
    data = Vector{Dict{Symbol, Any}}()
    for c in partial
        row = Dict{Symbol, Any}()
        row[:B_nT] = Float64(get(c, "B_nT", 0.0))
        row[:omega] = Float64(get(c, "omega", 0.0))
        row[:fz_total] = Float64(get(c, "fz_total", NaN))
        row[:Lz] = Float64(get(c, "Lz", NaN))
        row[:fx_total] = Float64(get(c, "fx_total", NaN))
        row[:fy_total] = Float64(get(c, "fy_total", NaN))
        row[:E] = Float64(get(c, "E", NaN))
        row[:grad_norm] = Float64(get(c, "grad_norm", NaN))
        row[:f_max] = Float64(get(c, "f_max", NaN))
        row[:m_dist] = collect(Float64, get(c, "m_dist", Float64[]))
        row[:conv] = Bool(get(c, "conv_lbfgs",
            get(c, "conv_itp", get(c, "conv", false))))
        row[:seed] = string(get(c, "seed", "default"))
        push!(data, row)
    end

    meta = Dict{Symbol, Any}(
        :conv_column => :conv,
        :run_kind => "rotating_frame_barnett_sweep",
        :exported_at => string(now()),
    )
    return SweepResult(axes, observables, data; meta=meta)
end

function main()
    for (run_dir, preferred, fallback) in M1_RUNS
        if !isdir(run_dir)
            println("skip $run_dir — directory missing")
            continue
        end
        partial = load_partial(run_dir, preferred, fallback)
        if partial === nothing
            println("skip $run_dir — no $preferred/$fallback")
            continue
        end
        if isempty(partial)
            println("skip $run_dir — empty partial")
            continue
        end
        result = build_m1_sweep_result(partial)
        out = joinpath(run_dir, "golden", "per_cell_table.json")
        write_golden_per_cell_table(out, result;
            signed_clip=Dict(),         # default ±F (=±6)
            positive_clip=Dict(),       # auto via converged-only p05/p95
            spectrum_margin=0.1,
            F=6)
        n_cells = length(partial)
        n_conv = count(r -> r[:conv], result.data)
        @printf "wrote %s  (%d cells, %d converged, axes: %d B × %d Ω)\n" out n_cells n_conv (
            length(result.axes[1].values)
        ) length(result.axes[2].values)
    end
    println("\nDone.")
end

main()
