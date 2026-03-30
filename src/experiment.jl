# --- Experiment Configuration Types ---

struct ConstantValue
    value::Float64
end

struct LinearRamp
    from::Float64
    to::Float64
end

const RampOrConstant = Union{ConstantValue, LinearRamp}

interpolate_value(v::ConstantValue, ::Float64) = v.value
interpolate_value(v::LinearRamp, t_frac::Float64) = v.from + (v.to - v.from) * clamp(t_frac, 0.0, 1.0)

struct PotentialConfig
    type::Symbol
    params::Dict{String,Any}
end

struct PhaseConfig
    name::String
    duration::Float64
    dt::Float64
    save_every::Int
    zeeman_p::RampOrConstant
    zeeman_q::RampOrConstant
    potential::Union{Nothing,PotentialConfig}
    noise_amplitude::Union{Nothing,Float64}
    adaptive_dt::Union{Nothing,AdaptiveDtParams}
end

struct GroundStateConfig
    dt::Float64
    n_steps::Int
    tol::Float64
    initial_state::Symbol
    zeeman::ZeemanParams
    potential::PotentialConfig
    enable_ddi::Bool
end

struct DDIConfig
    enabled::Bool
    c_dd::Union{Nothing,Float64}
    secular::Bool
    quasi_2d::Bool
    l_z::Float64
end

DDIConfig() = DDIConfig(false, nothing, false, false, 0.0)
DDIConfig(enabled, c_dd, secular) = DDIConfig(enabled, c_dd, secular, false, 0.0)

struct SystemConfig
    atom_name::Symbol
    grid_n_points::Vector{Int}
    grid_box_size::Vector{Float64}
    interactions::InteractionParams
    ddi::DDIConfig
    loss::Union{Nothing,LossParams}
end

struct ExperimentConfig
    name::String
    system::SystemConfig
    ground_state::Union{Nothing,GroundStateConfig}
    sequence::Vector{PhaseConfig}
end

struct ExperimentResult
    config::ExperimentConfig
    ground_state_energy::Union{Nothing,Float64}
    ground_state_converged::Union{Nothing,Bool}
    phase_results::Vector{SimulationResult}
    phase_names::Vector{String}
end

# --- Atom Registry ---

const ATOM_REGISTRY = Dict{Symbol,AtomSpecies}(
    :Rb87 => Rb87,
    :Na23 => Na23,
    :Eu151 => Eu151,
)

function resolve_atom(name::Symbol)
    haskey(ATOM_REGISTRY, name) || throw(ArgumentError("Unknown atom: $name. Available: $(keys(ATOM_REGISTRY))"))
    ATOM_REGISTRY[name]
end

# --- YAML Parsing ---

function load_experiment(path::String)
    data = YAML.load_file(path)
    exp_data = get(data, "experiment", data)
    _parse_experiment(exp_data)
end

function load_experiment_from_string(yaml_str::String)
    data = YAML.load(yaml_str)
    exp_data = get(data, "experiment", data)
    _parse_experiment(exp_data)
end

function _parse_experiment(d::Dict)
    name = get(d, "name", "unnamed")
    system = _parse_system(d["system"])
    gs = haskey(d, "ground_state") ? _parse_ground_state(d["ground_state"]) : nothing
    seq = haskey(d, "sequence") ? [_parse_phase(p) for p in d["sequence"]] : PhaseConfig[]
    ExperimentConfig(name, system, gs, seq)
end

