export make_grid, make_fft_plans, make_rfft_plans, rfft_output_shape
export cell_volume, n_spatial_points
export load_fftw_wisdom, save_fftw_wisdom

function make_grid(
    config::GridConfig{N};
    dtype::Type{T}=Float64,
) where {N, T <: AbstractFloat}
    x = ntuple(N) do d
        n = config.n_points[d]
        L = T(config.box_size[d])
        dx = L / n
        collect(T, range(-L / 2 + dx / 2, L / 2 - dx / 2; length=n))
    end

    dx = ntuple(d -> T(config.box_size[d] / config.n_points[d]), N)

    k = ntuple(N) do d
        n = config.n_points[d]
        L = T(config.box_size[d])
        dk = T(2π) / L
        collect(T, fftfreq(n, n * dk))
    end

    dk = ntuple(d -> T(2π / config.box_size[d]), N)

    k_squared = _compute_k_squared(k, config.n_points, T)

    Grid{N, T}(config, x, dx, k, dk, k_squared)
end

function _compute_k_squared(
    k::NTuple{N, Vector{T}},
    n_points::NTuple{N, Int},
    (::Type{T})=T,
) where {N, T <: AbstractFloat}
    ksq = zeros(T, n_points)
    @inbounds for I in CartesianIndices(n_points)
        s = zero(T)
        for d in 1:N
            s += k[d][I[d]]^2
        end
        ksq[I] = s
    end
    ksq
end

function make_fft_plans(
    spatial_shape::NTuple{N, Int},
    backend::AbstractBackend=CPUBackend();
    flags=FFTW.MEASURE,
    dtype::Type{T}=Float64,
) where {N, T <: AbstractFloat}
    buf = _zeros(backend, Complex{T}, spatial_shape...)
    kw = _fft_kwargs(backend, flags)
    fwd = plan_fft!(buf; kw...)
    inv = plan_ifft!(buf; kw...)
    FFTPlans(fwd, inv)
end

rfft_output_shape(n_pts::NTuple{N, Int}) where {N} = (n_pts[1] ÷ 2 + 1, n_pts[2:end]...)

function make_rfft_plans(
    spatial_shape::NTuple{N, Int},
    backend::AbstractBackend=CPUBackend();
    flags=FFTW.MEASURE,
    dtype::Type{T}=Float64,
) where {N, T <: AbstractFloat}
    rk_shape = rfft_output_shape(spatial_shape)
    real_buf = _zeros(backend, T, spatial_shape...)
    complex_buf = _zeros(backend, Complex{T}, rk_shape...)
    kw = _fft_kwargs(backend, flags)
    fwd = plan_rfft(real_buf; kw...)
    inv = plan_irfft(complex_buf, spatial_shape[1]; kw...)
    RFFTPlans{N, typeof(fwd), typeof(inv)}(fwd, inv, rk_shape)
end

function cell_volume(grid::Grid{N}) where {N}
    prod(grid.dx)
end

function n_spatial_points(grid::Grid{N}) where {N}
    prod(grid.config.n_points)
end

function load_fftw_wisdom(path::AbstractString)
    isfile(path) && FFTW.import_wisdom(path)
end

function save_fftw_wisdom(path::AbstractString)
    FFTW.export_wisdom(path)
end
