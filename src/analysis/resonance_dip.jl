"""
    resonance_dip(x, y; endpoint_baseline=true) -> NamedTuple

Locate and size a single dip in `y(x)` — the shape a resonantly enhanced loss
channel leaves in the population of the source component when a control
parameter is scanned across the resonance.

Returns `(; center, minimum, x_min, depth_left, depth_right, half_left,
half_right, width)`:

- `x_min` — the sampled abscissa of the smallest `y`.
- `center` — parabolic-vertex refinement of `x_min` using its two neighbours.
  This is the number to quote as *the* resonance position; `x_min` alone is
  quantised by the scan step.
- `half_left` / `half_right` — the abscissae where `y` first climbs back
  through half the dip depth on each side, linearly interpolated.
- `width = half_right - half_left`.

The dip is measured against a **per-side baseline**, because a resonance
sitting on an asymmetric background (the generic case: the two wings of a
magnetic-field scan are not related by any symmetry) has no single meaningful
"top". With `endpoint_baseline=true` the baseline on each side is `y` at that
side's extreme sampled `x`; otherwise it is that side's running maximum. Use
the same setting on every curve being compared — the width is only comparable
between curves measured the same way, and the endpoint convention is the one
that does not depend on where a noisy curve happens to peak.

!!! warning "`width` is a property of the curve **and its window**"
    With `endpoint_baseline=true` the half-depth level is set by the endpoints,
    so trimming the scan changes `width` even though the physics did not. This
    is not a small effect on a dip with long wings. Measured on the Matsui
    Fig. 4B theory curve, one and the same dataset:

    | window [nT] | `width` [nT] |
    |---|---|
    | [−20, +20] | 15.02 |
    | [−13, +9] | 13.07 |
    | [−10, +9] | 11.79 |

    Two curves are therefore comparable in `width` only over an **identical**
    `x` window — matching the nominal range is not enough if the two scans put
    their outermost sample at different `x`. Restricting both to a nominal
    [−12.5, +9] left one curve's leftmost sample at −12.5 and the other's, which
    had no node there, at −12; that half step alone inflated the apparent
    disagreement from 0.10 % to 1.04 %. Trim both to common abscissae before
    comparing. `center` is local to the minimum and carries none of this.

Throws if the minimum sits on either endpoint (no dip is bracketed) or if `y`
never returns to half depth on one side (the scan is too narrow to size it).
"""
function resonance_dip(
    x::AbstractVector{<:Real}, y::AbstractVector{<:Real}; endpoint_baseline::Bool=true
)
    length(x) == length(y) ||
        throw(ArgumentError("resonance_dip: x and y must have equal length"))
    length(x) >= 5 || throw(ArgumentError("resonance_dip: need at least 5 points"))
    issorted(x) || throw(ArgumentError("resonance_dip: x must be sorted ascending"))

    i = argmin(y)
    (i == firstindex(y) || i == lastindex(y)) &&
        throw(ArgumentError("resonance_dip: minimum is on an endpoint — no dip is bracketed"))

    y_min = float(y[i])
    x_min = float(x[i])

    # Parabolic vertex through (i-1, i, i+1). Guarded against a flat triple.
    xl, xc, xr = float(x[i - 1]), x_min, float(x[i + 1])
    yl, yc, yr = float(y[i - 1]), y_min, float(y[i + 1])
    d1 = (yr - yl) / (xr - xl)
    d2 = 2 * ((yr - yc) / (xr - xc) - (yc - yl) / (xc - xl)) / (xr - xl)
    center = d2 > 0 ? xc - d1 / d2 : xc

    base_left = endpoint_baseline ? float(y[begin]) : float(maximum(@view y[begin:i]))
    base_right = endpoint_baseline ? float(y[end]) : float(maximum(@view y[i:end]))
    depth_left = base_left - y_min
    depth_right = base_right - y_min

    half_left = _cross_half(x, y, i, base_left, y_min, -1)
    half_right = _cross_half(x, y, i, base_right, y_min, +1)

    (;
        center,
        minimum=y_min,
        x_min,
        depth_left,
        depth_right,
        half_left,
        half_right,
        width=half_right - half_left,
    )
end

# First crossing of the half-depth level walking outward from the minimum.
function _cross_half(x, y, i, baseline, y_min, dir::Int)
    level = (baseline + y_min) / 2
    j = i
    while true
        k = j + dir
        (k < firstindex(y) || k > lastindex(y)) && throw(
            ArgumentError(
                "resonance_dip: y never returns to half depth on the " *
                (dir < 0 ? "left" : "right") *
                " — widen the scan",
            ),
        )
        if y[k] >= level
            t = (level - y[j]) / (y[k] - y[j])
            return float(x[j]) + t * (float(x[k]) - float(x[j]))
        end
        j = k
    end
end

export resonance_dip
