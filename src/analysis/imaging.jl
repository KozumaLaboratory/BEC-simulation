# --- P3.1-P3.4: Realistic detection / imaging models ---
#
# Column density → observed camera counts. Models the stack of effects that
# separate a clean |ψ|² slice from a detector readout:
#   1. Gaussian PSF convolution (finite imaging resolution)

export gaussian_psf_convolve, apply_shot_noise, apply_saturation
export synthesise_absorption_image, faraday_polarization_components
export apply_sg_overlap, apply_fringe_noise!, synthesise_image_ensemble
export pixel_bin, imaging_forward, image_multiframe
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

# --- Physical-units forward model: density → camera image ---
#
# `gaussian_psf_convolve` / `apply_saturation` / `apply_shot_noise` above act on
# a 2D column density already in pixel units. The forward model below closes the
# gap from a reconstructed N-D LAB density (e.g. `recombine_density`,
# `far_field_density`, or a raw |ψ|² slice) to what the camera records:
#   3D density --(line-of-sight integral, physical dr)--> 2D column density
#             --(σ_abs)--> optical depth --(PSF, physical σ)--> blurred
#             --(saturation)--> --(camera pixel binning)--> --(noise)--> image.
# Pixel binning (magnification × camera pixel pitch) is the genuinely new piece;
# the rest composes the existing chain in physical units.

"""
    pixel_bin(img, fine_dx, pixel_size; combine=:mean)
        -> (image, bin, pixel_dx)

Bin a fine 2D image onto camera pixels. `fine_dx=(dx,dy)` is the simulation-grid
spacing; `pixel_size` (scalar or `(px,py)`) is the camera pixel pitch in the same
physical units (after magnification). The bin factor per axis is
`round(pixel_size/fine_dx)` (≥1); the image is cropped to a whole number of
pixels. `combine=:mean` keeps density / OD units (downsample); `:sum` gives
per-pixel counts. Number is conserved either way: `Σ image · prod(pixel_dx)`
(`:mean`) or `Σ image · prod(fine_dx)` (`:sum`) equals the fine-grid total.
"""
function pixel_bin(img::AbstractMatrix{<:Real}, fine_dx::NTuple{2, <:Real},
    pixel_size; combine::Symbol=:mean)
    combine in (:mean, :sum) || throw(ArgumentError("combine must be :mean or :sum"))
    ps = if pixel_size isa Tuple
        (Float64(pixel_size[1]), Float64(pixel_size[2]))
    else
        (Float64(pixel_size), Float64(pixel_size))
    end
    nx, ny = size(img)
    bx = max(1, round(Int, ps[1] / fine_dx[1]))
    by = max(1, round(Int, ps[2] / fine_dx[2]))
    nbx, nby = nx ÷ bx, ny ÷ by
    (nbx >= 1 && nby >= 1) ||
        throw(ArgumentError("pixel_size $ps too large for grid spacing $fine_dx"))
    out = zeros(Float64, nbx, nby)
    @inbounds for J in 1:nby, I in 1:nbx
        s = 0.0
        for jj in 1:by, ii in 1:bx
            s += Float64(img[(I - 1) * bx + ii, (J - 1) * by + jj])
        end
        out[I, J] = combine === :sum ? s : s / (bx * by)
    end
    (image=out, bin=(bx, by), pixel_dx=(bx * fine_dx[1], by * fine_dx[2]))
end

# block-mean of a coordinate axis (pixel centers from fine-grid coords)
function _bin_coords(xs::AbstractVector, b::Int, nb::Int)
    [sum(@view xs[((I - 1) * b + 1):(I * b)]) / b for I in 1:nb]
end

