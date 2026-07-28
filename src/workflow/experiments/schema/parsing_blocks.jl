# --- Per-block YAML parsers: interactions / DDI / Zeeman / loss / potential / scan ---
#
# All `_parse_*` helpers that consume one block of a pipeline step's
# YAML and emit a typed config record. Pulled out of helpers_parsers.jl
# 2026-05-01.

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
Parse higher-rank c_n keys (c2, c4, c6, ...) from a YAML interactions dict
into a `Dict{Int, Float64}`. Only **even** ranks n ≥ 2 are physical for
tensor-rank pair-channel couplings; odd-indexed entries (e.g. c3, c5) are
rejected with an ArgumentError pointing to the correct API. Sparse keys
(e.g. c4 present without c2) are supported — missing even ranks default
to zero.

Why odd-rank is rejected (not silently dropped):
- KU "c₃" (e.g. F=3 cyclic) is the **S=2 pair-channel coupling**, NOT a
  rank-3 single-particle tensor. The c_n slot here is for rank-k tensor
  couplings (even k only), so an entry named c₃ is meaningless here.
- For S-channel pair couplings, use `scattering_lengths` (in `AtomSpecies`)
  or `_make_tensor_cache_from_channels(F, Dict(S => g_S, ...))` directly.
"""
function _parse_higher_rank_c_n(inter::Dict, ::Int)
    odd_indices = Int[]
    out = Dict{Int, Float64}()
    for k in keys(inter)
        m = match(r"^c(\d+)$", string(k))
        m === nothing && continue
        n = parse(Int, m.captures[1])
        n >= 2 || continue
        if isodd(n)
            push!(odd_indices, n)
        else
            out[n] = Float64(inter["c$n"])
        end
    end
    if !isempty(odd_indices)
        throw(
            ArgumentError(
                "Odd-rank c_n entries (got c$(join(sort(odd_indices), ", c"))) " *
                "are not physical here. This slot is for rank-k single-particle " *
                "tensor couplings — even k only. For pair-channel S-couplings " *
                "(e.g. KU's c_3 = S=2 pair channel), use `scattering_lengths` on " *
                "the AtomSpecies or `_make_tensor_cache_from_channels(F, " *
                "Dict(S => g_S, ...))` directly. " *
                "See src/hamiltonian/terms/contact/singlet_pair.jl docstring."),
        )
    end
    out
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
    loss: {gamma_dr: 0.02, K3_per_m_cubic: [0.01, 0.02, ...]}  # dimensionless rates
    loss: {gamma_dr: 0.02, K3_per_m: [0.01, 0.02, 0.05, ...]}  # alias, dimensionless

SI-unit input (lab-friendly, requires atom + N_atoms + omega_ref to derive
the dimensionless conversion factor):

    loss:
      gamma_dr: 0.02
      K3_per_m_si: ["1.5e-30 m^6/s", "3.0e-30 m^6/s", ...]

For the SI form the dimensionless rate is K3_dimless = K3_SI · n0² / ω_ref
with n0 = N_atoms / a_ho³ and a_ho = √(ℏ / (m·ω_ref)).

Routing:
- `L3` / `L3_per_m`        → 2-body-shape `LossParams.L3` / `L3_per_m`
                              (dn_m/dt = -γ n n_m, linear in n)
- `K3_cubic` / `K3_per_m_cubic` / `K3_per_m` / `K3_per_m_si`
                            → physically correct 3-body `K3_per_m_cubic`
                              (dn_m/dt = -K_3 n² n_m, quadratic in n)
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
    # `L3_per_m` is the 2-body-shaped per-m rate (dn_m/dt = -γ n n_m).
    # Only the `L3_per_m` key routes here — `K3_per_m` and `K3_per_m_si`
    # are physically 3-body and must land in `K3_per_m_cubic` below.
    L3_per_m = let v = get(node, "L3_per_m", nothing)
        v === nothing ? Float64[] : Float64.(v)
    end

    # True 3-body cubic loss: dn_m/dt = -K_3 n² n_m. Three input forms:
    #   K3_cubic         — scalar dimensionless
    #   K3_per_m_cubic   — per-m dimensionless vector (canonical)
    #   K3_per_m_si      — per-m SI-units (m^6/s), converted via n0²/ω_ref
    # (The `K3_per_m` alias was removed 2026-05-24; canonical-only.)
    haskey(node, "K3_per_m") && throw(
        ArgumentError(
            "loss.K3_per_m: alias removed 2026-05-24 — use canonical " *
            "`K3_per_m_cubic` (dimensionless) or `K3_per_m_si` (SI \"X m^6/s\")."),
    )
    K3_cubic = Float64(get(node, "K3_cubic", 0.0))
    K3_per_m_cubic = let v = get(node, "K3_per_m_cubic", nothing)
        if v === nothing
            Float64[]
        elseif any(x -> x isa AbstractString, v)
            throw(
                ArgumentError(
                    "K3_per_m_cubic expects dimensionless numbers, " *
                    "but got string entries (e.g. \"1e-41 m^6/s\"). For SI-unit " *
                    "input use `K3_per_m_si: [\"... m^6/s\", ...]` instead — " *
                    "the parser converts via n0²/ω_ref using atom + N_atoms + " *
                    "omega_ref. See docs/reference/dynamics.md."),
            )
        else
            Float64.(v)
        end
    end
    if haskey(node, "K3_per_m_si")
        atom === nothing && throw(
            ArgumentError(
                "K3_per_m_si requires atom information. Set `atom: <Species>` on a " *
                "ground_state step in the same pipeline."),
        )
        (N_atoms === nothing || omega_ref === nothing) && throw(
            ArgumentError(
                "K3_per_m_si requires interactions.N_atoms AND interactions.omega_ref " *
                "for the n0²/ω_ref SI→dimless conversion. The idiomatic fix is the " *
                "top-level `defaults:` block:\n\n" *
                "  defaults:\n" *
                "    interactions: {N_atoms: <N>, omega_ref: <Hz·2π>}\n\n" *
                "so every step (including this dynamics phase) inherits the values. " *
                "Currently missing: " *
                (N_atoms === nothing ? "N_atoms" : "") *
                (N_atoms === nothing && omega_ref === nothing ? " AND " : "") *
                (omega_ref === nothing ? "omega_ref" : "") *
                ". See docs/reference/dynamics.md `Three-body loss K3_per_m_si` for " *
                "a worked example."),
        )
        a_ho = sqrt(Units.HBAR / (atom.mass * Float64(omega_ref)))
        n0 = Float64(N_atoms) / a_ho^3
        # K_3 [m^6/s] · n0² [m^-6] / ω_ref [1/s] → dimless rate for
        # quadratic application: exp(-K3_dimless · ñ² · dt̃ / 2)
        factor = n0^2 / Float64(omega_ref)
        si_vals = node["K3_per_m_si"]
        K3_per_m_cubic = [
            Units.k3_si(Units.safe_parse_quantity(String(s))) * factor
            for s in si_vals
        ]
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

    # c_dd: derive if not explicitly specified. `apply_schema_defaults!` has
    # already injected `ddi: {}` for ground_state steps (the only context
    # this helper sees), so `ddi_d isa Dict` is the common path; we still
    # tolerate `ddi: true` (alias for empty dict) and `ddi: false` (opt-out).
    ddi_d = get(p, "ddi", nothing)
    if ddi_d === true
        p["ddi"] = Dict{String, Any}()
        ddi_d = p["ddi"]
    end
    c_dd_val = NaN
    if ddi_d isa Dict && get(ddi_d, "enabled", true) !== false
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

    # LHY config — preferred path is the `lhy:` block (added in C5). Legacy
    # The resolver normalises the user-facing `lhy:` block into the internal fields
    # so downstream make_workspace / run_step plumbing is unchanged.
    _resolve_lhy_block!(p, inter, atom, c_dd_val, eps_dd, N_atoms, a_ho)

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

# LHY block resolver — `ground_state.lhy: {kind, c_lhy, n_max, n_points}` is
# the sole user-facing entry point for LHY configuration as of C6. When kind ∈
# {scalar, quasi_2d}, `c_lhy` is auto-derived via Lima-Pelster Q5(ε_dd) if the
# user omits it. The resolver writes the normalised fields into the internal
# slots (`p["lhy_kind"]`, `inter["c_lhy"]`) that downstream make_workspace /
# run_step continues to read — these slots are no longer user-visible because
# the schema rejects them.
function _resolve_lhy_block!(p::Dict, inter::Dict, atom, c_dd_val::Float64,
    eps_dd::Float64, N_atoms::Int, a_ho::Float64)
    lhy_block = get(p, "lhy", nothing)
    lhy_block isa Dict || return nothing

    kind = String(get(lhy_block, "kind", "none"))
    # Auto-derive c_lhy for scalar / quasi_2d when user omitted it.
    if (kind == "scalar" || kind == "quasi_2d") && !haskey(lhy_block, "c_lhy")
        if !isnan(c_dd_val) && c_dd_val > 0
            # Dimensionless scalar LHY coefficient for the repo's per-particle
            # convention (∫|ψ|²dV = 1, E_LHY/N = (2/5)·c_lhy·∫n^{5/2}dV,
            # c₀ = 4π(a_s/a_ho)N). Fixed by SI alone — no convention freedom:
            #
            #   γ_QF = (32/3)·g·√(a_s³/π),  g = 4πℏ²a_s/m
            #        = (128√π/3)(ℏ²/m)·a_s^{5/2}
            #   ⇒ c_lhy = (128√π/3)·(a_s/a_ho)^{5/2}·N^{3/2}·Q₅(ε_dd)
            #
            # equivalently c_lhy/c₀ = (32/3)√((a_s/a_ho)³N/π), which reproduces
            # the textbook ratio μ_LHY/μ_contact = (32/3)√(n_SI·a_s³/π).
            # test/oracles/test_scalar_lhy_si_roundtrip.jl gates exactly that.
            lhy_block["c_lhy"] = scalar_lhy_coefficient(atom.a_s / a_ho, N_atoms; eps_dd)
        end
    end
    # Normalise to internal fields for downstream consumers.
    if kind != "none"
        p["lhy_kind"] = kind
    end
    if haskey(lhy_block, "c_lhy")
        inter["c_lhy"] = lhy_block["c_lhy"]
    end
    # Table-resolution knobs. `n_max` / `n_points` were in LHY_SCHEMA from the
    # start but normalised nowhere, so `_build_spinor_lhy` never saw them and a
    # user's `n_points: 4000` silently stayed 200. They ride in one internal
    # slot as an `LHYTableOpts`, which is what `make_workspace` takes.
    p["lhy_opts"] = LHYTableOpts(;
        n_max=haskey(lhy_block, "n_max") ? Float64(lhy_block["n_max"]) : NaN,
        n_points=Int(get(lhy_block, "n_points", 200)),
        n_bins=Int(get(lhy_block, "n_bins", 12)))
    return nothing
end

function _parse_gs_interactions(inter::Dict, atom)
    F = atom.F
    # Higher-rank tensor couplings c_k (k = 2, 4, …) declared via YAML keys
    # `c2: …`, `c4: …`, etc.
    c_extra = _parse_higher_rank_c_n(inter, F)
    if haskey(inter, "c_total")
        c_total = Float64(inter["c_total"])
        c1_ratio = Float64(get(inter, "c1_ratio", 0.0))
        c_lhy = Float64(get(inter, "c_lhy", 0.0))
        ip = interaction_params_from_constraint(; c_total, c1_ratio, F, c_extra)
        InteractionParams(ip.c; c_lhy=c_lhy)
    elseif haskey(inter, "N_atoms") && haskey(inter, "omega_ref")
        N_atoms = Int(inter["N_atoms"])
        omega_ref = Float64(inter["omega_ref"])
        c_total = compute_c_total(atom; N_atoms, omega_ref)
        c1_ratio = Float64(get(inter, "c1_ratio", 0.0))
        c_lhy = Float64(get(inter, "c_lhy", 0.0))
        ip = interaction_params_from_constraint(; c_total, c1_ratio, F, c_extra)
        InteractionParams(ip.c; c_lhy=c_lhy)
    else
        c0_raw = get(inter, "c0", 0.0)
        c1_raw = get(inter, "c1", 0.0)
        c0 = c0_raw isa Dict ? Float64(get(c0_raw, "from", 0.0)) : Float64(c0_raw)
        c1 = c1_raw isa Dict ? Float64(get(c1_raw, "from", 0.0)) : Float64(c1_raw)
        c_lhy = Float64(get(inter, "c_lhy", 0.0))
        merged = merge(Dict(0 => c0, 1 => c1), c_extra)
        InteractionParams(merged; c_lhy=c_lhy)
    end
end

"""
    _parse_gs_ddi(ddi_d, inter, atom)
        -> (enabled, c_dd, secular, quasi_2d, l_z, trunc_radius, padded, pad_factor)

