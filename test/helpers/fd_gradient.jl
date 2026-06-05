# Directional finite-difference estimator with ε-scaling valley
# diagnostics. Implements docs/design/term_oracle_bootstrap.md §1–§3.
#
# Canonical gradient pin (§1): the canonical object is the per-voxel
# density g = δE/δψ̄ — no dV, no Wirtinger ×2. For a real functional E
# and a complex direction δ,
#
#     d/dh E(ψ + h·δ) |_{h=0} = 2·dV·Re⟨g, δ⟩.
#
# `canonical_projection` is the single place that formula lives;
# `fd_directional` is its finite-difference counterpart; `fd_valley`
# classifies their disagreement as truncation (healthy valley /
# exact floor) vs bug (h-independent plateau).
#
# Complex-step differentiation is deliberately absent: E contains
# conjugation and is not holomorphic (§1).

using Random: AbstractRNG

"""
    fd_directional(E, ψ, δ, h) -> Float64

Central-difference directional derivative of the scalar functional `E`
along the complex direction `δ`: `(E(ψ + h·δ) − E(ψ − h·δ)) / 2h`.
"""
fd_directional(E, ψ, δ, h) = (E(ψ .+ h .* δ) - E(ψ .- h .* δ)) / (2h)

"""
    canonical_projection(g, δ, dV) -> Float64

Analytic counterpart of `fd_directional`: `2·dV·Re⟨g, δ⟩` for the
canonical per-voxel gradient density `g = δE/δψ̄`. The Wirtinger ×2
and the dV clause live HERE and nowhere else in the harness.
"""
canonical_projection(g, δ, dV) = 2 * dV * real(sum(conj.(g) .* δ))

const FD_H_DECADES = [10.0^k for k in -1.0:-1.0:-8.0]

"""
    fd_valley(E, ψ, δ, ref; hs=FD_H_DECADES, floor_tol=1e-9) -> NamedTuple

ε-scaling sweep (§3). `rel_err(h) = |fd_directional(E,ψ,δ,h) − ref| /
max(|ref|, eps())` over decades of h. Returns
`(hs, errs, min_err, i_min, slope, kind)` with

- `kind = :exact_floor` — already at roundoff for the LARGEST h: E is
  (at most) quadratic along δ, central FD is exact up to roundoff.
  Healthy, and stronger than a valley.
- `kind = :valley` — truncation descent into a floor below 1e-7;
  healthy nonlinear-E pair. `slope` is the log-log LSQ fit over the
  truncation band (indices 2 .. i_min−1; NaN when < 2 points) and
  should be ≈ +2 for central differences.
- `kind = :plateau` — h-independent disagreement: the reference and the
  FD measure different derivatives. Real bug; magnitude of the plateau
  ≈ relative size of the bug (factor 2 ⇒ ~0.5, sign flip ⇒ ~2).
"""
function fd_valley(E, ψ, δ, ref; hs=FD_H_DECADES, floor_tol=1e-9)
    scale = max(abs(ref), eps())
    errs = [abs(fd_directional(E, ψ, δ, h) - ref) / scale for h in hs]
    i_min = argmin(errs)
    min_err = errs[i_min]
    if errs[1] < floor_tol
        return (; hs, errs, min_err, i_min, slope=NaN, kind=:exact_floor)
    end
    band = 2:(i_min - 1)
    slope = if length(band) >= 2
        xs = log10.(hs[band])
        ys = log10.(max.(errs[band], eps()))
        x̄ = sum(xs) / length(xs)
        ȳ = sum(ys) / length(ys)
        sum((xs .- x̄) .* (ys .- ȳ)) / sum(abs2, xs .- x̄)
    else
        NaN
    end
    kind = min_err < 1e-7 ? :valley : :plateau
    return (; hs, errs, min_err, i_min, slope, kind)
end

"""
    aligned_direction(g, dV, ψ; rng, mix=0.5) -> (δ, ref)

Construct a test direction with guaranteed alignment to `g`:

    δ ∝ mix·ĝ + (1 − mix)·η̂,   η̂ random complex Gaussian (unit),

L²-rescaled to ‖δ‖ = ‖ψ‖ (so the h decades are *relative* perturbation
sizes and the truncation band is asymptotic). Deterministic
conditioning: |cos(g, δ)| ≈ mix/√(mix² + (1−mix)²) ≈ 0.7 at the
default, while the η̂ component keeps generic (off-g) directions
exercised.

Construction replaces the earlier rejection sampling, which was flaky
by dimensional analysis: for random δ in d ≈ 10³ real dimensions,
|cos| ~ 1/√d ≈ 0.03, so P(|cos| ≥ 0.05) ≈ 7% per draw — a 20-try
loop fails at suite level tens of percent of the time and misreports
the failure as "g ≈ 0".

Throws only if `g` is genuinely zero (an inactive term has no step0
pair — fix the fixture, §7).
"""
function aligned_direction(g, dV, ψ; rng::AbstractRNG, mix=0.5)
    nrm_g = sqrt(sum(abs2, g))
    nrm_g > 1e-300 || error(
        "aligned_direction: g ≡ 0 — the term is inactive in this " *
        "fixture and has no step0 pair (fix the fixture, §7).",
    )
    nrm_ψ = sqrt(sum(abs2, ψ))
    η = randn(rng, ComplexF64, size(g))
    η .*= inv(sqrt(sum(abs2, η)))
    δ = mix .* (g ./ nrm_g) .+ (1 - mix) .* η
    δ .*= nrm_ψ / sqrt(sum(abs2, δ))
    ref = canonical_projection(g, δ, dV)
    return δ, ref
end
