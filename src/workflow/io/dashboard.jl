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
                "mz_actual" => get(d, "mz_actual", NaN),
                "populations" => pops_norm,
                "m_values" => m_values,
                "override" => scan_params,
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
_write_json(io::IO, n::Real) =
    if isnan(n)
        print(io, "null")
    elseif isinf(n)
        print(io, "null")
    else
        print(io, n)
    end
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
- `GET /api/physics_summary/:run/:file` → integrator metadata,
  Larmor regime classification, Lz/Fz/m-top extremes summary
  (lightweight — no snapshot loading required)

See src/workflow/io/dashboard.jl for the full /api surface that the
React app consumes.
"""
function serve_dashboard(port::Int=8080; base_dir::String="runs")
    if !isfile(_WEB_DIST_INDEX)
        throw(
            ArgumentError(
                "React dashboard not built. Run: cd web && bun install && bun run build"
            ),
        )
    end
    html_content = read(_WEB_DIST_INDEX, String)
    legacy_html = isfile(_LEGACY_DASHBOARD_HTML) ? read(_LEGACY_DASHBOARD_HTML, String) : ""
    data_cache = Dict{String, String}()
    psi_cache = Dict{String, Any}()  # path → (psi, n_comp, n_pts, F, pops)

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
                sock, html_content, legacy_html, data_cache, psi_cache, base_dir
            )
        end
    catch e
        e isa InterruptException || rethrow(e)
        println("\nDashboard server stopped.")
    finally
        close(server)
    end
end

function _handle_dashboard_connection(
    sock, html_content, legacy_html, data_cache, psi_cache, base_dir
)
    try
        # Keep-alive loop: a single TCP connection serves successive
        # requests. Browsers cap to ~6 connections per origin, and the
        # scrubber fires many small density_bin GETs in a burst — recycling
        # the connection avoids per-request TCP setup (negligible on
        # localhost but costly over LAN/SSH tunnel). We avoid `eof(sock)`
        # as the loop guard because it calls `wait_readnb(s, 1)` and adds
        # ~1 ms per iteration on idle sockets; relying on `readline`
        # returning an empty string at EOF is simpler and faster.
        while true
            request_line = readline(sock)
            isempty(request_line) && break
            parts = split(request_line)
            length(parts) >= 2 || break
            method = String(parts[1])
            path = String(parts[2])
            http_ver = length(parts) >= 3 ? String(parts[3]) : "HTTP/1.0"

            # HTTP/1.0 defaults to close; HTTP/1.1 defaults to keep-alive.
            client_close = (http_ver == "HTTP/1.0")
            content_length = 0
            accept_gzip = false
            ws_key = ""
            ws_upgrade = false
            while true
                line = readline(sock)
                (isempty(line) || line == "\r") && break
                lc = lowercase(line)
                if startswith(lc, "content-length:")
                    content_length = parse(Int, strip(split(line, ':'; limit=2)[2]))
                elseif startswith(lc, "connection:")
                    val = strip(lowercase(split(line, ':'; limit=2)[2]))
                    if occursin("close", val)
                        client_close = true
                    elseif occursin("keep-alive", val)
                        client_close = false
                    elseif occursin("upgrade", val)
                        ws_upgrade = true
                    end
                elseif startswith(lc, "upgrade:")
                    occursin("websocket", lowercase(split(line, ':'; limit=2)[2])) &&
                        (ws_upgrade = true)
                elseif startswith(lc, "sec-websocket-key:")
                    ws_key = String(strip(split(line, ':'; limit=2)[2]))
                elseif startswith(lc, "accept-encoding:")
                    val = lowercase(split(line, ':'; limit=2)[2])
                    accept_gzip = occursin("gzip", val)
                end
            end

            # WebSocket upgrade hijacks the connection — handshake +
            # binary push loop, then close the socket on disconnect.
            if ws_upgrade && method == "GET" && !isempty(ws_key) && startswith(path, "/ws/")
                _websocket_serve(sock, path, ws_key, psi_cache, base_dir)
                break
            end

            keep_alive = !client_close
            if method == "POST"
                body_bytes = content_length > 0 ? read(sock, content_length) : UInt8[]
                status, content_type, body = _route_dashboard_post(
                    path, body_bytes, base_dir
                )
                _send_http_response(sock, status, content_type, body; keep_alive, accept_gzip)
            else
                status, content_type, body = _route_dashboard(
                    path, html_content, legacy_html, data_cache, psi_cache, base_dir
                )
                _send_http_response(sock, status, content_type, body; keep_alive, accept_gzip)
            end

            keep_alive || break
        end
    catch e
        e isa EOFError || @warn "Dashboard connection error: $e"
    finally
        close(sock)
    end
end

"""
    _route_dashboard_post(path, body_bytes, base_dir) -> (status, content_type, body)

