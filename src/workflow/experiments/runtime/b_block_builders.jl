# --- Unified B-block builders ---
# User-facing reference: docs/reference/yaml_schema_reference.md (B block).
# Operational guide: docs/guides/klaus_regime.md "Spec B(t), not (p,q,bx,by)".
#
# Three coord-system inputs (auto-detected from keys):
#   :dimless    — p, q, bx, by                 (dimensionless, ℏω_ref units)
#   :cartesian  — Bx, By, Bz                   (Gauss; scalar or Waveform)
#   :spherical  — B_mag, theta_deg, phi_deg    (Gauss; scalar or Waveform)
#
# Internally everything reduces to a single dimensionless Cartesian
# (bx_wf, by_wf, bz_wf) triple via `_canonicalize_b_to_dimless_xyz`. The
# Gauss-valued paths apply `g_F · μ_B / (ℏ · ω_ref)`; the dimless path is
# pass-through. The TimeDependentZeeman is then built from that triple
# plus the orthogonal quadratic-Zeeman waveform `q_wf`.
#
# All time-dep specs are sampled to PiecewiseLinearWaveform after conversion
# to keep everything concretely-typed; see CLAUDE.md > Type stability boundaries.

const _GAUSS_TO_TESLA = 1.0e-4
const _ZEEMAN_SAMPLE_N = 1024  # default — override via `B.n_samples`.

"""
    _detect_b_coord(z::Dict) -> Symbol  (:dimless | :cartesian | :spherical)

The Zeeman Hamiltonian has two mathematically independent contributions:

    H_Zeeman = -p·F_z + q F_z²,  p ≡ -g_F μ_B B   (Kawaguchi-Ueda form)
             = +(g_F μ_B B · F) + q F_z²          (physical: μ = -g_F μ_B F)
               ↑ vector (chooses coord system)    ↑ scalar (orthogonal)

    The operator form is -p·F_z (every spinor-BEC paper). The lab field
    enters via p = -g_F μ_B B (the single signed conversion lives in
    `Units.bfield_to_p`), so +Bz on a g_F>0 atom gives ground state m=-F
    (spin down). Sign corrected 2026-06-10.

Auto-detect the vector-term coord system from keys:

  :dimless    — `p`, `bx`, `by`              (with `bz ≡ p`)
  :cartesian  — `Bx`, `By`, `Bz`
  :spherical  — `B_mag`, `theta_deg`, `phi_deg`

`q` (quadratic Zeeman) is a scalar coupling allowed alongside any coord
system — it does NOT participate in coord detection. Mixing keys across
coord systems raises `ArgumentError`. An empty B block defaults to
`:dimless`.
"""
function _detect_b_coord(z::Dict)
    has_dimless = any(haskey(z, k) for k in ("p", "bx", "by"))
    has_cartesian = any(haskey(z, k) for k in ("Bx", "By", "Bz"))
    has_spherical = any(haskey(z, k) for k in ("B_mag", "theta_deg", "phi_deg"))

    coord_systems = count(identity, (has_dimless, has_cartesian, has_spherical))
    coord_systems > 1 && throw(
        ArgumentError(
            "B: cannot mix coord systems — " *
            "dimensionless Cartesian (p/bx/by), " *
            "Gauss Cartesian (Bx/By/Bz), " *
            "Gauss spherical (B_mag/theta_deg/phi_deg). " *
            "Pick one. (`q` quadratic Zeeman is independent and can " *
            "be combined with any of these.)",
        ),
    )

    has_spherical && return :spherical
    has_cartesian && return :cartesian
    :dimless
end

"""
    _resolve_omega_ref(z::Dict, p_step::Dict) -> Float64

Resolve the reference angular frequency (rad/s) used for Gauss → dimensionless
conversion. Priority:
  1. `B.omega_ref_hz` (Hz, this-block override; multiplied by 2π)
  2. `interactions.omega_ref` (rad/s, canonical)
  3. step-level `omega_ref` (rad/s)

Raises `ArgumentError` if none is set — required for `:cartesian` / `:spherical`.
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
            "B (Gauss-valued coord system) requires omega_ref; set " *
            "`B.omega_ref_hz` (Hz) or `interactions.omega_ref` (rad/s).",
        ),
    )
end

"""
    _gauss_to_dimless(B_gauss, g_F, omega_ref) -> Float64

