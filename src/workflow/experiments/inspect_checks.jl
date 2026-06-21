# Structural config checks (the concrete A/B/C/D check classes) + their
# registration into CHECK_REGISTRY. The check *framework* (CheckContext,
# Check, register_check!, run_checks) lives in inspect.jl; this file holds
# the rules:
#   A. input-vs-resolved key drop   B. boundary-value linter
#   C. unit-conversion audit        D. feature-compatibility matrix
# Included immediately after inspect.jl so the register_check! calls at the
# bottom populate the registry once at load.

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
