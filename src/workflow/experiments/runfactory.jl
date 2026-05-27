# --- Spec-builder DSL (config / block primitives) ---
#
# YAML-schema as Julia kwargs. Returns plain `Dict` objects shaped for
# YAML serialisation. `config([ground_state(...), dynamics(...), ...])`
# assembles them into a full pipeline-config Dict, which is then handed
# to `Experiment(spec; outdir)` (see `workflow/experiment.jl`) for the
# lifecycle (persist → run → observe).
#
# This layer has no I/O and no atom / protocol / experiment names — it's
# the schema constructor only. Batch persistence + sweep + run live on
# top in `Batch` / `Experiment`.

using YAML

export config,
    ground_state, dynamics, analyze,
    B, ddi, lhy, loss, save, ramp, rate

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

When `enabled=false`, the `secular` key is omitted (matches the schema's
"DDI off" form, where secular has no meaning).
"""
function ddi(; enabled::Bool=true, secular::Union{Nothing, Bool}=nothing)
    body = Dict{Any, Any}("enabled" => enabled)
    enabled || return body
    body["secular"] = secular === nothing ? false : secular
    body
end

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
    B::Union{Nothing, Dict}=nothing,
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
        "ddi" => ddi,
        "lhy" => lhy,
    )
    B === nothing || (body["B"] = B)
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

# === Internal helpers (used by config() and by Experiment / Batch) ===

_dictify(d::Dict) = d
_dictify(nt::NamedTuple) = Dict{Any, Any}(string(k) => v for (k, v) in pairs(nt))
_dictify(p::AbstractDict) = Dict{Any, Any}(string(k) => v for (k, v) in p)

# Dotted-path override: `:pipeline_2_dynamics_loss` walks through Dict /
# Vector levels. Numeric path tokens index into vectors (1-based,
# matching pipeline list index). Used by `Batch` to apply the sweep
# axis to a base spec.
# Resolve a path-token to a vector index. Supports literal integers and
# the keyword `end` for "last cell" (matches Julia's `vec[end]` idiom).
_path_idx(token::AbstractString, vec) = token == "end" ? lastindex(vec) : parse(Int, token)

function _set_path!(node, tokens::AbstractVector, value)
    isempty(tokens) && throw(ArgumentError("empty path"))
    if length(tokens) == 1
        key = tokens[1]
        if node isa AbstractVector
            idx = _path_idx(key, node)
            value === nothing ? deleteat!(node, idx) : (node[idx] = value)
        else
            value === nothing ? delete!(node, key) : (node[key] = value)
        end
        return value
    end
    if node isa AbstractVector
        idx = _path_idx(tokens[1], node)
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
