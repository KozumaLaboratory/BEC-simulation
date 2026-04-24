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

const _REPO_ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const _WEB_DIST_DIR = joinpath(_REPO_ROOT, "web", "dist")
const _WEB_DIST_INDEX = joinpath(_WEB_DIST_DIR, "index.html")
const _LEGACY_DASHBOARD_HTML = joinpath(_REPO_ROOT, "runs", "tools", "dashboard.html")

"""
    serve_dashboard(port=8080; base_dir="runs")

Start a local HTTP server for the React + WebGPU dashboard.
Browse to http://localhost:\$port to view results.

Requires `web/dist/` (run `cd web && bun run build`). The legacy
Plotly dashboard remains reachable at `/legacy` as long as
`runs/tools/dashboard.html` exists.

API:
- `GET /`               → React dashboard (web/dist/index.html)
- `GET /assets/*`       → hashed static assets from web/dist/assets/
- `GET /favicon.svg`    → favicon from web/dist/
- `GET /legacy`         → legacy Plotly dashboard (if present)
- `GET /api/runs`       → list of run directories
- `GET /api/data/:name` → dashboard data JSON for a run
- `GET /api/refresh`    → clear cache

See src/workflow/io/dashboard.jl for the full /api surface that the
React app consumes.
"""
function serve_dashboard(port::Int = 8080; base_dir::String = "runs")
    if !isfile(_WEB_DIST_INDEX)
        throw(ArgumentError(
            "React dashboard not built. Run: cd web && bun install && bun run build"
        ))
    end
    html_content = read(_WEB_DIST_INDEX, String)
    legacy_html = isfile(_LEGACY_DASHBOARD_HTML) ? read(_LEGACY_DASHBOARD_HTML, String) : ""
    data_cache = Dict{String,String}()
    psi_cache = Dict{String,Any}()  # path → (psi, n_comp, n_pts, F, pops)

    server = Sockets.listen(Sockets.InetAddr(ip"0.0.0.0", port))
    println("Dashboard server running at http://localhost:$port")
    println("  Serving runs from: $(abspath(base_dir))")
    println("  React app:         $(_WEB_DIST_INDEX)")
    isempty(legacy_html) || println("  Legacy dashboard:  /legacy")
    println("  Press Ctrl+C to stop")
    flush(stdout)

    try
        while true
            sock = Sockets.accept(server)
            @async _handle_dashboard_connection(
                sock, html_content, legacy_html, data_cache, psi_cache, base_dir,
            )
        end
    catch e
        e isa InterruptException || rethrow(e)
        println("\nDashboard server stopped.")
    finally
        close(server)
    end
end

function _handle_dashboard_connection(sock, html_content, legacy_html, data_cache, psi_cache, base_dir)
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

        status, content_type, body = _route_dashboard(
            path, html_content, legacy_html, data_cache, psi_cache, base_dir,
        )
        _send_http_response(sock, status, content_type, body)
    catch e
        e isa EOFError || @warn "Dashboard connection error: $e"
    finally
        close(sock)
    end
end

