# ── Surrogate trust gradient ──────────────────────────────────────────
#
# Each recipe carries an `autonomy_level` ∈ {:suggest, :propose, :dispatch}:
#
#   :suggest   recorded only — never dispatched, never enqueued
#   :propose   enqueued as pending, but autopilot_tick! skips dispatch
#              (human must promote to :dispatch by editing state.toml or
#              calling `autopilot_promote!`)
#   :dispatch  free to run
#
# Recipe trust score is persisted in `<qr.path>/trust/<recipe>.toml`.
# Each new recipe starts at autonomy=:suggest. Promotion happens via the
# offline calibration harness — `recipe_calibration!` evaluates the
# recipe against historical runs (NLL / coverage on hold-outs), and the
# operator promotes manually when calibration crosses a threshold.
#
# This is intentionally manual-promotion-only for now. Auto-promotion
# would defeat the entire trust gate; the harness is a *measurement
# tool*, not a decision tool.

export RecipeTrust, get_recipe_trust, set_recipe_trust!, list_recipe_trust,
    record_calibration!, recipe_calibration_history,
    record_recipe_outcome!, recipe_outcome_summary

const _TRUST_SUBDIR = "trust"

"""
    RecipeTrust

Per-recipe trust state. `nll_history` is a sliding window of recent
held-out NLL measurements (offline calibration). `autonomy_level` is
the operator's current grant.
"""
Base.@kwdef mutable struct RecipeTrust
    recipe::Symbol
    autonomy_level::Symbol = :suggest
    nll_history::Vector{Float64} = Float64[]
    coverage_history::Vector{Float64} = Float64[]      # observed 90% interval coverage
    last_measured::String = ""                          # ISO timestamp
    notes::String = ""                                  # operator's rationale

    # Raw outcome counters — bumped by `record_recipe_outcome!` on each
    # terminal classification. Descriptive only; auto-promotion is still
    # disabled.
    n_done::Int = 0
    n_killed_data::Int = 0
    n_killed_bug::Int = 0
end

function _trust_dir(qr::QueueRoot)
    d = joinpath(qr.path, _TRUST_SUBDIR)
    isdir(d) || mkpath(d)
    d
end

_trust_path(qr::QueueRoot, recipe::Symbol) = joinpath(_trust_dir(qr), String(recipe) * ".toml")

function get_recipe_trust(recipe::Symbol;
    qr::QueueRoot=autopilot_queue_root())
    p = _trust_path(qr, recipe)
    if !isfile(p)
        return RecipeTrust(; recipe=recipe)
    end
    d = try
        TOML.parsefile(p)
    catch
        ;
        nothing
    end
    d isa AbstractDict || return RecipeTrust(; recipe=recipe)
    RecipeTrust(;
        recipe=recipe,
        autonomy_level=Symbol(get(d, "autonomy_level", "suggest")),
        nll_history=Float64.(get(d, "nll_history", Float64[])),
        coverage_history=Float64.(get(d, "coverage_history", Float64[])),
        last_measured=String(get(d, "last_measured", "")),
        notes=String(get(d, "notes", "")),
        n_done=Int(get(d, "n_done", 0)),
        n_killed_data=Int(get(d, "n_killed_data", 0)),
        n_killed_bug=Int(get(d, "n_killed_bug", 0)),
    )
end

function set_recipe_trust!(t::RecipeTrust;
    qr::QueueRoot=autopilot_queue_root())
    t.autonomy_level in (:suggest, :propose, :dispatch) ||
        throw(ArgumentError("autonomy_level must be :suggest|:propose|:dispatch"))
    p = _trust_path(qr, t.recipe)
    d = Dict{String, Any}(
        "recipe" => String(t.recipe),
        "autonomy_level" => String(t.autonomy_level),
        "nll_history" => t.nll_history,
        "coverage_history" => t.coverage_history,
        "last_measured" => t.last_measured,
        "notes" => t.notes,
        "n_done" => t.n_done,
        "n_killed_data" => t.n_killed_data,
        "n_killed_bug" => t.n_killed_bug,
    )
    tmp = p * ".tmp"
    open(tmp, "w") do io
        TOML.print(io, d)
    end
    mv(tmp, p; force=true)
    return t
