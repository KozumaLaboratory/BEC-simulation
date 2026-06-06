# --- Effective-config inspector ---
#
# `inspect_config(path)` answers the question:
#
#   "When I write this YAML, what does the simulator actually solve?"
#
# Runs the normal `_normalize_and_validate!` pipeline, then `parse_pipeline`,
# then samples the resolved B(t) / q(t) / Raman / loss / LHY for each step
# and runs a battery of detectors for silent semantic mismatches we have
# been bitten by historically:
#
#   - W1  B-direction (theta/phi) silently dropped on the split-step path.
#         The unified B-block normaliser splits {B_mag, theta, phi} into
#         `B`/`B_direction`, but only the rotating_basis path reads
#         `B_direction.theta` (radians). The split-step path reads
#         `theta_deg`/`phi_deg` (degrees) from the magnitude dict — so a
#         spinor (split-step) step that writes `B: {B_mag, theta: π}`
#         silently runs with the field aligned to +ẑ. Memory:
#         gotcha_B_mag_spherical_form_ignores_theta_for_direction.md.
#
#   - W2  `{from, to, duration: 0.0}` ramps. Before 2026-05-25 the inner
#         `duration: 0.0` was silently overridden by the outer step
#         duration, producing a full-window ramp instead of an
#         instantaneous jump. The 2026-05-25 fix in builders_phase.jl
#         now collapses to ConstantWaveform(to) — but legacy configs
#         that were authored assuming the old buggy semantics may not
#         match the user's intent. The inspector reports the resolved
#         waveform shape so the user can verify. Memory:
#         gotcha_bz_ramp_duration_ignored.md.
#
#   - W3  `phi_omega` / `frequency` Hz-string resolution. Reports the
#         dimensionless number the runtime actually sees, since the
#         conversion is `ω_phys / (2π · ω_ref)` not `ω_phys / ω_ref`.
#         Memory: gotcha_waveform_frequency_convention.md.
#
#   - W4  `kind: spinor` + nonzero `rotating_frame_omega` + GPU backend.
#         Memory: gotcha_rotating_frame_omega_gpu_scalar_indexing.md.
#
# Each warning carries `kind::Symbol`, `step_index`, `severity`, message
# and a concrete suggestion. The struct serialises to JSON for the
# dashboard endpoint; `print_inspection` gives a CLI report.

export inspect_config, inspect_config_string, print_inspection
export ConfigInspection, StepInspection, ConfigWarning
export audit_loaded_data, terse_warning_line
export Check, CheckContext, register_check!, list_checks, run_checks
export default_inspector_severity

# --- Result types --------------------------------------------------------

"""
Single resolved time series sampled on `t::Vector{Float64}` with one value
column per channel. `kind` is what the runtime sees (e.g. `:zeeman_p` is
the linear-Zeeman waveform after Gauss → dimensionless conversion).
"""
struct ResolvedTrace
    kind::Symbol
    t::Vector{Float64}
    channels::Dict{Symbol, Vector{Float64}}   # e.g. :bx,:by,:bz,:q
end

"""
Per-step resolved view. `traces` is `[]` for ground_state / analyze steps
unless they carry a non-trivial Zeeman block.
"""
struct StepInspection
    index::Int
    name::String                         # "ground_state" | "dynamics" | "analyze"
    kind::Symbol                         # :split_step | :rotating_basis | :binary | :analyze
    duration::Float64                    # 0.0 for ground_state / analyze
    params_summary::Dict{String, Any}    # selected resolved scalars (rotating_frame_omega, dt, etc.)
    traces::Vector{ResolvedTrace}
end

struct ConfigWarning
    kind::Symbol
    severity::Symbol     # :error | :warn | :info
    step_index::Int      # 0 = config-level
    title::String
    message::String
    suggestion::String
    details::Dict{String, Any}
end

struct ConfigInspection
    path::String
    raw::Dict
    normalised::Dict
    steps::Vector{StepInspection}
    warnings::Vector{ConfigWarning}
end

# --- Check registry (structural lift v1.x, 2026-05-28) ------------------
#
# Each Check is a (id, default_severity, detect) triple. `detect(ctx)`
# returns a Vector{ConfigWarning} (zero or more findings). Failures are
# isolated — a buggy check produces an :info-severity self-report,
# never aborts inspection.
#
# Severity ladder (4 levels):
#   :info   informational, e.g. unit conversion happened
#   :warn   user almost certainly wants to know
#   :error  config has a clear semantic error
#   :block  WILL break at runtime — run_yaml aborts before sim
#
# Add a new check with `register_check!(Check(:id, :sev, fn))`. The
# registry is a Ref of Vector so test harnesses can swap it.

struct CheckContext
    raw::Dict                    # pre-normalize (best-effort; empty if N/A)
    normalised::Dict             # post-normalize
    parsed::Any                  # PipelineConfig, or nothing if parse failed
    atom::Any                    # resolved atom (Eu151 default)
end

struct Check
    id::Symbol
    severity::Symbol             # default; per-finding severity may override
    detect::Function             # (CheckContext) -> Vector{ConfigWarning}
end

const CHECK_REGISTRY = Ref(Check[])

