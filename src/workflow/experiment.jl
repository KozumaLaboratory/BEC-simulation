# ============================================================================
# Experiment — unified model for the SpinorBEC workflow.
# ============================================================================
#
# Reducible essence (anko 2026-05-27):
#   spec   - what to simulate (Dict, built via the DSL)
#   run    - execute (idempotent on cached result.jld2)
#   observe - read derived quantities from the result
#
# Everything else (sweep, twin, diff, classification, etc.) is a plain
# function that *falls out* of these three. There is no Batch / RunResult
# type — `Vector{Experiment}` is the sweep collection, and the lazy
# result-jld2 lives in `exp.memo`.
#
# Content-addressable storage (CAS): `spec` uniquely determines `outdir`
# via SHA-256 of canonical bytes. Users never name an outdir.

using JLD2
using YAML
using SHA: sha256
using Printf: @printf

# Core types + lifecycle
export Experiment, CASStore
export outdir, content_id, default_store
export write_run!, run!, status

# Observables (plain functions on Experiment)
export times, Fz_t, Lz_t, Jz_t, norm_t, energy_t
export Fz_drift, Lz_drift, energy_drift, norm_drift
export Fz_rel_drift, energy_rel_drift, norm_rel_drift
export peaks, populations_t, per_m_t
export classify, n_trajectories, integrator_meta
export density, psi, density_stats_at

# Collection-level operations
export sweep, twin, spec_diff, tabulate

# ===========================================================================
# Content-addressable storage (CAS)
# ===========================================================================
#
# Canonical bytes are deterministic across dict-iteration order:
#   Dict       → "{<sorted_key>:<value>,...}" (keys sorted by string repr)
#   Vector     → "[<value>,...]" (order preserved)
#   Float      → printf("%.17g", x); NaN / Inf error out
#   Integer    → decimal
#   Bool       → true | false
#   String / Symbol → JSON-escaped "<utf8>"
#   nothing    → null
# 16 hex (64-bit) ≈ birthday-safe to ~10^10 distinct specs.

struct CASStore
    root::String
end

default_store() = CASStore(get(ENV, "SPINORBEC_STORE", "runs"))

const _CONTENT_ID_HEX = 16

function _canonical_bytes!(io::IO, x)
    if x isa AbstractDict
        print(io, "{")
        first = true
        for k in sort!(collect(keys(x)); by=string)
            first || print(io, ",")
            _canonical_bytes!(io, string(k))
            print(io, ":")
            _canonical_bytes!(io, x[k])
            first = false
        end
        print(io, "}")
    elseif x isa AbstractVector
        print(io, "[")
        for (i, v) in enumerate(x)
            i == 1 || print(io, ",")
            _canonical_bytes!(io, v)
        end
        print(io, "]")
    elseif x isa Bool
        print(io, x)
    elseif x isa Integer
        print(io, x)
    elseif x isa AbstractFloat
        (isnan(x) || isinf(x)) &&
            error("content_id: non-finite Float in spec ($x); refuse to hash")
        @printf io "%.17g" x
    elseif x isa AbstractString || x isa Symbol
        print(io, '"')
        for c in string(x)
            if c == '\\' || c == '"'
                print(io, '\\', c)
            elseif c < ' '
                @printf io "\\u%04x" Int(c)
            else
                print(io, c)
            end
        end
        print(io, '"')
    elseif x === nothing
        print(io, "null")
    else
        error("content_id: unsupported type $(typeof(x)) for value $(repr(x))")
    end
end

function _canonical_bytes(x)
    io = IOBuffer()
    _canonical_bytes!(io, x)
    take!(io)
end

"""
    content_id(spec; n=16) -> String

SHA-256 of the canonical-bytes serialisation, truncated to `n` hex
chars. Pure function of `spec` — independent of dict ordering / YAML
round-trip / Julia version.
"""
content_id(spec; n::Int=_CONTENT_ID_HEX) = bytes2hex(sha256(_canonical_bytes(spec)))[1:n]

# ===========================================================================
# Experiment
# ===========================================================================

