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
            readdir(run_dir))
    )
    isempty(jld2_files) && throw(ArgumentError("No point_*.jld2 files in $run_dir"))

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
_write_json(io::IO, n::Real) = if isnan(n)
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

See src/workflow/io/dashboard.jl for the full /api surface that the
React app consumes.
"""
function serve_dashboard(port::Int=8080; base_dir::String="runs")
    if !isfile(_WEB_DIST_INDEX)
        throw(
            ArgumentError(
                "React dashboard not built. Run: cd web && bun install && bun run build"
            )
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
                    n = if haskey(f, "dynamics/psi_snapshots_streamed/n_snapshots")
                        Int(f["dynamics/psi_snapshots_streamed/n_snapshots"])
                    else
                        0
                    end
                    n == 0 ? 1.0 : _global_density_max_total_sampled(f, n; n_samples=16)
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
        empty!(data_cache)
        empty!(psi_cache)
        empty!(_vector3d_plans_cache)
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

const _GZIP_THRESHOLD_BYTES = 100_000

# --- bitshuffle + zstd payload codec ---
# For slowly-varying physical fields (e.g. BEC density profiles) the
# Float32 bit pattern's upper bytes are nearly constant, so byte-shuffle
# preprocessing dramatically improves zstd's compression ratio (~3×
# vs ~1.05× on raw float32). Per the research note in
# docs/dashboard_2d_optimization_research.md and Aras Pranckevičius's
# Float Compression series.

"""Reorder the bytes of `data` so that the i-th byte of every esize-byte
element is contiguous: byte0_of_elem1, byte0_of_elem2, …, byte1_of_elem1,
byte1_of_elem2, …. esize is typically 4 (Float32). Length must divide
evenly by esize."""
function _bitshuffle(data::AbstractVector{UInt8}, esize::Int)
    n = length(data)
    @assert n % esize == 0 "bitshuffle length $n must be a multiple of element size $esize"
    n_elem = n ÷ esize
    out = Vector{UInt8}(undef, n)
    @inbounds for b in 0:(esize - 1)
        for i in 0:(n_elem - 1)
            out[b * n_elem + i + 1] = data[i * esize + b + 1]
        end
    end
    out
end

"""Pack `payload_bytes` as bitshuffle + zstd-3 with a magic + size header
so the client can reverse it. Layout:

    "BSZ1" (4 bytes)
    original_size as Int32 (4 bytes)
    esize as Int32 (4 bytes)
    zstd_compressed_bitshuffled_bytes (the rest)