"""
    register_check!(c::Check) -> Check

Add `c` to the global inspector check registry. Idempotent on `id` —
re-registering a check with the same id replaces the previous one (so
hot-reload during development keeps the registry clean).
"""
function register_check!(c::Check)
    reg = CHECK_REGISTRY[]
    for (i, existing) in enumerate(reg)
        if existing.id === c.id
            reg[i] = c
            return c
        end
    end
    push!(reg, c)
    return c
end

"""List the IDs of all registered checks (stable insertion order)."""
list_checks() = Symbol[c.id for c in CHECK_REGISTRY[]]

"""
    default_inspector_severity(kind::Symbol) -> Symbol

Severity registered for a check kind. Defaults to `:warn` when the kind
is unknown (e.g. a finding emitted before the registry was loaded).
"""
function default_inspector_severity(kind::Symbol)
    for c in CHECK_REGISTRY[]
        c.id === kind && return c.severity
    end
    return :warn
end

"""
    run_checks(ctx) -> Vector{ConfigWarning}

Run every registered check against `ctx` and concatenate findings.
A check that throws produces a self-report finding rather than crashing
the inspection.
"""
function run_checks(ctx::CheckContext)
    findings = ConfigWarning[]
    for c in CHECK_REGISTRY[]
        try
            append!(findings, c.detect(ctx))
        catch e
            push!(
                findings,
                ConfigWarning(
                    Symbol(:check_threw_, c.id), :warn, 0,
                    "Inspector check '$(c.id)' threw",
                    sprint(showerror, e),
                    "This is a bug in the check itself; please report.",
                    Dict{String, Any}("exception" => string(typeof(e))),
                ),
            )
        end
    end
    return findings
end

# --- Entry point ---------------------------------------------------------

"""
    inspect_config(path::AbstractString; n_samples::Int=256, strict::Bool=true)
        -> ConfigInspection

Load and normalise a pipeline YAML, returning the raw and post-normalize
dicts, per-step resolved waveforms, and a list of detected gotchas. Does
not run the simulator. Safe to call before any expensive setup.

`n_samples` controls how densely B(t) / q(t) / Raman are sampled across
each dynamics step (default 256).
"""
function inspect_config(path::AbstractString; n_samples::Int=256, strict::Bool=true)
    raw = YAML.load_file(String(path))
    raw isa AbstractDict || throw(ArgumentError(
        "inspect_config: $(path) did not parse to a mapping"))
    return _inspect_loaded(raw, String(path); n_samples, strict)
end

"""
    inspect_config_string(yaml::AbstractString; n_samples=256, strict=true)
        -> ConfigInspection

Same as `inspect_config` but takes a YAML literal. The `path` field of
the returned struct is `"<string>"`.
"""
function inspect_config_string(yaml::AbstractString; n_samples::Int=256, strict::Bool=true)
    raw = YAML.load(String(yaml))
    raw isa AbstractDict || throw(ArgumentError(
        "inspect_config_string: input did not parse to a mapping"))
    return _inspect_loaded(raw, "<string>"; n_samples, strict)
end

function _inspect_loaded(raw::AbstractDict, path::String;
    n_samples::Int, strict::Bool)
    raw_dict = Dict{Any, Any}(raw)            # ensure mutable
    normalised = deepcopy(raw_dict)
    warnings = ConfigWarning[]

    # Run the same normalize+validate pass as load_config.
    try
        _normalize_and_validate!(normalised; strict)
    catch e
        push!(
            warnings,
            ConfigWarning(
                :normalize_failed, :error, 0,
                "normalize_and_validate failed",
                sprint(showerror, e),
                "Fix the schema error reported above before running.",
                Dict{String, Any}("exception" => string(typeof(e))),
            ),
        )
        return ConfigInspection(path, raw_dict, normalised,
            StepInspection[], warnings)
    end

    steps, more_warnings = _inspect_pipeline(normalised;
        raw=raw_dict, n_samples, audit_only=false)
    append!(warnings, more_warnings)
    return ConfigInspection(path, raw_dict, normalised, steps, warnings)
end

# Shared inspection over an *already-normalised* dict. Used by both
# `inspect_config` (which normalises then calls this) and `audit_loaded_data`
# (the run_yaml hot path, where the run pipeline has already normalised).
function _inspect_pipeline(normalised::AbstractDict;
    raw::AbstractDict=Dict{Any, Any}(),
    n_samples::Int, audit_only::Bool)
    warnings = ConfigWarning[]
    cfg = try
        parse_pipeline(normalised)
    catch e
        push!(
            warnings,
            ConfigWarning(
                :parse_pipeline_failed, :error, 0,
                "parse_pipeline failed",
                sprint(showerror, e),
                "Fix the pipeline structure error reported above before running.",
                Dict{String, Any}("exception" => string(typeof(e))),
            ),
        )
        return StepInspection[], warnings
    end
    atom = _resolve_inspection_atom(cfg.steps, warnings)

    # Per-step traces (skipped when audit_only — saves builder cost).
    steps = StepInspection[]
    for (i, step) in enumerate(cfg.steps)
        si = _inspect_step(step, i, atom, warnings;
            n_samples=audit_only ? 0 : n_samples,
            audit_only)
        push!(steps, si)
    end

    # Run the registered check battery against the global context. Checks
    # are responsible for iterating steps as they see fit.
    ctx = CheckContext(Dict{Any, Any}(raw), Dict{Any, Any}(normalised), cfg, atom)
    append!(warnings, run_checks(ctx))

    return steps, warnings
