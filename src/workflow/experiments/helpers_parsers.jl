# --- YAML parsing helpers ---

_zeeman_scalar(v) = v isa Dict ? Float64(v["from"]) : Float64(v)

# --- Unitful-aware numeric parsing ---------------------------------------
#
# Policy: numeric YAML fields that represent a physical quantity accept EITHER:
#   - a raw Real (legacy convention, default unit implicit per field)
#   - a unit-carrying string ("0.819 G", "50 Hz", "20 μm") parsed via
#     Units.safe_parse_quantity
#
# Keeping both paths means existing YAMLs (25+ configs) continue to work
# unchanged while new YAMLs can use physical units for experimental clarity.

"""
    _parse_bfield(node, g_F, omega_ref) -> Float64 (dimensionless p-equivalent)

Accept Real (default Gauss) or string ("0.819 G", "81.9 mT"). Returns
g_F · μ_B · B / (ℏ · ω_ref) — ready for direct use as a dimensionless
Zeeman parameter.
"""
function _parse_bfield(node, g_F::Real, omega_ref::Real)
    if node isa AbstractString
        q = Units.safe_parse_quantity(node)
        return Units.bfield_to_p(q, g_F, omega_ref)
    elseif node isa Real
        # Real → already-dimensionless Zeeman OR raw Gauss number?
        # Convention: In Level 1/2 zeeman context (caller decides), Real = Gauss.
        # This function is only called from the Gauss-context parsers, so
        # always convert as Gauss for consistency.
        return Units.bfield_to_p(Float64(node), g_F, omega_ref)
    end
    throw(ArgumentError("B-field: expected Real (Gauss) or quantity string; got $(typeof(node))"))
end

"""
    _parse_angular_frequency(node) -> Float64 (rad/s)

Accept Real (rad/s, existing convention) or string ("50 Hz", "314 rad/s").
"""
function _parse_angular_frequency(node)
    if node isa AbstractString
        return Units.freq_to_angular(Units.safe_parse_quantity(node))
    elseif node isa Real
        return Float64(node)
    end
    throw(ArgumentError("frequency: expected Real (rad/s) or quantity string"))
end

"""
    _parse_dimless_time(node, omega_ref) -> Float64

Accept Real (already dimensionless t·ω_ref) or string ("1 ms", "50 μs").
"""
function _parse_dimless_time(node, omega_ref::Real)
    if node isa AbstractString
        return Units.time_to_dimless(Units.safe_parse_quantity(node), omega_ref)
    elseif node isa Real
        return Float64(node)
    end
    throw(ArgumentError("time: expected Real (dimensionless) or quantity string"))
end

"""
    _parse_dimless_freq(node, omega_ref) -> Float64

Accept Real (already-dimensionless ω/ω_ref) or string ("226 Hz", "1.42 kHz",
"314 rad/s"). Returns the dimensionless ratio used internally.

Eliminates the documented Klaus 2022 magnetostir footgun where
`phi_omega: 4.524` was sometimes computed as `f/f_ref` instead of
`(2π·f)/ω_ref` — the 2π factor.
"""
function _parse_dimless_freq(node, omega_ref::Real)
    omega_ref > 0 ||
        throw(ArgumentError("omega_ref must be positive, got $omega_ref"))
    if node isa AbstractString
        ω_si = Units.freq_to_angular(Units.safe_parse_quantity(node))
        return ω_si / omega_ref
    elseif node isa Real
        return Float64(node)
    end
    throw(ArgumentError(
        "frequency: expected Real (dimensionless) or quantity string"))
end

_to_int_vec(v::Vector) = Int[Int(x) for x in v]
_to_int_vec(v) = Int[Int(v)]
_to_float_vec(v::Vector) = Float64[Float64(x) for x in v]
_to_float_vec(v) = Float64[Float64(v)]

"""Convert all keys in a dict to String."""
_to_string_keys(d::Dict) = Dict{String, Any}(string(k) => v for (k, v) in d)

"""Get an optional Float64 from a dict, returning nothing if key is absent."""
_get_optional_float(d::Dict, key::String) =
    let v = get(d, key, nothing);
        v === nothing ? nothing : Float64(v)
    end

"""Get an optional Int from a dict, returning nothing if key is absent."""
_get_optional_int(d::Dict, key::String) =
    let v = get(d, key, nothing);
        v === nothing ? nothing : Int(v)
    end

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
    for n in 2:max_n
        haskey(inter, "c$n") && (c_extra[n - 1] = Float64(inter["c$n"]))
    end
    c_extra
end

