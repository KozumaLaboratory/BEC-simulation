# ── Queue storage (state.toml in run_dir) ─────────────────────────────
#
# 2026-05-28 honest re-foundation: queue state is **per-run metadata
# living in the same directory as the run's data**. There is no separate
# `queue/{pending,running,done,failed}/` tree — that would split the
# single source of truth from the run's CAS-keyed `runs/<content_id>/`.
#
# Layout:
#   runs/
#     <content_id>/
#       config.yaml        ← user spec
#       state.toml         ← queue entry (this file's responsibility)
#       outcome.toml       ← structured terminal status (written by run_yaml)
#       ... run artefacts (point_NNN.jld2, _live_status.json, ...)
#     .autopilot.lock      ← process-level lockfile
#     .autopilot.paused    ← drain / pause sentinel (touched by operator CLI)
#
# `list_queue(:state)` walks `runs/*/state.toml` and filters by status.
# At active research sizes (O(10³) runs) this is milliseconds.
#
# Status enum (5 states):
#   :pending     waiting for dispatch
#   :running     dispatched (job_id may be nothing during submitting window)
#   :done        completed successfully
#   :killed_data physically divergent (norm drift, classify_collapse).
#                Carries epistemic value — NOT a bug. Surrogates may consume.
#   :killed_bug  NaN cascade, exception, OOM. No epistemic value, code-side
#                problem. Surrogates ignore.

import TOML
import Base.Filesystem: mkpath, mv

export QueueEntry, QueueRoot,
    QUEUE_STATES, RUN_STATE_FILENAME, OUTCOME_FILENAME,
    STATE_TOML_SCHEMA_VERSION,
    enqueue!, list_queue, get_entry, save_entry!,
    backfill_group_ids!,
    queue_root_default, autopilot_queue_root,
    set_status!, with_autopilot_lock, with_entry_lock

const RUN_STATE_FILENAME = "state.toml"
const OUTCOME_FILENAME = "outcome.toml"
const QUEUE_STATES = (:pending, :running, :done, :killed_data, :killed_bug)

"""
    QueueRoot(path)

Filesystem-backed queue root. `path` is the *CAS store root* — usually
`runs/`. There are no sub-directories per state; each run dir under
`path` carries its own state.toml. Default resolves to
`ENV["SPINORBEC_QUEUE"]` or `default_store().root`.
"""
struct QueueRoot
    path::String
end

queue_root_default() = QueueRoot(
    get(ENV, "SPINORBEC_QUEUE", default_store().root)
)

const _DEFAULT_QUEUE_ROOT = Ref{Union{Nothing, QueueRoot}}(nothing)

function autopilot_queue_root()
    if _DEFAULT_QUEUE_ROOT[] === nothing
        _DEFAULT_QUEUE_ROOT[] = queue_root_default()
    end
    _DEFAULT_QUEUE_ROOT[]::QueueRoot
end

function autopilot_queue_root(qr::QueueRoot)
    _DEFAULT_QUEUE_ROOT[] = qr
    qr
end

# ── Entry ──────────────────────────────────────────────────────────────

