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
# with job_id=nothing and reconciles via the backend's find_job_by_name.

export autopilot_tick!, kick_tick_async,
    default_autopilot_config,
    is_autopilot_paused, is_autopilot_dry_run, autopilot_set_dry_run!

# Sentinel file that pauses dispatch. Touch this to halt new submissions;
# remove to resume. `drain` is just "touch + wait for running to drain".
_pause_file(qr::QueueRoot) = joinpath(qr.path, ".autopilot.paused")
is_autopilot_paused(qr::QueueRoot=autopilot_queue_root()) = isfile(_pause_file(qr))

# Global dry-run sentinel. Persists across cron-driven ticks so the
# operator can flip it via CLI/dashboard without restarting any process.
# `autopilot_tick!` consults this in addition to `config.dry_run`.
_dry_run_file(qr::QueueRoot) = joinpath(qr.path, ".autopilot.dry_run")
is_autopilot_dry_run(qr::QueueRoot=autopilot_queue_root()) = isfile(_dry_run_file(qr))

"""
    autopilot_set_dry_run!(on::Bool; qr=autopilot_queue_root()) -> Bool

Touch or remove `<qr>/.autopilot.dry_run`. Returns the new state.
"""
function autopilot_set_dry_run!(on::Bool;
    qr::QueueRoot=autopilot_queue_root())
    f = _dry_run_file(qr)
    isdir(qr.path) || mkpath(qr.path)
    if on
        open(f, "w") do io
            println(io, "enabled_at: ", now())
            println(io, "by: ", get(ENV, "USER", "unknown"))
        end
    else
        isfile(f) && rm(f; force=true)
    end
    return on
end

function default_autopilot_config(;
    backends::Union{Nothing, Dict{Symbol, <:AutopilotBackend}}=nothing,
    backend::Union{Nothing, AutopilotBackend}=nothing,
    qr::QueueRoot=autopilot_queue_root(),
    kwargs...,
)
    if backends !== nothing && backend !== nothing
        throw(ArgumentError(
            "default_autopilot_config: pass backends= or backend=, not both"))
    end
    resolved = if backends !== nothing
        Dict{Symbol, AutopilotBackend}(backends)
    elseif backend !== nothing
        Dict{Symbol, AutopilotBackend}(:local => backend)
    else
        # Always register :local. Auto-register :uge when env says so —
        # this is what lets the systemd timer / dashboard server pick up
        # TSUBAME without anyone editing code.
        d = Dict{Symbol, AutopilotBackend}(:local => LocalBackend())
        uge = _maybe_uge_backend_from_env()
        uge === nothing || (d[:uge] = uge)
        d
    end
    AutopilotConfig(; backends=resolved, qr=qr, kwargs...)
end

"""
    _maybe_uge_backend_from_env() -> Union{Nothing, UGEBackend}

Build a UGEBackend from the SPINORBEC_TSUBAME_* env triple
(host / project_root / runs_root) if all three are set, otherwise
return nothing. Compute group / julia path / cuda module are optional
and default to TSUBAME 4-friendly values when unset.
"""
function _maybe_uge_backend_from_env()
    host = get(ENV, "SPINORBEC_TSUBAME_HOST", "")
    proj = get(ENV, "SPINORBEC_TSUBAME_PROJECT_ROOT", "")
    runs = get(ENV, "SPINORBEC_TSUBAME_RUNS_ROOT", "")
    (isempty(host) || isempty(proj) || isempty(runs)) && return nothing
    UGEBackend(;
        ssh_host=host,
        project_root=proj,
        remote_runs_root=runs,
        compute_group=get(ENV, "SPINORBEC_TSUBAME_GROUP", ""),
        julia_path=get(ENV, "SPINORBEC_TSUBAME_JULIA", "julia"),
        julia_depot=get(ENV, "SPINORBEC_TSUBAME_DEPOT", ""),
        cuda_module=get(ENV, "SPINORBEC_TSUBAME_CUDA_MODULE", ""),
        sync_code=lowercase(get(ENV, "SPINORBEC_TSUBAME_SYNC_CODE", "")) in
                  ("1", "true", "yes"),
    )
end