function _parse_potential_config(d::Dict)
    t = Symbol(get(d, "type", "none"))
    params = Dict{String, Any}()
    for (k, v) in d
        k == "type" && continue
        params[k] = v
    end
    PotentialConfig(t, params)
end

function _parse_potential_config(v::Vector)
    components = [_parse_potential_config(d) for d in v]
    PotentialConfig(:composite, Dict{String, Any}("components" => components))
end

_parse_ramp_or_constant(v::Dict) =
    if haskey(v, "to")
        LinearRamp(Float64(v["from"]), Float64(v["to"]))
    else
        ConstantValue(Float64(v["from"]))
    end
_parse_ramp_or_constant(v) = ConstantValue(Float64(v))

"""
    _parse_loss_params(node; atom=nothing, N_atoms=nothing, omega_ref=nothing) -> Union{Nothing,LossParams}

Parse a YAML `loss:` block into `LossParams`. Supported forms:

    loss: false | 0 | null        # no loss
    loss: {gamma_dr: 0.02, L3: 0.001}
    loss: {gamma_dr: 0.02, K3_per_m: [0.01, 0.02, 0.05, ...]}  # dimless

SI-unit input (lab-friendly, requires atom + N_atoms + omega_ref to derive
the dimensionless conversion factor):

    loss:
      gamma_dr: 0.02
      K3_per_m_si: ["1.5e-30 m^6/s", "3.0e-30 m^6/s", ...]

For the SI form the dimensionless rate is K3_dimless = K3_SI · n0² / ω_ref
with n0 = N_atoms / a_ho³ and a_ho = √(ℏ / (m·ω_ref)).
"""
function _parse_loss_params(
    node;
    atom::Union{Nothing, AtomSpecies}=nothing,
    N_atoms::Union{Nothing, Real}=nothing,
    omega_ref::Union{Nothing, Real}=nothing,
)
    node === nothing && return nothing
    node isa Bool && (node || return nothing; return nothing)
    if node isa Real
        v = Float64(node)
        v == 0 && return nothing
        return LossParams(v)
    end
    node isa Dict || throw(ArgumentError("loss must be a mapping or scalar, got $(typeof(node))"))
    gamma_dr = Float64(get(node, "gamma_dr", 0.0))
    L3 = Float64(get(node, "L3", 0.0))
    L3_per_m = let v = get(node, "K3_per_m", get(node, "L3_per_m", nothing))
        v === nothing ? Float64[] : Float64.(v)
    end
    # SI-unit per-m K3 — convert to dimless using atom/N/ω_ref
    if haskey(node, "K3_per_m_si")
        atom === nothing && throw(
            ArgumentError(
                "K3_per_m_si requires atom information (passed via dynamics step parsing)"),
        )
        N_atoms === nothing && throw(ArgumentError(
            "K3_per_m_si requires interactions.N_atoms"))
        omega_ref === nothing && throw(ArgumentError(
            "K3_per_m_si requires interactions.omega_ref"))
        a_ho = sqrt(Units.HBAR / (atom.mass * Float64(omega_ref)))
        n0 = Float64(N_atoms) / a_ho^3
        # K_3 [m^6/s] · n^2 [1/m^6]^2 = [1/s]; divide by ω_ref to dimless
        factor = n0^2 / Float64(omega_ref)
        si_vals = node["K3_per_m_si"]
        L3_per_m = [Units.k3_si(Units.safe_parse_quantity(String(s))) * factor
                    for s in si_vals]
    end

    # True 3-body cubic loss (physically correct: dn/dt = -K_3 n² n_m)
    K3_cubic = Float64(get(node, "K3_cubic", 0.0))
    K3_per_m_cubic = let v = get(node, "K3_per_m_cubic", nothing)
        v === nothing ? Float64[] : Float64.(v)
    end
    # Energy-selective evaporation (Phase 4 #40)
    evap_energy_cutoff = Float64(get(node, "evap_energy_cutoff", 0.0))
    evap_rate = Float64(get(node, "evap_rate", 0.0))

    LossParams(; gamma_dr, L3, L3_per_m, K3_cubic, K3_per_m_cubic,
        evap_energy_cutoff, evap_rate)
end

# --- Scan parsing helpers ---

function _parse_override_scan(d::Dict)
    points = expand_scan_points(d)

    comparison_runs = if haskey(d, "comparison_runs")
        Tuple{String, Dict{String, Any}}[
            (String(r["name"]), parse_override_map(get(r, "override", Dict())))
            for r in d["comparison_runs"]
        ]
    else
        Tuple{String, Dict{String, Any}}[]
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

