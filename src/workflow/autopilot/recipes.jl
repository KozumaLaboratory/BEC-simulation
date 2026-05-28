# ── Day-1 recipes ────────────────────────────────────────────────────
#
# Registered recipes shipped with the autopilot so the named-recipe
# machinery is not theatrical at first dispatch. None of these are
# decision-driving — they are mechanical proposals the operator
# audits at autonomy_level=:propose before promoting to :dispatch.
#
#   :next_random_in_bounds   one random sample inside a box around the
#                            current run's varied parameter. Pure
#                            exploration, no model.
#   :refine_around_best      compare this run's outcome to the historical
#                            best on a chosen metric and propose a tighter
#                            param around the winner. Greedy exploitation.
#   :analyze_majorana        analysis-only follow-up (no new sim) —
#                            re-runs the Majorana / polyhedral classifier
#                            on the just-finished result and tags the
#                            run dir. Useful as a smoke check before any
#                            new sim cycles.
#
# Adding a recipe = drop a function in this file + register at __init__.

using Random: MersenneTwister
import Base: get

export setup_default_recipes!,
    recipe_next_random_in_bounds, recipe_refine_around_best,
    recipe_analyze_majorana

# ── :next_random_in_bounds ──────────────────────────────────────────

"""
    recipe_next_random_in_bounds(entry, params) -> Vector{Experiment}

Sample one random point uniformly inside the box specified by
`params`. Required keys:

  - `path::Vector{String}`       dotted path into the spec to vary
  - `low::Float64`, `high::Float64`   bounds
  - `seed::Int` (optional)       RNG seed; default deterministic
                                  from parent_id

Returns 0 or 1 child Experiment. Never raises — silently skips on
malformed params with a `@warn`.
"""
function recipe_next_random_in_bounds(entry, params::AbstractDict)
    path = get(params, "path", nothing)
    lo = get(params, "low", nothing)
    hi = get(params, "high", nothing)
    if path === nothing || lo === nothing || hi === nothing
        @warn "next_random_in_bounds: missing path/low/high" cid=entry.content_id
        return Experiment[]
    end
    seed = Int(get(params, "seed",
        hash(String(entry.content_id)) % typemax(UInt32)))
    rng = MersenneTwister(seed)
    v = Float64(lo) + rand(rng) * (Float64(hi) - Float64(lo))

    spec = _load_spec(entry)
    spec === nothing && return Experiment[]
    _set_path!(spec, _split_path(path), v)
    [Experiment(spec)]
end

# ── :refine_around_best ─────────────────────────────────────────────

"""
    recipe_refine_around_best(entry, params) -> Vector{Experiment}

Compare every completed sibling's metric (read from outcome.toml) and
propose a new run at `(best_param ± shrink * range)` halfway toward
the best. Pure greedy exploitation — wrap in a trust gate before any
unattended dispatch.

Required params: `path`, `low`, `high`, `metric` (path into outcome's
`[metrics]` table). Optional: `shrink::Float64 = 0.5`.
"""
function recipe_refine_around_best(entry, params::AbstractDict)
    path = get(params, "path", nothing)
    lo = get(params, "low", nothing)
    hi = get(params, "high", nothing)
    metric = get(params, "metric", nothing)
    if path === nothing || lo === nothing || hi === nothing || metric === nothing
        @warn "refine_around_best: missing path/low/high/metric" cid=entry.content_id
        return Experiment[]
    end
    shrink = Float64(get(params, "shrink", 0.5))

    # Walk every :done entry in this queue and find the one whose
    # outcome.toml metric is best (we minimise by default; flip with
    # `lower_is_better = false`).
    lower_is_better = Bool(get(params, "lower_is_better", true))
    best_val = nothing
    best_param = nothing
    for sibling in list_queue(:done; qr=autopilot_queue_root())
        m = _outcome_metric(sibling, metric)
        m === nothing && continue
        sp = _load_spec(sibling)
        sp === nothing && continue
        p = _get_path(sp, _split_path(path))
        p isa Real || continue
        if best_val === nothing ||
            (lower_is_better ? m < best_val : m > best_val)
            best_val = m
            best_param = Float64(p)
        end
    end
    if best_param === nothing
        @info "refine_around_best: no completed sibling has the metric" cid=entry.content_id
        return Experiment[]
    end

    # New sample halfway between best_param and the box center.
    center = 0.5 * (Float64(lo) + Float64(hi))
    new_val = best_param + shrink * (center - best_param) * (2 * rand() - 1)
    new_val = clamp(new_val, Float64(lo), Float64(hi))

    spec = _load_spec(entry)
    spec === nothing && return Experiment[]
    _set_path!(spec, _split_path(path), new_val)
    [Experiment(spec)]