Parse the `ddi:` block of a step. Assumes `apply_schema_defaults!` has
already run, so for a ground_state step `ddi_d` is at least `Dict{}`;
dynamics steps either inherit DDI from `ws_prev` (handled in the caller)
or pass an explicit user value here. Opt-outs: `ddi: false` or
`ddi: {enabled: false}` ⇒ disabled. Without N_atoms+ω_ref c_dd can't
be derived, so DDI ends up off too.

`trunc_radius` (Ronen spherical-cutoff radius) is a `Float64` sentinel for
`make_workspace`: `NaN` = off (default), `≤ 0` = auto, `> 0` = explicit R.
`padded` (Bool) enables the zero-padded, image-free convolution (Tier B);
`pad_factor` (a number or per-axis vector) sets the zero-pad multiple
(default `2`; smaller on thin axes for anisotropic padding).
"""
function _parse_gs_ddi(ddi_d, inter, atom)
    if ddi_d === false || (ddi_d isa Dict && get(ddi_d, "enabled", true) === false)
        return (false, NaN, false, false, 0.0, NaN, false, 2.0)
    end
    ddi_d isa Dict || (ddi_d = Dict{String, Any}())

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

    enabled = !isnan(c_dd) && c_dd != 0.0
    secular = Bool(get(ddi_d, "secular", false))
    q2d = Bool(get(ddi_d, "quasi_2d", false))
    lz = Float64(get(ddi_d, "l_z", 0.0))
    trunc = _parse_ddi_trunc_radius(get(ddi_d, "trunc_radius", nothing))
    padded = Bool(get(ddi_d, "padded", false))
    pad_factor = _parse_ddi_pad_factor(get(ddi_d, "pad_factor", nothing))
    (enabled, c_dd, secular, q2d, lz, trunc, padded, pad_factor)
end

"""
    _parse_ddi_trunc_radius(raw) -> Float64