"""
    QueueEntry

Per-run queue state. Mirrors state.toml 1:1. Constructed via
`load_entry(run_dir)` or `QueueEntry(content_id, ...)`.

Recipe is the named-callback layer (`recipe_name + recipe_params`),
intentionally serializable so the autopilot can wake up cold and replay
intent from disk. Closures are forbidden here — see `enqueue_dev!` for
the REPL-only path that bypasses persistence.
"""
mutable struct QueueEntry
    # state
    status::Symbol                          # :pending | :running | :done | :killed_data | :killed_bug
    kill_reason::String                     # "" when status is not killed_*
    attempt::Int
    priority::Int

    # provenance (immutable after enqueue)
    content_id::String
    enqueued_at::DateTime
    enqueued_by::String
    parent_id::Union{Nothing, String}
    # Intention grouping key. A manual sweep shares one group_id across
    # all cells; an on_complete child inherits its parent's group_id; a
    # lone run defaults to its own content_id (singleton group). The
    # dashboard groups the queue by this so 100-cell sweeps collapse to
    # one expandable row instead of 100 flat rows.
    group_id::String

    # recipe (named registry — no closures)
    recipe_name::Union{Nothing, Symbol}
    recipe_params::Dict{String, Any}
    autonomy_level::Symbol                  # :suggest | :propose | :dispatch

    # backend
    backend_type::Symbol                    # :local | :uge
    job_id::Union{Nothing, String}           # nothing during the submit window
    profile::String                         # submit-script profile / resource class
    estimated_walltime_hours::Float64

    # lifecycle timestamps — each phase boundary that the autopilot can
    # observe is captured so the dashboard can show "queued 2m / cluster
    # qw 5m / running 3m" instead of a flat ":running for N min".
    dispatched_at::Union{Nothing, DateTime}        # when dispatch! succeeded (qsub / subprocess spawn)
    cluster_started_at::Union{Nothing, DateTime}   # when scheduler flipped pending→running (qw→r on UGE)
    terminal_at::Union{Nothing, DateTime}          # when status went to :done / :killed_*
    cluster_state::Symbol                          # :unknown | :pending | :running | :done | :failed (transient, refreshed each tick)

    # budget (filled in by qacct/scheduler poller)
    gpu_hours_realized::Float64

    # filesystem
    run_dir::String                         # absolute path to runs/<cid>/
    spec_path::String                       # config.yaml in run_dir

    # reproducibility (captured at enqueue! time, never mutated)
    code_sha::String                        # git rev-parse HEAD at enqueue
    recipe_version::String                  # recipe-declared semver, default "1"
    inspector_snapshot_hash::String         # sha256 of inspect_config output
    autopilot_config_hash::String           # sha of the AutopilotConfig snapshot
end

function QueueEntry(content_id::AbstractString;
    run_dir::AbstractString,
    spec_path::AbstractString,
    status::Symbol=:pending,
    kill_reason::AbstractString="",
    attempt::Int=1,
    priority::Int=5,
    enqueued_at::DateTime=now(),
    enqueued_by::AbstractString="manual",
    parent_id::Union{Nothing, AbstractString}=nothing,
    group_id::AbstractString="",
    recipe_name::Union{Nothing, Symbol}=nothing,
    recipe_params::AbstractDict=Dict{String, Any}(),
    autonomy_level::Symbol=:dispatch,
    backend_type::Symbol=:local,
    job_id::Union{Nothing, AbstractString}=nothing,
    profile::AbstractString="default",
    estimated_walltime_hours::Real=2.0,
    dispatched_at::Union{Nothing, DateTime}=nothing,
    cluster_started_at::Union{Nothing, DateTime}=nothing,
    terminal_at::Union{Nothing, DateTime}=nothing,
    cluster_state::Symbol=:unknown,
    gpu_hours_realized::Real=0.0,
    code_sha::AbstractString="",
    recipe_version::AbstractString="1",
    inspector_snapshot_hash::AbstractString="",
    autopilot_config_hash::AbstractString="",
)
    status in QUEUE_STATES ||
        throw(ArgumentError("unknown status $status; expected one of $QUEUE_STATES"))
    autonomy_level in (:suggest, :propose, :dispatch) ||
        throw(ArgumentError("autonomy_level must be :suggest|:propose|:dispatch"))
    # Empty group_id → singleton group keyed on the run's own content_id.
    resolved_group = isempty(group_id) ? String(content_id) : String(group_id)
    QueueEntry(
        status, String(kill_reason), attempt, priority,
        String(content_id), enqueued_at, String(enqueued_by),
        parent_id === nothing ? nothing : String(parent_id),
        resolved_group,
        recipe_name,
        Dict{String, Any}(string(k) => v for (k, v) in recipe_params),
        autonomy_level,
        backend_type,
        job_id === nothing ? nothing : String(job_id),
        String(profile), Float64(estimated_walltime_hours),
        dispatched_at, cluster_started_at, terminal_at, cluster_state,
        Float64(gpu_hours_realized),
        abspath(String(run_dir)),
        abspath(String(spec_path)),
        String(code_sha), String(recipe_version),
        String(inspector_snapshot_hash), String(autopilot_config_hash),
    )
