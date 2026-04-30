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
    range::Union{Nothing, Tuple{Float64, Float64}}
    enum::Union{Nothing, Vector{String}}
    schema::Union{Nothing, Dict{String, FieldSpec}}  # for nested dicts
end

FieldSpec(; required=false, type=Any, default=nothing, range=nothing, enum=nothing, schema=nothing) = FieldSpec(
    required, type, default, range, enum, schema
)

const GRID_SCHEMA = Dict{String, FieldSpec}(
    "n" => FieldSpec(; required=true, type=Union{Vector, Int}),
    "box" => FieldSpec(; required=true, type=Union{Vector, Float64}),
)

const INTERACTIONS_SCHEMA = Dict{String, FieldSpec}(
    "N_atoms" => FieldSpec(; type=Number),
    "omega_ref" => FieldSpec(; type=Number, range=(0.0, 1e10)),
    "c_total" => FieldSpec(; type=Number),
    "c0" => FieldSpec(; type=Number),
    "c1" => FieldSpec(; type=Number),
    "c1_ratio" => FieldSpec(; type=Number, range=(-1.0, 1.0)),
    "c_lhy" => FieldSpec(; type=Number),
    "c_extra" => FieldSpec(; type=Vector),
)

const DDI_SCHEMA = Dict{String, FieldSpec}(
    "enabled" => FieldSpec(; type=Bool, default=true),     # was false, flipped 2026-04-30
    "c_dd" => FieldSpec(; type=Union{Number, Dict}),
    "secular" => FieldSpec(; type=Bool, default=false),
    "quasi_2d" => FieldSpec(; type=Bool, default=false),
    "l_z" => FieldSpec(; type=Number, range=(0.0, 100.0)),
)

# `kind` selects the solver path:
#   spinor          (default)  — full F=2F+1 spinor GP, Larmor sub-cycled
#                              Use for static B / weak-field experiments.
#   binary                     — two-component miscible/immiscible GP
#                              (species_A, species_B blocks required).
#   rotating_basis             — Option γ: B̂(t) rotating-direction frame
#                              that absorbs Larmor analytically. Use for
#                              Klaus-style protocols where B direction
#                              evolves and p·F·dt would otherwise blow up.
#   option_gamma               — alias for rotating_basis (legacy name).
const GS_SCHEMA = Dict{String, FieldSpec}(
    "kind" => FieldSpec(; type=String, enum=["spinor", "binary", "rotating_basis", "option_gamma"]),
    "dtype" => FieldSpec(; type=String, default="f64", enum=["f32", "f64"]),
    "species_A" => FieldSpec(; type=Dict),    # binary path
    "species_B" => FieldSpec(; type=Dict),    # binary path
    "B_hat" => FieldSpec(; type=Dict),        # rotating_basis path
    "F" => FieldSpec(; type=Integer, range=(0, 12)),   # rotating_basis F override
    "gauge_fix" => FieldSpec(; type=Bool, default=true),  # rotating_basis
    "init_m_idx" => FieldSpec(; type=Integer, range=(1, 25)),
    "init_sigma" => FieldSpec(; type=Number, range=(0.0, 100.0)),
    "backend" => FieldSpec(; type=String, enum=["cpu", "gpu"]),
    "method" => FieldSpec(; type=String, default="itp", enum=["itp", "lbfgs"]),
    "atom" => FieldSpec(; type=String),
    "grid" => FieldSpec(; type=Dict, schema=GRID_SCHEMA),
    "interactions" => FieldSpec(; type=Dict, schema=INTERACTIONS_SCHEMA),
    "ddi" => FieldSpec(; type=Union{Dict, Bool}),
    "zeeman" => FieldSpec(; type=Dict),
    "potential" => FieldSpec(; type=Union{Dict, Vector}),
    "dt" => FieldSpec(; type=Number, default=0.001, range=(1e-8, 1.0)),
    "n_steps" => FieldSpec(; type=Number, default=100000, range=(1.0, 1e9)),
    "tol" => FieldSpec(; type=Number, default=1e-8, range=(1e-16, 1.0)),
    "m_lbfgs" => FieldSpec(; type=Number, default=10, range=(1.0, 100.0)),
    "initial_state" => FieldSpec(; type=String, default="polar",
        enum=["polar", "ferromagnetic", "ferromagnetic_min",
            "uniform", "antiferromagnetic", "random",
            "spin_coherent", "fl_vortex", "spin_helix",
            "cyclic", "biaxial_nematic", "polar_core_vortex",
            "soliton_bright", "soliton_dark", "skyrmion",
            "gaussian_wavepacket", "domain_wall", "two_packet",
            "chiral_spin_vortex", "magnetic_domain",
            "vortex_lattice", "skyrmion_lattice"]),
    "backend" => FieldSpec(; type=String, default="cpu", enum=["cpu", "gpu"]),
    "target_magnetization" => FieldSpec(; type=Number),
    "temperature_ratio" => FieldSpec(; type=Number, range=(0.0, 1.0)),
    "spinor_lhy" => FieldSpec(; type=String,
        enum=["two_channel", "table", "scalar"]),
    "init_state_params" => FieldSpec(; type=Dict),
    "cache" => FieldSpec(; type=String),
    "quasi_2d" => FieldSpec(; type=Bool),
    "l_z" => FieldSpec(; type=Number, range=(0.0, 100.0)),
    "noise_seed" => FieldSpec(; type=Number),
    "rotating_frame_omega" => FieldSpec(; type=Number),
    "light_shift" => FieldSpec(; type=Dict),
    "raman" => FieldSpec(; type=Dict),
)

