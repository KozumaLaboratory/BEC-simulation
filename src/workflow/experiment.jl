# ============================================================================
# Experiment / Batch — unified model for the SpinorBEC workflow.
# ============================================================================
#
# An *experiment* is the unit object: a (spec, outdir, lazy cache) triple
# that owns its full lifecycle from definition through observation. A
# *batch* is a `Vector{Experiment}` plus the sweep axis it varies over,
# plus a directory root. Ensembles (TWA) are not a separate type —
# `exp.density_at(t)` dispatches at observation time on the jld2 layout,
# returning either an `Array` (single trajectory) or a `(mean, variance)`
# tuple (`dynamics/ensemble/...` layout).
#
# See the docstrings on `Experiment` / `Batch` for the full observable
# property table.

using JLD2
using YAML

export Experiment, Batch
export write_run!, run!, status, tabulate, twin_off

# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

"""
    Experiment(spec; outdir) — Experiment(yaml_path)

A single simulation cell. Cheap to construct (no I/O). Observable
properties (`exp.Fz_t`, `exp.classification`, `exp.density_at(t)`, ...)
are lazy — they open / cache the jld2 on first access.

Scalar accessors (terminal value of the trajectory):
  `:norm  :energy  :Fz  :Lz  :Jz`

Trajectory accessors (Vector{Float64}, one per snapshot):
  `:norm_t  :energy_t  :Fz_t  :Lz_t  :Jz_t  :times  :peaks`
  `:populations_t` — `Vector{Vector{Float64}}`

Drift summaries:
  `:norm_drift  :Fz_drift  :energy_drift  :Lz_drift`
  `:norm_rel_drift  :Fz_rel_drift  :energy_rel_drift`

Classification:
  `:classification` — `Symbol` from `classify_collapse`

Parametrised (call like methods):
  `exp.density_at(t)` → `Array{Float64,3}` (single) or
                       `(mean::Array, variance::Array)` (ensemble)
  `exp.psi_at(t)`     → `Array{Complex,4}` (single trajectory only)
"""
mutable struct Experiment
    spec::Dict{Any, Any}
    outdir::String
    _cache::Dict{Any, Any}
end

"""
    Batch(base_spec; over, outdir, name) — Batch(outdir)

A swept set of experiments differing along one dim (`over`). Each cell's
outdir is `<batch.outdir>/<name(value)>/`, holding `config.yaml` and
`result.jld2` (after `run!`).

`Batch(outdir::AbstractString)` rehydrates from `<outdir>/_manifest.yaml`
without touching the per-cell jld2 files.

# Indexing
`batch[i]`, `length(batch)`, `for exp in batch ... end` work as expected.
"""
mutable struct Batch
    experiments::Vector{Experiment}
    over::Pair{Symbol, Vector}
    outdir::String
end

# ---------------------------------------------------------------------------
# Experiment construction
# ---------------------------------------------------------------------------

function Experiment(spec::AbstractDict; outdir::AbstractString)
    Experiment(Dict{Any, Any}(spec), String(outdir), Dict{Any, Any}())
end

function Experiment(yaml_path::AbstractString)
    isfile(yaml_path) || throw(ArgumentError("Experiment: no such file: $yaml_path"))
    spec = YAML.load_file(yaml_path)
    outdir = if basename(yaml_path) == "config.yaml"
        dirname(abspath(yaml_path))
    else
        candidate = find_run_dir(yaml_path)
        if candidate !== nothing
            candidate
        else
            joinpath(dirname(abspath(yaml_path)), splitext(basename(yaml_path))[1])
        end
    end
    Experiment(spec, String(outdir), Dict{Any, Any}())
end

# ---------------------------------------------------------------------------
# Persist
# ---------------------------------------------------------------------------

"""
    write_run!(exp::Experiment) -> String

Write `exp.spec` to `<exp.outdir>/config.yaml`. Creates the outdir if
missing. Returns the path written. (Named `write_run!` rather than
`write!` to avoid colliding with `Base.write`.)
"""
function write_run!(exp::Experiment)
    mkpath(getfield(exp, :outdir))
    path = joinpath(getfield(exp, :outdir), "config.yaml")
    YAML.write_file(path, getfield(exp, :spec))
    path
end

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