"""
    imaging_forward(density, grid; imaging_axis=N, psf_sigma=0, pixel_size=0,
        sigma_abs=0, OD_sat=Inf, photons_per_unit=0, read_noise_sigma=0, seed)
        -> (image, x, y, pixel_dx, bin)

Camera forward model for a 2D or 3D real density. A 3D density is line-of-sight
integrated along `imaging_axis` (physical dr) to a 2D column density; a 2D
density is taken as the image directly. Then: optional optical depth
`OD = sigma_abs · n_col`; Gaussian PSF of PHYSICAL width `psf_sigma` (requires
isotropic in-plane spacing); `apply_saturation(OD_sat)`; camera `pixel_bin`;
optional shot + read noise. Each stage is opt-in (0 / Inf skips it). Returns the
image and physical pixel-center coordinates.
"""
function imaging_forward(density::AbstractArray{<:Real, N}, grid::Grid{N};
    imaging_axis::Int=N, psf_sigma::Real=0.0, pixel_size::Real=0.0,
    sigma_abs::Real=0.0, OD_sat::Real=Inf, photons_per_unit::Real=0.0,
    read_noise_sigma::Real=0.0, seed::Union{Nothing, Int}=nothing) where {N}
    if N == 3
        1 <= imaging_axis <= 3 ||
            throw(ArgumentError("imaging_axis=$imaging_axis out of range"))
        col = dropdims(sum(density; dims=imaging_axis); dims=imaging_axis) .*
              grid.dx[imaging_axis]
        inplane = Tuple(d for d in 1:3 if d != imaging_axis)
    elseif N == 2
        col = Matrix{Float64}(density)
        inplane = (1, 2)
    else
        throw(ArgumentError("imaging_forward needs a 2D or 3D density (got $(N)D)"))
    end
    dx_ip = (grid.dx[inplane[1]], grid.dx[inplane[2]])
    img = Matrix{Float64}(col)
    sigma_abs > 0 && (img = Float64(sigma_abs) .* img)
    if psf_sigma > 0
        isapprox(dx_ip[1], dx_ip[2]; rtol=1e-6) || throw(ArgumentError(
            "psf_sigma needs isotropic in-plane spacing; got $dx_ip"))
        img = gaussian_psf_convolve(img, Float64(psf_sigma) / dx_ip[1])
    end
    isfinite(OD_sat) && (img = apply_saturation(img, OD_sat))
    x_ip, y_ip = collect(grid.x[inplane[1]]), collect(grid.x[inplane[2]])
    bin = (1, 1)
    pdx = dx_ip
    if pixel_size > 0
        pb = pixel_bin(img, dx_ip, pixel_size)
        img, bin, pdx = pb.image, pb.bin, pb.pixel_dx
        x_ip = _bin_coords(x_ip, bin[1], size(img, 1))
        y_ip = _bin_coords(y_ip, bin[2], size(img, 2))
    end
    photons_per_unit > 0 && (img = apply_shot_noise(img, photons_per_unit; seed))
    if read_noise_sigma > 0
        rng = seed === nothing ? Random.default_rng() :
              Random.MersenneTwister(seed + 1)
        img = img .+ Float64(read_noise_sigma) .* randn(rng, size(img))
    end
    (image=img, x=x_ip, y=y_ip, pixel_dx=pdx, bin=bin)
end

"""
    image_multiframe(state; lab_grid=state.grid, imaging_axis=N, kwargs...)

Camera image of a multi-frame TOF state: reconstruct the physical lab density
(`recombine_density`, coherent within / incoherent across internal states) and
run `imaging_forward`. `lab_grid` chooses the reconstruction grid; remaining
kwargs (`psf_sigma`, `pixel_size`, `sigma_abs`, `OD_sat`, noise) pass through.
"""
function image_multiframe(state::MultiFrameTOFState{N};
    lab_grid::Grid{N}=state.grid, imaging_axis::Int=N, kwargs...) where {N}
    dens = recombine_density(state; lab_grid=lab_grid)
    imaging_forward(dens, lab_grid; imaging_axis=imaging_axis, kwargs...)
end

# --- SG overlap + σ_eff(m) weighted composition ---
#
# `simulate_tof` and `simulate_tof_with_gradient` return Dict{Int, Matrix} of
# per-m column densities, each already shifted to the SG-displaced position
# (via integer circshift in the far-field path or real-time evolution with the
# magnetic gradient). The composite image observed by the camera is the
# σ_eff(m)-weighted sum, broadened by the residual momentum-distribution
# width (initial cloud momentum width × t_tof) which sets the per-m Gaussian
# kernel σ_SG. When adjacent m clouds have centres separated by less than
# σ_SG, they overlap in the observed image — this is what `apply_sg_overlap`
# models.

"""
    apply_sg_overlap(components, sigma_sg_pixels; sigma_eff=nothing) -> Matrix{Float64}

Compose the camera-side OD image from per-m component column densities.

- `components::Dict{Int, <:AbstractMatrix}`: output of `simulate_tof` or
  `simulate_tof_with_gradient`, keyed by m.
- `sigma_sg_pixels::Real`: Gaussian broadening (pixels) applied per component
  to model finite initial momentum spread × TOF. `0` disables broadening.
- `sigma_eff::Union{Nothing, Dict{Int, Float64}}`: per-m σ_eff weight (output
  of `build_sigma_eff_table` keyed by m); `nothing` ⇒ uniform σ_eff = 1.

Returns the composite OD `Σ_m σ_eff(m) · Gaussian_σ_SG ⊗ Σ_m(x, y)`.
"""
function apply_sg_overlap(
    components::Dict{<:Integer, <:AbstractArray},
    sigma_sg_pixels::Real;
    sigma_eff::Union{Nothing, Dict{<:Integer, <:Real}}=nothing,
)
    isempty(components) && throw(ArgumentError("components must be non-empty"))
    ms = sort(collect(keys(components)))
    ref = components[ms[1]]
    ndims(ref) == 2 || throw(
        ArgumentError(
            "apply_sg_overlap currently supports 2D component images (got $(ndims(ref))D). " *
            "For a 1D SG output use a 3D source grid with imaging_axis=3."),
    )
    nx, ny = size(ref)
    composite = zeros(Float64, nx, ny)
    σ = Float64(sigma_sg_pixels)
    @inbounds for m in ms
        c = components[m]
        ndims(c) == 2 && size(c) == (nx, ny) ||
            throw(DimensionMismatch("components[$m] shape $(size(c)) ≠ ($(nx), $(ny))"))
        c2d = reshape(c, nx, ny)  # ensure AbstractMatrix view for gaussian_psf_convolve
        broadened = σ > 0 ? gaussian_psf_convolve(c2d, σ) : Matrix{Float64}(c2d)
        weight = sigma_eff === nothing ? 1.0 :
                 Float64(get(sigma_eff, m, 1.0))
        composite .+= weight .* broadened
    end
    composite
