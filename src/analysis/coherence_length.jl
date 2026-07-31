export first_order_correlation, coherence_length

"""
    first_order_correlation(psi, grid, plans) -> (r, g1)

Angle-averaged first-order correlation `g₁(r) = |⟨ψ†(x)ψ(x+r)⟩| / ⟨n⟩`, summed
over spinor components, as a function of separation `r`.

Computed through the Wiener–Khinchin theorem rather than by looping over pairs:
the autocorrelation is the inverse transform of the momentum density, so the
whole function costs one FFT pair per component instead of `O(N²)`.

# Why this and not a defect count

For a spinor the natural KZ observable is the coherence length, not a vortex
tally. Counting requires deciding *which* defect — per-component phase
singularities are basis-dependent (a spin rotation mixes the `m` components and
changes the count), mass vortices miss spin defects, and the topological
classification itself changes with the sign of `c₁`, which for ¹⁵¹Eu is unknown.
`g₁` sidesteps all of it: summing over components makes it invariant under spin
rotations, it needs no threshold, and it is the same observable for scalar and
spinor so the two are directly comparable.
"""
function first_order_correlation(
    psi::AbstractArray{<:Complex}, grid::Grid{N}, plans::FFTPlans
) where {N}
    n_pts = grid.config.n_points
    n_comp = size(psi, N + 1)
    dV = cell_volume(grid)

    # |ψ̂(k)|² summed over components; its inverse transform is Σ_c ∫ψ_c*(x)ψ_c(x+r)dx.
    Sk = zeros(Float64, n_pts)
    buf = zeros(ComplexF64, n_pts)
    for c in 1:n_comp
        buf .= view(psi, ntuple(_ -> Colon(), N)..., c)
        plans.forward * buf
        @. Sk += abs2(buf)
    end
    buf .= Sk
    plans.inverse * buf
    acf = real.(buf)
    norm0 = acf[ntuple(_ -> 1, N)...]
    norm0 > 0 || return (Float64[], Float64[])

    # Angle-average onto |r| bins. Separations wrap, so fold each axis at L/2.
    L = grid.config.box_size
    nb = minimum(n_pts) ÷ 2
    rmax = minimum(L) / 2
    edges = range(0, rmax; length=nb + 1)
    acc = zeros(Float64, nb)
    cnt = zeros(Int, nb)
    for I in CartesianIndices(n_pts)
        r2 = 0.0
        for d in 1:N
            i = I[d] - 1
            i > n_pts[d] ÷ 2 && (i -= n_pts[d])          # nearest image
            r2 += (i * (L[d] / n_pts[d]))^2
        end
        r = sqrt(r2)
        r < rmax || continue
        b = clamp(Int(floor(r / rmax * nb)) + 1, 1, nb)
        acc[b] += abs(acf[I]);
        cnt[b] += 1
    end
    keep = findall(>(0), cnt)
    (collect(edges)[keep] .+ step(edges) / 2, (acc[keep] ./ cnt[keep]) ./ norm0)
end

"""
    coherence_length(r, g1; threshold=exp(-1)) -> ℓ

Separation at which `g₁` first falls to `threshold`, linearly interpolated
between the bracketing bins. `NaN` if `g₁` never gets there inside the box —
reported rather than clamped, because a coherence length pinned at the box size
is not a measurement of the field, it is a measurement of the box.
"""
function coherence_length(r::AbstractVector, g1::AbstractVector; threshold::Real=exp(-1))
    length(r) == length(g1) || throw(DimensionMismatch("r and g1 length mismatch"))
    i = findfirst(<(threshold), g1)
    (i === nothing || i == 1) && return NaN
    x0, x1 = g1[i - 1], g1[i]
    x0 ≈ x1 && return r[i]
    r[i - 1] + (r[i] - r[i - 1]) * (x0 - threshold) / (x0 - x1)
end
