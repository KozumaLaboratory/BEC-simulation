# --- Abstract config builders + batch sweep ---
#
# YAML-schema as Julia kwargs. Replaces scripts/validation/*_gen.jl with
# REPL-callable functions whose names match YAML keys 1:1.
#
# Pattern: each function returns a `Dict` (or vector of Dicts) shaped for
# YAML serialisation. `config([...])` assembles them into a full pipeline
# config; `sweep(outdir, base; over, name)` writes N variants + a
# `_manifest.yaml` so the batch is reproducible via `regenerate(outdir)`.
#
# No atom / protocol / experiment names appear in this layer.

using YAML
using Dates: now

export config,
    ground_state, dynamics, analyze,
    B, ddi, lhy, loss, save, ramp, rate,
    sweep, regenerate

# === ramp / rate value markers ===
struct Ramp
    from::Any
    to::Any
    duration::Float64
end

struct RateSpec
    value::Any  # Number or Ramp
end

"""
    ramp(from, to; duration=0.0)

Linear ramp from `from` → `to` over `duration` (dimensionless ω_ref⁻¹).
Embeds in a `B(...)` call for time-dependent Bz / B_mag / theta.
"""
ramp(from, to; duration::Real=0.0) = Ramp(from, to, float(duration))

"""
    rate(v)

Wraps `v` (a Number or a `ramp(...)`) into the `{rate: ...}` form used
for time-dependent `phi` in the spherical-B schema. Equivalent to the
YAML `phi: {rate: <v>}` and `phi: {rate: {from, to, duration}}`.
"""
rate(v) = RateSpec(v)
rate(from, to; duration::Real=0.0) = RateSpec(ramp(from, to; duration=duration))

# === Block builders (match YAML sub-keys 1:1) ===

_serialize_b(v::Ramp) = Dict("from" => v.from, "to" => v.to, "duration" => v.duration)
function _serialize_b(v::RateSpec)
    inner = v.value isa Ramp ? _serialize_b(v.value) : v.value
    Dict("rate" => inner)
end
_serialize_b(v) = v

"""
    B(; kwargs...)

Magnetic-field block. Pass any subset of `Bz`, `B_mag`, `theta`, `phi`.
Each value may be a constant (Number or "X Gauss" string), a
`ramp(from, to; duration)`, or — for `phi` — a `rate(...)` wrapper.
`theta` and `phi` default to `0.0` when not supplied.
"""
function B(; kwargs...)
    body = Dict{Any, Any}()
    haskey(kwargs, :theta) || (body["theta"] = 0.0)
    haskey(kwargs, :phi) || (body["phi"] = 0.0)
    for (k, v) in pairs(kwargs)
        body[string(k)] = _serialize_b(v)
    end
    body
end

"""
    ddi(; enabled=true, secular=false)
"""
ddi(; enabled::Bool=true, secular::Bool=false) = Dict{Any, Any}(
    "enabled" => enabled, "secular" => secular
)

"""
    lhy(kind=:none)

LHY block. `kind` ∈ {:none, :scalar, :polar_contact, :polar_dipolar,
:fm_contact, :fm_dipolar, :icosahedral, :quasi_2d, :full_bdg,
:polar_two_channel}.
"""
lhy(kind::Symbol=:none) = Dict{Any, Any}("kind" => string(kind))

"""
    loss(; K3_si=0.0, gamma_dr=0.0, n_components=13)

Loss block. Returns `nothing` when both terms are zero (the caller should
then omit the block entirely). `K3_si` is the per-component 3-body
coefficient in m⁶/s; serialised as a length-`n_components` list with the
"X m^6/s" unit string.
"""
function loss(; K3_si::Real=0.0, gamma_dr::Real=0.0, n_components::Int=13)
    iszero(K3_si) && iszero(gamma_dr) && return nothing
    body = Dict{Any, Any}()
    iszero(gamma_dr) || (body["gamma_dr"] = float(gamma_dr))
    iszero(K3_si) || (body["K3_per_m_si"] = ["$(K3_si) m^6/s" for _ in 1:n_components])
    body
end

"""
    save(; every=100, psi=true, precision=:f64)
"""
save(; every::Int=100, psi::Bool=true, precision::Symbol=:f64) = Dict{Any, Any}(
    "every" => every, "psi" => psi, "precision" => string(precision)
)

# === Pipeline step builders (match YAML pipeline keys 1:1) ===

