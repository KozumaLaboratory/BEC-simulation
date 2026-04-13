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

function _json_string(data)
    buf = IOBuffer()
    _write_json(buf, data)
    String(take!(buf))
end

# --- Dashboard server (stdlib Sockets only, no HTTP.jl needed) ---

const _DASHBOARD_HTML_PATH = joinpath(@__DIR__, "..", "..", "..", "runs", "tools", "dashboard.html")

"""
    serve_dashboard(port=8080; base_dir="runs")

Start a local HTTP server for the dashboard.
Browse to http://localhost:\$port to view results.

API:
- `GET /`               → dashboard HTML
- `GET /api/runs`       → list of run directories
- `GET /api/data/:name` → dashboard data JSON for a run
- `GET /api/refresh`    → clear cache
"""
function serve_dashboard(port::Int = 8080; base_dir::String = "runs")
    html_path = _DASHBOARD_HTML_PATH
    isfile(html_path) || throw(ArgumentError("Dashboard HTML not found: $html_path"))
    html_content = read(html_path, String)
    data_cache = Dict{String,String}()

    server = Sockets.listen(Sockets.InetAddr(ip"0.0.0.0", port))
    println("Dashboard server running at http://localhost:$port")
    println("  Serving runs from: $(abspath(base_dir))")
    println("  Press Ctrl+C to stop")
    flush(stdout)

    try
        while true
            sock = Sockets.accept(server)
            @async _handle_dashboard_connection(sock, html_content, data_cache, base_dir)
        end
    catch e
        e isa InterruptException || rethrow(e)
        println("\nDashboard server stopped.")
    finally
        close(server)
    end
end

function _handle_dashboard_connection(sock, html_content, data_cache, base_dir)
    try
        request_line = readline(sock)
        isempty(request_line) && return close(sock)
        # Read remaining headers (discard)
        while true
            line = readline(sock)
            (isempty(line) || line == "\r") && break
        end

        parts = split(request_line)
        length(parts) >= 2 || return close(sock)
        path = String(parts[2])

        status, content_type, body = _route_dashboard(path, html_content, data_cache, base_dir)
        _send_http_response(sock, status, content_type, body)
    catch e
        e isa EOFError || @warn "Dashboard connection error: $e"
    finally
        close(sock)
    end
end

