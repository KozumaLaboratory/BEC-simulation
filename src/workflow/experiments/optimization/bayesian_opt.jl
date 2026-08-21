# --- Phase 4 #61: real GP + Expected-Improvement Bayesian optimisation ---

export bayesian_optimize, gp_predict, expected_improvement

# Hand-rolled — no extra deps. Adequate for 1-3D parameter spaces with
# ~50-200 evaluations, which covers most SpinorBEC scan-replacement use
# cases (e.g. locating the supersolid critical point in (p, q)).
#
# For higher-dim spaces or noisy evaluations, swap in BayesianOptimization.jl.

using LinearAlgebra: cholesky, Symmetric, diag, I as IDENT
using Random
using SpecialFunctions: erf

# Matérn-5/2 kernel — smoother than RBF, suits physics objectives.
function _matern52(x, y; ℓ::Float64=1.0, σ²::Float64=1.0)
    r = sqrt(sum(((x .- y) ./ ℓ) .^ 2))
    σ² * (1 + sqrt(5) * r + 5/3 * r^2) * exp(-sqrt(5) * r)
end

"""
    gp_predict(X_train, y_train, X_test; ℓ, σ², σ_noise)

Closed-form Gaussian Process posterior mean + variance at `X_test`,
given training data `(X_train, y_train)`. Returns `(μ, σ²)` vectors.
"""
function gp_predict(
    X_train::AbstractMatrix{<:Real},
    y_train::AbstractVector{<:Real},
    X_test::AbstractMatrix{<:Real};
    ℓ::Float64=1.0,
    σ²::Float64=1.0,
    σ_noise::Float64=1e-3,
)
    n, d = size(X_train)
    m = size(X_test, 1)
    K11 = [_matern52(X_train[i, :], X_train[j, :]; ℓ, σ²) for i in 1:n, j in 1:n]
    K11 .+= σ_noise^2 .* IDENT(n)
    K12 = [_matern52(X_train[i, :], X_test[j, :]; ℓ, σ²) for i in 1:n, j in 1:m]
    K22 = [_matern52(X_test[i, :], X_test[j, :]; ℓ, σ²) for i in 1:m, j in 1:m]
    L = cholesky(Symmetric(K11)).L
    α = L' \ (L \ y_train)
    μ = K12' * α
    v = L \ K12
    Σ = K22 .- v' * v
    σ²_pred = max.(diag(Σ), 0.0)
    return μ, σ²_pred
end

"""
    expected_improvement(μ, σ², y_best; minimise=true) -> Vector{Float64}

EI acquisition function. Higher value = better candidate.
"""
function expected_improvement(μ, σ², y_best; minimise::Bool=true)
    σ = sqrt.(σ²)
    Δ = minimise ? (y_best .- μ) : (μ .- y_best)
    z = Δ ./ max.(σ, 1e-12)
    Φ = 0.5 .* (1 .+ erf.(z ./ sqrt(2)))
    φ = exp.(-0.5 .* z .^ 2) ./ sqrt(2π)
    Δ .* Φ .+ σ .* φ
end

