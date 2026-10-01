# Legacy configuration composition. New Julia experiments share parameters
# through ordinary functions and NamedTuples; existing YAML uses named mixins.

"""
    apply_mixins!(data::Dict) -> Dict

Expand top-level `mixins:` into pipeline steps that declare `use:`. Mixins
are layered in declaration order, with explicit step fields taking precedence.
Mutates and returns `data`.
"""
function apply_mixins!(data::Dict)
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
