# --- Multi-fidelity Bayesian optimisation (R33, 2026-05-02) ---
#
# Two-tier MFBO via Forrester-style discrepancy modelling. We have:
#   - `eval_low(p)`  : cheap (low-resolution / few-step) surrogate.
#   - `eval_high(p)` : expensive (production-grade) objective.
#
# Both share the same parameter space and the same physical observable.
# `eval_low` is biased — different grid resolution / step count produces
# a slightly different optimum — but its bias is *correlated across
# parameter space*, so a residual GP δ(x) = y_high(x) - y_low(x) fitted
# on paired evaluations carries that bias.
#
# Model
# -----
#   y_low(x)  ~ GP(μ_low,  Matérn-5/2)        (fitted from many cheap evals)
#   δ(x)       ~ GP(μ_δ,    Matérn-5/2)        (fitted from PAIRED evals)
#   y_high(x) ≈ y_low(x) + δ(x)
#   μ_high(x) = μ_low(x) + μ_δ(x)
#   σ²_high(x) = σ²_low(x) + σ²_δ(x)            (independent contributions)
#
# Acquisition
# -----------
# Cost-aware EI: maximise EI(x, fidelity_high) / cost(query). Two
# candidate query types are scored:
#   - low-fidelity at x:  cost = 1, target = y_high (via discrepancy)
#   - high-fidelity at x: cost = `cost_ratio`, target = y_high
# whichever yields the larger EI / cost wins. High-fidelity queries
# always come PAIRED with the matching low-fidelity query (so δ stays
# well-conditioned).
#
# Cost-saving expectation
# -----------------------
# Biswas-Kalinin 2024 (Ising-model MFBO) reports 73-86 % cost reduction
# vs single-fidelity BO at the same final accuracy. For SpinorBEC phase
# scans where coarse 16³ ≈ 30 s and full 32³ ≈ 30 min (cost ratio ~ 60),
# the same scaling argument predicts the high-fidelity budget gets
# concentrated near the optimum.
#
# This is a deliberately small, dependency-free implementation. Higher-
# tier-count MFBO, BoTorch-style trust-region acquisition, or knowledge-
# gradient acquisition would need a proper BO library.

using Random

"""
    MultiFidelityBOResult

Returned by `multi_fidelity_optimize_2tier`. Captures every queried point
plus the high-fidelity prediction at convergence so callers can audit
which tier the budget went to.
"""
struct MultiFidelityBOResult
    best_p::Vector{Float64}
    best_y::Float64
    X_high::Matrix{Float64}
    y_high::Vector{Float64}
    X_low::Matrix{Float64}
    y_low::Vector{Float64}
    n_evals_high::Int
    n_evals_low::Int
    total_cost::Float64
end