end

# ── :analyze_majorana ───────────────────────────────────────────────

"""
    recipe_analyze_majorana(entry, params) -> Vector{Experiment}

Run the Majorana / polyhedral classifier on `entry`'s result and
write a sidecar at `<run_dir>/analysis_majorana.toml`. Returns NO new
experiments — pure post-hoc analysis. Useful as a smoke check that
the registry + on_complete chain is wired before any sim cycles.
"""
function recipe_analyze_majorana(entry, params::AbstractDict)
    out_path = joinpath(entry.run_dir, "analysis_majorana.toml")
    summary = Dict{String, Any}(
        "produced_at" => string(now()),
        "by_recipe" => "analyze_majorana",
        "content_id" => entry.content_id,
    )
    # Open the Experiment, pull psi at the final snapshot, classify.
    try
        exp = Experiment(entry.spec_path)
        ts = times(exp)
        if isempty(ts)
            summary["classification"] = "(no time samples)"
        else
            t_final = last(ts)
            psi = density(exp, t_final)
            # `psi` is either Array{Float64,3} (single-trajectory) or a
            # NamedTuple for ensembles; classify_phase only handles the
            # former. Skip ensemble runs with a note.
            if psi isa AbstractArray
                # Need atom + grid for classify_phase; reload from spec.
                spec = SpinorBEC.load_config(entry.spec_path)
                gs_step = first(spec.steps)
                grid, atom = gs_step.grid, gs_step.atom
                sm = spin_matrices(atom.F)
                cls = classify_phase(psi, atom.F, grid, sm)
                summary["classification"] = string(cls.phase)
                summary["t_final"] = t_final
            else
                summary["classification"] = "(ensemble run; analyzer skipped)"
            end
        end
    catch err
        summary["error"] = sprint(showerror, err)
    end
    open(out_path, "w") do io
        TOML.print(io, summary)
    end
    return Experiment[]
end

# ── Helpers ─────────────────────────────────────────────────────────

function _split_path(p)
    p isa AbstractVector && return [String(x) for x in p]
    p isa AbstractString && return [String(s) for s in split(p, '.')]
    throw(ArgumentError("path must be Vector{String} or dotted-string"))
end

function _get_path(d::AbstractDict, parts)
    cursor::Any = d
    for k in parts
        if cursor isa AbstractDict && haskey(cursor, k)
            cursor = cursor[k]
        elseif cursor isa AbstractVector
            idx = tryparse(Int, k)
            idx === nothing && return nothing
            1 <= idx <= length(cursor) || return nothing
            cursor = cursor[idx]
        else
            return nothing
        end
    end
    return cursor
end

function _load_spec(entry)
    isfile(entry.spec_path) || return nothing
    try
        return YAML.load_file(entry.spec_path)
    catch err
        @warn "_load_spec failed" path=entry.spec_path exception=err
        return nothing
    end
end

function _outcome_metric(entry, metric_path)
    p = joinpath(entry.run_dir, OUTCOME_FILENAME)
    isfile(p) || return nothing
    d = try
        TOML.parsefile(p)
    catch
        ;
        return nothing
    end
    return _get_path(d, _split_path(metric_path))
end

# ── Registration ────────────────────────────────────────────────────

"""
    setup_default_recipes!()

Idempotently register the Day-1 recipes (next_random_in_bounds,
refine_around_best, analyze_majorana). Versions follow the recipe's
own SemVer; bump when behavior changes.
"""
function setup_default_recipes!()
    register_on_complete!(:next_random_in_bounds) do entry, params
        recipe_next_random_in_bounds(entry, params)
    end
    register_on_complete_version!(:next_random_in_bounds, "1.0")

    register_on_complete!(:refine_around_best) do entry, params
        recipe_refine_around_best(entry, params)
    end
    register_on_complete_version!(:refine_around_best, "1.0")

    register_on_complete!(:analyze_majorana) do entry, params
        recipe_analyze_majorana(entry, params)
    end
    register_on_complete_version!(:analyze_majorana, "1.0")
    return nothing
end