Returns the packed Vector{UInt8}."""
function _pack_bitshuffle_zstd(payload_bytes::Vector{UInt8}; esize::Int=4, level::Int=3)
    shuffled = _bitshuffle(payload_bytes, esize)
    compressed = transcode(ZstdCompressor(; level=level), shuffled)
    out = IOBuffer(; sizehint=12 + length(compressed))
    write(out, b"BSZ1")
    write(out, Int32(length(payload_bytes)))
    write(out, Int32(esize))
    write(out, compressed)
    take!(out)
end

"""Wrap a 3D binary endpoint result with bitshuffle+zstd when requested.
Skips re-encoding (pass-through) when `bsz=false` so HTTP clients without
the codec stay on the raw path."""
function _maybe_bitshuffle_zstd(payload::Vector{UInt8}, bsz::Bool)
    bsz || return payload
    _pack_bitshuffle_zstd(payload; esize=4, level=3)
end

# --- Minimal WebSocket implementation (RFC 6455 subset) ---
# Supports binary push from server + JSON text requests from client.
# No fragmentation, no permessage-deflate (raw float doesn't compress
# meaningfully and the codec adds latency the scrubber can't afford).
const _WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

function _ws_handshake(sock, ws_key::AbstractString)
    accept = base64encode(sha1(string(ws_key, _WS_GUID)))
    write(sock,
        "HTTP/1.1 101 Switching Protocols\r\n" *
        "Upgrade: websocket\r\n" *
        "Connection: Upgrade\r\n" *
        "Sec-WebSocket-Accept: $accept\r\n" *
        "\r\n")
end

# Read exactly n bytes (or throw EOFError).
function _ws_read_exact(sock, n::Int)
    n == 0 && return UInt8[]
    buf = read(sock, n)
    length(buf) == n || throw(EOFError())
    buf
end

# Read one frame from client. Returns (opcode::UInt8, payload::Vector{UInt8})
# or (0xFF, UInt8[]) on close.
function _ws_read_frame(sock)
    hdr = _ws_read_exact(sock, 2)
    fin = (hdr[1] & 0x80) != 0
    opcode = hdr[1] & 0x0F
    masked = (hdr[2] & 0x80) != 0
    len = Int(hdr[2] & 0x7F)
    if len == 126
        ext = _ws_read_exact(sock, 2)
        len = (Int(ext[1]) << 8) | Int(ext[2])
    elseif len == 127
        ext = _ws_read_exact(sock, 8)
        len = 0
        for b in ext
            len = (len << 8) | Int(b)
        end
    end
    mask = masked ? _ws_read_exact(sock, 4) : UInt8[]
    payload = _ws_read_exact(sock, len)
    if masked
        @inbounds for i in 1:len
            payload[i] ⊻= mask[((i - 1) & 3) + 1]
        end
    end
    fin || @warn "WebSocket fragmentation not supported, dropping frame"
    (opcode, payload)
end

# Send one unfragmented frame (server → client, no mask). Header and
# payload are concatenated into a single buffer and sent in one
# `write(sock, …)` so the second packet doesn't get delayed by Nagle's
# algorithm waiting on the first packet's ACK (~40 ms penalty per frame
# observed when the two were sent separately).
function _ws_send_frame(sock, opcode::UInt8, payload::AbstractVector{UInt8})
    n = length(payload)
    hdr_len = n < 126 ? 2 : (n <= 0xFFFF ? 4 : 10)
    buf = Vector{UInt8}(undef, hdr_len + n)
    buf[1] = 0x80 | opcode
    if n < 126
        buf[2] = UInt8(n)
    elseif n <= 0xFFFF
        buf[2] = UInt8(126)
        buf[3] = UInt8((n >> 8) & 0xFF)
        buf[4] = UInt8(n & 0xFF)
    else
        buf[2] = UInt8(127)
        @inbounds for (i, shift) in enumerate((56, 48, 40, 32, 24, 16, 8, 0))
            buf[2 + i] = UInt8((n >> shift) & 0xFF)
        end
    end
    n > 0 && copyto!(buf, hdr_len + 1, payload, 1, n)
    write(sock, buf)
end

_ws_send_binary(sock, payload) = _ws_send_frame(sock, UInt8(0x02), payload)
_ws_send_text(sock, s::AbstractString) = _ws_send_frame(sock, UInt8(0x01), Vector{UInt8}(s))
_ws_send_pong(sock, payload) = _ws_send_frame(sock, UInt8(0x0A), payload)
_ws_send_close(sock) = _ws_send_frame(sock, UInt8(0x08), UInt8[])

# Parse a JSON-ish "{"key":val,...}" payload into a Dict{String,Any}.
# Tiny parser tailored to the scrub-channel protocol (key:value, no
# nesting). Falls back to JSON.parse via the project dep if available.
function _ws_parse_request(payload::Vector{UInt8})
    s = String(payload)
    try
        return JSON.parse(s)
    catch
        return Dict{String, Any}()
    end
end

# Build the same density_bin / phase_bin payload an HTTP request would
# return. Returns Vector{UInt8} or nothing on error.
function _ws_build_payload(req::Dict, psi_cache::Dict{String, Any}, base_dir::String)
    kind = String(get(req, "kind", "density"))
    run = String(get(req, "run", ""))
    file = String(get(req, "file", ""))
    axis = Int(get(req, "axis", 3))
    snap = haskey(req, "snap") && req["snap"] !== nothing ? Int(req["snap"]) : nothing
    fpath = joinpath(base_dir, run, file)
    isfile(fpath) || return nothing
    if kind == "density"
        cache_key = "density_bin:$(fpath)#snap=$(snap)#axis=$(axis)"
        return get(psi_cache, cache_key) do
            while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                _evict_one!(psi_cache)
            end
            v = _compute_column_density_binary(
                _load_psi_cached(fpath, psi_cache, snap)..., axis, fpath
            )
            psi_cache[cache_key] = v
            v
        end
    elseif kind == "phase"
        slice = haskey(req, "slice") && req["slice"] !== nothing ? Int(req["slice"]) : nothing
        cache_key = "phase_bin:$(fpath)#snap=$(snap)#axis=$(axis)#slice=$(slice)"
        return get(psi_cache, cache_key) do
            while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                _evict_one!(psi_cache)
            end
            v = _compute_phase_slice_binary(
                _load_psi_cached(fpath, psi_cache, snap)...,
                axis, slice, fpath,
            )
            psi_cache[cache_key] = v
            v
        end
    end
    nothing
end

"""Run the WebSocket request loop on `sock`. Currently only `/ws/scrub`
is recognised; the protocol is plain JSON requests in, density_bin /
phase_bin binary blobs out. The `req_id` field is echoed in the first 8
bytes of each binary response so the client can match replies to their
issuing request even out-of-order."""
function _websocket_serve(sock, path::AbstractString, ws_key::AbstractString,
    psi_cache::Dict{String, Any}, base_dir::String)
    try
        # Disable Nagle so each frame goes out immediately. WebSocket
        # frames are intentionally small + interactive — the OS coalescing
        # them costs ~40 ms per frame for no benefit.
        try
            Sockets.nagle(sock, false);
        catch
            ;
        end
        _ws_handshake(sock, ws_key)
    catch
        return nothing
    end
    if path != "/ws/scrub"
        try
            _ws_send_close(sock);
        catch
            ;
        end
        return nothing
    end
    try
        while true
            opcode, payload = _ws_read_frame(sock)
            if opcode == 0x08  # close
                try
                    _ws_send_close(sock);
                catch
                    ;
                end
                return nothing
            elseif opcode == 0x09  # ping
                _ws_send_pong(sock, payload)
                continue
            elseif opcode == 0x0A  # pong
                continue
            elseif opcode == 0x01  # text request
                req = _ws_parse_request(payload)
                req_id = UInt32(get(req, "req_id", 0))
                bin = _ws_build_payload(req, psi_cache, base_dir)
                if bin === nothing
                    err = "{\"req_id\":$(req_id),\"error\":\"not found\"}"
                    _ws_send_text(sock, err)
                else
                    # Prefix 8 bytes: u32 req_id, u32 reserved.
                    out = Vector{UInt8}(undef, 8 + length(bin))
                    out[1] = UInt8(req_id & 0xFF)
                    out[2] = UInt8((req_id >> 8) & 0xFF)
                    out[3] = UInt8((req_id >> 16) & 0xFF)
                    out[4] = UInt8((req_id >> 24) & 0xFF)
                    out[5] = 0;
                    out[6] = 0;
                    out[7] = 0;
                    out[8] = 0
                    @inbounds copyto!(out, 9, bin, 1, length(bin))
                    _ws_send_binary(sock, out)
                end
            end
        end
    catch e
        e isa EOFError || @warn "WebSocket loop error: $e"
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
function _trilinear_upsample(data::Array{Float64, 3}, target_n::Int)
    nx, ny, nz = size(data)
    out = Array{Float64, 3}(undef, target_n, target_n, target_n)
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
                c000 = data[x0, y0, z0];
                c100 = data[x1, y0, z0]
                c010 = data[x0, y1, z0];
                c110 = data[x1, y1, z0]
                c001 = data[x0, y0, z1];
                c101 = data[x1, y0, z1]
                c011 = data[x0, y1, z1];
                c111 = data[x1, y1, z1]
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
function _compute_3d_densities(jld2_path::String; target_n::Int=0, max_components::Int=0)
    d = JLD2.load(jld2_path)
    psi = d["psi"]
    n_comp = size(psi, ndims(psi))
    ndim = ndims(psi) - 1
    F = div(n_comp - 1, 2)
    m_values = [F - (c - 1) for c in 1:n_comp]
    n_pts = ntuple(i -> size(psi, i), ndim)

    ndim == 3 || throw(ArgumentError("3D density requires 3D data, got $(ndim)D"))

    all_densities = [
        Float64.(abs2.(view(psi, _component_slice(ndim, n_pts, c)...))) for c in 1:n_comp
    ]
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

    components = Dict{String, Any}[]
    for ci in top_idx
        dens = need_interp ? _trilinear_upsample(all_densities[ci], out_n) : all_densities[ci]
        push!(
            components,
            Dict{String, Any}(
                "m" => m_values[ci],
                "population" => pops[ci] / max(total_pop, 1e-300),
                "density" => vec(dens),
            ),
        )
    end

    out_shape = need_interp ? (out_n, out_n, out_n) : n_pts

    Dict{String, Any}(
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
function _compute_column_densities(jld2_path::String, axis::Int=3)
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
        return Dict{String, Any}(
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

    axis_names = ["x", "y", "z"]
    ax_labels = [axis_names[i] for i in remaining]
    ax_ranges = if box !== nothing && length(box) >= ndim
        [[-box[i]/2, box[i]/2] for i in remaining]
    else
        [[0, n_pts[i]-1] for i in remaining]
    end

    Dict{String, Any}(
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
function _compute_column_densities_from_cache(
    psi, n_comp, ndim, n_pts, F, axis::Int, jld2_path::String
)
    m_values = [F - (c - 1) for c in 1:n_comp]
    box = _read_box_size(jld2_path)

    if ndim == 1
        densities = [Float64[abs2(psi[i, c]) for i in 1:n_pts[1]] for c in 1:n_comp]
        x_range = box !== nothing ? [-box[1]/2, box[1]/2] : [0, n_pts[1]-1]
        return Dict{String, Any}(
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

    axis_names = ["x", "y", "z"]
    ax_labels = [axis_names[i] for i in remaining]
    ax_ranges = if box !== nothing && length(box) >= ndim
        [[-box[i]/2, box[i]/2] for i in remaining]
    else
        [[0, n_pts[i]-1] for i in remaining]
    end

    Dict{String, Any}(
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
    axis::Int, slice_idx::Union{Nothing, Int},
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

    axis_names = ["x", "y", "z"]
    ax_labels = [axis_names[i] for i in remaining]
    ax_ranges = if box !== nothing && length(box) >= ndim
        [[-box[i]/2, box[i]/2] for i in remaining]
    else
        [[0, n_pts[i]-1] for i in remaining]
    end

    Dict{String, Any}(
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

"""
Column density (axis-integrated) packed as Float32. Layout matches the
JSON endpoint field-for-field, just binary:

    Int32 header (6):  ndim, axis, nx, ny, n_comp, F
    Float32 axis_ranges (4):  x_min, x_max, y_min, y_max
    Int32 m_values (n_comp)
    Float32 total_density (nx*ny)
    Float32 densities (n_comp * nx * ny)   -- per-component, in m=+F → -F order

