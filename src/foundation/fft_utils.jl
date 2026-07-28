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
    # Null the Nyquist mode: ik is aliased/ill-defined at k=±N/2 for even N, so it
    # emits a checkerboard artifact in odd (first) derivatives. Standard convention.
    nyq = iseven(n_pts[dim]) ? n_pts[dim] ÷ 2 + 1 : 0
    @inbounds for I in CartesianIndices(n_pts)
        buf[I] = I[dim] == nyq ? zero(ComplexF64) : im * grid.k[dim][I[dim]] * buf[I]
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
        nyq = iseven(n_pts[dim]) ? n_pts[dim] ÷ 2 + 1 : 0   # null Nyquist (see above)
        @inbounds for I in CartesianIndices(n_pts)
            buf[I] = I[dim] == nyq ? zero(ComplexF64) : im * grid.k[dim][I[dim]] * f_k[I]
        end
        local_plans.inverse * buf
        result = Array{Float64, N}(undef, n_pts)
        @inbounds for I in CartesianIndices(n_pts)
            result[I] = real(buf[I])
        end
        result
    end
end

"""
    _null_nyquist_modes!(psi, grid) -> psi

Zero the Nyquist Fourier mode (k=±N/2 along each even spatial dim) of every
spinor component, then renormalise. Removes the checkerboard-generating Nyquist
content that L-BFGS / Newton (which do NOT re-dealias) can accumulate in ψ. The
split-step dealias already strips it during ITP, so this is a no-op there. Kills
the artifact at the SOURCE (ψ), complementing the derivative-level Nyquist null.
"""
function _null_nyquist_modes!(psi::AbstractArray{<:Complex}, grid::Grid{N}) where {N}
    n_spatial = ntuple(d -> size(psi, d), N)
    D = size(psi, N + 1)
    nrm0 = sqrt(sum(abs2, psi))
    buf = Array{ComplexF64, N}(undef, n_spatial)
    local_plans = make_fft_plans(n_spatial; flags=FFTW.ESTIMATE)
    for c in 1:D
        comp = @view psi[ntuple(_ -> Colon(), N)..., c]
        buf .= comp
        local_plans.forward * buf
        @inbounds for d in 1:N
            iseven(n_spatial[d]) || continue
            nyq = n_spatial[d] ÷ 2 + 1
            for I in CartesianIndices(n_spatial)
                I[d] == nyq && (buf[I] = zero(ComplexF64))
            end
        end
        local_plans.inverse * buf
        comp .= buf
    end
    nrm1 = sqrt(sum(abs2, psi))
    nrm1 > 0 && (psi .*= nrm0 / nrm1)
    psi
end
