# --- Experiment Configuration Types ---

struct ConstantValue
    value::Float64
end

struct LinearRamp
    from::Float64
    to::Float64
end

const RampOrConstant = Union{ConstantValue,LinearRamp}

interpolate_value(v::ConstantValue, ::Float64) = v.value
interpolate_value(v::LinearRamp, t_frac::Float64) =
    v.from + (v.to - v.from) * clamp(t_frac, 0.0, 1.0)

struct PotentialConfig
    type::Symbol
    params::Dict{String,Any}
end


function scale_interactions_quasi_2d(ip::InteractionParams, l_z::Float64)
    factor = 1.0 / (sqrt(2π) * l_z)
    if ip.c_lhy != 0.0
        @warn "c_lhy scaling under quasi-2D is approximate; 2D LHY requires logarithmic treatment"
    end
    InteractionParams(
        ip.c0 * factor,
        ip.c1 * factor,
        ip.c_lhy * factor,
        isempty(ip.c_extra) ? Float64[] : ip.c_extra .* factor,
    )
end


_zeeman_scalar(v) = v isa Dict ? Float64(v["from"]) : Float64(v)


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

_to_int_vec(v::Vector) = Int[Int(x) for x in v]
_to_int_vec(v) = Int[Int(v)]
_to_float_vec(v::Vector) = Float64[Float64(x) for x in v]
_to_float_vec(v) = Float64[Float64(v)]

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

# --- Scan Parsing Helpers ---

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

function _build_potential(pc::PotentialConfig, ndim::Int)
    if pc.type == :none
        NoPotential()
    elseif pc.type == :harmonic
        omega_raw = get(pc.params, "omega", nothing)
        omega_raw === nothing && throw(ArgumentError("Harmonic potential requires omega"))
        omega = _to_float_vec(omega_raw)
        length(omega) == ndim ||
            throw(ArgumentError("omega length must match grid dimensions ($ndim)"))
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

"""
    _build_phase_zeeman(phase_raw, t_offset, duration) → ZeemanParams or TimeDependentZeeman

Build the per-phase Zeeman object directly from the override-applied raw
YAML dict. Entries under `ground_state.zeeman.p`/`q` may be scalars
(constant over the phase) or `{from, to}` dicts (linear ramp over the
phase duration). If both p and q are scalar the result is a cheap
constant `ZeemanParams`; otherwise it is a `TimeDependentZeeman` closure.
"""
function _build_phase_zeeman(phase_raw::Dict, t_offset::Float64, duration::Float64)
    gs = get(phase_raw, "ground_state", Dict())
    z = get(gs, "zeeman", Dict())
    p_spec = get(z, "p", 0.0)
    q_spec = get(z, "q", 0.0)

    p_ramp = _parse_ramp_or_constant(p_spec)
    q_ramp = _parse_ramp_or_constant(q_spec)

    if p_ramp isa ConstantValue && q_ramp isa ConstantValue
        ZeemanParams(p_ramp.value, q_ramp.value)
    else
        TimeDependentZeeman(t -> begin
            t_local = t - t_offset
            t_frac = duration > 0 ? t_local / duration : 0.0
            ZeemanParams(
                interpolate_value(p_ramp, t_frac),
                interpolate_value(q_ramp, t_frac),
            )
        end)
    end
end

_parse_ramp_or_constant(v::Dict) = haskey(v, "to") ?
    LinearRamp(Float64(v["from"]), Float64(v["to"])) :
    ConstantValue(Float64(v["from"]))
_parse_ramp_or_constant(v) = ConstantValue(Float64(v))

function _add_noise!(psi, amplitude, n_components, ndim, grid)
    n_pts = ntuple(d -> size(psi, d), ndim)
    dV = cell_volume(grid)
    dominant = argmax([
        sum(abs2, view(psi, _component_slice(ndim, n_pts, c)...)) for c = 1:n_components
    ])
    for c = 1:n_components
        c == dominant && continue
        idx = _component_slice(ndim, n_pts, c)
        view(psi, idx...) .+= amplitude .* randn(ComplexF64, n_pts)
    end
    norm = sqrt(sum(abs2, psi) * dV)
    psi ./= norm
end

function seed_noise(
    psi_gs,
    n_components::Int,
    ndim::Int,
    grid::Grid;
    amplitude::Float64 = 0.001,
    seed::Int = 42,
)
    psi = copy(psi_gs)
    Random.seed!(seed)
    _add_noise!(psi, amplitude, n_components, ndim, grid)
    psi
end

# --- Pipeline step helpers (from pipeline.jl) ---

