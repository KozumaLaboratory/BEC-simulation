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
    coherence_length(r, g1; r_fit_max=nothing, min_points=5) -> (; xi, f_inf, resid, window)

Fit `g₁(r) ≈ f_∞ + A exp(−r/ξ)` and return the decay length `ξ` and the plateau
`f_∞` separately. `ξ` is scanned on a log grid and the linear parameters
`(f_∞, A)` are solved exactly at each `ξ`, so there is no initial guess and no
iteration to diverge.

`r_fit_max` bounds the fit. With `nothing` it is chosen self-consistently: fit
the first few bins, then refit over `6ξ`. Pass an explicit value when the cloud
radius is known.

# Why the fit is bounded at all

A measured `g₁` has three parts, and only the first two are what this function
is for. On a condensed cloud (`t_hold = 200`, `μ = 15`, `R_TF = 5.48`):

    r     0.07  0.22  0.36  0.51  0.66  0.80  1.09  1.97  3.13  4.30  6.04  7.79
    g₁    1.00  0.96  0.91  0.86  0.84  0.84  0.83  0.79  0.72  0.61  0.41  0.17

a fast drop over `r ≲ 0.65`, a plateau at 0.835 — the condensate fraction — and
then a slow decline that is cloud structure: the condensate fraction is not
uniform, so dividing by the amplitude autocorrelation does not flatten it. An
unbounded fit charges that structural tail to the coherence length, and reading
the plateau off the outer end of the measured range reports 0.12 for a plateau
of 0.835 because that range ends at `r = 10` while the cloud ends at 5.48.

# History

This is the third statement of this function; the first two were wrong in ways
the returned number could not show.

  - A `1/e` threshold is not a length. It reported where the plateau happened to
    cross 0.368: `0.354 / 0.439 / 7.966 / NaN / NaN` for known coherent fractions
    `0.0 / 0.3 / 0.6 / 0.9 / 0.99`.
  - Normalising by `⟨n⟩` left the envelope autocorrelation in `g₁`, so the far
    field measured the cloud's finite size rather than its coherence.

Both produced `ξ̂ = 0.367 … 0.405` across an 8× change in quench rate with the
per-seed spread reported as exactly 0.000, and turned a Kibble–Zurek prediction
of `b = 0.47 ± 0.04` into `0.073`.

`resid` is returned so a fit that does not describe the data is visible rather
than silent.
"""
function coherence_length(
    r::AbstractVector, g1::AbstractVector;
    r_fit_max::Union{Nothing, Real}=nothing, min_points::Int=5,
)
    length(r) == length(g1) || throw(DimensionMismatch("r and g1 length mismatch"))
    n = length(r)
    n >= min_points || return (; xi=NaN, f_inf=NaN, resid=NaN, window=NaN)

    r_fit_max === nothing && (r_fit_max = _knee_window(r, g1))
    imax = something(findlast(<=(r_fit_max), r), n)
    imax >= min_points || (imax = min_points)
    fit = _fit_plateau_exp(r, g1, imax)
    (; fit.xi, fit.f_inf, fit.resid, window=r[imax])
end

# The fit window has to come from the shape, not from a bin count: the same
# curve sampled coarsely put a count-based window out in the structural tail and
# turned a plateau of 0.835 into 0.611. The knee — where the decay rate has
# fallen to 15% of its steepest — is a property of the curve, so it lands in the
# same place at any sampling. Three times the knee gives the fit enough of the
# decay to constrain ξ while staying clear of the tail.
function _knee_window(r::AbstractVector, g1::AbstractVector)
    n = length(r)
    n >= 4 || return r[n]
    slope = [(g1[i + 1] - g1[i]) / (r[i + 1] - r[i]) for i in 1:(n - 1)]
    imax = argmax(abs.(slope))
    thr = 0.15 * abs(slope[imax])
    knee = something(findfirst(i -> abs(slope[i]) < thr, (imax + 1):(n - 1)), n - 1 - imax)
    clamp(3 * r[min(imax + knee, n)], r[min(4, n)], r[n])
end

# ξ enters only through exp(-r/ξ), so scanning it and solving the two linear
# parameters in closed form at each node beats any gradient method here: no
# starting point, no local minimum, and the cost is one 2×2 solve per node.
function _fit_plateau_exp(r::AbstractVector, g1::AbstractVector, imax::Int)
    rr = @view r[1:imax]
    yy = @view g1[1:imax]
    best = (; xi=NaN, f_inf=NaN, resid=Inf)
    lo, hi = log(r[1] / 4), log(r[imax] * 4)
    for lξ in range(lo, hi; length=400)
        ξ = exp(lξ)
        S1 = float(imax)
        Se = Sf = Sy = Sey = 0.0
        for i in 1:imax
            e = exp(-rr[i] / ξ)
            Se += e;
            Sf += e * e
            Sy += yy[i];
            Sey += e * yy[i]
        end
        det = S1 * Sf - Se^2
        abs(det) > 1e-14 || continue
        f = (Sf * Sy - Se * Sey) / det
        A = (S1 * Sey - Se * Sy) / det
        A > 1e-3 || continue                      # no decaying component to speak of
        res = 0.0
        for i in 1:imax
            res += (yy[i] - (f + A * exp(-rr[i] / ξ)))^2
        end
        res < best.resid && (best = (; xi=ξ, f_inf=f, resid=res))
    end
    best.resid === Inf ? (; xi=NaN, f_inf=(sum(g1[1:imax]) / imax), resid=NaN) : best
end