"""
    multi_fidelity_optimize_2tier(eval_low, eval_high, bounds; …) → MultiFidelityBOResult

Two-tier MFBO using a discrepancy GP `δ(x) = y_high - y_low` fitted from
paired evaluations.

Arguments
=========
- `eval_low(p::Vector)::Real`  — cheap surrogate (e.g. coarse-grid GS)
- `eval_high(p::Vector)::Real` — expensive true objective (e.g. full-grid GS)
- `bounds = [(lo₁,hi₁), …]`     — search box in real coordinates

Keyword arguments
=================
- `cost_ratio = 10.0`        — `cost(high) / cost(low)`. Drives tier balance.
- `n_init_low = 10`          — number of low-fidelity warmup samples
- `n_init_high = 3`          — number of *paired* high-fidelity warmup samples
                              (each also evaluates `eval_low` at the same `p`)
- `n_iter = 25`              — total acquisition iterations after warmup
- `budget_high = 10`         — hard cap on extra `eval_high` calls beyond warmup
- `minimise = true`          — if `false`, maximise instead
- `ℓ = nothing`              — kernel length scale (defaults to 30 % of box)
- `n_grid = 50`              — per-axis acquisition mesh resolution (d ≤ 3)
- `seed = 42`                — RNG seed for warmup placement
- `verbose = true`           — print per-iteration status

Acquisition
===========
At each iteration, the candidate `(x, tier)` maximising
`EI_high(x) / cost(tier)` is queried. High-fidelity queries are paired
(both `eval_low` and `eval_high` are called) so the discrepancy GP gets
new training data simultaneously.

Returns the best `p` evaluated at high fidelity, along with full
histories.
"""
function multi_fidelity_optimize_2tier(
    eval_low::Function,
    eval_high::Function,
    bounds::Vector{Tuple{Float64, Float64}};
    cost_ratio::Float64=10.0,
    n_init_low::Int=10,
    n_init_high::Int=3,
    n_iter::Int=25,
    budget_high::Int=10,
    minimise::Bool=true,
    ℓ::Union{Nothing, Float64}=nothing,
    n_grid::Int=50,
    seed::Int=42,
    verbose::Bool=true,
)
    d = length(bounds)
    rng = MersenneTwister(seed)

    # --- Warmup ---
    # n_init_low cheap samples (Latin-hypercube-ish random)
    X_low = zeros(Float64, n_init_low, d)
    for i in 1:n_init_low, j in 1:d
        X_low[i, j] = bounds[j][1] + rand(rng) * (bounds[j][2] - bounds[j][1])
    end
    y_low = [Float64(eval_low(X_low[i, :])) for i in 1:n_init_low]

    # n_init_high paired (low + high) samples — random subset of the low set so the
    # δ GP has training data right away.
    paired_idx = randperm(rng, n_init_low)[1:min(n_init_high, n_init_low)]
    X_high = zeros(Float64, length(paired_idx), d)
    y_high = zeros(Float64, length(paired_idx))
    for (k, i) in enumerate(paired_idx)
        X_high[k, :] = X_low[i, :]
        y_high[k] = Float64(eval_high(X_high[k, :]))
    end

    cost_used = n_init_low * 1.0 + length(paired_idx) * cost_ratio
    if verbose
        println("MFBO warmup: $n_init_low low + $(length(paired_idx)) paired high " *
                "(cost = $(round(cost_used; digits=1)))")
    end

    # Default kernel length scale: 30 % of box width (dimension-averaged)
    ℓ_use =
        ℓ === nothing ? mean(bounds[j][2] - bounds[j][1] for j in 1:d) * 0.3 : ℓ

    axis_grids = [collect(range(b[1], b[2]; length=n_grid)) for b in bounds]
    candidates = _box_grid(axis_grids)

    n_high_extra = 0
    for it in 1:n_iter
        # Best high-fidelity y observed so far (target for EI).
        y_best_high = isempty(y_high) ?
                      (minimise ? Inf : -Inf) :
                      (minimise ? minimum(y_high) : maximum(y_high))

        # Posterior at every candidate, both at high-fidelity (via discrepancy)
        # and at low-fidelity directly.
        μ_low_at_cand, σ²_low_at_cand = gp_predict(X_low, y_low, candidates; ℓ=ℓ_use)
        μ_high_at_cand, σ²_high_at_cand = _high_posterior(
            X_low, y_low, X_high, y_high, candidates; ℓ=ℓ_use,
        )

        # EI for *high-fidelity* y at each candidate (since high is the truth)
        ei_high = expected_improvement(
            μ_high_at_cand, σ²_high_at_cand, y_best_high; minimise=minimise,
        )
        # EI for *low-fidelity* y is irrelevant in isolation, but a low-fidelity
        # query still updates the y_low GP and (via discrepancy mean) the
        # high-fidelity prediction. Approximate the value of a low-query at x as
        # the prospective EI at x's *high* prediction *after* the low data
        # arrives — but cheaply we use ei_high(x) directly. The cost-discount
        # then rewards low queries naturally.

        ei_per_cost_low = ei_high ./ 1.0          # cost = 1
        ei_per_cost_high = ei_high ./ cost_ratio  # cost = cost_ratio

        # Pick the (candidate, tier) maximising EI / cost.
        i_low = argmax(ei_per_cost_low)
        i_high = argmax(ei_per_cost_high)
        score_low = ei_per_cost_low[i_low]
        score_high = ei_per_cost_high[i_high]

        # Don't run high tier if budget exhausted.
        budget_left = budget_high - n_high_extra
        if budget_left <= 0 && score_low > 0
            chose_high = false
        else
            chose_high = score_high >= score_low
        end

        if chose_high
            p_next = candidates[i_high, :]
            y_low_new = Float64(eval_low(p_next))
            y_high_new = Float64(eval_high(p_next))
            X_low = vcat(X_low, p_next')
            push!(y_low, y_low_new)
            X_high = vcat(X_high, p_next')
            push!(y_high, y_high_new)
            n_high_extra += 1
            cost_used += 1.0 + cost_ratio
            verbose && println(
                "iter $it tier=high p=$(round.(p_next; digits=3)) " *
                "y_low=$(round(y_low_new; digits=4)) " *
                "y_high=$(round(y_high_new; digits=4)) " *
                "cost=$(round(cost_used; digits=1))",
            )
        else
            p_next = candidates[i_low, :]
            y_low_new = Float64(eval_low(p_next))
            X_low = vcat(X_low, p_next')
            push!(y_low, y_low_new)
            cost_used += 1.0
            verbose && println(
                "iter $it tier=low  p=$(round.(p_next; digits=3)) " *
                "y_low=$(round(y_low_new; digits=4)) " *
                "cost=$(round(cost_used; digits=1))",
            )
        end
    end

    # Final answer: best high-fidelity sample observed.
    i_opt = isempty(y_high) ? 1 : (minimise ? argmin(y_high) : argmax(y_high))
    best_p = isempty(y_high) ? X_low[1, :] : X_high[i_opt, :]
    best_y = isempty(y_high) ?
             (minimise ? minimum(y_low) : maximum(y_low)) :
             y_high[i_opt]

    MultiFidelityBOResult(
        best_p, best_y,
        X_high, y_high, X_low, y_low,
        size(X_high, 1), size(X_low, 1),
        cost_used,
    )
end

"""
Posterior over high-fidelity y at `X_test` via the discrepancy GP:

    y_high(x) ≈ y_low(x) + δ(x)
    μ_high     = μ_low    + μ_δ
    σ²_high    = σ²_low   + σ²_δ

`X_high, y_high` and the `δ` training data are derived as
`δ_i = y_high[i] - y_low_at(X_high[i, :])`, where `y_low_at` is the
posterior mean of the low GP at `X_high[i, :]`.

Falls back to the low GP alone when no high-fidelity data exists yet.
"""
function _high_posterior(
    X_low::AbstractMatrix{<:Real}, y_low::AbstractVector{<:Real},
    X_high::AbstractMatrix{<:Real}, y_high::AbstractVector{<:Real},
    X_test::AbstractMatrix{<:Real};
    ℓ::Float64=1.0,
    σ²::Float64=1.0,
    σ_noise::Float64=1.0e-3,
)
    μ_low_t, σ²_low_t = gp_predict(X_low, y_low, X_test; ℓ, σ², σ_noise)

    isempty(y_high) && return μ_low_t, σ²_low_t

    # Discrepancy training set
    μ_low_h, _ = gp_predict(X_low, y_low, X_high; ℓ, σ², σ_noise)
    δ_train = y_high .- μ_low_h
    μ_δ, σ²_δ = gp_predict(X_high, δ_train, X_test; ℓ, σ², σ_noise)

    μ_high = μ_low_t .+ μ_δ
    σ²_high = σ²_low_t .+ σ²_δ
    μ_high, σ²_high
end
