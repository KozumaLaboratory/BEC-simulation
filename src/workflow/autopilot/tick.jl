# ── Autopilot tick ────────────────────────────────────────────────────
#
# Single tick of the meta-loop. Stateless: all state lives in
# `runs/<cid>/state.toml`. Resilient to mid-tick crashes — the next tick
# inspects the filesystem and recovers.
#
# 2-stage submit pattern (crash-safe):
#   (a) mark entry status=:running, job_id=nothing, fsync
#   (b) call backend.dispatch! → real job_id
#   (c) save_entry! with job_id
# If a crash occurs between (a) and (c), the next tick sees status=:running
# with job_id=nothing and reconciles via `squeue --name=<content_id>`.

export autopilot_tick!, default_autopilot_config, is_autopilot_paused

# Sentinel file that pauses dispatch. Touch this to halt new submissions;
# remove to resume. `drain` is just "touch + wait for running to drain".
_pause_file(qr::QueueRoot) = joinpath(qr.path, ".autopilot.paused")
is_autopilot_paused(qr::QueueRoot=autopilot_queue_root()) = isfile(_pause_file(qr))

default_autopilot_config(; kwargs...) = AutopilotConfig(;
    backend=LocalBackend(),
    qr=autopilot_queue_root(),
    kwargs...,
)

"""
    autopilot_tick!(; config=default_autopilot_config()) -> AutopilotStats

One tick. Reconciles inconsistent states, dispatches pending, reaps
running, fires on_complete. Holds the autopilot lockfile for the duration.
"""
function autopilot_tick!(; config::AutopilotConfig=default_autopilot_config())
    stats = AutopilotStats()
    return with_autopilot_lock(; qr=config.qr) do
        _autopilot_tick_body!(config, stats)
        stats
    end
end

function _autopilot_tick_body!(config::AutopilotConfig, stats::AutopilotStats)
    pending = list_queue(:pending; qr=config.qr)
    running = list_queue(:running; qr=config.qr)
    stats.n_pending = length(pending)
    stats.n_running = length(running)

    # 0. Reconcile mid-submit zombies: status=:running but job_id=nothing.
    #    Lookup by job-name (= content_id prefix) on the backend; recover
    #    or reset.
    for entry in running
        entry.job_id === nothing || continue
        recovered = _reconcile_zombie!(config.backend, entry)
        if recovered === :recovered_running
            # job_id now set on entry; save below by reap loop
        elseif recovered === :reset_to_pending
            # rolled back
        elseif recovered === :gave_up
            set_status!(entry, :killed_bug;
                kill_reason="autopilot: cannot find job by name after mid-submit crash")
            stats.failed += 1
        end
    end

    # 1. Dispatch pending → running ────────────────────────────────────
    paused = is_autopilot_paused(config.qr)
    # Budget gate is consulted once per tick; if quarter or daily cap
    # would be exceeded, skip the entire dispatch loop. Realized hours
    # are refreshed before the decision so it sees newly-terminal work.
    budget_decision = if config.respect_budget && !paused
        refresh_budget!(; qr=config.qr)
        budget_gate(; qr=config.qr)
    else
        nothing
    end
    dispatched = 0
    if !paused && (budget_decision === nothing || budget_decision.allow)
        for entry in pending
            dispatched >= config.max_dispatches_per_tick && break

            # Autonomy gate: :suggest / :propose recipes never dispatch
            # (autopilot only records the suggestion).
            if entry.autonomy_level !== :dispatch
                continue
            end

            # Pre-flight inspector with explicit 4-level severity mapping:
            #   :block → killed_bug (don't dispatch)
            #   :error → dispatch but record findings on entry
            #   :warn  → dispatch + Slack notify
            #   :info  → silent
            if config.inspect_before_dispatch
                pre = _inspector_preflight(entry)
                if pre.blocked !== nothing
                    set_status!(entry, :killed_bug;
                        kill_reason="inspector blocked: $(pre.blocked)")
                    stats.inspected_blocked += 1
                    continue
                end
                if !isempty(pre.error_kinds) || !isempty(pre.warn_kinds)
                    entry.recipe_params["_inspector_findings"] = Dict{String, Any}(
                        "error_kinds" => pre.error_kinds,
                        "warn_kinds" => pre.warn_kinds,
                    )
                    save_entry!(entry)
                end
                if !isempty(pre.warn_kinds) && config.notify_slack_on_failure
                    try
                        notify_slack(
                            "[autopilot] pre-flight :warn on " *
                            "$(entry.content_id): $(join(pre.warn_kinds, ", "))",
                        )
                    catch err
                        @warn "notify_slack threw" exception=err
                    end
                end
            end

            if config.dry_run
                _dry_run_dispatch!(entry)
                stats.dispatched += 1
                dispatched += 1
                continue
            end
            ok = _dispatch_one!(config.backend, entry)
            if !ok
                break    # backend full or transient error; try next tick
            end
            stats.dispatched += 1
            dispatched += 1
        end
    end

    # 2. Reap running → done / killed_data / killed_bug ──────────────
    for entry in list_queue(:running; qr=config.qr)   # re-list to pick up reconciliations
        entry.job_id === nothing && continue   # still mid-submit (other process?)
        status = job_status(config.backend, entry)
        if status === :done
            _terminal_classify!(entry, :done; reason="completed")
            stats.completed += 1
            _maybe_fire_on_complete!(entry, config, stats)
        elseif status === :failed
            # SLURM said failed. Look at outcome.toml + sacct to decide
            # killed_data vs killed_bug (OOM is resource-permanent and
            # classified as killed_bug; divergence is killed_data).
            terminal, reason = _classify_terminal_failure(entry, config.backend)
            _terminal_classify!(entry, terminal; reason=reason)
            stats.failed += 1
            if config.notify_slack_on_failure
                try
                    notify_slack("[autopilot] $(entry.content_id) → $(terminal): $(reason)")
                catch err
                    ;
                    @warn "notify_slack threw" exception=err
                end
            end
        elseif status === :running || status === :pending
            # Still in flight; check for divergence kill.
            if _is_divergent(entry)
                @info "kill-divergent" cid=entry.content_id job=entry.job_id
                try
                    cancel!(config.backend, entry)
                catch
                end
                set_status!(entry, :killed_data;
                    kill_reason="divergent ($(string(_divergence_metric(entry))))")
                stats.killed_divergent += 1
            end
        else
            # :unknown — backend lost track; leave for next tick
        end
    end
    return nothing