"""
    run!(exp::Experiment; force=false) -> Experiment

Idempotent: returns immediately if `result.jld2` / `point_001.jld2`
already exists in `exp.outdir`. With `force=true`, clears the lazy
cache and reruns regardless.
"""
function run!(exp::Experiment; force::Bool=false)
    if !force && _result_path_or_nothing(exp) !== nothing
        return exp
    end
    force && empty!(getfield(exp, :_cache))
    cfg_path = joinpath(getfield(exp, :outdir), "config.yaml")
    isfile(cfg_path) || write_run!(exp)
    # `run_yaml` writes outputs alongside config.yaml when invoked on a
    # `<dir>/config.yaml` path (directory-per-config form), so passing
    # `cfg_path` lands the result in `exp.outdir` directly.
    run_yaml(cfg_path)
    exp
end

# ---------------------------------------------------------------------------
# Status
# ---------------------------------------------------------------------------

"""
    status(exp::Experiment) -> Symbol

  `:cached`  result jld2 present and YAML mtime ≤ jld2 mtime
  `:stale`   jld2 present but older than the YAML (rerun needed)
  `:pending` outdir exists, no jld2 yet
  `:missing` outdir does not exist
"""
function status(exp::Experiment)
    outdir = getfield(exp, :outdir)
    isdir(outdir) || return :missing
    jld = _result_path_or_nothing(exp)
    jld === nothing && return :pending
    cfg = joinpath(outdir, "config.yaml")
    isfile(cfg) && mtime(cfg) > mtime(jld) && return :stale
    :cached
end

# ---------------------------------------------------------------------------
# Internals — jld2 path resolution + raw access
# ---------------------------------------------------------------------------

_RESULT_NAMES = ("result.jld2", "point_001.jld2")

function _result_path_or_nothing(exp::Experiment)
    outdir = getfield(exp, :outdir)
    for n in _RESULT_NAMES
        p = joinpath(outdir, n)
        isfile(p) && return p
    end
    nothing
end

function _result_path(exp::Experiment)
    p = _result_path_or_nothing(exp)
    p === nothing && throw(
        ArgumentError(
            "Experiment: no result jld2 in $(getfield(exp, :outdir)). Did you `run!`?"
        ),
    )
    p
end

# RunResult-backed scalar / trajectory access. Existing
# `observable_dispatch.jl` does the heavy lifting; we just cache the
# RunResult so repeated accesses are O(1).
function _runresult(exp::Experiment)
    cache = getfield(exp, :_cache)
    haskey(cache, :_runresult) && return cache[:_runresult]
    rr = open_result(_result_path(exp))
    cache[:_runresult] = rr
    rr
end

# Detect ensemble layout once and cache.
function _is_ensemble(exp::Experiment)
    cache = getfield(exp, :_cache)
    haskey(cache, :_is_ensemble) && return cache[:_is_ensemble]
    jld = _result_path_or_nothing(exp)
    flag = if jld === nothing
        false
    else
        jldopen(jld, "r") do f
            any(k -> startswith(k, "dynamics") && haskey(f[k], "ensemble"),
                collect(keys(f)))
        end
    end
    cache[:_is_ensemble] = flag
    flag
end

# ---------------------------------------------------------------------------
# Observable surface — getproperty dispatch
# ---------------------------------------------------------------------------

const _SCALAR_OR_TRAJECTORY = (
    :norm, :energy, :Fz, :Lz, :Jz,
    :norm_t, :energy_t, :Fz_t, :Lz_t, :Jz_t,
)

const _DRIFT_SUFFIXES = (
    "_rel_drift", "_drift"
)

function Base.getproperty(exp::Experiment, name::Symbol)
    if name === :spec || name === :outdir
        return getfield(exp, name)
    end
    cache = getfield(exp, :_cache)
    haskey(cache, name) && return cache[name]
    val = _compute_observable(exp, name)
    cache[name] = val
    val
end

