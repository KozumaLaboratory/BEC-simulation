# --- Phase 1.5: Zeeman-level dispatch (docs/phase15_zeeman_levels.md) ---
#
# Level 0 (existing): p, q, bx, by — dimensionless (ℏω_ref units)
# Level 1 (new): Bx, By, Bz — Gauss (scalar or Waveform)
# Level 2 (new): B_mag + theta_deg + phi_deg — spherical (scalar or Waveform)
#
# All time-dep specs are sampled to PiecewiseLinearWaveform after conversion to
# keep everything concretely-typed; see CLAUDE.md > Type stability boundaries.

const _GAUSS_TO_TESLA = 1.0e-4
const _ZEEMAN_SAMPLE_N = 1024  # default — increase for stir experiments via
                               # zeeman.n_samples YAML override

"""
    _detect_zeeman_level(z::Dict) -> Int  (0, 1, or 2)

Infer the level from keys present. Explicit `level:` key wins if set.
Raises ArgumentError on mixed levels.
"""
function _detect_zeeman_level(z::Dict)
    has_l0 = any(haskey(z, k) for k in ("p", "q", "bx", "by"))
    has_l1 = any(haskey(z, k) for k in ("Bx", "By", "Bz"))
    has_l2 = haskey(z, "B_mag")
    explicit = get(z, "level", nothing)

    levels_present = count(identity, (has_l0, has_l1, has_l2))
    levels_present > 1 && throw(ArgumentError(
        "zeeman: cannot mix Level 0 (p/q/bx/by), Level 1 (Bx/By/Bz), and Level 2 (B_mag)"))

    if explicit !== nothing
        lvl = Int(explicit)
        (lvl in (0, 1, 2)) || throw(ArgumentError("zeeman.level must be 0, 1, or 2; got $lvl"))
        return lvl
    end

    has_l2 && return 2
    has_l1 && return 1
    return 0
end

"""
    _resolve_omega_ref(z::Dict, atom, p::Dict) -> Float64

Resolve the reference angular frequency (rad/s) for Gauss→dimensionless
conversion. Priority:
  1. zeeman.omega_ref_hz (Hz, this-section override; multiplied by 2π)
  2. interactions.omega_ref (rad/s, existing convention)
  3. Top-level p['omega_ref'] if present (rad/s)

Raises ArgumentError if none of the above are set — required for Level 1/2.
"""
function _resolve_omega_ref(z::Dict, p_step::Dict)
    if haskey(z, "omega_ref_hz")
        return 2π * Float64(z["omega_ref_hz"])
    end
    inter = get(p_step, "interactions", Dict())
    if inter isa Dict && haskey(inter, "omega_ref")
        return Float64(inter["omega_ref"])
    end
    if haskey(p_step, "omega_ref")
        return Float64(p_step["omega_ref"])
    end
    throw(ArgumentError(
        "zeeman Level 1/2 requires omega_ref; set zeeman.omega_ref_hz (Hz) or interactions.omega_ref (rad/s)"))
end

"""
    _gauss_to_dimless(B_gauss, g_F, omega_ref) -> Float64

Thin wrapper over existing `linear_zeeman_p(atom, B_tesla, omega_ref)` that
accepts g_F directly (so pure-unit tests don't need a full AtomSpecies) and
converts Gauss → Tesla. The formula is identical:
p = g_F · μ_B · B[T] / (ℏ · ω_ref).
"""
@inline function _gauss_to_dimless(B_gauss::Float64, g_F::Float64, omega_ref::Float64)
    g_F * Units.MU_BOHR * B_gauss * _GAUSS_TO_TESLA / (Units.HBAR * omega_ref)
end

"""Evaluate a YAML spec at time t (scalar or Waveform)."""
@inline function _eval_spec(spec, t::Float64, duration::Float64)
    spec === nothing && return 0.0
    spec isa Number && return Float64(spec)
    # Dict or existing Waveform — route through _make_waveform + evaluate.
    wf = spec isa Waveform ? spec : _make_waveform(spec, duration)
    evaluate(wf, t)
