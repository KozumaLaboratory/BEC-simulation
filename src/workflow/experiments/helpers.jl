# --- Experiment Configuration Types ---

struct ConstantValue
    value::Float64
end

struct LinearRamp
    from::Float64
    to::Float64
end

const RampOrConstant = Union{ConstantValue,LinearRamp}

interpolate_value(v::ConstantValue, ::Float64) = v.value
interpolate_value(v::LinearRamp, t_frac::Float64) =
    v.from + (v.to - v.from) * clamp(t_frac, 0.0, 1.0)

struct PotentialConfig
    type::Symbol
    params::Dict{String,Any}
end


function scale_interactions_quasi_2d(ip::InteractionParams, l_z::Float64)
    factor = 1.0 / (sqrt(2π) * l_z)
    if ip.c_lhy != 0.0
        @warn "c_lhy scaling under quasi-2D is approximate; 2D LHY requires logarithmic treatment"
    end
    InteractionParams(
        ip.c0 * factor,
        ip.c1 * factor,
        ip.c_lhy * factor,
        isempty(ip.c_extra) ? Float64[] : ip.c_extra .* factor,
    )
end


_zeeman_scalar(v) = v isa Dict ? Float64(v["from"]) : Float64(v)

function _parse_ramp_or_constant(v)::RampOrConstant
    if v isa Dict
        if haskey(v, "to")
            return LinearRamp(Float64(v["from"]), Float64(v["to"]))
        end
        return ConstantValue(Float64(v["from"]))
    end
    ConstantValue(Float64(v))
end

function _parse_potential_config(d::Dict)
    t = Symbol(get(d, "type", "none"))
    params = Dict{String,Any}()
    for (k, v) in d
        k == "type" && continue
        params[k] = v
    end
    PotentialConfig(t, params)
end

function _parse_potential_config(v::Vector)
    components = [_parse_potential_config(d) for d in v]
    PotentialConfig(:composite, Dict{String,Any}("components" => components))
end

_to_int_vec(v::Vector) = Int[Int(x) for x in v]
_to_int_vec(v) = Int[Int(v)]
_to_float_vec(v::Vector) = Float64[Float64(x) for x in v]
_to_float_vec(v) = Float64[Float64(v)]

"""
Parse c_extra (c2, c3, c4, ...) from a YAML interactions dict. Handles sparse keys
(e.g. c4 present without c2/c3) by filling zeros up to the largest cN found.
"""
function _parse_c_extra(inter::Dict, ::Int)
    max_n = 0
    for k in keys(inter)
        m = match(r"^c(\d+)$", string(k))
        m === nothing && continue
        n = parse(Int, m.captures[1])
        n >= 2 && (max_n = max(max_n, n))
    end
    max_n < 2 && return Float64[]
    c_extra = zeros(Float64, max_n - 1)
    for n = 2:max_n
        haskey(inter, "c$n") && (c_extra[n-1] = Float64(inter["c$n"]))
    end
    c_extra
end

# --- Scan Parsing Helpers ---

function _parse_override_scan(d::Dict)
    points = expand_scan_points(d)

    comparison_runs = if haskey(d, "comparison_runs")
        Tuple{String,Dict{String,Any}}[
            (String(r["name"]), parse_override_map(get(r, "override", Dict())))
            for r in d["comparison_runs"]
        ]
    else
        Tuple{String,Dict{String,Any}}[]
    end

    continuation = Bool(get(d, "continuation", false))
    auto_rotate = Bool(get(d, "auto_rotate_on_mz", false))

    OverrideScan(points, comparison_runs, continuation, auto_rotate)
end

function _parse_constrained_jz_scan(d::Dict)
    target_values = Float64[Float64(v) for v in d["target_values"]]
    tolerance = Float64(get(d, "tolerance", 0.05))
    max_iter = Int(get(d, "max_iter", 15))
    omega_range = if haskey(d, "omega_range")
        r = d["omega_range"]
        (Float64(r[1]), Float64(r[2]))
    else
        (-10.0, 10.0)
    end
    ConstrainedJzScan(target_values, tolerance, max_iter, omega_range)
end

