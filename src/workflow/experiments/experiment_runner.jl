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