"""
    ground_state(; atom, grid, box=12.0, trap, interactions, ddi=ddi(),
                 lhy=lhy(), B, initial_state=:m_minus_F, init_sigma=1.5,
                 dt=0.005, n_steps=2000, tol=1.0e-9, gauge_fix=false,
                 extra...) -> Dict

Single ground-state pipeline step. `grid` is `(nx, ny, nz)` or `Int` (cubic).
`trap` is the harmonic-trap ω-ratios `(ωx, ωy, ωz)` or `Real` (isotropic).
`interactions` is a Dict / NamedTuple of `(N_atoms, omega_ref, c1_ratio,
[c2_ratio, ...])`.
"""
function ground_state(;
    atom::AbstractString,
    grid,
    box=12.0,
    trap,
    interactions,
    ddi::Dict=ddi(),
    lhy::Dict=lhy(),
    B::Dict,
    initial_state::Symbol=:m_minus_F,
    init_sigma::Real=1.5,
    dt::Real=0.005,
    n_steps::Int=2000,
    tol::Real=1.0e-9,
    gauge_fix::Bool=false,
    extra::Dict=Dict{Any, Any}(),
)
    grid_n = grid isa Tuple ? collect(grid) : [grid, grid, grid]
    box_v = box isa Tuple ? collect(box) : [box, box, box]
    trap_v = trap isa Tuple ? collect(trap) : [1.0, 1.0, float(trap)]
    body = Dict{Any, Any}(
        "atom" => String(atom),
        "grid" => Dict("n" => grid_n, "box" => box_v),
        "potential" => Dict("type" => "harmonic", "omega" => trap_v),
        "interactions" => _dictify(interactions),
        "ddi" => ddi,
        "lhy" => lhy,
        "B" => B,
        "gauge_fix" => gauge_fix,
        "initial_state" => string(initial_state),
        "init_sigma" => float(init_sigma),
        "dt" => float(dt),
        "n_steps" => n_steps,
        "tol" => float(tol),
    )
    merge!(body, extra)
    Dict{Any, Any}("ground_state" => body)
end

"""
    dynamics(; duration, dt=0.005, B, ddi=ddi(secular=false), lhy=lhy(),
             loss=nothing, rotating_frame_omega=0.0,
             seed_amplitude=1.0e-6, seed_k_cut=2.5,
             save=save(), extra...) -> Dict

Single dynamics pipeline step.
"""
function dynamics(;
    duration::Real,
    dt::Real=0.005,
    B::Dict,
    ddi::Dict=Dict{Any, Any}("secular" => false),
    lhy::Dict=lhy(),
    loss::Union{Nothing, Dict}=nothing,
    rotating_frame_omega::Union{Nothing, Real}=nothing,
    seed_amplitude::Union{Nothing, Real}=1.0e-6,
    seed_k_cut::Union{Nothing, Real}=2.5,
    save::Dict=save(),
    extra::Dict=Dict{Any, Any}(),
)
    body = Dict{Any, Any}(
        "duration" => float(duration),
        "dt" => float(dt),
        "B" => B,
        "ddi" => ddi,
        "lhy" => lhy,
    )
    rotating_frame_omega === nothing ||
        (body["rotating_frame_omega"] = float(rotating_frame_omega))
    loss === nothing || (body["loss"] = loss)
    seed_amplitude === nothing || (body["seed_amplitude"] = float(seed_amplitude))
    seed_k_cut === nothing || (body["seed_k_cut"] = float(seed_k_cut))
    body["save"] = save
    merge!(body, extra)
    Dict{Any, Any}("dynamics" => body)
end

"""
    analyze(steps::Symbol...) -> Dict

Analyze pipeline step. Each `step` is the analyzer name; emitted as
`- <step>: {}` per the YAML schema.
"""
analyze(steps::Symbol...) = Dict{Any, Any}(
    "analyze" => [Dict(string(s) => Dict{Any, Any}()) for s in steps]
)

# === Top-level config assembly ===

"""
    config(pipeline; defaults=nothing, metadata=nothing, dealias=nothing) -> Dict

Wrap a vector of pipeline-step Dicts (from `ground_state`, `dynamics`,
`analyze`) into a full YAML-shaped config Dict. `defaults` accepts a
NamedTuple or Dict mapping to the top-level `defaults:` block; `metadata`
likewise.
"""
function config(
    pipeline::AbstractVector;
    defaults=nothing,
    metadata=nothing,
    dealias=nothing,
)
    out = Dict{Any, Any}()
    metadata === nothing || (out["metadata"] = _dictify(metadata))
    defaults === nothing || (out["defaults"] = _dictify(defaults))
    dealias === nothing || (out["dealias"] = _dictify(dealias))
    out["pipeline"] = collect(pipeline)
    out