function _route_dashboard(path, html_content, legacy_html, data_cache, psi_cache, base_dir)
    if path == "/" || path == ""
        (200, "text/html; charset=utf-8", html_content)
    elseif path == "/legacy"
        if isempty(legacy_html)
            (404, "text/plain", "Legacy dashboard not present")
        else
            (200, "text/html; charset=utf-8", legacy_html)
        end
    elseif startswith(path, "/assets/") || path == "/favicon.svg"
        _serve_static_asset(path)
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
            cached = _load_psi_cached(fpath, psi_cache)
            _json_string(_compute_column_densities_from_cache(cached..., axis, fpath))
        catch e
            "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
        end
        (200, "application/json", json)

    elseif startswith(path, "/api/phase/")
        # /api/phase/:run/:file?axis=N&slice=K
        rest = _uri_decode(path[12:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/phase/:run/:file?axis=N&slice=K")
        end
        name = rest[1:slash_idx-1]
        file = rest[slash_idx+1:end]
        axis = 3
        slice_idx = nothing
        qidx = findfirst('?', file)
        if qidx !== nothing
            query = file[qidx+1:end]
            file = file[1:qidx-1]
            m = match(r"axis=(\d+)", query)
            m !== nothing && (axis = parse(Int, m.captures[1]))
            ms = match(r"slice=(\d+)", query)
            ms !== nothing && (slice_idx = parse(Int, ms.captures[1]))
        end
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        json = try
            cached = _load_psi_cached(fpath, psi_cache)
            _json_string(_compute_phase_slice_from_cache(cached..., axis, slice_idx, fpath))
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

    elseif startswith(path, "/api/density3d_bin/")
        rest = _uri_decode(path[19:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/density3d_bin/:run/:file")
        end
        name = rest[1:slash_idx-1]
        file = rest[slash_idx+1:end]
        qidx = findfirst('?', file)
        comp_idx = 0
        snap_idx = nothing
        if qidx !== nothing
            query = file[qidx+1:end]
            file = file[1:qidx-1]
            m = match(r"comp=(-?\d+)", query)
            m !== nothing && (comp_idx = parse(Int, m.captures[1]))
            ms = match(r"snap=(\d+)", query)
            ms !== nothing && (snap_idx = parse(Int, ms.captures[1]))
        end
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        bin = try
            _compute_3d_density_binary(_load_psi_cached(fpath, psi_cache, snap_idx)...; component=comp_idx)
        catch e
            return (500, "text/plain", "Error: $(e)")
        end
        (200, "application/octet-stream", bin)

    elseif startswith(path, "/api/snapshots/")
        # /api/snapshots/:run/:file → metadata for the time-scrubber UI.
        rest = _uri_decode(path[16:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/snapshots/:run/:file")
        end
        name = rest[1:slash_idx-1]
        file = rest[slash_idx+1:end]
        qidx = findfirst('?', file)
        qidx !== nothing && (file = file[1:qidx-1])
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        meta = _snapshots_metadata(fpath)
        if meta === nothing
            return (200, "application/json", "{\"n_snapshots\":0,\"times\":[]}")
        end
        (200, "application/json", _json_string(meta))

    elseif startswith(path, "/api/vortex_lines/")
        # /api/vortex_lines/:run/:file?snap=K&mask=FRAC  → per-m polylines
        rest = _uri_decode(path[19:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/vortex_lines/:run/:file?snap=K&mask=FRAC")
        end
        name = rest[1:slash_idx-1]
        file = rest[slash_idx+1:end]
        snap_idx = nothing
        mask_frac = 0.0
        qidx = findfirst('?', file)
        if qidx !== nothing
            query = file[qidx+1:end]
            file = file[1:qidx-1]
            ms = match(r"snap=(\d+)", query)
            ms !== nothing && (snap_idx = parse(Int, ms.captures[1]))
            mm = match(r"mask=([0-9.]+)", query)
            mm !== nothing && (mask_frac = parse(Float64, mm.captures[1]))
        end
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        json = try
            psi, n_comp, ndim, n_pts, F = _load_psi_cached(fpath, psi_cache, snap_idx)
            ndim == 3 || throw(ArgumentError("vortex_lines requires 3D data"))
            box_size = _load_box_size(fpath)
            g = make_grid(GridConfig(n_pts, box_size))
            lines = extract_vortex_lines_per_m(psi, g; min_density_frac = mask_frac)
            # Flatten into a frontend-friendly list [{m, charge, points}, ...]
            out_lines = Dict{String,Any}[]
            for (m_label, polylines) in lines
                for ln in polylines
                    push!(out_lines, Dict{String,Any}(
                        "m" => m_label,
                        "charge" => ln.charge,
                        "points" => [[p[1], p[2], p[3]] for p in ln.points],
                    ))
                end
            end
            _json_string(Dict{String,Any}(
                "lines" => out_lines,
                "box" => collect(Float64.(box_size)),
                "n_lines" => length(out_lines),
            ))
        catch e
            "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
        end
        (200, "application/json", json)

    elseif startswith(path, "/api/vorticity3d_bin/")
        # /api/vorticity3d_bin/:run/:file?snap=K
        rest = _uri_decode(path[22:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/vorticity3d_bin/:run/:file?snap=K")
        end
        name = rest[1:slash_idx-1]
        file = rest[slash_idx+1:end]
        qidx = findfirst('?', file)
        snap_idx = nothing
        if qidx !== nothing
            query = file[qidx+1:end]
            file = file[1:qidx-1]
            ms = match(r"snap=(\d+)", query)
            ms !== nothing && (snap_idx = parse(Int, ms.captures[1]))
        end
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        bin = try
            psi, n_comp, ndim, n_pts, F = _load_psi_cached(fpath, psi_cache, snap_idx)
            ndim == 3 || throw(ArgumentError("vorticity3d requires 3D data"))
            box_size = _load_box_size(fpath)
            _compute_3d_vorticity_binary(psi, n_comp, ndim, n_pts, F, box_size)
        catch e
            return (500, "text/plain", "Error: $(e)")
        end
        (200, "application/octet-stream", bin)

    elseif startswith(path, "/api/phase3d_bin/")
        # /api/phase3d_bin/:run/:file?comp=N&snap=K (N >= 1)
        rest = _uri_decode(path[18:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/phase3d_bin/:run/:file?comp=N&snap=K")
        end
        name = rest[1:slash_idx-1]
        file = rest[slash_idx+1:end]
        qidx = findfirst('?', file)
        comp_idx = 1
        snap_idx = nothing
        if qidx !== nothing
            query = file[qidx+1:end]
            file = file[1:qidx-1]
            m = match(r"comp=(-?\d+)", query)
            m !== nothing && (comp_idx = parse(Int, m.captures[1]))
            ms = match(r"snap=(\d+)", query)
            ms !== nothing && (snap_idx = parse(Int, ms.captures[1]))
        end
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        bin = try
            _compute_3d_phase_binary(_load_psi_cached(fpath, psi_cache, snap_idx)...; component=comp_idx)
        catch e
            return (500, "text/plain", "Error: $(e)")
        end
        (200, "application/octet-stream", bin)

    elseif startswith(path, "/api/coherence/")
        rest = _uri_decode(path[16:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/coherence/:run/:file?axis=N")
        end
        name = rest[1:slash_idx-1]
        file = rest[slash_idx+1:end]
        axis = 3
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
        bin = try
            _compute_coherence_matrix_binary(_load_psi_cached(fpath, psi_cache)..., axis)
        catch e
            return (500, "text/plain", "Error: $(e)")
        end
        (200, "application/octet-stream", bin)

    elseif startswith(path, "/api/density3d_rotated/")
        rest = _uri_decode(path[23:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/density3d_rotated/:run/:file?angle=DEG&comp=N")
        end
        name = rest[1:slash_idx-1]
        file = rest[slash_idx+1:end]
        angle_deg = 0.0; comp_idx = 0
        qidx = findfirst('?', file)
        if qidx !== nothing
            query = file[qidx+1:end]
            file = file[1:qidx-1]
            m = match(r"angle=([0-9.e+-]+)", query)
            m !== nothing && (angle_deg = parse(Float64, m.captures[1]))
            m2 = match(r"comp=(-?\d+)", query)
            m2 !== nothing && (comp_idx = parse(Int, m2.captures[1]))
        end
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        bin = try
            _compute_rotated_3d_density_binary(
                _load_psi_cached(fpath, psi_cache)...; angle_deg, component=comp_idx)
        catch e
            return (500, "text/plain", "Error: $(e)")
        end
        (200, "application/octet-stream", bin)

    elseif startswith(path, "/api/vector3d_bin/")
        rest = _uri_decode(path[18:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/vector3d_bin/:run/:file?field=current&stride=2&snap=K")
        end
        name = rest[1:slash_idx-1]
        file = rest[slash_idx+1:end]
        vec_field = :current
        vec_stride = 2
        snap_idx = nothing
        qidx = findfirst('?', file)
        if qidx !== nothing
            query = file[qidx+1:end]
            file = file[1:qidx-1]
            m = match(r"field=(\w+)", query)
            m !== nothing && (vec_field = Symbol(m.captures[1]))
            m2 = match(r"stride=(\d+)", query)
            m2 !== nothing && (vec_stride = parse(Int, m2.captures[1]))
            ms = match(r"snap=(\d+)", query)
            ms !== nothing && (snap_idx = parse(Int, ms.captures[1]))
        end
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        bin = try
            psi, n_comp, ndim, n_pts, F = _load_psi_cached(fpath, psi_cache, snap_idx)
            ndim == 3 || throw(ArgumentError("vector3d requires 3D data"))
            box_size = _load_box_size(fpath)
            _compute_vector3d_binary(psi, n_comp, ndim, n_pts, F, box_size;
                field = vec_field, stride = vec_stride)
        catch e
            return (500, "text/plain", "Error: $(e)")
        end
        (200, "application/octet-stream", bin)

    elseif path == "/api/refresh"
        empty!(data_cache)
        empty!(psi_cache)
        empty!(_vector3d_plans_cache)
        (200, "text/plain", "Cache cleared")
    else
        (404, "text/plain", "Not found")
    end
end

function _send_http_response(sock, status, content_type, body)
    reason = status == 200 ? "OK" : status == 404 ? "Not Found" : "Error"
    body_bytes = body isa Vector{UInt8} ? body : Vector{UInt8}(body)
    write(sock,
        "HTTP/1.1 $status $reason\r\n" *
        "Content-Type: $content_type\r\n" *
        "Content-Length: $(length(body_bytes))\r\n" *
        "Access-Control-Allow-Origin: *\r\n" *
        "Cache-Control: no-store\r\n" *
        "Connection: close\r\n" *
        "\r\n")
    write(sock, body_bytes)
end

function _uri_decode(s::AbstractString)
    replace(s, r"%([0-9A-Fa-f]{2})" => m -> Char(parse(UInt8, m[2:3]; base=16)))
end

function _static_content_type(path::AbstractString)
    endswith(path, ".js")  && return "application/javascript; charset=utf-8"
    endswith(path, ".css") && return "text/css; charset=utf-8"
    endswith(path, ".svg") && return "image/svg+xml"
    endswith(path, ".png") && return "image/png"
    endswith(path, ".ico") && return "image/x-icon"
    endswith(path, ".json") && return "application/json"
    endswith(path, ".map") && return "application/json"
    endswith(path, ".woff2") && return "font/woff2"
    endswith(path, ".woff") && return "font/woff"
    "application/octet-stream"
end

function _serve_static_asset(path::AbstractString)
    # Sanitize: strip leading "/", reject traversal.
    rel = lstrip(_uri_decode(path), '/')
    occursin("..", rel) && return (400, "text/plain", "Bad path")
    full = normpath(joinpath(_WEB_DIST_DIR, rel))
    startswith(full, _WEB_DIST_DIR) || return (400, "text/plain", "Bad path")
    isfile(full) || return (404, "text/plain", "Not found: $path")
    body = read(full)
    (200, _static_content_type(full), body)
end

"""
    _trilinear_upsample(data::Array{Float64,3}, target_n::Int) -> Array{Float64,3}

Upsample a 3D array to `target_n` points per axis using trilinear interpolation.
"""
function _trilinear_upsample(data::Array{Float64,3}, target_n::Int)
    nx, ny, nz = size(data)
    out = Array{Float64,3}(undef, target_n, target_n, target_n)
    @inbounds for iz in 1:target_n
        fz = 1.0 + (iz - 1) * (nz - 1) / (target_n - 1)
        z0 = clamp(floor(Int, fz), 1, nz - 1)
        z1 = z0 + 1
        wz = fz - z0
        for iy in 1:target_n
            fy = 1.0 + (iy - 1) * (ny - 1) / (target_n - 1)
            y0 = clamp(floor(Int, fy), 1, ny - 1)
            y1 = y0 + 1
            wy = fy - y0
            for ix in 1:target_n
                fx = 1.0 + (ix - 1) * (nx - 1) / (target_n - 1)
                x0 = clamp(floor(Int, fx), 1, nx - 1)
                x1 = x0 + 1
                wx = fx - x0
                c000 = data[x0, y0, z0]; c100 = data[x1, y0, z0]
                c010 = data[x0, y1, z0]; c110 = data[x1, y1, z0]
                c001 = data[x0, y0, z1]; c101 = data[x1, y0, z1]
                c011 = data[x0, y1, z1]; c111 = data[x1, y1, z1]
                c00 = c000 * (1 - wx) + c100 * wx
                c01 = c001 * (1 - wx) + c101 * wx
                c10 = c010 * (1 - wx) + c110 * wx
                c11 = c011 * (1 - wx) + c111 * wx
                c0 = c00 * (1 - wy) + c10 * wy
                c1 = c01 * (1 - wy) + c11 * wy
                out[ix, iy, iz] = c0 * (1 - wz) + c1 * wz
            end
        end
    end
    out
end

"""
Compute 3D density for each m-component.
Uses trilinear interpolation to produce smooth output at `target_n` resolution.
Top `max_components` by population are included, plus total.
"""
function _compute_3d_densities(jld2_path::String; target_n::Int = 0, max_components::Int = 0)
    d = JLD2.load(jld2_path)
    psi = d["psi"]
    n_comp = size(psi, ndims(psi))
    ndim = ndims(psi) - 1
    F = div(n_comp - 1, 2)
    m_values = [F - (c - 1) for c in 1:n_comp]
    n_pts = ntuple(i -> size(psi, i), ndim)

    ndim == 3 || throw(ArgumentError("3D density requires 3D data, got $(ndim)D"))

    all_densities = [Float64.(abs2.(view(psi, _component_slice(ndim, n_pts, c)...))) for c in 1:n_comp]
    pops = [sum(dens) for dens in all_densities]
    total_pop = sum(pops)

    total_dens = sum(all_densities)

    sorted_idx = sortperm(pops; rev=true)
    n_keep = max_components > 0 ? min(max_components, n_comp) : n_comp
    top_idx = sorted_idx[1:n_keep]

    # Interpolate only if explicitly requested (target_n > 0)
    out_n = target_n > 0 ? min(target_n, maximum(n_pts) * 2) : 0
    need_interp = out_n > 0 && (out_n != n_pts[1] || out_n != n_pts[2] || out_n != n_pts[3])

    total_out = need_interp ? _trilinear_upsample(total_dens, out_n) : total_dens

    components = Dict{String,Any}[]
    for ci in top_idx
        dens = need_interp ? _trilinear_upsample(all_densities[ci], out_n) : all_densities[ci]
        push!(components, Dict{String,Any}(
            "m" => m_values[ci],
            "population" => pops[ci] / max(total_pop, 1e-300),
            "density" => vec(dens),
        ))
    end

    out_shape = need_interp ? (out_n, out_n, out_n) : n_pts

    Dict{String,Any}(
        "m_values" => [c["m"] for c in components],
        "total_density" => vec(total_out),
        "components" => components,
        "shape" => collect(out_shape),
        "original_shape" => collect(n_pts),
        "interpolated" => need_interp,
    )
end

"""
Read box_size from the config.yaml in the same directory as the JLD2 file.
Returns nothing if not found.
"""
function _read_box_size(jld2_path::String)
    config_path = joinpath(dirname(jld2_path), "config.yaml")
    isfile(config_path) || return nothing
    try
        data = YAML.load_file(config_path)
        pipe = get(data, "pipeline", [])
        isempty(pipe) && return nothing
        gs = first(values(pipe[1]))
        g = get(gs, "grid", nothing)
        g === nothing && return nothing
        box_raw = g isa Dict ? get(g, "box", get(g, "box_size", nothing)) : nothing
        box_raw === nothing && return nothing
        box_raw isa Vector ? Float64.(box_raw) : Float64[Float64(box_raw)]
    catch
        nothing
    end
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
    box = _read_box_size(jld2_path)

    if ndim == 1
        densities = [Float64[abs2(psi[i, c]) for i in 1:n_pts[1]] for c in 1:n_comp]
        x_range = box !== nothing ? [-box[1]/2, box[1]/2] : [0, n_pts[1]-1]
        return Dict{String,Any}(
            "m_values" => m_values,
            "densities" => densities,
            "ndim" => 1,
            "shape" => [n_pts[1]],
            "axis" => 0,
            "box" => box,
            "x_range" => x_range,
        )
    end

    axis = clamp(axis, 1, ndim)
    remaining = [i for i in 1:ndim if i != axis]
    out_shape = ntuple(i -> n_pts[remaining[i]], length(remaining))

    densities = Vector{Vector{Float64}}()
    for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        comp = abs2.(view(psi, idx...))
        col = dropdims(sum(comp; dims=axis); dims=axis)
        push!(densities, vec(col))
    end

    total = zeros(Float64, prod(out_shape))
    for dens in densities
        total .+= dens
    end

    axis_names = ["x","y","z"]
    ax_labels = [axis_names[i] for i in remaining]
    ax_ranges = if box !== nothing && length(box) >= ndim
        [[-box[i]/2, box[i]/2] for i in remaining]
    else
        [[0, n_pts[i]-1] for i in remaining]
    end

    Dict{String,Any}(
        "m_values" => m_values,
        "densities" => densities,
        "total_density" => total,
        "ndim" => ndim,
        "shape" => collect(out_shape),
        "axis" => axis,
        "axis_labels" => ax_labels,
        "axis_ranges" => ax_ranges,
        "box" => box,
    )
end

"""Column densities from pre-loaded (cached) psi."""
function _compute_column_densities_from_cache(psi, n_comp, ndim, n_pts, F, axis::Int, jld2_path::String)
    m_values = [F - (c - 1) for c in 1:n_comp]
    box = _read_box_size(jld2_path)

    if ndim == 1
        densities = [Float64[abs2(psi[i, c]) for i in 1:n_pts[1]] for c in 1:n_comp]
        x_range = box !== nothing ? [-box[1]/2, box[1]/2] : [0, n_pts[1]-1]
        return Dict{String,Any}(
            "m_values" => m_values, "densities" => densities,
            "ndim" => 1, "shape" => [n_pts[1]], "axis" => 0,
            "box" => box, "x_range" => x_range,
        )
    end

    axis = clamp(axis, 1, ndim)
    remaining = [i for i in 1:ndim if i != axis]
    out_shape = ntuple(i -> n_pts[remaining[i]], length(remaining))

    densities = Vector{Vector{Float64}}()
    for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        comp = abs2.(view(psi, idx...))
        col = dropdims(sum(comp; dims=axis); dims=axis)
        push!(densities, vec(col))
    end

    total = zeros(Float64, prod(out_shape))
    for dens in densities
        total .+= dens
    end

    axis_names = ["x","y","z"]
    ax_labels = [axis_names[i] for i in remaining]
    ax_ranges = if box !== nothing && length(box) >= ndim
        [[-box[i]/2, box[i]/2] for i in remaining]
    else
        [[0, n_pts[i]-1] for i in remaining]
    end

    Dict{String,Any}(
        "m_values" => m_values, "densities" => densities,
        "total_density" => total, "ndim" => ndim,
        "shape" => collect(out_shape), "axis" => axis,
        "axis_labels" => ax_labels, "axis_ranges" => ax_ranges, "box" => box,
    )
end

"""
Per-component phase arg(ψ_m) at a single plane (index `slice_idx` along `axis`).
3D only. Also returns per-component |ψ_m|² at the same plane so the frontend
can mask phase at low density where the angle is ill-defined.
"""
function _compute_phase_slice_from_cache(
    psi, n_comp, ndim, n_pts, F,
    axis::Int, slice_idx::Union{Nothing,Int},
    jld2_path::String,
)
    ndim == 3 || throw(ArgumentError("Phase slice requires 3D data, got $(ndim)D"))
    m_values = [F - (c - 1) for c in 1:n_comp]
    axis = clamp(axis, 1, ndim)
    k = slice_idx === nothing ? max(1, n_pts[axis] ÷ 2) : clamp(slice_idx, 1, n_pts[axis])

    remaining = [i for i in 1:ndim if i != axis]
    out_shape = ntuple(i -> n_pts[remaining[i]], length(remaining))
    box = _read_box_size(jld2_path)

    phases = Vector{Vector{Float64}}()
    densities = Vector{Vector{Float64}}()
    for c in 1:n_comp
        comp_view = view(psi, _component_slice(ndim, n_pts, c)...)
        slice = selectdim(comp_view, axis, k)  # 2D complex
        push!(phases, vec(angle.(slice)))
        push!(densities, vec(abs2.(slice)))
    end

    axis_names = ["x","y","z"]
    ax_labels = [axis_names[i] for i in remaining]
    ax_ranges = if box !== nothing && length(box) >= ndim
        [[-box[i]/2, box[i]/2] for i in remaining]
    else
        [[0, n_pts[i]-1] for i in remaining]
    end

    Dict{String,Any}(
        "m_values" => m_values,
        "phases" => phases,
        "densities" => densities,
        "ndim" => ndim,
        "axis" => axis,
        "slice_index" => k,
        "shape" => collect(out_shape),
        "axis_labels" => ax_labels,
        "axis_ranges" => ax_ranges,
        "box" => box,
    )
end

# --- Binary APIs for performance ---

"""Load psi from JLD2 with caching. Returns (psi, n_comp, ndim, n_pts, F).

When `snap_idx === nothing` (default) the final `psi` field is returned.
When `snap_idx` is a positive integer, loads the requested time-slice
from `dynamics/psi_snapshots` (saved by runs with
`save_psi_snapshots: true`); the 5D array is up-cast to ComplexF64 so
downstream code (FFT, probability_current, etc.) runs at its native
precision."""
function _load_psi_cached(
    jld2_path::String,
    cache::Dict{String,Any},
    snap_idx::Union{Nothing,Int} = nothing,
)
    key = snap_idx === nothing ? jld2_path : "$(jld2_path)#snap=$(snap_idx)"
    get!(cache, key) do
        if snap_idx === nothing
            d = JLD2.load(jld2_path)
            psi = d["psi"]
        else
            snaps = JLD2.load(jld2_path, "dynamics/psi_snapshots")
            n_snaps = size(snaps, ndims(snaps))
            k = clamp(snap_idx, 1, n_snaps)
            idx = ntuple(d -> d == ndims(snaps) ? k : Colon(), ndims(snaps))
            psi = ComplexF64.(view(snaps, idx...))
        end
        n_comp = size(psi, ndims(psi))
        ndim = ndims(psi) - 1
        F = div(n_comp - 1, 2)
        n_pts = ntuple(i -> size(psi, i), ndim)
        (psi, n_comp, ndim, n_pts, F)
    end
end

"""Return metadata about the saved snapshot time series, or nothing if
the file has no `dynamics/psi_snapshots` key."""
function _snapshots_metadata(jld2_path::String)
    try
        jldopen(jld2_path, "r") do f
            if !haskey(f, "dynamics/psi_snapshots")
                return nothing
            end
            snaps = f["dynamics/psi_snapshots"]
            n_snaps = size(snaps, ndims(snaps))
            times = haskey(f, "dynamics/times") ? Float64.(f["dynamics/times"]) : Float64[]
            Dict{String,Any}(
                "n_snapshots" => n_snaps,
                "times" => times,
                "shape" => collect(size(snaps)[1:end-1]),
            )
        end
    catch
        nothing
    end
end

"""
Compute a single 3D density component as binary Float32.
"""
function _compute_3d_density_binary(psi, n_comp, ndim, n_pts, F; component::Int = 0)
    ndim == 3 || throw(ArgumentError("3D density requires 3D data"))
    _pack_3d_binary(psi, n_comp, ndim, n_pts, F, component)
end

"""
3D vorticity magnitude |∇×v_s| as Float32 volume. Matches density3d_bin's
header layout so the frontend can reuse the same parser. Breathing/radial
modes have ∇×v = 0, so peaks in this field isolate the rotational part of
the flow — vortex cores show up cleanly even when the mass current is
dominated by a radial-inflow component.
"""
function _compute_3d_vorticity_binary(psi, n_comp, ndim, n_pts, F, box_size)
    ndim == 3 || throw(ArgumentError("3D vorticity requires 3D data"))
    plans, grid = _get_plans_and_grid(n_pts, box_size)
    # v = j/n explodes where n → 0 (trap vacuum), and ∇×v inherits those
    # spurious peaks. Scale the density cutoff to the actual cloud: 1% of
    # peak |ψ|² masks out everything outside the Thomas-Fermi radius without
    # touching the physical vortex-core structure (where n is small but the
    # j ≈ nv compensates the denominator).
    total_n = sum(m -> Float64.(abs2.(view(psi, _component_slice(ndim, n_pts, m)...))), 1:n_comp)
    n_peak = maximum(total_n)
    cutoff = max(1e-8, 1e-2 * n_peak)
    ωx, ωy, ωz = superfluid_vorticity(psi, grid, plans; density_cutoff = cutoff)

    N = prod(n_pts)
    # Also zero the output outside the cloud to be defensive; the cutoff
    # above zeroes v, but numerical ∇ can still pick up edge gradients.
    mag = Vector{Float32}(undef, N)
    total_flat = vec(total_n)
    @inbounds for i = 1:N
        if total_flat[i] < cutoff
            mag[i] = 0.0f0
        else
            a = ωx[i]; b = ωy[i]; c = ωz[i]
            mag[i] = Float32(sqrt(a*a + b*b + c*c))
        end
    end

    pops = Float32[Float32(sum(abs2, view(psi, _component_slice(ndim, n_pts, m)...))) for m in 1:n_comp]
    total_pop = sum(pops)
    pops ./= max(total_pop, 1f-30)

    buf = IOBuffer(; sizehint = 24 + n_comp * 4 + N * 4)
    write(buf, Int32(n_pts[1]), Int32(n_pts[2]), Int32(n_pts[3]))
    write(buf, Int32(n_comp), Int32(F), Int32(0))
    write(buf, pops)
    write(buf, mag)
    take!(buf)
end

"""
3D per-component phase arg(ψ_m) as Float32 volume. Matches density3d_bin's
header layout so the frontend can reuse the same parser. Requires a
specific component (`component >= 1`); the total spinor has no scalar phase.
"""
function _compute_3d_phase_binary(psi, n_comp, ndim, n_pts, F; component::Int = 0)
    ndim == 3 || throw(ArgumentError("3D phase requires 3D data"))
    component >= 1 || throw(ArgumentError("phase3d requires component >= 1 (per-m only)"))
    c = clamp(component, 1, n_comp)

    psi_c = view(psi, _component_slice(ndim, n_pts, c)...)
    phase = zeros(Float32, n_pts...)
    @inbounds for i in eachindex(psi_c)
        phase[i] = Float32(angle(psi_c[i]))
    end

    pops = Float32[Float32(sum(abs2, view(psi, _component_slice(ndim, n_pts, m)...))) for m in 1:n_comp]
    total_pop = sum(pops)
    pops ./= max(total_pop, 1f-30)

    N = prod(n_pts)
    buf = IOBuffer(; sizehint = 24 + n_comp * 4 + N * 4)
    write(buf, Int32(n_pts[1]), Int32(n_pts[2]), Int32(n_pts[3]))
    write(buf, Int32(n_comp), Int32(F), Int32(c))
    write(buf, pops)
    write(buf, phase)
    take!(buf)
end

"""
Compute rotated 3D density: rotate quantization axis by angle_deg around y, then extract component.
Optimized: only computes the single requested component (not full matrix multiply).
Total density (component=0) is rotation-invariant, so skip rotation entirely.
"""
function _compute_rotated_3d_density_binary(psi, n_comp, ndim, n_pts, F; angle_deg::Float64 = 0.0, component::Int = 0)
    ndim == 3 || throw(ArgumentError("3D density requires 3D data"))
    if abs(angle_deg) < 0.01 || component == 0
        return _pack_3d_binary(psi, n_comp, ndim, n_pts, F, component)
    end
    beta = angle_deg * π / 180
    Fy = spin_matrices(F).Fy
    R = exp(-im * beta * Matrix{ComplexF64}(Fy))

    c = clamp(component, 1, n_comp)
    N = prod(n_pts)
    # ψ'_c(r) = Σ_m R[c,m] * ψ_m(r) — only one row of R needed
    R_row = R[c, :]
    psi_flat = reshape(psi, N, n_comp)
    psi_c_rot = psi_flat * conj.(R_row)  # (N,D) * (D,) → (N,) complex
    dens = Float32.(abs2.(psi_c_rot))

    # Compute rotated populations (cheap: just norms of R * population_vector)
    pops_orig = Float32[Float32(sum(abs2, view(psi, _component_slice(ndim, n_pts, m)...))) for m in 1:n_comp]
    total_pop = sum(pops_orig)
    pops_orig ./= max(total_pop, 1f-30)

    buf = IOBuffer(; sizehint = 24 + n_comp * 4 + N * 4)
    write(buf, Int32(n_pts[1]), Int32(n_pts[2]), Int32(n_pts[3]))
    write(buf, Int32(n_comp), Int32(F), Int32(component))
    write(buf, pops_orig)
    write(buf, dens)
    take!(buf)
end

function _pack_3d_binary(psi, n_comp, ndim, n_pts, F, component)
    N = prod(n_pts)
    # Use 3D array matching psi_c shape (eachindex returns CartesianIndices for SubArray)
    dens = zeros(Float32, n_pts...)
    if component == 0
        for c in 1:n_comp
            psi_c = view(psi, _component_slice(ndim, n_pts, c)...)
            @inbounds for i in eachindex(psi_c)
                dens[i] += Float32(abs2(psi_c[i]))
            end
        end
    else
        c = clamp(component, 1, n_comp)
        psi_c = view(psi, _component_slice(ndim, n_pts, c)...)
        @inbounds for i in eachindex(psi_c)
            dens[i] = Float32(abs2(psi_c[i]))
        end
    end

    pops = zeros(Float32, n_comp)
    for c in 1:n_comp
        s = 0.0
        for v in view(psi, _component_slice(ndim, n_pts, c)...)
            s += abs2(v)
        end
        pops[c] = Float32(s)
    end
    total_pop = sum(pops)
    pops ./= max(total_pop, 1f-30)

    buf = IOBuffer(; sizehint = 24 + n_comp * 4 + N * 4)
    write(buf, Int32(n_pts[1]), Int32(n_pts[2]), Int32(n_pts[3]))
    write(buf, Int32(n_comp), Int32(F), Int32(component))
    write(buf, pops)
    write(buf, vec(dens))  # flatten to column-major 1D
    take!(buf)
end

"""
Compute coherence matrix C_{mn}(x,y) = Σ_z ψ_m*(x,y,z) ψ_n(x,y,z) for quantization axis rotation.
"""
function _compute_coherence_matrix_binary(psi, n_comp, ndim, n_pts, F, axis::Int = 3)
    ndim == 3 || throw(ArgumentError("Coherence matrix requires 3D data"))
    axis = clamp(axis, 1, 3)

    remaining = [i for i in 1:3 if i != axis]
    n1, n2 = n_pts[remaining[1]], n_pts[remaining[2]]

    buf = IOBuffer()
    # Header
    write(buf, Int32(n1), Int32(n2), Int32(n_comp), Int32(F), Int32(axis))

    # Compute and write upper triangle
    for m in 1:n_comp
        psi_m = view(psi, _component_slice(ndim, n_pts, m)...)
        for n in m:n_comp
            psi_n = view(psi, _component_slice(ndim, n_pts, n)...)
            # C_{mn}(x,y) = Σ_axis conj(ψ_m) * ψ_n
            c_mn = dropdims(sum(conj.(psi_m) .* psi_n; dims=axis); dims=axis)
            for val in vec(c_mn)
                write(buf, Float32(real(val)), Float32(imag(val)))
            end
        end
    end

    take!(buf)
end

# --- Vector field (current / spin_density / velocity) binary API ---

const _vector3d_plans_cache = Dict{NTuple{3,Int},Tuple{FFTPlans,Grid{3}}}()

function _load_box_size(jld2_path::String)
    # Preferred: pull "grid_box_size" from the JLD2 file itself (newer runs
    # embed it). Older runs — e.g. eu151_edh/point_001.jld2 — don't. FileIO
    # may re-wrap JLD2's KeyError as CapturedException, so swallow any
    # lookup failure and fall back to the sibling config.yaml.
    try
        d = JLD2.load(jld2_path, "grid_box_size")
        return NTuple{3,Float64}(d)
    catch
        # fall through
    end
    box = _read_box_size(jld2_path)
    if box === nothing || length(box) < 3
        throw(ArgumentError(
            "Cannot resolve box_size for $(jld2_path): missing `grid_box_size` " *
            "in the JLD2 file and no usable grid.box in config.yaml.",
        ))
    end
    NTuple{3,Float64}((Float64(box[1]), Float64(box[2]), Float64(box[3])))
end

function _get_plans_and_grid(n_pts::NTuple{3,Int}, box_size::NTuple{3,Float64})
    get!(_vector3d_plans_cache, n_pts) do
        grid = make_grid(GridConfig(n_pts, box_size))
        plans = make_fft_plans(n_pts; flags = FFTW.ESTIMATE)
        (plans, grid)
    end
end

function _compute_vector3d_binary(psi, n_comp, ndim, n_pts, F, box_size;
    field::Symbol = :current, stride::Int = 2)

    stride = max(1, stride)
    sub_idx = ntuple(d -> 1:stride:n_pts[d], 3)
    n_sub = ntuple(d -> length(sub_idx[d]), 3)

    if field === :spin_density
        sm = spin_matrices(F)
        vx, vy, vz = spin_density_vector(psi, sm, 3)
    else
        plans, grid = _get_plans_and_grid(n_pts, box_size)
        if field === :current
            vx, vy, vz = probability_current(psi, grid, plans)
        elseif field === :velocity
            vx, vy, vz = superfluid_velocity(psi, grid, plans)
        else
            throw(ArgumentError("Unknown vector field: $field"))
        end
    end

    N_sub = prod(n_sub)
    buf = IOBuffer(; sizehint = 28 + 4 * 4 * N_sub)
    write(buf, Int32(n_sub[1]), Int32(n_sub[2]), Int32(n_sub[3]))
    write(buf, Int32(stride), Int32(0), Int32(0), Int32(0))

    for iz in sub_idx[3], iy in sub_idx[2], ix in sub_idx[1]
        ux = Float32(vx[ix, iy, iz])
        uy = Float32(vy[ix, iy, iz])
        uz = Float32(vz[ix, iy, iz])
        mag = sqrt(ux^2 + uy^2 + uz^2)
        write(buf, ux, uy, uz, mag)
    end

    take!(buf)
end