end

"""
    _convert_B_waveform(B_spec, duration, g_F, omega_ref) -> Waveform

Convert a Gauss-valued spec into a dimensionless Waveform by sampling N
points over [0, duration] and applying the Gauss→dimless factor. Accepts:

- `Number` (Gauss): returns ConstantWaveform.
- `AbstractString` ("0.819 G", "81.9 mT"): Unitful parsed, returns
  ConstantWaveform.
- `Dict` (ramp/sinusoidal/...): samples the waveform, applies factor,
  returns PiecewiseLinearWaveform.
- `Waveform`: samples it directly.

Never returns a closure — keeps everything concretely typed (see CLAUDE.md:
Type stability boundaries).
"""
function _convert_B_waveform(B_spec, duration::Float64, g_F::Float64, omega_ref::Float64;
                              n_samples::Int = _ZEEMAN_SAMPLE_N)
    factor = g_F * Units.BOHR_MAGNETON * _GAUSS_TO_TESLA / (Units.HBAR * omega_ref)
    if B_spec isa AbstractString
        # "0.819 G" → parse Quantity → to Tesla → dimensionless p
        q = Units.safe_parse_quantity(B_spec)
        return ConstantWaveform(Units.bfield_to_p(q, g_F, omega_ref))
    elseif B_spec isa Number
        return ConstantWaveform(factor * Float64(B_spec))
    end
    B_wf = B_spec isa Waveform ? B_spec : _make_waveform(B_spec, duration)
    times = collect(range(0.0, duration; length = n_samples))
    values = Float64[factor * evaluate(B_wf, t) for t in times]
    PiecewiseLinearWaveform(times, values)
end

"""Estimate appropriate sample count for a Bz/Bx/By spec. For sinusoidal and
chirped spec, return ≥ 20 samples per highest-frequency cycle. Returns the
default floor otherwise."""
function _suggest_sample_count(spec, duration::Float64)
    spec isa Dict || return _ZEEMAN_SAMPLE_N
    if haskey(spec, "sinusoidal")
        f = Float64(get(spec["sinusoidal"], "frequency", 1.0))
        f > 0 || return _ZEEMAN_SAMPLE_N
        return max(_ZEEMAN_SAMPLE_N, ceil(Int, 20 * f * duration))
    elseif haskey(spec, "chirped_sinusoidal")
        f_end = Float64(get(spec["chirped_sinusoidal"], "freq_end", 1.0))
        return max(_ZEEMAN_SAMPLE_N, ceil(Int, 20 * f_end * duration))
    end
    _ZEEMAN_SAMPLE_N
end

"""Level 1: Bx, By, Bz → TimeDependentZeeman (always, even for scalar)."""
function _build_zeeman_level1(z::Dict, duration::Float64, atom, omega_ref::Float64)
    Bx = get(z, "Bx", 0.0)
    By = get(z, "By", 0.0)
    Bz = get(z, "Bz", 0.0)
    g_F = atom.g_F
    # p: longitudinal (Bz). q: 2nd-order Zeeman is user-override only.
    # Pick sample counts: enough to resolve the fastest oscillation in each axis.
    n_override = Int(get(z, "n_samples", 0))
    n_bx = n_override > 0 ? n_override : _suggest_sample_count(Bx, duration)
    n_by = n_override > 0 ? n_override : _suggest_sample_count(By, duration)
    n_bz = n_override > 0 ? n_override : _suggest_sample_count(Bz, duration)
    p_wf = _convert_B_waveform(Bz, duration, g_F, omega_ref; n_samples = n_bz)
    q_wf = _make_waveform(get(z, "q", 0.0), duration)
    bx_wf = _convert_B_waveform(Bx, duration, g_F, omega_ref; n_samples = n_bx)
    by_wf = _convert_B_waveform(By, duration, g_F, omega_ref; n_samples = n_by)
    TimeDependentZeeman(p_wf, q_wf, bx_wf, by_wf)
