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

# One declaration, used by BOTH the constructor's path resolution and `run!`'s
# admission. Before cutover step 2 the same `isfile` predicate was written out
# twice (here and in `_result_path_or_nothing`), which is how the two would have
# drifted the moment one of them learned about the marker.
_has_result(dir::AbstractString) =
    isdir(dir) && _admitted_result_path(dir) !== nothing

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

"""
    _admitted_result_path(dir) -> Union{Nothing,String}

The run's payload, or `nothing` if the directory does not admit (cutover step 2,
invariant 4). Replaces the bare `isfile` that served a killed run's output as
converged.

**A rejection poisons the whole directory**, and that is deliberate rather than
conservative. `save_rotating_basis_result!` makes `point_001.jld2` a SYMLINK to
`result.jld2`; if a marked-and-disagreeing `result.jld2` merely fell through to
the next candidate, the unmarked symlink pointing at those exact bytes would be
admitted under arm (b) and the rejection would have achieved nothing.
"""
function _admitted_result_path(dir::AbstractString)
    hit = nothing
    for n in _RESULT_NAMES
        p = joinpath(dir, n)
        isfile(p) || continue
        adm = admit_payload(p)
        adm.hit || return nothing
        hit === nothing && (hit = p)
    end
    hit
end

_result_path_or_nothing(exp::Experiment) = _admitted_result_path(outdir(exp))

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
