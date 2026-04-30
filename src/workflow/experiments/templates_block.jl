# --- Templates + mixins: opt-in YAML composition primitives ---
#
# `template:` and `mixins:` are pre-parse rewriters that EXPAND a YAML config
# from a compact form into the full schema-validated form. Both are applied
# AFTER calibration + units block, BEFORE schema validation, so the rest of
# the pipeline sees only the expanded form.
#
# === templates ===
#
# A template is a Julia function `(parameters::Dict) -> Dict{String,Any}`
# that returns the full pipeline / metadata for a named protocol.
#
# ```yaml
# template: klaus_magnetostir
# parameters:
#   atom: Eu151
#   B_static: "1 Gauss"
#   theta_tilt_deg: 35
#   stir_freq: "226.2 Hz"
#   stir_duration: "500 ms"
#   N_atoms: 60000
#   trap_freq_hz: [50, 50, 130]
# ```
#
# Expands to a 4-phase rotating_basis pipeline (GS → tilt ramp → phi chirp
# → steady stir) with all fields filled in by the template function.
#
# === mixins ===
#
# A mixin is a named parameter set defined in the YAML (under `mixins:` or
# loaded from a separate file). Each named mixin's keys are seeded into
# every pipeline step (analogous to `defaults:` but reusable across configs).
#
# ```yaml
# mixins:
#   eu151_baseline: {atom: Eu151, N_atoms: 60000, omega_ref: 314.159}
#   klaus_phys:    {gauge_fix: false, init_m_idx: 1, c1_ratio: 0.028}
#
# pipeline:
#   - ground_state:
#       use: [eu151_baseline, klaus_phys]
#       grid: {n: [16, 16, 16], box: [12, 12, 12]}
#       ...
# ```
#
# `use: [...]` inside a step pulls the listed mixins, layered in order with
# the step's explicit fields winning. Useful for sharing physics constants
# across many configs (e.g. `eu151_baseline` once, used in 20 configs).

const _TEMPLATES = Dict{String, Function}()

function __init_templates__()
    # No built-in templates — use `mixins:` + explicit pipeline for
    # human-readable configs. The template hook is preserved for any
    # third-party extension that wants to register a named protocol.
    nothing
end

"""
    register_template!(name::String, fn::Function)

Register a template function. `fn(parameters::Dict) -> Dict{String,Any}`
must return a full YAML-equivalent dict (with at least a `pipeline:` key)
that the runner can parse.
"""
function register_template!(name::String, fn::Function)
    _TEMPLATES[name] = fn
end

"""
    apply_templates_and_mixins!(data::Dict) -> Dict

Expand `template:` (with optional `parameters:`) and `mixins:` blocks at
the top level. Mutates and returns `data`.

If both are present, template expansion happens first; the resulting dict
is then merged with mixins applied to its pipeline steps.
"""
function apply_templates_and_mixins!(data::Dict)
    # Template expansion
    if haskey(data, "template")
        tname = String(pop!(data, "template"))
        params_raw = pop!(data, "parameters", Dict{String, Any}())
        params = Dict{String, Any}(string(k) => v for (k, v) in params_raw)
        haskey(_TEMPLATES, tname) || throw(ArgumentError(
            "Unknown template '$tname'. Registered: $(sort(collect(keys(_TEMPLATES))))"))
        expanded = _TEMPLATES[tname](params)
        # Merge expanded into data — expanded wins for pipeline, data wins
        # for top-level extras (calibration, scan, etc.)
        for (k, v) in expanded
            haskey(data, k) || (data[k] = v)
        end
        # If template provided a pipeline and user also did, this is an
        # error — the template OWNS the pipeline.
        # (Already handled above: data[pipeline] absent so expanded wins.)
    end

    # Mixins expansion
    mixin_defs = if haskey(data, "mixins")
        m = pop!(data, "mixins")
        m isa AbstractDict || throw(ArgumentError(
            "mixins: must be a mapping name → params; got $(typeof(m))"))
        Dict{String, Dict{Any, Any}}(
            String(k) => Dict{Any, Any}(v) for (k, v) in m
        )
    else
        Dict{String, Dict{Any, Any}}()
    end

    if !isempty(mixin_defs) && haskey(data, "pipeline")
        pipe = data["pipeline"]
        if pipe isa AbstractVector
            data["pipeline"] = [_apply_step_mixins(s, mixin_defs) for s in pipe]
        end
    end

    return data
end

function _apply_step_mixins(step, mixin_defs::Dict{String, Dict{Any, Any}})
    step isa AbstractDict || return step
    keys_list = collect(keys(step))
    length(keys_list) == 1 || return step
    key = keys_list[1]
    inner = step[key]
    inner isa AbstractDict || return step
    haskey(inner, "use") || return step

    use_list = pop!(inner, "use")
    use_list isa AbstractVector || (use_list = [use_list])

    # Layer mixins in order, then the step's own fields (which win).
    seeded = Dict{Any, Any}()
    for mname in use_list
        m = mixin_defs[String(mname)]
        for (k, v) in m
            seeded[k] = v
        end
    end
    for (k, v) in inner
        seeded[k] = v
    end
    Dict{Any, Any}(key => seeded)
end
