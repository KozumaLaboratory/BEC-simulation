function _analyze_rosensweig_pattern(psi, grid, atom, params, ws_prev)
    # Detect a hexagonal / striped DDI-driven Rosensweig pattern by
    # locating the dominant non-zero |k| peak in the column-density
    # (or in-plane) power spectrum. Returns:
    #   peak_k          — wavenumber of the dominant ring (1/a_ho)
    #   lambda_peak     — 2π / peak_k (a_ho)
    #   pattern_strength — peak_power / mean(non-low-k power);
    #                     >>1 means a sharp ring, ~1 means structureless
    #   n_petals        — angular fold count estimated from the
    #                     azimuthal FFT of the |k| ≈ peak_k ring
    # Works on 2D ψ directly or on the column density of a 3D ψ
    # (axis controls which spatial axis is integrated). `k_min` (a_ho⁻¹)
    # skips the long-wavelength bins where the trap-confined cloud
    # envelope smears spectral weight.
    ndim = length(grid.config.n_points)
    ndim >= 2 || throw(ArgumentError("rosensweig_pattern requires N >= 2"))
    n_total = total_density(psi, ndim)
    plane = if ndim == 3
        axis = Int(get(params, "axis", 3))
        dropdims(sum(n_total; dims=axis); dims=axis)
    else
        n_total
    end
    nx, ny = size(plane)
    # Center & FFT. Subtract the spatial mean so the DC bin doesn't
    # drown the peak; the envelope still leaks into the bottom few k
    # bins, which `k_min` filters out below.
    plane_c = plane .- (sum(plane) / length(plane))
    spec = abs2.(fft(plane_c))
    kvecs = grid.k
    kx = kvecs[1]
    ky = kvecs[2]
    n_bins = Int(get(params, "n_radial_bins", min(nx, ny) ÷ 2))
    k_max = max(maximum(abs, kx), maximum(abs, ky))
    bin_w = k_max / n_bins
    radial_power = zeros(Float64, n_bins)
    radial_count = zeros(Int, n_bins)
    for j in 1:ny, i in 1:nx
        kr = sqrt(kx[i]^2 + ky[j]^2)
        b = clamp(round(Int, kr / bin_w) + 1, 1, n_bins)
        radial_power[b] += spec[i, j]
        radial_count[b] += 1
    end
    for b in 1:n_bins
        radial_count[b] > 0 && (radial_power[b] /= radial_count[b])
    end
    # Skip the lowest k bins where the cloud envelope's finite size
    # smears spectral weight (default: k < 1.0/a_ho — a few bins on a
    # box ~ 16 a_ho). Caller can tune via `k_min`.
    k_min = Float64(get(params, "k_min", 1.0))
    b_lo = max(2, ceil(Int, k_min / bin_w) + 1)
    if b_lo >= n_bins
        return (peak_k=NaN, lambda_peak=Inf, pattern_strength=NaN,
            n_petals=0, radial_power=radial_power)
    end
    slice = @view radial_power[b_lo:end]
    peak_b = argmax(slice) + b_lo - 1
    peak_k = (peak_b - 1) * bin_w
    lambda_peak = peak_k > 0 ? 2π / peak_k : Inf
    # Strength = peak / mean of the searched band (excludes envelope
    # smear). Sharp ring → strength >> 1; flat spectrum → ≈ 1.
    band_mean = sum(slice) / length(slice)
    pattern_strength = band_mean > 0 ? radial_power[peak_b] / band_mean : NaN
    # Azimuthal FFT of the ring at |k|≈peak_k → angular fold count
    n_angular = Int(get(params, "n_angular", 64))
    ring = zeros(Float64, n_angular)
    for a in 1:n_angular
        θ = 2π * (a - 1) / n_angular
        kxv = peak_k * cos(θ)
        kyv = peak_k * sin(θ)
        i = argmin(abs.(kx .- kxv))
        j = argmin(abs.(ky .- kyv))
        ring[a] = spec[i, j]
    end
    ring_spec = abs.(fft(ring))
    m_max = length(ring_spec) ÷ 2
    peak_m = argmax(@view ring_spec[2:(m_max + 1)])
    n_petals = peak_m   # angular FFT mode number = rotational fold count
    (peak_k=peak_k,
        lambda_peak=lambda_peak,
        pattern_strength=pattern_strength,
        n_petals=n_petals,
        radial_power=radial_power,
        k_min=k_min)
end