Gauss → dimensionless linear Zeeman `p`. Delegates to `Units.bfield_to_p`,
the single signed SSoT (`p = -g_F · μ_B · B[T] / (ℏ · ω_ref)`, K-U convention).
"""
@inline function _gauss_to_dimless(B_gauss::Float64, g_F::Float64, omega_ref::Float64)
    Units.bfield_to_p(B_gauss, g_F, omega_ref)
end

@inline function _gauss_to_dimless_factor(g_F::Float64, omega_ref::Float64)
    Units.bfield_to_p(1.0, g_F, omega_ref)   # per-Gauss factor (1 G)
end

"""
    _convert_B_waveform(B_spec, duration, g_F, omega_ref; n_samples) -> Waveform

Convert a Gauss-valued spec into a dimensionless Waveform. Accepts:

- `Number` (Gauss): returns `ConstantWaveform`.
- `AbstractString` ("0.819 Gauss", "81.9 mT"): Unitful-parsed, returns
  `ConstantWaveform`.
- `Dict` (ramp / sinusoidal / ...): samples the waveform, applies factor,
  returns `PiecewiseLinearWaveform`.
- `Waveform`: samples it directly.

Never returns a closure (CLAUDE.md type-stability discipline).
"""
function _convert_B_waveform(B_spec, duration::Float64, g_F::Float64, omega_ref::Float64;
    n_samples::Int=_ZEEMAN_SAMPLE_N)
    factor = _gauss_to_dimless_factor(g_F, omega_ref)
    if B_spec isa AbstractString
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

"""
    _suggest_sample_count(spec, duration; omega_ref) -> Int

For sinusoidal / chirped specs, return ≥ 20 samples per highest-frequency
cycle (Nyquist headroom). Returns the default floor otherwise.
"""
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

"""Wrap a Number / String / Waveform / Dict spec as a `Waveform`. Helper for
the `:spherical` branch of the canonicalizer where each axis must be a
uniformly-typed `Waveform`."""
@inline function _to_waveform_or_const(spec, duration::Float64; omega_ref::Float64)
    spec isa Number && return ConstantWaveform(Float64(spec))
    spec isa Waveform && return spec
    _make_waveform(spec, duration; omega_ref=omega_ref)
end

"""
    _canonicalize_b_to_dimless_xyz(z, coord, duration, atom, omega_ref)
        -> (bx_wf, by_wf, bz_wf)

Reduce any B-block coord system to a dimensionless Cartesian triple. The
returned waveforms are ready to feed into `TimeDependentZeeman(bz, q, bx, by)`.

- `:dimless`: pass-through of `p` / `bx` / `by` (no ω_ref needed; `factor=1`).
- `:cartesian`: per-axis Gauss → dimensionless via `_convert_B_waveform`.
- `:spherical`: sample `B_mag` / `θ` / `φ` on a common time grid, project to
  Cartesian, multiply by the Gauss factor.