Total size for 64×64 × 13 components: 24 + 16 + 52 + 16384 + 213 KB ≈ 230 KB,
vs ~1.6 MB for the equivalent JSON.
"""
function _compute_column_density_binary(
    psi, n_comp, ndim, n_pts, F, axis::Int, jld2_path::String
)
    ndim >= 2 || throw(ArgumentError("Column density binary requires 2D or 3D data"))
    axis = clamp(axis, 1, ndim)
    box = _read_box_size(jld2_path)

    remaining = [i for i in 1:ndim if i != axis]
    out_shape = ntuple(i -> n_pts[remaining[i]], length(remaining))
    nx = out_shape[1]
    ny = length(out_shape) >= 2 ? out_shape[2] : 1
    plane_n = nx * ny

    densities = Vector{Float32}(undef, n_comp * plane_n)
    total = zeros(Float32, plane_n)
    @inbounds for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        comp = abs2.(view(psi, idx...))
        col = vec(dropdims(sum(comp; dims=axis); dims=axis))
        off = (c - 1) * plane_n
        for i in 1:plane_n
            v = Float32(col[i])
            densities[off + i] = v
            total[i] += v
        end
    end

    ax_ranges = if box !== nothing && length(box) >= ndim
        Float32[-box[remaining[1]] / 2, box[remaining[1]] / 2,
            length(remaining) >= 2 ? -box[remaining[2]]/2 : 0.0f0,
            length(remaining) >= 2 ? box[remaining[2]]/2 : 0.0f0]
    else
        Float32[0, nx - 1, 0, ny - 1]
    end
    m_values = Int32[F - (c - 1) for c in 1:n_comp]

    buf = IOBuffer(; sizehint=24 + 16 + n_comp*4 + plane_n*4 + n_comp*plane_n*4)
    write(buf, Int32(ndim), Int32(axis), Int32(nx), Int32(ny),
        Int32(n_comp), Int32(F))
    write(buf, ax_ranges)
    write(buf, m_values)
    write(buf, total)
    write(buf, densities)
    take!(buf)
end

"""
Bulk column-density atlas: every snap of a run packed into one panel-major
binary so the dashboard can fetch the whole scrub timeline in a single
HTTP request. Layout:

    Char header (4):  "DATL"
    Int32 header (7): n_snaps, ndim, axis, nx, ny, n_comp, F
    Float32 axis_ranges (4):  x_min, x_max, y_min, y_max
    Int32 m_values (n_comp)
    Float32 total_atlas:        n_snaps × nx × ny  (Total channel)
    Float32 component_atlases:  n_comp × n_snaps × nx × ny  (per-m channels)

The panel-major layout means the frontend can take per-channel
Float32Array views directly off the response ArrayBuffer — no
deinterleaving, no per-frame parsing.

