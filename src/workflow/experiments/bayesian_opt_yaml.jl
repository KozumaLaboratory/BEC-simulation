"""
Bayesian optimization wired through the YAML pipeline interface.

`bayesian_optimize_yaml` takes a YAML config, a list of override paths
(dotted keys into the YAML dict, same format as `scan:` block), and a list
of bounds. Each BO evaluation:

  1. Apply the candidate point as overrides to the YAML dict
  2. Re-parse and run the pipeline via `run_config`
  3. Apply the user-supplied `objective_fn(result) → Float64` to score
  4. BO selects the next point to evaluate (Matérn 5/2 GP + EI acquisition)

This is the production integration for parameter scans whose target
quantity is non-trivial enough that uniform/Latin sweeps are wasteful —
e.g. find c1 that maximizes m=+F-1 transfer in Klaus magnetostir.

`bounds` is a Vector{Tuple{Float64,Float64}} matching `override_paths`
length. `objective_fn` takes the pipeline result NamedTuple and returns
a Float64. By default `minimise=false` (BO maximises).
"""
function bayesian_optimize_yaml(
    yaml_path::AbstractString,
    override_paths::Vector{<:AbstractString},
    bounds::Vector{Tuple{Float64, Float64}};
    objective_fn::Function,
    n_init::Int=5,
    n_iter::Int=25,
    minimise::Bool=false,
    ℓ::Union{Nothing, Float64}=nothing,
    n_grid::Int=20,
    seed::Int=42,
    verbose::Bool=true,
    save_history_to::Union{Nothing, AbstractString}=nothing,
)
    length(override_paths) == length(bounds) || throw(ArgumentError(
        "override_paths and bounds must have same length"))

    base_dict = YAML.load_file(yaml_path; dicttype=Dict{String, Any})

    eval_count = Ref(0)
    function eval_fn(p::AbstractVector{Float64})
        eval_count[] += 1
        # Build override dict from candidate point
        overrides = OverrideMap()
        for (path, val) in zip(override_paths, p)
            overrides[path] = val
        end
        # Apply to fresh copy of base_dict
        modified = apply_overrides(base_dict, overrides)
        # Run pipeline in-memory (no caching to disk for BO speed)
        config = parse_pipeline(modified)
        if verbose
            println("  [eval $(eval_count[])] params: ",
                    join(["$(p_)=$(round(v_; digits=4))" for (p_, v_) in zip(override_paths, p)], ", "))
        end
        result = run_pipeline(config; verbose=false)
        score = Float64(objective_fn(result))
        if verbose
            println("  [eval $(eval_count[])] objective: $(round(score; digits=6))")
        end
        score
    end

    res = bayesian_optimize(eval_fn, bounds;
        n_init, n_iter, minimise, ℓ, n_grid, seed, verbose)

    if save_history_to !== nothing
        # Save BO trajectory for post-mortem / convergence plots
        JLD2.jldsave(save_history_to;
            best_p = res.best_p,
            best_y = res.best_y,
            X_history = res.X_history,
            y_history = res.y_history,
            override_paths = collect(override_paths),
            bounds = bounds,
            yaml_path = yaml_path,
            n_init = n_init,
            n_iter = n_iter,
            minimise = minimise,
        )
        verbose && println("History saved to: $save_history_to")
    end

    res
end

"""
    bo_objective_max_m_transfer(result; m_target=2)

Convenience: extract `1 - N_{m=+F}` from a rotating_basis dynamics result,
i.e. the total population that left the initial m=+F state. Higher score
= more spin transfer, so use with `minimise=false`.
"""
function bo_objective_max_m_transfer(result)
    haskey(result, :rotating_basis_dynamics) || throw(ArgumentError(
        "result has no :rotating_basis_dynamics; pipeline must end with rotating_basis dynamics"))
    dyn = result[:rotating_basis_dynamics]::Dict
    pm = dyn[:per_m_history][end]::Vector{Float64}
    1.0 - pm[1] / sum(pm)
end

"""
    bo_objective_max_lz(result)

Maximise final |⟨L_z⟩| in the rotating_basis dynamics result.
"""
function bo_objective_max_lz(result)
    haskey(result, :rotating_basis_dynamics) || throw(ArgumentError(
        "result has no :rotating_basis_dynamics"))
    dyn = result[:rotating_basis_dynamics]::Dict
    abs(dyn[:Lz][end])
end

"""
    bo_objective_min_energy(result)

Minimise final ground-state μ from a rotating_basis_ground_state step.
Useful for ε_dd/c1 calibration runs where one wants the lowest-energy GS.
"""
function bo_objective_min_energy(result)
    haskey(result, :rotating_basis_mu) || throw(ArgumentError(
        "result has no :rotating_basis_mu (need a ground_state step)"))
    Float64(result[:rotating_basis_mu])
end
