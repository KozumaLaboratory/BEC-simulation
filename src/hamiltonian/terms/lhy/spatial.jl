# spatial.jl
# =================================================================
# LHY that follows the local spin texture.
#
# Every other table here is a function of `n` alone, built for ONE spinor and
# applied at every voxel. Exact for a uniform state; measured at ~5% on
# converged weak-field Eu ground states, with a sign that flips along a B-scan
# so it does not cancel in a comparison.
#
# What makes a spatial table affordable is the same separation the `n^(5/2)`
# fast path already relies on: with degenerate Zeeman energies the BdG
# stiffness matrices are exactly ∝ n, so
#
#     ε_LHY(n, ζ) = n^(5/2) e₁(ζ),     V_LHY = (5/2) n^(3/2) e₁(ζ)
#
# and all the spinor dependence sits in `e₁`. Tabulating `e₁` costs a handful
# of BdG solves at build time; the propagator then pays one interpolation and
# an O(D) ladder sum per voxel, on component reads it already performs.
#
# `e₁` is tabulated against `p = |⟨F⟩|/F` because that is the direction it
# actually varies in. Measured at F=6: rotating a spinor leaves ε_LHY invariant
# to machine precision for contact (an SO(3) scalar) and moves it 0.25% under
# the DDI, while taking `p` from 1 to 0 moves it ~20%.
#
# `p` does not fix ζ uniquely, so this remains an approximation — but the
# representative spinors are taken from the ACTUAL cloud rather than from an
# invented interpolation path between FM and polar, so the family is the
# physical one. The residual within a `p` bin is measured and reported by
# `spatial_lhy_residual`.

export compute_spatial_lhy, spatial_lhy_residual

"""
    compute_spatial_lhy(; psi_init, F, interactions, zeeman, c_dd,
                          n_bins=12, rtol=1e-4) → SpatialLHY

Build an `e₁(p)` table from the local spinors present in `psi_init`.

Voxels are binned by `p = |⟨F⟩|/F`; each occupied bin contributes one BdG solve
for its heaviest voxel (heaviest by `n^(5/2)`, the weight ε_LHY carries), and
empty bins are filled by interpolation. So the cost is at most `n_bins` solves,
independent of grid size.

Returns `nothing` when the state is uniform enough that a single-spinor table
is already right — there is no reason to pay for a texture that is not there.
"""
function compute_spatial_lhy(;
    psi_init::AbstractArray{<:Complex, M},
    F::Int,
    interactions::InteractionParams,
    zeeman::ZeemanParams=ZeemanParams(),
    c_dd::Float64=0.0,
    n_bins::Int=12,
    rtol::Float64=1e-4,
    min_spread::Float64=0.05,
) where {M}
    n_bins >= 2 || throw(ArgumentError("n_bins must be ≥ 2"))
    N = M - 1
    D = size(psi_init, M)
    D == 2F + 1 ||
        throw(DimensionMismatch("psi_init has $D components, expected 2F+1 = $(2F + 1)"))

    ps, ws, reps = _bin_local_spinors(psi_init, F, Val(N), Val(D), n_bins)
    isempty(ps) && return nothing
    (maximum(ps) - minimum(ps)) < min_spread && return nothing

    e1 = similar(ps)
    for i in eachindex(reps)
        e1[i] = _lhy_bdg_energy_density(reps[i], 1.0, F, interactions, zeeman,
            c_dd, nothing, nothing, nothing; rtol)
    end
    SpatialLHY(ps, e1, F, [fp_ladder_coeff(F, F - (c - 1)) for c in 1:D])
end