"""
    bayesian_optimize(eval_fn, bounds; n_init=5, n_iter=25, minimise=true,
                      ℓ=nothing, n_grid=100, seed=42)

Sequential Bayesian optimisation. `eval_fn(p::Vector)::Real` returns the
objective at parameter vector `p`; `bounds = [(lo₁, hi₁), (lo₂, hi₂), …]`
defines the search box.

The acquisition (EI) is maximised over a uniform `n_grid^d` candidate
mesh — fine for d ≤ 3. For larger d, replace `_grid_argmax_ei` with a
gradient-based search.

Returns `(best_p, best_y, X_history, y_history)`. Each evaluation cost
matters (one SpinorBEC run = ~minutes), so even ~30 iterations buy
significant compute savings vs a grid sweep.
"""
function bayesian_optimize(
    eval_fn::Function,
    bounds::Vector{Tuple{Float64, Float64}};
    n_init::Int=5,
    n_iter::Int=25,
    # A BUDGET IS NOT A STOPPING RULE. `n_iter` alone answers "when do we stop?"
    # with "when the loop counter runs out", and the returned object looked the
    # same either way — so a map that ran out of budget read as a finished map.
    # `acq_tol` is the declared criterion: the acquisition value at the point the
    # scan is ABOUT to sample is how much the model still expects to learn, so
    # when the most informative point left in the whole domain is below tolerance
    # for `acq_patience` consecutive iterations, there is nothing left to learn at
    # this resolution. Default `nothing` keeps the old behaviour and still reports
    # `:budget_exhausted`, which is the half that matters most.
    acq_tol::Union{Nothing, Float64}=nothing,
    acq_patience::Int=3,
    minimise::Bool=true,
    ℓ::Union{Nothing, Float64}=nothing,
    n_grid::Int=100,
    seed::Int=42,
    verbose::Bool=_default_solver_verbose(),
)
    d = length(bounds)
    rng = MersenneTwister(seed)
    # Latin Hypercube-ish init via random points in the box
    X = zeros(Float64, n_init, d)
    for i in 1:n_init, j in 1:d
        X[i, j] = bounds[j][1] + rand(rng) * (bounds[j][2] - bounds[j][1])
    end
    y = [Float64(eval_fn(X[i, :])) for i in 1:n_init]
    verbose && for i in 1:n_init
        println("init $i: p=$(round.(X[i, :]; digits=3)) y=$(round(y[i]; digits=4))")
    end

    # Default length scale: 30% of box width
    ℓ_use = ℓ === nothing ?
            mean(bounds[j][2] - bounds[j][1] for j in 1:d) * 0.3 : ℓ

    # Pre-build candidate mesh
    axis_grids = [collect(range(b[1], b[2]; length=n_grid)) for b in bounds]

    acq_history = Float64[]
    stop_reason = :budget_exhausted
    below = 0
    for it in 1:n_iter
        y_best = minimise ? minimum(y) : maximum(y)
        # Evaluate EI on a grid
        candidates = _box_grid(axis_grids)
        μ, σ² = gp_predict(X, y, candidates; ℓ=ℓ_use)
        ei = expected_improvement(μ, σ², y_best; minimise=minimise)
        i_best = argmax(ei)
        acq = ei[i_best]
        push!(acq_history, acq)
        p_next = candidates[i_best, :]
        y_next = Float64(eval_fn(p_next))
        X = vcat(X, p_next')
        push!(y, y_next)
        verbose && println(
            "iter $it: p=$(round.(p_next; digits=3)) y=$(round(y_next; digits=4)) " *
            "best=$(round(minimise ? minimum(y) : maximum(y); digits=4)) " *
            "acq=$(round(acq; sigdigits=3))",
        )

        # Checked AFTER the sample, not before: the acquisition value describes
        # the point just taken, so stopping on it without taking it would discard
        # the evaluation that justified the decision.
        if acq_tol !== nothing
            below = acq < acq_tol ? below + 1 : 0
            if below >= acq_patience
                stop_reason = :acquisition_below_tol
                verbose && println(
                    "stopping: acquisition < $(acq_tol) for $(acq_patience) " *
                    "consecutive iterations (iter $it of $n_iter)")
                break
            end
        end
    end

    i_opt = minimise ? argmin(y) : argmax(y)
    # `stop_reason` is not decoration. `:budget_exhausted` means the scan was cut
    # off, and a caller that treats it as `:acquisition_below_tol` is reporting a
    # truncation as a result — the same shape as an absent convergence flag
    # written as `true`.
    return (best_p=X[i_opt, :], best_y=y[i_opt], X_history=X, y_history=y,
        stop_reason=stop_reason, n_evaluations=length(y), acq_history=acq_history)
end

# Build a regular d-dim mesh from per-axis 1D grids; rows are points.
function _box_grid(axis_grids::Vector{Vector{Float64}})
    d = length(axis_grids)
    iters = Iterators.product(axis_grids...)
    n_total = prod(length.(axis_grids))
    M = zeros(Float64, n_total, d)
    for (i, pt) in enumerate(iters)
        M[i, :] .= collect(pt)
    end
    M
end

# Tiny helper since we don't import Statistics
mean(itr) = sum(itr) / length(collect(itr))
