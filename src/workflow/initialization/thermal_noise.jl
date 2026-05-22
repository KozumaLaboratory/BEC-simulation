export add_thermal_seed!, add_thermal_seed
export add_thermal_noise!, add_thermal_noise         # backward-compat aliases
export thermal_noise_amplitude, bec_critical_temperature
export add_symmetry_breaking_seed!, add_deterministic_mode_seed!

"""
    bec_critical_temperature(N, omega_geometric_mean) → T_c (Kelvin)

BEC critical temperature for an ideal gas in a 3D harmonic trap:
    T_c = ℏω̄ (N / ζ(3))^{1/3} / k_B

where ω̄ is the geometric mean of trap frequencies and ζ(3) ≈ 1.202.
"""
function bec_critical_temperature(N::Int, omega_geometric_mean::Float64)
    zeta_3 = 1.2020569031595942
    Units.HBAR * omega_geometric_mean * (N / zeta_3)^(1 / 3) / Units.KB
end

"""
    thermal_noise_amplitude(T_over_Tc) → η

Inverse of (T/T_c) ≈ 1.59 η^{2/3}, the noise amplitude needed to seed
thermal fluctuations corresponding to a target temperature ratio.

    η ≈ (T/T_c)^{3/2} / (4)^{1/2} / (some prefactor)

Solving T/T_c = (4η²)^{1/3}:  η = ((T/T_c)^3 / 4)^{1/2}
"""
function thermal_noise_amplitude(T_over_Tc::Float64)
    sqrt(T_over_Tc^3 / 4)
end

"""
    add_thermal_seed!(psi, F; T_over_Tc, transverse_only, seed) → psi

Heuristic symmetry-breaking kick: add small Gaussian noise to the wavefunction
to seed spin-rotational symmetry breaking before / during ITP.

> **This is a heuristic seed, NOT a true classical-field thermal initialisation.**
> The amplitude `η = √((T/T_c)³ / 4)` is dimensional-scaling shorthand without
> a derivation, and the per-component weight `exp(-|c - c_dom|/2)` is
> hand-tuned for ferromagnetic / polar GS scenarios. For a true thermal
> Wigner sample (Bogoliubov-weighted occupations on each k-mode), use the
> SGPE callback (`apply_sgpe_step!`) followed by a measurement window —
> see `test_sgpe_fdr.jl` for the FDR contract.

The backward-compat alias `add_thermal_noise!` is preserved so existing callers
keep working; new code should use `add_thermal_seed!`.

# Arguments
- `psi`: spinor wavefunction (modified in place)
- `F`: total spin quantum number
- `T_over_Tc`: target temperature ratio T/T_c (default 0.1, ~18 nK at T_c=180 nK)
- `transverse_only`: if true, only add noise to non-polarized components
  (preserves the dominant component, only seeds spin-flip excitations)
- `seed`: RNG seed

After adding noise, the wavefunction is renormalized to preserve total density.

# When to reach for this
Useful as a 1-line "kick the GS off the high-symmetry axis" before ITP
finds the FL / cyclic / nematic phase. For quench dynamics (Kibble-Zurek)
or thermal-state preparation, prefer SGPE.
"""
function add_thermal_seed!(
    psi::AbstractArray{<:Complex},
    F::Int;
    T_over_Tc::Float64=0.1,
    transverse_only::Bool=true,
    seed::Int=42,
)
    D = 2F + 1
    ndim = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    eta = thermal_noise_amplitude(T_over_Tc)

    rng = Random.MersenneTwister(seed)

    original_norm = sqrt(sum(abs2, psi))

    psi_max = maximum(abs, psi)
    noise_scale = eta * psi_max

    noise = zeros(ComplexF64, size(psi))

    if transverse_only
        dominant_c = 1
        dominant_norm = 0.0
        for c in 1:D
            idx = _component_slice(ndim, n_pts, c)
            n_c = sum(abs2, view(psi, idx...))
            if n_c > dominant_norm
                dominant_norm = n_c
                dominant_c = c
            end
        end

        for c in 1:D
            c == dominant_c && continue
            delta_m = abs(c - dominant_c)
            weight = exp(-delta_m / 2)
            idx = _component_slice(ndim, n_pts, c)
            v = view(noise, idx...)
            @inbounds for I in eachindex(v)
                v[I] = weight * noise_scale * (randn(rng) + 1im * randn(rng)) / sqrt(2)
            end
        end
    else
        @inbounds for I in eachindex(noise)
            noise[I] = noise_scale * (randn(rng) + 1im * randn(rng)) / sqrt(2)
        end
    end

    noise_buf = similar(psi)
    copyto!(noise_buf, noise)
    psi .+= noise_buf

    total_norm = sqrt(sum(abs2, psi))
    if total_norm > 0 && original_norm > 0
        psi .*= (original_norm / total_norm)
    end
    psi