function _compute_observable(exp::Experiment, name::Symbol)
    # Parametrised accessors return closures bound to `exp`.
    if name === :density_at
        return (t::Real) -> _density_at(exp, float(t))
    elseif name === :psi_at
        return (t::Real) -> _psi_at(exp, float(t))
    elseif name === :density_stats_at
        return (t::Real) -> _density_stats_at(exp, float(t))
    end

    # `times` lives on the dynamics block but isn't in the observable
    # dispatch table; surface it directly.
    if name === :times
        dyn = _runresult(exp).dynamics
        dyn === nothing && throw(ArgumentError(
            "Experiment.times: this run has no dynamics block"
        ))
        return Float64.(dyn.times)
    end

    # Scalar / trajectory / drift — delegate to RunResult's dispatch.
    if name in _SCALAR_OR_TRAJECTORY || _has_drift_suffix(name)
        return getproperty(_runresult(exp), name)
    end

    # Derived from psi snapshots (single) or ensemble-mean density (ensemble).
    if name === :peaks
        return _is_ensemble(exp) ? _ensemble_peaks(exp) :
               peak_density_trajectory(_result_path(exp))
    elseif name === :populations_t
        _is_ensemble(exp) && throw(
            ArgumentError(
                "Experiment.populations_t: undefined for ensemble (no per-trajectory psi)"
            ),
        )
        return spin_populations_trajectory(_result_path(exp))
    elseif name === :per_m_t
        # Rotating-basis save layout: `dynamics/per_m_history` is a
        # D × T matrix (per-component population at each saved frame).
        # Surface as Vector{Vector{Float64}} for parity with
        # populations_t (D-vector per frame).
        jld = _result_path(exp)
        return jldopen(jld, "r") do f
            haskey(f, "dynamics/per_m_history") || throw(
                ArgumentError(
                    "Experiment.per_m_t: dynamics/per_m_history missing " *
                    "(this run did not use save_rotating_basis_result!)",
                ),
            )
            pm = f["dynamics/per_m_history"]
            T = size(pm, 2)
            [Vector{Float64}(view(pm, :, t)) for t in 1:T]
        end
    elseif name === :integrator_meta
        # Rotating-basis save layout: dynamics/integrator_meta/<key>.
        jld = _result_path(exp)
        return jldopen(jld, "r") do f
            meta = Dict{String, Any}()
            haskey(f, "dynamics/integrator_meta") || return meta
            for k in keys(f["dynamics/integrator_meta"])
                meta[String(k)] = f["dynamics/integrator_meta/$k"]
            end
            meta
        end
    elseif name === :classification
        peaks = _compute_observable(exp, :peaks)
        norms = _runresult(exp).norm_t
        N_ratio = norms[end] / norms[1]
        return classify_collapse(peaks, N_ratio)
    elseif name === :n_trajectories
        return _n_trajectories(exp)
    end

    throw(
        ArgumentError(
            "Experiment: no observable `$name`. Known: " *
            "scalar/trajectory/drift via observable_dispatch, plus " *
            ":peaks :populations_t :per_m_t :classification :density_at :psi_at " *
            ":density_stats_at :n_trajectories :integrator_meta",
        ),
    )
end

function _has_drift_suffix(name::Symbol)
    s = String(name)
    any(endswith(s, suf) for suf in _DRIFT_SUFFIXES)
end

# ---------------------------------------------------------------------------
# Parametrised field accessors
# ---------------------------------------------------------------------------

function _density_at(exp::Experiment, t::Float64)
    jld = _result_path(exp)
    if _is_ensemble(exp)
        jldopen(jld, "r") do f
            _ensemble_density_at(f, t)
        end
    else
        psi = _psi_at(exp, t)
        total_density(psi, ndims(psi) - 1)
    end
end

function _psi_at(exp::Experiment, t::Float64)
    _is_ensemble(exp) && throw(ArgumentError(
        "Experiment.psi_at: undefined for ensemble runs; use density_at"
    ))
    jld = _result_path(exp)
    jldopen(jld, "r") do f
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        snap_times = _snapshot_times(f, frames)
        idx = argmin(abs.(snap_times .- t))
        g[frames[idx]]
    end
end

# Snapshot-aligned time axis. `dynamics/times` may include the initial
# t=0 state even when psi_snapshots_streamed only stores post-step
# frames (save_every offset), giving `length(times) == length(frames)+1`.
function _snapshot_times(f, frames::AbstractVector{<:AbstractString})
    times = Vector{Float64}(f["dynamics/times"])
    nf = length(frames)
    if length(times) == nf + 1
        return @view times[2:end]
    elseif length(times) == nf
        return times
    else
        return @view times[1:min(nf, length(times))]
    end
end