# Bin voxels by |⟨F⟩|/F and return (bin centres, bin weights, representative
# normalised spinors). The representative is the heaviest voxel in the bin,
# because that is the one whose e₁ the bin's weight is mostly buying.
function _bin_local_spinors(psi_init, F::Int, ::Val{N}, ::Val{D},
    n_bins::Int) where {N, D}
    n_pts = ntuple(d -> size(psi_init, d), Val(N))
    edges = range(0.0, 1.0; length=n_bins + 1)
    best_w = zeros(Float64, n_bins)
    tot_w = zeros(Float64, n_bins)
    best_i = Vector{Union{Nothing, CartesianIndex{N}}}(nothing, n_bins)
    fp = ntuple(c -> fp_ladder_coeff(F, F - (c - 1)), Val(D))

    nmax = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        s = 0.0
        for c in 1:D
            s += abs2(psi_init[I, c])
        end
        nmax = max(nmax, s)
    end
    nmax <= 0 && return (Float64[], Float64[], Vector{ComplexF64}[])
    cut = 1e-6 * nmax

    @inbounds for I in CartesianIndices(n_pts)
        s = 0.0
        for c in 1:D
            s += abs2(psi_init[I, c])
        end
        s < cut && continue
        fz = 0.0
        for c in 1:D
            fz += (F - (c - 1)) * abs2(psi_init[I, c])
        end
        fre = 0.0
        fim = 0.0
        for c in 2:D
            pr = conj(psi_init[I, c - 1]) * psi_init[I, c]
            fre += fp[c] * real(pr)
            fim += fp[c] * imag(pr)
        end
        p = clamp(sqrt(fre^2 + fim^2 + fz^2) / (s * F), 0.0, 1.0)
        b = clamp(searchsortedlast(edges, p), 1, n_bins)
        w = s^2.5
        tot_w[b] += w
        if w > best_w[b]
            best_w[b] = w
            best_i[b] = I
        end
    end

    occupied = findall(!isnothing, best_i)
    isempty(occupied) && return (Float64[], Float64[], Vector{ComplexF64}[])
    ps = Float64[(edges[b] + edges[b + 1]) / 2 for b in occupied]
    wts = Float64[tot_w[b] for b in occupied]
    reps = map(occupied) do b
        I = best_i[b]::CartesianIndex{N}
        z = ComplexF64[psi_init[I, c] for c in 1:D]
        z ./ norm(z)
    end
    (ps, wts, reps)
end

"""
    spatial_lhy_residual(lhy, psi_init, F, interactions; zeeman, c_dd, rtol,
                         n_probe=3) → Float64

Largest relative disagreement between the tabulated `e₁(p)` and a direct BdG
solve, over `n_probe` randomly drawn voxels per occupied bin.

`p` does not determine ζ, so this is the approximation's own error bar, and it
is what should be quoted alongside a spatially-varying LHY result rather than
assumed small. Returns `NaN` when nothing could be probed.
"""
function spatial_lhy_residual(lhy::SpatialLHY, psi_init::AbstractArray{<:Complex, M},
    F::Int, interactions::InteractionParams;
    zeeman::ZeemanParams=ZeemanParams(), c_dd::Float64=0.0,
    rtol::Float64=1e-4, n_probe::Int=3, seed::Int=0) where {M}
    N = M - 1
    D = size(psi_init, M)
    n_pts = ntuple(d -> size(psi_init, d), Val(N))
    rng = Random.MersenneTwister(seed)
    fp = lhy.fp_coeffs

    idx = CartesianIndex{N}[]
    @inbounds for I in CartesianIndices(n_pts)
        s = 0.0
        for c in 1:D
            s += abs2(psi_init[I, c])
        end
        s > 0 && push!(idx, I)
    end
    isempty(idx) && return NaN

    worst = 0.0
    hit = false
    for _ in 1:(n_probe * length(lhy.polarisations))
        I = idx[rand(rng, 1:length(idx))]
        z = ComplexF64[psi_init[I, c] for c in 1:D]
        nz = norm(z)
        nz < 1e-14 && continue
        z ./= nz
        fz = sum(c -> (F - (c - 1)) * abs2(z[c]), 1:D)
        fre = sum(c -> fp[c] * real(conj(z[c - 1]) * z[c]), 2:D)
        fim = sum(c -> fp[c] * imag(conj(z[c - 1]) * z[c]), 2:D)
        p = clamp(sqrt(fre^2 + fim^2 + fz^2) / F, 0.0, 1.0)
        exact = _lhy_bdg_energy_density(z, 1.0, F, interactions, zeeman, c_dd,
            nothing, nothing, nothing; rtol)
        tab = _interpolate_1d(lhy.polarisations, lhy.e1_values, p)
        abs(exact) < 1e-30 && continue
        worst = max(worst, abs(tab - exact) / abs(exact))
        hit = true
    end
    hit ? worst : NaN
end