function _build_potential(pc::PotentialConfig, ndim::Int)
    if pc.type == :none
        NoPotential()
    elseif pc.type == :harmonic
        omega_raw = get(pc.params, "omega", nothing)
        omega_raw === nothing && throw(ArgumentError("Harmonic potential requires omega"))
        omega = _to_float_vec(omega_raw)
        length(omega) == ndim ||
            throw(ArgumentError("omega length must match grid dimensions ($ndim)"))
        HarmonicTrap(NTuple{ndim,Float64}(omega))
    elseif pc.type == :gravity
        g = Float64(get(pc.params, "g", 9.81))
        axis = Int(get(pc.params, "axis", ndim))
        GravityPotential{ndim}(g, axis)
    elseif pc.type == :crossed_dipole
        pol = Float64(pc.params["polarizability"])
        beam_dicts = pc.params["beams"]
        beams = [_build_beam(bd) for bd in beam_dicts]
        CrossedDipoleTrap{ndim}(beams, pol)
    elseif pc.type == :composite
        components = [_build_potential(c, ndim) for c in pc.params["components"]]
        CompositePotential{ndim}(components)
    else
        throw(ArgumentError("Unknown potential type: $(pc.type)"))
    end
end

function _build_beam(d::Dict)
    wavelength = Float64(d["wavelength"])
    power = Float64(d["power"])
    waist = Float64(d["waist"])
    position = NTuple{3,Float64}(_to_float_vec(d["position"]))
    direction = NTuple{3,Float64}(_to_float_vec(d["direction"]))
    GaussianBeam(wavelength, power, waist, position, direction)
end

"""
    _build_phase_zeeman(phase_raw, t_offset, duration) → ZeemanParams or TimeDependentZeeman

Build the per-phase Zeeman object directly from the override-applied raw
YAML dict. Entries under `ground_state.zeeman.p`/`q` may be scalars
(constant over the phase) or `{from, to}` dicts (linear ramp over the
phase duration). If both p and q are scalar the result is a cheap
constant `ZeemanParams`; otherwise it is a `TimeDependentZeeman` closure.
"""
function _build_phase_zeeman(phase_raw::Dict, t_offset::Float64, duration::Float64)
    gs = get(phase_raw, "ground_state", Dict())
    z = get(gs, "zeeman", Dict())
    p_spec = get(z, "p", 0.0)
    q_spec = get(z, "q", 0.0)

    p_ramp = _zeeman_ramp(p_spec)
    q_ramp = _zeeman_ramp(q_spec)

    if p_ramp isa ConstantValue && q_ramp isa ConstantValue
        ZeemanParams(p_ramp.value, q_ramp.value)
    else
        TimeDependentZeeman(t -> begin
            t_local = t - t_offset
            t_frac = duration > 0 ? t_local / duration : 0.0
            ZeemanParams(
                interpolate_value(p_ramp, t_frac),
                interpolate_value(q_ramp, t_frac),
            )
        end)
    end
end

_zeeman_ramp(v::Dict) = haskey(v, "to") ?
    LinearRamp(Float64(v["from"]), Float64(v["to"])) :
    ConstantValue(Float64(v["from"]))
_zeeman_ramp(v) = ConstantValue(Float64(v))

function _add_noise!(psi, amplitude, n_components, ndim, grid)
    n_pts = ntuple(d -> size(psi, d), ndim)
    dV = cell_volume(grid)
    dominant = argmax([
        sum(abs2, view(psi, _component_slice(ndim, n_pts, c)...)) for c = 1:n_components
    ])
    for c = 1:n_components
        c == dominant && continue
        idx = _component_slice(ndim, n_pts, c)
        view(psi, idx...) .+= amplitude .* randn(ComplexF64, n_pts)
    end
    norm = sqrt(sum(abs2, psi) * dV)
    psi ./= norm
end

function seed_noise(
    psi_gs,
    n_components::Int,
    ndim::Int,
    grid::Grid;
    amplitude::Float64 = 0.001,
    seed::Int = 42,
)
    psi = copy(psi_gs)
    Random.seed!(seed)
    _add_noise!(psi, amplitude, n_components, ndim, grid)
    psi
end
