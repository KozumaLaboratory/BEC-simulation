# --- Phase-object builders: waveforms + Zeeman + Raman + interpolators ---

"""
    _make_waveform(spec, duration; omega_ref=NaN) -> Waveform

Convert a YAML scalar or `{sinusoidal: {...}}` / `{chirped_sinusoidal: {...}}` /
`{gaussian_pulse: {...}}` / `{piecewise: {...}}` / `{interpolated: {...}}` /
`{csv: ...}` dict into a Waveform.

When `omega_ref` is finite (rad/s), accepts unit-bearing strings for time and
frequency fields:

  - `frequency: "226 Hz"` → dimensionless waveform freq = ω_phys / (2π·ω_ref)
  - `freq_start: "100 Hz"`, `freq_end: "1 kHz"`           (same convention)
  - `duration: "10 ms"`, `t_center: "5 ms"`, `sigma: "1 ms"`  (× ω_ref)

`duration::Float64` (positional) is the dimensionless step duration used as
default for chirp/pulse durations and as a fallback unit base for absolute
time fields. When `omega_ref` is NaN (legacy / unrecognized callers), all
fields fall back to plain `Float64(get(...))`.
"""
function _make_waveform(spec, duration::Float64; omega_ref::Float64=NaN)
    # Helpers route Real → Float64 (legacy) and String → unit-aware parse
    # Frequency: dimensionless waveform-freq = ω_phys / (2π·ω_ref).
    # We re-use _parse_dimless_freq with scale = 2π·ω_ref to get this.
    _f(node) = isnan(omega_ref) ? Float64(node) :
               _parse_dimless_freq(node, 2π * omega_ref)
    _t(node) = isnan(omega_ref) ? Float64(node) :
               _parse_dimless_time(node, omega_ref)

    spec isa Dict || return ConstantWaveform(Float64(spec))
    if haskey(spec, "sinusoidal")
        s = spec["sinusoidal"]
        return SinusoidalWaveform(;
            center=Float64(get(s, "center", 0.0)),
            amplitude=Float64(get(s, "amplitude", 1.0)),
            frequency=_f(get(s, "frequency", 1.0)),
            phase=Float64(get(s, "phase", 0.0)),
        )
    elseif haskey(spec, "chirped_sinusoidal")
        c = spec["chirped_sinusoidal"]
        return ChirpedSinusoidalWaveform(;
            center=Float64(get(c, "center", 0.0)),
            amplitude=Float64(get(c, "amplitude", 1.0)),
            freq_start=_f(get(c, "freq_start", 0.0)),
            freq_end=_f(get(c, "freq_end", get(c, "freq_start", 0.0))),
            duration=_t(get(c, "duration", duration)),
            phase=Float64(get(c, "phase", 0.0)),
        )
    elseif haskey(spec, "gaussian_pulse")
        g = spec["gaussian_pulse"]
        return GaussianPulseWaveform(;
            center=Float64(get(g, "center", 0.0)),
            amplitude=Float64(get(g, "amplitude", 1.0)),
            t_center=_t(get(g, "t_center", duration / 2)),
            sigma=_t(get(g, "sigma", 0.01)),
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
    elseif haskey(spec, "from")
        # Implicit ramp form: {from, to?, scale?}
        from = Float64(spec["from"])
        to = Float64(get(spec, "to", from))
        scale = Symbol(get(spec, "scale", "linear"))
        return RampWaveform(from, to, duration, scale)
    end
    # Reject unknown / typo'd waveform keys with a recognisable message
    # instead of letting `spec["from"]` throw a bare KeyError("from").
    throw(ArgumentError(
        "Unknown waveform spec: keys $(collect(keys(spec))). " *
        "Recognised: sinusoidal, chirped_sinusoidal, gaussian_pulse, " *
        "piecewise, interpolated, csv, or {from, to, scale}."))
end

"""
    _build_phase_zeeman(phase_raw, t_offset, duration) -> ZeemanParams or TimeDependentZeeman

Build the per-phase Zeeman object from override-applied raw YAML dict.

Level 0 (dimensionless `p`/`q`/`bx`/`by`) delegates to `_parse_zeeman`,
which handles all four channels including the transverse `bx`/`by`
fields. Levels 1/2 (Gauss-valued) require an atom kwarg and route
through `_build_zeeman_dispatched`. Non-zero `t_offset` post-shifts the
resulting waveforms by sampling onto a fresh time grid.
"""
function _build_phase_zeeman(phase_raw::Dict, t_offset::Float64, duration::Float64;
    atom=nothing, p_step::Dict=Dict{String, Any}())
    gs = get(phase_raw, "ground_state", Dict())
    z = get(gs, "zeeman", Dict())
    z isa Dict || return ZeemanParams(0.0, 0.0)

    level = _detect_zeeman_level(z)
    if level >= 1
        atom === nothing && throw(ArgumentError(
            "zeeman Level $level requires atom; caller must pass atom kwarg"))
        zee = _build_zeeman_dispatched(z, duration, atom, p_step)
    else
        zee = _parse_zeeman(z, duration)
    end

    # Time-shift (samples each waveform onto an offset grid). Static
    # ZeemanParams are unaffected by t_offset; only TimeDependent forms
    # need adjusting.
    if t_offset != 0.0 && zee isa TimeDependentZeeman
        return TimeDependentZeeman(
            _shift_waveform(zee.p_wf, t_offset, duration),
            _shift_waveform(zee.q_wf, t_offset, duration),
            zee.bx_wf === nothing ? nothing : _shift_waveform(zee.bx_wf, t_offset, duration),
            zee.by_wf === nothing ? nothing : _shift_waveform(zee.by_wf, t_offset, duration),
        )
    end
    zee
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
                "Unknown ramp scale: $scale. Supported: linear, log, sqrt, cosine, exponential, reverse_sqrt"
            ),
        )
    end
end
