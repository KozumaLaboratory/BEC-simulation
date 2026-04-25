# --- YAML schema validation ---
#
# Catches typos and invalid values before a multi-hour GPU run starts.
# Design: each schema is a Dict{String, FieldSpec}. validate_config! walks
# the pipeline dict and reports unknown keys as warnings, missing required
# keys and out-of-range values as errors.

struct FieldSpec
    required::Bool
    type::Type
    default::Any
    range::Union{Nothing, Tuple{Float64,Float64}}
    enum::Union{Nothing, Vector{String}}
    schema::Union{Nothing, Dict{String, FieldSpec}}  # for nested dicts
end

FieldSpec(; required=false, type=Any, default=nothing, range=nothing, enum=nothing, schema=nothing) =
    FieldSpec(required, type, default, range, enum, schema)

const GRID_SCHEMA = Dict{String, FieldSpec}(
    "n"   => FieldSpec(required=true, type=Union{Vector, Int}),
    "box" => FieldSpec(required=true, type=Union{Vector, Float64}),
)

const INTERACTIONS_SCHEMA = Dict{String, FieldSpec}(
    "N_atoms"    => FieldSpec(type=Number),
    "omega_ref"  => FieldSpec(type=Number, range=(0.0, 1e10)),
    "c_total"    => FieldSpec(type=Number),
    "c0"         => FieldSpec(type=Number),
    "c1"         => FieldSpec(type=Number),
    "c1_ratio"   => FieldSpec(type=Number, range=(-1.0, 1.0)),
    "c_lhy"      => FieldSpec(type=Number),
    "c_extra"    => FieldSpec(type=Vector),
)

const DDI_SCHEMA = Dict{String, FieldSpec}(
    "enabled"   => FieldSpec(type=Bool, default=false),
    "c_dd"      => FieldSpec(type=Union{Number, Dict}),
    "secular"   => FieldSpec(type=Bool, default=false),
    "quasi_2d"  => FieldSpec(type=Bool, default=false),
    "l_z"       => FieldSpec(type=Number, range=(0.0, 100.0)),
)

const GS_SCHEMA = Dict{String, FieldSpec}(
    "method"               => FieldSpec(type=String, default="itp", enum=["itp", "lbfgs"]),
    "atom"                 => FieldSpec(type=String),
    "grid"                 => FieldSpec(type=Dict, schema=GRID_SCHEMA),
    "interactions"         => FieldSpec(type=Dict, schema=INTERACTIONS_SCHEMA),
    "ddi"                  => FieldSpec(type=Union{Dict, Bool}),
    "zeeman"               => FieldSpec(type=Dict),
    "potential"            => FieldSpec(type=Union{Dict, Vector}),
    "dt"                   => FieldSpec(type=Number, default=0.001, range=(1e-8, 1.0)),
    "n_steps"              => FieldSpec(type=Number, default=100000, range=(1.0, 1e9)),
    "tol"                  => FieldSpec(type=Number, default=1e-8, range=(1e-16, 1.0)),
    "m_lbfgs"              => FieldSpec(type=Number, default=10, range=(1.0, 100.0)),
    "initial_state"        => FieldSpec(type=String, default="polar",
        enum=["polar", "ferromagnetic", "ferromagnetic_min",
              "uniform", "antiferromagnetic", "random",
              "spin_coherent", "fl_vortex", "spin_helix",
              "cyclic", "biaxial_nematic", "polar_core_vortex",
              "soliton_bright", "soliton_dark", "skyrmion",
              "gaussian_wavepacket", "domain_wall", "two_packet",
              "chiral_spin_vortex", "magnetic_domain",
              "vortex_lattice", "skyrmion_lattice"]),
    "backend"              => FieldSpec(type=String, default="cpu", enum=["cpu", "cuda", "gpu"]),
    "target_magnetization" => FieldSpec(type=Number),
    "temperature_ratio"    => FieldSpec(type=Number, range=(0.0, 1.0)),
    "spinor_lhy"           => FieldSpec(type=String,
        enum=["two_channel", "table", "scalar"]),
    "init_state_params"    => FieldSpec(type=Dict),
    "cache"                => FieldSpec(type=String),
    "quasi_2d"             => FieldSpec(type=Bool),
    "l_z"                  => FieldSpec(type=Number, range=(0.0, 100.0)),
    "noise_seed"           => FieldSpec(type=Number),
    "rotating_frame_omega" => FieldSpec(type=Number),
    "adaptive_dt"          => FieldSpec(type=Bool),
    "dt_max"               => FieldSpec(type=Number),
    "light_shift"          => FieldSpec(type=Dict),
    "raman"                => FieldSpec(type=Dict),
)

