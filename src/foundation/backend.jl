export CPUBackend, CUDABackend

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
