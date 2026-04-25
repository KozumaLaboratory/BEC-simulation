# Bayesian-optimization scaffold for SpinorBEC parameter scans (#61).
#
# Status: PROOF OF CONCEPT — does NOT call out to a real GP/EI library.
# The point is to pin down the loop shape so the next contributor only
# has to wire in `BayesianOptimization.jl` or `Surrogates.jl`.
#
# Real impl plan:
#   1. Pick `BayesianOptimization.jl` (simpler) or `Surrogates.jl`
#      (more flexible, async-friendly).
#   2. The objective function = run_yaml on a single-point config with
#      the proposal substituted via apply_override!, then read a scalar
#      from the per-point .jld2 (e.g. analyze/bogoliubov/max_growth).
#   3. Async dispatch so the GP doesn't block waiting for the 4-min eval.
#   4. Maintain a JSON history file so resuming = reading past evals.

using SpinorBEC
using Random

# --- Toy 1D objective ---------------------------------------------------
# Pretend this is "find the supersolid critical p at q=0.3 by maximising
# the Bogoliubov max_growth". Real version reads from .jld2.
toy_objective(p::Float64) = exp(-(p - 1.7)^2 / 0.5) + 0.3 * randn()

# --- Hand-rolled "GP-EI" placeholder ------------------------------------
# Maintains an empirical mean over a grid and picks the grid point with
# the highest UCB-style score. Replace with a real GP.
function placeholder_propose(history::Vector{Tuple{Float64,Float64}};
                              candidates = 0.0:0.1:5.0,
                              κ::Float64 = 1.5)
    isempty(history) && return rand(candidates)
    means = Dict(p => mean_at(history, p) for p in candidates)
    n_at = Dict(p => count(==(p), first.(history)) for p in candidates)
    ucb = Dict(p => means[p] + κ * sqrt(log(length(history) + 1) / max(n_at[p], 1))
               for p in candidates)
    findmax(ucb)[2]
end

mean_at(hist, p) = isempty(filter(x -> x[1] == p, hist)) ? 0.0 :
    sum(x[2] for x in hist if x[1] == p) / count(x -> x[1] == p, hist)

# --- Smoke loop --------------------------------------------------------
function main(n_iter::Int = 30)
    Random.seed!(42)
    history = Tuple{Float64,Float64}[]
    for i in 1:n_iter
        p_next = placeholder_propose(history)
        y = toy_objective(p_next)
        push!(history, (p_next, y))
        @info "iter $i" p = p_next y = round(y; digits = 3) best = round(maximum(last, history); digits = 3)
    end
    best_p, best_y = argmax(last, history) |> identity, maximum(last, history)
    println("\nBest: p = $(best_p)  y = $(round(best_y; digits = 3))  (true peak ≈ 1.7)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(parse(Int, get(ARGS, 1, "30")))
end
