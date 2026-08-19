# --- Vortex holes and vortex stripes in a column density ---
#
# Klaus et al., Nat. Phys. 18, 1453 (2022), Methods A.7. The point of doing it
# THEIR way rather than a better way is comparability: their published vortex
# number is a *detector output*, not a vortex count. Their own benchmark says
# so — between 600 and 700 ms the detector reports ≈9 where ≈33 vortices are
# actually present. A raw count from a phase map is a different observable and
# comparing it to their 𝒩ᵥ is wrong by ≈3.7×.
#
# Everything here therefore takes a column density (what an absorption image
# measures) and never the phase.

export blurred_reference, residual_image, detect_density_holes
export stripe_spectrum, stripe_metrics

"""
    blurred_reference(img, sigma_px) -> Matrix

Gaussian-blurred copy of `img`, rescaled so its sum matches `img`'s — the
"unmodulated reference" of Methods A.7 ("we then normalize the atom number of
the reference to be the same as from the image").

The convolution is normalised by the kernel weight that actually lands inside
the array, so the border is not darkened by implicit zeros. A periodic (FFT)
blur would wrap the cloud into the opposite edge; the images here are masked to
the high-density region, but the reference is built before the mask.
"""
function blurred_reference(img::AbstractMatrix{T}, sigma_px::Real) where {T <: Real}
    σ = T(sigma_px)
    σ > 0 || return copy(img)
    r = max(1, ceil(Int, 4σ))
    k = T[exp(-T(d)^2 / (2σ^2)) for d in (-r):r]
    nx, ny = size(img)
    tmp = zeros(T, nx, ny)
    out = zeros(T, nx, ny)
    @inbounds for j in 1:ny, i in 1:nx
        acc = zero(T);
        w = zero(T)
        for d in (-r):r
            ii = i + d
            (1 <= ii <= nx) || continue
            acc += k[d + r + 1] * img[ii, j];
            w += k[d + r + 1]
        end
        tmp[i, j] = w > 0 ? acc / w : zero(T)
    end
    @inbounds for j in 1:ny, i in 1:nx
        acc = zero(T);
        w = zero(T)
        for d in (-r):r
            jj = j + d
            (1 <= jj <= ny) || continue
            acc += k[d + r + 1] * tmp[i, jj];
            w += k[d + r + 1]
        end
        out[i, j] = w > 0 ? acc / w : zero(T)
    end
    s_img = sum(img);
    s_out = sum(out)
    s_out > 0 && (out .*= s_img / s_out)
    out
end

"""
    residual_image(img; sigma_px, mask_threshold=0.1) -> (res, mask)

`n_res = n_img − n_ref`, zeroed where `n_ref ≤ mask_threshold`, with both
images normalised to `max(n_img) = 1` first. `mask` is the boolean support.
"""
function residual_image(
    img::AbstractMatrix{T}; sigma_px::Real, mask_threshold::Real=0.1
) where {T <: Real}
    m = maximum(img)
    m > 0 || throw(ArgumentError("residual_image: image is identically zero"))
    n_img = img ./ m
    n_ref = blurred_reference(n_img, sigma_px)
    mask = n_ref .> T(mask_threshold)
    res = (n_img .- n_ref) .* mask
    (res, mask)
end

"""
    detect_density_holes(res, mask; contrast_threshold=-0.11, min_distance=5)
        -> Vector{Tuple{Int,Int}}

Local minima of the residual that survive Methods A.7's three filters: negative
residual, local contrast against the mean of the pixels ±2 away below
`contrast_threshold`, and no second minimum within `min_distance` pixels (the
shallower of a close pair is dropped). Minima touching the mask border are
dropped.

The published thresholds (−0.11, 5 px) are calibrated to *their* pixel size and
noise; on a raw simulation grid they are not transferable, which is why the
paper itself uses −0.08 / 3 px for its Fig. 4 visualisation of raw theory data.
Pass the values that match the image you have and say which you used.
"""
function detect_density_holes(
    res::AbstractMatrix{T}, mask::AbstractMatrix{Bool};
    contrast_threshold::Real=-0.11, min_distance::Real=5,
) where {T <: Real}
    nx, ny = size(res)
    cands = Tuple{Int, Int, T}[]
    @inbounds for j in 2:(ny - 1), i in 2:(nx - 1)
        mask[i, j] || continue
        v = res[i, j]
        v < 0 || continue
        is_min = true
        for dj in (-1):1, di in (-1):1
            (di == 0 && dj == 0) && continue
            if res[i + di, j + dj] <= v
                is_min = false;
                break
            end
        end
        is_min || continue
        # Touching the mask border: one of the 8 neighbours is outside.
        border = false
        for dj in (-1):1, di in (-1):1
            mask[i + di, j + dj] || (border = true)
        end
        border && continue
        # Local contrast against the four ±2 pixels.
        (i > 2 && i < nx - 1 && j > 2 && j < ny - 1) || continue
        ring = (res[i - 2, j] + res[i + 2, j] + res[i, j - 2] + res[i, j + 2]) / 4
        (v - ring) < T(contrast_threshold) || continue
        push!(cands, (i, j, v))
    end
    # Deepest first, then greedily drop anything within min_distance.
    sort!(cands; by=c -> c[3])
    kept = Tuple{Int, Int}[]
    d2 = T(min_distance)^2
    for (i, j, _) in cands
        ok = true
        for (ki, kj) in kept
            if (ki - i)^2 + (kj - j)^2 < d2
                ok = false;
                break
            end
        end
        ok && push!(kept, (i, j))
    end
    kept
end

