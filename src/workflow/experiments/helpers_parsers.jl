# --- YAML parsing helpers ---

_zeeman_scalar(v) = v isa Dict ? Float64(v["from"]) : Float64(v)

_to_int_vec(v::Vector) = Int[Int(x) for x in v]
_to_int_vec(v) = Int[Int(v)]
_to_float_vec(v::Vector) = Float64[Float64(x) for x in v]
_to_float_vec(v) = Float64[Float64(v)]

"""Convert all keys in a dict to String."""
_to_string_keys(d::Dict) = Dict{String,Any}(string(k) => v for (k, v) in d)

"""Get an optional Float64 from a dict, returning nothing if key is absent."""
_get_optional_float(d::Dict, key::String) =
    let v = get(d, key, nothing); v === nothing ? nothing : Float64(v) end

"""Get an optional Int from a dict, returning nothing if key is absent."""
_get_optional_int(d::Dict, key::String) =
    let v = get(d, key, nothing); v === nothing ? nothing : Int(v) end

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
    for n = 2:max_n
        haskey(inter, "c$n") && (c_extra[n-1] = Float64(inter["c$n"]))
    end
    c_extra
end

function _parse_potential_config(d::Dict)
    t = Symbol(get(d, "type", "none"))
    params = Dict{String,Any}()
    for (k, v) in d
        k == "type" && continue
        params[k] = v
    end
    PotentialConfig(t, params)
end

function _parse_potential_config(v::Vector)
    components = [_parse_potential_config(d) for d in v]
    PotentialConfig(:composite, Dict{String,Any}("components" => components))
end

_parse_ramp_or_constant(v::Dict) = haskey(v, "to") ?
    LinearRamp(Float64(v["from"]), Float64(v["to"])) :
    ConstantValue(Float64(v["from"]))
_parse_ramp_or_constant(v) = ConstantValue(Float64(v))

# --- Scan parsing helpers ---

function _parse_override_scan(d::Dict)
    points = expand_scan_points(d)

    comparison_runs = if haskey(d, "comparison_runs")
        Tuple{String,Dict{String,Any}}[
            (String(r["name"]), parse_override_map(get(r, "override", Dict())))
            for r in d["comparison_runs"]
        ]
    else
        Tuple{String,Dict{String,Any}}[]
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

function _parse_gs_interactions(inter::Dict, atom)
    F = atom.F
    c_extra = Float64[]
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
        c0 = Float64(get(inter, "c0", 0.0))
        c1 = Float64(get(inter, "c1", 0.0))
        c_lhy = Float64(get(inter, "c_lhy", 0.0))
        InteractionParams(c0, c1, c_lhy, c_extra)
    end
end

function _parse_gs_ddi(ddi_d, inter, atom)
    if isempty(ddi_d) || ddi_d === nothing
        return (false, NaN, false, false, 0.0)
    end
    ddi_d = ddi_d isa Dict ? ddi_d : Dict{String,Any}("enabled" => ddi_d)
    enabled = Bool(get(ddi_d, "enabled", false))
    c_dd_raw = get(ddi_d, "c_dd", nothing)
    c_dd = if c_dd_raw isa Dict
        Float64(get(c_dd_raw, "from", 0.0))
    elseif c_dd_raw !== nothing
        Float64(c_dd_raw)
    elseif haskey(inter, "N_atoms") && haskey(inter, "omega_ref")
        compute_c_dd_dimless(atom; N_atoms = Int(inter["N_atoms"]), omega_ref = Float64(inter["omega_ref"]))
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

    p_interp = _make_interpolator(p_spec)
    q_interp = _make_interpolator(q_spec)

    TimeDependentZeeman(t -> begin
        t_frac = duration > 0 ? clamp(t / duration, 0.0, 1.0) : 0.0
        ZeemanParams(p_interp(t_frac), q_interp(t_frac))
    end)
end

"""Parse grid config from pipeline step params."""
function _setup_grid_from_params(p::Dict)
    g = p["grid"]
    n_raw = g isa Dict ? get(g, "n", get(g, "n_points", 32)) : g
    box_raw = g isa Dict ? get(g, "box", get(g, "box_size", 12.0)) : 12.0
    n_pts, box_size = _normalize_grid(n_raw, box_raw)
    ndim = length(n_pts)
    grid = make_grid(GridConfig(NTuple{ndim,Int}(n_pts), NTuple{ndim,Float64}(box_size)))
    (grid, ndim)
end
