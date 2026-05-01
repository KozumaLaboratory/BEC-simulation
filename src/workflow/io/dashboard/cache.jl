# --- Dashboard cache layers: ψ + derived blobs + JLD2 handles + atlas disk ---
#
# Six cache state pools live here (PSI_CACHE-keyed dict, _DERIVED_CACHE_PREFIXES,
# _PREPACK_INFLIGHT, _OPEN_JLD_HANDLES + lock, _DASHBOARD_CACHE_DIRNAME). The
# topology + the unified `clear_all_caches!` / `invalidate_path!` entry
# points are documented inline.

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
    "density_atlas:", "synth_disp:",
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

# --- Cache topology -----------------------------------------------------
#
# The dashboard maintains six parallel caches. Each addresses a distinct
# bottleneck and they share no keys, but they all need to be cleared
# together when a run regenerates its on-disk files (otherwise the user
# sees stale data even after `/api/refresh`).
#
#   data_cache             run-level JSON responses (per /api/data/<run>)
#   psi_cache              ψ + derived binary blobs keyed by fpath[#snap=K]
#   _OPEN_JLD_HANDLES      persistent JLD2 read handles (mmap'd)
#   _vector3d_plans_cache  FFT plans per (nx, ny, nz)
#   _PREPACK_INFLIGHT      in-flight prepack-warmer task IDs
#   _DASHBOARD_CACHE_DIRNAME  on-disk atlas blobs (per run dir)
#
# Two helpers below are the canonical entry points for invalidation:
# `clear_all_caches!` (used by /api/refresh) and `invalidate_path!`
# (used when a single run regenerates).

"""Drop every cache layer at once. Used by /api/refresh."""
function clear_all_caches!(data_cache::Dict, psi_cache::Dict)
    empty!(data_cache)
    empty!(psi_cache)
    empty!(_vector3d_plans_cache)
    empty!(_PREPACK_INFLIGHT)
    lock(_OPEN_JLD_LOCK) do
        for (_, (h, _)) in _OPEN_JLD_HANDLES
            try
                close(h)
            catch
            end
        end
        empty!(_OPEN_JLD_HANDLES)
    end
    return nothing
end

"""Drop every cache entry that references `fpath` so the next request
reads it fresh. Other runs' caches are preserved."""
function invalidate_path!(data_cache::Dict, psi_cache::Dict, fpath::String)
    for k in collect(keys(data_cache))
        occursin(k, fpath) && delete!(data_cache, k)
    end
    for k in collect(keys(psi_cache))
        occursin(fpath, k) && delete!(psi_cache, k)
    end
    lock(_OPEN_JLD_LOCK) do
        if haskey(_OPEN_JLD_HANDLES, fpath)
            (h, _) = _OPEN_JLD_HANDLES[fpath]
            try
                close(h)
            catch
            end
            delete!(_OPEN_JLD_HANDLES, fpath)
        end
    end
    # Plans cache + prepack-inflight aren't path-keyed; leave alone.
    return nothing
end

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