function _ensemble_density_at(f, t::Float64)
    # Find the last ensemble phase group: dynamics_<n>/ensemble or
    # dynamics/ensemble. Aggregate by 'times' length match.
    phase_groups = String[]
    for k in collect(keys(f))
        startswith(k, "dynamics") || continue
        haskey(f[k], "ensemble") || continue
        push!(phase_groups, k)
    end
    sort!(phase_groups)
    isempty(phase_groups) && throw(ArgumentError(
        "ensemble density_at: no dynamics/ensemble/ group in jld2"
    ))
    # Walk phases, find which holds the requested time.
    for pg in phase_groups
        eg = f["$pg/ensemble"]
        for k in keys(eg)
            startswith(k, "phase_") || continue
            tk = "$pg/ensemble/$k/times"
            haskey(f, tk) || continue
            times = Vector{Float64}(f[tk])
            tmin, tmax = extrema(times)
            (t < tmin - 1e-12 || t > tmax + 1e-12) && continue
            idx = argmin(abs.(times .- t))
            mean_arr = f["$pg/ensemble/$k/density/mean"]
            var_arr = f["$pg/ensemble/$k/density/variance"]
            return (mean=mean_arr[:, :, :, idx], variance=var_arr[:, :, :, idx])
        end
    end
    throw(ArgumentError("ensemble density_at: t=$t outside all phase windows"))
end

# Per-frame max(ensemble-mean density) trajectory.
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
                return [Float64(maximum(view(mean_arr,:,:,:,it))) for it in 1:nt]
            end
        end
        throw(ArgumentError("ensemble peaks: no dynamics/ensemble/phase_*/density/mean"))
    end
end

function _n_trajectories(exp::Experiment)
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

# Single-frame stats helper: (peak, fwhm_x, fwhm_z, on_axis, σ_over_μ).
# Accepts a 3D density array, optionally with a matching variance array
# for σ_over_μ at the peak voxel.
function _density_stats_at(exp::Experiment, t::Float64)
    if _is_ensemble(exp)
        snap = _density_at(exp, t)
        return density_stats(snap.mean; variance=snap.variance)
    end
    return density_stats(_density_at(exp, t))
end

# ---------------------------------------------------------------------------
# Twin off
# ---------------------------------------------------------------------------

"""
    twin_off(exp::Experiment; suffix="_TWIN_OFF") -> Experiment

Return a sibling Experiment with every `lhy:` reset to `{kind: "none"}`
and every `loss:` block removed. The new outdir is the original with
`suffix` appended. Does not touch disk — caller does `write_run!` +
`run!` as needed.
"""
function twin_off(exp::Experiment; suffix::AbstractString="_TWIN_OFF")
    new_spec = deepcopy(getfield(exp, :spec))
    walk_dicts!(new_spec) do d
        haskey(d, "lhy") && d["lhy"] isa AbstractDict &&
            (d["lhy"] = Dict("kind" => "none"))
        delete!(d, "loss")
    end
    Experiment(new_spec; outdir=getfield(exp, :outdir) * suffix)
end

# ---------------------------------------------------------------------------
# Batch construction
# ---------------------------------------------------------------------------

function Batch(
    base_spec::AbstractDict;
    over::Pair{Symbol, <:AbstractVector},
    outdir::AbstractString,
    name::Function,
)
    path_tokens = split(String(over.first), '_')
    values_ = collect(over.second)
    exps = Experiment[]
    for v in values_
        spec = deepcopy(Dict{Any, Any}(base_spec))
        _set_path!(spec, path_tokens, v)
        cellname = String(name(v))
        cell_outdir = joinpath(String(outdir), cellname)
        push!(exps, Experiment(spec; outdir=cell_outdir))
    end
    Batch(exps, Pair{Symbol, Vector}(over.first, values_), String(outdir))
end