end

"""
    list_recipe_trust(; qr=autopilot_queue_root()) -> Vector{RecipeTrust}

All recipes that have ever been measured or promoted. Useful for
operator status display.
"""
function list_recipe_trust(; qr::QueueRoot=autopilot_queue_root())
    dir = joinpath(qr.path, _TRUST_SUBDIR)
    isdir(dir) || return RecipeTrust[]
    [get_recipe_trust(Symbol(splitext(f)[1]); qr=qr)
     for f in readdir(dir) if endswith(f, ".toml")]
end

"""
    record_calibration!(recipe; nll, coverage_90,
                        qr=autopilot_queue_root(),
                        history_window=20)

Record a calibration measurement (held-out NLL + 90% interval coverage)
for `recipe`. Slides the history window to length `history_window`.
This is descriptive only — does NOT change autonomy_level. Promotion
is a separate operator-side decision.
"""
function record_calibration!(recipe::Symbol;
    nll::Real,
    coverage_90::Real,
    qr::QueueRoot=autopilot_queue_root(),
    history_window::Int=20,
)
    t = get_recipe_trust(recipe; qr=qr)
    push!(t.nll_history, Float64(nll))
    push!(t.coverage_history, Float64(coverage_90))
    if length(t.nll_history) > history_window
        deleteat!(t.nll_history, 1:(length(t.nll_history) - history_window))
    end
    if length(t.coverage_history) > history_window
        deleteat!(t.coverage_history, 1:(length(t.coverage_history) - history_window))
    end
    t.last_measured = string(now())
    set_recipe_trust!(t; qr=qr)
    return t
end

function recipe_calibration_history(recipe::Symbol;
    qr::QueueRoot=autopilot_queue_root())
    t = get_recipe_trust(recipe; qr=qr)
    (recipe=t.recipe,
        autonomy_level=t.autonomy_level,
        nll=t.nll_history,
        coverage_90=t.coverage_history)
end

"""
    record_recipe_outcome!(recipe::Symbol, outcome::Symbol;
                           qr=autopilot_queue_root())

Bump the per-recipe terminal-outcome counter. `outcome` is one of
`:done`, `:killed_data`, `:killed_bug`. Called from `autopilot_tick!`'s
reap loop when a recipe-attached entry reaches a terminal state.

Descriptive only — does NOT change `autonomy_level`. The trust struct
already disables auto-promotion; this is just outcome telemetry the
dashboard / operator surfaces (`autopilot_recipe_success_rate` in
observability.jl).
"""
function record_recipe_outcome!(recipe::Symbol, outcome::Symbol;
    qr::QueueRoot=autopilot_queue_root())
    outcome in (:done, :killed_data, :killed_bug) ||
        throw(ArgumentError("outcome must be :done|:killed_data|:killed_bug, got $outcome"))
    t = get_recipe_trust(recipe; qr=qr)
    if outcome === :done
        t.n_done += 1
    elseif outcome === :killed_data
        t.n_killed_data += 1
    else
        t.n_killed_bug += 1
    end
    set_recipe_trust!(t; qr=qr)
    return t
end

"""
    recipe_outcome_summary(recipe::Symbol; qr=...) ->
        (done, killed_data, killed_bug, total, success_rate)
"""
function recipe_outcome_summary(recipe::Symbol;
    qr::QueueRoot=autopilot_queue_root())
    t = get_recipe_trust(recipe; qr=qr)
    total = t.n_done + t.n_killed_data + t.n_killed_bug
    rate = total == 0 ? 0.0 : t.n_done / total
    (done=t.n_done, killed_data=t.n_killed_data, killed_bug=t.n_killed_bug,
        total=total, success_rate=rate)
end