function _normalize_grid(n_raw, box_raw)
    n_pts = n_raw isa Vector ? Int.(n_raw) : Int[Int(n_raw)]
    box_size = box_raw isa Vector ? Float64.(box_raw) : Float64[Float64(box_raw)]
    length(n_pts) == length(box_size) ||
        throw(ArgumentError("grid n and box must have the same length"))
    (n_pts, box_size)
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
    c_dd = if haskey(ddi_d, "c_dd")
        Float64(ddi_d["c_dd"])
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

# --- Shared utilities ---

"""Convert all keys in a dict to String."""
_to_string_keys(d::Dict) = Dict{String,Any}(string(k) => v for (k, v) in d)

"""Get an optional Float64 from a dict, returning nothing if key is absent."""
_get_optional_float(d::Dict, key::String) =
    let v = get(d, key, nothing); v === nothing ? nothing : Float64(v) end

"""Get an optional Int from a dict, returning nothing if key is absent."""
_get_optional_int(d::Dict, key::String) =
    let v = get(d, key, nothing); v === nothing ? nothing : Int(v) end

"""Parse a potential spec (dict or list of dicts) and build the potential."""
function _parse_and_build_potential(pot_d, ndim::Int)
    if pot_d isa Vector
        components = [PotentialConfig(Symbol(get(c, "type", "harmonic")),
            _to_string_keys(Dict(k => v for (k, v) in c if k != "type"))) for c in pot_d]
        _build_potential(PotentialConfig(:composite, Dict{String,Any}("components" => components)), ndim)
    else
        _build_potential(PotentialConfig(Symbol(get(pot_d, "type", "harmonic")),
            _to_string_keys(Dict(k => v for (k, v) in pot_d if k != "type"))), ndim)
    end
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

"""Parse constant zeeman params from a dict {p: ..., q: ...}."""
function _parse_constant_zeeman(z)
    z isa Dict || return ZeemanParams(0.0, 0.0)
    ZeemanParams(_zeeman_scalar(get(z, "p", 0.0)), _zeeman_scalar(get(z, "q", 0.0)))
end

"""Print ground state summary with populations."""
function _print_gs_summary(psi, grid, atom, gs)
    F = atom.F
    D = 2F + 1
    dV = cell_volume(grid)
    n_pts = grid.config.n_points
    ndim = length(n_pts)
    pops = [sum(abs2, view(psi, _component_slice(ndim, n_pts, c)...)) * dV for c in 1:D]
    total = sum(pops)
    pops ./= total
    sorted_idx = sortperm(pops; rev=true)
    top = [(F - (i-1), pops[i]) for i in sorted_idx[1:min(3, D)]]
    pop_str = join(["m=$(m): $(round(p*100; digits=1))%" for (m, p) in top], ", ")
    mz = sum((F - (c-1)) * pops[c] for c in 1:D)
    println("  E=$(round(gs.energy; sigdigits=6)) conv=$(gs.converged) Mz=$(round(mz; digits=2)) [$pop_str]")
end

"""
Parse zeeman from pipeline params. Supports:
  - {p: 0.5, q: 0.0}                     → constant ZeemanParams
  - {p: {from: 100, to: 0}}              → linear ramp
  - {p: {from: 100, to: 0.1, scale: log}} → log ramp (denser near small values)
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

"""
Build an interpolation function from a ramp spec.
Scalar → constant. Dict {from, to, scale?} → scaled interpolation.
"""
function _make_interpolator(spec)
    spec isa Dict || return _ -> Float64(spec)

    from = Float64(spec["from"])
    to = Float64(get(spec, "to", from))
    scale = Symbol(get(spec, "scale", "linear"))

    if scale == :linear
        return t -> from + (to - from) * t
    elseif scale == :log
        from > 0 && to > 0 || throw(ArgumentError("log ramp requires positive from/to"))
        log_from = log(from)
        log_to = log(to)
        return t -> exp(log_from + (log_to - log_from) * t)
    elseif scale == :sqrt
        s_from = sign(from) * sqrt(abs(from))
        s_to = sign(to) * sqrt(abs(to))
        return t -> begin
            s = s_from + (s_to - s_from) * t
            sign(s) * s^2
        end
    elseif scale == :cosine
        # Smooth start/end (S-curve)
        return t -> from + (to - from) * (1 - cos(π * t)) / 2
    elseif scale == :exponential
        # Fast initial decay, slow tail
        from > 0 || throw(ArgumentError("exponential ramp requires positive from"))
        rate = -log(max(to / from, 1e-10))
        return t -> from * exp(-rate * t)
    else
        throw(ArgumentError("Unknown ramp scale: $scale. Supported: linear, log, sqrt, cosine, exponential"))
    end
end