"""
    Experiment(spec; store=default_store(), outdir=nothing) -> Experiment
    Experiment(yaml_path; store=default_store()) -> Experiment

A single simulation cell. The triple `(spec, store, memo)` is enough
to define what to run, where the result lives, and to cache derived
quantities lazily.

- `spec` is the YAML-shaped Dict built by the DSL (`config([...])`).
- `store` is the CAS root; the cell's outdir is
  `<store.root>/<content_id(spec)>/`.
- `memo` is a lazy property cache used by `Fz_t`, `peaks`, … etc.

Construction is I/O-free. `run!(exp)` performs the simulation (skipping
if the cached jld2 already exists). Observables (plain functions:
`Fz_t(exp)`, `peaks(exp)`, `classify(exp)`, `density(exp, t)`, …) read
the jld2 on first call and memoise.
"""
mutable struct Experiment
    spec::Dict{Any, Any}
    store::CASStore
    _outdir_override::Union{Nothing, String}  # legacy / explicit override
    memo::Dict{Symbol, Any}
end

# --- construction ---

function Experiment(
    spec::AbstractDict;
    store::CASStore=default_store(),
    outdir::Union{Nothing, AbstractString}=nothing,
)
    Experiment(
        Dict{Any, Any}(spec),
        store,
        outdir === nothing ? nothing : String(outdir),
        Dict{Symbol, Any}(),
    )
end

function Experiment(yaml_path::AbstractString; store::CASStore=default_store())
    isfile(yaml_path) ||
        throw(ArgumentError("Experiment: no such file: $yaml_path"))
    spec = YAML.load_file(yaml_path)
    spec_dict = Dict{Any, Any}(spec)
    cid = content_id(spec_dict)
    cas_dir = joinpath(store.root, cid)
    _has_result(cas_dir) && return Experiment(
        spec_dict, store, nothing, Dict{Symbol, Any}()
    )
    if basename(yaml_path) == "config.yaml"
        same_dir = dirname(abspath(yaml_path))
        _has_result(same_dir) && return Experiment(
            spec_dict, store, same_dir, Dict{Symbol, Any}()
        )
    end
    legacy = find_run_dir(yaml_path)
    legacy !== nothing && return Experiment(
        spec_dict, store, String(legacy), Dict{Symbol, Any}()
    )
    Experiment(spec_dict, store, nothing, Dict{Symbol, Any}())
end

_has_result(dir::AbstractString) =
    isdir(dir) && (isfile(joinpath(dir, "result.jld2")) ||
                   isfile(joinpath(dir, "point_001.jld2")))

# --- outdir (CAS-derived getter; no field access) ---

"""
    outdir(exp::Experiment) -> String

Derived directory path. Pure function of `exp.spec` (via CAS),
overridable only via the legacy `_outdir_override` field for migration.
"""
function outdir(exp::Experiment)
    ovr = getfield(exp, :_outdir_override)
    ovr !== nothing && return ovr
    joinpath(getfield(exp, :store).root, content_id(getfield(exp, :spec)))
end

# Property forwarding: `exp.spec` / `exp.store` / `exp.memo` / `exp.outdir`.
# `getproperty` no longer carries observable dispatch — those are plain
# functions exported above.
function Base.getproperty(exp::Experiment, name::Symbol)
    name === :spec && return getfield(exp, :spec)
    name === :store && return getfield(exp, :store)
    name === :memo && return getfield(exp, :memo)
    name === :outdir && return outdir(exp)
    throw(
        ArgumentError(
            "Experiment.$(name) is not a property. Observables are now " *
            "plain functions: Fz_t(exp), peaks(exp), classify(exp), " *
            "density(exp, t), … (see exports in src/workflow/experiment.jl).",
        ),
    )
end

Base.propertynames(::Experiment) = (:spec, :store, :memo, :outdir)

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

const _RESULT_NAMES = ("result.jld2", "point_001.jld2")

function _result_path_or_nothing(exp::Experiment)
    dir = outdir(exp)
    for n in _RESULT_NAMES
        p = joinpath(dir, n)
        isfile(p) && return p
    end
    nothing
end

function _result_path(exp::Experiment)
    p = _result_path_or_nothing(exp)
    p === nothing && throw(ArgumentError(
        "Experiment: no result jld2 in $(outdir(exp)). Did you `run!`?"
    ))
    p
end

"""
    write_run!(exp) -> String

Write `exp.spec` to `<outdir(exp)>/config.yaml`. Internal: `run!`
calls it automatically before launching the simulation. The only
external reason to call it directly is the cluster split-flow
(write here, run on HPC).
"""
function write_run!(exp::Experiment)
    mkpath(outdir(exp))
    path = joinpath(outdir(exp), "config.yaml")
    YAML.write_file(path, getfield(exp, :spec))
    path