const DYNAMICS_SCHEMA = Dict{String, FieldSpec}(
    "duration"           => FieldSpec(required=true, type=Number, range=(0.0, 1e6)),
    "dt"                 => FieldSpec(required=true, type=Number, range=(1e-8, 1.0)),
    "save_every"         => FieldSpec(type=Number, range=(1.0, 1e8)),
    "save_psi_snapshots" => FieldSpec(type=Bool),
    "save_snapshot_compression" => FieldSpec(type=Bool),
    "save_snapshot_precision"   => FieldSpec(type=String, enum=["f32", "f64"]),
    "ddi"                => FieldSpec(type=Union{Dict, Bool}),
    "zeeman"             => FieldSpec(type=Dict),
    "interactions"       => FieldSpec(type=Dict),
    "potential"          => FieldSpec(type=Union{Dict, Vector}),
    "temperature_ratio"  => FieldSpec(type=Number, range=(0.0, 1.0)),
    "seed_amplitude"     => FieldSpec(type=Number, range=(0.0, 1.0)),
    "noise_seed"         => FieldSpec(type=Number),
    "integrator"         => FieldSpec(type=String,
        enum=["strang", "yoshida", "adaptive", "richardson"]),
    "backend"            => FieldSpec(type=String, enum=["cpu", "cuda", "gpu"]),
    "raman"              => FieldSpec(type=Dict),
    "absorbing_boundary" => FieldSpec(type=Dict),
    "light_shift"        => FieldSpec(type=Dict),
    "twa"                => FieldSpec(type=Dict),
    "magnetic_gradient"  => FieldSpec(type=Dict),
    "pulse_sequence"     => FieldSpec(type=Vector),
    "sgpe"               => FieldSpec(type=Union{Dict, Bool}),
    "loss"               => FieldSpec(type=Union{Dict, Bool, Number}),
)

const STEP_SCHEMAS = Dict{String, Dict{String, FieldSpec}}(
    "ground_state" => GS_SCHEMA,
    "dynamics"     => DYNAMICS_SCHEMA,
)

"""
    validate_config!(params::Dict, schema::Dict, path::String; strict::Bool=false)

Validate a YAML config dict against a schema.
- Unknown keys → warning (typo detection)
- Missing required keys → error
- Wrong type or out-of-range → error
- Invalid enum value → error
"""
function validate_config!(params::Dict, schema::Dict, path::String = ""; strict::Bool = false)
    errors = String[]
    known = Set(keys(schema))

    # Check for unknown keys (likely typos)
    for k in keys(params)
        if !(k in known)
            msg = "Unknown key '$(isempty(path) ? k : "$path.$k")' — possible typo? Known keys: $(sort(collect(known)))"
            if strict
                push!(errors, msg)
            else
                @warn msg
            end
        end
    end

    # Check required keys
    for (k, spec) in schema
        if spec.required && !haskey(params, k)
            push!(errors, "Required key '$(isempty(path) ? k : "$path.$k")' is missing")
        end
    end

    # Type, range, and enum checks
    for (k, v) in params
        haskey(schema, k) || continue
        spec = schema[k]
        full_key = isempty(path) ? k : "$path.$k"

        # Type check
        if spec.type !== Any && !(v isa spec.type)
            # Allow Number → Bool promotion, Int → Float64, etc.
            ok = (spec.type <: Number && v isa Number) ||
                 (spec.type === String && v isa AbstractString) ||
                 (spec.type === Bool && v isa Bool) ||
                 (spec.type isa Union && any(T -> v isa T, Base.uniontypes(spec.type)))
            if !ok
                push!(errors, "'$full_key' expected $(spec.type), got $(typeof(v))")
            end
        end

        # Range check
        if spec.range !== nothing && v isa Number
            lo, hi = spec.range
            (lo <= Float64(v) <= hi) || push!(errors,
                "'$full_key' = $v is out of range [$lo, $hi]")
        end

        # Enum check
        if spec.enum !== nothing && v isa AbstractString
            String(v) in spec.enum || push!(errors,
                "'$full_key' = '$v' is not valid. Options: $(spec.enum)")
        end

        # Nested schema
        if spec.schema !== nothing && v isa Dict
            validate_config!(v, spec.schema, full_key; strict)
        end
    end

    if !isempty(errors)
        throw(ArgumentError("Config validation errors:\n" * join(["  • $e" for e in errors], "\n")))
    end
end

"""
    validate_pipeline!(data::Dict)

Validate a full pipeline YAML dict. Checks each step against its schema.
"""
function validate_pipeline!(data::Dict)
    pipeline = get(data, "pipeline", nothing)
    pipeline === nothing && throw(ArgumentError("YAML must have a 'pipeline:' key"))
    pipeline isa Vector || throw(ArgumentError("'pipeline' must be a list of steps"))

    for (i, step) in enumerate(pipeline)
        step isa Dict || throw(ArgumentError("Pipeline step $i must be a dict"))
        step_keys = collect(keys(step))
        length(step_keys) == 1 || throw(ArgumentError(
            "Pipeline step $i must have exactly one key, got: $step_keys"))
        step_type = String(step_keys[1])
        step_params = step[step_keys[1]]

        if haskey(STEP_SCHEMAS, step_type) && step_params isa Dict
            validate_config!(step_params, STEP_SCHEMAS[step_type], "pipeline.$i.$step_type")
        end
    end
end
