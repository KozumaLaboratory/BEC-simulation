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
# actually varies in. Re-measured at ¹⁵¹Eu F=6, c1_ratio = 1/36, ε_dd = 0.54
# (#337, `bench/lhy_state_dependence.jl`) — the numbers this comment used to
# carry were both taken at a much weaker dipole and are quoted here corrected:
#
#   rotation, contact, B = 0     5.3e-7   (SO(3) scalar, as claimed)
#   rotation, contact, B = 44 µG 7.6e-3   (a field picks an axis; not scale-free)
#   rotation, with DDI, B = 0    2.6e-2   (was recorded as 0.25%, at ε_dd ~ 0.05)
#   p: 1 → 0                     factor 3.9  (was recorded as "~20%")
#
# The p-dependence rides on `c1_ratio`: it is a factor 1.50 at c1_ratio = 0,
# where every g_S collapses to c₀ and only the DDI distinguishes the endpoints,
# and 3.9 at the campaign's 1/36. A number measured near zero therefore says
# nothing about production, which is where the "~20%" came from.
#
# `p` does not fix ζ uniquely, so this remains an approximation — but the
# representative spinors are taken from the ACTUAL cloud rather than from an
# invented interpolation path between FM and polar, so the family is the
# physical one. The residual within a `p` bin is measured and reported by
# `spatial_lhy_residual`.

export compute_spatial_lhy, spatial_lhy_residual, spatial_lhy_energy_residual

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
    n_atoms::Int=1,
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
        # Same 1/N as `_tabulate_lhy`: the closed/BdG forms are in physical
        # units, the repo's n = |ψ|² is normalised to 1 and c₀ already carries N.
        e1[i] =
            _lhy_bdg_energy_density(reps[i], 1.0, F, interactions, zeeman,
                c_dd, nothing, nothing, nothing; rtol) / n_atoms
    end
    SpatialLHY(ps, e1, F, [fp_ladder_coeff(F, F - (c - 1)) for c in 1:D], n_atoms)
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

The reference is divided by `lhy.n_atoms` because `compute_spatial_lhy` divided
the table by it — the closed forms are in physical units while `n = |ψ|²` here is
normalised to 1 and `c₀` already carries N. Without that division this compared
two quantities N apart and returned ≈ 1 − 1/N: measured 2026-08-19 on converged
Eu ground states at N = 50000 it read exactly **1.0000** for every state, a
"100 % residual" that was entirely the missing factor and would have been read as
the spatial approximation collapsing.
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
        exact =
            _lhy_bdg_energy_density(z, 1.0, F, interactions, zeeman, c_dd,
                nothing, nothing, nothing; rtol) / lhy.n_atoms
        tab = _interpolate_1d(lhy.polarisations, lhy.e1_values, p)
        abs(exact) < 1e-30 && continue
        worst = max(worst, abs(tab - exact) / abs(exact))
        hit = true
    end
    hit ? worst : NaN
end

"""
    spatial_lhy_energy_residual(lhy, psi_init, F, interactions; zeeman, c_dd,
                                rtol, n_probe=24, seed=0)
        → (signed, absolute, worst)

Relative error of the INTEGRATED `∫ε_LHY dV` that the spatial table implies,
estimated by importance sampling voxels with probability ∝ `n^(5/2)` — the
weight ε_LHY actually carries.

This is the number that propagates to an energy or a phase boundary, and it is
NOT what [`spatial_lhy_residual`] reports. That one takes the worst case over
voxels drawn UNIFORMLY, so it is dominated by the dilute edge, where the local
spinor is furthest from its bin's representative and the density contributes
essentially nothing. Measured on converged Eu ground states the two differ by an
order of magnitude, and quoting the uniform worst case as "the error on the
result" overstates it by that much.

Three numbers, because they answer different questions:

- `signed` — `Σw(tab−exact) / Σw·exact`. Errors of opposite sign cancel inside
  an integral, so this is the error on the energy.
- `absolute` — the same with `|tab−exact|`. The bound if they did not cancel.
- `worst` — the largest single-voxel relative error among the sampled (weighted)
  voxels.

Unlike [`spatial_lhy_residual`] this compares `n^(5/2)·e₁(p)` against a BdG solve
**at the voxel's own density**, not at `n = 1`. That folds in the second
approximation as well as the first: the `ε ∝ n^(5/2)` scaling the table relies on
is exact only for degenerate Zeeman energies, and at the campaign's 44 µG the
splitting `p·F ≈ 3.9` is comparable to `c₀n ≈ 8.6`, so it is not exact there.
Evaluating at `n = 1` would have hidden that by construction.
"""
function spatial_lhy_energy_residual(lhy::SpatialLHY,
    psi_init::AbstractArray{<:Complex, M}, F::Int, interactions::InteractionParams;
    zeeman::ZeemanParams=ZeemanParams(), c_dd::Float64=0.0,
    rtol::Float64=1e-4, n_probe::Int=24, seed::Int=0) where {M}
    N = M - 1
    D = size(psi_init, M)
    n_pts = ntuple(d -> size(psi_init, d), Val(N))
    rng = Random.MersenneTwister(seed)
    fp = lhy.fp_coeffs

    # Cumulative n^(5/2) weight, so a draw is an energy-weighted draw.
    idx = CartesianIndex{N}[]
    wts = Float64[]
    @inbounds for I in CartesianIndices(n_pts)
        s = 0.0
        for c in 1:D
            s += abs2(psi_init[I, c])
        end
        s <= 0 && continue
        push!(idx, I)
        push!(wts, s^2.5)
    end
    isempty(idx) && return (NaN, NaN, NaN)
    cum = cumsum(wts)
    total = cum[end]
    total <= 0 && return (NaN, NaN, NaN)

    num_signed = 0.0
    num_abs = 0.0
    den = 0.0
    worst = 0.0
    hit = false
    for _ in 1:n_probe
        I = idx[searchsortedfirst(cum, rand(rng) * total)]
        z = ComplexF64[psi_init[I, c] for c in 1:D]
        n_loc = sum(abs2, z)
        n_loc <= 0 && continue
        z ./= sqrt(n_loc)
        fz = sum(c -> (F - (c - 1)) * abs2(z[c]), 1:D)
        fre = sum(c -> fp[c] * real(conj(z[c - 1]) * z[c]), 2:D)
        fim = sum(c -> fp[c] * imag(conj(z[c - 1]) * z[c]), 2:D)
        p = clamp(sqrt(fre^2 + fim^2 + fz^2) / F, 0.0, 1.0)

        exact =
            _lhy_bdg_energy_density(z, n_loc, F, interactions, zeeman, c_dd,
                nothing, nothing, nothing; rtol) / lhy.n_atoms
        tab = n_loc^2.5 * _interpolate_1d(lhy.polarisations, lhy.e1_values, p)
        abs(exact) < 1e-30 && continue
        # Importance sampling: drawing ∝ n^(5/2) and then weighting by n^(5/2)
        # again would square the weight. The draw IS the weight, so each sample
        # enters with weight 1 and the ratio below is the energy-weighted mean.
        num_signed += tab - exact
        num_abs += abs(tab - exact)
        den += abs(exact)
        worst = max(worst, abs(tab - exact) / abs(exact))
        hit = true
    end
    hit || return (NaN, NaN, NaN)
    (num_signed / den, num_abs / den, worst)
end