"""
    stripe_spectrum(res, dx, dy) -> (kx, ky, mag)

`|F{n_res}|` with the k grids that go with it. Klaus et al. Fig. 4b3/c3 average
this over many images before reading it; `mag` from a single frame is noisy and
is meant to be summed.
"""
function stripe_spectrum(res::AbstractMatrix{T}, dx::Real, dy::Real) where {T <: Real}
    nx, ny = size(res)
    mag = abs.(fft(complex.(res)))
    kx = collect(T, fftfreq(nx, nx * 2π / (nx * dx)))
    ky = collect(T, fftfreq(ny, ny * 2π / (ny * dy)))
    (kx, ky, mag)
end

"""
    stripe_metrics(kx, ky, mag; k_lo, k_hi, n_angle=180) -> NamedTuple

Reduce a residual spectrum to the two things that separate Klaus Fig. 4b3
("clear peak at the k of the inter-stripe spacing", orientation set by B̂) from
Fig. 4d3 ("a homogeneous ring"):

- `angle` — direction of the dominant modulation wavevector, in `[0, π)`. The
  residual is real, so `|F|` is centrosymmetric and a stripe pattern always
  appears as a *pair*; only the axis is meaningful.
- `axis_order` — `|Σ w e^{2iφ}| / Σ w` over the annulus: the standard order
  parameter for a two-fold (axis) anisotropy, in `[0, 1]`. This is the
  ring-vs-peak discriminator. It replaced a binned `max(S)/mean(S)` on
  2026-08-18 **because that quantity read 6.8 on white noise**: an annulus of a
  few hundred k-points spread over 180 angular bins leaves ~2 points per bin,
  and `max/mean` of a 2-count histogram is shot noise, not structure. A
  binned peak-to-mean has a null that depends on the binning; this one does not.
- `axis_order_null` — `1/√n_k_points`, the level `axis_order` takes on
  isotropic power. **Always compare `axis_order` to it**, never to zero: with
  345 k-points the null is 0.054, so 0.05 means nothing and 0.4 means a lot.
- `k_peak` — radial centre of mass of the annulus power. **Weakly informative on
  its own**: it is a mean over a bounded window, so a featureless spectrum
  returns roughly the window's centre, which can sit close to a real stripe
  wavenumber. Use `k_mode` / `radial_prominence` to decide whether there is a
  peak at all, and `k_peak` only to locate one that exists.
- `k_mode`, `radial_prominence` — argmax and `max/median` of the radial profile
  of **mean power per k-bin**. Dividing by the bin population is what makes a
  flat spectrum give prominence ≈ 1: the raw count of k-points per radial bin
  grows ∝ k, so an unnormalised profile peaks at the top of the annulus no
  matter what the image contains.

Stripe count over a cloud of diameter `D` is `k·D/2π`.

`k_lo`/`k_hi` must be passed: an annulus chosen after seeing the answer is not
a measurement. `k_lo` excludes the cloud envelope (which is a huge low-k
feature and would swamp everything); `k_hi` excludes the pixel-noise floor.
"""
function stripe_metrics(
    kx::AbstractVector{T}, ky::AbstractVector{T}, mag::AbstractMatrix{T};
    k_lo::Real, k_hi::Real, n_angle::Int=180, n_radial::Int=24,
) where {T <: Real}
    k_lo < k_hi || throw(ArgumentError("need k_lo < k_hi, got $k_lo, $k_hi"))
    S = zeros(T, n_angle)
    R = zeros(T, n_radial)          # summed power per radial bin
    Rn = zeros(Int, n_radial)       # and its population, which is NOT uniform
    q_re = zero(T);
    q_im = zero(T)                  # Σ w e^{2iφ}, unbinned
    k_w = zero(T);
    w_tot = zero(T)
    n_in = 0
    @inbounds for j in eachindex(ky), i in eachindex(kx)
        k = sqrt(kx[i]^2 + ky[j]^2)
        (T(k_lo) <= k <= T(k_hi)) || continue
        w = mag[i, j]
        φ = mod(atan(ky[j], kx[i]), π)          # axis, not direction
        q_re += w * cos(2φ);
        q_im += w * sin(2φ)
        b = min(n_angle, 1 + floor(Int, φ / π * n_angle))
        S[b] += w
        rb = min(n_radial, 1 + floor(Int, (k - k_lo) / (k_hi - k_lo) * n_radial))
        R[rb] += w;
        Rn[rb] += 1
        k_w += w * k;
        w_tot += w
        n_in += 1
    end
    n_in > 0 || throw(
        ArgumentError(
            "stripe_metrics: no k points inside [$k_lo, $k_hi] — annulus outside the grid"),
    )
    prof = [Rn[b] > 0 ? R[b] / Rn[b] : T(0) for b in 1:n_radial]
    occupied = [p for p in prof if p > 0]
    p_max, rb_max = findmax(prof)
    med = isempty(occupied) ? zero(T) : sort(occupied)[cld(length(occupied), 2)]
    (
        angle=mod(atan(q_im, q_re) / 2, π),
        axis_order=w_tot > 0 ? sqrt(q_re^2 + q_im^2) / w_tot : T(NaN),
        axis_order_null=one(T) / sqrt(T(n_in)),
        k_peak=w_tot > 0 ? k_w / w_tot : T(NaN),
        k_mode=T(k_lo) + (rb_max - T(0.5)) * (T(k_hi) - T(k_lo)) / n_radial,
        radial_prominence=med > 0 ? p_max / med : T(NaN),
        angular_profile=S,
        radial_profile=prof,
        n_k_points=n_in,
    )
end
