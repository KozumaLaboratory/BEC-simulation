# --- WebSocket subprotocol: handshake + frame I/O + binary scrubber payload ---
#
# Hand-rolled WS implementation (no fragmentation, no permessage-deflate)
# because the time-scrubber's per-frame payload is dense Float32 — built-in
# WS compression doesn't help and adds latency.

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