function _route_dashboard(path, html_content, data_cache, base_dir)
    if path == "/" || path == ""
        (200, "text/html; charset=utf-8", html_content)
    elseif path == "/api/runs"
        runs = list_runs(base_dir)
        (200, "application/json", "[" * join(["\"$r\"" for r in runs], ",") * "]")
    elseif startswith(path, "/api/data/")
        name = _uri_decode(path[11:end])
        run_dir = joinpath(base_dir, name)
        if !isdir(run_dir)
            return (404, "text/plain", "Run not found: $name")
        end
        json = get!(data_cache, name) do
            try
                _json_string(generate_dashboard_data(run_dir))
            catch e
                "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
            end
        end
        (200, "application/json", json)
    elseif startswith(path, "/api/density/")
        # /api/density/run_name/point_001.jld2?axis=3
        rest = _uri_decode(path[14:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/density/:run/:file")
        end
        name = rest[1:slash_idx-1]
        file = rest[slash_idx+1:end]
        # Parse query string for axis
        axis = 3  # default: integrate along z
        qidx = findfirst('?', file)
        if qidx !== nothing
            query = file[qidx+1:end]
            file = file[1:qidx-1]
            m = match(r"axis=(\d+)", query)
            m !== nothing && (axis = parse(Int, m.captures[1]))
        end
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        json = try
            _json_string(_compute_column_densities(fpath, axis))
        catch e
            "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
        end
        (200, "application/json", json)

    elseif startswith(path, "/api/density3d/")
        rest = _uri_decode(path[16:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/density3d/:run/:file")
        end
        name = rest[1:slash_idx-1]
        file = rest[slash_idx+1:end]
        qidx = findfirst('?', file)
        qidx !== nothing && (file = file[1:qidx-1])
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        json = try
            _json_string(_compute_3d_densities(fpath))
        catch e
            "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
        end
        (200, "application/json", json)

    elseif path == "/api/refresh"
        empty!(data_cache)
        (200, "text/plain", "Cache cleared")
    else
        (404, "text/plain", "Not found")
    end
end

function _send_http_response(sock, status, content_type, body)
    reason = status == 200 ? "OK" : status == 404 ? "Not Found" : "Error"
    body_bytes = Vector{UInt8}(body)
    write(sock,
        "HTTP/1.1 $status $reason\r\n" *
        "Content-Type: $content_type\r\n" *
        "Content-Length: $(length(body_bytes))\r\n" *
        "Access-Control-Allow-Origin: *\r\n" *
        "Connection: close\r\n" *
        "\r\n")
    write(sock, body_bytes)
end

function _uri_decode(s::AbstractString)
    replace(s, r"%([0-9A-Fa-f]{2})" => m -> Char(parse(UInt8, m[2:3]; base=16)))
end

"""
Compute 3D density for each m-component. Returns downsampled if grid > max_n.
Top `max_components` by population are included, plus total.
"""
function _compute_3d_densities(jld2_path::String; max_n::Int = 40, max_components::Int = 5)
    d = JLD2.load(jld2_path)
    psi = d["psi"]
    n_comp = size(psi, ndims(psi))
    ndim = ndims(psi) - 1
    F = div(n_comp - 1, 2)
    m_values = [F - (c - 1) for c in 1:n_comp]
    n_pts = ntuple(i -> size(psi, i), ndim)

    ndim == 3 || throw(ArgumentError("3D density requires 3D data, got $(ndim)D"))

    # Compute all densities to find top components
    all_densities = [abs2.(view(psi, _component_slice(ndim, n_pts, c)...)) for c in 1:n_comp]
    pops = [sum(dens) for dens in all_densities]
    total_pop = sum(pops)

    # Total density
    total_dens = sum(all_densities)

    # Pick top components by population
    sorted_idx = sortperm(pops; rev=true)
    top_idx = sorted_idx[1:min(max_components, n_comp)]

    # Downsample if needed
    step = max(1, cld(maximum(n_pts), max_n))
    r1 = 1:step:n_pts[1]
    r2 = 1:step:n_pts[2]
    r3 = 1:step:n_pts[3]
    out_shape = (length(r1), length(r2), length(r3))

    components = Dict{String,Any}[]
    for ci in top_idx
        dens = all_densities[ci][r1, r2, r3]
        push!(components, Dict{String,Any}(
            "m" => m_values[ci],
            "population" => pops[ci] / max(total_pop, 1e-300),
            "density" => vec(dens),
        ))
    end

    Dict{String,Any}(
        "m_values" => [c["m"] for c in components],
        "total_density" => vec(total_dens[r1, r2, r3]),
        "components" => components,
        "shape" => collect(out_shape),
        "original_shape" => collect(n_pts),
        "step" => step,
    )
end

"""
Compute column densities (integrated along `axis`) for each m-component.
Returns Dict with m_values, densities (list of 2D arrays), grid info.
"""
function _compute_column_densities(jld2_path::String, axis::Int = 3)
    d = JLD2.load(jld2_path)
    psi = d["psi"]
    n_comp = size(psi, ndims(psi))
    ndim = ndims(psi) - 1
    F = div(n_comp - 1, 2)
    m_values = [F - (c - 1) for c in 1:n_comp]
    n_pts = ntuple(i -> size(psi, i), ndim)

    if ndim == 1
        # 1D: just return |psi_m|² directly
        densities = [Float64[abs2(psi[i, c]) for i in 1:n_pts[1]] for c in 1:n_comp]
        return Dict{String,Any}(
            "m_values" => m_values,
            "densities" => densities,
            "ndim" => 1,
            "shape" => [n_pts[1]],
            "axis" => 0,
        )
    end

    axis = clamp(axis, 1, ndim)
    # Remaining axes after integration
    remaining = [i for i in 1:ndim if i != axis]
    out_shape = ntuple(i -> n_pts[remaining[i]], length(remaining))

    densities = Vector{Vector{Float64}}()
    for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        comp = abs2.(view(psi, idx...))
        # Sum along the integration axis
        col = dropdims(sum(comp; dims=axis); dims=axis)
        push!(densities, vec(col))
    end

    # Total density
    total = zeros(Float64, prod(out_shape))
    for dens in densities
        total .+= dens
    end

    Dict{String,Any}(
        "m_values" => m_values,
        "densities" => densities,
        "total_density" => total,
        "ndim" => ndim,
        "shape" => collect(out_shape),
        "axis" => axis,
        "axis_labels" => [["x","y","z"][i] for i in remaining],
    )
end