end

"""Level 2: B_mag + theta_deg + phi_deg → project to Bx/By/Bz then Level 1."""
function _build_zeeman_level2(z::Dict, duration::Float64, atom, omega_ref::Float64)
    B_mag_spec = get(z, "B_mag", 1.0)
    theta_spec = get(z, "theta_deg", 0.0)
    phi_spec = get(z, "phi_deg", 0.0)
    g_F = atom.g_F
    factor = g_F * Units.BOHR_MAGNETON * _GAUSS_TO_TESLA / (Units.HBAR * omega_ref)

    # Sample all three at the same time grid, project, convert.
    # B_mag_spec may be a unit-carrying string ("0.819 G"); pre-resolve to Gauss.
    B_mag_gauss_spec = if B_mag_spec isa AbstractString
        q = Units.safe_parse_quantity(B_mag_spec)
        # convert to Gauss so the `factor` (Gauss→dimless) applies directly
        Float64(ustrip(u"Gauss", q))
    else
        B_mag_spec
    end

    times = collect(range(0.0, duration; length = _ZEEMAN_SAMPLE_N))
    Bmag_wf = B_mag_gauss_spec isa Number ? ConstantWaveform(Float64(B_mag_gauss_spec)) :
        (B_mag_gauss_spec isa Waveform ? B_mag_gauss_spec : _make_waveform(B_mag_gauss_spec, duration))
    theta_wf = theta_spec isa Number ? ConstantWaveform(Float64(theta_spec)) :
        (theta_spec isa Waveform ? theta_spec : _make_waveform(theta_spec, duration))
    phi_wf = phi_spec isa Number ? ConstantWaveform(Float64(phi_spec)) :
        (phi_spec isa Waveform ? phi_spec : _make_waveform(phi_spec, duration))

    bx_vals = Vector{Float64}(undef, _ZEEMAN_SAMPLE_N)
    by_vals = Vector{Float64}(undef, _ZEEMAN_SAMPLE_N)
    bz_vals = Vector{Float64}(undef, _ZEEMAN_SAMPLE_N)
    @inbounds for i in eachindex(times)
        t = times[i]
        B = evaluate(Bmag_wf, t)
        θ = deg2rad(evaluate(theta_wf, t))
        φ = deg2rad(evaluate(phi_wf, t))
        sinθ = sin(θ)
        bx_vals[i] = factor * B * sinθ * cos(φ)
        by_vals[i] = factor * B * sinθ * sin(φ)
        bz_vals[i] = factor * B * cos(θ)
    end
    p_wf = PiecewiseLinearWaveform(times, bz_vals)
    bx_wf = PiecewiseLinearWaveform(times, bx_vals)
    by_wf = PiecewiseLinearWaveform(times, by_vals)
    q_wf = _make_waveform(get(z, "q", 0.0), duration)
    TimeDependentZeeman(p_wf, q_wf, bx_wf, by_wf)
end

"""
    _build_zeeman_dispatched(z::Dict, duration, atom, p_step) -> Zeeman

Level-aware builder. Level 0 returns the existing `ZeemanParams` /
`TimeDependentZeeman` from `_parse_zeeman`; Level 1/2 converts from Gauss
using atom.g_F and a resolved omega_ref.
"""
function _build_zeeman_dispatched(z::Dict, duration::Float64, atom, p_step::Dict)
    level = _detect_zeeman_level(z)
    if level == 0
        return _parse_zeeman(z, duration)
    end
    omega_ref = _resolve_omega_ref(z, p_step)
    level == 1 ? _build_zeeman_level1(z, duration, atom, omega_ref) :
                 _build_zeeman_level2(z, duration, atom, omega_ref)
end
