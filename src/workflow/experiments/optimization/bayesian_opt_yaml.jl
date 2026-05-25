export bayesian_optimize_yaml, multi_fidelity_optimize_yaml
export bo_objective_max_m_transfer, bo_objective_max_lz, bo_objective_min_energy

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
                join(["$(p_)=$(round(v_; digits=4))" for (p_, v_) in zip(override_paths, p)], ", "),
            )
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
            best_p=res.best_p,
            best_y=res.best_y,
            X_history=res.X_history,
            y_history=res.y_history,
            override_paths=collect(override_paths),
            bounds=bounds,
            yaml_path=yaml_path,
            n_init=n_init,
            n_iter=n_iter,
            minimise=minimise,
        )
        verbose && println("History saved to: $save_history_to")
    end

    res
end

"""
    multi_fidelity_optimize_yaml(yaml_path, override_paths, bounds;
                                 objective_fn,
                                 low_overrides::OverrideMap,
                                 high_overrides::OverrideMap=OverrideMap(),
                                 cost_ratio=10.0, n_init_low=10, n_init_high=3,
                                 n_iter=20, budget_high=8, minimise=false, …)
        → MultiFidelityBOResult

Two-tier MFBO wired through the YAML pipeline. Like
`bayesian_optimize_yaml` but with a CHEAP surrogate fidelity (e.g.
coarse 12³ grid, fewer ITP steps) used most of the time, anchored to
the production-grade fidelity by a discrepancy GP.

`low_overrides` / `high_overrides` are `OverrideMap`s applied on top of
the candidate-point overrides at each evaluation. Typical usage for
SpinorBEC phase scans:

```julia
res = multi_fidelity_optimize_yaml(
    "runs/eu151_phase_diagram_lbfgs/config.yaml",
    ["pipeline.0.ground_state.B.p", "pipeline.0.ground_state.interactions[1]_ratio"],
    [(10.0, 1000.0), (-0.1, 0.1)];
    objective_fn = bo_objective_min_energy,
    low_overrides = Dict{String,Any}(
        "pipeline.0.ground_state.grid.n"  => [12, 12, 6],
        "pipeline.0.ground_state.n_steps" => 300,
    ),
    high_overrides = Dict{String,Any}(),   # use config-default high tier
    cost_ratio  = 30.0,
    n_init_low  = 12, n_init_high = 3,
    n_iter      = 25, budget_high = 8,
    minimise    = true,
)
```

The cheap-tier override list typically tightens grid resolution and
ITP step count. `cost_ratio` should reflect the actual wall-time
ratio (calibrate by running each tier once on a representative point).

See `multi_fidelity_optimize_2tier` for the underlying acquisition
strategy (cost-aware EI on a discrepancy GP).
"""
function multi_fidelity_optimize_yaml(
    yaml_path::AbstractString,
    override_paths::Vector{<:AbstractString},
    bounds::Vector{Tuple{Float64, Float64}};
    objective_fn::Function,
    low_overrides::OverrideMap,
    high_overrides::OverrideMap=OverrideMap(),
    cost_ratio::Float64=10.0,
    n_init_low::Int=10,
    n_init_high::Int=3,
    n_iter::Int=20,
    budget_high::Int=8,
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

    function _make_eval(fidelity_overrides::OverrideMap, label::String)
        eval_count = Ref(0)
        return function (p::AbstractVector{Float64})
            eval_count[] += 1
            cand = OverrideMap()
            for (path, val) in zip(override_paths, p)
                cand[path] = val
            end
            modified = apply_overrides(base_dict, cand, fidelity_overrides)
            config = parse_pipeline(modified)
            if verbose
                println("  [$label eval $(eval_count[])] params: ",
                    join(
                        ["$(p_)=$(round(v_; digits=4))" for (p_, v_) in zip(override_paths, p)],
                        ", ",
                    ))
            end
            result = run_pipeline(config; verbose=false)
            score = Float64(objective_fn(result))
            if verbose
                println("  [$label eval $(eval_count[])] objective: $(round(score; digits=6))")
            end
            score
        end
    end

    eval_low = _make_eval(low_overrides, "low")
    eval_high = _make_eval(high_overrides, "high")

    res = multi_fidelity_optimize_2tier(
        eval_low, eval_high, bounds;
        cost_ratio, n_init_low, n_init_high,
        n_iter, budget_high, minimise,
        ℓ, n_grid, seed, verbose,
    )

    if save_history_to !== nothing
        JLD2.jldsave(save_history_to;
            best_p=res.best_p,
            best_y=res.best_y,
            X_high=res.X_high,
            y_high=res.y_high,
            X_low=res.X_low,
            y_low=res.y_low,
            n_evals_high=res.n_evals_high,
            n_evals_low=res.n_evals_low,
            total_cost=res.total_cost,
            override_paths=collect(override_paths),
            bounds=bounds,
            yaml_path=yaml_path,
            cost_ratio=cost_ratio,
            n_init_low=n_init_low,
            n_init_high=n_init_high,
            n_iter=n_iter,
            budget_high=budget_high,
            minimise=minimise,
        )
        verbose && println("MFBO history saved to: $save_history_to")
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
    haskey(result, :rotating_basis_dynamics) || throw(
        ArgumentError(
            "result has no :rotating_basis_dynamics; pipeline must end with rotating_basis dynamics"
        ),
    )
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
