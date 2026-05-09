# Dashboard static asset + HTTP response helpers

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