end

"""
    audit_loaded_data(normalised; raw=Dict()) -> Vector{ConfigWarning}

Fast-path audit for `run_yaml` and similar entry points that have *already*
finished `_normalize_and_validate!` (or its piecewise equivalents). Returns
just the warnings — no trace sampling. Pass `raw` (pre-normalize snapshot)
to enable input-vs-resolved drop detection; without it that check skips.
Use this on the hot path; reserve `inspect_config` for human-facing reports.
"""
function audit_loaded_data(normalised::AbstractDict;
    raw::AbstractDict=Dict{Any, Any}())
    _, warnings = _inspect_pipeline(normalised; raw,
        n_samples=0, audit_only=true)
    return warnings
end

# --- Per-step inspection -------------------------------------------------

# Extract atom from the first step that names one. Falls back to Eu151 with
# an info-warning so the inspector still produces traces — the user can
# correct the atom and re-run if they care about absolute Gauss → dimless
# scaling.
function _resolve_inspection_atom(steps, warnings::Vector{ConfigWarning})
    for s in steps
        p = _step_params(s)
        p === nothing && continue
        if haskey(p, "atom")
            name = Symbol(string(p["atom"]))
            try
                return resolve_atom(name)
            catch
                push!(
                    warnings,
                    ConfigWarning(
                        :unknown_atom, :warn, 0,
                        "Unknown atom `$name`",
                        "Atom `$name` is not registered in ATOM_REGISTRY.",
                        "Pick a registered atom (Eu151, Rb87, etc.) or add it to atoms.jl.",
                        Dict{String, Any}("name" => string(name)),
                    ),
                )
                return resolve_atom(:Eu151)
            end
        end
    end
    push!(
        warnings,
        ConfigWarning(
            :atom_not_specified, :info, 0,
            "No `atom:` field found",
            "No step declared an atom. Using Eu151 for Gauss → dimensionless scaling in resolved traces.",
            "Set `atom: <name>` in your first ground_state step.",
            Dict{String, Any}(),
        ),
    )
    return resolve_atom(:Eu151)
end

_step_params(s::GroundStateStep) = s.params
_step_params(s::DynamicsStep) = s.params
_step_params(s::BinaryGroundStateStep) = s.params
_step_params(s::BinaryDynamicsStep) = s.params
_step_params(s::RotatingBasisGroundStateStep) = s.params
_step_params(s::RotatingBasisDynamicsStep) = s.params
_step_params(::AnalyzeStep) = nothing

_step_path(::GroundStateStep) = :split_step
_step_path(::DynamicsStep) = :split_step
_step_path(::BinaryGroundStateStep) = :binary
_step_path(::BinaryDynamicsStep) = :binary
_step_path(::RotatingBasisGroundStateStep) = :rotating_basis
_step_path(::RotatingBasisDynamicsStep) = :rotating_basis
_step_path(::AnalyzeStep) = :analyze

_step_name(::GroundStateStep) = "ground_state"
_step_name(::DynamicsStep) = "dynamics"
_step_name(::BinaryGroundStateStep) = "ground_state (binary)"
_step_name(::BinaryDynamicsStep) = "dynamics (binary)"
_step_name(::RotatingBasisGroundStateStep) = "ground_state (rotating_basis)"
_step_name(::RotatingBasisDynamicsStep) = "dynamics (rotating_basis)"
_step_name(::AnalyzeStep) = "analyze"

_is_dynamics(::DynamicsStep) = true
_is_dynamics(::BinaryDynamicsStep) = true
_is_dynamics(::RotatingBasisDynamicsStep) = true
_is_dynamics(_) = false

function _inspect_step(step::AnalyzeStep, idx::Int, _atom,
    _warnings::Vector{ConfigWarning}; n_samples::Int, audit_only::Bool=false)
    return StepInspection(idx, "analyze", :analyze, 0.0,
        Dict{String, Any}("n_analyzers" => length(step.analyzers)),
        ResolvedTrace[])
end

function _inspect_step(step, idx::Int, atom,
    warnings::Vector{ConfigWarning}; n_samples::Int, audit_only::Bool=false)
    params = _step_params(step)
    path_kind = _step_path(step)
    name = _step_name(step)

    duration = Float64(get(params, "duration", 0.0))
    summary = Dict{String, Any}(
        "duration" => duration,
        "dt" => get(params, "dt", nothing),
    )
    for key in ("rotating_frame_omega", "n_steps", "backend", "kind",
        "epsilon", "save_every", "seed_amplitude", "seed_k_cut")
        haskey(params, key) && (summary[key] = params[key])
    end

    traces = ResolvedTrace[]
    if !audit_only
        # Sampling window: ground_state uses single-point [0.0]; dynamics uses
        # [0, duration]. duration=0 → degenerate single point.
        times = if _is_dynamics(step) && duration > 0
            collect(range(0.0, duration; length=n_samples))
        else
            [0.0]
        end
        _inspect_zeeman!(traces, params, times, atom, path_kind, idx, warnings)
        _inspect_raman!(traces, params, times, duration, idx, warnings)
        _inspect_loss_lhy!(summary, params)
    end
    # Per-step gotcha detection runs via the global check registry against
    # the parsed pipeline (see _inspect_pipeline). Builder failures above
    # already populate warnings inline.

    return StepInspection(idx, name, path_kind, duration, summary, traces)
