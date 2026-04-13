# --- Dashboard data extraction ---

"""
    generate_dashboard_data(run_dir; F=nothing) -> Dict

Extract dashboard-ready data from a run directory's JLD2 files.
Returns a Dict that can be serialized to JSON.

If `F` is not provided, it is inferred from the psi array shape.
"""
function generate_dashboard_data(run_dir::String; F::Union{Nothing,Int} = nothing)
    isdir(run_dir) || throw(ArgumentError("Not a directory: $run_dir"))

    config_path = joinpath(run_dir, "config.yaml")
    config_raw = isfile(config_path) ? read(config_path, String) : ""

    jld2_files = sort(filter(f -> startswith(f, "point_") && endswith(f, ".jld2"),
                             readdir(run_dir)))
    isempty(jld2_files) && throw(ArgumentError("No point_*.jld2 files in $run_dir"))

    points = Dict{String,Any}[]
    run_names = Set{String}()

    for fname in jld2_files
        d = JLD2.load(joinpath(run_dir, fname))
        psi = d["psi"]
        n_comp = size(psi, ndims(psi))
        F_local = F !== nothing ? F : div(n_comp - 1, 2)
        m_values = [F_local - (c - 1) for c in 1:n_comp]

        ndim = ndims(psi) - 1
        n_pts = ntuple(i -> size(psi, i), ndim)
        pops = [sum(abs2, view(psi, _component_slice(ndim, n_pts, c)...))
                for c in 1:n_comp]
        total = sum(pops)
        pops_norm = total > 0 ? pops ./ total : pops

        override = get(d, "override", Dict{String,Any}())
        scan_params = Dict{String,Any}()
        for (k, v) in override
            v isa AbstractArray || (scan_params[k] = v)
        end

        rn = get(d, "run_name", "")
        !isempty(rn) && push!(run_names, rn)

        push!(points, Dict{String,Any}(
            "file" => fname,
            "index" => get(d, "scan_index", 0),
            "run_name" => rn,
            "energy" => get(d, "energy", NaN),
            "converged" => get(d, "converged", false),
            "mz_actual" => get(d, "mz_actual", NaN),
            "populations" => pops_norm,
            "m_values" => m_values,
            "override" => scan_params,
            "duration_seconds" => get(d, "duration_seconds", NaN),
            "started_at" => get(d, "started_at", ""),
            "finished_at" => get(d, "finished_at", ""),
        ))
    end

    scan_keys = String[]
    if !isempty(points) && !isempty(first(points)["override"])
        scan_keys = sort(collect(keys(first(points)["override"])))
    end

    F_out = !isempty(points) ? div(length(first(points)["m_values"]) - 1, 2) : 0

    Dict{String,Any}(
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
function export_dashboard(run_dir::String; output::Union{Nothing,String} = nothing, F::Union{Nothing,Int} = nothing)
    data = generate_dashboard_data(run_dir; F)
    out_path = output !== nothing ? output : joinpath(run_dir, "dashboard_data.json")

    open(out_path, "w") do io
        _write_json(io, data)
    end
    println("Dashboard data written to $out_path ($(length(data["points"])) points)")
    out_path
end

function _write_json(io::IO, d::Dict)
    print(io, "{")
    first_entry = true
    for (k, v) in d
        first_entry || print(io, ",")
        first_entry = false
        _write_json(io, k)
        print(io, ":")
        _write_json(io, v)
    end
    print(io, "}")
end

function _write_json(io::IO, v::AbstractVector)
    print(io, "[")
    for (i, x) in enumerate(v)
        i > 1 && print(io, ",")
        _write_json(io, x)
    end
    print(io, "]")
end

function _write_json(io::IO, s::AbstractString)
    print(io, '"')
    for ch in s
        if ch == '"'
            print(io, "\\\"")
        elseif ch == '\\'
            print(io, "\\\\")
        elseif ch == '\n'
            print(io, "\\n")
        elseif ch == '\r'
            print(io, "\\r")
        elseif ch == '\t'
            print(io, "\\t")
        elseif codepoint(ch) < 0x20
            @printf(io, "\\u%04x", codepoint(ch))
        else
            print(io, ch)
        end
    end
    print(io, '"')
end
_write_json(io::IO, n::Real) = isnan(n) ? print(io, "null") : isinf(n) ? print(io, "null") : print(io, n)
_write_json(io::IO, b::Bool) = print(io, b ? "true" : "false")
_write_json(io::IO, ::Nothing) = print(io, "null")