POST endpoints. Currently supports:

  POST /api/lab/image/<run_name>     body = raw PNG bytes
    → writes runs/<run_name>/lab_images/shot_NNNNN.png
       with NNNNN auto-incremented per run.

Lab acquisition scripts can ship images straight off the camera with
`curl --data-binary @shot.png http://host:port/api/lab/image/today`.
"""
function _route_dashboard_post(path, body_bytes, base_dir)
    if startswith(path, "/api/lab/image/")
        run_name = _uri_decode(path[(length("/api/lab/image/") + 1):end])
        run_dir = joinpath(base_dir, run_name)
        isdir(run_dir) || return (404, "text/plain", "Run not found: $run_name")
        img_dir = joinpath(run_dir, "lab_images")
        mkpath(img_dir)
        # Auto-increment shot index based on existing files
        existing = filter(f -> startswith(f, "shot_"), readdir(img_dir))
        n = length(existing) + 1
        out_path = joinpath(img_dir, "shot_$(lpad(n, 5, '0')).png")
        write(out_path, body_bytes)
        body_json = "{\"path\":\"$out_path\",\"size\":$(length(body_bytes)),\"shot_id\":$n}"
        return (200, "application/json", body_json)
    end
    (404, "text/plain", "POST endpoint not found: $path")
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
    elseif startswith(path, "/runs/") && occursin("/lab_images/", path)
        # Static-serve lab images posted via /api/lab/image/<run> POST.
        # Path looks like /runs/<run_name>/lab_images/shot_NNNNN.png.
        # Resolve relative to base_dir, refuse path-traversal (..).
        rel = _uri_decode(path[7:end])    # strip leading "/runs/"
        occursin("..", rel) && return (400, "text/plain", "bad path")
        full = joinpath(base_dir, rel)
        if isfile(full) && (endswith(full, ".png") || endswith(full, ".fits"))
            ct = endswith(full, ".png") ? "image/png" : "application/octet-stream"
            return (200, ct, read(full))
        end
        return (404, "text/plain", "lab image not found: $rel")
    elseif startswith(path, "/api/lab/list/")
        return _route_lab_list(path, base_dir)
    elseif path == "/api/live/list"
        return _route_live_list(base_dir)
    elseif startswith(path, "/api/live/")
        return _route_live(path, base_dir)
    elseif startswith(path, "/api/scan_status/")
        return _route_scan_status(path, base_dir)
    elseif path == "/api/runs"
        runs = list_runs(base_dir)
        (200, "application/json", "[" * join(["\"$r\"" for r in runs], ",") * "]")
    elseif startswith(path, "/api/data/")
        return _route_data(path, base_dir, data_cache)
    elseif startswith(path, "/api/density/")
        return _route_density2d(path, base_dir, psi_cache)
    elseif startswith(path, "/api/phase/")
        return _route_phase2d(path, base_dir, psi_cache)
    elseif startswith(path, "/api/density_bin/")
        return _route_density_bin(path, base_dir, psi_cache)
    elseif startswith(path, "/api/phase_bin/")
        return _route_phase_bin(path, base_dir, psi_cache)
    elseif startswith(path, "/api/density3d/")
        return _route_density3d(path, base_dir)
    elseif startswith(path, "/api/density3d_bin/")
        return _route_density3d_bin(path, base_dir, psi_cache)
    elseif startswith(path, "/api/dynamics_series/")
        return _route_dynamics_series(path, base_dir)
    elseif startswith(path, "/api/scan_group/")
        return _route_scan_group(path, base_dir, data_cache, psi_cache)

    elseif startswith(path, "/api/physics_summary/")
        return _route_physics_summary(path, base_dir, psi_cache)

    elseif startswith(path, "/api/snapshots/")
        return _route_snapshots(path, base_dir, psi_cache)

    elseif startswith(path, "/api/ensemble/")
        return _route_ensemble(path, base_dir)

    elseif startswith(path, "/api/density3d_atlas/")
        return _route_density3d_atlas(path, base_dir, psi_cache)

    elseif startswith(path, "/api/density_atlas/")
        return _route_density_atlas(path, base_dir, psi_cache)

    elseif startswith(path, "/api/synthetic_dispersion/")
        return _route_synthetic_dispersion(path, base_dir, psi_cache)

    elseif startswith(path, "/api/density_max/")
        return _route_density_max(path, base_dir, psi_cache)

    elseif startswith(path, "/api/vortex_lines/")
        return _route_vortex_lines(path, base_dir, psi_cache)

    elseif startswith(path, "/api/vorticity3d_bin/")
        return _route_vorticity3d_bin(path, base_dir, psi_cache)

    elseif startswith(path, "/api/phase3d_bin/")
        return _route_phase3d_bin(path, base_dir, psi_cache)

    elseif startswith(path, "/api/coherence/")
        return _route_coherence(path, base_dir, psi_cache)

    elseif startswith(path, "/api/density3d_rotated/")
        return _route_density3d_rotated(path, base_dir, psi_cache)

    elseif startswith(path, "/api/vector3d_bin/")
        return _route_vector3d_bin(path, base_dir, psi_cache)

    elseif path == "/api/refresh"
        clear_all_caches!(data_cache, psi_cache)
        (200, "text/plain", "Cache cleared")
    elseif startswith(path, "/api/")
        # Unknown API route — actual 404
        (404, "text/plain", "Not found: $path")
    else
        # SPA client-side routing fallback. The React app uses
        # react-router (or equivalent) so URLs like /runs/foo /view/3d
        # /viz/density-slice are valid in-app routes that don't exist
        # on the server. Serve index.html and let the JS router pick
        # them up. Same trick as nginx `try_files $uri /index.html`.
        (200, "text/html; charset=utf-8", html_content)
    end
end

function _send_http_response(
    sock, status, content_type, body; keep_alive::Bool=false, accept_gzip::Bool=false
)
    reason = if status == 200
        "OK"
    elseif status == 404
        "Not Found"
    else
        "Error"
    end
    body_bytes = body isa Vector{UInt8} ? body : Vector{UInt8}(body)
    # Gzip large bodies when the client asked for it. Float32 binaries
    # only compress ~10-15% (fundamentally noisy bit patterns), but on a
    # bandwidth-constrained tunnel (SSH-forwarded port, remote desktop)
    # even that helps. Threshold + level-1 gzip keeps the localhost
    # warm path's CPU cost negligible.
    encoding_hdr = ""
    if accept_gzip && length(body_bytes) >= _GZIP_THRESHOLD_BYTES
        try
            compressed = transcode(GzipCompressor(; level=1), body_bytes)
            if length(compressed) < length(body_bytes)
                body_bytes = compressed
                encoding_hdr = "Content-Encoding: gzip\r\n"
            end
        catch
            # If gzip blows up for any reason, just send uncompressed.
        end
    end
    conn_hdr = if keep_alive
        "Connection: keep-alive\r\nKeep-Alive: timeout=30\r\n"
    else
        "Connection: close\r\n"
    end
    write(sock,
        "HTTP/1.1 $status $reason\r\n" *
        "Content-Type: $content_type\r\n" *
        "Content-Length: $(length(body_bytes))\r\n" *
        "Access-Control-Allow-Origin: *\r\n" *
        "Cache-Control: no-store\r\n" *
        encoding_hdr *
        conn_hdr *
        "\r\n")
    write(sock, body_bytes)
end

function _uri_decode(s::AbstractString)
    replace(s, r"%([0-9A-Fa-f]{2})" => m -> Char(parse(UInt8, m[2:3]; base=16)))
end

function _static_content_type(path::AbstractString)
    endswith(path, ".js") && return "application/javascript; charset=utf-8"
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
