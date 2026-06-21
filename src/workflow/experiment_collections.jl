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
present on only one side).

Used by:
- `twin` verification (twin should differ on lhy + loss only)
- sweep-axis discovery (which keys vary across a Vector{Experiment})
- compare provenance / auto-labelling
"""
function spec_diff(a::AbstractDict, b::AbstractDict)
    out = Tuple{String, Any, Any}[]
    _spec_diff!(out, a, b, String[])
    [(path=p, a=va, b=vb) for (p, va, vb) in out]
end

spec_diff(a::Experiment, b::Experiment) = spec_diff(a.spec, b.spec)

function _spec_diff!(out, a, b, prefix)
    if a isa AbstractDict && b isa AbstractDict
        ks = union(keys(a), keys(b))
        for k in sort!(collect(ks); by=string)
            ak = haskey(a, k) ? a[k] : _MISSING
            bk = haskey(b, k) ? b[k] : _MISSING
            _spec_diff!(out, ak, bk, vcat(prefix, string(k)))
        end
    elseif a isa AbstractVector && b isa AbstractVector
        for i in 1:max(length(a), length(b))
            ai = i ≤ length(a) ? a[i] : _MISSING
            bi = i ≤ length(b) ? b[i] : _MISSING
            _spec_diff!(out, ai, bi, vcat(prefix, string(i)))
        end
    else
        if !_spec_equal(a, b)
            push!(out, (join(prefix, "."), a, b))
        end
    end
end

const _MISSING = :__SPEC_DIFF_MISSING__

_spec_equal(a, b) = a == b
_spec_equal(::typeof(_MISSING), ::typeof(_MISSING)) = true

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

"""
    sweep(scan_yaml_path::AbstractString; store=default_store())
        -> Vector{Experiment}

Legacy scan.yaml reader. Loads template + parameter.values +
override_path + extra_overrides and returns the Vector{Experiment}.
"""
function sweep(scan_yaml_path::AbstractString; store::CASStore=default_store())
    scan = YAML.load_file(scan_yaml_path)
    scan_dir = dirname(abspath(scan_yaml_path))
    template_rel = scan["template"]
    template_path =
        isabspath(template_rel) ? template_rel :
        normpath(joinpath(scan_dir, template_rel))
    base = YAML.load_file(template_path)
    override_path = _dotted_to_underscore(scan["override_path"])
    extra_overrides = get(scan, "extra_overrides", Dict{Any, Any}())
    values = scan["parameter"]["values"]
    cells = Pair{Any, Dict{Any, Any}}[]
    for (idx, v) in enumerate(values)
        ovr = Dict{Any, Any}(Symbol(override_path) => v)
        for (ep, ev) in extra_overrides
            ovr[Symbol(_dotted_to_underscore(ep))] = _resolve_scan_placeholder(ev, v, idx)
        end
        push!(cells, v => ovr)
    end
    sweep(base, cells; store)
end

function _dotted_to_underscore(dotted::AbstractString)
    parts = String[]
    for p in split(dotted, '.')
        idx = tryparse(Int, p)
        push!(parts, idx === nothing ? p : string(idx + 1))
    end
    join(parts, "_")
end

function _resolve_scan_placeholder(literal, value, idx)
    literal isa AbstractString || return literal
    literal == "\${value}" && return value
    literal == "\${idx}" && return idx
    s = String(literal)
    s = replace(s, "\${value}" => string(value))
    s = replace(s, "\${idx}" => string(idx))
    s
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
