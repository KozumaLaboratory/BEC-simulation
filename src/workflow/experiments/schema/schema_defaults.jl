# --- Pre-parse stage: schema-level block defaults ---
#
# The YAML schema (schema.jl) declares per-field defaults via FieldSpec, but
# those only kick in when validate_config! sees the field. They do NOT
# auto-inject blocks the user omitted entirely. That created a long-running
# inconsistency: schema said `ddi.enabled: true`, but the parser saw an
# absent `ddi:` block and silently returned `enabled=false`. Two independent
# parsers (`_parse_gs_ddi` and `_resolve_derived_params!`) duplicated the
# missing-block fallback and disagreed on the answer.
#
# `apply_schema_defaults!` is a pre-parse stage that runs after templates +
# mixins (so the steps it walks already have the user's full content) and
# before B/noise/units normalisation. It auto-injects schema defaults that
# are conditional on the step type, so downstream parsers see explicit
# values for everything.

"""
    apply_schema_defaults!(data) -> data

Walk the pipeline and fill in schema-level block defaults that the user
typically omits. Currently auto-injects:

  - `ground_state.ddi: {}`  (empty dict ⇒ schema's `enabled: true` default
    applies; downstream parsers derive c_dd from atom + N_atoms + ω_ref).
    Skipped if the GS step already has `ddi:` (any value, including
    `false` to opt out).

`dynamics:` steps are intentionally NOT auto-injected: the dynamics-step
DDI is inherited from `ws_prev.ddi` unless the user explicitly overrode
it, and a default `ddi: {}` here would force re-derivation against an
incomplete `interactions:` block (no N_atoms in dynamics steps).
"""
function apply_schema_defaults!(data::Dict)
    haskey(data, "pipeline") || return data
    pipe = data["pipeline"]
    pipe isa AbstractVector || return data

    for step in pipe
        step isa AbstractDict || continue
        length(keys(step)) == 1 || continue
        key = String(first(keys(step)))
        inner = step[first(keys(step))]
        inner isa AbstractDict || continue

        # GS step: auto-enable DDI when user didn't write a `ddi:` block.
        if key == "ground_state" && !haskey(inner, "ddi")
            inner["ddi"] = Dict{String, Any}()
        end
    end
    return data
end