"""
function _canonicalize_b_to_dimless_xyz(z::Dict, coord::Symbol, duration::Float64,
    atom, omega_ref::Float64)
    if coord === :dimless
        # bz ≡ p in this convention.
        bx_wf = _make_waveform(get(z, "bx", 0.0), duration; omega_ref=omega_ref)
        by_wf = _make_waveform(get(z, "by", 0.0), duration; omega_ref=omega_ref)
        bz_wf = _make_waveform(get(z, "p", 0.0), duration; omega_ref=omega_ref)
        return (bx_wf, by_wf, bz_wf)
    end

    g_F = atom.g_F
    n_override = Int(get(z, "n_samples", 0))

    if coord === :cartesian
        Bx = get(z, "Bx", 0.0)
        By = get(z, "By", 0.0)
        Bz = get(z, "Bz", 0.0)
        n_bx =
            n_override > 0 ? n_override : _suggest_sample_count(Bx, duration; omega_ref=omega_ref)
        n_by =
            n_override > 0 ? n_override : _suggest_sample_count(By, duration; omega_ref=omega_ref)
        n_bz =
            n_override > 0 ? n_override : _suggest_sample_count(Bz, duration; omega_ref=omega_ref)
        bx_wf = _convert_B_waveform(Bx, duration, g_F, omega_ref; n_samples=n_bx)
        by_wf = _convert_B_waveform(By, duration, g_F, omega_ref; n_samples=n_by)
        bz_wf = _convert_B_waveform(Bz, duration, g_F, omega_ref; n_samples=n_bz)
        return (bx_wf, by_wf, bz_wf)
    end

    # :spherical — sample B_mag / θ / φ then project.
    factor = _gauss_to_dimless_factor(g_F, omega_ref)
    n = n_override > 0 ? n_override : _ZEEMAN_SAMPLE_N
    times = collect(range(0.0, duration; length=n))

    Bmag_spec = get(z, "B_mag", 1.0)
    # `B_mag` may carry units; pre-resolve string → Gauss scalar so the
    # `factor` (Gauss → dimensionless) applies uniformly.
    Bmag_gauss = if Bmag_spec isa AbstractString
        q = Units.safe_parse_quantity(Bmag_spec)
        Float64(ustrip(u"Gauss", q))
    else
        Bmag_spec
    end
    Bmag_wf = _to_waveform_or_const(Bmag_gauss, duration; omega_ref=omega_ref)
    theta_wf = _to_waveform_or_const(get(z, "theta_deg", 0.0), duration; omega_ref=omega_ref)
    phi_wf = _to_waveform_or_const(get(z, "phi_deg", 0.0), duration; omega_ref=omega_ref)

    bx_vals = Vector{Float64}(undef, n)
    by_vals = Vector{Float64}(undef, n)
    bz_vals = Vector{Float64}(undef, n)
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
    (
        PiecewiseLinearWaveform(times, bx_vals),
        PiecewiseLinearWaveform(times, by_vals),
        PiecewiseLinearWaveform(times, bz_vals),
    )
end

"""
    _resolve_q_waveform(z, p_wf, atom, omega_ref, duration) -> Waveform

Resolve the quadratic Zeeman waveform `q_wf`. Priority:

1. User wrote `q: <value>` in the B block → that wins (override).
2. Atom has full hyperfine data (`Delta_E_hf > 0`, `g_J > 0`, `q_geometry > 0`)
   → auto-derive `q(t)` from `p(t)²` via Breit-Rabi (`compute_quadratic_zeeman`).
3. Atom is bosonic / no hyperfine (`Delta_E_hf = 0`) → `q = 0` (correct
   physics for I=0 isotopes; quadratic Zeeman `~ B² / ΔE_fs` negligible).
4. Atom has hyperfine but missing q-derivation data → `ArgumentError`.