end

# --- Fringe noise + 116-shot ensemble ---
#
# Absorption imaging shot-to-shot reproducibility is limited by interference
# fringes from probe-beam wavefront drift. These fringes are typically rank-K
# patterns (PCA basis of K ≲ 10 modes) with shot-to-shot Gaussian amplitudes.
# Averaging N ~ 100 shots suppresses fringe variance as 1/N. SBI likelihoods
# must distinguish the iid component (Poisson + readout, also ∝ 1/N) from the
# shot-correlated fringe component (whose pixel covariance is low-rank rather
# than diagonal).

"""
    apply_fringe_noise!(image, fringe_basis, fringe_sigmas; seed=nothing) -> image

Add a single random fringe realization to `image` in-place. `fringe_basis` is
`(nx, ny, K)` with K orthonormal patterns; `fringe_sigmas` is length-K giving
the per-mode RMS amplitude. Each shot draws K independent Gaussian
amplitudes a_k ~ N(0, σ_k²) and adds `Σ_k a_k φ_k`.
"""
function apply_fringe_noise!(
    image::AbstractMatrix,
    fringe_basis::AbstractArray{<:Real, 3},
    fringe_sigmas::AbstractVector{<:Real};
    seed::Union{Nothing, Int}=nothing,
)
    K = length(fringe_sigmas)
    size(fringe_basis, 3) == K ||
        throw(DimensionMismatch("fringe_basis depth $(size(fringe_basis, 3)) ≠ K=$K"))
    size(fringe_basis)[1:2] == size(image) ||
        throw(DimensionMismatch("fringe_basis spatial dims ≠ image dims"))
    rng = seed === nothing ? Random.default_rng() : Random.MersenneTwister(seed)
    @inbounds for k in 1:K
        a = Float64(fringe_sigmas[k]) * randn(rng)
        @views image .+= a .* fringe_basis[:, :, k]
    end
    image
end

"""
    synthesise_image_ensemble(clean, grid; n_shots, ..., seed=nothing)
        -> (mean=Matrix, var=Matrix)

Generate `n_shots` independent realizations of the noise chain
(PSF → saturation → Poisson photons → readout → optional fringe) and return
the per-pixel mean and sample variance (Welford accumulator).

Single-shot ⇒ variance is zero. Use `n_shots = 116` to match the Matsui 2026
EdH protocol averaging.
"""
function synthesise_image_ensemble(
    clean::AbstractMatrix, grid::Grid{N};
    sigma_pixels::Real=0.0,
    photons_per_unit::Real=0.0,
    OD_sat::Real=Inf,
    read_noise_sigma::Real=0.0,
    fringe_basis::Union{Nothing, AbstractArray{<:Real, 3}}=nothing,
    fringe_sigmas::Union{Nothing, AbstractVector{<:Real}}=nothing,
    n_shots::Int=1,
    seed::Union{Nothing, Int}=nothing,
) where {N}
    n_shots >= 1 || throw(ArgumentError("n_shots must be ≥ 1"))
    sz = size(clean)
    mean_img = zeros(Float64, sz)
    M2 = zeros(Float64, sz)
    for shot in 1:n_shots
        seed_shot = seed === nothing ? nothing : seed + 1000 * shot
        img = synthesise_absorption_image(clean, grid;
            sigma_pixels, photons_per_unit, OD_sat,
            read_noise_sigma, seed=seed_shot)
        if fringe_basis !== nothing && fringe_sigmas !== nothing
            seed_fringe = seed_shot === nothing ? nothing : seed_shot + 1
            apply_fringe_noise!(img, fringe_basis, fringe_sigmas; seed=seed_fringe)
        end
        delta = img .- mean_img
        mean_img .+= delta ./ shot
        M2 .+= delta .* (img .- mean_img)
    end
    var_img = n_shots > 1 ? M2 ./ (n_shots - 1) : zeros(Float64, sz)
    (mean=mean_img, var=var_img)
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
