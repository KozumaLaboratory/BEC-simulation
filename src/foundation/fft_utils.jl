# `_fft_partial_derivative` and `_fft_gradient` are CPU-only analysis
# helpers: they materialise host `Array{ComplexF64}` buffers and copy
# the input into them, then run FFT-multiply-IFFT to get a spatial
# derivative on the host. Pre-2026-06-02 they accepted a `plans::FFTPlans`
# argument; callers that passed a GPU workspace's `ws.fft_plans` (which
# is CUFFT) triggered massive implicit GPU↔host transfers on every
# `plans.forward * buf` — the same 30 GB OOM class fixed in
# `orbital_angular_momentum`. We now always build a CPU plan inside the
# function. The `plans` parameter is retained for source-compat but
# ignored.

"""
Compute ∂f/∂x_dim of an N-D real `f` via FFT-multiply-IFFT. CPU-only
(allocates host buffers internally); pass any `plans::FFTPlans` for
source-compat — the function builds its own CPU plan keyed on
`(eltype, size)` via the shared scratch registry, eliminating the
30 GB GPU↔host implicit-transfer OOM class.
"""
function _fft_partial_derivative(
    f::AbstractArray{Float64, N},
    grid::Grid{N},
    plans::FFTPlans,
    dim::Int,
) where {N}
    n_pts = size(f)
    buf = scratch_get!(:fft_deriv_buf, (Array{ComplexF64, N}, n_pts)) do
        Array{ComplexF64, N}(undef, n_pts)
    end
    local_plans = scratch_get!(:fft_deriv_plan, (Array{ComplexF64, N}, n_pts)) do
        make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
    end
    buf .= f
    local_plans.forward * buf
    @inbounds for I in CartesianIndices(n_pts)
        buf[I] = im * grid.k[dim][I[dim]] * buf[I]
    end
    local_plans.inverse * buf
    result = Array{Float64, N}(undef, n_pts)
    @inbounds for I in CartesianIndices(n_pts)
        result[I] = real(buf[I])
    end
    result
end

"""
Compute the full FFT-gradient `(∂f/∂x_1, …, ∂f/∂x_N)` of an N-D real
`f`. Returns an `NTuple{N, Array{Float64, N}}`. Single forward FFT
shared across components. CPU-only (same caveat as
`_fft_partial_derivative`).
"""
function _fft_gradient(
    f::AbstractArray{Float64, N},
    grid::Grid{N},
    plans::FFTPlans,
) where {N}
    n_pts = size(f)
    f_k = scratch_get!(:fft_grad_fk, (Array{ComplexF64, N}, n_pts)) do
        Array{ComplexF64, N}(undef, n_pts)
    end
    buf = scratch_get!(:fft_grad_buf, (Array{ComplexF64, N}, n_pts)) do
        Array{ComplexF64, N}(undef, n_pts)
    end
    local_plans = scratch_get!(:fft_deriv_plan, (Array{ComplexF64, N}, n_pts)) do
        make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
    end
    f_k .= f
    local_plans.forward * f_k

    ntuple(N) do dim
        @inbounds for I in CartesianIndices(n_pts)
            buf[I] = im * grid.k[dim][I[dim]] * f_k[I]
        end
        local_plans.inverse * buf
        result = Array{Float64, N}(undef, n_pts)
        @inbounds for I in CartesianIndices(n_pts)
            result[I] = real(buf[I])
        end
        result
    end
end