end

# ── (De)serialize to TOML ────────────────────────────────────────────
#
# Schema versioning: every state.toml carries a top-level
# `schema_version` string. When fields shift, bump `STATE_TOML_SCHEMA_VERSION`
# and add a clause in `_migrate_state_toml`. Old entries are migrated
# in-memory at read time; rewriting requires explicit
# `save_entry!(get_entry(run_dir))`. Schema history is documented at
# the top of this file.

"""
    with_entry_lock(f, e::QueueEntry; stale_after_s=300) -> result of f()

Per-entry mutex via `mkdir`-based exclusive lock at
`<run_dir>/.state.lock/` (mkdir is atomic on POSIX). Holder writes a
`pid` file inside; stale locks older than `stale_after_s` are forcibly
taken. Used by every read-modify-write site on state.toml so concurrent
ticks / monitors don't clobber each other.

`with_autopilot_lock` is the autopilot-wide tick-mutex; this is per-run.
"""
function with_entry_lock(f::Function, e::QueueEntry;
    stale_after_s::Real=300,
)
    isdir(e.run_dir) || mkpath(e.run_dir)
    lockdir = joinpath(e.run_dir, ".state.lock")
    acquired = false
    attempts = 0
    while !acquired
        attempts += 1
        try
            mkdir(lockdir)
            acquired = true
        catch err
            if err isa SystemError && isdir(lockdir)
                # Lock held; check staleness.
                if time() - mtime(lockdir) > stale_after_s
                    @warn "stale entry lock taken over" cid=e.content_id
                    try
                        rm(lockdir; recursive=true, force=true)
                    catch
                    end
                    continue
                end
                attempts > 50 && throw(ErrorException(
                    "with_entry_lock: $(lockdir) held for too long"))
                sleep(0.1)
            else
                rethrow(err)
            end
        end
    end
    try
        open(joinpath(lockdir, "pid"), "w") do io
            println(io, "pid: ", getpid())
            println(io, "host: ", gethostname())
            println(io, "acquired_at: ", now())
        end
    catch
    end
    try
        return f()
    finally
        try
            rm(lockdir; recursive=true, force=true)
        catch
        end
    end
end

"""
    save_entry!(e::QueueEntry)

Atomic write of state.toml. Always wrap multi-step RMW in
`with_entry_lock` (this function alone is safe for single-shot replaces;
only the read+mutate+write sequence needs the per-entry lock).
"""
function save_entry!(e::QueueEntry)
    isdir(e.run_dir) || mkpath(e.run_dir)
    p = joinpath(e.run_dir, RUN_STATE_FILENAME)
    # Two-step write (tmp + rename) so a crash mid-write doesn't corrupt
    # the on-disk truth. fsync semantics are what's load-bearing here.
    tmp = p * ".tmp"
    open(tmp, "w") do io
        TOML.print(io, _entry_to_toml_dict(e))
    end
    mv(tmp, p; force=true)
    return p
end

"""
    get_entry(run_dir) -> Union{QueueEntry, Nothing}

Read state.toml in `run_dir`. Returns nothing when absent (= run dir not
queued).
"""
function get_entry(run_dir::AbstractString)
    p = joinpath(String(run_dir), RUN_STATE_FILENAME)
    isfile(p) || return nothing
    d = try
        TOML.parsefile(p)
    catch e
        @warn "state.toml parse failed" path=p exception=e
        return nothing
    end
    _entry_from_toml_dict(d, String(run_dir))
end

# ── Public API ────────────────────────────────────────────────────────

