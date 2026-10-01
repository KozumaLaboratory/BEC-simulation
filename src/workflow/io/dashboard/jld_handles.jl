# Persistent JLD2 read handles keyed by absolute path. Each handle is
# paired with a ReentrantLock — JLD2 maintains shared internal state
# (jloffset Dict, read buffers) so concurrent readers on the same handle
# must serialise. Reusing a handle across requests skips the
# root-group + datatype-table reload cost (~30 ms cold) which dominated
# the per-snap latency.
#
# Capacity is bounded so we don't exhaust file descriptors when many runs
# get visited; eviction closes one pooled handle when the cap is hit.
const _OPEN_JLD_HANDLES = Dict{String, Tuple{JLD2.JLDFile, ReentrantLock}}()
const _OPEN_JLD_LOCK = ReentrantLock()
const _OPEN_JLD_MAX = 32

"""Retire one path, or the whole pool, waiting for its active readers."""
function _retire_jld_handles!(fpath::Union{Nothing, String}=nothing)
    entries = lock(_OPEN_JLD_LOCK) do
        if fpath === nothing
            entries = collect(values(_OPEN_JLD_HANDLES))
            empty!(_OPEN_JLD_HANDLES)
            entries
        else
            entry = pop!(_OPEN_JLD_HANDLES, fpath, nothing)
            entry === nothing ? () : (entry,)
        end
    end
    _close_jld_entries!(entries)
    nothing
end

# Remove entries under the pool lock, then close under their individual locks.
# Waiting for readers while holding the pool lock would block unrelated files.
function _close_jld_entries!(entries)
    failures = Any[]
    for (h, reader_lock) in entries
        try
            lock(reader_lock) do
                close(h)
            end
        catch err
            push!(failures, err)
        end
    end
    isempty(failures) || throw(CompositeException(failures))
    nothing
end

function _get_or_open_jld_handle(fpath::String)
    retired = Tuple{JLD2.JLDFile, ReentrantLock}[]
    entry = try
        lock(_OPEN_JLD_LOCK) do
            existing = get(_OPEN_JLD_HANDLES, fpath, nothing)
            existing === nothing || return existing
            while length(_OPEN_JLD_HANDLES) >= _OPEN_JLD_MAX
                k = first(keys(_OPEN_JLD_HANDLES))
                push!(retired, pop!(_OPEN_JLD_HANDLES, k))
            end
            # A retired generation may still be in use by an earlier reader.
            # JLD2's default open can return that same object; independent opens
            # keep each generation paired with exactly one reader lock.
            h = jldopen(fpath, "r"; parallel_read=true)
            l = ReentrantLock()
            _OPEN_JLD_HANDLES[fpath] = (h, l)
            (h, l)
        end
    finally
        _close_jld_entries!(retired)
    end
    entry
end

"""Run `f(handle)` against the persistent JLD2 handle for `fpath`,
holding the per-path lock for the duration. Use for short, sequential
reads — long critical sections will starve concurrent fetchers."""
function _with_jld_handle(f::Function, fpath::String)
    while true
        h, l = _get_or_open_jld_handle(fpath)
        lock(l)
        try
            # Invalidation may have retired this entry between lookup and lock.
            # Retry against the live pool instead of reading a closed handle.
            active = lock(_OPEN_JLD_LOCK) do
                entry = get(_OPEN_JLD_HANDLES, fpath, nothing)
                entry !== nothing && entry[1] === h && entry[2] === l
            end
            active && return f(h)
        finally
            unlock(l)
        end
    end
end
