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

"""
    _make_waveform(spec, duration) -> Waveform

Convert a YAML scalar or {from, to, scale?} dict into a Waveform.
"""
function _make_waveform(spec, duration::Float64)
    spec isa Dict || return ConstantWaveform(Float64(spec))
    if haskey(spec, "sinusoidal")
        s = spec["sinusoidal"]
        return SinusoidalWaveform(;
            center=Float64(get(s, "center", 0.0)),
            amplitude=Float64(get(s, "amplitude", 1.0)),
            frequency=Float64(get(s, "frequency", 1.0)),
            phase=Float64(get(s, "phase", 0.0)),
        )
    elseif haskey(spec, "chirped_sinusoidal")
        c = spec["chirped_sinusoidal"]
        return ChirpedSinusoidalWaveform(;
            center=Float64(get(c, "center", 0.0)),
            amplitude=Float64(get(c, "amplitude", 1.0)),
            freq_start=Float64(get(c, "freq_start", 0.0)),
            freq_end=Float64(get(c, "freq_end", get(c, "freq_start", 0.0))),
            duration=Float64(get(c, "duration", duration)),
            phase=Float64(get(c, "phase", 0.0)),
        )
    elseif haskey(spec, "gaussian_pulse")
        g = spec["gaussian_pulse"]
        return GaussianPulseWaveform(;
            center=Float64(get(g, "center", 0.0)),
            amplitude=Float64(get(g, "amplitude", 1.0)),
            t_center=Float64(get(g, "t_center", duration / 2)),
            sigma=Float64(get(g, "sigma", 0.01)),
        )
    elseif haskey(spec, "piecewise")
        p = spec["piecewise"]
        times = Float64.(p["times"])
        values = Float64.(p["values"])
        return PiecewiseLinearWaveform(times, values)
    elseif haskey(spec, "interpolated")
        p = spec["interpolated"]
        times = Float64.(p["times"])
        values = Float64.(p["values"])
        return InterpolatedWaveform(times, values)
    elseif haskey(spec, "csv")
        # `csv:` may be a bare filename ("beams.csv") or a dict with optional
        # time/value column indices, scale, offset, delimiter, header flag.
        c = spec["csv"]
        path, opts = if c isa AbstractString
            (String(c), Dict{String, Any}())
        elseif c isa Dict
            (String(c["path"]), c)
        else
            throw(ArgumentError("`csv` must be a filename or a {path, ...} dict"))
        end
        # Resolve relative paths against the YAML file's directory when known
        # (ENV set by run_yaml / load_config). Otherwise treat as CWD.
        resolved = isabspath(path) ? path :
                   joinpath(get(ENV, "SPINORBEC_YAML_DIR", pwd()), path)
        isfile(resolved) || throw(ArgumentError(
            "csv waveform path not found: $resolved"))
        w = load_waveform_csv(
            resolved;
            time_col=Int(get(opts, "time_col", 1)),
            value_col=Int(get(opts, "value_col", 2)),
            header=Bool(get(opts, "header", true)),
            delimiter=first(String(get(opts, "delimiter", ","))),
        )
        scale = Float64(get(opts, "scale", 1.0))
        offset = Float64(get(opts, "offset", 0.0))
        if scale != 1.0 || offset != 0.0
            n = length(w.times)
            scaled = Vector{Float64}(undef, n)
            @inbounds for i in 1:n
                scaled[i] = scale * w.values[i] + offset
            end
            return InterpolatedWaveform(w.times, scaled)
        end
        return w
    end
    from = Float64(spec["from"])
    to = Float64(get(spec, "to", from))
    scale = Symbol(get(spec, "scale", "linear"))
    RampWaveform(from, to, duration, scale)
end

"""
    _build_phase_zeeman(phase_raw, t_offset, duration) -> ZeemanParams or TimeDependentZeeman

Build the per-phase Zeeman object from override-applied raw YAML dict.
"""
function _build_phase_zeeman(phase_raw::Dict, t_offset::Float64, duration::Float64;
    atom=nothing, p_step::Dict=Dict{String, Any}())
    gs = get(phase_raw, "ground_state", Dict())
    z = get(gs, "zeeman", Dict())
    z isa Dict || return ZeemanParams(0.0, 0.0)

    # Level 1/2 dispatch if the zeeman dict uses Gauss-valued keys.
    # Requires atom for g_F and an omega_ref from p_step.
    level = _detect_zeeman_level(z)
    if level >= 1
        atom === nothing && throw(ArgumentError(
            "zeeman Level $level requires atom; caller must pass atom kwarg"))
        return _build_zeeman_dispatched(z, duration, atom, p_step)
    end

    p_spec = get(z, "p", 0.0)
    q_spec = get(z, "q", 0.0)
    p_is_ramp = p_spec isa Dict
    q_is_ramp = q_spec isa Dict
    bx_spec = get(z, "bx", nothing)
    by_spec = get(z, "by", nothing)
    has_transverse = bx_spec !== nothing || by_spec !== nothing

    if !p_is_ramp && !q_is_ramp && !has_transverse
        return ZeemanParams(Float64(p_spec), Float64(q_spec))
    end

    p_wf = _make_waveform(p_spec, duration)
    q_wf = _make_waveform(q_spec, duration)

    if t_offset != 0.0
        # Pre-sample shifted waveforms to avoid closure type leakage
        # (see CLAUDE.md > Type stability boundaries).
        p_wf = _shift_waveform(p_wf, t_offset, duration)
        q_wf = _shift_waveform(q_wf, t_offset, duration)
    end

    bx_wf = bx_spec !== nothing ? _make_waveform(bx_spec, duration) : nothing
    by_wf = by_spec !== nothing ? _make_waveform(by_spec, duration) : nothing
    TimeDependentZeeman(p_wf, q_wf, bx_wf, by_wf)
end

"""Apply a time shift to a waveform by sampling into a PiecewiseLinearWaveform."""
function _shift_waveform(wf::Waveform, t_offset::Float64, duration::Float64; n_samples::Int=1024)
    times = collect(range(0.0, duration; length=n_samples))
    values = Float64[evaluate(wf, t - t_offset) for t in times]
    PiecewiseLinearWaveform(times, values)
end

"""
    _build_raman(p, duration) -> RamanCoupling | TimeDependentRaman | nothing

Build a Raman coupling from a dynamics step dict.
"""
function _build_raman(p::Dict, duration::Float64)
    haskey(p, "raman") || return nothing
    r = p["raman"]
    k_eff = Tuple(Float64.(r["k_eff"]))
    omega_spec = r["Omega_R"]
    delta_spec = get(r, "delta", 0.0)
    omega_is_ramp = omega_spec isa Dict
    delta_is_ramp = delta_spec isa Dict
    if !omega_is_ramp && !delta_is_ramp
        return RamanCoupling(Float64(omega_spec), Float64(delta_spec), k_eff)
    end
    TimeDependentRaman(
        _make_waveform(omega_spec, duration),
        _make_waveform(delta_spec, duration),
        k_eff,
    )
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
        throw(
            ArgumentError(
                "Unknown ramp scale: $scale. Supported: linear, log, sqrt, cosine, exponential, reverse_sqrt",
            ),
        )
    end
end