function _parse_system(d::Dict)
    atom_name = Symbol(d["atom"])
    g = d["grid"]
    n_points = _to_int_vec(g["n_points"])
    box_size = _to_float_vec(g["box_size"])

    inter = d["interactions"]
    interactions = if haskey(inter, "c_total")
        c_total = Float64(inter["c_total"])
        c1_ratio = Float64(get(inter, "c1_ratio", 0.0))
        F_atom = resolve_atom(atom_name).F
        c_extra = _parse_c_extra(inter, F_atom)
        interaction_params_from_constraint(; c_total, c1_ratio, F=F_atom, c_extra)
    else
        c0 = Float64(inter["c0"])
        c1 = Float64(inter["c1"])
        c_lhy = Float64(get(inter, "c_lhy", 0.0))
        F_atom = resolve_atom(atom_name).F
        c_extra = _parse_c_extra(inter, F_atom)
        InteractionParams(c0, c1, c_lhy, c_extra)
    end

    ddi = if haskey(d, "ddi")
        dd = d["ddi"]
        enabled = get(dd, "enabled", false)
        c_dd = haskey(dd, "c_dd") ? Float64(dd["c_dd"]) : nothing
        secular = Bool(get(dd, "secular", false))
        quasi_2d = Bool(get(dd, "quasi_2d", false))
        l_z = Float64(get(dd, "l_z", 0.0))
        DDIConfig(enabled, c_dd, secular, quasi_2d, l_z)
    else
        DDIConfig()
    end

    loss = if haskey(d, "losses")
        ld = d["losses"]
        LossParams(Float64(get(ld, "gamma_dr", 0.0)), Float64(get(ld, "L3", 0.0)))
    else
        nothing
    end

    SystemConfig(atom_name, n_points, box_size, interactions, ddi, loss)
end

function _parse_ground_state(d::Dict)
    dt = Float64(d["dt"])
    n_steps = Int(d["n_steps"])
    tol = Float64(d["tol"])
    initial_state = Symbol(get(d, "initial_state", "polar"))

    z = get(d, "zeeman", Dict())
    zeeman = ZeemanParams(Float64(get(z, "p", 0.0)), Float64(get(z, "q", 0.0)))

    pot = _parse_potential_config(get(d, "potential", Dict("type" => "none")))

    gs_enable_ddi = Bool(get(d, "enable_ddi", false))

    GroundStateConfig(dt, n_steps, tol, initial_state, zeeman, pot, gs_enable_ddi)
end

function _parse_phase(d::Dict)
    name = get(d, "name", "unnamed")
    duration = Float64(d["duration"])
    dt = Float64(d["dt"])
    save_every = Int(get(d, "save_every", 1))

    z = get(d, "zeeman", Dict())
    zeeman_p = _parse_ramp_or_constant(get(z, "p", 0.0))
    zeeman_q = _parse_ramp_or_constant(get(z, "q", 0.0))

    pot = haskey(d, "potential") ? _parse_potential_config(d["potential"]) : nothing

    noise_amp = let v = get(d, "noise_amplitude", nothing)
        v === nothing ? nothing : Float64(v)
    end

    adaptive = if haskey(d, "adaptive_dt")
        ad = d["adaptive_dt"]
        AdaptiveDtParams(;
            dt_init=Float64(get(ad, "dt_init", dt)),
            dt_min=Float64(get(ad, "dt_min", 1e-5)),
            dt_max=Float64(get(ad, "dt_max", 10 * dt)),
            tol=Float64(get(ad, "tol", 1e-3)),
            error_mode=Symbol(get(ad, "error_mode", "step_change")),
        )
    else
        nothing
    end

    PhaseConfig(name, duration, dt, save_every, zeeman_p, zeeman_q, pot, noise_amp, adaptive)
end

function _parse_ramp_or_constant(v)::RampOrConstant
    if v isa Dict
        if haskey(v, "to")
            return LinearRamp(Float64(v["from"]), Float64(v["to"]))
        end
        return ConstantValue(Float64(v["from"]))
    end
    ConstantValue(Float64(v))
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
    for n in 2:max_n
        haskey(inter, "c$n") && (c_extra[n - 1] = Float64(inter["c$n"]))
    end
    c_extra
end

# --- Phase Scan Configuration ---

struct ScanGroundStateConfig
    dt::Float64
    n_steps::Int
    tol::Float64
    initial_state::Symbol
    zeeman::ZeemanParams
    potential::PotentialConfig
    target_magnetization::Union{Nothing,Float64}
    rotating_frame_omega::Float64
end

struct PhaseScanConfig
    name::String
    system::SystemConfig
    ground_state::ScanGroundStateConfig
    c_total::Float64
    scan::AbstractScanSpec
    strategy::ScanStrategyConfig
    stability::ScanStabilityConfig
    output::ScanOutputConfig
end

function load_phase_scan(path::String)
    data = YAML.load_file(path)
    ps_data = get(data, "phase_scan", data)
    _parse_phase_scan(ps_data)
end

function load_phase_scan_from_string(yaml_str::String)
    data = YAML.load(yaml_str)
    ps_data = get(data, "phase_scan", data)
    _parse_phase_scan(ps_data)
