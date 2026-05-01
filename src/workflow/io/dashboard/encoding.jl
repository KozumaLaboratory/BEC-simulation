# --- Dashboard payload encoding: bitshuffle + zstd ---
#
# Slowly-varying physical fields (e.g. BEC density profiles) compress very
# poorly under raw zstd because the Float32 high-order bytes vary ~uniformly.
# Bitshuffle reorders bytes so the i-th byte of every element becomes
# contiguous, which dramatically improves zstd's compression ratio
# (~3× vs ~1.05× on raw float32). See docs/dashboard_2d_optimization_research.md.

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
