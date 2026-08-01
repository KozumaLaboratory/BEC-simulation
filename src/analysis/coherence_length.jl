export first_order_correlation, coherence_length

"""
    first_order_correlation(psi, grid, plans) -> (r, g1)

Angle-averaged first-order correlation

    g₁(r) = |Σ_c ⟨ψ_c*(x) ψ_c(x+r)⟩| / ⟨√n(x) √n(x+r)⟩

as a function of separation `r`, with both averages taken over the box.

Computed through the Wiener–Khinchin theorem rather than by looping over pairs:
an autocorrelation is the inverse transform of a spectral density, so the whole
function costs a few FFT pairs instead of `O(N²)`.

# Why the denominator is not simply ⟨n⟩

Normalising by the constant `⟨n⟩` leaves the *envelope* autocorrelation in `g₁`:
for a trapped cloud, ⟨ψ*(x)ψ(x+r)⟩ falls off with `r` because the cloud has a
finite size, whether or not phase coherence is lost. On a Gaussian cloud whose
width is comparable to the half-box that decay dominates, and the far-field value
of `g₁` is then neither the condensate fraction nor anything else physical.

Dividing by the autocorrelation of the amplitude `√n` — the same field with the
phase stripped — removes it identically: a fully phase-coherent state has
`ψ_c = ζ_c √n` with constant `ζ`, so numerator and denominator are equal and
`g₁ ≡ 1` at every `r`, exactly, for any envelope. What remains is the decay from
phase decoherence alone, which is the length Kibble–Zurek scaling is about.

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

    # Σ_c |ψ̂_c(k)|²; its inverse transform is Σ_c ∫ψ_c*(x)ψ_c(x+r)dx.
    Sk = zeros(Float64, n_pts)
    amp = zeros(Float64, n_pts)
    buf = zeros(ComplexF64, n_pts)
    for c in 1:n_comp
        buf .= view(psi, ntuple(_ -> Colon(), N)..., c)
        @. amp += abs2(buf)
        plans.forward * buf
        @. Sk += abs2(buf)
    end
    @. amp = sqrt(amp)                       # |ψ| with the phase discarded

    buf .= Sk
    plans.inverse * buf
    acf = real.(buf)

    buf .= amp
    plans.forward * buf
    @. buf = abs2(buf)
    plans.inverse * buf
    env = real.(buf)                         # same transform, phase removed

    norm0 = acf[ntuple(_ -> 1, N)...]
    norm0 > 0 || return (Float64[], Float64[])

    # Angle-average numerator and denominator separately onto |r| bins, then
    # divide — binning the ratio pointwise would weight by envelope, not volume.
    L = grid.config.box_size
    nb = minimum(n_pts) ÷ 2
    rmax = minimum(L) / 2
    edges = range(0, rmax; length=nb + 1)
    num = zeros(Float64, nb)
    den = zeros(Float64, nb)
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
        num[b] += abs(acf[I])
        den[b] += env[I]
        cnt[b] += 1
    end
    keep = findall(i -> cnt[i] > 0 && den[i] > 0, 1:nb)
    (collect(edges)[keep] .+ step(edges) / 2, num[keep] ./ den[keep])
end

"""
    coherence_length(r, g1; plateau_frac=0.7, min_points=4) -> (; xi, f_inf)

Decay length of the CONNECTED part of `g₁`, with the condensate plateau removed
first:

    g₁(r) ≈ f_∞ + (1 − f_∞) exp(−r/ξ)

`f_∞` is the mean of `g₁` over the outer `plateau_frac`…1 of the measured range
(the condensate fraction, up to finite-size effects); `ξ` comes from a
least-squares line through `log(g₁ − f_∞)` over the points where that residual is
positive and above the plateau noise.

# Why not a 1/e threshold

The first version returned the separation where `g₁` first fell to `1/e`, and
that number is not a length — it is where the plateau happens to cross 0.368.
Measured on synthetic fields with a known condensate fraction `f`:

    f       g₁(r→0⁺)   g₁(far)   1/e crossing
    0.00      0.002     0.001     0.354
    0.30      0.301     0.184     0.439
    0.60      0.600     0.368     7.966      <- plateau sits ON 1/e
    0.90      0.899     0.551     NaN        <- never reaches it
    0.99      0.988     0.606     NaN

Below `f = 1/e` it reports the thermal decay (a couple of grid cells), near it the
crossing runs away, above it there is no crossing at all. In the Kibble-Zurek scan
that produced `ξ̂ = 0.367, 0.374, 0.386, 0.405` across an 8× change in quench rate
with the per-seed spread reported as exactly zero — a constant condensate fraction
masquerading as a constant length, which broke the prediction `b = α/2 = 0.47`
(measured 0.073) and made the observable, not the defect count, the thing at
fault.

Returns `xi = NaN` when fewer than `min_points` usable points remain, rather than
extrapolating from two.
"""
function coherence_length(
    r::AbstractVector, g1::AbstractVector;
    plateau_frac::Real=0.7, min_points::Int=4,
)
    length(r) == length(g1) || throw(DimensionMismatch("r and g1 length mismatch"))
    n = length(r)
    n >= 6 || return (; xi=NaN, f_inf=NaN)

    i0 = max(2, Int(floor(plateau_frac * n)))
    f_inf = sum(@view g1[i0:n]) / (n - i0 + 1)
    # Scatter of the plateau itself sets the floor: below it, g₁ − f_∞ is noise.
    σ = sqrt(sum((g1[i] - f_inf)^2 for i in i0:n) / max(n - i0, 1))
    floor_ = max(3σ, 1e-6)

    idx = [i for i in 1:(i0 - 1) if g1[i] - f_inf > floor_]
    length(idx) >= min_points || return (; xi=NaN, f_inf)

    x = [r[i] for i in idx]
    y = [log(g1[i] - f_inf) for i in idx]
    x̄ = sum(x) / length(x);
    ȳ = sum(y) / length(y)
    Sxx = sum((a - x̄)^2 for a in x)
    Sxx > 0 || return (; xi=NaN, f_inf)
    slope = sum((a - x̄) * (b - ȳ) for (a, b) in zip(x, y)) / Sxx
    slope < 0 || return (; xi=NaN, f_inf)      # not a decay
    (; xi=-1 / slope, f_inf)
end
