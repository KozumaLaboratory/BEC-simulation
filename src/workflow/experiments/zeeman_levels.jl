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

The Zeeman Hamiltonian has two mathematically independent contributions:

  H_Zeeman = -(g_F μ_B B · F) + q F_z²
             ↑ vector (chooses coord system)   ↑ scalar (orthogonal)

The "level" refers ONLY to the vector term's coordinate system:
  Level 0 — dimensionless Cartesian:  p, bx, by  (with bz≡p)
  Level 1 — Gauss-Cartesian:          Bx, By, Bz
  Level 2 — Gauss-spherical:          B_mag, theta_deg, phi_deg

`q` (quadratic Zeeman) is a scalar coupling that is allowed alongside
any vector-coord system. It does NOT participate in level detection.

Mixing keys across vector coord systems (e.g. `p:` and `B_mag:`) raises
ArgumentError. Writing both an explicit `level:` AND vector-coord keys
also raises (duplicate spec — pick one). The lone case where explicit
`level:` is meaningful is an empty zeeman block being pre-declared for
later override.
"""
function _detect_zeeman_level(z::Dict)
    # Vector-coord keys per level. q is NOT here — it's coord-orthogonal.
    has_l0 = any(haskey(z, k) for k in ("p", "bx", "by"))
    has_l1 = any(haskey(z, k) for k in ("Bx", "By", "Bz"))
    has_l2 = any(haskey(z, k) for k in ("B_mag", "theta_deg", "phi_deg"))
    explicit = get(z, "level", nothing)

    coord_systems = count(identity, (has_l0, has_l1, has_l2))
    coord_systems > 1 && throw(
        ArgumentError(
            "zeeman: cannot mix vector coord systems — " *
            "Level 0 dimensionless Cartesian (p/bx/by), " *
            "Level 1 Gauss Cartesian (Bx/By/Bz), " *
            "Level 2 Gauss spherical (B_mag/theta_deg/phi_deg). " *
            "Pick one. (`q` quadratic Zeeman is independent and can " *
            "be combined with any of these.)",
        ),
    )

    if explicit !== nothing
        lvl = Int(explicit)
        (lvl in (0, 1, 2)) || throw(ArgumentError("zeeman.level must be 0, 1, or 2; got $lvl"))
        # Reject duplicate specs: either explicit `level:` OR vector-coord
        # keys, not both. Auto-detect from keys is preferred.
        coord_systems > 0 && throw(
            ArgumentError(
                "zeeman: explicit `level: $lvl` conflicts with vector-coord " *
                "keys already present in the block. Drop the `level:` line — " *
                "the keys imply the level (Bx/By/Bz → 1, " *
                "B_mag/theta_deg/phi_deg → 2, p/bx/by → 0).",
            ),
        )
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
    throw(
        ArgumentError(
            "zeeman Level 1/2 requires omega_ref; set zeeman.omega_ref_hz (Hz) or interactions.omega_ref (rad/s)"
        ),
    )
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
    n_samples::Int=_ZEEMAN_SAMPLE_N)
    factor = g_F * Units.BOHR_MAGNETON * _GAUSS_TO_TESLA / (Units.HBAR * omega_ref)
    if B_spec isa AbstractString
        # "0.819 G" → parse Quantity → to Tesla → dimensionless p
        q = Units.safe_parse_quantity(B_spec)
        return ConstantWaveform(Units.bfield_to_p(q, g_F, omega_ref))
    elseif B_spec isa Number
        return ConstantWaveform(factor * Float64(B_spec))
    end
    B_wf = B_spec isa Waveform ? B_spec :
           _make_waveform(B_spec, duration; omega_ref=omega_ref)
    times = collect(range(0.0, duration; length=n_samples))
    values = Float64[factor * evaluate(B_wf, t) for t in times]
    PiecewiseLinearWaveform(times, values)
end

"""Estimate appropriate sample count for a Bz/Bx/By spec. For sinusoidal and
chirped spec, return ≥ 20 samples per highest-frequency cycle. Returns the
default floor otherwise."""
function _suggest_sample_count(spec, duration::Float64; omega_ref::Float64=NaN)
    spec isa Dict || return _ZEEMAN_SAMPLE_N
    _f(node) = isnan(omega_ref) ? Float64(node) :
               _parse_dimless_freq(node, 2π * omega_ref)
    if haskey(spec, "sinusoidal")
        f = _f(get(spec["sinusoidal"], "frequency", 1.0))
        f > 0 || return _ZEEMAN_SAMPLE_N
        return max(_ZEEMAN_SAMPLE_N, ceil(Int, 20 * f * duration))
    elseif haskey(spec, "chirped_sinusoidal")
        f_end = _f(get(spec["chirped_sinusoidal"], "freq_end", 1.0))
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
    n_override = Int(get(z, "n_samples", 0))
    n_bx = n_override > 0 ? n_override : _suggest_sample_count(Bx, duration; omega_ref=omega_ref)
    n_by = n_override > 0 ? n_override : _suggest_sample_count(By, duration; omega_ref=omega_ref)
    n_bz = n_override > 0 ? n_override : _suggest_sample_count(Bz, duration; omega_ref=omega_ref)
    p_wf = _convert_B_waveform(Bz, duration, g_F, omega_ref; n_samples=n_bz)
    q_wf = _resolve_q_waveform(z, p_wf, atom, omega_ref, duration)
    bx_wf = _convert_B_waveform(Bx, duration, g_F, omega_ref; n_samples=n_bx)
    by_wf = _convert_B_waveform(By, duration, g_F, omega_ref; n_samples=n_by)
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

    times = collect(range(0.0, duration; length=_ZEEMAN_SAMPLE_N))
    Bmag_wf = if B_mag_gauss_spec isa Number
        ConstantWaveform(Float64(B_mag_gauss_spec))
    else
        (
            if B_mag_gauss_spec isa Waveform
                B_mag_gauss_spec
            else
                _make_waveform(B_mag_gauss_spec, duration; omega_ref=omega_ref)
            end
        )
    end
    theta_wf = if theta_spec isa Number
        ConstantWaveform(Float64(theta_spec))
    else
        (theta_spec isa Waveform ? theta_spec : _make_waveform(theta_spec, duration; omega_ref=omega_ref))
    end
    phi_wf = if phi_spec isa Number
        ConstantWaveform(Float64(phi_spec))
    else
        (phi_spec isa Waveform ? phi_spec : _make_waveform(phi_spec, duration; omega_ref=omega_ref))
    end

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
    q_wf = _resolve_q_waveform(z, p_wf, atom, omega_ref, duration)
    TimeDependentZeeman(p_wf, q_wf, bx_wf, by_wf)
end

"""
    _resolve_q_waveform(z, p_wf, atom, omega_ref, duration) -> Waveform

