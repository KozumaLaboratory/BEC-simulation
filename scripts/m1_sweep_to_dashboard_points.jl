#!/usr/bin/env julia
# Convert M1 sweep partial.jld2 (Vector{Dict} of per-cell results) into
# the per-point format the dashboard's run viewer expects:
# `point_NNN.jld2` with keys {psi, scan_index, run_name, energy, converged,
# grid_box_size, grid_n_points, env, units, analyze, dynamics, ...}.
#
# psi is left empty (M1 sweep does not persist the wavefunction); only
# the scalar observables (E, ⟨F_x/y/z⟩, ⟨L_z⟩, ‖∇E‖, m_dist, conv,
# omega, B_nT, seed) flow into the `analyze` dict for scan-plot display.

using JLD2, JSON, Dates

const M1_RUNS = [
    "runs/sprint5_M1_ITP_omega_sweep_polished",
    "runs/sprint5_M1_ITP_omega_sweep",
    "runs/sprint5_M1_ITP_cpu_scout",
    "runs/sprint5_M1_ITP_omega_sweep_converged",
]

# Eu Matsui digital twin (canonical sweep geometry)
const TWIN_BOX = [30.0, 30.0, 26.0]
const TWIN_NPTS = [24, 24, 24]
const TWIN_BOX_CPU = [20.0, 20.0, 18.0]
const TWIN_NPTS_CPU = [16, 16, 16]

function find_jld2(run_dir::String)
    for fname in
        ("partial.jld2", "m1_itp_sweep.jld2", "polished_sweep.jld2", "converged_sweep.jld2")
        path = joinpath(run_dir, fname)
        isfile(path) && return path
    end
    return nothing
end

function load_partial(jld2_path::String)
    snapshot = JLD2.load(jld2_path)
    for key in ("partial", "snapshot")
        haskey(snapshot, key) && return snapshot[key]
    end
    error("expected `partial` or `snapshot` array in $jld2_path; got $(keys(snapshot))")
end

function write_point(out_path::String, cell::Dict, idx::Int, run_name::String,
    npts::Vector{Int}, box::Vector{Float64})
    # `override` is what the dashboard reads to populate scan_keys (the
    # axes of the scan-plot view). Put the sweep parameters here so the
    # 30-cell M1 sweep shows up as a 2D (B, Ω) scan.
    override = Dict{String, Any}(
        "B_nT" => float(get(cell, "B_nT", 0.0)),
        "omega" => float(get(cell, "omega", 0.0)),
        "seed" => string(get(cell, "seed", "default")),
    )
    # `analyze` carries the per-cell observables so they appear next to
    # each scan point.
    analyze = Dict{String, Any}(
        "fz_total" => get(cell, "fz_total", NaN),
        "fx_total" => get(cell, "fx_total", NaN),
        "fy_total" => get(cell, "fy_total", NaN),
        "Lz" => get(cell, "Lz", NaN),
        "f_max" => get(cell, "f_max", NaN),
        "grad_norm" => get(cell, "grad_norm", NaN),
        "E_itp" => get(cell, "E_itp", NaN),
        "m_dist" => get(cell, "m_dist", Float64[]),
        "time_itp_min" => get(cell, "time_itp_min", NaN),
        "time_lbfgs_min" => get(cell, "time_lbfgs_min", NaN),
    )
    conv = get(cell, "conv_lbfgs", get(cell, "conv_itp", get(cell, "conv", false)))
    energy = get(cell, "E", NaN)

    # Standard dashboard fields. With empty psi, dashboard's data_export
    # falls back to these directly (patched 2026-06-02):
    #   * mz_actual ← ⟨F_z⟩ (Barnett magnetization is exactly Mz)
    #   * populations ← per-m density distribution (normalised to 1)
    #   * m_values ← [+F, +F-1, …, −F]
    F = 6
    D = 2F + 1
    m_values_vec = collect(F:-1:(-F))
    pops_raw = collect(get(cell, "m_dist", zeros(Float64, D)))
    pops_total = sum(pops_raw)
    pops_norm = pops_total > 0 ? pops_raw ./ pops_total : pops_raw
    mz_actual = get(cell, "fz_total", NaN)

    jldopen(out_path, "w") do f
        f["psi"] = ComplexF64[]                          # empty — wavefunction not saved
        f["scan_index"] = idx
        f["run_name"] = run_name
        f["override"] = override                         # fuels scan_keys / scan plot
        f["m_values"] = m_values_vec                     # NEW — dashboard reads when psi empty
        f["populations"] = collect(pops_norm)            # NEW
        f["mz_actual"] = float(mz_actual)                # NEW
        f["started_at"] = string(now())
        f["finished_at"] = string(now())
        f["duration_seconds"] =
            (
                get(cell, "time_itp_min", 0.0) + get(cell, "time_lbfgs_min", 0.0)
            ) * 60.0
        f["energy"] = float(energy)
        f["converged"] = Bool(conv)
        f["grid_box_size"] = box
        f["grid_n_points"] = npts
        f["env"] = Dict{String, Any}("source" => "m1_sweep_dashboard_export")
        f["units"] = Dict{String, Any}("length" => "a_ho", "energy" => "hbar_omega_ref")
        f["analyze"] = analyze                           # extras: Lz, grad_norm, f_max, …
        f["dynamics"] = Dict{String, Any}()              # no time series for ITP/LBFGS GS
    end
end

function process_run(run_dir::String)
    jld2_path = find_jld2(run_dir)
    jld2_path === nothing && (println("skip $(run_dir) — no partial.jld2"); return nothing)
    partial = load_partial(jld2_path)
    isempty(partial) && (println("skip $(run_dir) — empty partial"); return nothing)
    npts = occursin("cpu_scout", run_dir) ? TWIN_NPTS_CPU : TWIN_NPTS
    box = occursin("cpu_scout", run_dir) ? TWIN_BOX_CPU : TWIN_BOX
    run_name = basename(run_dir)
    for (i, cell) in enumerate(partial)
        out = joinpath(run_dir, lpad(string(i), 3, '0') |> s -> "point_$(s).jld2")
        write_point(out, cell, i, run_name, npts, box)
    end
    println("$(run_dir): wrote $(length(partial)) point_*.jld2")
end

for run_dir in M1_RUNS
    isdir(run_dir) ? process_run(run_dir) : println("skip $run_dir — dir missing")
end
println("\nDone. The dashboard run viewer should now show points for each cell.")
