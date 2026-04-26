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
    add_thermal_noise!(psi, F; T_over_Tc, transverse_only, seed) → psi

Add Gaussian random noise to the wavefunction to seed thermal fluctuations.

This breaks the spin-rotational symmetry of a polarized state, allowing
ITP to find non-trivial spin textures via spontaneous symmetry breaking.

# Arguments
- `psi`: spinor wavefunction (modified in place)
- `F`: total spin quantum number
- `T_over_Tc`: target temperature ratio T/T_c (default 0.1, ~18 nK at T_c=180 nK)
- `transverse_only`: if true, only add noise to non-polarized components
  (preserves the dominant component, only seeds spin-flip excitations)
- `seed`: RNG seed

The noise amplitude is set so that |δψ|/|ψ| ≈ ((T/T_c)³/4)^{1/2}.
For T/T_c = 0.1 → η ≈ 1.6%; for T/T_c = 0.2 → η ≈ 4.5%.

After adding noise, the wavefunction is renormalized to preserve total density.

# Physical interpretation
This is a minimal classical-field-method initialization: instead of full
truncated Wigner with Bogoliubov modes, we add Gaussian noise on the
spin transverse modes only. Sufficient to break Z-axis rotational symmetry.
"""
function add_thermal_noise!(
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
    add_thermal_noise(psi, F; kwargs...) → psi_noisy

Non-mutating version of `add_thermal_noise!`.
"""
function add_thermal_noise(psi::AbstractArray{<:Complex}, F::Int; kwargs...)
    psi_copy = copy(psi)
    add_thermal_noise!(psi_copy, F; kwargs...)
    psi_copy
end

"""
    add_symmetry_breaking_seed!(psi, F; amplitude, seed) → psi

Add a tiny perturbation to the nearest transverse spin component (Δm=±1)
to seed dynamical instabilities (e.g. EdH effect).

Only the m=F-1 (or m=-F+1 for AFM) component receives noise.
Amplitude is relative to max|ψ|.  After seeding, the wavefunction is
renormalized to preserve total density.

Typical usage: `amplitude = 1e-6` for symmetry breaking without
injecting macroscopic energy.
"""
function add_symmetry_breaking_seed!(
    psi::AbstractArray{<:Complex},
    F::Int;
    amplitude::Float64=1e-6,
    seed::Int=42,
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
