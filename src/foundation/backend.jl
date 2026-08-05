export CPUBackend, CUDABackend, seed_device_rng!

struct CPUBackend <: AbstractBackend end
struct CUDABackend <: AbstractBackend end

_zeros(::CPUBackend, T::Type, dims...) = zeros(T, dims...)
_similar(::CPUBackend, arr::AbstractArray) = similar(arr)
_similar(::CPUBackend, arr::AbstractArray, T::Type, dims...) = similar(arr, T, dims...)
_to_device(::CPUBackend, arr) = arr
_to_host(arr::Array) = arr
_to_host(arr::AbstractArray) = Array(arr)
_fft_kwargs(::CPUBackend, flags) = (; flags=flags)

_is_gpu(::Array) = false
_is_gpu(::AbstractArray) = true

"""
    _to_device_cached(backend, host::AbstractArray) → AbstractArray

`host` resident on `backend`'s device, allocated and copied ONCE per
`(device array type, host array identity)` and cached in the shared scratch
registry. CPU returns `host` itself.

Use this — not `_to_device` — for read-only device copies of *workspace-
lifetime* host arrays taken inside a hot path. `Grid.k_squared` is a host
`Array` even for a GPU workspace, so the plain `_to_device(ws.backend,
ws.grid.k_squared)` that the kinetic operator face used allocated a fresh
`CuArray` and paid a full host→device copy of k² on every gradient and every
energy evaluation — i.e. several times per L-BFGS iteration, forever.

Keyed on the IDENTITY of `host` (the key tuple holds the array itself, so it
is also pinned against GC and no later array can reuse its address and inherit
its entry). Mutating `host` in place after the first call would leave the
device copy stale, so only pass arrays that are immutable in practice.
"""
function _to_device_cached(backend::AbstractBackend, host::AbstractArray)
    host isa Array || return host   # already device-resident
    backend isa CPUBackend && return host
    return scratch_get!(:to_device_cached, (typeof(backend), host)) do
        _to_device(backend, host)
    end
end

"""
    _axis_broadcast(template::AbstractArray, vec::AbstractVector, axis::Int) → AbstractArray

Build a singleton-padded ND array suitable for broadcasting `vec` against
arrays shaped like `template` along `axis`. CPU path returns a zero-copy
`reshape` of `vec`; GPU path copies `vec` to the device once (backed by
the shared scratch registry under `:axis_broadcast`) then reshapes. Used
wherever a 1D coordinate / wavenumber array needs to broadcast against
an N-D spatial array — Coriolis gradient term, 1D-shear substep, etc.
"""
function _axis_broadcast(template::AbstractArray, vec::AbstractVector, axis::Int)
    N = ndims(template)
    shape = ntuple(d -> d == axis ? length(vec) : 1, N)
    if template isa Array
        return reshape(vec, shape)
    else
        dev = scratch_get!(
            :axis_broadcast,
            (typeof(template), eltype(vec), length(vec), objectid(vec)),
        ) do
            buf = similar(template, eltype(vec), length(vec))
            copyto!(buf, vec)
            buf
        end
        return reshape(dev, shape)
    end
end

"""
    _randn_fill!(backend, arr::AbstractArray{<:Real}, rng) -> arr

Fill `arr` with 𝒩(0,1) draws. The CPU path is `Random.randn!(rng, arr)`, which
consumes `rng` in exactly the same order as `randn(rng, T, size(arr))` — so
existing seeded streams are unchanged.

The CUDA extension overloads this to draw **on the device** (CURAND). That path
ignores `rng`: the device stream is seeded once per process/trajectory via
[`seed_device_rng!`](@ref), not per call. Per-step host draws were the dominant
cost of every stochastic sub-step (measured 14.7 ms of a 15.1 ms SGPE step at
48³/D=3 — 33× the unitary split-step) because each one allocates a host array
and pushes it over PCIe; on-device draws make second-scale stochastic runs
tractable.
"""
_randn_fill!(::CPUBackend, arr::AbstractArray{<:Real}, rng) = Random.randn!(rng, arr)

"""
    seed_device_rng!(backend, seed) -> Nothing

Seed the backend's RNG stream. CPU is a no-op (callers pass an explicit `rng`);
CUDA seeds CURAND so a trajectory is reproducible end-to-end. Reproducibility on
GPU is therefore **per trajectory**, not per step.
"""
seed_device_rng!(::CPUBackend, ::Integer) = nothing

function _resolve_backend(name::Symbol)
    name === :cpu && return CPUBackend()
    name === :gpu && return CUDABackend()
    name === :cuda && throw(
        ArgumentError(
            "backend: `:cuda` was renamed to `:gpu` (alias removed 2026-05-24). " *
            "Update YAML / Julia callers to `backend: gpu`."),
    )
    throw(ArgumentError("Unknown backend: $name (expected :cpu or :gpu)"))
end