"""
    kick_tick_async(; max_wait_s=120) -> Task

Fire an `autopilot_tick!` asynchronously, retrying with 2s backoff
if the autopilot lock is held by another tick (e.g. the systemd timer,
or the parent tick that just ran the on_complete recipe that called us).
The retry deadline is `max_wait_s` — long enough to outlast any
reasonable tick body (dispatch is fast; the only thing that can hold
the lock for minutes is a Julia precompile inside a synchronous job,
which LocalBackend has already moved to a subprocess).

This is the "tick on enqueue" plumbing: called by `enqueue!`, the
dashboard's Run-now route, and on_complete's child enqueues so every
new pending entry gets picked up within seconds instead of waiting
for the next 5-min systemd timer fire.
"""
function kick_tick_async(; max_wait_s::Real=120)
    @async begin
        deadline = time() + max_wait_s
        while time() < deadline
            try
                autopilot_tick!()
                return nothing
            catch err
                msg = string(err)
                if occursin("lock", msg) || occursin("locked", msg)
                    sleep(2)   # back off; current tick is in flight
                    continue
                else
                    @warn "kick_tick_async tick failed" exception=err
                    return nothing
                end
            end
        end
        @warn "kick_tick_async gave up after $(max_wait_s)s — lock held too long"
    end
end

"""
    autopilot_tick!(; config=default_autopilot_config()) -> AutopilotStats

One tick. Reconciles inconsistent states, dispatches pending, reaps
running, fires on_complete. Holds the autopilot lockfile for the duration.
"""
function autopilot_tick!(; config::AutopilotConfig=default_autopilot_config())
    stats = AutopilotStats()
    breaker_details = Dict{String, Any}()
    # Task-local sentinel so any `enqueue!` called from *inside* this
    # tick (most importantly on_complete recipe children) skips
    # `kick_tick_async` — the second dispatch pass below picks the new
    # entries up in the same tick, no async storm needed.
    task_local_storage(:spinorbec_in_tick, true)
    return with_autopilot_lock(; qr=config.qr) do
        # Pre-tick circuit-breaker check. Trip → auto-pause + log; the
        # body still runs so reap/cleanup happens (only dispatch is gated
        # by the pause sentinel).
        trip, breaker_details = try
            check_breakers(; qr=config.qr)
        catch err
            @warn "check_breakers threw" exception=err
            (BREAKER_OK, Dict{String, Any}("breaker_error" => string(err)))
        end
        if trip !== BREAKER_OK
            @warn "circuit breaker tripped — auto-pausing" trip=trip details=breaker_details
            autopilot_pause!(; qr=config.qr)
            append_error_event!("breaker:$(trip)", breaker_details; qr=config.qr)
            try
                notify_slack("[autopilot] breaker $(trip) tripped — paused. $(breaker_details)")
            catch
            end
        end

        _autopilot_tick_body!(config, stats)

        # Post-tick metrics snapshot — append one JSONL record so
        # `recent_metric_samples(288)` gives 24h at 5-min cadence.
        try
            append_metric_sample!(stats, breaker_details; qr=config.qr)
        catch err
            @warn "append_metric_sample! threw" exception=err
        end
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
        recovered = _reconcile_zombie!(resolve_backend(config, entry), entry)
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
    dispatched_ref = Ref(0)
    _dispatch_pending_pass!(config, stats, pending, paused, budget_decision,
        dispatched_ref)

    # 2. Reap running → done / killed_data / killed_bug ──────────────
    # Pre-fetch one status snapshot per backend so per-entry polls
    # don't each pay an ssh round-trip. Default `prepare_status_snapshot`
    # returns nothing for backends without batch support (LocalBackend);
    # UGEBackend returns its qstat listing.
    running_now = list_queue(:running; qr=config.qr)
    status_snapshots = IdDict{AutopilotBackend, Any}()
    for entry in running_now
        backend = resolve_backend(config, entry)
        haskey(status_snapshots, backend) && continue
        status_snapshots[backend] = prepare_status_snapshot(backend)
    end
    for entry in running_now
        entry.job_id === nothing && continue   # still mid-submit (other process?)
        backend = resolve_backend(config, entry)
        snap = get(status_snapshots, backend, nothing)
        status = if snap === nothing
            job_status(backend, entry)
        else
            job_status(backend, entry; snapshot=snap)
        end
        # Record cluster-state transitions so the dashboard can show
        # "qw" vs "actually running" wait time. The pending→running
        # transition stamps cluster_started_at (only the first time)
        # and emits a structured @info line — visible in journalctl
        # and in CLI stdout, captures the actual TSUBAME qw wait the
        # operator just paid.
        if entry.cluster_state !== status
            if entry.cluster_started_at === nothing &&
                status in (:running, :done, :failed)
                entry.cluster_started_at = now()
                @info "autopilot: cluster started" cid=entry.content_id qw_wait_s=_elapsed_s(
                    entry.dispatched_at, entry.cluster_started_at
                ) est_walltime_h=entry.estimated_walltime_hours
            end
            entry.cluster_state = status
            save_entry!(entry)
        end
        if status === :done
            _terminal_classify!(entry, :done; reason="completed")
            stats.completed += 1
            _record_outcome_safe!(entry, :done; qr=config.qr)
            _collect_safe!(backend, entry)
            _maybe_fire_on_complete!(entry, config, stats)
        elseif status === :failed
            # Backend said failed. Look at outcome.toml + backend-side reason to decide
            # killed_data vs killed_bug (OOM is resource-permanent and
            # classified as killed_bug; divergence is killed_data).
            # Collect first so the classifier can read outcome.toml even
            # when the producer was a remote backend.
            _collect_safe!(backend, entry)
            terminal, reason = _classify_terminal_failure(entry, backend)
            _terminal_classify!(entry, terminal; reason=reason)
            stats.failed += 1
            _record_outcome_safe!(entry, terminal; qr=config.qr)
            if config.notify_slack_on_failure
                try
                    notify_slack("[autopilot] $(entry.content_id) → $(terminal): $(reason)")
                catch err
                    ;
                    @warn "notify_slack threw" exception=err
                end
            end
        elseif status === :running || status === :pending
            # Refresh _live_status.json in canonical local runs/ so the
            # divergence check and the dashboard see fresh data. No-op
            # for LocalBackend (already local); rsync for UGEBackend.
            try
                pull_live(backend, entry)
            catch err
                @warn "pull_live threw" cid=entry.content_id exception=err
            end
            # Still in flight; check for divergence kill.
            if _is_divergent(entry)
                @info "kill-divergent" cid=entry.content_id job=entry.job_id
                try
                    cancel!(backend, entry)
                catch
                end
                set_status!(entry, :killed_data;
                    kill_reason="divergent ($(string(_divergence_metric(entry))))")
                stats.killed_divergent += 1
                _collect_safe!(backend, entry)
                _record_outcome_safe!(entry, :killed_data; qr=config.qr)
            end
        else
            # :unknown — backend lost track; leave for next tick
        end
    end

    # 3. Second dispatch pass to pick up on_complete children created
    #    by the reap loop above. Their `enqueue!` saw the in-tick
    #    sentinel and suppressed `kick_tick_async`, so without this
    #    pass they'd wait for the next 5-min systemd tick. Shares the
    #    same dispatch budget (`max_dispatches_per_tick`) so it cannot
    #    runaway. Skipped if no on_complete fired (stats unchanged).
    if stats.on_complete_fired > 0
        new_pending = list_queue(:pending; qr=config.qr)
        _dispatch_pending_pass!(config, stats, new_pending, paused,
            budget_decision, dispatched_ref)
    end
    return nothing