"""
Resolve derived parameters from N_atoms + omega_ref.

Auto-derives c_lhy (Lima-Pelster Q5) and logs all derived values.
Explicit values in the YAML override auto-derived ones.
"""
function _resolve_derived_params!(p::Dict, atom; verbose::Bool=true)
    inter = get(p, "interactions", Dict())
    inter isa Dict || return nothing
    N_raw = get(inter, "N_atoms", nothing)
    ω_raw = get(inter, "omega_ref", nothing)
    (N_raw === nothing || ω_raw === nothing) && return nothing

    N_atoms = Int(N_raw)
    omega_ref = Float64(ω_raw)
    a_ho = sqrt(Units.HBAR / (atom.mass * omega_ref))

    # c_total (always derived — basis for c0/c1)
    c_total = compute_c_total(atom; N_atoms, omega_ref)

    # c_dd: derive if not explicitly specified
    ddi_d = get(p, "ddi", nothing)
    if ddi_d === true
        p["ddi"] = Dict{String, Any}("enabled" => true)
        ddi_d = p["ddi"]
    end
    c_dd_val = NaN
    if ddi_d isa Dict
        if !haskey(ddi_d, "c_dd") || ddi_d["c_dd"] === nothing
            c_dd_val = compute_c_dd_dimless(atom; N_atoms, omega_ref)
            ddi_d["c_dd"] = c_dd_val
        else
            c_dd_raw = ddi_d["c_dd"]
            c_dd_val = c_dd_raw isa Dict ? Float64(get(c_dd_raw, "from", 0.0)) : Float64(c_dd_raw)
        end
    end

    # ε_dd
    eps_dd = atom.a_s > 0 ? compute_a_dd(atom) / atom.a_s : 0.0

    # c_lhy: derive if not explicitly specified and DDI is active
    if !haskey(inter, "c_lhy") && !isnan(c_dd_val) && c_dd_val > 0
        a_s_dl = atom.a_s / a_ho
        c_lhy_scalar = (128.0 / (3.0 * sqrt(π))) * sqrt(abs(a_s_dl)^3) * N_atoms
        inter["c_lhy"] = c_lhy_scalar * lima_pelster_Q5(eps_dd)
    end

    # l_z: derive from trap ratio if quasi_2d and not specified
    pot = get(p, "potential", nothing)
    if pot isa Dict && get(pot, "type", "") == "harmonic" && ddi_d isa Dict
        ω_vec = _to_float_vec(pot["omega"])
        if Bool(get(ddi_d, "quasi_2d", false)) && !haskey(ddi_d, "l_z") && length(ω_vec) >= 2
            ω_perp = sqrt(ω_vec[1] * ω_vec[2])
            ω_z = length(ω_vec) >= 3 ? ω_vec[3] : ω_vec[end]
            ddi_d["l_z"] = sqrt(ω_perp / ω_z)
        end
    end

    if verbose
        c_lhy_val = Float64(get(inter, "c_lhy", 0.0))
        l_z_val = ddi_d isa Dict ? Float64(get(ddi_d, "l_z", 0.0)) : 0.0
        println(
            "  Derived: c_total=$(round(c_total; digits=1))" *
            " c_dd=$(isnan(c_dd_val) ? "N/A" : string(round(c_dd_val; digits=1)))" *
            " c_lhy=$(round(c_lhy_val; digits=1))" *
            " ε_dd=$(round(eps_dd; digits=4))" *
            (l_z_val > 0 ? " l_z=$(round(l_z_val; digits=4))" : ""),
        )
    end
end

function _parse_gs_interactions(inter::Dict, atom)
    F = atom.F
    # Higher-rank tensor couplings c_k (k = 2, 3, …) declared via YAML keys
    # `c2: …`, `c4: …`, etc. Pre-Apr 2026 this was hardcoded `Float64[]`,
    # silently dropping any c_extra YAML inputs. Regression test:
    # test_interactions_constraint.jl "YAML c_total with c_extra".
    c_extra = _parse_c_extra(inter, F)
    if haskey(inter, "c_total")
        c_total = Float64(inter["c_total"])
        c1_ratio = Float64(get(inter, "c1_ratio", 0.0))
        c_lhy = Float64(get(inter, "c_lhy", 0.0))
        ip = interaction_params_from_constraint(; c_total, c1_ratio, F, c_extra)
        InteractionParams(ip.c0, ip.c1, c_lhy, ip.c_extra)
    elseif haskey(inter, "N_atoms") && haskey(inter, "omega_ref")
        N_atoms = Int(inter["N_atoms"])
        omega_ref = Float64(inter["omega_ref"])
        c_total = compute_c_total(atom; N_atoms, omega_ref)
        c1_ratio = Float64(get(inter, "c1_ratio", 0.0))
        c_lhy = Float64(get(inter, "c_lhy", 0.0))
        ip = interaction_params_from_constraint(; c_total, c1_ratio, F, c_extra)
        InteractionParams(ip.c0, ip.c1, c_lhy, ip.c_extra)
    else
        c0_raw = get(inter, "c0", 0.0)
        c1_raw = get(inter, "c1", 0.0)
        c0 = c0_raw isa Dict ? Float64(get(c0_raw, "from", 0.0)) : Float64(c0_raw)
        c1 = c1_raw isa Dict ? Float64(get(c1_raw, "from", 0.0)) : Float64(c1_raw)
        c_lhy = Float64(get(inter, "c_lhy", 0.0))
        InteractionParams(c0, c1, c_lhy, c_extra)
    end