Reuses the per-frame `density_bin` cache: if the prepack warmer has
already populated frames, the atlas just shuffles bytes; otherwise it
computes the missing frames in passing and back-fills the cache so a
subsequent per-frame request still hits.
"""
function _compute_column_density_atlas_binary(
    fpath::String, axis::Int, n_snaps::Int, psi_cache::Dict{String, Any}
)
    n_snaps > 0 || throw(ArgumentError("n_snaps must be positive"))
    # Load snap=1 to learn the shape; subsequent snaps reuse the same
    # geometry (the simulator never resizes the grid mid-dynamics).
    first_tup = _load_psi_cached(fpath, psi_cache, 1)
    psi1, n_comp, ndim, n_pts, F = first_tup
    ndim >= 2 || throw(ArgumentError("Atlas requires 2D or 3D data"))
    axis_clamped = clamp(axis, 1, ndim)

    # Geometry & axis ranges, derived from snap=1 with the same logic as
    # _compute_column_density_binary.
    box = _read_box_size(fpath)
    remaining = [i for i in 1:ndim if i != axis_clamped]
    nx = n_pts[remaining[1]]
    ny = length(remaining) >= 2 ? n_pts[remaining[2]] : 1
    plane_n = nx * ny
    plane_bytes = plane_n * 4
    ax_ranges = if box !== nothing && length(box) >= ndim
        Float32[-box[remaining[1]] / 2, box[remaining[1]] / 2,
            length(remaining) >= 2 ? -box[remaining[2]]/2 : 0.0f0,
            length(remaining) >= 2 ? box[remaining[2]]/2 : 0.0f0]
    else
        Float32[0, nx - 1, 0, ny - 1]
    end
    m_values = Int32[F - (c - 1) for c in 1:n_comp]

    # Pre-allocate panel-major output buffer.
    header_size = 4 + 28 + 16 + n_comp * 4
    panel_atlas_bytes = n_snaps * plane_bytes
    total_size = header_size + (1 + n_comp) * panel_atlas_bytes
    out = Vector{UInt8}(undef, total_size)

    # Write header.
    out[1] = UInt8('D');
    out[2] = UInt8('A');
    out[3] = UInt8('T');
    out[4] = UInt8('L')
    hdr_int = reinterpret(Int32, view(out, 5:32))
    hdr_int[1] = Int32(n_snaps)
    hdr_int[2] = Int32(ndim)
    hdr_int[3] = Int32(axis_clamped)
    hdr_int[4] = Int32(nx)
    hdr_int[5] = Int32(ny)
    hdr_int[6] = Int32(n_comp)
    hdr_int[7] = Int32(F)
    rng_off = 33
    rng_view = reinterpret(Float32, view(out, rng_off:(rng_off + 15)))
    @inbounds for i in 1:4
        rng_view[i] = ax_ranges[i]
    end
    mv_off = rng_off + 16
    mv_view = reinterpret(Int32, view(out, mv_off:(mv_off + n_comp * 4 - 1)))
    @inbounds for i in 1:n_comp
        mv_view[i] = m_values[i]
    end

    # Per-snap data: pull each frame from the cache (or compute + cache it),
    # then route bytes into the panel-major output regions.
    total_atlas_off = header_size + 1
    frame_header_bytes = 24 + 16 + n_comp * 4  # matches per-frame binary layout
    @inbounds for snap in 1:n_snaps
        cache_key = "density_bin:$(fpath)#snap=$(snap)#axis=$(axis_clamped)"
        per_frame = if haskey(psi_cache, cache_key)
            psi_cache[cache_key]::Vector{UInt8}
        else
            while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                _evict_one!(psi_cache)
            end
            v = _compute_column_density_binary(
                _load_psi_cached(fpath, psi_cache, snap)..., axis_clamped, fpath
            )
            psi_cache[cache_key] = v
            v
        end
        # Source layout: header (frame_header_bytes) | total | densities × n_comp
        src_total_off = frame_header_bytes + 1
        dst_total_off = total_atlas_off + (snap - 1) * plane_bytes
        copyto!(out, dst_total_off, per_frame, src_total_off, plane_bytes)
        for c in 1:n_comp
            src_off = frame_header_bytes + plane_bytes + (c - 1) * plane_bytes + 1
            dst_off =
                total_atlas_off + panel_atlas_bytes +
                (c - 1) * panel_atlas_bytes + (snap - 1) * plane_bytes
            copyto!(out, dst_off, per_frame, src_off, plane_bytes)
        end
    end
    out
end

"""
3D density atlas: every snap of one component packed into one binary so
the 3D viewer can load the whole scrub timeline in a single fetch.
Layout (single-component, panel-major over snap):

    Char header (4):  "D3AT"
    Int32 header (6): n_snaps, nx, ny, nz, n_comp, component
    Float32 atlas:    n_snaps × nx × ny × nz

Reuses the per-frame `density3d_bin` cache: pre-warmed frames just memcpy
into the atlas region; missing frames are computed in passing and
cached.
"""
function _compute_density3d_atlas_binary(
    fpath::String, component::Int, n_snaps::Int, psi_cache::Dict{String, Any}
)
    n_snaps > 0 || throw(ArgumentError("n_snaps must be positive"))
    first_tup = _load_psi_cached(fpath, psi_cache, 1)
    psi1, n_comp, ndim, n_pts, F = first_tup
    ndim == 3 || throw(ArgumentError("density3d atlas requires 3D data"))
    nx = n_pts[1];
    ny = n_pts[2];
    nz = n_pts[3]
    voxel_n = nx * ny * nz
    voxel_bytes = voxel_n * 4

    header_size = 4 + 6 * 4  # magic + 6 Int32
    total_size = header_size + n_snaps * voxel_bytes
    out = Vector{UInt8}(undef, total_size)

    out[1] = UInt8('D');
    out[2] = UInt8('3');
    out[3] = UInt8('A');
    out[4] = UInt8('T')
    hdr_int = reinterpret(Int32, view(out, 5:28))
    hdr_int[1] = Int32(n_snaps)
    hdr_int[2] = Int32(nx)
    hdr_int[3] = Int32(ny)
    hdr_int[4] = Int32(nz)
    hdr_int[5] = Int32(n_comp)
    hdr_int[6] = Int32(component)

    # Per-frame data: pull from cache or compute. The per-snap binary
    # has its own header which we strip when copying.
    frame_header_bytes = 24 + n_comp * 4  # density3d_bin: header (24) + populations (n_comp*4)
    @inbounds for snap in 1:n_snaps
        cache_key = "density3d_bin:$(fpath)#snap=$(snap)#comp=$(component)#bsz=false"
        per_frame = if haskey(psi_cache, cache_key)
            psi_cache[cache_key]::Vector{UInt8}
        else
            while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                _evict_one!(psi_cache)
            end
            v = _compute_3d_density_binary(
                _load_psi_cached(fpath, psi_cache, snap)...; component=component
            )
            psi_cache[cache_key] = v
            v
        end
        src_off = frame_header_bytes + 1
        dst_off = header_size + (snap - 1) * voxel_bytes + 1
        copyto!(out, dst_off, per_frame, src_off, voxel_bytes)
    end
    out
end

"""
Phase slice packed as Float32. Layout:

    Int32 header (7):  ndim, axis, slice_idx, nx, ny, n_comp, F
    Float32 axis_ranges (4)
    Int32 m_values (n_comp)
    Float32 phases     (n_comp * nx * ny)   -- radians, [-π, π]
    Float32 densities  (n_comp * nx * ny)   -- |ψ_m|² for low-density masking
