# ── Recipe registry (on_complete) ─────────────────────────────────────
#
# Callbacks are registered by Symbol name so they can be persisted in
# queue entries (state.toml) without serializing closures. The autopilot
# looks up `entry.recipe_name` after a run lands in `:done` and invokes
#
#     f(entry, entry.recipe_params)
#
# which returns zero or more new Experiments enqueued as children of the
# completed run (parent_id propagation). recipe_params is a
# Dict{String,Any} so any TOML-serializable shape is fine.

export register_on_complete!,
    on_complete_registry, on_complete_call,
    register_on_complete_version!, on_complete_version

const _ON_COMPLETE_REGISTRY = Dict{Symbol, Function}()
const _RECIPE_VERSIONS = Dict{Symbol, String}()

"""
    register_on_complete_version!(name::Symbol, version::AbstractString)

Declare the version tag for a registered recipe. Captured into
`state.toml.reproducibility.recipe_version` at enqueue time. Bump when
the recipe's behavior changes meaningfully (e.g. proposes different
samples) so historical runs are traceable to the recipe code that
generated them.
"""
function register_on_complete_version!(name::Symbol, version::AbstractString)
    _RECIPE_VERSIONS[name] = String(version)
    return version
end

on_complete_version(name::Symbol) = get(_RECIPE_VERSIONS, name, "1")

"""
    register_on_complete!(name::Symbol, f::Function)
    register_on_complete!(f::Function, name::Symbol)    # do-block form

Register a callback. `f` must accept `(entry::QueueEntry, params::Dict)`
(or `(entry::QueueEntry,)` for the legacy no-params form) and return
either `nothing`, an `Experiment`, or a `Vector{Experiment}`.

```julia
register_on_complete!(:next_phi) do entry, params
    target = params["target_fz"]::Float64
    exp = Experiment(entry.spec_path)
    last_fz = last(Fz_t(exp))
    [Experiment(_next_spec(last_fz, target))]
end
```
"""
function register_on_complete!(name::Symbol, f::Function)
    _ON_COMPLETE_REGISTRY[name] = f
    return f
end

# do-block-friendly overload
register_on_complete!(f::Function, name::Symbol) = register_on_complete!(name, f)

on_complete_registry() = _ON_COMPLETE_REGISTRY

function on_complete_call(name::Symbol, entry::QueueEntry,
    params::AbstractDict=Dict{String, Any}())
    f = get(_ON_COMPLETE_REGISTRY, name, nothing)
    f === nothing && return Experiment[]
    out = try
        # Try 2-arg signature first (entry, params); fall back to 1-arg.
        if hasmethod(f, Tuple{QueueEntry, typeof(params)})
            f(entry, params)
        else
            f(entry)
        end
    catch err
        @warn "on_complete callback threw" callback=name cid=entry.content_id exception=err
        return Experiment[]
    end
    if out === nothing
        return Experiment[]
    elseif out isa Experiment
        return [out]
    elseif out isa AbstractVector
        return collect(Experiment, out)
    else
        @warn "on_complete returned unexpected type" callback=name type=typeof(out)
        return Experiment[]
    end
end

function _maybe_fire_on_complete!(entry::QueueEntry,
    config::AutopilotConfig,
    stats::AutopilotStats)
    name = entry.recipe_name
    name === nothing && return nothing
    if _descendant_count(entry, config.qr) >= config.on_complete_max_descendants
        @warn "on_complete: max_descendants hit, skipping" cid=entry.content_id
        return nothing
    end
    new_exps = on_complete_call(name, entry, entry.recipe_params)
    for ne in new_exps
        try
            enqueue!(ne;
                priority=5,
                enqueued_by="on_complete:$(name)",
                recipe_name=name,
                recipe_params=entry.recipe_params,
                parent_id=entry.content_id,
                group_id=entry.group_id,    # child stays in parent's intention group
                qr=config.qr,
            )
            stats.on_complete_fired += 1
        catch err
            @warn "enqueue! during on_complete failed" exception=err
        end
    end
end

"""
    _descendant_count(entry, qr) -> Int

Count entries whose lineage (via `parent_id` transitive chain) traces
back to `entry.content_id`. Bound by total queue size — fine for the
sizes we operate at (~10⁴ entries).
"""
function _descendant_count(entry::QueueEntry, qr::QueueRoot)
    all_entries = QueueEntry[]
    for st in QUEUE_STATES
        append!(all_entries, list_queue(st; qr=qr))
    end
    target = entry.content_id
    descendants = Set{String}([target])
    changed = true
    while changed
        changed = false
        for e in all_entries
            if e.parent_id !== nothing && e.parent_id in descendants &&
                !(e.content_id in descendants)
                push!(descendants, e.content_id)
                changed = true
            end
        end
    end
    return length(descendants) - 1
end