Map a YAML `ddi.trunc_radius` value to the `make_workspace` sentinel:
`nothing` ⇒ `NaN` (off); `"auto"`/`"box_half"` ⇒ `-1.0` (auto); a number ⇒
that value.
"""
function _parse_ddi_trunc_radius(raw)
    raw === nothing && return NaN
    if raw isa AbstractString
        s = lowercase(strip(raw))
        (s == "auto" || s == "box_half") && return -1.0
        throw(ArgumentError("ddi.trunc_radius string must be \"auto\"/\"box_half\", got \"$raw\""))
    end
    Float64(raw)
end

"""
    _parse_ddi_pad_factor(raw) -> Float64 or Vector{Float64}

Map a YAML `ddi.pad_factor` value to `make_workspace`'s `ddi_pad_factor`:
`nothing` ⇒ `2.0` (default); a number ⇒ scalar factor; a vector ⇒ per-axis
factors (anisotropic padding).
"""
function _parse_ddi_pad_factor(raw)
    raw === nothing && return 2.0
    # Return an NTuple (not a Vector) so it satisfies the `Union{Real, NTuple}`
    # kwarg type on make_workspace / the solver entry points.
    raw isa AbstractVector && return Tuple(Float64.(raw))
    Float64(raw)
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
    bx_spec = get(z, "bx", nothing)
    by_spec = get(z, "by", nothing)

    p_is_ramp = p_spec isa Dict
    q_is_ramp = q_spec isa Dict
    has_transverse = bx_spec !== nothing || by_spec !== nothing

    # Fast path: static + no transverse field → return the static struct.
    if !p_is_ramp && !q_is_ramp && !has_transverse
        return ZeemanParams(_zeeman_scalar(p_spec), _zeeman_scalar(q_spec))
    end

    # Time-dependent or transverse → TimeDependentZeeman with all 4
    # waveforms (p, q, bx, by). bx/by were previously dropped on the
    # floor here, which silently broke `:dimless` ground_state YAML
    # using transverse fields and the multi-source aggregator
    # (`b_block_builders.jl:_build_zeeman_multi_source` treats each
    # per-source dict as a sub-block with p/bx/by).
    TimeDependentZeeman(
        _make_waveform(p_spec, duration),
        _make_waveform(q_spec, duration),
        bx_spec !== nothing ? _make_waveform(bx_spec, duration) : nothing,
        by_spec !== nothing ? _make_waveform(by_spec, duration) : nothing,
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