"""
function _compute_phase_slice_binary(
    psi, n_comp, ndim, n_pts, F,
    axis::Int, slice_idx::Union{Nothing, Int},
    jld2_path::String,
)
    ndim == 3 || throw(ArgumentError("Phase slice binary requires 3D data, got $(ndim)D"))
    axis = clamp(axis, 1, ndim)
    k = slice_idx === nothing ? max(1, n_pts[axis] ÷ 2) : clamp(slice_idx, 1, n_pts[axis])
    box = _read_box_size(jld2_path)

    remaining = [i for i in 1:ndim if i != axis]
    nx = n_pts[remaining[1]]
    ny = n_pts[remaining[2]]
    plane_n = nx * ny

    phases = Vector{Float32}(undef, n_comp * plane_n)
    densities = Vector{Float32}(undef, n_comp * plane_n)
    @inbounds for c in 1:n_comp
        comp_view = view(psi, _component_slice(ndim, n_pts, c)...)
        slice = selectdim(comp_view, axis, k)
        ph = vec(angle.(slice))
        de = vec(abs2.(slice))
        off = (c - 1) * plane_n
        for i in 1:plane_n
            phases[off + i] = Float32(ph[i])
            densities[off + i] = Float32(de[i])
        end
    end

    ax_ranges = if box !== nothing && length(box) >= ndim
        Float32[-box[remaining[1]] / 2, box[remaining[1]] / 2,
            -box[remaining[2]] / 2, box[remaining[2]] / 2]
    else
        Float32[0, nx - 1, 0, ny - 1]
    end
    m_values = Int32[F - (c - 1) for c in 1:n_comp]

    buf = IOBuffer(; sizehint=28 + 16 + n_comp*4 + 2*n_comp*plane_n*4)
    write(buf, Int32(ndim), Int32(axis), Int32(k), Int32(nx), Int32(ny),
        Int32(n_comp), Int32(F))
    write(buf, ax_ranges)
    write(buf, m_values)
    write(buf, phases)
    write(buf, densities)
    take!(buf)
end

# --- Binary APIs for performance ---

"""Load psi from JLD2 with caching. Returns (psi, n_comp, ndim, n_pts, F).