end

"""
    add_thermal_seed(psi, F; kwargs...) → psi_noisy

Non-mutating version of [`add_thermal_seed!`](@ref). The backward-compat alias
`add_thermal_noise` is preserved for backwards compatibility.
"""
function add_thermal_seed(psi::AbstractArray{<:Complex}, F::Int; kwargs...)
    psi_copy = copy(psi)
    add_thermal_seed!(psi_copy, F; kwargs...)
    psi_copy
end

# Legacy aliases — see add_thermal_seed!/add_thermal_seed docstrings for
# why the rename happened (the previous name implied a true thermal Wigner
# initialisation, which this function is not).
const add_thermal_noise! = add_thermal_seed!
const add_thermal_noise = add_thermal_seed

"""
    add_deterministic_mode_seed!(psi, F; k_vec, amplitude, grid, phase=0.0) → psi

Deterministic-pattern alternative to `add_symmetry_breaking_seed!`. Adds a
single plane-wave mode `amplitude * peak|ψ| * exp(i k·r + i phase)` into the
transverse spin component (m=±F-1) adjacent to the dominant one. Total
density is then re-normalised to the pre-seed value.

The seed is **grid-independent by construction**: same `k_vec` (in
dimensionless 1/a_ho units), same amplitude relative to peak|ψ|, identical
phase, deterministic — no RNG. This is the diagnostic seed used to
distinguish "noise spectrum couples to grid" from "DDI kernel resolution
is the convergence bottleneck": if `add_symmetry_breaking_seed!` fails to
grid-converge but `add_deterministic_mode_seed!` succeeds, the seed
spectrum is the culprit; if both diverge, DDI discretisation is.

`k_vec` must be a Tuple/Vector of `ndim` real numbers (the mode wavevector).
For a 3D 1/a_ho grid with box L, the smallest non-zero k is `2π/L` along
each axis. Aliasing-safe range: `|k| < π·N/L` (Nyquist) at the coarsest
grid being compared.
"""
function add_deterministic_mode_seed!(
    psi::AbstractArray{<:Complex},
    F::Int;
    k_vec,
    amplitude::Float64=1e-6,
    grid,
    phase::Float64=0.0,
)
    D = 2F + 1
    ndim = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    grid === nothing &&
        throw(ArgumentError("add_deterministic_mode_seed! requires `grid` (for x-coordinates)"))
    length(k_vec) == ndim ||
        throw(ArgumentError("k_vec length $(length(k_vec)) ≠ ndim $(ndim)"))

    original_norm = sqrt(sum(abs2, psi))
    psi_max = maximum(abs, psi)
    mode_scale = amplitude * psi_max

    dominant_c = 1
    dominant_norm = 0.0
    for c in 1:D
        idx = _component_slice(ndim, n_pts, c)
        n_c = sum(abs2, view(psi, idx...))
        if n_c > dominant_norm
            dominant_norm = n_c
            dominant_c = c
        end
    end
    target_c = dominant_c < D ? dominant_c + 1 : dominant_c - 1

    # Build plane wave exp(i k·r + i φ) on the grid coordinates.
    pattern = zeros(ComplexF64, n_pts...)
    @inbounds for I in CartesianIndices(pattern)
        kr = 0.0
        for d in 1:ndim
            kr += Float64(k_vec[d]) * grid.x[d][I.I[d]]
        end
        pattern[I] = mode_scale * exp(1im * (kr + phase))
    end

    idx = _component_slice(ndim, n_pts, target_c)
    seed_buf = similar(psi, ComplexF64, n_pts...)
    copyto!(seed_buf, pattern)
    view(psi, idx...) .+= seed_buf

    total_norm = sqrt(sum(abs2, psi))
    if total_norm > 0 && original_norm > 0
        psi .*= (original_norm / total_norm)
    end
    psi
end

