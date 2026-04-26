# --- P3.1-P3.4: Realistic detection / imaging models ---
#
# Column density → observed camera counts. Models the stack of effects that
# separate a clean |ψ|² slice from a detector readout:
#   1. Gaussian PSF convolution (finite imaging resolution)
#   2. Saturation:  OD_raw = -log((N_probe - N_obs) / N_probe)
#                   becomes non-linear at OD ≳ 2; we invert it.
#   3. Poisson shot noise on photon counts
#   4. Camera read noise (additive Gaussian, rarely dominant)
#
# All functions are pure (take a density 2D array, return a new 2D array);
# downstream analyzers (fitting, density profile extraction) receive realistic
# data without branching on whether noise is on or off.

using Random

"""
    gaussian_psf_convolve(img, grid, sigma_pixels) -> Matrix{Float64}

Blur a 2D column density with a separable Gaussian PSF of width
`sigma_pixels` (in pixel units — real-space sigma / grid spacing).
Uses two 1D FFT-based convolutions (separable kernel) for O(N·log N)
scaling.
"""
function gaussian_psf_convolve(
    img::AbstractMatrix{T}, sigma_pixels::Real
) where {T <: Real}
    sigma = Float64(sigma_pixels)
    if sigma <= 0
        return Matrix{Float64}(img)
    end
    nx, ny = size(img)
    # Truncate the kernel at 4σ — negligible contribution beyond.
    half = max(1, ceil(Int, 4 * sigma))
    xs = (-half):half
    k = exp.(-xs .^ 2 ./ (2 * sigma^2))
    k ./= sum(k)
    # Convolve rows
    out1 = zeros(Float64, nx, ny)
    @inbounds for j in 1:ny
        for i in 1:nx
            s = 0.0
            for di in (-half):half
                ii = clamp(i + di, 1, nx)
                s += Float64(img[ii, j]) * k[di + half + 1]
            end
            out1[i, j] = s
        end
    end
    # Convolve columns
    out = zeros(Float64, nx, ny)
    @inbounds for j in 1:ny
        for i in 1:nx
            s = 0.0
            for dj in (-half):half
                jj = clamp(j + dj, 1, ny)
                s += out1[i, jj] * k[dj + half + 1]
            end
            out[i, j] = s
        end
    end
    out
end

"""
    apply_shot_noise(image, photons_per_unit; seed=rand_seed) -> Matrix{Float64}

Add Poisson shot noise. `image` is interpreted as a density; `photons_per_unit`
sets how many photons the brightest pixel ~ corresponds to — scales the
Poisson mean.
"""
function apply_shot_noise(
    image::AbstractMatrix{T}, photons_per_unit::Real;
    seed::Union{Nothing, Int}=nothing,
) where {T <: Real}
    rng = seed === nothing ? Random.default_rng() : Random.MersenneTwister(seed)
    s = Float64(photons_per_unit)
    s > 0 || throw(ArgumentError("photons_per_unit must be positive"))
    out = similar(image, Float64)
    @inbounds for i in eachindex(image)
        λ = max(0.0, Float64(image[i]) * s)
        # Knuth's Poisson generator for small λ, normal approx for large λ.
        if λ > 50
            out[i] = λ + sqrt(λ) * randn(rng)
        else
            L = exp(-λ)
            k = 0;
            p = 1.0
            while p > L
                k += 1
                p *= rand(rng)
            end
            out[i] = Float64(k - 1)
        end
    end
    out
end

"""
    apply_saturation(image, OD_sat=2.0) -> Matrix{Float64}

Model the absorption-imaging saturation curve: invert
`OD = -log(T)` where `T = 1 - (counts_sat/counts_probe)`. For input
column density `n` → OD, clip OD ≤ `OD_sat` (typical dichroic camera limit).
"""
function apply_saturation(image::AbstractMatrix{T}, OD_sat::Real=2.0) where {T <: Real}
    od_cap = Float64(OD_sat)
    out = similar(image, Float64)
    @inbounds for i in eachindex(image)
        od = max(0.0, Float64(image[i]))
        out[i] = od < od_cap ? od : od_cap - 0.1 * log1p(od - od_cap)
    end
    out
end

"""
    synthesise_absorption_image(column_density, grid; sigma_pixels=0.0,
                                 photons_per_unit=0.0, OD_sat=Inf,
                                 read_noise_sigma=0.0, seed=nothing)
        -> Matrix{Float64}

End-to-end camera simulator. Chain PSF → saturation → shot noise → read noise.
Each stage is opt-in (pass `0.0` or `Inf` to skip).
"""
function synthesise_absorption_image(
    column_density::AbstractMatrix, grid::Grid{N};
    sigma_pixels::Real=0.0,
    photons_per_unit::Real=0.0,
    OD_sat::Real=Inf,
    read_noise_sigma::Real=0.0,
    seed::Union{Nothing, Int}=nothing,
) where {N}
    img = if sigma_pixels > 0
        gaussian_psf_convolve(column_density, sigma_pixels)
    else
        Matrix{Float64}(column_density)
    end
    isfinite(OD_sat) && (img = apply_saturation(img, OD_sat))
    photons_per_unit > 0 && (img = apply_shot_noise(img, photons_per_unit; seed))
    if read_noise_sigma > 0
        rng = seed === nothing ? Random.default_rng() :
              Random.MersenneTwister(seed + 1)
        σ = Float64(read_noise_sigma)
        @inbounds for i in eachindex(img)
            img[i] += σ * randn(rng)
        end
    end
    img
