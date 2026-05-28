# Dashboard HTTP server core (Sockets-based, no HTTP.jl dep)

export serve_dashboard

# --- Dashboard server (stdlib Sockets only, no HTTP.jl needed) ---

const _REPO_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", "..", ".."))
const _WEB_DIST_DIR = joinpath(_REPO_ROOT, "dashboard", "dist")
const _WEB_DIST_INDEX = joinpath(_WEB_DIST_DIR, "index.html")
const _LEGACY_DASHBOARD_HTML = joinpath(_REPO_ROOT, "runs", "tools", "dashboard.html")

"""
    serve_dashboard(port=8080; base_dir="runs")

Start a local HTTP server for the React + WebGPU dashboard.
Browse to http://localhost:\$port to view results.

Requires `dashboard/dist/` (run `cd dashboard && bun run build`). The
legacy Plotly dashboard remains reachable at `/legacy` as long as
`runs/tools/dashboard.html` exists.

API:
- `GET /`               → React dashboard (dashboard/dist/index.html)
- `GET /assets/*`       → hashed static assets from dashboard/dist/assets/
- `GET /favicon.svg`    → favicon from dashboard/dist/
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
function serve_dashboard(port::Int=8080; base_dir::String="runs",
    bind::AbstractString=get(ENV, "SPINORBEC_DASHBOARD_BIND", "0.0.0.0"),
)
    if !isfile(_WEB_DIST_INDEX)
        throw(
            ArgumentError(
                "React dashboard not built. Run: cd dashboard && bun install && bun run build"
            ),
        )
    end
    # Read index.html / legacy.html on each request, mtime-gated. Avoids
    # the previous footgun where a `bun run build` while the server was
    # alive would point the cached HTML at a stale asset hash and the
    # browser landed on a black screen until restart.
    html_cache = Ref{Tuple{Float64, String}}((0.0, ""))
    legacy_cache = Ref{Tuple{Float64, String}}((0.0, ""))
    fetch_html() = _mtime_cached_read(html_cache, _WEB_DIST_INDEX)
    fetch_legacy() =
        if isfile(_LEGACY_DASHBOARD_HTML)
            _mtime_cached_read(legacy_cache, _LEGACY_DASHBOARD_HTML)
        else
            ""
        end

    data_cache = Dict{String, String}()
    psi_cache = Dict{String, Any}()  # path → (psi, n_comp, n_pts, F, pops)

    # `bind` controls which interface the server listens on. Default
    # `"0.0.0.0"` keeps the dev workflow (LAN access from any host on
    # the lab network, VITE_API_TARGET reachable). Set to `"127.0.0.1"`
    # (or via `SPINORBEC_DASHBOARD_BIND=127.0.0.1`) when fronted by a
    # reverse proxy like Caddy — the dashboard then refuses direct LAN
    # access and only the proxied + authenticated path remains.
    bind_addr = try
        parse(IPAddr, String(bind))
    catch
        throw(
            ArgumentError(
                "serve_dashboard: bind=$(repr(bind)) is not a valid IP literal " *
                "(expected e.g. \"0.0.0.0\" or \"127.0.0.1\")"),
        )
    end
    server = Sockets.listen(Sockets.InetAddr(bind_addr, port))
    println("Dashboard server running at http://$(bind_addr):$port")
    println("  Serving runs from: $(abspath(base_dir))")
    println("  React app:         $(_WEB_DIST_INDEX)")
    !isempty(fetch_legacy()) && println("  Legacy dashboard:  /legacy")
    println("  Press Ctrl+C to stop")
    flush(stdout)

    try
        while true
            sock = Sockets.accept(server)
            @async _handle_dashboard_connection(
                sock, fetch_html, fetch_legacy, data_cache, psi_cache, base_dir
            )
        end
    catch e
        e isa InterruptException || rethrow(e)
        println("\nDashboard server stopped.")
    finally
        close(server)
    end
end

# Re-read a file when its mtime advances past the cached version.
# Cheap when the file is unchanged (a single stat call); avoids stale
# HTML when `bun run build` lands while the server is still up.
function _mtime_cached_read(slot::Ref{Tuple{Float64, String}}, path::AbstractString)
    m = mtime(path)
    last_m, last_content = slot[]
    if m != last_m
        last_content = read(path, String)
        slot[] = (m, last_content)
    end
    last_content
end

function _handle_dashboard_connection(
    sock, fetch_html, fetch_legacy, data_cache, psi_cache, base_dir
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
            # Upstream-proxy auth headers — Caddy/oauth2-proxy/nginx pass
            # the authenticated identity here so write endpoints can use
            # it as `enqueued_by` provenance. We trust these only when
            # the dashboard is behind a reverse proxy; direct access
            # bypasses them and falls back to session_id.
            #
            # Priority (most specific → least):
            #   X-Auth-Request-Email     — oauth2-proxy w/ Google Workspace
            #                              (full institutional address,
            #                              e.g. anko@isct.ac.jp)
            #   X-Authenticated-User     — Caddy basicauth
            #   X-Forwarded-User         — oauth2-proxy GitHub / generic
            #   Remote-User              — nginx / legacy
            # First non-empty header in this order wins.
            authed_user = ""
            authed_user_priority = typemax(Int)
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
                else
                    p =
                        if startswith(lc, "x-auth-request-email:")
                            1
                        elseif startswith(lc, "x-authenticated-user:")
                            2
                        elseif startswith(lc, "x-forwarded-user:")
                            3
                        elseif startswith(lc, "remote-user:")
                            4
                        else
                            0
                        end
                    if p > 0 && p < authed_user_priority
                        v = String(strip(split(line, ':'; limit=2)[2]))
                        if !isempty(v)
                            authed_user = v
                            authed_user_priority = p
                        end
                    end
                end
            end

            # WebSocket upgrade hijacks the connection — handshake +
            # binary push loop, then close the socket on disconnect.
            if ws_upgrade && method == "GET" && !isempty(ws_key) && startswith(path, "/ws/")
                _websocket_serve(sock, path, ws_key, psi_cache, base_dir)
                break
            end

            keep_alive = !client_close
            # Profile every request — `[t=Nms s=BYTES] method path → code`.
            # Activate by setting SPINORBEC_DASHBOARD_LOG=1; default off so
            # production sessions don't spam stdout. Timings include both
            # route compute and response delivery (HTTP write).
            log_requests = get(ENV, "SPINORBEC_DASHBOARD_LOG", "") == "1"
            t0 = log_requests ? time_ns() : UInt64(0)
            if method == "POST"
                body_bytes = content_length > 0 ? read(sock, content_length) : UInt8[]
                status, content_type, body = _route_dashboard_post(
                    path, body_bytes, base_dir; authed_user=authed_user
                )
                _send_http_response(sock, status, content_type, body; keep_alive, accept_gzip)
            else
                status, content_type, body = _route_dashboard(
                    path, fetch_html(), fetch_legacy(), data_cache, psi_cache, base_dir
                )
                _send_http_response(sock, status, content_type, body; keep_alive, accept_gzip)
            end
            if log_requests
                # Use stdout + explicit flush — stderr is fully-buffered
                # under nohup redirection in this Julia, so println(stderr,…)
                # never reaches the log file in real time.
                dt_ms = (time_ns() - t0) / 1e6
                size_b = body isa AbstractVector ? length(body) : sizeof(body)
                println(stdout, "[t=",
                    round(dt_ms; digits=1), "ms s=",
                    size_b, "] ", method, " ", status, " ", path)
                flush(stdout)
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
function _route_dashboard_post(path, body_bytes, base_dir;
    authed_user::AbstractString="",
)
    if path == "/api/queue/enqueue"
        return _route_autopilot_enqueue(body_bytes, base_dir;
            authed_user=authed_user)
    end
    if path == "/api/queue/action"
        return _route_autopilot_action(body_bytes, base_dir;
            authed_user=authed_user)
    end
    if path == "/api/tags"
        return _route_tags_post(body_bytes, base_dir;
            authed_user=authed_user)
    end
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
    elseif startswith(path, "/api/effective_config/")
        return _route_effective_config(path, base_dir)
    elseif path == "/api/tags"
        return _route_tags_get(base_dir)
    elseif startswith(path, "/api/queue")
        return _route_autopilot_queue(path)
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