end

function _parse_gs_ddi(ddi_d, inter, atom)
    if isempty(ddi_d) || ddi_d === nothing
        return (false, NaN, false, false, 0.0)
    end
    ddi_d = ddi_d isa Dict ? ddi_d : Dict{String, Any}("enabled" => ddi_d)
    enabled = Bool(get(ddi_d, "enabled", false))
    c_dd_raw = get(ddi_d, "c_dd", nothing)
    c_dd = if c_dd_raw isa Dict
        Float64(get(c_dd_raw, "from", 0.0))
    elseif c_dd_raw !== nothing
        Float64(c_dd_raw)
    elseif haskey(inter, "N_atoms") && haskey(inter, "omega_ref")
        compute_c_dd_dimless(atom; N_atoms=Int(inter["N_atoms"]), omega_ref=Float64(inter["omega_ref"]))
    else
        NaN
    end
    secular = Bool(get(ddi_d, "secular", false))
    q2d = Bool(get(ddi_d, "quasi_2d", false))
    lz = Float64(get(ddi_d, "l_z", 0.0))
    (enabled, c_dd, secular, q2d, lz)
end

"""Parse constant zeeman params from a dict {p: ..., q: ...}."""
function _parse_constant_zeeman(z)
    z isa Dict || return ZeemanParams(0.0, 0.0)
    ZeemanParams(_zeeman_scalar(get(z, "p", 0.0)), _zeeman_scalar(get(z, "q", 0.0)))
end

"""
Parse zeeman from pipeline params. Supports:
  - {p: 0.5, q: 0.0}                     -> constant ZeemanParams
  - {p: {from: 100, to: 0}}              -> linear ramp
  - {p: {from: 100, to: 0.1, scale: log}} -> log ramp
"""
function _parse_zeeman(z, duration::Float64)
    z isa Dict || return ZeemanParams(0.0, 0.0)
    p_spec = get(z, "p", 0.0)
    q_spec = get(z, "q", 0.0)

    p_is_ramp = p_spec isa Dict
    q_is_ramp = q_spec isa Dict

    if !p_is_ramp && !q_is_ramp
        return ZeemanParams(_zeeman_scalar(p_spec), _zeeman_scalar(q_spec))
    end

    TimeDependentZeeman(
        _make_waveform(p_spec, duration),
        _make_waveform(q_spec, duration),
    )
end

"""Parse grid config from pipeline step params.

Accepts `dtype: "float32"` or `dtype: "float64"` on the pipeline step to
request mixed-precision simulation. Default is `Float64`. The resolved
eltype also propagates through `make_workspace(; dtype=…)` so the entire
hot path runs in the requested precision.
"""
function _setup_grid_from_params(p::Dict)
    g = p["grid"]
    n_raw = g isa Dict ? get(g, "n", get(g, "n_points", 32)) : g
    box_raw = g isa Dict ? get(g, "box", get(g, "box_size", 12.0)) : 12.0
    n_pts, box_size = _normalize_grid(n_raw, box_raw)
    ndim = length(n_pts)
    T = _parse_dtype(get(p, "dtype", "float64"))
    grid = make_grid(
        GridConfig(NTuple{ndim, Int}(n_pts), NTuple{ndim, Float64}(box_size));
        dtype=T,
    )
    (grid, ndim)
end

"""Parse a YAML `dtype:` string/symbol into a concrete AbstractFloat type."""
function _parse_dtype(spec)
    s = spec isa Symbol ? String(spec) : String(spec)
    s_lower = lowercase(s)
    if s_lower in ("float32", "f32", "single")
        Float32
    elseif s_lower in ("float64", "f64", "double")
        Float64
    else
        throw(ArgumentError("Unknown dtype '$s' — use 'float32' or 'float64'."))
    end
end