end

"""
    run!(exp; force=false) -> Experiment

Idempotent: if a `result.jld2` / `point_001.jld2` exists in `outdir(exp)`,
returns immediately. With `force=true`, clears the memo + reruns.
Writes `config.yaml` if missing.
"""
function run!(exp::Experiment; force::Bool=false)
    if !force && _result_path_or_nothing(exp) !== nothing
        return exp
    end
    force && empty!(getfield(exp, :memo))
    cfg_path = joinpath(outdir(exp), "config.yaml")
    isfile(cfg_path) || write_run!(exp)
    run_yaml(cfg_path)
    exp
end

"""
    status(exp) -> Symbol

  `:cached`  result jld2 present and config.yaml mtime ≤ jld2 mtime
  `:stale`   jld2 present but older than the YAML (rerun needed)
  `:pending` outdir exists, no jld2 yet
  `:missing` outdir does not exist
"""
function status(exp::Experiment)
    dir = outdir(exp)
    isdir(dir) || return :missing
    jld = _result_path_or_nothing(exp)
    jld === nothing && return :pending
    cfg = joinpath(dir, "config.yaml")
    isfile(cfg) && mtime(cfg) > mtime(jld) && return :stale
    :cached
end

# ---------------------------------------------------------------------------
# Memo helper + RunResult bridge
# ---------------------------------------------------------------------------
# RunResult stays as the internal jld2-view used by observable_dispatch.jl;
# Experiment caches it in memo[:_runresult]. Phase B may collapse RunResult
# into the memo entirely.

# `do`-block-friendly arg order: `_memoize(do …; end, exp, key)`.
function _memoize(compute::Function, exp::Experiment, key::Symbol)
    memo = getfield(exp, :memo)
    haskey(memo, key) && return memo[key]
    val = compute()
    memo[key] = val
    val
end

_runresult(exp::Experiment) = _memoize(() -> open_result(_result_path(exp)), exp, :_runresult)

function _is_ensemble(exp::Experiment)
    _memoize(exp, :_is_ensemble) do
        jld = _result_path_or_nothing(exp)
        jld === nothing && return false
        jldopen(jld, "r") do f
            any(k -> startswith(k, "dynamics") && haskey(f[k], "ensemble"),
                collect(keys(f)))
        end
    end
end

# ---------------------------------------------------------------------------
# Observables (plain functions)
# ---------------------------------------------------------------------------
#
# Convention: function name == observable name. Trajectory observables
# have `_t` suffix (e.g. `Fz_t`); drift summaries `_drift` /
# `_rel_drift`; classification `classify`; meta `n_trajectories`,
# `integrator_meta`; parametrised `density(exp, t)`, `psi(exp, t)`,
# `density_stats_at(exp, t)`.
#
# For terminal scalar from a trajectory: `last(Fz_t(exp))` etc.

# --- trajectories from RunResult dispatch ---

for (name, src) in (
    (:Fz_t, :Fz_t), (:Lz_t, :Lz_t), (:Jz_t, :Jz_t),
    (:norm_t, :norm_t), (:energy_t, :energy_t),
)
    @eval $name(exp::Experiment) =
        _memoize(exp, $(QuoteNode(name))) do
            getproperty(_runresult(exp), $(QuoteNode(src)))
        end
end

times(exp::Experiment) =
    _memoize(exp, :times) do
        dyn = _runresult(exp).dynamics
        dyn === nothing && throw(ArgumentError(
            "times(exp): this run has no dynamics block"
        ))
        Float64.(dyn.times)
    end

# --- drift summaries ---

for (fn, base) in (
    (:Fz_drift, :Fz_t), (:Lz_drift, :Lz_t),
    (:energy_drift, :energy_t), (:norm_drift, :norm_t),
)
    @eval $fn(exp::Experiment) =
        _memoize(exp, $(QuoteNode(fn))) do
            ts = $base(exp)
            maximum(abs.(ts .- ts[1]))
        end
end

for (fn, base) in (
    (:Fz_rel_drift, :Fz_t),
    (:energy_rel_drift, :energy_t),
    (:norm_rel_drift, :norm_t),
)
    @eval $fn(exp::Experiment) =
        _memoize(exp, $(QuoteNode(fn))) do
            ts = $base(exp)
            maximum(abs.(ts .- ts[1])) / max(abs(ts[1]), 1e-30)
        end