"""
    list_queue(state=:pending; qr=autopilot_queue_root()) -> Vector{QueueEntry}

Scan `<qr.path>/*/state.toml` and return entries whose `status` matches
`state`. Use `:all` to skip filtering. Sorted by (priority, enqueued_at).
"""
function list_queue(state::Symbol=:pending;
    qr::QueueRoot=autopilot_queue_root())
    state in QUEUE_STATES || state === :all ||
        throw(ArgumentError("unknown state $state; expected $(QUEUE_STATES) or :all"))
    isdir(qr.path) || return QueueEntry[]
    entries = QueueEntry[]
    for sub in readdir(qr.path; join=true)
        isdir(sub) || continue
        startswith(basename(sub), ".") && continue
        e = get_entry(sub)
        e === nothing && continue
        if state === :all || e.status === state
            push!(entries, e)
        end
    end
    sort!(entries; by=e -> (e.priority, e.enqueued_at))
    return entries
end

"""
    backfill_group_ids!(; qr=autopilot_queue_root(), dry_run=false)
        -> Vector{Pair{String,String}}

Reconstruct intention `group_id`s for legacy lineages. For each entry,
walk the `parent_id` chain to its lineage root and adopt the root's
`group_id`; parentless entries keep their own. Needed only for on_complete
trees enqueued before `group_id` inheritance existed — read-time
deserialization already resolves an empty id to the entry's own
`content_id`, so this is purely a clustering pass, never invents grouping
that lineage doesn't already imply. Returns the `content_id => new_group_id`
changes applied (or that would apply when `dry_run`).
"""
function backfill_group_ids!(; qr::QueueRoot=autopilot_queue_root(),
    dry_run::Bool=false)
    all_entries = list_queue(:all; qr=qr)
    by_cid = Dict(e.content_id => e for e in all_entries)
    changes = Pair{String, String}[]
    for e in all_entries
        root = e
        seen = Set{String}((e.content_id,))
        while root.parent_id !== nothing && haskey(by_cid, root.parent_id) &&
                  !(root.parent_id in seen)
            push!(seen, root.parent_id)
            root = by_cid[root.parent_id]
        end
        target = root.group_id
        e.group_id == target && continue
        push!(changes, e.content_id => target)
        dry_run && continue
        with_entry_lock(e) do
            latest = get_entry(e.run_dir)
            latest === nothing && return nothing
            latest.group_id = target
            save_entry!(latest)
        end
    end
    return changes
end

"""
    set_status!(entry, new_status; kill_reason="") -> QueueEntry

Update status (and optionally kill_reason) and persist atomically.
Validates the transition is in the 5-state enum.
"""
function set_status!(e::QueueEntry, new_status::Symbol; kill_reason::AbstractString="")
    new_status in QUEUE_STATES ||
        throw(ArgumentError("unknown status $new_status"))
    with_entry_lock(e) do
        # Re-read inside the lock so we don't clobber concurrent updates
        # (e.g. monitor wrote killed_data while we held a stale copy).
        latest = get_entry(e.run_dir)
        if latest !== nothing
            # Preserve concurrent updates by merging — only status + reason
            # are this call's responsibility.
            latest.status = new_status
            latest.kill_reason = if !isempty(kill_reason)
                String(kill_reason)
            else
                (new_status in (:killed_data, :killed_bug) ?
                 latest.kill_reason : "")
            end
            # Pull lifecycle fields the caller may have stamped on `e`
            # but on-disk hadn't seen (e.g. `_terminal_classify!` sets
            # terminal_at + cluster_state right before calling
            # set_status!). Only overwrite when `e` has the newer value;
            # otherwise keep what disk has.
            e.dispatched_at === nothing || (latest.dispatched_at = e.dispatched_at)
            e.cluster_started_at === nothing || (latest.cluster_started_at = e.cluster_started_at)
            e.terminal_at === nothing || (latest.terminal_at = e.terminal_at)
            e.cluster_state === :unknown || (latest.cluster_state = e.cluster_state)
            # Sync back to caller's struct so they see fresh fields too.
            e.status = latest.status
            e.kill_reason = latest.kill_reason
            e.job_id = latest.job_id
            e.attempt = latest.attempt
            e.dispatched_at = latest.dispatched_at
            e.cluster_started_at = latest.cluster_started_at
            e.terminal_at = latest.terminal_at
            e.cluster_state = latest.cluster_state
            save_entry!(latest)
        else
            e.status = new_status
            if !isempty(kill_reason)
                e.kill_reason = String(kill_reason)
            elseif !(new_status in (:killed_data, :killed_bug))
                e.kill_reason = ""
            end
            save_entry!(e)
        end
    end
    return e
