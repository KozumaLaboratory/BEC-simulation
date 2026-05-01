# --- Miscellaneous analyzers ---
#
# `summary_json` is the only analyzer that needs the full
# `pipeline_results` dict — it dumps the accumulated step results
# plus user-supplied extras to a JSON file (one-shot, not for plot
# consumption). Other one-off analyzers can also live here as the
# rosters grow.

function _analyze_summary_json(psi, grid, atom, params, ws_prev, pipeline_results)
    output_path = String(get(params, "path", "summary.json"))
    extras = get(params, "extras", Dict{String, Any}())
    summary = Dict{String, Any}()
    for (k, v) in pipeline_results
        if v isa Number || v isa AbstractString || v isa Bool || v === nothing
            summary[String(k)] = v
        end
    end
    if haskey(pipeline_results, :dynamics_result)
        dr = pipeline_results[:dynamics_result]
        summary["n_snapshots"] = length(dr.psi_snapshots)
        summary["t_initial"] = dr.times[1]
        summary["t_final"] = dr.times[end]
        if !isempty(dr.energies)
            summary["energy_initial"] = Float64(dr.energies[1])
            summary["energy_final"] = Float64(dr.energies[end])
            summary["norm_drift"] = Float64(abs(dr.norms[end] - dr.norms[1]))
        end
    end
    for (k, v) in extras
        summary[String(k)] = v
    end
    mkpath(dirname(output_path) == "" ? "." : dirname(output_path))
    open(output_path, "w") do io
        JSON.print(io, summary, 2)
    end
    (path=output_path, n_fields=length(summary))
end
