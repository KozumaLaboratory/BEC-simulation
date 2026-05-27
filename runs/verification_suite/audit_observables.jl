#!/usr/bin/env julia
# Read each result.jld2 from the verification suite runs, extract key
# observables (norms, Fz, populations, energies), and compare against
# the pass criteria in checks/expected_observables.yaml.
#
# Usage:
#   julia --project=. runs/verification_suite/audit_observables.jl

using JLD2, JSON

const RUNS_ROOT = "runs"
const OUT_PATH = "runs/verification_suite/outputs/observable_audit.json"

function latest_run_for(stem)
    prefix = stem * "_"
    all_dirs = readdir(RUNS_ROOT)
    matching = Tuple{String, String}[]   # (path, kind)
    for d in all_dirs
        startswith(d, prefix) || continue
        full = joinpath(RUNS_ROOT, d)
        isdir(full) || continue
        # Pipeline output (dynamics-bearing) → result.jld2
        result = joinpath(full, "result.jld2")
        if isfile(result)
            push!(matching, (result, "pipeline"))
            continue
        end
        # Scan/point output (GS-only) → point_001.jld2
        point = joinpath(full, "point_001.jld2")
        if isfile(point)
            push!(matching, (point, "scan_point"))
            continue
        end
    end
    isempty(matching) && return nothing
    sort!(matching, by=t -> mtime(t[1]), rev=true)
    return matching[1]
end

function pull_array(f, key)
    haskey(f, key) || return nothing
    return f[key]
end

function summarize(v::AbstractVector{<:Real})
    isempty(v) && return Dict("n"=>0)
    Dict(
        "n" => length(v),
        "first" => Float64(first(v)),
        "last" => Float64(last(v)),
        "min" => Float64(minimum(v)),
        "max" => Float64(maximum(v)),
        "drift" => Float64(last(v) - first(v)),
        "rel_drift" => abs(first(v)) > 1e-30 ? Float64((last(v) - first(v)) / first(v)) : NaN,
    )
end

function summarize(v::AbstractMatrix{<:Real})
    isempty(v) && return Dict("shape"=>[0,0])
    n_rows, n_cols = size(v)
    first_row = Float64.(v[1, :])
    last_row = Float64.(v[end, :])
    Dict(
        "shape" => [n_rows, n_cols],
        "first_row" => round.(first_row; digits=6),
        "last_row" => round.(last_row; digits=6),
        "per_col_drift" => round.(last_row .- first_row; digits=6),
        "max_abs_per_col_drift" => maximum(abs.(last_row .- first_row)),
    )
end

summarize(v) = Dict("type" => string(typeof(v)))

stems = [
    "00_scalar_free_uniform_stationary",
    "01_scalar_harmonic_oscillator_ground",
    "02_spin1_polar_contact_ground",
    "03_spin1_ferromagnetic_contact_ground",
    "04_spin2_cyclic_contact_ground",
    "05_spin1_zeeman_phase_only",
    "06_spin1_sma_spin_mixing",
    "07_spin1_polar_bogoliubov_stable",
    "08_ddi_spherical_polarized_zero_kernel",
    "09_edh_toy_spin_orbit_transfer",
    "L2_ddi_axis_flip_Bx",
    "L2_ddi_prolate_trap",
    "L2_ddi_oblate_trap",
    "L3_cr_f3_edh_toy_ddi_on",
    "L3_cr_f3_edh_toy_ddi_off",
    "L4_eu_matsui_hamiltonian_only_32",
    "L4_eu_matsui_hamiltonian_only_ddi_off_32",
    "L4_eu_matsui_hamiltonian_only_48",
    "L4_eu_matsui_hamiltonian_only_64",
    "L7_loss_only_uniform_K3",
]

results = Dict{String, Any}()
for s in stems
    entry = latest_run_for(s)
    if entry === nothing
        results[s] = Dict("status" => "no_result", "path" => nothing)
        continue
    end
    p, kind = entry
    try
        obs = jldopen(p, "r") do f
            d = Dict{String, Any}("path" => p, "kind" => kind,
                                  "found_keys" => collect(keys(f)))
            if kind == "scan_point"
                # GS-only: top-level psi/energy/converged/analyze
                for k in ["energy", "converged", "duration_seconds"]
                    haskey(f, k) && (d[k] = f[k])
                end
                if haskey(f, "psi")
                    psi = f["psi"]
                    d["psi_shape"] = collect(size(psi))
                    d["psi_norm2"] = Float64(sum(abs2, psi))
                end
                if haskey(f, "analyze")
                    analyze_keys = collect(keys(f["analyze"]))
                    d["analyze_keys"] = analyze_keys
                    for ak in analyze_keys
                        full = "analyze/$ak"
                        haskey(f, full) || continue
                        sub = f[full]
                        if sub isa JLD2.Group
                            subkeys = collect(keys(sub))
                            d["analyze/$ak/keys"] = subkeys
                        end
                    end
                end
            else
                # pipeline output (dynamics-bearing or full pipeline)
                if haskey(f, "dynamics")
                    dyn_keys = collect(keys(f["dynamics"]))
                    d["dynamics_keys"] = dyn_keys
                    for k in ["times", "norms", "energies", "magnetizations", "Fz",
                              "component_populations", "peak_density"]
                        full = "dynamics/$k"
                        if haskey(f, full)
                            d[full] = summarize(f[full])
                        end
                    end
                end
                for k in ["ground_state/energy", "ground_state/Mz_final",
                          "ground_state/converged", "ground_state/component_populations"]
                    if haskey(f, k)
                        d[k] = f[k]
                    end
                end
            end
            d
        end
        results[s] = obs
    catch e
        results[s] = Dict("status" => "extract_error",
                          "err" => sprint(showerror, e)[1:300],
                          "path" => p)
    end
end

mkpath(dirname(OUT_PATH))
open(OUT_PATH, "w") do io
    JSON.print(io, results, 2)
end
println("Wrote $OUT_PATH (n=$(length(results)))")