end

# Dispatch loop body, extracted so step 1 (initial) and step 3
# (post-on_complete catch-up) can share it without duplicating the
# autonomy/inspector/dry-run gating. The `dispatched_ref` is shared
# across passes so the per-tick cap is honored cluster-wide, not
# reset between passes.
function _dispatch_pending_pass!(config::AutopilotConfig,
    stats::AutopilotStats,
    pending::AbstractVector,
    paused::Bool,
    budget_decision,
    dispatched_ref::Ref{Int},
)
    (paused || (budget_decision !== nothing && !budget_decision.allow)) &&
        return nothing
    for entry in pending
        dispatched_ref[] >= config.max_dispatches_per_tick && break

        # Autonomy gate: :suggest / :propose recipes never dispatch.
        entry.autonomy_level === :dispatch || continue

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

        # Honor either in-process config.dry_run OR the persistent
        # sentinel set by the operator. Either is sufficient.
        if config.dry_run || is_autopilot_dry_run(config.qr)
            _dry_run_dispatch!(entry, config, stats)
            stats.dispatched += 1
            stats.completed += 1
            dispatched_ref[] += 1
            continue
        end
        # Capture the autopilot config hash at dispatch time —
        # answers "what autopilot rules dispatched this run?".
        entry.autopilot_config_hash = _capture_autopilot_config_hash(config)
        ok = _dispatch_one!(resolve_backend(config, entry), entry)
        ok || break    # backend full or transient error; try next tick
        stats.dispatched += 1
        dispatched_ref[] += 1
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
    # reconciliation will recover or roll back via find_job_by_name.
    entry.status = :running
    entry.job_id = nothing
    save_entry!(entry)

    # Stage (a+): stage_in places config + code at the execution site.
    # No-op for LocalBackend; rsync+ssh for UGEBackend. A failure here
    # rolls back identically to a dispatch! failure — the entry returns
    # to :pending and the next tick retries.
    try
        stage_in(backend, entry)
    catch err
        @warn "stage_in threw; rolling back to pending" cid=entry.content_id exception=err
        entry.status = :pending
        entry.job_id = nothing
        save_entry!(entry)
        return false
    end

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
    # dispatch!) and stamp dispatched_at for queue-wait visibility. The
    # cluster_state stays :unknown until the reap loop polls — for
    # LocalBackend that's effectively immediate (next tick); for UGE
    # the gap is the qw → r wait.
    entry.dispatched_at = now()
    save_entry!(entry)
    @info "autopilot: dispatched" cid=entry.content_id backend=string(entry.backend_type) profile=entry.profile queue_wait_s=_elapsed_s(
        entry.enqueued_at, entry.dispatched_at
    ) est_walltime_h=entry.estimated_walltime_hours
    return true