When `snap_idx === nothing` (default) the final `psi` field is returned.
When `snap_idx` is a positive integer, loads the requested time-slice
from `dynamics/psi_snapshots` (saved by runs with
`save_psi_snapshots: true`); the 5D array is up-cast to ComplexF64 so
downstream code (FFT, probability_current, etc.) runs at its native
precision."""
# Maximum number of entries kept in the dashboard's combined cache.
# Two flavours share the dict:
#   - heavy ψ snapshots, keyed by "path" or "path#snap=K" (~14 MB each)
#   - cheap derived binaries (density_bin/phase_bin/vortex_lines/…),
#     keyed by a "<kind>:" prefix (~300 KB each, often <1 MB)
# `_evict_one!` evicts the oldest *heavy* entry first so a long scrub
# session keeps every frame's pre-packed binary warm even after the ψ
# cache has fully cycled. Worst-case RAM with all-heavy entries is
# ~PSI_CACHE_MAX_ENTRIES × 14 MB; with all-derived it's ~PSI_CACHE_MAX_ENTRIES
# × 1 MB. 200 keeps a 157-frame Klaus run fully warm.
const PSI_CACHE_MAX_ENTRIES = 200

const _DERIVED_CACHE_PREFIXES = (
    "density_bin:", "phase_bin:", "density3d_bin:", "phase3d_bin:",
    "vorticity3d_bin:", "vector3d_bin:", "vortex_lines:", "density_max:",
    "density_atlas:",
)

function _is_derived_cache_key(k::AbstractString)
    for p in _DERIVED_CACHE_PREFIXES
        startswith(k, p) && return true
    end
    false
end

function _evict_one!(cache::Dict)
    # Prefer evicting a heavy ψ entry; only fall back to a derived blob
    # when nothing else is left.
    for k in keys(cache)
        if !_is_derived_cache_key(k)
            delete!(cache, k)
            return nothing
        end
    end
    # All entries are derived blobs — fall back to FIFO (insertion order).
    delete!(cache, first(keys(cache)))
end

# Tracks (file, axis) pairs whose density-binary cache is currently being
# warmed in the background. Singleton across `serve_dashboard` invocations
# (the cache itself is per-call, so a stale entry just means "skip warming
# until the in-flight task finishes" which is harmless).
const _PREPACK_INFLIGHT = Set{String}()

# Persistent JLD2 read handles keyed by absolute path. Each handle is
# paired with a ReentrantLock — JLD2 maintains shared internal state
# (jloffset Dict, read buffers) so concurrent readers on the same handle
# must serialise. Reusing a handle across requests skips the
# root-group + datatype-table reload cost (~30 ms cold) which dominated
# the per-snap latency.
#
# Capacity is bounded so we don't exhaust file descriptors when many runs
# get visited; LRU-ish eviction (FIFO via insertion order) closes the
# oldest open handle when the cap is hit.
const _OPEN_JLD_HANDLES = Dict{String, Tuple{JLD2.JLDFile, ReentrantLock}}()
const _OPEN_JLD_LOCK = ReentrantLock()
const _OPEN_JLD_MAX = 32

function _get_or_open_jld_handle(fpath::String)
    lock(_OPEN_JLD_LOCK) do
        existing = get(_OPEN_JLD_HANDLES, fpath, nothing)
        existing === nothing || return existing
        while length(_OPEN_JLD_HANDLES) >= _OPEN_JLD_MAX
            (k, (h, _)) = first(_OPEN_JLD_HANDLES)
            try
                close(h)
            catch
            end
            delete!(_OPEN_JLD_HANDLES, k)
        end
        h = jldopen(fpath, "r")
        l = ReentrantLock()
        _OPEN_JLD_HANDLES[fpath] = (h, l)
        (h, l)
    end
end

"""Run `f(handle)` against the persistent JLD2 handle for `fpath`,
holding the per-path lock for the duration. Use for short, sequential
reads — long critical sections will starve concurrent fetchers."""
function _with_jld_handle(f::Function, fpath::String)
    h, l = _get_or_open_jld_handle(fpath)
    lock(l) do
        f(h)
    end
end

# --- Atlas disk-cache: persist computed atlases between dashboard runs ---
# The /api/density_atlas pre-build takes ~1.4 s per axis the first time
# a Klaus-sized run is opened. Writing the resulting blob to a sibling
# `_dashboard_cache/` directory means we can re-load it instantly on the
# next dashboard restart, eliminating the cold path for repeat sessions.
#
# Cache is keyed by (run, file, axis, bsz). Validity is checked against
# the source jld2's mtime: if the simulation rewrites the file, the
# cached atlas is silently rebuilt.

const _DASHBOARD_CACHE_DIRNAME = "_dashboard_cache"

function _atlas_disk_path(base_dir::String, fpath::String, axis::Int, bsz::Bool)
    rel = relpath(fpath, base_dir)
    safe = replace(rel, '/' => "__", '\\' => "__")
    cache_dir = joinpath(base_dir, _DASHBOARD_CACHE_DIRNAME)
    joinpath(cache_dir, "atlas__$(safe)__axis$(axis)__bsz$(bsz).bin")
end

"""Try to load a previously-cached atlas from disk. Returns the blob or
nothing if it's missing, stale, or corrupted. Caller must validate by
re-pack on `nothing`."""
function _try_load_atlas_from_disk(base_dir::String, fpath::String, axis::Int, bsz::Bool)
    cache_path = _atlas_disk_path(base_dir, fpath, axis, bsz)
    isfile(cache_path) || return nothing
    # Stale check: source jld2 newer than cache → invalidate.
    src_mtime = mtime(fpath)
    cache_mtime = mtime(cache_path)
    cache_mtime >= src_mtime || return nothing
    try
        return read(cache_path)
    catch
        return nothing
    end
end

"""Write atlas blob to disk-cache. Best-effort — failures (full disk,
permission denied, etc.) are logged but don't propagate."""
function _save_atlas_to_disk(
    base_dir::String, fpath::String, axis::Int, bsz::Bool, blob::Vector{UInt8}
)
    cache_path = _atlas_disk_path(base_dir, fpath, axis, bsz)
    try
        mkpath(dirname(cache_path))
        # Atomic write: tmp + rename so a concurrent reader never sees a
        # half-written file.
        tmp = cache_path * ".tmp"
        open(tmp, "w") do io
            write(io, blob)
        end
        mv(tmp, cache_path; force=true)
    catch e
        @warn "Failed to persist atlas cache: $(e)"
    end
end

"""
Pre-compute every per-snap density_bin for `fpath` along `axis` and cache
the results in `psi_cache`. Runs as a background `@async` task, yielding
between frames so HTTP handlers stay responsive. Idempotent: skips frames
that are already cached.

Why: the cold path for a single frame is dominated by the JLD2 read
(~30 ms even after OS page cache warm-up). Eagerly walking every frame
once during the run-open hop turns subsequent scrubbing into a pure cache
hit (sub-ms). The cache cap is 200 entries — enough for the 157-frame
Klaus run + room for a few ψ snapshots without eviction churn.
"""
function _warm_density_bin_all(
    fpath::String, n_snapshots::Int, axis::Int, psi_cache::Dict{String, Any},
    base_dir::String,
)
    inflight_key = "warm_density_bin:$(fpath)#axis=$(axis)"
    try
        atlas_key_raw = "density_atlas:$(fpath)#axis=$(axis)#bsz=false"
        atlas_key_bsz = "density_atlas:$(fpath)#axis=$(axis)#bsz=true"
        # Try the disk-cache first — survives dashboard restarts and skips
        # the ~1.4 s pack cost entirely.
        if !haskey(psi_cache, atlas_key_raw)
            disk_raw = _try_load_atlas_from_disk(base_dir, fpath, axis, false)
            if disk_raw !== nothing
                psi_cache[atlas_key_raw] = disk_raw
            end
        end
        if !haskey(psi_cache, atlas_key_bsz)
            disk_bsz = _try_load_atlas_from_disk(base_dir, fpath, axis, true)
            if disk_bsz !== nothing
                psi_cache[atlas_key_bsz] = disk_bsz
            end
        end
        # Build the raw atlas if it isn't in either cache. The atlas walks
        # every snap internally and back-fills the per-snap cache as a
        # side effect.
        if !haskey(psi_cache, atlas_key_raw)
            try
                while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                    _evict_one!(psi_cache)
                end
                raw = _compute_column_density_atlas_binary(fpath, axis, n_snapshots, psi_cache)
                psi_cache[atlas_key_raw] = raw
                _save_atlas_to_disk(base_dir, fpath, axis, false, raw)
            catch
                # Best-effort
            end
        end
        yield()
        # bsz variant for slow-link clients (LAN/SSH tunnel).
        if !haskey(psi_cache, atlas_key_bsz)
            try
                raw = get(psi_cache, atlas_key_raw, nothing)
                if raw !== nothing
                    while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                        _evict_one!(psi_cache)
                    end
                    bsz_blob = _maybe_bitshuffle_zstd(raw, true)
                    psi_cache[atlas_key_bsz] = bsz_blob
                    _save_atlas_to_disk(base_dir, fpath, axis, true, bsz_blob)
                end
            catch
                # Best-effort
            end
        end
    finally
        delete!(_PREPACK_INFLIGHT, inflight_key)
    end