The auto-derived q tracks the time-dependent p (B) — it's a function of
B², so a ramping B yields a quadratically-ramping q.
"""
function _resolve_q_waveform(z::Dict, p_wf, atom, omega_ref::Float64, duration::Float64)
    if haskey(z, "q")
        return _make_waveform(z["q"], duration; omega_ref=omega_ref)
    end
    atom.Delta_E_hf > 0 || return ConstantWaveform(0.0)
    (atom.g_J > 0 && atom.q_geometry > 0) || throw(
        ArgumentError(
            "atom $(atom.name): magnetic field set but quadratic-Zeeman " *
            "geometry data is incomplete (g_J=$(atom.g_J), " *
            "q_geometry=$(atom.q_geometry)). Set `q:` explicitly in the " *
            "B block, or fill in `g_J` and `q_geometry` for this atom " *
            "in src/workflow/initialization/atoms.jl."),
    )
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
    _build_zeeman_from_b_block(z::Dict, duration, atom, p_step) -> Zeeman

Build a `ZeemanParams` (static) or `TimeDependentZeeman` from a unified
B block. `:dimless` preserves the static-or-dynamic split via
`_parse_zeeman` (all-constant input → `ZeemanParams`; any waveform →
`TimeDependentZeeman`). `:cartesian` / `:spherical` always return
`TimeDependentZeeman` (Gauss conversion forces the waveform pipeline).
Multi-source blocks dispatch through `_build_zeeman_multi_source`.
"""
function _build_zeeman_from_b_block(z::Dict, duration::Float64, atom, p_step::Dict)
    haskey(z, "sources") && return _build_zeeman_multi_source(z, duration, atom, p_step)

    coord = _detect_b_coord(z)
    if coord === :dimless
        return _parse_zeeman(z, duration)
    end
    omega_ref = _resolve_omega_ref(z, p_step)
    (bx_wf, by_wf, bz_wf) = _canonicalize_b_to_dimless_xyz(z, coord, duration, atom, omega_ref)
    q_wf = _resolve_q_waveform(z, bz_wf, atom, omega_ref, duration)
    TimeDependentZeeman(bz_wf, q_wf, bx_wf, by_wf)
end

"""
Build a `TimeDependentZeeman` from a list of vector-source contributions
that sum additively. Each source is independently `:dimless` / `:cartesian`
/ `:spherical` (auto-detect). The global scalar `q` (quadratic Zeeman)
lives at the parent block, NOT per-source.
"""
function _build_zeeman_multi_source(z::Dict, duration::Float64, atom, p_step::Dict)
    sources = z["sources"]
    sources isa AbstractVector ||
        throw(ArgumentError("B.sources: must be a list, got $(typeof(sources))"))

    omega_ref = _resolve_omega_ref(z, p_step)

    sub_zeemans = TimeDependentZeeman[]
    for (i, src) in enumerate(sources)
        src isa AbstractDict || throw(ArgumentError(
            "B.sources[$i]: must be a mapping, got $(typeof(src))"))
        # Each source carries its own coord-system keys. q is forced to 0
        # in sub-builders; the parent's q is added once at the end.
        src_dict = Dict{Any, Any}(src)
        src_dict["q"] = 0.0
        coord = _detect_b_coord(src_dict)
        sub_z = if coord === :dimless
            zee = _parse_zeeman(src_dict, duration)
            zee isa TimeDependentZeeman ? zee : _zeeman_to_time_dependent(zee, duration)
        else
            (bx_wf, by_wf, bz_wf) = _canonicalize_b_to_dimless_xyz(
                src_dict, coord, duration, atom, omega_ref
            )
            TimeDependentZeeman(bz_wf, ConstantWaveform(0.0), bx_wf, by_wf)
        end
        push!(sub_zeemans, sub_z)
    end

    # Sum each axis on a common time grid.
    n = _ZEEMAN_SAMPLE_N
    times = collect(range(0.0, duration; length=n))
    total_bz = zeros(Float64, n)
    total_bx = zeros(Float64, n)
    total_by = zeros(Float64, n)
    for sub in sub_zeemans
        for (i, t) in enumerate(times)
            total_bz[i] += evaluate(sub.p_wf, t)
            total_bx[i] += sub.bx_wf === nothing ? 0.0 : evaluate(sub.bx_wf, t)
            total_by[i] += sub.by_wf === nothing ? 0.0 : evaluate(sub.by_wf, t)
        end
    end

    q_wf = _make_waveform(get(z, "q", 0.0), duration; omega_ref=omega_ref)
    p_wf = PiecewiseLinearWaveform(times, total_bz)
    bx_wf = all(x -> x == 0.0, total_bx) ? nothing : PiecewiseLinearWaveform(times, total_bx)
    by_wf = all(x -> x == 0.0, total_by) ? nothing : PiecewiseLinearWaveform(times, total_by)
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