Resolve the quadratic Zeeman waveform `q_wf`. Priority:

1. User wrote `q: <value>` in the zeeman block → that wins (override).
2. Atom has full hyperfine data (Delta_E_hf > 0, g_J > 0, q_geometry > 0)
   → auto-derive q from p via Breit-Rabi (`compute_quadratic_zeeman`).
3. Atom is bosonic / no hyperfine (Delta_E_hf = 0) → q = 0 (correct
   physics for I=0 isotopes; quadratic Zeeman ~ B²/ΔE_fs is negligible).
4. Atom has hyperfine but missing q-derivation data → ArgumentError.
   User must either explicitly set `q:` or fill in the atom's
   `q_geometry`/`g_J` constants.

The auto-derived q tracks the time-dependent p (B) — it's a function of
B², so a B that ramps yields a quadratically-ramping q.
"""
function _resolve_q_waveform(z::Dict, p_wf, atom, omega_ref::Float64, duration::Float64)
    if haskey(z, "q")
        return _make_waveform(z["q"], duration; omega_ref=omega_ref)
    end
    # Auto-derive: bosonic / no hyperfine → q = 0 silently.
    atom.Delta_E_hf > 0 || return ConstantWaveform(0.0)
    # Hyperfine present but q-geometry missing → error (incomplete atom data).
    (atom.g_J > 0 && atom.q_geometry > 0) || throw(ArgumentError(
        "atom $(atom.name): magnetic field set but quadratic-Zeeman " *
        "geometry data is incomplete (g_J=$(atom.g_J), " *
        "q_geometry=$(atom.q_geometry)). Set `q:` explicitly in the " *
        "zeeman block, or fill in `g_J` and `q_geometry` for this atom " *
        "in src/workflow/initialization/atoms.jl."))
    # Hyperfine + geometry present → derive q(t) from p(t)².
    n = _ZEEMAN_SAMPLE_N
    times = collect(range(0.0, duration; length=n))
    q_vals = Vector{Float64}(undef, n)
    @inbounds for (i, t) in enumerate(times)
        p_t = evaluate(p_wf, t)
        q_vals[i] = compute_quadratic_zeeman(atom; p_dimless=p_t, omega_ref=omega_ref)
    end
    PiecewiseLinearWaveform(times, q_vals)
end

"""
    _build_zeeman_dispatched(z::Dict, duration, atom, p_step) -> Zeeman

