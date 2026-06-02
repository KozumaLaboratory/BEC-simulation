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
`scratch_clear!(:my_category)` empties one category — useful when the
grid changes mid-session.

`SCRATCH_REGISTRY` is single-threaded by construction; callers running
under multi-threading should partition by thread id in their `key`.
"""
const SCRATCH_REGISTRY = IdDict{Symbol, IdDict{Any, Any}}()

function scratch_get!(factory::Function, category::Symbol, key)
    cache = get!(SCRATCH_REGISTRY, category) do
        IdDict{Any, Any}()
    end
    return get!(factory, cache, key)
end

function scratch_clear!(category::Symbol)
    haskey(SCRATCH_REGISTRY, category) && empty!(SCRATCH_REGISTRY[category])
    nothing
end

function scratch_clear_all!()
    for cat in keys(SCRATCH_REGISTRY)
        empty!(SCRATCH_REGISTRY[cat])
    end
    nothing
end
