SpinorBEC._zeros(::CUDABackend, T::Type, dims...) = CUDA.zeros(T, dims...)
SpinorBEC._similar(::CUDABackend, arr::CuArray) = similar(arr)
SpinorBEC._similar(::CUDABackend, arr::CuArray, T::Type, dims...) = similar(arr, T, dims...)
SpinorBEC._to_device(::CUDABackend, arr::Array) = CuArray(arr)
SpinorBEC._to_device(::CUDABackend, arr::CuArray) = arr
SpinorBEC._to_host(arr::CuArray) = Array(arr)
SpinorBEC._fft_kwargs(::CUDABackend, _) = (;)

SpinorBEC._is_gpu(::CuArray) = true