end

"""
    enqueue!(exp; priority=5, enqueued_by="manual", recipe_name=nothing,
             recipe_params=Dict(), autonomy_level=:dispatch, parent_id=nothing,
             profile="default", estimated_walltime_hours=2.0,
             backend_type=:local, qr=autopilot_queue_root()) -> QueueEntry

Create / update the run dir's state.toml to `status=:pending`. Persists
the spec to `<run_dir>/config.yaml` if it isn't already there. Idempotent
on re-enqueue (existing terminal status is overwritten by warning).
"""
function enqueue!(exp::Experiment;
    priority::Int=5,
    enqueued_by::AbstractString="manual",
    recipe_name::Union{Nothing, Symbol}=nothing,
    recipe_params::AbstractDict=Dict{String, Any}(),
    autonomy_level::Symbol=:dispatch,
    parent_id::Union{Nothing, AbstractString}=nothing,
    group_id::AbstractString="",
    profile::AbstractString="default",
    estimated_walltime_hours::Real=2.0,
    backend_type::Symbol=:local,
    qr::QueueRoot=autopilot_queue_root(),
    # When true (default), spawn an async `autopilot_tick!` so the new
    # entry dispatches within seconds instead of waiting for the next
    # 5-min systemd timer fire. Skipped automatically when
    # autonomy_level != :dispatch (nothing to dispatch). Set false in
    # bulk-load / test contexts where the side-effect would be noise.
    kick_tick::Bool=true,
)
    od = outdir(exp)
    isdir(od) || mkpath(od)
    cfg_path = joinpath(od, "config.yaml")
    isfile(cfg_path) || write_run!(exp)

    existing = get_entry(od)
    if existing !== nothing && existing.status in (:running, :done)
        @warn "enqueue!: overwriting existing $(existing.status) entry" cid=existing.content_id
    end

    e = QueueEntry(content_id(exp.spec);
        run_dir=od, spec_path=cfg_path,
        status=:pending, priority=priority,
        enqueued_by=enqueued_by, parent_id=parent_id,
        group_id=group_id,
        recipe_name=recipe_name, recipe_params=recipe_params,
        autonomy_level=autonomy_level,
        profile=profile, estimated_walltime_hours=estimated_walltime_hours,
        backend_type=backend_type,
        code_sha=_capture_code_sha(),
        recipe_version=_capture_recipe_version(recipe_name),
        inspector_snapshot_hash=_capture_inspector_snapshot_hash(cfg_path),
        autopilot_config_hash="",   # filled at dispatch time by tick.jl
    )
    save_entry!(e)
    if kick_tick && autonomy_level === :dispatch &&
        !get(task_local_storage(), :spinorbec_in_tick, false)
        # `kick_tick_async` lives in tick.jl (loaded after queue.jl),
        # so look it up lazily via the parent module.
        # Suppressed when we're already inside `autopilot_tick!`
        # (e.g. on_complete recipe enqueueing children) — the parent
        # tick will pick them up via its second dispatch pass, so
        # there's no thundering-herd of 64 async kick tasks competing
        # for the same autopilot lock.
        kicker = if isdefined(@__MODULE__, :kick_tick_async)
            getfield(@__MODULE__, :kick_tick_async)
        else
            nothing
        end
        kicker === nothing || Base.invokelatest(kicker)
    end
    return e
end

# Reproducibility-metadata capture helpers ────────────────────────────

