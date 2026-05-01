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
        # /api/lab/list/<run_name>?limit=N → JSON array of recent lab
        # images uploaded via POST /api/lab/image/<run>. Most recent
        # first, capped to `limit` (default 32 — matches the React
        # LabImageOverlay's ring buffer expectation).
        run_name = _uri_decode(path[(length("/api/lab/list/") + 1):end])
        qidx = findfirst('?', run_name)
        limit = 32
        if qidx !== nothing
            query = run_name[(qidx + 1):end]
            run_name = run_name[1:(qidx - 1)]
            m = match(r"limit=(\d+)", query)
            m !== nothing && (limit = parse(Int, m.captures[1]))
        end
        img_dir = joinpath(base_dir, run_name, "lab_images")
        if !isdir(img_dir)
            return (200, "application/json", "[]")
        end
        files = sort(filter(f -> startswith(f, "shot_") && endswith(f, ".png"),
                readdir(img_dir)); rev=true)
        files = files[1:min(limit, length(files))]
        items = map(files) do f
            full = joinpath(img_dir, f)
            mt = round(Int, mtime(full) * 1000)
            sz = filesize(full)
            "{\"name\":\"$f\",\"url\":\"/runs/$(run_name)/lab_images/$(f)\",\"mtime_ms\":$mt,\"size\":$sz}"
        end
        (200, "application/json", "[" * join(items, ",") * "]")

    elseif path == "/api/live/list"
        # Scan base_dir/* for runs whose _live_status.json was touched in
        # the last 5 minutes — those are presumed actively running. Return
        # a JSON array of {run, mtime_ms, age_s}.
        cutoff_s = 300.0
        active = String[]
        if isdir(base_dir)
            now_s = time()
            for entry in readdir(base_dir)
                full = joinpath(base_dir, entry, "_live_status.json")
                isfile(full) || continue
                age = now_s - mtime(full)
                age <= cutoff_s || continue
                mt = round(Int, mtime(full) * 1000)
                push!(active,
                    "{\"run\":\"$entry\",\"mtime_ms\":$mt,\"age_s\":$(round(age; digits=1))}")
            end
        end
        (200, "application/json", "[" * join(active, ",") * "]")

    elseif startswith(path, "/api/live/")
        # /api/live/<run_name> → contents of base_dir/<run>/_live_status.json
        run_name = _uri_decode(path[(length("/api/live/") + 1):end])
        status_path = joinpath(base_dir, run_name, "_live_status.json")
        if !isfile(status_path)
            return (404, "application/json", "{\"error\":\"no live status for $run_name\"}")
        end
        body = read(status_path, String)
        (200, "application/json", body)

    elseif startswith(path, "/api/scan_status/")
        # /api/scan_status/<run_name> → JSON with {completed, expected,
        # latest_mtime_s, eta_s} so the dashboard can show "12/144 done · ETA 9h"
        # for an in-progress overnight scan. expected may be null when the
        # config has no scan block.
        run_name = _uri_decode(path[(length("/api/scan_status/") + 1):end])
        status = run_status(joinpath(base_dir, run_name))
        if !status.exists
            return (404, "application/json", "{\"error\":\"unknown run $run_name\"}")
        end
        expected_str = status.expected === nothing ? "null" : string(status.expected)
        latest_str =
            isnan(status.latest_mtime_s) ? "null" :
            string(round(status.latest_mtime_s; digits=3))
        eta_str = isnan(status.eta_s) ? "null" :
                  string(round(status.eta_s; digits=1))
        body =
            "{\"completed\":$(status.completed),\"expected\":$expected_str," *
            "\"latest_mtime_s\":$latest_str,\"eta_s\":$eta_str}"
        (200, "application/json", body)

    elseif path == "/api/runs"
        runs = list_runs(base_dir)
        (200, "application/json", "[" * join(["\"$r\"" for r in runs], ",") * "]")
    elseif startswith(path, "/api/data/")
        name = _uri_decode(path[11:end])
        run_dir = joinpath(base_dir, name)
        if !isdir(run_dir)
            return (404, "text/plain", "Run not found: $name")
        end
        # Cache only completed runs. In-progress runs (no point_*.jld2 yet,
        # or whose point file count differs from a prior cache hit) bypass
        # the cache so the dashboard reflects new files as the batch lands
        # them. Without this guard the first request during a run cached
        # the empty in-progress response and the dashboard never updated
        # even after `point_001.jld2` appeared on disk.
        live_count = count(f -> startswith(f, "point_") && endswith(f, ".jld2"),
            readdir(run_dir))
        cache_key = "$name#$live_count"
        json = get!(data_cache, cache_key) do
            try
                _json_string(generate_dashboard_data(run_dir))
            catch e
                "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
            end
        end
        (200, "application/json", json)
    elseif startswith(path, "/api/density/")
        # /api/density/run_name/point_001.jld2?axis=3&snap=K
        rest = _uri_decode(path[14:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/density/:run/:file")
        end
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        axis = 3  # default: integrate along z
        snap_idx = nothing
        qidx = findfirst('?', file)
        if qidx !== nothing
            query = file[(qidx + 1):end]
            file = file[1:(qidx - 1)]
            m = match(r"axis=(\d+)", query)
            m !== nothing && (axis = parse(Int, m.captures[1]))
            ms = match(r"snap=(\d+)", query)
            ms !== nothing && (snap_idx = parse(Int, ms.captures[1]))
        end
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        json = try
            cached = _load_psi_cached(fpath, psi_cache, snap_idx)
            _json_string(_compute_column_densities_from_cache(cached..., axis, fpath))
        catch e
            "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
        end
        (200, "application/json", json)

    elseif startswith(path, "/api/phase/")
        # /api/phase/:run/:file?axis=N&slice=K&snap=S
        rest = _uri_decode(path[12:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/phase/:run/:file?axis=N&slice=K")
        end
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        axis = 3
        slice_idx = nothing
        snap_idx = nothing
        qidx = findfirst('?', file)
        if qidx !== nothing
            query = file[(qidx + 1):end]
            file = file[1:(qidx - 1)]
            m = match(r"axis=(\d+)", query)
            m !== nothing && (axis = parse(Int, m.captures[1]))
            ms = match(r"slice=(\d+)", query)
            ms !== nothing && (slice_idx = parse(Int, ms.captures[1]))
            mn = match(r"snap=(\d+)", query)
            mn !== nothing && (snap_idx = parse(Int, mn.captures[1]))
        end
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        json = try
            cached = _load_psi_cached(fpath, psi_cache, snap_idx)
            _json_string(_compute_phase_slice_from_cache(cached..., axis, slice_idx, fpath))
        catch e
            "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
        end
        (200, "application/json", json)

    elseif startswith(path, "/api/density_bin/")
        # /api/density_bin/:run/:file?axis=N&snap=K — packed Float32 column density.
        # ~7× smaller than the JSON endpoint and skips JSON.parse on the
        # client; the time-scrubber needs this to stay <20 ms per frame.
        rest = _uri_decode(path[18:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/density_bin/:run/:file")
        end
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        axis = 3
        snap_idx = nothing
        qidx = findfirst('?', file)
        if qidx !== nothing
            query = file[(qidx + 1):end]
            file = file[1:(qidx - 1)]
            m = match(r"axis=(\d+)", query)
            m !== nothing && (axis = parse(Int, m.captures[1]))
            ms = match(r"snap=(\d+)", query)
            ms !== nothing && (snap_idx = parse(Int, ms.captures[1]))
        end
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        cache_key = "density_bin:$(fpath)#snap=$(snap_idx)#axis=$(axis)"
        bin = if haskey(psi_cache, cache_key)
            psi_cache[cache_key]
        else
            while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                _evict_one!(psi_cache)
            end
            v = try
                _compute_column_density_binary(
                    _load_psi_cached(fpath, psi_cache, snap_idx)..., axis, fpath
                )
            catch e
                return (500, "text/plain", "Error: $(e)")
            end
            psi_cache[cache_key] = v
            v
        end
        (200, "application/octet-stream", bin)

    elseif startswith(path, "/api/phase_bin/")
        # /api/phase_bin/:run/:file?axis=N&slice=K&snap=S — packed Float32
        # phase + |ψ_m|² for low-density masking. Same speed motivation as
        # density_bin.
        rest = _uri_decode(path[16:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/phase_bin/:run/:file")
        end
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        axis = 3
        slice_idx = nothing
        snap_idx = nothing
        qidx = findfirst('?', file)
        if qidx !== nothing
            query = file[(qidx + 1):end]
            file = file[1:(qidx - 1)]
            m = match(r"axis=(\d+)", query)
            m !== nothing && (axis = parse(Int, m.captures[1]))
            ms = match(r"slice=(\d+)", query)
            ms !== nothing && (slice_idx = parse(Int, ms.captures[1]))
            mn = match(r"snap=(\d+)", query)
            mn !== nothing && (snap_idx = parse(Int, mn.captures[1]))
        end
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        cache_key = "phase_bin:$(fpath)#snap=$(snap_idx)#axis=$(axis)#slice=$(slice_idx)"
        bin = if haskey(psi_cache, cache_key)
            psi_cache[cache_key]
        else
            while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                _evict_one!(psi_cache)
            end
            v = try
                _compute_phase_slice_binary(
                    _load_psi_cached(fpath, psi_cache, snap_idx)...,
                    axis, slice_idx, fpath,
                )
            catch e
                return (500, "text/plain", "Error: $(e)")
            end
            psi_cache[cache_key] = v
            v
        end
        (200, "application/octet-stream", bin)

    elseif startswith(path, "/api/density3d/")
        rest = _uri_decode(path[16:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/density3d/:run/:file")
        end
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        qidx = findfirst('?', file)
        qidx !== nothing && (file = file[1:(qidx - 1)])
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
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        qidx = findfirst('?', file)
        comp_idx = 0
        snap_idx = nothing
        bsz = false
        if qidx !== nothing
            query = file[(qidx + 1):end]
            file = file[1:(qidx - 1)]
            m = match(r"comp=(-?\d+)", query)
            m !== nothing && (comp_idx = parse(Int, m.captures[1]))
            ms = match(r"snap=(\d+)", query)
            ms !== nothing && (snap_idx = parse(Int, ms.captures[1]))
            occursin("bsz=1", query) && (bsz = true)
        end
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        # Cache density3d_bin output by (file, snap, component). The
        # packed Float32 volume is much smaller than the underlying ψ
        # (524 KB for 64x64x32 vs 13.6 MB), so this is a RAM win + the
        # time-scrubber playback hits cache after the first full pass.
        # bsz variant cached separately to avoid re-encoding on each hit.
        cache_key = "density3d_bin:$(fpath)#snap=$(snap_idx)#comp=$(comp_idx)#bsz=$(bsz)"
        bin = if haskey(psi_cache, cache_key)
            psi_cache[cache_key]
        else
            while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                _evict_one!(psi_cache)
            end
            v = try
                raw = _compute_3d_density_binary(
                    _load_psi_cached(fpath, psi_cache, snap_idx)...; component=comp_idx
                )
                _maybe_bitshuffle_zstd(raw, bsz)
            catch e
                return (500, "text/plain", "Error: $(e)")
            end
            psi_cache[cache_key] = v
            v
        end
        (200, "application/octet-stream", bin)

    elseif startswith(path, "/api/dynamics_series/")
        # /api/dynamics_series/:run/:file → scalar time series for sparkline rendering
        rest = _uri_decode(path[22:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/dynamics_series/:run/:file")
        end
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        qidx = findfirst('?', file)
        qidx !== nothing && (file = file[1:(qidx - 1)])
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        json = try
            d = JLD2.load(fpath)
            out = Dict{String, Any}("has_dynamics" => haskey(d, "dynamics/times"))
            for k in (
                "dynamics/times",
                "dynamics/energies",
                "dynamics/magnetizations",
                "dynamics/norms",
            )
                haskey(d, k) || continue
                out[split(k, "/")[2]] = Float64.(d[k])
            end
            if haskey(d, "dynamics/component_populations")
                # Just return the dominant m's series so sparklines stay compact.
                pops = d["dynamics/component_populations"]
                n_snaps = size(pops, 1)
                n_comp = size(pops, 2)
                out["pop_top"] = [Float64(pops[t, 1]) for t in 1:n_snaps]  # m=+F
                out["pop_mid"] = [Float64(pops[t, (n_comp + 1) ÷ 2]) for t in 1:n_snaps]  # m=0
            end
            _json_string(out)
        catch e
            "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
        end
        (200, "application/json", json)

    elseif startswith(path, "/api/scan_group/")
        # /api/scan_group/<scan_dir_name> → aggregated cross-run summary
        # for all points declared in `runs/<scan_dir>/scan.yaml`. Backed
        # by the per-run `/api/physics_summary` data, but loaded once
        # per scan rather than per point.
        rest = _uri_decode(path[17:end])
        qidx = findfirst('?', rest)
        qidx !== nothing && (rest = rest[1:(qidx - 1)])
        scan_dir = joinpath(base_dir, rest)
        if !isdir(scan_dir)
            return (404, "text/plain", "scan_dir not found: $rest")
        end
        scan_yaml_path = joinpath(scan_dir, "scan.yaml")
        if !isfile(scan_yaml_path)
            return (
                404, "text/plain",
                "scan.yaml not found in $rest — run scripts/scan_retrofit.jl first",
            )
        end
        json = try
            scan = YAML.load_file(scan_yaml_path)
            param = scan["parameter"]
            values = param["values"]
            display_factor = Float64(get(param, "display_factor", 1.0))

            point_pattern = get(scan, "point_dir_pattern",
                "$(scan["name"])_p\${idx}")

            # Resolve point dir per value (mirror scan_expand naming).
            function _point_name(value, idx)
                s = point_pattern
                s = replace(s, "\${idx}" => string(idx))
                val_str = replace(string(value), "." => "_")
                s = replace(s, "\${value}" => val_str)
                s
            end

            runs_data = []
            for (idx, value) in enumerate(values)
                pt_name = _point_name(value, idx)
                pt_dir = joinpath(scan_dir, pt_name)
                # Look for canonical result.jld2 first, then legacy result_legacy.jld2.
                jld_path = isfile(joinpath(pt_dir, "result.jld2")) ?
                           joinpath(pt_dir, "result.jld2") :
                           joinpath(pt_dir, "result_legacy.jld2")
                run_summary = Dict{String, Any}(
                    "value" => value,
                    "value_display" => value * display_factor,
                    "point_dir" => pt_name,
                    "completed" => isfile(jld_path),
                )
                if isfile(jld_path)
                    try
                        d = JLD2.load(jld_path)
                        # Same fields as /api/physics_summary, abbreviated.
                        for sym in ("Lz", "Fz")
                            v = if haskey(d, "dynamics/$sym")
                                Float64.(d["dynamics/$sym"])
                            elseif haskey(d, sym)
                                Float64.(d[sym])
                            else
                                Float64[]
                            end
                            if !isempty(v)
                                run_summary[sym * "_min"] = minimum(v)
                                run_summary[sym * "_max"] = maximum(v)
                                run_summary[sym * "_init"] = v[1]
                                run_summary[sym * "_final"] = v[end]
                            end
                        end
                        pm = if haskey(d, "dynamics/per_m_history")
                            d["dynamics/per_m_history"]
                        elseif haskey(d, "per_m_history")
                            d["per_m_history"]
                        else
                            nothing
                        end
                        if pm !== nothing
                            T = size(pm, 2)
                            col1 = sum(view(pm, :, 1))
                            colT = sum(view(pm, :, T))
                            run_summary["m_top_init"] = pm[1, 1] / max(col1, 1e-30)
                            run_summary["m_top_final"] = pm[1, T] / max(colT, 1e-30)
                        end
                        nv = if haskey(d, "dynamics/norms")
                            Float64.(d["dynamics/norms"])
                        elseif haskey(d, "norms")
                            Float64.(d["norms"])
                        else
                            Float64[]
                        end
                        if !isempty(nv)
                            run_summary["norm_max_dev"] = maximum(abs.(nv .- 1.0))
                        end
                        if haskey(d, "dynamics/integrator_meta/larmor_phase_per_step")
                            run_summary["larmor_phase_per_step"] =
                                d["dynamics/integrator_meta/larmor_phase_per_step"]
                        end
                    catch e
                        run_summary["error"] = string(e)
                    end
                end
                push!(runs_data, run_summary)
            end

            out = Dict{String, Any}(
                "name" => scan["name"],
                "description" => get(scan, "description", ""),
                "parameter" => Dict{String, Any}(
                    "key" => param["key"],
                    "values" => values,
                    "unit" => get(param, "unit", ""),
                    "display_unit" => get(param, "display_unit", ""),
                    "display_factor" => display_factor,
                ),
                "runs" => runs_data,
            )
            _json_string(out)
        catch e
            "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
        end
        (200, "application/json", json)

    elseif startswith(path, "/api/physics_summary/")
        # /api/physics_summary/:run/:file → integrator metadata + Larmor regime
        # classification + Lz/Fz/m=+F summary. Designed so a frontend physics
        # panel can render gauge widgets (Larmor ratio, ε vs threshold,
        # Lz min/max) without re-loading the multi-GB result.jld2 each time.
        rest = _uri_decode(path[22:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/physics_summary/:run/:file")
        end
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        qidx = findfirst('?', file)
        qidx !== nothing && (file = file[1:(qidx - 1)])
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        json = try
            d = JLD2.load(fpath)
            out = Dict{String, Any}()

            # Integrator metadata block (written by `save_rotating_basis_result!`).
            for (k, label) in (
                ("dynamics/integrator_meta/dt_used", "dt_used"),
                ("dynamics/integrator_meta/integrator", "integrator"),
                ("dynamics/integrator_meta/epsilon_target", "epsilon_target"),
                ("dynamics/integrator_meta/p_zeeman", "p_zeeman"),
                ("dynamics/integrator_meta/F_atom", "F_atom"),
                ("dynamics/integrator_meta/larmor_phase_per_step", "larmor_phase_per_step"),
                ("dynamics/integrator_meta/theta_const", "theta_const"),
                ("dynamics/integrator_meta/phi_omega", "phi_omega"),
            )
                haskey(d, k) && (out[label] = d[k])
            end

            # Larmor regime classification — same threshold as the Larmor
            # guard warning in pipeline_runner. Audit 2026-04-28 showed
            # ε=1e-3 fails for `p·F·dt > 300`; ε=1e-6 brings it down to
            # ~90 for the Klaus-equivalent runs. Frontend can colour-code
            # the gauge from this field.
            larmor = get(out, "larmor_phase_per_step", NaN)
            out["larmor_regime"] = if !isfinite(larmor) || larmor == 0
                "unknown"
            elseif larmor < 1
                "safe"
            elseif larmor < 100
                "marginal"
            elseif larmor < 300
                "stiff"
            else
                "danger"
            end

            # Lz / Fz extremes summary. Try the canonical
            # `dynamics/<X>` keys first; fall back to top-level `<X>`
            # for the legacy launch_*.jl Vector output (pre-2026-04-29).
            for sym in ("Lz", "Fz", "Fx", "Fy")
                v = if haskey(d, "dynamics/$sym")
                    Float64.(d["dynamics/$sym"])
                elseif haskey(d, sym)
                    Float64.(d[sym])
                else
                    nothing
                end
                v === nothing || isempty(v) && continue
                if v !== nothing && !isempty(v)
                    out[sym * "_min"] = minimum(v)
                    out[sym * "_max"] = maximum(v)
                    out[sym * "_init"] = v[1]
                    out[sym * "_final"] = v[end]
                end
            end

            # m=+F population at start vs end (canonical thesis observable).
            pm = if haskey(d, "dynamics/per_m_history")
                d["dynamics/per_m_history"]
            elseif haskey(d, "per_m_history")
                d["per_m_history"]
            else
                nothing
            end
            if pm !== nothing
                T = size(pm, 2)
                col1 = sum(view(pm, :, 1))
                colT = sum(view(pm, :, T))
                out["m_top_init"] = pm[1, 1] / max(col1, 1e-30)
                out["m_top_final"] = pm[1, T] / max(colT, 1e-30)
            end

            # Norm conservation diagnostic.
            nv = if haskey(d, "dynamics/norms")
                Float64.(d["dynamics/norms"])
            elseif haskey(d, "norms")
                Float64.(d["norms"])
            else
                nothing
            end
            if nv !== nothing && !isempty(nv)
                out["norm_max_dev"] = maximum(abs.(nv .- 1.0))
            end

            _json_string(out)
        catch e
            "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
        end
        (200, "application/json", json)

    elseif startswith(path, "/api/snapshots/")
        # /api/snapshots/:run/:file → metadata for the time-scrubber UI.
        rest = _uri_decode(path[16:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/snapshots/:run/:file")
        end
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        qidx = findfirst('?', file)
        qidx !== nothing && (file = file[1:(qidx - 1)])
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        meta = _snapshots_metadata(fpath)
        if meta === nothing
            return (200, "application/json", "{\"n_snapshots\":0,\"times\":[]}")
        end
        # Kick off background warming of every per-snap density_bin (axis=3,
        # the default the SlicePanel opens to). The frontend's prefetch
        # only covers the next 1-2 frames; this turns the rest of the run
        # into a cache hit by the time the user scrubs to it. axis=1/2 are
        # warmed lazily via the existing per-request path.
        n_snaps = get(meta, "n_snapshots", 0)
        if n_snaps isa Integer && n_snaps > 0
            # Prefer the user's most-likely first axis (z-integration)
            # but warm 1 and 2 right behind it so the axis selector is
            # also instant. The warmer yields between frames so the
            # subsequent axes don't starve the active scrub.
            for ax in (3, 1, 2)
                inflight_key = "warm_density_bin:$(fpath)#axis=$(ax)"
                inflight_key in _PREPACK_INFLIGHT && continue
                push!(_PREPACK_INFLIGHT, inflight_key)
                @async _warm_density_bin_all(fpath, Int(n_snaps), ax, psi_cache, base_dir)
            end
        end
        (200, "application/json", _json_string(meta))

    elseif startswith(path, "/api/density3d_atlas/")
        # /api/density3d_atlas/:run/:file?comp=N → all-snaps 3D density
        # atlas for one component. Same panel-major idea as the 2D atlas
        # but for the 3D viewer: 1 fetch instead of one per scrub frame.
        # Layout (panel-major over snap, single component):
        #   "D3AT" magic (4)
        #   Int32 header (6): n_snaps, nx, ny, nz, n_comp_total, component
        #   Float32 atlas  (n_snaps * nx * ny * nz)
        rest = _uri_decode(path[22:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/density3d_atlas/:run/:file")
        end
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        comp_idx = 0
        bsz = false
        qidx = findfirst('?', file)
        if qidx !== nothing
            query = file[(qidx + 1):end]
            file = file[1:(qidx - 1)]
            m = match(r"comp=(-?\d+)", query)
            m !== nothing && (comp_idx = parse(Int, m.captures[1]))
            occursin("bsz=1", query) && (bsz = true)
        end
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        cache_key = "density3d_atlas:$(fpath)#comp=$(comp_idx)#bsz=$(bsz)"
        bin = if haskey(psi_cache, cache_key)
            psi_cache[cache_key]
        else
            disk_blob = _try_load_atlas_from_disk(base_dir, fpath, 1000 + comp_idx, bsz)
            if disk_blob !== nothing
                while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                    _evict_one!(psi_cache)
                end
                psi_cache[cache_key] = disk_blob
                disk_blob
            else
                while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                    _evict_one!(psi_cache)
                end
                v = try
                    meta = _snapshots_metadata(fpath)
                    n_snaps = meta === nothing ? 0 : Int(get(meta, "n_snapshots", 0))
                    n_snaps == 0 && return (404, "text/plain", "No snapshots")
                    raw = _compute_density3d_atlas_binary(fpath, comp_idx, n_snaps, psi_cache)
                    _maybe_bitshuffle_zstd(raw, bsz)
                catch e
                    return (500, "text/plain", "Error: $(e)")
                end
                psi_cache[cache_key] = v
                _save_atlas_to_disk(base_dir, fpath, 1000 + comp_idx, bsz, v)
                v
            end
        end
        (200, "application/octet-stream", bin)

    elseif startswith(path, "/api/density_atlas/")
        # /api/density_atlas/:run/:file?axis=N → all-snaps atlas in one
        # binary blob (panel-major: total then n_comp components, each
        # n_snaps × nx × ny). Replaces ~157 separate /api/density_bin
        # round-trips with a single fetch.
        rest = _uri_decode(path[20:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/density_atlas/:run/:file")
        end
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        axis = 3
        bsz = false
        qidx = findfirst('?', file)
        if qidx !== nothing
            query = file[(qidx + 1):end]
            file = file[1:(qidx - 1)]
            m = match(r"axis=(\d+)", query)
            m !== nothing && (axis = parse(Int, m.captures[1]))
            occursin("bsz=1", query) && (bsz = true)
        end
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        cache_key = "density_atlas:$(fpath)#axis=$(axis)#bsz=$(bsz)"
        bin = if haskey(psi_cache, cache_key)
            psi_cache[cache_key]
        else
            # Disk-cache fallback: a previous dashboard run may have
            # already written this atlas to runs/_dashboard_cache/.
            disk_blob = _try_load_atlas_from_disk(base_dir, fpath, axis, bsz)
            if disk_blob !== nothing
                while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                    _evict_one!(psi_cache)
                end
                psi_cache[cache_key] = disk_blob
                disk_blob
            else
                while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                    _evict_one!(psi_cache)
                end
                v = try
                    meta = _snapshots_metadata(fpath)
                    n_snaps = meta === nothing ? 0 : Int(get(meta, "n_snapshots", 0))
                    if n_snaps == 0
                        return (404, "text/plain", "No snapshots in $name/$file")
                    end
                    raw = _compute_column_density_atlas_binary(fpath, axis, n_snaps, psi_cache)
                    _maybe_bitshuffle_zstd(raw, bsz)
                catch e
                    return (500, "text/plain", "Error: $(e)")
                end
                psi_cache[cache_key] = v
                # Also write through to disk so the next session is instant.
                _save_atlas_to_disk(base_dir, fpath, axis, bsz, v)
                v
            end
        end
        (200, "application/octet-stream", bin)

    elseif startswith(path, "/api/synthetic_dispersion/")
        # /api/synthetic_dispersion/:run/:file?axis=N&snap=K → packed
        # Float32 (k_real × k_synth) dispersion image. Drives the new
        # SlicePanel "dispersion" mode — same protocol shape as
        # density_bin so the same DataTexture upload path can render it.
        rest = _uri_decode(path[27:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/synthetic_dispersion/:run/:file")
        end
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        axis = 1
        snap_idx = nothing
        qidx = findfirst('?', file)
        if qidx !== nothing
            query = file[(qidx + 1):end]
            file = file[1:(qidx - 1)]
            m = match(r"axis=(\d+)", query)
            m !== nothing && (axis = parse(Int, m.captures[1]))
            ms = match(r"snap=(\d+)", query)
            ms !== nothing && (snap_idx = parse(Int, ms.captures[1]))
        end
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        cache_key = "synth_disp:$(fpath)#snap=$(snap_idx)#axis=$(axis)"
        bin = if haskey(psi_cache, cache_key)
            psi_cache[cache_key]
        else
            while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                _evict_one!(psi_cache)
            end
            v = try
                tup = _load_psi_cached(fpath, psi_cache, snap_idx)
                psi = tup[1]
                # Re-derive a Grid from the JLD2 box_size so the
                # synthetic_dim_dispersion call (which queries
                # grid.config.box_size) has what it needs.
                box = _load_box_size(fpath)
                ndim = ndims(psi) - 1
                n_pts = ntuple(i -> size(psi, i), ndim)
                box_n = ntuple(i -> Float64(box[i]), ndim)
                grid = make_grid(GridConfig(n_pts, box_n))
                d = synthetic_dim_dispersion(psi, grid; axis=axis)
                spectrum_f32 = Float32.(d.spectrum)
                n_axis = size(spectrum_f32, 1)
                D = size(spectrum_f32, 2)
                buf = IOBuffer(; sizehint=40 + n_axis * D * 4)
                # density_bin header reused: ndim=2, axis=axis,
                # nx=n_axis, ny=D, n_comp=0 (no per-component split,
                # the whole image lives in the total slot), F=0.
                write(buf, Int32(2), Int32(axis), Int32(n_axis), Int32(D), Int32(0), Int32(0))
                # axis_ranges in radians-of-k (label-only on the client)
                write(buf, Float32[-π, π, -π, π])
                # m_values empty (n_comp=0) so the frontend parser skips
                # straight to total_density.
                # total_density slot carries the spectrum.
                write(buf, vec(spectrum_f32))
                take!(buf)
            catch e
                return (500, "text/plain", "Error: $(e)")
            end
            psi_cache[cache_key] = v
            v
        end
        (200, "application/octet-stream", bin)

    elseif startswith(path, "/api/density_max/")
        # /api/density_max/:run/:file → {"density_max_total": float}
        # Lazy version of the field that used to live in /api/snapshots.
        # The 16-frame walk takes ~0.8 s on Klaus and stalled the
        # initial run-open hop; computing it on demand keeps that hop
        # instant. Cached server-side so repeat calls are sub-ms.
        rest = _uri_decode(path[18:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/density_max/:run/:file")
        end
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        qidx = findfirst('?', file)
        qidx !== nothing && (file = file[1:(qidx - 1)])
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        cache_key = "density_max:$(fpath)"
        d_max = if haskey(psi_cache, cache_key)
            psi_cache[cache_key]
        else
            v = try
                jldopen(fpath, "r") do f
                    if haskey(f, "dynamics/psi_snapshots_streamed/n_snapshots")
                        n = Int(f["dynamics/psi_snapshots_streamed/n_snapshots"])
                        n == 0 ? 1.0 : _global_density_max_total_sampled(f, n; n_samples=16)
                    elseif haskey(f, "dynamics/psi_snapshots")
                        # Legacy 5D layout — sample frames directly
                        snaps = f["dynamics/psi_snapshots"]
                        nframes = size(snaps, ndims(snaps))
                        nframes == 0 && return 1.0
                        # Sample up to 16 frames; for legacy 5D the array IS in
                        # memory, so just compute peak per frame quickly.
                        sample_idxs = if nframes ≤ 16
                            (1:nframes)
                        else
                            Int.(round.(range(1, nframes; length=16)))
                        end
                        gmax = 0.0
                        spatial_dims = ndims(snaps) - 2  # (Nx,Ny,Nz, D, n)
                        for k in sample_idxs
                            idx = ntuple(d -> d == ndims(snaps) ? k : Colon(),
                                ndims(snaps))
                            ψk = view(snaps, idx...)
                            # |ψ|² summed across components (last axis of slice)
                            local_max = 0.0
                            for I in CartesianIndices(ntuple(d -> size(ψk, d),
                                spatial_dims))
                                rho = 0.0
                                for c in 1:size(ψk, ndims(ψk))
                                    rho += abs2(ψk[I, c])
                                end
                                rho > local_max && (local_max = rho)
                            end
                            local_max > gmax && (gmax = local_max)
                        end
                        gmax > 0 ? gmax : 1.0
                    elseif haskey(f, "psi_snapshots")
                        # Top-level Vector{Array{Complex,4}} layout (saved by
                        # legacy launch_*.jl direct jldsave). Each element is
                        # an N+1-D array (spatial..., D); sample up to 16.
                        snaps = f["psi_snapshots"]
                        nframes = length(snaps)
                        nframes == 0 && return 1.0
                        sample_idxs = if nframes ≤ 16
                            (1:nframes)
                        else
                            Int.(round.(range(1, nframes; length=16)))
                        end
                        gmax = 0.0
                        for k in sample_idxs
                            ψk = snaps[k]
                            local_max = 0.0
                            spatial_dims = ndims(ψk) - 1
                            for I in CartesianIndices(ntuple(d -> size(ψk, d),
                                spatial_dims))
                                rho = 0.0
                                for c in 1:size(ψk, ndims(ψk))
                                    rho += abs2(ψk[I, c])
                                end
                                rho > local_max && (local_max = rho)
                            end
                            local_max > gmax && (gmax = local_max)
                        end
                        gmax > 0 ? gmax : 1.0
                    elseif haskey(f, "psi")
                        # Static-psi file (e.g. ground-state-only run, or a
                        # `_run_yaml_single` point_NNN.jld2 that only stores
                        # the final ψ). Compute the spin-summed peak density
                        # directly so the volume renderer can normalise.
                        psi = f["psi"]
                        spatial_dims = ndims(psi) - 1
                        D = size(psi, ndims(psi))
                        gmax = 0.0
                        for I in CartesianIndices(ntuple(d -> size(psi, d), spatial_dims))
                            rho = 0.0
                            for c in 1:D
                                rho += abs2(psi[I, c])
                            end
                            rho > gmax && (gmax = rho)
                        end
                        gmax > 0 ? gmax : 1.0
                    else
                        1.0
                    end
                end
            catch
                1.0
            end
            while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                _evict_one!(psi_cache)
            end
            psi_cache[cache_key] = v
            v
        end
        (200, "application/json", "{\"density_max_total\":$(d_max)}")

    elseif startswith(path, "/api/vortex_lines/")
        # /api/vortex_lines/:run/:file?snap=K&mask=FRAC  → per-m polylines
        rest = _uri_decode(path[19:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/vortex_lines/:run/:file?snap=K&mask=FRAC")
        end
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        snap_idx = nothing
        mask_frac = 0.0
        qidx = findfirst('?', file)
        if qidx !== nothing
            query = file[(qidx + 1):end]
            file = file[1:(qidx - 1)]
            ms = match(r"snap=(\d+)", query)
            ms !== nothing && (snap_idx = parse(Int, ms.captures[1]))
            mm = match(r"mask=([0-9.]+)", query)
            mm !== nothing && (mask_frac = parse(Float64, mm.captures[1]))
        end
        fpath = joinpath(base_dir, name, file)
        if !isfile(fpath)
            return (404, "text/plain", "File not found: $name/$file")
        end
        # Cache key: (file, snap, mask). Identical scrub-replay returns
        # instantly from cache instead of re-running the per-plaquette
        # phase-winding scan + greedy z-stitch (sub-second per call but
        # the scrubber fires many in rapid succession).
        cache_key = "vortex_lines:$(fpath)#snap=$(snap_idx)#mask=$(mask_frac)"
        json = if haskey(psi_cache, cache_key)
            psi_cache[cache_key]
        else
            # Reuse the same FIFO cap as ψ snapshots to keep RAM bounded.
            while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                _evict_one!(psi_cache)
            end
            json_str = try
                psi, n_comp, ndim, n_pts, F = _load_psi_cached(fpath, psi_cache, snap_idx)
                ndim == 3 || throw(ArgumentError("vortex_lines requires 3D data"))
                box_size = _load_box_size(fpath)
                g = make_grid(GridConfig(n_pts, box_size))
                lines = extract_vortex_lines_per_m(psi, g; min_density_frac=mask_frac)
                # Flatten into a frontend-friendly list [{m, charge, points}, ...]
                out_lines = Dict{String, Any}[]
                for (m_label, polylines) in lines
                    for ln in polylines
                        push!(
                            out_lines,
                            Dict{String, Any}(
                                "m" => m_label,
                                "charge" => ln.charge,
                                "points" => [[p[1], p[2], p[3]] for p in ln.points],
                            ),
                        )
                    end
                end
                _json_string(
                    Dict{String, Any}(
                        "lines" => out_lines,
                        "box" => collect(Float64.(box_size)),
                        "n_lines" => length(out_lines),
                    ),
                )
            catch e
                "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
            end
            psi_cache[cache_key] = json_str
            json_str
        end
        (200, "application/json", json)

    elseif startswith(path, "/api/vorticity3d_bin/")
        # /api/vorticity3d_bin/:run/:file?snap=K
        rest = _uri_decode(path[22:end])
        slash_idx = findfirst('/', rest)
        if slash_idx === nothing
            return (400, "text/plain", "Expected /api/vorticity3d_bin/:run/:file?snap=K")
        end
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        qidx = findfirst('?', file)
        snap_idx = nothing
        if qidx !== nothing
            query = file[(qidx + 1):end]
            file = file[1:(qidx - 1)]
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
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        qidx = findfirst('?', file)
        comp_idx = 1
        snap_idx = nothing
        if qidx !== nothing
            query = file[(qidx + 1):end]
            file = file[1:(qidx - 1)]
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
            _compute_3d_phase_binary(
                _load_psi_cached(fpath, psi_cache, snap_idx)...; component=comp_idx
            )
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
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        axis = 3
        qidx = findfirst('?', file)
        if qidx !== nothing
            query = file[(qidx + 1):end]
            file = file[1:(qidx - 1)]
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
            return (
                400, "text/plain", "Expected /api/density3d_rotated/:run/:file?angle=DEG&comp=N"
            )
        end
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        angle_deg = 0.0;
        comp_idx = 0
        qidx = findfirst('?', file)
        if qidx !== nothing
            query = file[(qidx + 1):end]
            file = file[1:(qidx - 1)]
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
            return (
                400,
                "text/plain",
                "Expected /api/vector3d_bin/:run/:file?field=current&stride=2&snap=K",
            )
        end
        name = rest[1:(slash_idx - 1)]
        file = rest[(slash_idx + 1):end]
        vec_field = :current
        vec_stride = 2
        snap_idx = nothing
        qidx = findfirst('?', file)
        if qidx !== nothing
            query = file[(qidx + 1):end]
            file = file[1:(qidx - 1)]
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
                field=vec_field, stride=vec_stride)
        catch e
            return (500, "text/plain", "Error: $(e)")
        end
        (200, "application/octet-stream", bin)

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