Level-aware builder. Level 0 returns the existing `ZeemanParams` /
`TimeDependentZeeman` from `_parse_zeeman`; Level 1/2 converts from Gauss
using atom.g_F and a resolved omega_ref.
"""
function _build_zeeman_dispatched(z::Dict, duration::Float64, atom, p_step::Dict)
    # Multi-source: `sources: [...]` lists multiple B-vector contributions,
    # each independently in L0/L1/L2. Sum at sample-grid level. `q` is
    # global (coord-orthogonal scalar) and lives at the top of the zeeman
    # block, NOT inside individual sources.
    if haskey(z, "sources")
        return _build_zeeman_multi_source(z, duration, atom, p_step)
    end

    level = _detect_zeeman_level(z)
    if level == 0
        return _parse_zeeman(z, duration)
    end
    omega_ref = _resolve_omega_ref(z, p_step)
    if level == 1
        _build_zeeman_level1(z, duration, atom, omega_ref)
    else
        _build_zeeman_level2(z, duration, atom, omega_ref)
    end
end

"""
Build a TimeDependentZeeman from a list of vector-source contributions
that sum additively. Each source is independently L0/L1/L2 (auto-detect).
The global scalar `q` (quadratic Zeeman) lives at the parent level, NOT
per-source.
"""
function _build_zeeman_multi_source(z::Dict, duration::Float64, atom, p_step::Dict)
    sources = z["sources"]
    sources isa AbstractVector ||
        throw(ArgumentError("zeeman.sources: must be a list, got $(typeof(sources))"))

    omega_ref = _resolve_omega_ref(z, p_step)

    # Build each source as a standalone TimeDependentZeeman (any level).
    # We fork the source dict to avoid leaking `q:` (which we'll add once
    # at the end) into each sub-builder.
    sub_zeemans = TimeDependentZeeman[]
    for (i, src) in enumerate(sources)
        src isa AbstractDict || throw(ArgumentError(
            "zeeman.sources[$i]: must be a mapping, got $(typeof(src))"))
        # Each source carries its own coord-system keys. q is forced to 0
        # in sub-builders; the parent's q is added separately below.
        src_dict = Dict{Any, Any}(src)
        src_dict["q"] = 0.0
        sub_z = if haskey(src_dict, "Bx") || haskey(src_dict, "By") || haskey(src_dict, "Bz")
            _build_zeeman_level1(src_dict, duration, atom, omega_ref)
        elseif haskey(src_dict, "B_mag") || haskey(src_dict, "theta_deg") ||
               haskey(src_dict, "phi_deg")
            _build_zeeman_level2(src_dict, duration, atom, omega_ref)
        else
            # Treat as Level 0 vector source (p/bx/by). Wrap via _parse_zeeman.
            zee = _parse_zeeman(src_dict, duration)
            zee isa TimeDependentZeeman ? zee : _zeeman_to_time_dependent(zee, duration)
        end
        push!(sub_zeemans, sub_z)
    end

    # Sum each axis on a common time grid.
    n = _ZEEMAN_SAMPLE_N
    times = collect(range(0.0, duration; length=n))
    total_p = zeros(Float64, n)
    total_bx = zeros(Float64, n)
    total_by = zeros(Float64, n)
    for sub in sub_zeemans
        for (i, t) in enumerate(times)
            total_p[i]  += evaluate(sub.p_wf,  t)
            total_bx[i] += sub.bx_wf === nothing ? 0.0 : evaluate(sub.bx_wf, t)
            total_by[i] += sub.by_wf === nothing ? 0.0 : evaluate(sub.by_wf, t)
        end
    end

    # Global q from the parent block.
    q_wf = _make_waveform(get(z, "q", 0.0), duration; omega_ref=omega_ref)

    p_wf = PiecewiseLinearWaveform(times, total_p)
    bx_wf = all(x -> x == 0.0, total_bx) ?
            nothing : PiecewiseLinearWaveform(times, total_bx)
    by_wf = all(x -> x == 0.0, total_by) ?
            nothing : PiecewiseLinearWaveform(times, total_by)
    TimeDependentZeeman(p_wf, q_wf, bx_wf, by_wf)
end

"""Wrap a static `ZeemanParams` into a `TimeDependentZeeman` for uniform
handling in multi-source summation."""
function _zeeman_to_time_dependent(z::ZeemanParams, duration::Float64)
    times = [0.0, duration]
    p_wf = PiecewiseLinearWaveform(times, [z.p, z.p])
    q_wf = PiecewiseLinearWaveform(times, [z.q, z.q])
    TimeDependentZeeman(p_wf, q_wf, nothing, nothing)
end