"""
    _capture_code_sha() -> String

`git rev-parse HEAD` of the running checkout. Empty string when git is
unavailable or the working tree isn't a repo — enqueue does not fail,
but the resulting state.toml documents the omission.
"""
function _capture_code_sha()
    try
        sha = strip(read(`git rev-parse HEAD`, String))
        # Mark dirty trees so we don't pretend a mutated checkout is the
        # committed SHA. Cheap check via `git diff --quiet`.
        dirty = try
            success(`git diff --quiet`) ? "" : "-dirty"
        catch
            ""
        end
        return String(sha * dirty)
    catch
        return ""
    end
end

"""
    _capture_recipe_version(name) -> String

Recipes register a version via `register_on_complete_version!(:name, "1.2")`.
Default "1" when no explicit version is registered. Empty string when no
recipe is attached.
"""
function _capture_recipe_version(name::Union{Nothing, Symbol})
    name === nothing && return ""
    # `on_complete_version` lives in on_complete.jl, which is loaded after
    # this file. `invokelatest` defers symbol resolution to call time.
    try
        return String(Base.invokelatest(on_complete_version, name))
    catch
        return "1"
    end
end

"""
    _capture_autopilot_config_hash(config) -> String

SHA-256 of the AutopilotConfig's serializable shape (backend kind,
queue root path, dispatch caps, gate flags). Called at dispatch
time by tick.jl and persisted on the entry. Answers "what
autopilot config rules dispatched this run?".
"""
function _capture_autopilot_config_hash(config)
    config === nothing && return ""
    payload = try
        # Hash the registry as a sorted (kind => backend-typename) map so
        # the digest is stable across iteration order and reflects "which
        # backends were available at dispatch time".
        backend_kinds = Dict{String, String}()
        for (k, b) in config.backends
            backend_kinds[String(k)] = string(typeof(b).name.name)
        end
        Dict{String, Any}(
            "backends" => backend_kinds,
            "qr_path" => config.qr.path,
            "inspect_before_dispatch" => config.inspect_before_dispatch,
            "max_dispatches_per_tick" => config.max_dispatches_per_tick,
            "on_complete_max_descendants" => config.on_complete_max_descendants,
            "notify_slack_on_failure" => config.notify_slack_on_failure,
            "dry_run" => hasproperty(config, :dry_run) ? config.dry_run : false,
            "respect_budget" =>
                hasproperty(config, :respect_budget) ?
                config.respect_budget : true,
        )
    catch
        return ""
    end
    bytes2hex(SHA.sha256(JSON.json(payload)))
end

"""
    _capture_inspector_snapshot_hash(spec_path) -> String

Run `inspect_config(spec_path)` and hash its serialized output. The
hash answers "did the spec / templates / calibrations resolve to the
same effective YAML at enqueue time as on this dispatch?" — i.e. it
detects silent semantic drift across enqueue and dispatch.
"""
function _capture_inspector_snapshot_hash(spec_path::AbstractString)
    isdefined(@__MODULE__, :inspect_config) || return ""
    try
        ins = inspect_config(String(spec_path))
        # Serialize through the standard to_dict view, then sha256 the
        # canonical JSON. Cheap, deterministic, doesn't depend on
        # warning-message wording.
        d = if isdefined(@__MODULE__, :to_dict)
            to_dict(ins)
        else
            Dict("warnings" => length(ins.warnings))
        end
        bytes2hex(SHA.sha256(JSON.json(d)))
    catch err
        @warn "inspector snapshot capture failed" exception=err
        ""
    end
end

# Recipe version registry now lives in on_complete.jl
# (`register_on_complete_version!`); `_capture_recipe_version` resolves
# it via `Base.invokelatest`.