end

function _load_psi_cached(
    jld2_path::String,
    cache::Dict{String, Any},
    snap_idx::Union{Nothing, Int}=nothing,
)
    key = snap_idx === nothing ? jld2_path : "$(jld2_path)#snap=$(snap_idx)"
    if haskey(cache, key)
        return cache[key]
    end
    # Evict oldest when at cap (Dicts iterate in insertion order in Julia,
    # so popfirst!-style first-key removal gives us FIFO eviction).
    while length(cache) >= PSI_CACHE_MAX_ENTRIES
        _evict_one!(cache)
    end
    get!(cache, key) do
        if snap_idx === nothing
            d = JLD2.load(jld2_path)
            psi = d["psi"]
        else
            # Two on-disk layouts are supported:
            #   (1) streamed — one key per frame, keys
            #       "dynamics/psi_snapshots_streamed/frame_00001" … 00154.
            #       Written by the current simulator; peak memory on the
            #       write side is one snapshot.
            #   (2) legacy — a single 5D array "dynamics/psi_snapshots"
            #       with the snapshot index on the trailing axis.
            # Only read the requested frame in either case; never stack.
            #
            # Read at the on-disk precision (ComplexF32 by default per
            # `save_snapshot_precision: "f32"`). Promoting to ComplexF64
            # here doubled disk read + conversion cost; the binary
            # column/phase packers already cast to Float32, and the
            # JSON helpers promote via `Float64(...)` lazily, so they
            # don't care.
            psi = _with_jld_handle(jld2_path) do f
                if haskey(f, "dynamics/psi_snapshots_streamed/n_snapshots")
                    n = Int(f["dynamics/psi_snapshots_streamed/n_snapshots"])
                    k = clamp(snap_idx, 1, n)
                    key = "dynamics/psi_snapshots_streamed/frame_" *
                          lpad(string(k), 5, '0')
                    f[key]
                elseif haskey(f, "dynamics/psi_snapshots")
                    snaps = f["dynamics/psi_snapshots"]
                    n = size(snaps, ndims(snaps))
                    k = clamp(snap_idx, 1, n)
                    idx = ntuple(
                        d -> d == ndims(snaps) ? k : Colon(),
                        ndims(snaps),
                    )
                    Array(view(snaps, idx...))
                else
                    throw(
                        ArgumentError(
                            "No psi snapshots in $(jld2_path). Re-run with " *
                            "`save_psi_snapshots: true`.",
                        ),
                    )
                end
            end
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
        # Use a fresh handle here rather than the persistent
        # _OPEN_JLD_HANDLES one: this function holds the lock for the
        # entire 16-frame `_global_density_max_total_sampled` walk
        # (~250 ms), which would block the background prepack and any
        # in-flight scrub fetches sharing the handle. /api/snapshots is
        # called once per run-open hop, so the per-call open cost is
        # acceptable in exchange for not starving the hot path.
        jldopen(jld2_path, "r") do f
            times = haskey(f, "dynamics/times") ?
                    Float64.(f["dynamics/times"]) : Float64[]
            if haskey(f, "dynamics/psi_snapshots_streamed/n_snapshots")
                n = Int(f["dynamics/psi_snapshots_streamed/n_snapshots"])
                shape = Int.(f["dynamics/psi_snapshots_streamed/spatial_shape"])
                D = Int(f["dynamics/psi_snapshots_streamed/n_components"])
                # `times` includes t=0 (the GS state) PLUS one entry per
                # save_every checkpoint. Streamed frames only cover the
                # checkpoints, so times has length n+1. Slice the leading
                # t=0 off so times[k] aligns with frame_NNNNN where N=k.
                times_aligned = length(times) == n + 1 ? times[2:end] : times
                # density_max_total moved to its own /api/density_max
                # endpoint — the 16-frame walk took ~0.8 s and blocked the
                # snapshots response. Lazy fetch keeps run-open instant.
                return Dict{String, Any}(
                    "n_snapshots" => n,
                    "times" => times_aligned,
                    "shape" => vcat(shape, D),
                )
            elseif haskey(f, "dynamics/psi_snapshots")
                snaps = f["dynamics/psi_snapshots"]
                n_snaps = size(snaps, ndims(snaps))
                times_aligned = length(times) == n_snaps + 1 ? times[2:end] : times
                return Dict{String, Any}(
                    "n_snapshots" => n_snaps,
                    "times" => times_aligned,
                    "shape" => collect(size(snaps)[1:(end - 1)]),
                )
            end
            nothing
        end
    catch
        nothing
    end
end

"""Sub-sample n_samples evenly-spaced snapshots and return the max
spin-summed total density across them. Full sweep through all 157
Klaus frames takes ~8 s; sub-sampled to 16 frames it's ~0.8 s,
within HTTP timeout budget. Always includes the first + last frame.

Returned value is the physically correct normalisation reference
for the 3D viewer (same density renders the same color frame-to-frame).
"""
function _global_density_max_total_sampled(f, n_snapshots::Int; n_samples::Int=16)
    n_snapshots == 0 && return 1.0
    # Sample indices: evenly spaced + include endpoints
    idxs = if n_snapshots <= n_samples
        collect(1:n_snapshots)
    else
        unique([1; round.(Int, range(1, n_snapshots; length=n_samples)); n_snapshots])
    end
    g_max = 0.0
    for k in idxs
        key = "dynamics/psi_snapshots_streamed/frame_" * lpad(string(k), 5, '0')
        haskey(f, key) || continue
        frame = f[key]
        ndim = ndims(frame) - 1
        D = size(frame, ndim + 1)
        # Spin-summed density per grid cell. Avoid CartesianIndices
        # for speed: sum over component axis with abs2.(view(...)).
        n_total = sum(c -> abs2.(view(frame, ntuple(d -> d <= ndim ? Colon() : c, ndim + 1)...)),
            1:D)
        local_max = Float64(maximum(n_total))
        local_max > g_max && (g_max = local_max)
    end
    g_max
