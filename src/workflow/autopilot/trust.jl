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
    record_calibration!, recipe_calibration_history

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