end

function _parse_phase_scan(d::Dict)
    name = get(d, "name", "unnamed scan")
    system = _parse_system(d["system"])
    gs = _parse_scan_ground_state(d["ground_state"])

    F = resolve_atom(system.atom_name).F
    ip = system.interactions
    c_total = ip.c0 + F^2 * ip.c1

    scan_d = d["scan"]
    scan_type = Symbol(scan_d["type"])
    scan = if scan_type == :parameter
        _parse_parameter_scan(scan_d)
    elseif scan_type == :constrained_jz
        _parse_constrained_jz_scan(scan_d)
    else
        throw(ArgumentError("Unknown scan type: $scan_type. Supported: parameter, constrained_jz"))
    end

    strategy = haskey(d, "strategy") ? _parse_strategy(d["strategy"]) : ScanStrategyConfig()

    stab = haskey(d, "stability") ? _parse_scan_stability(d["stability"]) : ScanStabilityConfig()
    output = haskey(d, "output") ? _parse_scan_output(d["output"]) : ScanOutputConfig()

    PhaseScanConfig(name, system, gs, c_total, scan, strategy, stab, output)
end

function _parse_scan_ground_state(d::Dict)
    dt = Float64(d["dt"])
    n_steps = Int(d["n_steps"])
    tol = Float64(d["tol"])
    initial_state = Symbol(get(d, "initial_state", "polar"))

    z = get(d, "zeeman", Dict())
    zeeman = ZeemanParams(Float64(get(z, "p", 0.0)), Float64(get(z, "q", 0.0)))

    pot = _parse_potential_config(get(d, "potential", Dict("type" => "none")))

    target_mag = let v = get(d, "target_magnetization", nothing)
        v === nothing ? nothing : Float64(v)
    end

    rotating_frame_omega = Float64(get(d, "rotating_frame_omega", 0.0))

    ScanGroundStateConfig(dt, n_steps, tol, initial_state, zeeman, pot,
                          target_mag, rotating_frame_omega)
end

function _parse_parameter_scan(d::Dict)
    axes_data = d["axes"]
    axes = SweepAxis[_parse_sweep_axis(a) for a in axes_data]
    ParameterScan(axes)
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

function _parse_strategy(d::Dict)
    cont = haskey(d, "continuation") ? _parse_continuation(d["continuation"]) : ContinuationConfig()
    ms = haskey(d, "multistart") ? _parse_multistart(d["multistart"]) : MultiStartConfig()
    ScanStrategyConfig(cont, ms)
end

function _parse_multistart(d::Dict)
    enabled = Bool(get(d, "enabled", false))
    states = if haskey(d, "initial_states")
        Symbol[Symbol(s) for s in d["initial_states"]]
    else
        Symbol[:polar, :ferromagnetic, :uniform, :antiferromagnetic]
    end
    n_random = Int(get(d, "n_random", 0))
    MultiStartConfig(enabled, states, n_random)
end

function _parse_sweep_axis(d::Dict)
    param = Symbol(d["parameter"])
    vals = d["values"]
    values = if vals isa Dict
        SweepValues(Float64(vals["from"]), Float64(vals["to"]), Int(vals["n_points"]))
    else
        Float64[Float64(v) for v in vals]
    end
    SweepAxis(param, values)
end

function _parse_continuation(d::Dict)
    enabled = Bool(get(d, "enabled", true))
    n_steps = Int(get(d, "n_steps", 1000))
    threshold = Float64(get(d, "energy_jump_threshold", 0.1))
    ContinuationConfig(enabled, n_steps, threshold)
end

function _parse_scan_stability(d::Dict)
    enabled = Bool(get(d, "enabled", false))
    perturbation = Float64(get(d, "perturbation", 1e-4))
    n_steps = Int(get(d, "n_steps", 300))
    sample_every = Int(get(d, "sample_every", 10))
    ScanStabilityConfig(enabled, perturbation, n_steps, sample_every)
end

function _parse_scan_output(d::Dict)
    dir = String(get(d, "dir", "results"))
    csv = Bool(get(d, "csv", true))
    save_psi = Bool(get(d, "save_psi", false))
    ScanOutputConfig(dir, csv, save_psi)
end