"""
    Batch(path::AbstractString) -> Batch

Loads a Batch from disk in one of two forms:

- a directory with `_manifest.yaml` — rehydration of a Batch that was
  previously created + `write_run!`'d;
- a `scan.yaml` file (legacy format, see `docs/design/scan_group_redesign.md`)
  — `parameter.values` + `template` + `override_path` + `extra_overrides`
  + `point_dir_pattern` get converted to the Batch cell-list form.

Dotted path conventions in scan.yaml (`pipeline.3.dynamics.B_hat.phi_omega`,
0-based indices) are translated to the internal underscore-joined,
1-based form used by `_set_path!`.
"""
function Batch(path::AbstractString)
    if isfile(path) && endswith(basename(path), ".yaml")
        return _batch_from_scan_yaml(path)
    end
    outdir = path
    manifest_path = joinpath(outdir, "_manifest.yaml")
    isfile(manifest_path) || throw(ArgumentError(
        "Batch($outdir): no _manifest.yaml — cannot rehydrate."
    ))
    m = YAML.load_file(manifest_path)
    base = Dict{Any, Any}(m["base_config"])
    over_key = Symbol(m["over_path"])
    path_tokens = split(m["over_path"], '_')
    exps = Experiment[]
    values_ = Any[]
    for pt in m["points"]
        spec = deepcopy(base)
        _set_path!(spec, path_tokens, pt["value"])
        cellname = splitext(pt["filename"])[1]
        cell_outdir = joinpath(outdir, cellname)
        push!(exps, Experiment(spec; outdir=cell_outdir))
        push!(values_, pt["value"])
    end
    Batch(exps, Pair{Symbol, Vector}(over_key, values_), String(outdir))
end

function _dotted_to_underscore(dotted::AbstractString)
    parts = String[]
    for p in split(dotted, '.')
        idx = tryparse(Int, p)
        push!(parts, idx === nothing ? p : string(idx + 1))  # 0-based → 1-based
    end
    join(parts, "_")
end

function _format_scan_point_name(pattern::AbstractString, value, idx)
    s = String(pattern)
    s = replace(s, "\${idx}" => string(idx))
    val_str = replace(string(value), "." => "_")
    val_str = replace(val_str, " " => "")
    val_str = replace(val_str, r"[^A-Za-z0-9_]" => "")
    replace(s, "\${value}" => val_str)
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

function _batch_from_scan_yaml(scan_yaml_path::AbstractString)
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
    pattern = get(scan, "point_dir_pattern", "$(scan["name"])_p\${idx}")
    cells = Pair{Any, Dict{Any, Any}}[]
    for (idx, v) in enumerate(values)
        overrides = Dict{Any, Any}(Symbol(override_path) => v)
        for (ep, ev) in extra_overrides
            overrides[Symbol(_dotted_to_underscore(ep))] = _resolve_scan_placeholder(ev, v, idx)
        end
        push!(cells, v => overrides)
    end
    # Cache the value→idx map for the name callback.
    val_to_idx = Dict(v => i for (i, v) in enumerate(values))
    Batch(base, cells; outdir=scan_dir,
        name=v -> _format_scan_point_name(pattern, v, val_to_idx[v]))
end

"""
    Batch(base_spec, cells; outdir, name) -> Batch

Multi-override cell-list form. Each cell is a `Pair{Any, Dict}` of
`(label, overrides)` where `overrides` maps dotted-path symbols to
the value to set at that path. Used when one sweep dim doesn't capture
the variation (e.g. epsilon + duration + phi_omega all changing
together, with phi_omega written into two pipeline steps).

```julia
cells = [
    1.0 => Dict(
        :pipeline_3_dynamics_B_hat_phi_chirp_to => 1.0,
        :pipeline_end_dynamics_B_hat_phi_omega  => 1.0,
        :pipeline_end_dynamics_duration         => 157.0,
    ),
    # ... one entry per cell
]
batch = Batch(base, cells; outdir="runs/phi_omega_scan",
              name=v -> "eu151_phi\$(replace(string(v),"."=>"_"))_500ms")
```

`name(v)` receives the cell label (the `Pair.first`).
"""
function Batch(
    base_spec::AbstractDict,
    cells::AbstractVector{<:Pair};
    outdir::AbstractString,
    name::Function,
)
    exps = Experiment[]
    values_ = Any[]
    for cell in cells
        label, overrides = cell
        spec = deepcopy(Dict{Any, Any}(base_spec))
        for (path, val) in overrides
            _set_path!(spec, split(String(path), '_'), val)
        end
        cellname = String(name(label))
        cell_outdir = joinpath(String(outdir), cellname)
        push!(exps, Experiment(spec; outdir=cell_outdir))
        push!(values_, label)
    end
    Batch(exps, Pair{Symbol, Vector}(:cells, values_), String(outdir))
end

# ---------------------------------------------------------------------------
# Batch persist / run
# ---------------------------------------------------------------------------