end

# ── helpers ──────────────────────────────────────────────────────────

function _inspect_blocks(entry::QueueEntry)::Union{Nothing, String}
    # Backward-compat shim: returns the first :block finding or nothing.
    # New call sites should use `_inspector_preflight` for the full
    # severity breakdown.
    p = _inspector_preflight(entry)
    return p.blocked
end

"""
    _inspector_preflight(entry) -> (blocked, error_kinds, warn_kinds, info_kinds)

Run `inspect_config` on `entry.spec_path` and partition findings by
severity. Returns a NamedTuple consumed by the dispatch loop's
inspector seam (`block` → killed_bug, `error` → recorded on entry,
`warn` → Slack notify, `info` → ignored).
"""
function _inspector_preflight(entry::QueueEntry)
    blocked = nothing
    error_kinds = String[]
    warn_kinds = String[]
    info_kinds = String[]
    try
        ins = inspect_config(entry.spec_path)
        for w in ins.warnings
            if w.severity === :block && blocked === nothing
                blocked = "$(w.kind): $(w.title)"
            elseif w.severity === :error
                push!(error_kinds, String(w.kind))
            elseif w.severity === :warn
                push!(warn_kinds, String(w.kind))
            elseif w.severity === :info
                push!(info_kinds, String(w.kind))
            end
        end
    catch err
        blocked = "inspector threw: $(typeof(err).name.name)"
    end
    return (blocked=blocked,
        error_kinds=unique(error_kinds),
        warn_kinds=unique(warn_kinds),
        info_kinds=unique(info_kinds))
end

function _dispatch_one!(backend::AutopilotBackend, entry::QueueEntry)
    # Stage (a): mark running + job_id=nothing + fsync. If the autopilot
    # crashes between here and stage (c), the next tick's zombie
    # reconciliation will recover or roll back via squeue --name.
    entry.status = :running
    entry.job_id = nothing
    save_entry!(entry)

    # Stage (b): backend.dispatch! mutates entry.job_id on success.
    ok = try
        dispatch!(backend, entry)
    catch err
        @warn "dispatch! threw; rolling back to pending" cid=entry.content_id exception=err
        false
    end
    if !ok
        entry.status = :pending
        entry.job_id = nothing
        save_entry!(entry)
        return false
    end

    # Stage (c): persist the entry with the real job_id (already set by
    # dispatch!).
    save_entry!(entry)
    return true