const DYNAMICS_SCHEMA = Dict{String, FieldSpec}(
    "duration" => FieldSpec(; required=true, type=Number, range=(0.0, 1e6)),
    "dt" => FieldSpec(; required=true, type=Number, range=(1e-8, 1.0)),
    # Unified `save:` block. Sub-keys: every (steps) | n_snapshots (frames)
    # | psi (Bool) | compression (Bool) | precision ("f32"|"f64").
    "save" => FieldSpec(; type=Dict),
    "rotating_frame_omega" => FieldSpec(; type=Number),    # spatial (rotating bucket)
    "ddi" => FieldSpec(; type=Union{Dict, Bool}),
    "zeeman" => FieldSpec(; type=Dict),
    "interactions" => FieldSpec(; type=Dict),
    "potential" => FieldSpec(; type=Union{Dict, Vector}),
    "temperature_ratio" => FieldSpec(; type=Number, range=(0.0, 1.0)),
    "seed_amplitude" => FieldSpec(; type=Number, range=(0.0, 1.0)),
    "seed_k_cut" => FieldSpec(; type=Number, range=(0.0, 1.0e6)),
    "noise_seed" => FieldSpec(; type=Number),
    "live_monitor" => FieldSpec(; type=Union{Bool, Dict}),
    "integrator" => FieldSpec(; type=String,
        enum=["strang", "yoshida", "adaptive", "richardson"]),
    "backend" => FieldSpec(; type=String, enum=["cpu", "gpu"]),
    "raman" => FieldSpec(; type=Dict),
    "absorbing_boundary" => FieldSpec(; type=Dict),
    "light_shift" => FieldSpec(; type=Dict),
    "twa" => FieldSpec(; type=Dict),
    "magnetic_gradient" => FieldSpec(; type=Dict),
    "pulse_sequence" => FieldSpec(; type=Vector),
    "sgpe" => FieldSpec(; type=Union{Dict, Bool}),
    "projected_gp" => FieldSpec(; type=Union{Dict, Bool}),
    "photon_scattering" => FieldSpec(; type=Union{Dict, Bool}),
    "loss" => FieldSpec(; type=Union{Dict, Bool, Number}),
    # Two-component / binary GP path (Phase 4/5 #51 scaffold).
    "kind" => FieldSpec(; type=String, enum=["binary", "rotating_basis", "option_gamma"]),
    "couplings" => FieldSpec(; type=Dict),
    # Option γ rotating-basis dynamics
    "B_hat" => FieldSpec(; type=Dict),
    "integrator" => FieldSpec(; type=String,
        enum=["strang", "yoshida4", "yoshida6", "cfet4"]),
    "epsilon" => FieldSpec(; type=Number, range=(1e-15, 1.0)),
)

const STEP_SCHEMAS = Dict{String, Dict{String, FieldSpec}}(
    "ground_state" => GS_SCHEMA,
    "dynamics" => DYNAMICS_SCHEMA,
)

# Top-level YAML keys recognised by the runner. Anything else triggers
# a typo warning so users catch e.g. `pipline:` vs `pipeline:` early.
const TOP_LEVEL_KEYS = Set([
    "pipeline",
    "scan",
    "calibration",
    "calibration_history",
    "target_date",
    "units",             # opt-in lab-unit interpretation of bare Reals
    "defaults",          # per-step seeded fallbacks (DRY across pipeline)
    "mixins",            # named parameter sets pulled into the config
    "accuracy",          # ε accuracy budget — seeds rotating_basis epsilon
    "auto_grid",         # bool — enable TF-radius grid auto-derivation
    "metadata",          # free-form provenance, ignored at runtime
    "name",              # human-readable label for the scenario
    "notes",             # free-form notes
    "version",           # YAML schema version stamp
])