end

# --- Zeeman trace --------------------------------------------------------

function _inspect_zeeman!(traces::Vector{ResolvedTrace},
    params::AbstractDict, times::AbstractVector, atom, path_kind::Symbol,
    idx::Int, warnings::Vector{ConfigWarning})

    # ground_state nests Zeeman under `ground_state.B`; dynamics has it
    # at top level. The pipeline_runner extraction logic mirrors this.
    z_dict = if haskey(params, "B")
        params["B"]
    elseif haskey(get(params, "ground_state", Dict()), "B")
        params["ground_state"]["B"]
    else
        nothing
    end
    z_dict isa AbstractDict || return nothing

    duration = isempty(times) ? 0.0 : Float64(last(times))
    duration_for_build = duration > 0 ? duration : 1.0  # builders require a positive duration

    zeeman = try
        _build_zeeman_from_b_block(Dict{Any, Any}(z_dict),
            duration_for_build, atom, params)
    catch e
        push!(
            warnings,
            ConfigWarning(
                :zeeman_build_failed, :warn, idx,
                "Could not resolve B block",
                sprint(showerror, e),
                "Check the B block syntax for step $idx.",
                Dict{String, Any}("exception" => string(typeof(e))),
            ),
        )
        return nothing
    end

    bx_vals = Float64[]
    by_vals = Float64[]
    bz_vals = Float64[]
    q_vals = Float64[]
    for t in times
        push!(bz_vals, linear_p(zeeman, t))
        push!(q_vals, quadratic_q(zeeman, t))
        (bx, by) = transverse_b(zeeman, t)
        push!(bx_vals, bx)
        push!(by_vals, by)
    end
    push!(
        traces,
        ResolvedTrace(:zeeman,
            collect(Float64, times),
            Dict{Symbol, Vector{Float64}}(
                :bx => bx_vals, :by => by_vals, :bz => bz_vals, :q => q_vals
            )),
    )
    return nothing
end

# --- Raman trace ---------------------------------------------------------

function _inspect_raman!(traces::Vector{ResolvedTrace},
    params::AbstractDict, times::AbstractVector, duration::Float64,
    idx::Int, warnings::Vector{ConfigWarning})
    haskey(params, "raman") || return nothing
    duration_for_build = duration > 0 ? duration : 1.0
    raman = try
        _build_raman(Dict{String, Any}(params), duration_for_build)
    catch e
        push!(
            warnings,
            ConfigWarning(
                :raman_build_failed, :warn, idx,
                "Could not resolve Raman block",
                sprint(showerror, e),
                "Check the raman block syntax for step $idx.",
                Dict{String, Any}("exception" => string(typeof(e))),
            ),
        )
        return nothing
    end
    raman === nothing && return nothing

    omega_vals = Float64[]
    delta_vals = Float64[]
    if raman isa RamanCoupling
        for _ in times
            push!(omega_vals, raman.Omega_R)
            push!(delta_vals, raman.delta)
        end
    else
        for t in times
            push!(omega_vals, evaluate(raman.omega_wf, t))
            push!(delta_vals, evaluate(raman.delta_wf, t))
        end
    end
    push!(
        traces,
        ResolvedTrace(:raman,
            collect(Float64, times),
            Dict{Symbol, Vector{Float64}}(
                :Omega_R => omega_vals, :delta => delta_vals
            )),
    )
    return nothing
end

# --- Loss / LHY summary --------------------------------------------------

function _inspect_loss_lhy!(summary::Dict{String, Any}, params::AbstractDict)
    if haskey(params, "loss")
        summary["loss"] = params["loss"]
    end
    if haskey(params, "lhy")
        summary["lhy"] = params["lhy"]
    end
    return nothing
end

# --- Structural Check classes (2026-05-28 reactive→structural lift) ----

# Helper: iterate parsed pipeline steps producing (idx, step, params, kind).
function _walk_steps(ctx::CheckContext)
    ctx.parsed === nothing && return Tuple{Int, Any, Dict, Symbol}[]
    return [
        (i, step, _step_params(step) === nothing ? Dict{String, Any}() :
                  _step_params(step), _step_path(step))
        for (i, step) in enumerate(ctx.parsed.steps)
    ]
end

# === A. Input-vs-resolved key drop =====================================
#
# Diff the user-written (raw) dict against the post-normalize dict.
# Keys present in raw but absent in normalised → drop candidate. Each
# drop is filtered through an allowlist: rules that say "drop X if Y"
# encode legitimate normalize-step transformations (B-block split,
# template expansion, calibration pop, etc.).
#
# A key drop not covered by the allowlist becomes a finding. The
# specific instance (e.g. theta on split-step) lives in the title/
# details; the structural kind is :input_resolved_drop. This subsumes
# the old W1 and catches future drops without code changes.

"""
Allowlist entry: `key_suffix` is the trailing dotted-path segment(s) to
match (e.g. `"B.theta"`, `"calibration"`). `predicate` is called with
(raw_dict, normalised_dict, path) and returns true when the drop is
legitimate. nothing predicate = unconditional allow.
"""
struct DropRule
    key_suffix::String
    predicate::Union{Nothing, Function}
    reason::String
