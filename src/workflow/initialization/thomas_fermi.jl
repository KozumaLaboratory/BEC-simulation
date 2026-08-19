export thomas_fermi_density, init_psi_thomas_fermi, init_psi_thomas_fermi_textured

"""
Thomas-Fermi density profile: n_TF(r) = max(0, (μ - V(r)) / g).
Chemical potential μ is found via bisection so that ∫n_TF dV = N_target.
"""
function thomas_fermi_density(
    V::Array{Float64, N},
    g::Float64,
    dV::Float64;
    N_target::Float64=1.0,
) where {N}
    μ = _find_chemical_potential(V, g, dV, N_target)
    n = similar(V)
    @inbounds for I in eachindex(V)
        n[I] = max(0.0, (μ - V[I]) / g)
    end
    (density=n, mu=μ)
end

function _find_chemical_potential(V, g, dV, N_target; max_iter=200, tol=1e-12)
    V_min = minimum(V)
    V_max = maximum(V)

    μ_lo = V_min
    μ_hi = V_min + (V_max - V_min) * 2.0

    while _tf_norm(V, g, dV, μ_hi) < N_target && μ_hi < V_max * 100
        μ_hi *= 2.0
    end

    for _ in 1:max_iter
        μ_mid = (μ_lo + μ_hi) / 2
        N_mid = _tf_norm(V, g, dV, μ_mid)
        if abs(N_mid - N_target) / N_target < tol
            return μ_mid
        elseif N_mid < N_target
            μ_lo = μ_mid
        else
            μ_hi = μ_mid
        end
    end
    (μ_lo + μ_hi) / 2
end

function _tf_norm(V, g, dV, μ)
    s = 0.0
    @inbounds for I in eachindex(V)
        val = μ - V[I]
        if val > 0
            s += val / g
        end
    end
    s * dV
end

"""
Initialize wavefunction with Thomas-Fermi profile.
Uses the polar state (m=0 component) for spinor BEC.
"""
function init_psi_thomas_fermi(
    grid::Grid{N},
    sys::SpinSystem,
    potential::AbstractPotential,
    c0::Float64;
    N_target::Float64=1.0,
) where {N}
    V = evaluate_potential(potential, grid)
    dV = cell_volume(grid)

    result = thomas_fermi_density(V, c0, dV; N_target)
    n_TF = result.density

    psi = zeros(ComplexF64, grid.config.n_points..., sys.n_components)
    mid = (sys.n_components + 1) ÷ 2
    n_pts = grid.config.n_points
    idx = _component_slice(N, n_pts, mid)
    view(psi, idx...) .= sqrt.(n_TF)

    norm = sqrt(sum(abs2, psi) * dV)
    if norm > 0
        psi ./= norm
        psi .*= sqrt(N_target)
    end

    psi
end

"""
    init_psi_thomas_fermi_textured(grid, sys, potential, c0, texture_psi;
                                   N_target=1.0) → psi

Pair a Thomas-Fermi *density* envelope with an arbitrary *spin texture*
provided as `texture_psi[x..., c]`. The texture is normalised per-point
(divided by its local total density), then multiplied by `sqrt(n_TF(r))`
so the final ψ has

    |ψ(r)|² = n_TF(r),     ψ_c(r) / sqrt(n_TF(r)) = texture_psi_c(r) / |texture(r)|

The total density is set by Thomas-Fermi (i.e. self-consistent against
the trap + `c0`), while the *spin texture* (FL vortex, cyclic, biaxial
nematic, …) is whatever the caller supplies. Closes the gap flagged in
the code review (Round 4 #2): polarized GS gave a biased initial
density when ITP'ing into a non-trivial spin texture, so the FL/PCV
energy curves used for the B-1 boundary scan inherited a systematic
bias from the seed. Feed this textured TF state in as `psi_init` and
ITP relaxes from a starting point that is already self-consistent on
the density side.

Points where the texture is exactly zero (vortex cores in the dominant
component, etc.) are left at zero density, which is correct for those
states.
"""
function init_psi_thomas_fermi_textured(
    grid::Grid{N},
    sys::SpinSystem,
    potential::AbstractPotential,
    c0::Float64,
    texture_psi::AbstractArray{<:Complex};
    N_target::Float64=1.0,
) where {N}
    n_pts = grid.config.n_points
    D = sys.n_components
    expected = (n_pts..., D)
    size(texture_psi) == expected || throw(
        ArgumentError(
            "texture_psi shape $(size(texture_psi)) must match (n_pts..., D) = $expected"),
    )

    V = evaluate_potential(potential, grid)
    dV = cell_volume(grid)
    n_TF = thomas_fermi_density(V, c0, dV; N_target).density

    psi = zeros(ComplexF64, expected)
    @inbounds for I in CartesianIndices(n_pts)
        # Local norm of the supplied texture
        local_n = 0.0
        for c in 1:D
            local_n += abs2(texture_psi[I, c])
        end
        local_n > COUPLING_TOL || continue
        # |ψ(r)|² = n_TF(r), with the per-component ratio set by the
        # supplied texture
        scale = sqrt(n_TF[I] / local_n)
        for c in 1:D
            psi[I, c] = scale * texture_psi[I, c]
        end
    end

    # Renormalise to the requested N (TF normalisation can drift slightly
    # under the unit cell discretisation).
    norm = sqrt(sum(abs2, psi) * dV)
    norm > 0 && (psi ./= norm; psi .*= sqrt(N_target))
    psi
end