"""
    validate_config!(params::Dict, schema::Dict, path::String; strict::Bool=false)

Validate a YAML config dict against a schema.
- Unknown keys → warning (typo detection)
- Missing required keys → error
- Wrong type or out-of-range → error
- Invalid enum value → error
"""
function validate_config!(params::Dict, schema::Dict, path::String=""; strict::Bool=false)
    errors = String[]
    known = Set(keys(schema))

    # Check for unknown keys (likely typos). Suggest the closest match
    # via Levenshtein distance — catches "phi" → "phi_omega", etc.
    for k in keys(params)
        if !(k in known)
            full_key = isempty(path) ? string(k) : "$path.$k"
            suggestion = _suggest_key(string(k), known)
            base = "Unknown key '$full_key'"
            msg = if suggestion !== nothing
                "$base — did you mean '$suggestion'? Known keys: $(sort(collect(known)))"
            else
                "$base — possible typo? Known keys: $(sort(collect(known)))"
            end
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
            ok =
                (spec.type <: Number && v isa Number) ||
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
function validate_pipeline!(data::Dict; strict::Bool=false)
    # Top-level typo guard. In strict mode (production runner default)
    # unknown keys become errors — silent drops here have caused entire
    # physics regressions (2026-04-27 `trap:` incident: pancake YAML ran
    # in isotropic trap because `trap:` was not recognized and the
    # @warn was easy to miss in the noise).
    unknown_top = String[]
    for k in keys(data)
        sk = String(k)
        sk in TOP_LEVEL_KEYS && continue
        push!(unknown_top, sk)
    end
    if !isempty(unknown_top)
        msg = "Unknown top-level YAML key(s) $unknown_top — typo? Recognised: $(sort(collect(TOP_LEVEL_KEYS)))"
        strict ? throw(ArgumentError(msg)) : @warn msg
    end

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
            validate_config!(step_params, STEP_SCHEMAS[step_type],
                "pipeline.$i.$step_type"; strict)
            # Cross-field F-dependent validation.
            if step_type == "ground_state"
                _validate_ground_state_physics!(step_params, "pipeline.$i.ground_state"; strict)
            end
        elseif !(step_type in ("ground_state", "dynamics", "analyze"))
            msg = "Unknown pipeline step kind '$step_type' (line $i) — typo? Recognised: ground_state, dynamics, analyze"
            strict ? throw(ArgumentError(msg)) : @warn msg
        end
    end
end

"""
    _validate_ground_state_physics!(step_params, path; strict)

F-dependent cross-field validation that the static schema cannot express:

- `c1_ratio > -1/F²` (singularity in `interaction_params_from_constraint`:
  `c0 = c_total / (1 + F²·c1_ratio)`, so values at or below `-1/F²` give
  `c0 ≤ 0` — non-physical density attraction).

The schema's `c1_ratio` range `(-1.0, 1.0)` is generous on purpose so
F=1 (singularity at -1) and F=6 (singularity at -1/36) share one declaration.
This function tightens it once `F` is known.
"""
function _validate_ground_state_physics!(step_params::Dict, path::String; strict::Bool=false)
    # Resolve F: prefer `atom:` lookup, fall back to F=1 if neither given.
    atom_str = get(step_params, "atom", nothing)
    F = if atom_str !== nothing
        a = resolve_atom(Symbol(String(atom_str)))
        a !== nothing ? a.F : 1
    else
        1
    end

    inter = get(step_params, "interactions", nothing)
    if inter isa Dict && haskey(inter, "c1_ratio")
        cr_raw = inter["c1_ratio"]
        cr = if cr_raw isa Number
            Float64(cr_raw)
        else
            (cr_raw isa Dict && haskey(cr_raw, "from") ? Float64(cr_raw["from"]) : 0.0)
        end
        bound = -1.0 / F^2
        if cr <= bound + 1e-10
            msg =
                "$path.interactions.c1_ratio = $cr is at or below the singularity " *
                "-1/F² = $(round(bound; sigdigits=4)) for F=$F. " *
                "interaction_params_from_constraint gives c0 → ∞ or c0 ≤ 0 (non-physical). " *
                "Use c1_ratio > $(round(bound; sigdigits=4))."
            strict ? throw(ArgumentError(msg)) : @warn msg
        end
    end
end

# Levenshtein distance for typo suggestions. Returns the closest key in
# `known` if its distance to `k` is ≤ max(2, |k|/3) — close enough to
# almost certainly be a typo. nothing otherwise.
function _suggest_key(k::String, known::Set)
    isempty(known) && return nothing
    threshold = max(2, length(k) ÷ 3)
    best, best_d = nothing, threshold + 1
    for cand in known
        c = string(cand)
        d = _levenshtein(k, c)
        if d < best_d
            best, best_d = c, d
        end
    end
    best_d <= threshold ? best : nothing
end

function _levenshtein(a::AbstractString, b::AbstractString)
    m, n = length(a), length(b)
    m == 0 && return n
    n == 0 && return m
    av, bv = collect(a), collect(b)
    prev = collect(0:n)
    curr = zeros(Int, n + 1)
    for i in 1:m
        curr[1] = i
        for j in 1:n
            cost = av[i] == bv[j] ? 0 : 1
            curr[j+1] = min(curr[j] + 1, prev[j+1] + 1, prev[j] + cost)
        end
        prev, curr = curr, prev
    end
    prev[n+1]
end