end

const DROP_ALLOWLIST = DropRule[
    DropRule("metadata", nothing, "purely informational, popped by schema"),
    DropRule("defaults", nothing, "seeded into each step, then removed"),
    DropRule("calibration", nothing, "popped after applying to lab units"),
    DropRule("calibration_history", nothing, "popped after interpolation"),
    DropRule("target_date", nothing, "consumed by calibration interpolation"),
    DropRule("dealias", nothing, "popped, applied via global Ref"),
    DropRule("use", nothing, "template/mixin reference"),
    DropRule("mixins", nothing, "template/mixin reference"),
    # B-block split: theta/phi may legitimately move to B_direction when
    # the step's downstream path is rotating_basis. The drop is REAL on
    # split_step / binary — that is the bug we want to catch. See the
    # split_step branch in the predicate below.
    DropRule("B.theta",
        (raw, norm, path) -> _b_theta_phi_drop_ok(raw, norm, path),
        "rerouted to B_direction.theta for rotating_basis steps"),
    DropRule("B.phi",
        (raw, norm, path) -> _b_theta_phi_drop_ok(raw, norm, path),
        "rerouted to B_direction.phi for rotating_basis steps"),
]

# Returns true when a `B.theta` or `B.phi` drop is benign — either
# rerouted to `B_direction` on the rotating_basis path, or trimmed by
# `_split_B_block!` because the value was exactly 0 on a Cartesian B.
# Path looks like `["pipeline", i, "dynamics", "B", "theta"]`.
function _b_theta_phi_drop_ok(raw::AbstractDict, norm::AbstractDict,
    path::DiffPath)
    length(path) >= 4 || return false
    path[1] == "pipeline" || return false
    pipe_norm = norm["pipeline"]
    pipe_norm isa AbstractVector || return false
    step_idx = path[2]
    step_idx isa Int || return false
    step_idx in 1:length(pipe_norm) || return false
    step_norm = pipe_norm[step_idx]
    step_norm isa AbstractDict && length(step_norm) == 1 || return false
    inner_norm = first(values(step_norm))
    inner_norm isa AbstractDict || return false

    # Case (a): rotating_basis / option_gamma steps consume the radian
    # `B.theta` / `B.phi` keys through `B_direction`.
    kind = lowercase(string(get(inner_norm, "kind", "")))
    if kind in ("rotating_basis", "option_gamma")
        return true
    end

    # Case (b): user wrote `theta: 0` / `phi: 0` (semantically a no-op
    # regardless of routing — direction stays along +ẑ). The normalizer
    # may delete it (Cartesian B) or move it to B_direction (spherical
    # B), but the physics is unchanged. Treat as benign.
    pipe_raw = raw["pipeline"]
    pipe_raw isa AbstractVector && length(pipe_raw) >= step_idx || return false
    step_raw = pipe_raw[step_idx]
    step_raw isa AbstractDict || return false
    inner_raw = first(values(step_raw))
    inner_raw isa AbstractDict || return false
    b_raw = get(inner_raw, "B", nothing)
    b_raw isa AbstractDict || return false
    direction_key = string(path[end])      # "theta" or "phi"
    v_raw = get(b_raw, direction_key, nothing)
    return v_raw isa Real && v_raw == 0
end

function _check_input_resolved_drop(ctx::CheckContext)
    findings = ConfigWarning[]
    isempty(ctx.raw) && return findings    # audit hot path may not pass raw
    d = diff_dicts(ctx.raw, ctx.normalised)
    for entry in d.removed
        path_str = path_string(entry.path)
        # Match against allowlist suffix
        legitimate = false
        for rule in DROP_ALLOWLIST
            endswith(path_str, rule.key_suffix) || continue
            if rule.predicate === nothing ||
                rule.predicate(ctx.raw, ctx.normalised, entry.path)
                legitimate = true
                break
            end
        end
        legitimate && continue

        step_idx = _step_index_from_path(entry.path)
        push!(
            findings,
            ConfigWarning(
                :input_resolved_drop, :warn, step_idx,
                "Input key not present after normalize: `$(path_str)`",
                "You wrote `$(path_str) = $(repr(entry.before))`, but the " *
                "post-normalize config no longer carries this key. It may " *
                "have been silently dropped by a parser, or rerouted to a " *
                "key not consumed by your step's runtime path.",
                "Verify the key is spelled correctly and belongs in this " *
                "block. If it should be consumed elsewhere, check the " *
                "DROP_ALLOWLIST in inspect.jl.",
                Dict{String, Any}(
                    "path" => path_str,
                    "value" => entry.before,
                ),
            ),
        )
    end
    return findings
end

# Extract step index from a pipeline path like ["pipeline", N, ...].
function _step_index_from_path(path::DiffPath)
    length(path) >= 2 || return 0
    path[1] == "pipeline" || return 0
    path[2] isa Int || return 0
    return path[2]
end

# === B. Boundary value linter ==========================================
#
# Walk dynamics step params for numeric fields whose 0 / negative values
# carry special semantics (instantaneous quench) or signal a bug
# (zero dt, zero n_steps). Table-driven — new fields = one row.

struct BoundaryRule
    field_path::String        # dotted path under the step, e.g. "duration"
    zero_meaning::Symbol      # :quench | :error | :degenerate | :info
    title::String
    suggestion::String