end

function _reconcile_zombie!(backend::AutopilotBackend, entry::QueueEntry)
    # Best effort: ask the backend whether a job with our content_id job-name
    # exists. If yes, adopt it; if no, return to pending.
    found = try
        find_job_by_name(backend, entry.content_id)
    catch err
        @warn "find_job_by_name threw during reconcile" cid=entry.content_id exception=err
        nothing
    end
    if found isa AbstractString && !isempty(found)
        entry.job_id = String(found)
        save_entry!(entry)
        return :recovered_running
    elseif found === :no_such_job
        entry.status = :pending
        save_entry!(entry)
        return :reset_to_pending
    end
    return :gave_up
end

function _terminal_classify!(entry::QueueEntry, terminal::Symbol;
    reason::AbstractString="")
    set_status!(entry, terminal;
        kill_reason=terminal === :done ? "" : String(reason))
end

# Classify SLURM "failed" → killed_bug (resource-permanent / NaN) or
# killed_data (divergence detected post-run by the runtime itself).
function _classify_terminal_failure(entry::QueueEntry, backend::AutopilotBackend)
    # First: outcome.toml (written by run_yaml at exit) — most informative.
    outcome_path = joinpath(entry.run_dir, OUTCOME_FILENAME)
    if isfile(outcome_path)
        d = try
            TOML.parsefile(outcome_path)
        catch
            ;
            nothing
        end
        if d isa AbstractDict
            term = String(get(get(d, "outcome", Dict()), "terminal", ""))
            reason = String(get(get(d, "outcome", Dict()), "reason", "no reason"))
            if term == "killed_data"
                return :killed_data, reason
            elseif term == "killed_bug"
                return :killed_bug, reason
            end
        end
    end
    # Fall back to backend-side reasons (TIMEOUT, OOM_KILLED, NODE_FAIL).
    reason = try
        backend_failure_reason(backend, entry)
    catch
        "backend reported failure"
    end
    # OOM is resource-permanent, not transient. Retry policy escalates
    # resource class instead of re-running the same recipe.
    if occursin(r"OUT_OF_MEMORY|OOM_KILLED"i, reason)
        return :killed_bug, "OOM: $(reason)"
    elseif occursin(r"TIMEOUT"i, reason)
        return :killed_bug, "TIMEOUT: $(reason)"
    elseif occursin(r"NODE_FAIL|PREEMPTED"i, reason)
        # Transient — but we don't auto-retry from tick. Mark bug for now;
        # retry policy will pick it up.
        return :killed_bug, "transient: $(reason)"
    end
    return :killed_bug, reason
end

_divergence_metric(entry::QueueEntry) = "norm/Fz drift"

# Dry-run: simulate one full dispatch cycle on a single entry. Logs the
# command we WOULD have run, writes a synthetic outcome.toml, and
# advances state to :done so on_complete can fire end-to-end. First
# dispatch safety net — operator inspects state.toml diff against what
# they expected before flipping `dry_run=false`.
function _dry_run_dispatch!(entry::QueueEntry)
    println(stderr, "[autopilot dry-run] would dispatch ",
        entry.content_id[1:min(8, length(entry.content_id))],
        "  recipe=", entry.recipe_name === nothing ? "—" : entry.recipe_name,
        "  profile=", entry.profile,
        "  est_wall=", entry.estimated_walltime_hours, "h",
        "  spec=", entry.spec_path)
    entry.status = :running
    entry.job_id = "dryrun-" * entry.content_id[1:min(8, length(entry.content_id))]
    save_entry!(entry)
    # Synthetic outcome.toml — marks the run as "completed by dry-run"
    # so retry / on_complete / archival downstream can see something
    # structured. Real runs overwrite this file at process exit.
    outcome_path = joinpath(entry.run_dir, OUTCOME_FILENAME)
    try
        open(outcome_path, "w") do io
            TOML.print(
                io,
                Dict{String, Any}(
                    "outcome" => Dict{String, Any}(
                        "terminal" => "done",
                        "reason" => "dry-run synthetic",
                        "completed" => true,
                    ),
                    "metrics" => Dict{String, Any}(),
                ),
            )
        end
    catch err
        @warn "_dry_run_dispatch! failed to write outcome.toml" exception=err
    end
    set_status!(entry, :done; kill_reason="")
    return entry
end
