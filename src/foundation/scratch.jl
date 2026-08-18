"""
Single-source-of-truth scratch-buffer registry for hot-path allocations
that would otherwise leak per call into the CUDA pool (or just churn the
GC). Replaces three earlier ad-hoc IdDict caches:

  * `_ENERGY_GRADIENT_SCRATCH` (kinetic/Coriolis FFT + spin-density bufs)
  * `_LBFGS_SCRATCH` (LBFGS direction-update + line-search bufs)
  * `_AXIS_BCAST_DEV_CACHE` (device-resident coordinate / wavenumber vecs)

Usage:

    buf = scratch_get!(:my_category, (typeof(psi), size)) do
        similar(psi, ComplexF64, size)
    end

The factory closure runs ONCE per `(category, key)`; subsequent calls
return the cached value. `key` should be hashable and capture the
allocation shape + device (typically `(typeof(template), shape...)`).

`SCRATCH_REGISTRY` is single-threaded by construction; callers running
under multi-threading should partition by thread id in their `key`.
"""
const SCRATCH_REGISTRY = IdDict{Symbol, IdDict{Any, Any}}()

"""
    scratch_clear!(category::Symbol...) → nothing

Drop cached scratch. With no argument, drops everything.

The registry deliberately holds STRONG references to both keys and values —
that is what pins a host array against GC so no later array can reuse its
address and inherit its device copy. The cost is that nothing in it is ever
collectable, so a GPU buffer parked here survives `GC.gc()` and
`CUDA.reclaim()` cannot return its memory to the driver either: reclaim only
frees what the pool already considers free.

The scan loop in `pipeline/run_registry.jl` drops the workspace and reclaims
between points precisely to stop device buffers accumulating, and its own
comment names k² as one of the things it is freeing — but the device k² copy
lives HERE, not on the workspace, so that sequence could not reach it. Clearing
between scan points is safe: every entry is a pure function of its key and is
rebuilt on next use.
"""
function scratch_clear!(categories::Symbol...)
    if isempty(categories)
        empty!(SCRATCH_REGISTRY)
    else
        for c in categories
            haskey(SCRATCH_REGISTRY, c) && empty!(SCRATCH_REGISTRY[c])
        end
    end
    nothing
end

function scratch_get!(factory::Function, category::Symbol, key)
    cache = get!(SCRATCH_REGISTRY, category) do
        IdDict{Any, Any}()
    end
    return get!(factory, cache, key)
end