end

# Elapsed seconds between two timestamps. Returns nothing when `start`
# is missing (e.g. legacy entry pre-1.1 schema). Used in @info lines
# so the journal/stdout shows the actual wait at each transition.
function _elapsed_s(start::Union{Nothing, DateTime},
    stop::DateTime=now())
    start === nothing && return nothing
    return round(Millisecond(stop - start).value / 1000; digits=1)
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
    # Stamp terminal_at so the dashboard can show "ran for Nm" on
    # completed entries without guessing from file mtimes.
    entry.terminal_at = now()
    entry.cluster_state = terminal === :done ? :done : :failed
    @info "autopilot: terminal" cid=entry.content_id status=string(terminal) ran_s=_elapsed_s(
        entry.cluster_started_at, entry.terminal_at
    ) total_s=_elapsed_s(entry.enqueued_at, entry.terminal_at) reason=String(reason)
    set_status!(entry, terminal;
        kill_reason=terminal === :done ? "" : String(reason))
end

# Classify backend "failed" → killed_bug (resource-permanent / NaN) or
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
# command we WOULD have run, writes a synthetic outcome.toml, advances
# state to :done, AND fires the on_complete chain so recipe-driven
# fan-out is exercised end-to-end during the observation lap. Without
# the explicit on_complete call here, dry-run silently masks recipe
# behavior because the reap loop only sees backend-driven completions.
# `on_complete_max_descendants` (default 64) bounds the chain length.
function _dry_run_dispatch!(entry::QueueEntry,
    config::AutopilotConfig, stats::AutopilotStats)
    println(stderr, "[autopilot dry-run] would dispatch ",
        entry.content_id[1:min(8, length(entry.content_id))],
        "  recipe=", entry.recipe_name === nothing ? "—" : entry.recipe_name,
        "  profile=", entry.profile,
        "  est_wall=", entry.estimated_walltime_hours, "h",
        "  spec=", entry.spec_path)
    entry.status = :running
    entry.job_id = "dryrun-" * entry.content_id[1:min(8, length(entry.content_id))]
    # Stamp lifecycle timestamps so dry-run entries get the same
    # dashboard ETA / per-phase breakdown that real dispatches do.
    # cluster_started_at = dispatched_at since dry-run has no queue.
    t = now()
    entry.dispatched_at = t
    entry.cluster_started_at = t
    entry.cluster_state = :running
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
    # Route through _terminal_classify! so dry-run entries get
    # terminal_at stamped + the same @info "terminal" line that real
    # runs produce. Without this, dashboard ETA / journal-replay
    # would be incomplete for dry-run dispatches.
    _terminal_classify!(entry, :done; reason="dry-run synthetic")
    # Fire the on_complete chain — recipes spawn children which land in
    # :pending and get picked up on the next tick.
    _maybe_fire_on_complete!(entry, config, stats)
    return entry
end

# Pull results into canonical local runs/<cid>/ via the backend's
# `collect!` contract method. No-op for LocalBackend (already there);
# rsync for UGEBackend. Best-effort — a collection failure must NOT
# crash the reap loop; we'd rather record a terminal status with
# missing artefacts than wedge the tick.
function _collect_safe!(backend::AutopilotBackend, entry::QueueEntry)
    try
        collect!(backend, entry)
    catch err
        @warn "collect! threw" cid=entry.content_id exception=err
    end
    return nothing
end

# Bump the per-recipe outcome counter; no-op when entry has no recipe.
# Wrapped because trust-store writes shouldn't crash a reap loop.
function _record_outcome_safe!(entry::QueueEntry, outcome::Symbol;
    qr::QueueRoot,
)
    entry.recipe_name === nothing && return nothing
    try
        record_recipe_outcome!(entry.recipe_name, outcome; qr=qr)
    catch err
        @warn "record_recipe_outcome! threw" recipe=entry.recipe_name outcome=outcome exception=err
    end
    return nothing
end
