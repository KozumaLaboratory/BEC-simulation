# ── Live-status divergence detector ───────────────────────────────────
#
# Polls `<run_dir>/_live_status.json` (written periodically by
# `run_pipeline`) and decides whether the running job should be killed.
# Criteria: norm drift > threshold or classify_collapse triggered. The
# default thresholds are conservative — tune via `set_divergence_threshold!`.

export DivergenceThresholds, divergence_thresholds,
    set_divergence_thresholds!, is_divergent_status,
    register_recipe_divergence_thresholds!,
    recipe_divergence_thresholds

Base.@kwdef mutable struct DivergenceThresholds
    norm_drift::Float64 = 1e-2          # |‖ψ‖² − 1| > this → kill
    fz_jump::Float64 = 1.0              # |⟨Fz⟩(now) − ⟨Fz⟩(start)| > this → kill
    classify_kill::Set{Symbol} = Set{Symbol}([:collapse])
end

const _DIVERGENCE_THRESHOLDS = Ref{DivergenceThresholds}(DivergenceThresholds())
const _RECIPE_DIVERGENCE_THRESHOLDS = Dict{Symbol, DivergenceThresholds}()

divergence_thresholds() = _DIVERGENCE_THRESHOLDS[]
set_divergence_thresholds!(t::DivergenceThresholds) = (_DIVERGENCE_THRESHOLDS[] = t)

"""
    register_recipe_divergence_thresholds!(name::Symbol, t::DivergenceThresholds)

Recipes that expect physically-large transient drifts (Klaus deep
quench, vortex nucleation, etc.) declare their own thresholds here so
the global default doesn't false-positive on legitimate physics. The
global thresholds remain the fallback for runs without a recipe.
"""
function register_recipe_divergence_thresholds!(name::Symbol, t::DivergenceThresholds)
    _RECIPE_DIVERGENCE_THRESHOLDS[name] = t
end

"""
    recipe_divergence_thresholds(name::Union{Nothing,Symbol}) -> DivergenceThresholds

Recipe-specific thresholds when registered, else the global default.
"""
function recipe_divergence_thresholds(name::Union{Nothing, Symbol})
    name === nothing && return divergence_thresholds()
    get(_RECIPE_DIVERGENCE_THRESHOLDS, name, divergence_thresholds())
end

"""
    is_divergent_status(status::AbstractDict;
                        thresholds=divergence_thresholds()) -> Bool

Pure predicate over a parsed `_live_status.json` dict. Separate from
filesystem access so tests can drive it with synthetic inputs.
"""
function is_divergent_status(status::AbstractDict;
    thresholds::DivergenceThresholds=divergence_thresholds())
    nd = get(status, "norm_drift", get(status, :norm_drift, 0.0))
    if nd isa Real && abs(nd) > thresholds.norm_drift
        return true
    end
    cls = get(status, "classify", get(status, :classify, nothing))
    if cls !== nothing && Symbol(cls) in thresholds.classify_kill
        return true
    end
    fzj = get(status, "fz_jump", get(status, :fz_jump, 0.0))
    if fzj isa Real && abs(fzj) > thresholds.fz_jump
        return true
    end
    return false
end

# Filesystem-side ──────────────────────────────────────────────────────

function _live_status_for(entry::QueueEntry)
    p = joinpath(entry.run_dir, "_live_status.json")
    isfile(p) || return nothing
    try
        return JSON.parsefile(p)
    catch
        return nothing
    end
end

function _is_divergent(entry::QueueEntry)::Bool
    # Recipe-specific thresholds take precedence over the global default;
    # ambitious physics scans (Klaus deep quench, vortex nucleation) need
    # their own envelopes.
    thr = recipe_divergence_thresholds(entry.recipe_name)
    status = _live_status_for(entry)
    status === nothing && return false
    is_divergent_status(status; thresholds=thr)
end