"""
    add_symmetry_breaking_seed!(psi, F; amplitude, seed, k_cut, grid) → psi

Add a tiny perturbation to the nearest transverse spin component (Δm=±1)
to seed dynamical instabilities (e.g. EdH effect).

Only the m=F-1 (or m=-F+1 for AFM) component receives noise.
Amplitude is relative to max|ψ|.  After seeding, the wavefunction is
renormalized to preserve total density.

Optional **k-space lowpass**: pass `k_cut > 0` together with `grid` to
suppress white-noise spectral content above |k| = k_cut. This concentrates
the seed in the long-wavelength modes that physically drive instabilities
(e.g. the EdH spin-wave manifold below the healing-length wavenumber)
instead of exciting all bands uniformly. With `k_cut === nothing` (default)
the noise is unfiltered white.

**Amplitude semantics under k-space lowpass (changed 2026-05-22 for
grid-convergent physics):** with `k_cut`, the seed is rescaled so its
**box RMS** equals `amplitude * max|ψ|`, not its peak. Box-RMS is
grid-independent for band-limited Gaussian noise (PSD invariant in the
continuum limit), so dynamical observables converge as the grid is
refined. The previous max-rescaling concentrated power in the band as
grid refined (max_over_N pixels grew weaker for band-limited noise →
the rescaling amplified in-band modes), producing the spurious
"32 ≡ 48 ≪ 64 ≪ 96" Eu EdH ladder.
The without-k_cut branch keeps the old per-pixel amplitude semantics.

Typical usage: `amplitude = 1e-6` for symmetry breaking without
injecting macroscopic energy. For EdH, also set `k_cut ≈ 1/ξ_h` with
`ξ_h = 1/sqrt(8π n a_s)` the healing length.
"""
function add_symmetry_breaking_seed!(
    psi::AbstractArray{<:Complex},
    F::Int;
    amplitude::Float64=1e-6,
    seed::Int=42,
    k_cut::Union{Nothing, Float64}=nothing,
    grid=nothing,
)
    D = 2F + 1
    ndim = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), ndim)

    rng = Random.MersenneTwister(seed)
    original_norm = sqrt(sum(abs2, psi))
    psi_max = maximum(abs, psi)
    noise_scale = amplitude * psi_max

    dominant_c = 1
    dominant_norm = 0.0
    for c in 1:D
        idx = _component_slice(ndim, n_pts, c)
        n_c = sum(abs2, view(psi, idx...))
        if n_c > dominant_norm
            dominant_norm = n_c
            dominant_c = c
        end
    end

    target_c = dominant_c < D ? dominant_c + 1 : dominant_c - 1

    noise = zeros(ComplexF64, n_pts...)
    @inbounds for I in eachindex(noise)
        noise[I] = noise_scale * (randn(rng) + 1im * randn(rng)) / sqrt(2)
    end

    if k_cut !== nothing
        grid === nothing && throw(
            ArgumentError(
                "add_symmetry_breaking_seed!: k_cut requires `grid` to map FFT bins"),
        )
        k_cut > 0 || throw(ArgumentError(
            "add_symmetry_breaking_seed!: k_cut must be positive (got $k_cut)"))
        nhat = fft(noise)
        kvecs = grid.k
        kc2 = k_cut^2
        @inbounds for I in CartesianIndices(nhat)
            k2 = 0.0
            for d in 1:ndim
                k2 += kvecs[d][I.I[d]]^2
            end
            if k2 > kc2
                nhat[I] = 0
            end
        end
        noise = ifft(nhat)
        # Box-RMS rescale (grid-convergent for band-limited noise).
        # The continuum band-limited PSD has well-defined real-space RMS
        # independent of grid; sampling it on the lattice matches that RMS
        # in the continuum limit. Rescaling by max-over-pixels was
        # grid-dependent (peak of band-limited noise scales weaker than RMS
        # with grid count), producing the L4 Eu 32≡48≪64≪96 spurious
        # ladder. See thermal_noise docstring §"Amplitude semantics".
        box_rms = sqrt(sum(abs2, noise) / length(noise))
        if box_rms > 0
            noise .*= noise_scale / box_rms
        end
    end

    idx = _component_slice(ndim, n_pts, target_c)
    noise_buf = similar(psi, ComplexF64, n_pts...)
    copyto!(noise_buf, noise)
    view(psi, idx...) .+= noise_buf

    total_norm = sqrt(sum(abs2, psi))
    if total_norm > 0 && original_norm > 0
        psi .*= (original_norm / total_norm)
    end
    psi
end
