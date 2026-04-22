"""
    add_vacuum_noise(psi, grid, F; seed=42, cutoff_energy=nothing) → psi_noisy

Add Wigner vacuum noise (½ particle per plane-wave mode per spinor component).

For each mode k and spinor component c, adds complex Gaussian noise
δψ̃_{k,c} = (η₁ + iη₂)/(2√V), where η ~ N(0,1) and V = prod(box_size).

Does NOT renormalize — TWA noise must preserve mode occupations exactly.

# Arguments
- `psi`: spinor wavefunction [x, y, ..., c]
- `grid`: simulation grid (provides k² and box_size)
- `F`: spin quantum number
- `seed`: RNG seed for reproducibility
- `cutoff_energy`: if set, skip modes with ε_k = k²/2 > cutoff_energy
"""
function add_vacuum_noise(
    psi::AbstractArray{ComplexF64},
    grid::Grid{N},
    F::Int;
    seed::Int = 42,
    cutoff_energy::Union{Nothing,Float64} = nothing,
) where {N}
    D = 2F + 1
    n_pts = ntuple(d -> size(psi, d), N)
    V = prod(grid.config.box_size)
    noise_sigma = 1.0 / (2.0 * sqrt(V))

    rng = Random.MersenneTwister(seed)
    plans = make_fft_plans(grid.config.n_points)
    psi_out = copy(psi)

    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        psi_c = Array(view(psi_out, idx...))

        psi_k = plans.forward * psi_c

        noise_k = noise_sigma .* (randn(rng, size(psi_k)...) .+ 1im .* randn(rng, size(psi_k)...))

        if cutoff_energy !== nothing
            @inbounds for I in CartesianIndices(grid.k_squared)
                if grid.k_squared[I] / 2.0 > cutoff_energy
                    noise_k[I] = zero(ComplexF64)
                end
            end
        end

        psi_k .+= noise_k
        psi_c .= plans.inverse * psi_k
        view(psi_out, idx...) .= psi_c
    end

    psi_out
end
