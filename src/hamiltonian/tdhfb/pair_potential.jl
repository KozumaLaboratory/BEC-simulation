# TDHFB anomalous (pair) potential Δ — channel-decomposed.
#
# The pair potential is the natural partner of the Hartree-Fock self-energy U:
# where U couples to (φ*φ + ρ) (normal density), Δ couples to (φφ + κ)
# (anomalous / pair density). Both are built from the same rank-4 channel
# kernel V = channel_kernel(F, g_S).
#
#   Δ_{m, m'}(r) = Σ_{m2, m2'} V_{m m'; m2 m2'} ( φ_{m2}(r) φ_{m2'}(r)
#                                                 + κ_{m2, m2'}(r) )
#
# Δ is symmetric in (m, m') by construction (V is symmetric under
# (c, c2) ↔ (c', c2') and (φ_{m2} φ_{m2'} + κ_{m2, m2'}) is symmetric in
# (m2, m2')).
#
# The un-symmetrized channel kernel V is used here because the pair density
# (φφ + κ) is already symmetric in its pair indices, so the factor-2 Bose
# symmetrization that appears in U would double-count. This matches
# Kawaguchi-Ueda 2012 Eq. (37) for the spinor BEC anomalous mean field.

export pair_potential_generic, pair_potential_generic!

"""
    pair_potential_generic!(Δ, phi, kappa, F, g_S; V=nothing) -> Δ

Compute the anomalous pair potential

    Δ[idx, c, c'] = Σ_{c2, c2'} V_{c c'; c2 c2'} ( φ_{c2}(idx) φ_{c2'}(idx)
                                                   + κ[idx, c2, c2'] )

in the local approximation, with the convention `c=1 ↔ m=+F`, `c=D ↔ m=-F`.

# Arguments
- `Δ::AbstractArray{ComplexF64, N+2}`: output buffer, shape `(spatial..., D, D)`
- `phi::AbstractArray{ComplexF64, N+1}`: mean field, shape `(spatial..., D)`
- `kappa::AbstractArray{ComplexF64, N+2}`: anomalous density, shape
  `(spatial..., D, D)`. Must be symmetric: `κ[idx, c, c'] == κ[idx, c', c]`.
- `F::Int`: spin quantum number
- `g_S::AbstractDict{Int, Float64}`: channel couplings keyed by S

# Keyword arguments
- `V`: optional precomputed channel kernel `Array{Float64, 4}` from
  `channel_kernel(F, g_S)`. If `nothing`, it is built on-the-fly.

# Properties
- Δ is symmetric in `(c, c')` by construction.
- Δ is linear in κ and quadratic-bilinear in φ.
- Reduces to `Δ = V · φφ` when κ = 0.

# Returns
The Δ array (for chaining).
"""
function pair_potential_generic!(Delta::AbstractArray, phi::AbstractArray,
                                 kappa::AbstractArray, F::Int,
                                 g_S::AbstractDict{Int, Float64};
                                 V=nothing)
    D = 2 * F + 1
    sz = size(phi)
    n_spatial = length(sz) - 1
    @assert sz[end] == D "phi last-axis dimension must be 2F+1 = $D"
    @assert size(Delta, ndims(Delta)) == D
    @assert size(Delta, ndims(Delta) - 1) == D
    @assert size(kappa, ndims(kappa)) == D
    @assert size(kappa, ndims(kappa) - 1) == D

    Vker = V === nothing ? channel_kernel(F, g_S) : V

    @inbounds for idx in CartesianIndices(size(phi)[1:n_spatial])
        for c in 1:D, c_p in 1:D
            val = ComplexF64(0)
            for c2 in 1:D, c2_p in 1:D
                pair = phi[idx, c2] * phi[idx, c2_p] + kappa[idx, c2, c2_p]
                val += Vker[c, c_p, c2, c2_p] * pair
            end
            Delta[idx, c, c_p] = val
        end
    end
    return Delta
end

"""
    pair_potential_generic(phi, kappa, F, g_S; V=nothing) -> Δ

Allocating variant of [`pair_potential_generic!`](@ref).
"""
function pair_potential_generic(phi::AbstractArray, kappa::AbstractArray,
                                F::Int, g_S::AbstractDict{Int, Float64};
                                V=nothing)
    D = 2 * F + 1
    sz = size(phi)
    n_spatial = length(sz) - 1
    Delta = zeros(ComplexF64, sz[1:n_spatial]..., D, D)
    return pair_potential_generic!(Delta, phi, kappa, F, g_S; V=V)
end