end

const BOUNDARY_RULES = BoundaryRule[
    BoundaryRule("dt", :error,
        "dt = 0 (or negative)",
        "Set dt > 0; this would divide-by-zero or stall the integrator."),
    BoundaryRule("n_steps", :error,
        "n_steps ≤ 0",
        "Set n_steps to a positive integer."),
    BoundaryRule("tol", :error,
        "tol ≤ 0",
        "Set tol > 0 (typical: 1e-8 to 1e-10)."),
    BoundaryRule("duration", :degenerate,
        "duration ≤ 0 for dynamics step",
        "A dynamics step with duration ≤ 0 produces a degenerate run; " *
        "remove the step or set duration > 0."),
]

function _check_boundary_values(ctx::CheckContext)
    findings = ConfigWarning[]
    for (idx, step, params, _kind) in _walk_steps(ctx)
        step isa AnalyzeStep && continue
        for rule in BOUNDARY_RULES
            v = get(params, rule.field_path, nothing)
            v === nothing && continue
            v isa Real || continue
            Float64(v) > 0 && continue
            # duration=0 on a dynamics step is degenerate (no time
            # window); but the ramp shorthand {from,to,duration:0}
            # is a different thing entirely — that lives inside a
            # waveform spec, handled by the ramp-detector below.
            sev = rule.zero_meaning === :error ? :block : :warn
            push!(
                findings,
                ConfigWarning(
                    :boundary_value, sev, idx,
                    rule.title,
                    "Step $(idx) `$(rule.field_path)` = $(v).",
                    rule.suggestion,
                    Dict{String, Any}(
                        "field" => rule.field_path,
                        "value" => v,
                    ),
                ),
            )
        end

        # Ramp shorthand: {from, to, duration ≤ 0} → ConstantWaveform(to).
        # Walk nested dicts looking for the ramp pattern.
        _walk_ramps!(findings, params, idx, "")
    end
    return findings
end

function _walk_ramps!(findings::Vector{ConfigWarning}, node, idx::Int,
    prefix::String)
    node isa AbstractDict || return nothing
    for (k, v) in node
        v isa AbstractDict || continue
        sub_path = isempty(prefix) ? string(k) : "$(prefix).$(k)"
        if haskey(v, "from") && haskey(v, "duration")
            dur = v["duration"]
            if dur isa Real && Float64(dur) <= 0.0
                push!(
                    findings,
                    ConfigWarning(
                        :boundary_value, :info, idx,
                        "Ramp collapsed to instantaneous jump",
                        "$(sub_path): `{from: $(get(v, "from", "?")), " *
                        "to: $(get(v, "to", "?")), duration: $dur}` is " *
                        "parsed as `ConstantWaveform(to)`.",
                        "If you intended a ramp, set `duration: <positive>`. " *
                        "If you intended a quench, this is now correct.",
                        Dict{String, Any}(
                            "field" => sub_path,
                            "from" => get(v, "from", nothing),
                            "to" => get(v, "to", nothing),
                            "duration" => dur,
                        ),
                    ),
                )
            end
        end
        _walk_ramps!(findings, v, idx, sub_path)
    end
    return nothing
end

# === C. Unit conversion audit ==========================================
#
# Surface every unit-bearing string the runtime will reinterpret. The
# user can confirm the dimensionless value matches their intent. Each
# entry has (regex on raw value, conversion rule label).

struct UnitRule
    pattern::Regex
    label::String           # e.g. "Hz → dimensionless ω/ω_ref"
    explanation::String     # exact conversion formula
end

const UNIT_RULES = UnitRule[
    UnitRule(r"\bHz\b"i, "Hz → dimensionless",
        "Converted as ω_phys / (2π · ω_ref). Note the 2π — the 2026 " *
        "magnetostir gotcha was a missing factor of 2π here."),
    UnitRule(r"\bGauss\b|\b[mu]?G\b"i, "Gauss → dimensionless",
        "Converted as g_F · μ_B · B[T] / (ℏ · ω_ref)."),
    UnitRule(r"\b[mun]?s\b"i, "time-string → dimensionless",
        "Multiplied by ω_ref."),
    UnitRule(r"\b[mc]?V\b"i, "mV (coil setpoint) → Gauss",
        "Resolved via calibration block; if absent, treated as raw mV."),
]

function _check_unit_audit(ctx::CheckContext)
    findings = ConfigWarning[]
    for (idx, _step, params, _kind) in _walk_steps(ctx)
        _walk_unit_strings!(findings, params, idx, "")
    end
    # Auto-derived q(t) from Breit-Rabi — surface as info because the
    # user did not write it and may not realise it varies with B(t)².
    for (idx, step, params, kind) in _walk_steps(ctx)
        step isa AnalyzeStep && continue
        b_block = get(params, "B", nothing)
        b_block isa AbstractDict || continue
        if !haskey(b_block, "q")
            # auto-derive will fire when atom has hyperfine data and B is set.
            push!(
                findings,
                ConfigWarning(
                    :unit_conversion, :info, idx,
                    "q (quadratic Zeeman) auto-derived from B(t)²",
                    "Step $(idx) has no `q:` in its B block. q(t) is " *
                    "auto-derived via Breit-Rabi from the resolved B(t); " *
                    "for ramping B this means q ramps quadratically.",
                    "Inspect the resolved zeeman.q trace to confirm the " *
                    "implicit ramp matches your intent.",
                    Dict{String, Any}("step" => idx),
                ),
            )
        end
    end
    return findings