end

# --- derived trajectories ---

"""
    peaks(exp) -> Vector{Float64}

Maximum total density per snapshot. For ensemble runs, peaks of the
ensemble-mean density.
"""
peaks(exp::Experiment) =
    _memoize(exp, :peaks) do
        _is_ensemble(exp) ? _ensemble_peaks(exp) :
        peak_density_trajectory(_result_path(exp))
    end

"""
    populations_t(exp) -> Vector{Vector{Float64}}

Per-frame `|ψ_m|²` integrated over space, length-`D` per frame.
Errors for ensemble runs (no per-trajectory psi available).
"""
populations_t(exp::Experiment) =
    _memoize(exp, :populations_t) do
        _is_ensemble(exp) && throw(
            ArgumentError(
                "populations_t(exp): undefined for ensemble (no per-trajectory psi)"
            ),
        )
        spin_populations_trajectory(_result_path(exp))
    end

"""
    per_m_t(exp) -> Vector{Vector{Float64}}

Rotating-basis save layout: `dynamics/per_m_history` D×T matrix
surfaced as a D-vector per frame.
"""
per_m_t(exp::Experiment) =
    _memoize(exp, :per_m_t) do
        jld = _result_path(exp)
        jldopen(jld, "r") do f
            haskey(f, "dynamics/per_m_history") || throw(
                ArgumentError(
                    "per_m_t(exp): dynamics/per_m_history missing (this run did " *
                    "not use save_rotating_basis_result!)",
                ),
            )
            pm = f["dynamics/per_m_history"]
            T = size(pm, 2)
            [Vector{Float64}(view(pm, :, t)) for t in 1:T]
        end
    end

"""
    integrator_meta(exp) -> Dict{String,Any}

Rotating-basis save layout: contents of `dynamics/integrator_meta/`.
Empty Dict if the group is missing.
"""
integrator_meta(exp::Experiment) =
    _memoize(exp, :integrator_meta) do
        jld = _result_path(exp)
        jldopen(jld, "r") do f
            meta = Dict{String, Any}()
            haskey(f, "dynamics/integrator_meta") || return meta
            for k in keys(f["dynamics/integrator_meta"])
                meta[String(k)] = f["dynamics/integrator_meta/$k"]
            end
            meta
        end
    end

# --- classification + ensemble meta ---

"""
    classify(exp) -> Symbol

5-category collapse classifier on the peaks trajectory + final norm
ratio. Categories: `:collapse / :delay / :marginal_arrest /
:sacrificial_arrest / :stable_arrest`.
"""
classify(exp::Experiment) =
    _memoize(exp, :classify) do
        ps = peaks(exp)
        ns = norm_t(exp)
        classify_collapse(ps, ns[end] / ns[1])
    end

"""
    n_trajectories(exp) -> Int

1 for single-trajectory runs, the recorded ensemble size for TWA runs.
"""
n_trajectories(exp::Experiment) =
    _memoize(exp, :n_trajectories) do
        _is_ensemble(exp) || return 1
        jld = _result_path(exp)
        jldopen(jld, "r") do f
            for k in sort(collect(keys(f)))
                startswith(k, "dynamics") || continue
                haskey(f[k], "ensemble") || continue
                eg = f["$k/ensemble"]
                for pk in sort(collect(keys(eg)))
                    startswith(pk, "phase_") || continue
                    haskey(eg[pk], "n_trajectories") || continue
                    return Int(f["$k/ensemble/$pk/n_trajectories"])
                end
            end
            return 1
        end
    end

# --- parametrised observables ---

"""
    density(exp, t) -> Array{Float64,3} or (mean=…, variance=…)

Total density at the snapshot closest to time `t`. For ensemble runs,
returns a named tuple `(mean, variance)` of 3D arrays.
"""
function density(exp::Experiment, t::Real)
    t = float(t)
    if _is_ensemble(exp)
        return jldopen(_result_path(exp), "r") do f
            _ensemble_density_at(f, t)
        end
    end
    p = psi(exp, t)
    total_density(p, ndims(p) - 1)
end

"""
    psi(exp, t) -> Array{Complex,4}

Raw ψ snapshot closest to time `t` (single trajectory only).
"""
function psi(exp::Experiment, t::Real)
    t = float(t)
    _is_ensemble(exp) && throw(ArgumentError(
        "psi(exp, t): undefined for ensemble runs; use density(exp, t)"
    ))
    jldopen(_result_path(exp), "r") do f
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        snap_times = _snapshot_times(f, frames)
        idx = argmin(abs.(snap_times .- t))
        g[frames[idx]]
    end