end

# === Sweep / manifest / regenerate ===

"""
    sweep(outdir, base_config; over, name, header="", manifest_extras=Dict()) -> Vector{String}

Generate N YAML configs by varying one parameter dotted-path within
`base_config`. Writes `_manifest.yaml` capturing the call so
`regenerate(outdir)` can recreate the batch byte-equivalent.

`over` is a `Pair{Symbol, AbstractVector}` where the symbol is a
dotted-path key (e.g. `:pipeline_2_dynamics_loss_K3_si`) into the config
tree. The numeric tokens denote pipeline-list index (1-based).

`name` is a function `value -> String` for the YAML filename (no .yaml).

```julia
base = config([
    ground_state(atom="Eu151", grid=32, trap=(1,1,0.25), ...),
    dynamics(duration=20.0, B=B(Bz=ramp(0.01, 2.6e-5)), loss=loss()),
    analyze(:phase_classify, :winding_map, :energy_decomposition),
])
sweep("runs/eu_k3_sweep", base;
    over = :pipeline_2_dynamics_loss => map(K3 -> loss(K3_si=K3),
                                            [0, 1e-41, 3e-41, ...]),
    name = i -> "K3x\$(i)",
)
```
"""
function sweep(
    outdir::AbstractString,
    base_config::Dict;
    over::Pair{Symbol, <:AbstractVector},
    name::Function,
    header::AbstractString="",
    manifest_extras::Dict=Dict{Any, Any}(),
)
    mkpath(outdir)
    path_str = String(over.first)
    values_ = collect(over.second)
    points = Vector{Dict{Any, Any}}(undef, length(values_))
    written = String[]
    for (i, v) in enumerate(values_)
        cfg = _override(base_config, path_str, v)
        fname = String(name(v)) * ".yaml"
        path = joinpath(outdir, fname)
        _write_yaml(path, cfg; header)
        points[i] = Dict{Any, Any}("filename" => fname, "value" => _to_yaml_value(v))
        push!(written, path)
        println("wrote $fname")
    end
    manifest = Dict{Any, Any}(
        "base_config" => base_config,
        "over_path" => path_str,
        "points" => points,
        "name_fn_source" => string(name),
        "generated_at" => string(now()),
        "header" => String(header),
    )
    merge!(manifest, manifest_extras)
    manifest_path = joinpath(outdir, "_manifest.yaml")
    YAML.write_file(manifest_path, manifest)
    println("manifest at $manifest_path")
    written
end

"""
    sweep(outdir, base_config, cells; header="", manifest_extras=Dict()) -> Vector{String}

Multi-override cell list variant. Each `cell` is a `Pair{String, Dict}`
mapping a filename (no `.yaml`) to a Dict of dotted-path => value
overrides. Applies all overrides per cell before writing.

```julia
cells = Pair{String,Dict}[]
for (K3, gdr, LHY) in Iterators.product([false,true], [false,true], [false,true])
    name = "K\$(Int(K3))_gdr\$(Int(gdr))_LHY\$(Int(LHY))"
    push!(cells, name => Dict(
        :pipeline_1_ground_state_lhy => lhy(LHY ? :scalar : :none),
        :pipeline_2_dynamics_lhy => lhy(LHY ? :scalar : :none),
        :pipeline_2_dynamics_loss => loss(K3_si=(K3 ? 1e-41 : 0.0),
                                          gamma_dr=(gdr ? 0.02 : 0.0)),
    ))
end
sweep("runs/eu_k3_arrest", base, cells)
```
"""
function sweep(
    outdir::AbstractString,
    base_config::Dict,
    cells::AbstractVector;
    header::AbstractString="",
    manifest_extras::Dict=Dict{Any, Any}(),
)
    mkpath(outdir)
    written = String[]
    manifest_cells = Vector{Dict{Any, Any}}(undef, length(cells))
    for (i, cell) in enumerate(cells)
        name, overrides = cell
        cfg = deepcopy(base_config)
        for (path, value) in overrides
            _set_path!(cfg, split(String(path), '_'), value)
        end
        fname = String(name) * ".yaml"
        path = joinpath(outdir, fname)
        _write_yaml(path, cfg; header)
        manifest_cells[i] = Dict{Any, Any}(
            "filename" => fname,
            "overrides" => Dict{Any, Any}(string(k) => _to_yaml_value(v)
                                          for (k, v) in overrides),
        )
        push!(written, path)
        println("wrote $fname")
    end
    manifest = Dict{Any, Any}(
        "base_config" => base_config,
        "cells" => manifest_cells,
        "generated_at" => string(now()),
        "header" => String(header),
    )
    merge!(manifest, manifest_extras)
    manifest_path = joinpath(outdir, "_manifest.yaml")
    YAML.write_file(manifest_path, manifest)
    println("manifest at $manifest_path")
    written
