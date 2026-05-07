# --- Generic observed-vs-simulated comparison API ---
#
# A single `compare(observed, simulated; metric, normalize, mask)` entry
# point that lets fit drivers (faraday_fit, bayesian_optimize) and ad-hoc
# data-vs-sim plotting code share one well-tested loss-function stack
# instead of each rolling its own L².
#
# Metrics
# -------
# `:l2`              ‖o − s‖₂² / N       (default — same as the previous
#                                         hand-rolled Faraday loss)
# `:l1`              ‖o − s‖₁ / N
# `:linf`            max |o − s|
# `:relative_l2`     Σ (oᵢ − sᵢ)² / max(oᵢ², ε)   (per-pixel relative)
# `:cosine`          1 − ⟨o, s⟩ / (‖o‖ ‖s‖)       (shape only)
# `:correlation`     1 − corr(o, s)                (Pearson, shape + sign)
# `:chi_squared`     Σ (oᵢ − sᵢ)² / max(|oᵢ|, ε)  (Poisson-noise prior)
# `:wasserstein_1d`  Σ |Fₒ(x) − Fₛ(x)| · Δx       (1-D EMD via CDF)
#
# Normalisation (applied independently to o and s before metric)
# --------------------------------------------------------------
# `:none`      pass through unchanged
# `:unit`      x ← x / ‖x‖₂                       (default — scale-invariant)
# `:max`       x ← x / max(|x|)                   (peak-normalised)
# `:integral`  x ← x / Σ x                        (probability-density form;
#                                                  required for Wasserstein)
#
# Mask
# ----
# Optional `BitArray` (or any AbstractArray of `Bool`) the same shape as
# `observed`. When supplied, only entries with `mask[i] == true` enter the
# metric. Typical use: limit the comparison to the cloud support so the
# vacuum noise floor doesn't dominate the loss.

"""
    normalize_field(x; method=:unit) → Array

Return a normalised copy of `x` according to `method` (see file header).
Zero-magnitude inputs are passed through unchanged so the caller never
sees a divide-by-zero NaN; the metric will then see the original 0 and
behave consistently.
"""
function normalize_field(x::AbstractArray{<:Real}; method::Symbol=:unit)
    if method === :none
        return Array(x)
    elseif method === :unit
        n = sqrt(sum(abs2, x))
        return n > 0 ? Array(x) ./ n : Array(x)
    elseif method === :max
        m = maximum(abs, x)
        return m > 0 ? Array(x) ./ m : Array(x)
    elseif method === :integral
        s = sum(x)
        return s > 0 ? Array(x) ./ s : Array(x)
    else
        throw(
            ArgumentError(
                "normalize method must be :none, :unit, :max, or :integral, got :$method"
            )
        )
    end
end

"""
    compare(observed, simulated; metric=:l2, normalize=:unit, mask=nothing,
            relative_eps=1e-12) → Float64

Scalar loss between two arrays of equal shape. See file header for the
metric and normalisation list. Smaller is better for every metric. The
returned value is `Float64` so it can be fed straight into 1-D
golden-section, n-D Bayesian optimisation, or any other minimiser.

Throws `DimensionMismatch` if `observed` and `simulated` differ in shape,
or if `mask` is given and doesn't match.
"""
function compare(
    observed::AbstractArray{<:Real},
    simulated::AbstractArray{<:Real};
    metric::Symbol=:l2,
    normalize::Symbol=:unit,
    mask::Union{Nothing, AbstractArray}=nothing,
    relative_eps::Float64=1e-12,
)
    size(observed) == size(simulated) ||
        throw(
            DimensionMismatch(
                "observed $(size(observed)) and simulated $(size(simulated)) shapes differ"
            ),
        )
    if mask !== nothing
        size(mask) == size(observed) ||
            throw(
                DimensionMismatch(
                    "mask shape $(size(mask)) does not match observed $(size(observed))"
                ),
            )
    end

    # Wasserstein needs probability-density inputs, normalisation can't
    # cancel that downstream, so enforce it.
    if metric === :wasserstein_1d && normalize !== :integral
        normalize = :integral
    end

    o = normalize_field(observed; method=normalize)
    s = normalize_field(simulated; method=normalize)

    if mask !== nothing
        idx = findall(mask)
        isempty(idx) && return 0.0
        o = o[idx]
        s = s[idx]
    end

    if metric === :l2
        return sum(abs2, o .- s) / length(o)
    elseif metric === :l1
        return sum(abs, o .- s) / length(o)
    elseif metric === :linf
        return maximum(abs, o .- s)
    elseif metric === :relative_l2
        # Per-pixel relative residual; floor by max(o², ε) so empty
        # cells (o ≈ 0) don't produce 0/0 spikes.
        diff_sq = (o .- s) .^ 2
        scale = max.(o .^ 2, relative_eps)
        return sum(diff_sq ./ scale) / length(o)
    elseif metric === :cosine
        no = sqrt(sum(abs2, o))
        ns = sqrt(sum(abs2, s))
        (no == 0 || ns == 0) && return 1.0
        return 1.0 - sum(o .* s) / (no * ns)
    elseif metric === :correlation
        ō = sum(o) / length(o)
        s̄ = sum(s) / length(s)
        do_ = o .- ō
        ds = s .- s̄
        no = sqrt(sum(abs2, do_))
        ns = sqrt(sum(abs2, ds))
        (no == 0 || ns == 0) && return 1.0
        return 1.0 - sum(do_ .* ds) / (no * ns)
    elseif metric === :chi_squared
        scale = max.(abs.(o), relative_eps)
        return sum((o .- s) .^ 2 ./ scale) / length(o)
    elseif metric === :wasserstein_1d
        # 1-D Earth-mover via CDF integral. Inputs must be 1-D
        # (or get flattened) and already integral-normalised above.
        ndims(observed) == 1 ||
            throw(ArgumentError("wasserstein_1d requires 1-D inputs (got $(ndims(observed))D)"))
        F_o = cumsum(o)
        F_s = cumsum(s)
        return sum(abs.(F_o .- F_s))
    else
        throw(
            ArgumentError(
                "unknown metric :$metric. Valid: :l2, :l1, :linf, :relative_l2, " *
                ":cosine, :correlation, :chi_squared, :wasserstein_1d",
            ),
        )
    end
end