end

function _walk_unit_strings!(findings::Vector{ConfigWarning},
    node, idx::Int, prefix::String)
    if node isa AbstractDict
        for (k, v) in node
            sub = isempty(prefix) ? string(k) : "$(prefix).$(k)"
            _walk_unit_strings!(findings, v, idx, sub)
        end
    elseif node isa AbstractVector
        for (i, v) in enumerate(node)
            _walk_unit_strings!(findings, v, idx, "$(prefix)[$(i)]")
        end
    elseif node isa AbstractString
        for rule in UNIT_RULES
            occursin(rule.pattern, node) || continue
            push!(
                findings,
                ConfigWarning(
                    :unit_conversion, :info, idx,
                    "$(rule.label): `$(prefix)` = $(repr(node))",
                    rule.explanation,
                    "Compare the dimensionless value in the resolved trace.",
                    Dict{String, Any}(
                        "field" => prefix,
                        "raw" => node,
                        "rule" => rule.label,
                    ),
                ),
            )
            break    # one rule fires per string
        end
    end
    return nothing
end

# === D. Feature compatibility matrix ===================================
#
# Table of known incompatible-or-silent combinations. Each entry is a
# predicate over a step's (params, kind) plus a severity + message.
# New gotcha = one row in the table, no code.

struct CompatRule
    id::Symbol
    severity::Symbol
    title::String
    predicate::Function       # (params::Dict, kind::Symbol) -> Bool
    message::String
    suggestion::String
end

function _compat_rotating_omega_spinor_gpu(params, kind)
    kind === :split_step || return false
    rfo = get(params, "rotating_frame_omega", 0)
    rfo isa Real && rfo != 0 || return false
    backend = lowercase(string(get(params, "backend", "")))
    return backend in ("gpu", "cuda")
end

function _compat_polar_two_channel_lhy(params, _kind)
    lhy = get(params, "lhy", nothing)
    lhy isa AbstractDict || return false
    return string(get(lhy, "kind", "")) == "polar_two_channel"
end

function _compat_full_bdg_f6_polar(params, _kind)
    lhy = get(params, "lhy", nothing)
    lhy isa AbstractDict || return false
    return string(get(lhy, "kind", "")) == "full_bdg"
end

function _compat_spin_rotating_omega_secular(params, _kind)
    srfo = get(params, "spin_rotating_frame_omega", 0)
    srfo isa Real && srfo != 0 || return false
    ddi = get(params, "ddi", nothing)
    ddi isa AbstractDict || return false
    return !get(ddi, "secular", false)
end

const COMPAT_TABLE = CompatRule[
    CompatRule(
        :rotating_omega_spinor_gpu, :block,
        "rotating_frame_omega + spinor + GPU will crash",
        _compat_rotating_omega_spinor_gpu,
        "`_apply_1d_shear_batch!` (the Coriolis term) scalar-indexes " *
        "GPU arrays. This will throw at runtime, after `make_workspace` " *
        "has already paid its precompile cost.",
        "Force `backend: cpu` on this step, or move to the rotating_basis " *
        "path which has a GPU-compatible shear.",
    ),
    CompatRule(
        :polar_two_channel_lhy_high_F, :warn,
        "PolarTwoChannelLHY: polar-only, off by 30-70% at F=6",
        _compat_polar_two_channel_lhy,
        "The two-channel reduction is exact at F=1, ~1% off at F=2, " *
        "and 30-70% off at F=6 polar (pinned by test_spinor_lhy.jl).",
        "For F=6 polar prefer PolarContactLHY / PolarDipolarLHY; for " *
        "FM use FMContactLHY / FMDipolarLHY; F=6 icosahedral uses " *
        "IcosahedralLHY. Polar at F=2 is fine.",
    ),
    CompatRule(
        :full_bdg_f6_polar, :warn,
        "FullBdGLHY at F=6 polar emits ~3000× spurious offset",
        _compat_full_bdg_f6_polar,
        "Memory: full_bdg_F6_polar_broken.md. Runtime emits a @warn " *
        "but the magnitude is large enough to render results unusable.",
        "Use PolarContactLHY / PolarDipolarLHY at F=6 polar instead.",
    ),
    CompatRule(
        :spin_rotating_omega_secular_required, :error,
        "spin_rotating_frame_omega ≠ 0 requires secular_ddi=true",
        _compat_spin_rotating_omega_secular,
        "Full DDI's off-diagonal components only Larmor-average to zero " *
        "in the secular limit (CLAUDE.md `# Constraints`). make_workspace " *
        "throws ArgumentError when this combination is requested.",
        "Set `ddi: {secular: true}` on this step.",
    ),
]

function _check_feature_compat(ctx::CheckContext)
    findings = ConfigWarning[]
    for (idx, _step, params, kind) in _walk_steps(ctx)
        for rule in COMPAT_TABLE
            rule.predicate(params, kind) || continue
            push!(
                findings,
                ConfigWarning(
                    :feature_incompat, rule.severity, idx,
                    rule.title,
                    "Step $(idx): $(rule.message)",
                    rule.suggestion,
                    Dict{String, Any}(
                        "rule_id" => string(rule.id)
                    ),
                ),
            )
        end
    end
    return findings
