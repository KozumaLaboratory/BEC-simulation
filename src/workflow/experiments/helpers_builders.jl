# --- Potential & Zeeman builders ---

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
    _build_phase_zeeman(phase_raw, t_offset, duration) -> ZeemanParams or TimeDependentZeeman

Build the per-phase Zeeman object from override-applied raw YAML dict.
"""
function _build_phase_zeeman(phase_raw::Dict, t_offset::Float64, duration::Float64)
    gs = get(phase_raw, "ground_state", Dict())
    z = get(gs, "zeeman", Dict())
    p_spec = get(z, "p", 0.0)
    q_spec = get(z, "q", 0.0)

    p_ramp = _parse_ramp_or_constant(p_spec)
    q_ramp = _parse_ramp_or_constant(q_spec)

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

"""Parse a potential spec (dict or list of dicts) and build the potential."""
function _parse_and_build_potential(pot_d, ndim::Int)
    if pot_d isa Vector
        components = [PotentialConfig(Symbol(get(c, "type", "harmonic")),
            _to_string_keys(Dict(k => v for (k, v) in c if k != "type"))) for c in pot_d]
        _build_potential(PotentialConfig(:composite, Dict{String,Any}("components" => components)), ndim)
    else
        _build_potential(PotentialConfig(Symbol(get(pot_d, "type", "harmonic")),
            _to_string_keys(Dict(k => v for (k, v) in pot_d if k != "type"))), ndim)
    end
end

"""
Build an interpolation function from a ramp spec.
Scalar -> constant. Dict {from, to, scale?} -> scaled interpolation.

Scale controls the t-mapping g(t): result = from + (to - from) * g(t)
- linear:      g(t) = t                          (uniform)
- log:         g(t) = log(1 + (e-1)*t)           (dense at start)
- sqrt:        g(t) = sqrt(t)                     (dense at start)
- cosine:      g(t) = (1 - cos(πt)) / 2          (S-curve: dense at both ends)
- exponential: g(t) = 1 - exp(-k*t) / (1-exp(-k)) (dense at start, k=5)
- reverse_sqrt: g(t) = t^2                        (dense at end)
"""
function _make_interpolator(spec)
    spec isa Dict || return _ -> Float64(spec)

    from = Float64(spec["from"])
    to = Float64(get(spec, "to", from))
    scale = Symbol(get(spec, "scale", "linear"))

    if scale == :linear
        return t -> from + (to - from) * t
    elseif scale == :log
        # g(t) = log(1 + (e-1)*t), maps [0,1] → [0,1], dense near t=0
        em1 = exp(1.0) - 1.0
        return t -> from + (to - from) * log(1.0 + em1 * t)
    elseif scale == :sqrt
        return t -> from + (to - from) * sqrt(t)
    elseif scale == :cosine
        return t -> from + (to - from) * (1 - cos(π * t)) / 2
    elseif scale == :exponential
        # Dense near t=0, k controls steepness
        k = 5.0
        norm = 1.0 / (1.0 - exp(-k))
        return t -> from + (to - from) * (1.0 - exp(-k * t)) * norm
    elseif scale == :reverse_sqrt
        return t -> from + (to - from) * t^2
    else
        throw(ArgumentError("Unknown ramp scale: $scale. Supported: linear, log, sqrt, cosine, exponential, reverse_sqrt"))
    end
end
