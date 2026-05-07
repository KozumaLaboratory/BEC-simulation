# --- Potential builders: harmonic + beam + composite ---

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
        HarmonicTrap(NTuple{ndim, Float64}(omega))
    elseif pc.type == :gravity
        g = Float64(get(pc.params, "g", 9.81))
        axis = Int(get(pc.params, "axis", ndim))
        GravityPotential{ndim}(g, axis)
    elseif pc.type == :crossed_dipole
        pol = Float64(pc.params["polarizability"])
        beam_dicts = pc.params["beams"]
        beams = [_build_beam(bd) for bd in beam_dicts]
        CrossedDipoleTrap{ndim}(beams, pol)
    elseif pc.type == :ring
        radius = Float64(get(pc.params, "radius", 5.0))
        strength = Float64(get(pc.params, "strength", 50.0))
        width = Float64(get(pc.params, "width", 1.0))
        RingPotential{ndim}(radius, strength, width)
    elseif pc.type == :box
        sz = _to_float_vec(pc.params["size"])
        length(sz) == ndim ||
            throw(ArgumentError("box size length must match grid dimensions ($ndim)"))
        wall_strength = Float64(get(pc.params, "wall_strength", 1000.0))
        wall_width = Float64(get(pc.params, "wall_width", 0.5))
        BoxPotential{ndim}(NTuple{ndim, Float64}(sz), wall_strength, wall_width)
    elseif pc.type == :lattice || pc.type == :optical_lattice
        depth = NTuple{ndim, Float64}(_to_float_vec(pc.params["depth"]))
        period = NTuple{ndim, Float64}(_to_float_vec(pc.params["period"]))
        phase = NTuple{ndim, Float64}(_to_float_vec(get(pc.params, "phase", zeros(ndim))))
        OpticalLatticePotential{ndim}(depth, period, phase)
    elseif pc.type == :double_well
        separation = Float64(get(pc.params, "separation", 4.0))
        barrier = Float64(get(pc.params, "barrier", 10.0))
        omega = NTuple{ndim, Float64}(_to_float_vec(get(pc.params, "omega", ones(ndim))))
        axis = Int(get(pc.params, "axis", 1))
        DoubleWellPotential{ndim}(separation, barrier, omega, axis)
    elseif pc.type == :quartic
        omega = NTuple{ndim, Float64}(_to_float_vec(pc.params["omega"]))
        lambda = NTuple{ndim, Float64}(_to_float_vec(pc.params["lambda"]))
        QuarticPotential{ndim}(omega, lambda)
    elseif pc.type == :laguerre_gauss || pc.type == :lg_beam
        power = Float64(get(pc.params, "power", 1.0))
        waist = Float64(get(pc.params, "waist", 10.0))
        l_mode = Int(get(pc.params, "l_mode", 1))
        p_mode = Int(get(pc.params, "p_mode", 0))
        pol = Float64(get(pc.params, "polarizability", 1.0))
        LaguerreGaussBeam{ndim}(power, waist, l_mode, p_mode, pol)
    elseif pc.type == :plug || pc.type == :plug_beam
        strength = Float64(get(pc.params, "strength", 50.0))
        waist = Float64(get(pc.params, "waist", 2.0))
        PlugBeam{ndim}(strength, waist)
    elseif pc.type == :shaken_lattice
        depth = NTuple{ndim, Float64}(_to_float_vec(pc.params["depth"]))
        period = NTuple{ndim, Float64}(_to_float_vec(pc.params["period"]))
        shake_specs = get(pc.params, "shake", nothing)
        duration = Float64(get(pc.params, "duration", 1.0))
        shake_wf = if shake_specs !== nothing
            wfs = _to_float_vec(shake_specs)
            NTuple{ndim, Waveform}(
                ntuple(d -> ConstantWaveform(d <= length(wfs) ? wfs[d] : 0.0), ndim)
            )
        else
            NTuple{ndim, Waveform}(ntuple(_ -> ConstantWaveform(0.0), ndim))
        end
        ShakenLatticePotential{ndim}(depth, period, shake_wf)
    elseif pc.type == :magnetic_gradient
        gradient = Float64(pc.params["gradient"])
        axis = Int(get(pc.params, "axis", ndim))
        g_F = Float64(get(pc.params, "g_F", 1.0))
        MagneticGradient{ndim}(gradient, axis, g_F)
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
    position = NTuple{3, Float64}(_to_float_vec(d["position"]))
    direction = NTuple{3, Float64}(_to_float_vec(d["direction"]))
    GaussianBeam(wavelength, power, waist, position, direction)
end
"""Parse a potential spec (dict or list of dicts) and build the potential."""
function _parse_and_build_potential(pot_d, ndim::Int)
    if pot_d isa Vector
        components = [
            PotentialConfig(Symbol(get(c, "type", "harmonic")),
                _to_string_keys(Dict(k => v for (k, v) in c if k != "type"))) for c in pot_d
        ]
        _build_potential(
            PotentialConfig(:composite, Dict{String, Any}("components" => components)), ndim
        )
    else
        _build_potential(
            PotentialConfig(Symbol(get(pot_d, "type", "harmonic")),
                _to_string_keys(Dict(k => v for (k, v) in pot_d if k != "type"))), ndim)
    end
end