end

# Register the 4 structural checks at module load. Order = display
# order in CLI / dashboard reports.
register_check!(Check(:input_resolved_drop, :warn, _check_input_resolved_drop))
register_check!(Check(:boundary_value, :warn, _check_boundary_values))
register_check!(Check(:unit_conversion, :info, _check_unit_audit))
register_check!(Check(:feature_incompat, :block, _check_feature_compat))

# --- CLI report ---------------------------------------------------------

const _SEV_PREFIX = Dict(
    :error => "ERROR",
    :warn => "WARN ",
    :info => "INFO ",
)

"""
    print_inspection(io::IO, ins::ConfigInspection)
    print_inspection(ins::ConfigInspection)   # → stdout

Render a terse pre-run summary suitable for terminal use. Lists warnings
first (most severe → least), then per-step resolved scalars + trace
endpoints. Does not print full traces; use the dashboard for that.
"""
print_inspection(ins::ConfigInspection) = print_inspection(stdout, ins)

function print_inspection(io::IO, ins::ConfigInspection)
    println(io, "inspect_config  ", ins.path)
    println(io, "=" ^ 70)

    if isempty(ins.warnings)
        println(io, "  (no warnings)")
    else
        # Sort error → warn → info; stable on step_index.
        sev_rank = Dict(:error => 0, :warn => 1, :info => 2)
        sorted = sort(ins.warnings;
            by=w -> (sev_rank[w.severity], w.step_index))
        for w in sorted
            prefix = get(_SEV_PREFIX, w.severity, "?    ")
            tag = w.step_index == 0 ? "[config]" : "[step $(w.step_index)]"
            println(io, "  $prefix $tag $(w.title)")
            for line in split(w.message, '\n')
                println(io, "         $line")
            end
            if !isempty(w.suggestion)
                println(io, "      → $(w.suggestion)")
            end
            println(io)
        end
    end

    println(io, "Steps")
    println(io, "-" ^ 70)
    for s in ins.steps
        dur = s.duration > 0 ? @sprintf("%.4g", s.duration) : "—"
        println(io, "  #$(s.index)  $(s.name)  ($(s.kind), duration = $dur)")
        for (k, v) in s.params_summary
            k == "duration" && continue
            v === nothing && continue
            println(io, "        $k = $v")
        end
        for tr in s.traces
            n = length(tr.t)
            t0 = isempty(tr.t) ? 0.0 : first(tr.t)
            t1 = isempty(tr.t) ? 0.0 : last(tr.t)
            println(
                io,
                "        trace $(tr.kind)  " *
                "$(n) samples on t ∈ [$(round(t0; digits=4)), " *
                "$(round(t1; digits=4))]",
            )
            for (cn, vals) in tr.channels
                isempty(vals) && continue
                vmin = minimum(vals)
                vmax = maximum(vals)
                v0 = first(vals)
                v1 = last(vals)
                println(
                    io,
                    @sprintf("          %-8s  start=%+.4g  end=%+.4g  min=%+.4g  max=%+.4g",
                        string(cn), v0, v1, vmin, vmax)
                )
            end
        end
    end
    return nothing
end

# --- JSON serialisation -------------------------------------------------

"""
    to_dict(ins::ConfigInspection) -> Dict

Plain-Dict view suitable for JSON3.write. Float arrays stay as Vector{Float64}.
"""
function to_dict(ins::ConfigInspection)
    Dict{String, Any}(
        "path" => ins.path,
        "raw" => ins.raw,
        "normalised" => ins.normalised,
        "warnings" => [_warning_dict(w) for w in ins.warnings],
        "steps" => [_step_dict(s) for s in ins.steps],
    )
end

function _warning_dict(w::ConfigWarning)
    Dict{String, Any}(
        "kind" => string(w.kind),
        "severity" => string(w.severity),
        "step_index" => w.step_index,
        "title" => w.title,
        "message" => w.message,
        "suggestion" => w.suggestion,
        "details" => w.details,
    )
end

function _step_dict(s::StepInspection)
    Dict{String, Any}(
        "index" => s.index,
        "name" => s.name,
        "kind" => string(s.kind),
        "duration" => s.duration,
        "params_summary" => s.params_summary,
        "traces" => [_trace_dict(t) for t in s.traces],
    )
end

function _trace_dict(t::ResolvedTrace)
    Dict{String, Any}(
        "kind" => string(t.kind),
        "t" => t.t,
        "channels" => Dict{String, Vector{Float64}}(
            string(k) => v for (k, v) in t.channels),
    )
end

# --- Terse one-line formatter (used by the run_yaml audit hook) ---------

"""
    terse_warning_line(w::ConfigWarning) -> String

Format `w` as a single line suitable for stderr in the middle of a
verbose run. Severity tag + step + kind + title only — no message body,
no suggestion. `print_inspection` is the verbose counterpart for CLI
and dashboard use.
"""
function terse_warning_line(w::ConfigWarning)
    sev = uppercase(string(w.severity))
    tag = w.step_index == 0 ? "config" : "step $(w.step_index)"
    "[audit] $sev [$tag] $(w.kind): $(w.title)"
end
