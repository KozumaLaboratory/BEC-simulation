function _build_potential(pc::PotentialConfig, ndim::Int)
    if pc.type == :none
        NoPotential()
    elseif pc.type == :harmonic
        omega_raw = get(pc.params, "omega", nothing)
        omega_raw === nothing && throw(ArgumentError("Harmonic potential requires omega"))
        omega = _to_float_vec(omega_raw)
        length(omega) == ndim || throw(ArgumentError("omega length must match grid dimensions ($ndim)"))
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

function _build_zeeman(phase::PhaseConfig, t_offset::Float64)
    p_is_const = phase.zeeman_p isa ConstantValue
    q_is_const = phase.zeeman_q isa ConstantValue
    duration = phase.duration

    if p_is_const && q_is_const
        ZeemanParams(phase.zeeman_p.value, phase.zeeman_q.value)
    else
        TimeDependentZeeman(t -> begin
            t_local = t - t_offset
            t_frac = duration > 0 ? t_local / duration : 0.0
            p = interpolate_value(phase.zeeman_p, t_frac)
            q = interpolate_value(phase.zeeman_q, t_frac)
            ZeemanParams(p, q)
        end)
    end
end

function _add_noise!(psi, amplitude, n_components, ndim, grid)
    n_pts = ntuple(d -> size(psi, d), ndim)
    dV = cell_volume(grid)
    dominant = argmax([sum(abs2, view(psi, _component_slice(ndim, n_pts, c)...)) for c in 1:n_components])
    for c in 1:n_components
        c == dominant && continue
        idx = _component_slice(ndim, n_pts, c)
        view(psi, idx...) .+= amplitude .* randn(ComplexF64, n_pts)
    end
    norm = sqrt(sum(abs2, psi) * dV)
    psi ./= norm
end

function seed_noise(psi_gs, n_components::Int, ndim::Int, grid::Grid;
                    amplitude::Float64=0.001, seed::Int=42)
    psi = copy(psi_gs)
    Random.seed!(seed)
    _add_noise!(psi, amplitude, n_components, ndim, grid)
    psi
end
