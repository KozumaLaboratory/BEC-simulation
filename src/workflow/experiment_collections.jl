# Experiment collection ops — spec_diff (the diff primitive), sweep,
# twin, tabulate, and the collection-level run! / write_run!. Each falls
# out of the spec → CAS → run → observe model; no Batch type. Split out
# of experiment.jl; all symbols are exported from there.

# ===========================================================================
# spec_diff — the single primitive
# ===========================================================================
#
# `spec_diff` is the workhorse: returns the dotted paths whose values
# differ between two specs. It powers (a) twin verification, (b) sweep
# axis discovery, (c) provenance / compare labels — one primitive, three
# users.

"""
    spec_diff(a::AbstractDict, b::AbstractDict) -> Vector{NamedTuple}

Recursively diff two YAML-shaped Dicts. Returns a vector of entries
`(path::String, a, b)` for every leaf whose value differs (or is
present on only one side). Absent values are represented by `missing`.
Symbol and String dictionary keys are equivalent, as in `diff_dicts`.

Used by:
- `twin` verification (twin should differ on lhy + loss only)
- sweep-axis discovery (which keys vary across a Vector{Experiment})
- compare provenance / auto-labelling
"""
function spec_diff(a::AbstractDict, b::AbstractDict)
    [
        (path=join(entry.path, "."), a=entry.before, b=entry.after)
        for entry in flatten_diff(diff_dicts(a, b))
    ]
end

spec_diff(a::Experiment, b::Experiment) = spec_diff(a.spec, b.spec)

# ===========================================================================
# Sweep — returns Vector{Experiment} directly. No Batch type.
# ===========================================================================

"""
    sweep(base::AbstractDict; over::Pair, store=default_store())
        -> Vector{Experiment}

1-axis sweep. Each cell gets its own CAS outdir derived from its own
modified spec. No naming, no manifest — the sweep axis is recoverable
post-hoc via `spec_diff` across the returned vector.

```julia
exps = sweep(base;
    over = :pipeline_2_dynamics_loss => [loss(K3_si=f*1e-41) for f in factors])
run!.(exps)
tabulate(exps, [Fz_t, classify, norm_drift])
```
"""
function sweep(
    base::AbstractDict;
    over::Pair{Symbol, <:AbstractVector},
    store::CASStore=default_store(),
)
    path_tokens = split(String(over.first), '_')
    exps = Experiment[]
    for v in over.second
        spec = deepcopy(Dict{Any, Any}(base))
        _set_path!(spec, path_tokens, v)
        push!(exps, Experiment(spec; store))
    end
    exps
end

"""
    sweep(base::AbstractDict, cells::Vector{<:Pair}; store=default_store())
        -> Vector{Experiment}

Multi-override form. Each cell is `label => Dict(:dotted_path => value, ...)`
applying multiple overrides per cell. The label is informational only
(no longer used for naming — CAS handles that).
"""
function sweep(
    base::AbstractDict,
    cells::AbstractVector{<:Pair};
    store::CASStore=default_store(),
)
    exps = Experiment[]
    for cell in cells
        _, overrides = cell
        spec = deepcopy(Dict{Any, Any}(base))
        for (path, val) in overrides
            _set_path!(spec, split(String(path), '_'), val)
        end
        push!(exps, Experiment(spec; store))
    end
    exps
end

# --- run! / write_run! on a collection ---

run!(exps::AbstractVector{Experiment}; force::Bool=false) =
    (
        for e in exps
            ;
            run!(e; force);
        end;
        exps
    )

write_run!(exps::AbstractVector{Experiment}) = [write_run!(e) for e in exps]

# ===========================================================================
# twin — spec-edit + new Experiment, not a new concept
# ===========================================================================

"""
    twin(exp) -> Experiment

Sibling Experiment with every `lhy:` block reset to `{kind: "none"}`
and every `loss:` block removed. The twin's outdir comes from CAS on
its own (modified) spec — no naming, no `_TWIN_OFF` suffix needed.

Verifying that a twin differs from its source on the expected keys
only is just `spec_diff(exp, twin(exp))`.
"""
function twin(exp::Experiment)
    s = deepcopy(getfield(exp, :spec))
    walk_dicts!(s) do d
        haskey(d, "lhy") && d["lhy"] isa AbstractDict &&
            (d["lhy"] = Dict("kind" => "none"))
        delete!(d, "loss")
    end
    Experiment(s; store=getfield(exp, :store))
end

# ===========================================================================
# tabulate — Vector{Experiment} × [observable functions] → NamedTuple
# ===========================================================================

"""
    tabulate(exps::AbstractVector{Experiment}, fields::AbstractVector)
        -> NamedTuple

Per-cell column table. `fields` is a vector of observable functions
(`Fz_t`, `classify`, `norm_drift`, …). Column names are derived via
`nameof(f)`. Failed cells (jld2 missing, etc.) put the caught Exception
in their slot so the table still assembles.

```julia
tab = tabulate(exps, [Fz_t, classify, norm_drift])
tab.Fz_t          # Vector of trajectories
tab.classify      # Vector{Symbol}
tab.norm_drift    # Vector{Float64}
```
"""
function tabulate(exps::AbstractVector{Experiment}, fields::AbstractVector)
    cols = Dict{Symbol, Vector}()
    for f in fields
        col = Any[]
        for e in exps
            push!(
                col,
                try
                    f(e)
                catch err
                    err
                end,
            )
        end
        cols[nameof(f)] = col
    end
    (; (k => cols[k] for k in (nameof(f) for f in fields))...)
end