"""
    enqueue!(exps::Vector{Experiment}; group_id="", kwargs...) -> Vector{QueueEntry}

Enqueue a sweep. All cells share one `group_id` so the dashboard renders
them as a single expandable group rather than N flat rows. When
`group_id` is empty, derive a deterministic one from the sorted member
content_ids — re-enqueuing the same sweep yields the same group.
"""
function enqueue!(exps::AbstractVector{<:Experiment}; group_id::AbstractString="",
    kick_tick::Bool=true, kwargs...)
    isempty(exps) && return QueueEntry[]
    gid = if !isempty(group_id)
        String(group_id)
    else
        cids = sort([content_id(e.spec) for e in exps])
        "grp-" * bytes2hex(SHA.sha256(join(cids, ",")))[1:12]
    end
    # Suppress per-entry ticks; fire ONE tick after the batch lands so a
    # 100-cell sweep doesn't spawn 100 async ticks fighting for the lock.
    entries = [enqueue!(e; group_id=gid, kick_tick=false, kwargs...) for e in exps]
    if kick_tick && any(en -> en.autonomy_level === :dispatch, entries) &&
        !get(task_local_storage(), :spinorbec_in_tick, false)
        kicker = if isdefined(@__MODULE__, :kick_tick_async)
            getfield(@__MODULE__, :kick_tick_async)
        else
            nothing
        end
        kicker === nothing || Base.invokelatest(kicker)
    end
    return entries
end

# ── Lockfile (process-level mutex for autopilot_tick!) ──────────────

"""
    with_autopilot_lock(f; qr=autopilot_queue_root(), stale_after_s=900)

Acquire the autopilot lock, run `f()`, release. Lock file
`<qr.path>/.autopilot.lock` contains the holder's PID + acquired
timestamp; a stale lock (mtime older than `stale_after_s`) is forcibly
taken over. Returns whatever `f()` returns; throws `:locked` if another
live autopilot is running.
"""
function with_autopilot_lock(f::Function;
    qr::QueueRoot=autopilot_queue_root(),
    stale_after_s::Real=900,
)
    isdir(qr.path) || mkpath(qr.path)
    lockfile = joinpath(qr.path, ".autopilot.lock")

    if !_try_acquire_lock(lockfile; stale_after_s)
        throw(ErrorException("autopilot: lock $(lockfile) held by another process"))
    end
    try
        return f()
    finally
        try
            rm(lockfile; force=true)
        catch
        end
    end
end

function _try_acquire_lock(lockfile::AbstractString; stale_after_s::Real=900)
    # Attempt atomic exclusive create. If the file exists, check whether
    # the holder is live; take over if stale.
    try
        # O_CREAT|O_EXCL semantics — Julia's `open(path, "wx")` not portable;
        # use `mkdir` of a marker dir? Simpler: write tmp + atomic rename
        # rejected if dest exists. Use a sentinel approach: hard-link from
        # tmp to dest fails if dest exists.
        if isfile(lockfile)
            if _is_lock_stale(lockfile; stale_after_s)
                @warn "autopilot lock stale, forcibly removing" file=lockfile
                rm(lockfile; force=true)
            else
                return false
            end
        end
        open(lockfile, "w") do io
            println(io, "pid: ", getpid())
            println(io, "host: ", gethostname())
            println(io, "acquired_at: ", now())
        end
        return true
    catch e
        @warn "autopilot lock acquire failed" exception=e
        return false
    end
end

function _is_lock_stale(lockfile::AbstractString; stale_after_s::Real=900)
    age_s = time() - mtime(lockfile)
    age_s > stale_after_s && return true
    # Best effort: parse PID and check if alive.
    content = try
        read(lockfile, String)
    catch
        return true
    end
    m = match(r"pid:\s*(\d+)", content)
    m === nothing && return false   # unknown PID; trust mtime
    pid = parse(Int, m.captures[1])
    return !_pid_alive(pid)
end

function _pid_alive(pid::Int)
    try
        # On Linux, /proc/<pid> exists iff process is alive.
        if Sys.islinux()
            return isdir("/proc/$pid")
        end
        # Fallback: send signal 0 via ccall to kill.
        return ccall(:kill, Cint, (Cint, Cint), pid, 0) == 0
    catch
        return true   # assume alive on uncertainty
    end
end