end

function _snapshot_times(f, frames::AbstractVector{<:AbstractString})
    ts = Vector{Float64}(f["dynamics/times"])
    nf = length(frames)
    length(ts) == nf + 1 && return @view ts[2:end]
    length(ts) == nf && return ts
    @view ts[1:min(nf, length(ts))]
end

"""
    density_stats_at(exp, t) -> NamedTuple

`(peak, peak_voxel, fwhm_x, fwhm_z, on_axis, sigma_over_mu)`. For
single trajectories `sigma_over_mu = NaN`; for ensembles it is
`sqrt(variance[peak_voxel]) / peak`.
"""
function density_stats_at(exp::Experiment, t::Real)
    t = float(t)
    if _is_ensemble(exp)
        snap = density(exp, t)
        return density_stats(snap.mean; variance=snap.variance)
    end
    density_stats(density(exp, t))
end

# --- ensemble internals (kept private — surfaced via density / peaks) ---

function _ensemble_density_at(f, t::Float64)
    phase_groups = String[]
    for k in collect(keys(f))
        startswith(k, "dynamics") || continue
        haskey(f[k], "ensemble") || continue
        push!(phase_groups, k)
    end
    sort!(phase_groups)
    isempty(phase_groups) && throw(ArgumentError(
        "density(exp, t): no dynamics/ensemble/ group in jld2"
    ))
    for pg in phase_groups
        eg = f["$pg/ensemble"]
        for k in keys(eg)
            startswith(k, "phase_") || continue
            tk = "$pg/ensemble/$k/times"
            haskey(f, tk) || continue
            times_arr = Vector{Float64}(f[tk])
            tmin, tmax = extrema(times_arr)
            (t < tmin - 1e-12 || t > tmax + 1e-12) && continue
            idx = argmin(abs.(times_arr .- t))
            mean_arr = f["$pg/ensemble/$k/density/mean"]
            var_arr = f["$pg/ensemble/$k/density/variance"]
            return (mean=mean_arr[:, :, :, idx],
                variance=var_arr[:, :, :, idx])
        end
    end
    throw(ArgumentError("density(exp, t): t=$t outside all phase windows"))
end

function _ensemble_peaks(exp::Experiment)
    jld = _result_path(exp)
    jldopen(jld, "r") do f
        for k in sort(collect(keys(f)))
            startswith(k, "dynamics") || continue
            haskey(f[k], "ensemble") || continue
            eg = f["$k/ensemble"]
            for pk in sort(collect(keys(eg)))
                startswith(pk, "phase_") || continue
                haskey(eg[pk], "density") || continue
                mean_arr = f["$k/ensemble/$pk/density/mean"]
                _, _, _, nt = size(mean_arr)
                return [
                    Float64(maximum(view(mean_arr,:,:,:,it))) for it in 1:nt
                ]
            end
        end
        throw(ArgumentError(
            "peaks(exp): no dynamics/ensemble/phase_*/density/mean"
        ))
    end
end

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

# ===========================================================================
# check / compare / audit — work on Experiment directly
# ===========================================================================
#
# These adapters bridge Experiment to the existing Spec-driven verdict
# layer (src/workflow/validation/{specs,operations}.jl).

"""
    check(spec, exp::Experiment) -> CheckResult

Apply a validation spec via the cached RunResult inside `exp.memo`.
"""
check(spec, exp::Experiment) = check(spec, _runresult(exp))

"""
    compare(a::Experiment, b::Experiment; label_a="A", label_b="B")
        -> RunComparison

Pair two Experiments for A/B diff.
"""
function compare(
    a::Experiment, b::Experiment;
    label_a::AbstractString="A", label_b::AbstractString="B",
)
    compare_runs(_runresult(a), _runresult(b); label_a, label_b)
end

"""
    audit(exp::Experiment; spec=ConservationSpec(), verbose=true) -> CheckResult

`run!` + `check`. The 1-liner for "this spec must respect conservation".
"""
function audit(exp::Experiment; spec=ConservationSpec(), verbose::Bool=true)
    run!(exp)
    verbose && @info "audit" outdir = outdir(exp)
    check(spec, exp)
end