end

# --- P3.2: Phase-contrast / polarization-resolved imaging ---

"""
    faraday_polarization_components(psi, grid, F; params=FaradayParams()) ->
        (sig_plus, sig_minus, linear_x, linear_y)

Decompose the Faraday signal into its four polarization components. The
existing `faraday_image` collapses these into a single rotation angle —
here we expose each polarization channel separately for diagnostic /
calibration purposes.

Convention follows Kawaguchi-Ueda §13.2:
    σ±: projection onto ψ_{±1} in an Fy-polarized probe
    linear_x, linear_y: real and imaginary parts of the raw M_F signal
"""
function faraday_polarization_components(
    psi, grid::Grid{N}, F::Int; params::FaradayParams=FaradayParams()
) where {N}
    img_x = faraday_image(psi, grid, F;
        params=FaradayParams(params.probe_axis,
            params.detuning, :linear_x,
            params.include_vector_shift))
    img_y = faraday_image(psi, grid, F;
        params=FaradayParams(params.probe_axis,
            params.detuning, :linear_y,
            params.include_vector_shift))
    img_c = faraday_image(psi, grid, F;
        params=FaradayParams(params.probe_axis,
            params.detuning, :circular,
            params.include_vector_shift))
    (
        sigma_plus=0.5 .* (img_c.rotation_angle .+ img_x.rotation_angle),
        sigma_minus=0.5 .* (img_c.rotation_angle .- img_x.rotation_angle),
        linear_x=img_x.rotation_angle,
        linear_y=img_y.rotation_angle,
        column_density=img_x.column_density,
    )
end

# --- P3.4: Faraday SNR with realistic photon noise ---

"""
    faraday_snr(psi, grid, F; N_photons_per_pixel, params=FaradayParams(), seed=nothing)
        → (signal, noise, snr)

Estimate the per-pixel Faraday SNR. Signal is the mean rotation angle; noise
is the shot-noise floor `σ_φ = 1 / (2 √N_photons)` (standard interferometric
limit). Returns per-pixel matrices of signal, noise, SNR.
"""
function faraday_snr(
    psi, grid::Grid{N}, F::Int;
    N_photons_per_pixel::Real,
    params::FaradayParams=FaradayParams(),
    seed::Union{Nothing, Int}=nothing,
) where {N}
    img = faraday_image(psi, grid, F; params)
    signal = img.rotation_angle
    Nph = Float64(N_photons_per_pixel)
    # Shot-noise floor per pixel for a balanced polarimeter.
    noise = fill(1.0 / (2 * sqrt(Nph)), size(signal))
    snr = @. abs(signal) / noise
    (signal=signal, noise=noise, snr=snr, column_density=img.column_density)
end

# --- P3.6: Long-TOF momentum distribution ---

"""
    momentum_distribution(psi, grid; t_tof=10.0, axis=3) → (k_coords, n_k)

Long-TOF limit: the cloud density in real space at time t_tof is proportional
to |ψ̃(k)|² at k = r/t_tof. This helper runs a far-field FFT and returns the
momentum-space density column-integrated along the given axis.

For intermediate TOF use `simulate_tof_with_gradient` instead.
"""
function momentum_distribution(
    psi::AbstractArray{<:Complex}, grid::Grid{N};
    t_tof::Real=10.0,
    axis::Int=N,
) where {N}
    n_pts = grid.config.n_points
    D = size(psi, N + 1)
    dV = cell_volume(grid)
    nk = prod(n_pts)
    norm_factor = dV / sqrt(Float64(nk))

    plans = make_fft_plans(n_pts)
    n_k_total = zeros(Float64, n_pts)
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        psi_c = copy(Array(view(psi, idx...)))
        psi_k = plans.forward * psi_c
        psi_k .*= norm_factor
        @. n_k_total += abs2(psi_k)
    end

    # Column integrate and return the momentum coordinates along remaining axes
    if N == 1
        return (k_coords=(grid.k[1],), n_k=n_k_total)
    end
    col = dropdims(sum(n_k_total; dims=axis); dims=axis)
    remaining_axes = Int[d for d in 1:N if d != axis]
    k_coords = ntuple(i -> grid.k[remaining_axes[i]], Val(N-1))
    (k_coords=k_coords, n_k=col)
end
