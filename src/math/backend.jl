struct CPUBackend <: AbstractBackend end
struct CUDABackend <: AbstractBackend end

_zeros(::CPUBackend, T::Type, dims...) = zeros(T, dims...)
_similar(::CPUBackend, arr::AbstractArray) = similar(arr)
_similar(::CPUBackend, arr::AbstractArray, T::Type, dims...) = similar(arr, T, dims...)
_to_device(::CPUBackend, arr) = arr
_to_host(arr::Array) = arr
_to_host(arr::AbstractArray) = Array(arr)
_fft_kwargs(::CPUBackend, flags) = (; flags = flags)

_is_gpu(::Array) = false
_is_gpu(::AbstractArray) = true