end

"""
    regenerate(outdir) -> Vector{String}

Read `outdir/_manifest.yaml` and rewrite every YAML point. Useful for
audits ("does the recorded recipe still reproduce the on-disk YAMLs?")
and for upgrading after a runfactory bug fix.
"""
function regenerate(outdir::AbstractString)
    mpath = joinpath(outdir, "_manifest.yaml")
    isfile(mpath) || throw(ArgumentError("no _manifest.yaml in $outdir"))
    manifest = YAML.load_file(mpath)
    base = manifest["base_config"]
    header = get(manifest, "header", "")
    written = String[]
    if haskey(manifest, "points")
        path_str = manifest["over_path"]
        for pt in manifest["points"]
            cfg = _override(base, path_str, pt["value"])
            path = joinpath(outdir, pt["filename"])
            _write_yaml(path, cfg; header)
            push!(written, path)
            println("regenerated $(pt["filename"])")
        end
    elseif haskey(manifest, "cells")
        for cell in manifest["cells"]
            cfg = deepcopy(base)
            for (path_str, value) in cell["overrides"]
                _set_path!(cfg, split(String(path_str), '_'), value)
            end
            path = joinpath(outdir, cell["filename"])
            _write_yaml(path, cfg; header)
            push!(written, path)
            println("regenerated $(cell["filename"])")
        end
    else
        throw(ArgumentError("_manifest.yaml has neither `points` nor `cells`"))
    end
    written
end

# === Internal helpers ===

_dictify(d::Dict) = d
_dictify(nt::NamedTuple) = Dict{Any, Any}(string(k) => v for (k, v) in pairs(nt))
_dictify(p::AbstractDict) = Dict{Any, Any}(string(k) => v for (k, v) in p)

_to_yaml_value(d::Dict) = d
_to_yaml_value(x) = x

function _write_yaml(path::AbstractString, cfg::Dict; header::AbstractString="")
    open(path, "w") do io
        isempty(header) || (write(io, header); endswith(header, "\n") || write(io, "\n"))
        YAML.write(io, cfg)
    end
end

# Dotted-path override: parses `:pipeline_2_dynamics_loss_K3_si` style into a
# walk through Dict / Vector levels. Numeric path tokens index into vectors
# (1-based, matching pipeline list index).
function _override(cfg::Dict, dotted_path::AbstractString, value)
    out = deepcopy(cfg)
    tokens = split(dotted_path, '_')
    _set_path!(out, tokens, value)
    out
end

function _set_path!(node, tokens::AbstractVector, value)
    isempty(tokens) && throw(ArgumentError("empty path"))
    if length(tokens) == 1
        key = tokens[1]
        if node isa AbstractVector
            value === nothing ? deleteat!(node, parse(Int, key)) :
            (node[parse(Int, key)] = value)
        else
            value === nothing ? delete!(node, key) : (node[key] = value)
        end
        return value
    end
    if node isa AbstractVector
        idx = parse(Int, tokens[1])
        return _set_path!(node[idx], tokens[2:end], value)
    end
    # Progressively longer prefixes match multi-word keys when a numeric
    # pipeline-index sits between them.
    for split_i in length(tokens):-1:1
        key = join(tokens[1:split_i], "_")
        if haskey(node, key)
            child = node[key]
            if split_i == length(tokens)
                value === nothing ? delete!(node, key) : (node[key] = value)
                return value
            end
            return _set_path!(child, tokens[(split_i + 1):end], value)
        end
    end
    # Path didn't match an existing key — if value is non-nothing, create the
    # leaf as a new entry (allows setting fields the base config omitted).
    if value !== nothing
        node[tokens[end]] = value
        return value
    end
    return value  # nothing + missing path = no-op
end