end

"""
Compute a single 3D density component as binary Float32.
"""
function _compute_3d_density_binary(psi, n_comp, ndim, n_pts, F; component::Int=0)
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
    ωx, ωy, ωz = superfluid_vorticity(psi, grid, plans; density_cutoff=cutoff)

    N = prod(n_pts)
    # Also zero the output outside the cloud to be defensive; the cutoff
    # above zeroes v, but numerical ∇ can still pick up edge gradients.
    mag = Vector{Float32}(undef, N)
    total_flat = vec(total_n)
    @inbounds for i in 1:N
        if total_flat[i] < cutoff
            mag[i] = 0.0f0
        else
            a = ωx[i];
            b = ωy[i];
            c = ωz[i]
            mag[i] = Float32(sqrt(a*a + b*b + c*c))
        end
    end

    pops = Float32[
        Float32(sum(abs2, view(psi, _component_slice(ndim, n_pts, m)...))) for m in 1:n_comp
    ]
    total_pop = sum(pops)
    pops ./= max(total_pop, 1.0f-30)

    buf = IOBuffer(; sizehint=24 + n_comp * 4 + N * 4)
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
function _compute_3d_phase_binary(psi, n_comp, ndim, n_pts, F; component::Int=0)
    ndim == 3 || throw(ArgumentError("3D phase requires 3D data"))
    component >= 1 || throw(ArgumentError("phase3d requires component >= 1 (per-m only)"))
    c = clamp(component, 1, n_comp)

    psi_c = view(psi, _component_slice(ndim, n_pts, c)...)
    phase = zeros(Float32, n_pts...)
    @inbounds for i in eachindex(psi_c)
        phase[i] = Float32(angle(psi_c[i]))
    end

    pops = Float32[
        Float32(sum(abs2, view(psi, _component_slice(ndim, n_pts, m)...))) for m in 1:n_comp
    ]
    total_pop = sum(pops)
    pops ./= max(total_pop, 1.0f-30)

    N = prod(n_pts)
    buf = IOBuffer(; sizehint=24 + n_comp * 4 + N * 4)
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
function _compute_rotated_3d_density_binary(
    psi, n_comp, ndim, n_pts, F; angle_deg::Float64=0.0, component::Int=0
)
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
    # Match precision so the BLAS matmul stays on the fast path; psi may
    # be ComplexF32 (snapshot default) and R is ComplexF64.
    R_row = convert(Vector{eltype(psi)}, R[c, :])
    psi_flat = reshape(psi, N, n_comp)
    psi_c_rot = psi_flat * conj.(R_row)  # (N,D) * (D,) → (N,) complex
    dens = Float32.(abs2.(psi_c_rot))

    # Compute rotated populations (cheap: just norms of R * population_vector)
    pops_orig = Float32[
        Float32(sum(abs2, view(psi, _component_slice(ndim, n_pts, m)...))) for m in 1:n_comp
    ]
    total_pop = sum(pops_orig)
    pops_orig ./= max(total_pop, 1.0f-30)

    buf = IOBuffer(; sizehint=24 + n_comp * 4 + N * 4)
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
    pops ./= max(total_pop, 1.0f-30)

    buf = IOBuffer(; sizehint=24 + n_comp * 4 + N * 4)
    write(buf, Int32(n_pts[1]), Int32(n_pts[2]), Int32(n_pts[3]))
    write(buf, Int32(n_comp), Int32(F), Int32(component))
    write(buf, pops)
    write(buf, vec(dens))  # flatten to column-major 1D
    take!(buf)
end

"""
Compute coherence matrix C_{mn}(x,y) = Σ_z ψ_m*(x,y,z) ψ_n(x,y,z) for quantization axis rotation.
"""
function _compute_coherence_matrix_binary(psi, n_comp, ndim, n_pts, F, axis::Int=3)
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

const _vector3d_plans_cache = Dict{NTuple{3, Int}, Tuple{FFTPlans, Grid{3}}}()

function _load_box_size(jld2_path::String)
    # Preferred: pull "grid_box_size" from the JLD2 file itself (newer runs
    # embed it). Older runs — e.g. eu151_edh/point_001.jld2 — don't. FileIO
    # may re-wrap JLD2's KeyError as CapturedException, so swallow any
    # lookup failure and fall back to the sibling config.yaml.
    try
        d = _with_jld_handle(jld2_path) do f
            haskey(f, "grid_box_size") ? f["grid_box_size"] : nothing
        end
        d === nothing || return NTuple{3, Float64}(d)
    catch
        # fall through
    end
    box = _read_box_size(jld2_path)
    if box === nothing || length(box) < 3
        throw(
            ArgumentError(
                "Cannot resolve box_size for $(jld2_path): missing `grid_box_size` " *
                "in the JLD2 file and no usable grid.box in config.yaml.",
            ),
        )
    end
    NTuple{3, Float64}((Float64(box[1]), Float64(box[2]), Float64(box[3])))
end

function _get_plans_and_grid(n_pts::NTuple{3, Int}, box_size::NTuple{3, Float64})
    get!(_vector3d_plans_cache, n_pts) do
        grid = make_grid(GridConfig(n_pts, box_size))
        plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
        (plans, grid)
    end
end

function _compute_vector3d_binary(psi, n_comp, ndim, n_pts, F, box_size;
    field::Symbol=:current, stride::Int=2)
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
    buf = IOBuffer(; sizehint=28 + 4 * 4 * N_sub)
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