function write_run!(batch::Batch)
    mkpath(getfield(batch, :outdir))
    paths = String[]
    points = Dict{Any, Any}[]
    for (exp, v) in zip(getfield(batch, :experiments), getfield(batch, :over).second)
        cfg = write_run!(exp)
        push!(paths, cfg)
        push!(
            points,
            Dict{Any, Any}(
                "filename" => basename(getfield(exp, :outdir)) * ".yaml",
                "value" => v,
            ),
        )
    end
    over = getfield(batch, :over)
    # Reconstruct base by inverting over on the first cell.
    base = deepcopy(getfield(getfield(batch, :experiments)[1], :spec))
    _set_path!(base, split(String(over.first), '_'), nothing)  # delete sweep dim
    manifest = Dict{Any, Any}(
        "base_config" => base,
        "over_path" => String(over.first),
        "points" => points,
    )
    YAML.write_file(joinpath(getfield(batch, :outdir), "_manifest.yaml"), manifest)
    paths
end

function run!(batch::Batch; force::Bool=false, parallel::Int=1)
    # parallel > 1 is a future hook; today everything runs serial.
    parallel == 1 || @warn "Batch run!: parallel>1 not yet wired; running serial."
    for exp in getfield(batch, :experiments)
        run!(exp; force)
    end
    batch
end

# ---------------------------------------------------------------------------
# Batch indexing / iteration / tabulation
# ---------------------------------------------------------------------------

Base.length(batch::Batch) = length(getfield(batch, :experiments))
Base.getindex(batch::Batch, i::Integer) = getfield(batch, :experiments)[i]
Base.iterate(batch::Batch, args...) = iterate(getfield(batch, :experiments), args...)

function Base.getproperty(batch::Batch, name::Symbol)
    name in (:experiments, :over, :outdir) && return getfield(batch, name)
    error(
        "Batch: no field $name (known: :experiments :over :outdir; " *
        "for per-cell access use `batch[i]` or `tabulate(batch, [:fields])`)",
    )
end

"""
    tabulate(batch::Batch, fields::Vector{Symbol}) -> NamedTuple

Per-cell column table. Each entry of `fields` is an Experiment
property name. The returned NamedTuple also carries a `values`
column with the sweep-axis values.

```julia
tab = tabulate(batch, [:Fz, :classification, :norm_drift])
tab.values, tab.Fz, tab.classification, tab.norm_drift
```
"""
function tabulate(batch::Batch, fields::AbstractVector{Symbol})
    cols = Dict{Symbol, Vector}(:values => collect(getfield(batch, :over).second))
    for f in fields
        col = Any[]
        for exp in getfield(batch, :experiments)
            push!(
                col,
                try
                    getproperty(exp, f)
                catch e
                    e
                end,
            )
        end
        cols[f] = col
    end
    (; (k => cols[k] for k in (:values, fields...))...)
end

# ---------------------------------------------------------------------------
# check / compare — Experiment ↔ RunResult bridges
# ---------------------------------------------------------------------------

"""
    check(spec, exp::Experiment) -> CheckResult

Adapter: applies an existing Spec (ConservationSpec / OperatorRHSSpec /
…) to an Experiment by routing through its cached RunResult. The
result is identical to `check(spec, open_result(_result_path(exp)))`
but reuses the lazy cache.
"""
check(spec, exp::Experiment) = check(spec, _runresult(exp))

"""
    compare(a::Experiment, b::Experiment; label_a="A", label_b="B") -> RunComparison

Pair two Experiments for A/B diff. Thin wrapper over `compare_runs`
that reuses each Experiment's lazy RunResult.
"""
function compare(
    a::Experiment, b::Experiment;
    label_a::AbstractString="A", label_b::AbstractString="B",
)
    compare_runs(_runresult(a), _runresult(b); label_a, label_b)
end

# ---------------------------------------------------------------------------
# audit(::Experiment) — end-to-end run + check
# ---------------------------------------------------------------------------

"""
    audit(exp::Experiment; spec=ConservationSpec(), verbose=true) -> CheckResult

End-to-end: `run!(exp)` (idempotent — no-op if cached) followed by
`check(spec, exp)`. The 1-liner that replaces the old
`audit(yaml::AbstractString)` glue.
"""
function audit(exp::Experiment; spec=ConservationSpec(), verbose::Bool=true)
    run!(exp)
    verbose && @info "audit" outdir = getfield(exp, :outdir)
    check(spec, exp)
end
