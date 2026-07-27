# Dashboard data extraction (generate_dashboard_data + export_dashboard)
#
# Extracted from dashboard.jl in the 2026-05-09 refactor.

export generate_dashboard_data, export_dashboard

# --- Dashboard data extraction ---

"""
    generate_dashboard_data(run_dir; F=nothing) -> Dict

Extract dashboard-ready data from a run directory's JLD2 files.
Returns a Dict that can be serialized to JSON.

If `F` is not provided, it is inferred from the psi array shape.
"""
function generate_dashboard_data(run_dir::String; F::Union{Nothing, Int}=nothing)
    isdir(run_dir) || throw(ArgumentError("Not a directory: $run_dir"))

    config_path = joinpath(run_dir, "config.yaml")
    config_raw = isfile(config_path) ? read(config_path, String) : ""

    jld2_files = sort(
        filter(f -> startswith(f, "point_") && endswith(f, ".jld2"),
            readdir(run_dir)),
    )
    if isempty(jld2_files)
        # Run dir exists with config.yaml but no completed points yet —
        # typical state for a batch in progress. Return the config so the
        # Config tab works, plus an `in_progress` flag the frontend can
        # show instead of an error.
        return Dict{String, Any}(
            "points" => Dict{String, Any}[],
            "scan_keys" => String[],
            "config_yaml" => config_raw,
            "in_progress" => true,
            "run_names" => String[],
        )
    end

    points = Dict{String, Any}[]
    run_names = Set{String}()

    for fname in jld2_files
        d = JLD2.load(joinpath(run_dir, fname))
        # Light point (no inline psi) → resolve from the stage store; the M1
        # scalar-export marker (psi = empty array) keeps its inline empty psi.
        psi = haskey(d, "psi") ? d["psi"] :
              load_point_psi(joinpath(run_dir, fname))

        # Two paths: psi-bearing point files (the standard YAML-pipeline
        # case) recompute observables on the fly; scalar-only exports
        # (e.g. M1 sweep → point_NNN.jld2 converter) carry pre-computed
        # `m_values` / `populations` / `mz_actual` on the file itself and
        # set `psi` to an empty array as a marker.
        if length(psi) == 0
            m_values = collect(get(d, "m_values", Int[]))
            pops_norm = collect(get(d, "populations", Float64[]))
            mz_actual_val = get(d, "mz_actual", NaN)
        else
            n_comp = size(psi, ndims(psi))
            F_local = F !== nothing ? F : div(n_comp - 1, 2)
            m_values = [F_local - (c - 1) for c in 1:n_comp]
            ndim = ndims(psi) - 1
            n_pts = ntuple(i -> size(psi, i), ndim)
            pops = [sum(abs2, view(psi, _component_slice(ndim, n_pts, c)...))
                    for c in 1:n_comp]
            total = sum(pops)
            pops_norm = total > 0 ? pops ./ total : pops
            mz_actual_val = get(d, "mz_actual", NaN)
        end

        override = get(d, "override", Dict{String, Any}())
        scan_params = Dict{String, Any}()
        for (k, v) in override
            v isa AbstractArray || (scan_params[k] = v)
        end

        rn = get(d, "run_name", "")
        !isempty(rn) && push!(run_names, rn)

        push!(
            points,
            Dict{String, Any}(
                "file" => fname,
                "index" => get(d, "scan_index", 0),
                "run_name" => rn,
                "energy" => get(d, "energy", NaN),
                "converged" => get(d, "converged", false),
                "mz_actual" => mz_actual_val,
                "populations" => pops_norm,
                "m_values" => m_values,
                "override" => scan_params,
                "analyze" => get(d, "analyze", Dict{String, Any}()),
                "duration_seconds" => get(d, "duration_seconds", NaN),
                "started_at" => get(d, "started_at", ""),
                "finished_at" => get(d, "finished_at", ""),
            ),
        )
    end

    scan_keys = String[]
    if !isempty(points) && !isempty(first(points)["override"])
        scan_keys = sort(collect(keys(first(points)["override"])))
    end

    F_out = !isempty(points) ? div(length(first(points)["m_values"]) - 1, 2) : 0

    Dict{String, Any}(
        "run" => basename(run_dir),
        "config_yaml" => config_raw,
        "F" => F_out,
        "n_points" => length(points),
        "scan_keys" => scan_keys,
        "run_names" => sort(collect(run_names)),
        "points" => points,
    )
end

"""
    export_dashboard(run_dir; output=nothing, F=nothing)

Generate dashboard_data.json for a run directory. If `output` is nothing,
writes to `run_dir/dashboard_data.json`.
"""
function export_dashboard(
    run_dir::String; output::Union{Nothing, String}=nothing, F::Union{Nothing, Int}=nothing
)
    data = generate_dashboard_data(run_dir; F)
    out_path = output !== nothing ? output : joinpath(run_dir, "dashboard_data.json")

    open(out_path, "w") do io
        _write_json(io, data)
    end
    println("Dashboard data written to $out_path ($(length(data["points"])) points)")
    out_path
end
