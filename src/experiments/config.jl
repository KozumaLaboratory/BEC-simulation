# --- Unified Config v3: types + parser ---

struct DynamicsExperiment <: AbstractExperimentSpec
    sequence::Vector{PhaseConfig}
    perturbation::Union{Nothing,PerturbationConfig}
end

struct ScanExperiment{S<:AbstractScanSpec} <: AbstractExperimentSpec
    scan::S
    stability::ScanStabilityConfig
end

struct UnifiedConfig{S<:AbstractExperimentSpec}
    version::Int
    name::String
    system::SystemConfig
    ground_state::GroundStateConfig
    spec::S
    output::OutputConfig
    observables::ObservablesConfig
end

# --- Loader ---

function load_config(path::String)
    data = YAML.load_file(path)
    _parse_config(data)
end

function load_config_from_string(yaml_str::String)
    data = YAML.load(yaml_str)
    _parse_config(data)
end

function _parse_config(data::Dict)
    exp_data = get(data, "experiment", data)
    _parse_v3(exp_data)
end

# --- v3 parsing ---

function _parse_v3(d::Dict)
    version = Int(get(d, "version", 3))
    name = get(d, "name", "unnamed")
    exp_type = Symbol(d["type"])

    system = _parse_system(d["system"])
    gs = _parse_ground_state(d["ground_state"])
    output = _parse_output_config(get(d, "output", Dict()))
    observables = _parse_observables(get(d, "observables", Dict()))

    if exp_type == :ground_state
        return UnifiedConfig(
            version,
            name,
            system,
            gs,
            GroundStateExperiment(),
            output,
            observables,
        )
    elseif exp_type == :dynamics
        spec = _parse_v3_dynamics(d)
        return UnifiedConfig(version, name, system, gs, spec, output, observables)
    elseif exp_type == :phase_scan
        spec = _parse_v3_phase_scan(d)
        return UnifiedConfig(version, name, system, gs, spec, output, observables)
    else
        throw(
            ArgumentError(
                "Unknown experiment type: $exp_type. Supported: ground_state, dynamics, phase_scan",
            ),
        )
    end
end

function _parse_v3_dynamics(d::Dict)
    seq = haskey(d, "sequence") ? [_parse_phase(p) for p in d["sequence"]] : PhaseConfig[]

    perturbation = if haskey(d, "perturbation")
        pd = d["perturbation"]
        amplitude = Float64(pd["amplitude"])
        seed = let v = get(pd, "seed", nothing)
            v === nothing ? nothing : Int(v)
        end
        PerturbationConfig(amplitude, seed)
    else
        nothing
    end

    DynamicsExperiment(seq, perturbation)
end

function _parse_v3_phase_scan(d::Dict)
    scan_d = d["scan"]
    scan_type = Symbol(scan_d["type"])
    scan = if scan_type == :parameter
        _parse_parameter_scan(scan_d)
    elseif scan_type == :constrained_jz
        _parse_constrained_jz_scan(scan_d)
    else
        throw(ArgumentError("Unknown scan type: $scan_type"))
    end

    stab =
        haskey(d, "stability") ? _parse_scan_stability(d["stability"]) :
        ScanStabilityConfig()

    ScanExperiment(scan, stab)
end

function _parse_output_config(d::Dict)
    dir = String(get(d, "dir", "results"))
    csv = Bool(get(d, "csv", true))
    save_psi = Bool(get(d, "save_psi", false))

    cp = get(d, "checkpoint", Dict())
    cp_enabled = Bool(get(cp, "enabled", false))
    cp_interval = Int(get(cp, "interval", 1000))

    seed = let v = get(d, "seed", nothing)
        v === nothing ? nothing : Int(v)
    end

    OutputConfig(dir, csv, save_psi, cp_enabled, cp_interval, seed)
end

function _parse_observables(d::Dict)
    always = Symbol[Symbol(s) for s in get(d, "always", ["norm", "magnetization"])]
    on_save = Symbol[Symbol(s) for s in get(d, "on_save", ["energy"])]
    final_only = Symbol[Symbol(s) for s in get(d, "final_only", String[])]
    spatial_sampling = Float64(get(d, "spatial_sampling", 1.0))
    ObservablesConfig(always, on_save, final_only, spatial_sampling)
end
