# --- YAML `dealias:` top-level block ---
#
# Auto-applies pseudospectral dealiasing settings before run_pipeline,
# avoiding hand-set Julia-side `SpinorBEC.DEALIAS_2_3_ENABLED[] = ...`
# in every driver script.
#
# YAML syntax (top-level):
#
#   dealias:
#     enabled: true        # toggle Orszag 2/3 filter on ψ + F (default false)
#     k_cut: 16.0          # OPTIONAL fixed physical-k cutoff (default: per-axis n/3)
#     auto_dt: true        # OPTIONAL: auto-set dt ≤ dt_max_for_k_cut(k_cut) on
#                          # every dynamics step that has dt above the bound
#     dt_safety: 10.0      # OPTIONAL: safety factor for dt_max_for_k_cut (default 10)
#
# Use cases:
#   - production single-grid run: just set `enabled: true`. Default
#     per-axis n/3 cutoff at the grid's Nyquist is fine.
#   - cross-grid convergence study (verification, paper comparison):
#     also set `k_cut: <fixed>` so every grid captures the same bandwidth.
#   - want auto-dt: add `auto_dt: true`; the runner walks the pipeline
#     and tightens any dynamics step's dt to the recommended bound.

export apply_dealias_block!

"""
Pending snapshot (was_enabled, was_k_cut) of the dealias Refs from the
most recent `apply_dealias_block!` call. `_run_yaml_execute` reads
this in a `finally` block to restore prior state and prevent leakage
across runs in the same Julia session.

Module-level Ref because the snapshot CANNOT be stashed inside the YAML
`data::Dict` — strict schema validation (validate_pipeline!) walks all
top-level keys and rejects unknown ones, so any `_dealias_snapshot`
sentinel placed there triggers ArgumentError before the execute phase
runs.
"""
const _DEALIAS_PENDING_SNAPSHOT = Ref{Union{Nothing, Tuple{Bool, Union{Nothing, Float64}}}}(nothing)

"""
    apply_dealias_block!(data::Dict) -> (was_enabled, was_k_cut)

If `data["dealias"]` is present, pop it, set the global filter Refs,
and (if `auto_dt`) override dt in every dynamics step that has dt
above the recommended bound. Returns the previous Ref values so the
caller can restore them in a `finally`.

Schema-friendly: pops the key from `data` so downstream
`validate_pipeline!` (strict=true) does not flag it as unknown.
"""
function apply_dealias_block!(data::Dict)
    # Snapshot current state (caller will restore)
    was_enabled = DEALIAS_2_3_ENABLED[]
    was_k_cut = DEALIAS_K_CUTOFF[]

    haskey(data, "dealias") || return (was_enabled, was_k_cut)
    block = pop!(data, "dealias")
    block isa Dict || throw(ArgumentError(
        "YAML `dealias:` block must be a mapping; got $(typeof(block))"))

    enabled = Bool(get(block, "enabled", false))
    DEALIAS_2_3_ENABLED[] = enabled

    if haskey(block, "k_cut") && block["k_cut"] !== nothing
        k_cut = Float64(block["k_cut"])
        k_cut > 0 || throw(ArgumentError(
            "dealias.k_cut must be positive, got $k_cut"))
        DEALIAS_K_CUTOFF[] = k_cut
    else
        DEALIAS_K_CUTOFF[] = nothing
    end

    if get(block, "auto_dt", false) == true
        # When k_cut is set we have a clear bound; when k_cut === nothing
        # the per-axis (n/3) default applies and the bound is grid-dependent
        # — we cannot tighten dt without walking each step's grid. Skip in
        # that case (user can set dt manually).
        if DEALIAS_K_CUTOFF[] !== nothing
            safety = Float64(get(block, "dt_safety", 10.0))
            dt_bound = dt_max_for_k_cut(DEALIAS_K_CUTOFF[]; safety)
            _tighten_dt_in_pipeline!(data, dt_bound)
        end
    end

    # Validate unknown keys
    known = ("enabled", "k_cut", "auto_dt", "dt_safety")
    for k in keys(block)
        k in known || throw(ArgumentError(
            "Unknown key `dealias.$k`. Allowed: $(join(known, ", "))"))
    end

    (was_enabled, was_k_cut)
end

"""
    restore_dealias_refs!(was_enabled, was_k_cut)

Restore the global dealias Refs to a snapshot. Use in `finally` so
multi-config sessions do not leak state between runs.
"""
function restore_dealias_refs!(was_enabled::Bool, was_k_cut::Union{Nothing, Float64})
    DEALIAS_2_3_ENABLED[] = was_enabled
    DEALIAS_K_CUTOFF[] = was_k_cut
    nothing
end

"""
Walk `data["pipeline"]` for `dynamics` steps and clamp `dt` to
`dt_bound` if the configured `dt` exceeds it. Other step types
(ground_state, analyze, …) are skipped.
"""
function _tighten_dt_in_pipeline!(data::Dict, dt_bound::Float64)
    haskey(data, "pipeline") || return nothing
    pl = data["pipeline"]
    pl isa AbstractVector || return nothing
    for step in pl
        step isa Dict || continue
        for (key, body) in step
            key in ("dynamics", "rotating_basis_dynamics") || continue
            body isa Dict || continue
            if haskey(body, "dt") && body["dt"] isa Real && body["dt"] > dt_bound
                @info "dealias.auto_dt: tightening $key.dt $(body["dt"]) → $(dt_bound) " *
                    "(bound from k_cut=$(DEALIAS_K_CUTOFF[]))"
                body["dt"] = dt_bound
            end
        end
    end
    nothing
end
