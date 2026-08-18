# ── UGE backend (Univa / Altair Grid Engine) ─────────────────────────
#
# Concrete remote backend for clusters running UGE. TSUBAME 4 is the
# primary target — `qsub -g <group>` for billing, `-l node_q=1` etc.
# for resources, output parsed from "Your job NNNN ...". Implements the
# ExecutionTarget contract (stage_in / dispatch! / job_status /
# pull_live / collect! / cancel! / find_job_by_name) with rsync-over-ssh
# for data movement and qsub/qstat/qdel for scheduler interaction.
#
# All transfers are PC-initiated: the dashboard never reads the remote
# filesystem, so a flaky link degrades to "stale local mirror" rather
# than wedging the catalog walk.

export UGEBackend,
    UGE_PROFILE_DIRECTIVES, UGE_PROFILE_ESCALATION,
    render_uge_script,
    next_profile

# ── profile table ────────────────────────────────────────────────────
#
# Each entry is a Vector{String} of `#$` arguments. The renderer prepends
# `#$ ` to each. Job-name / cwd / -o / -e / -g are added by the renderer
# from backend + entry fields, NOT here, so re-binding a profile doesn't
# accidentally hide them.
#
# TSUBAME 4 resource keys (from `qconf -sc`):
#   node_f / node_h / node_q / node_o : full / half / quarter / 1-of-8 node
#   gpu_1                              : 1 GPU on a shared node
#   h_rt                               : hard walltime HH:MM:SS

const UGE_PROFILE_DIRECTIVES = Dict{String, Vector{String}}(
    # Single-H100 default for SpinorBEC.jl: 1/4 node = 1× H100 + 48 cores.
    "default" => ["-l node_q=1", "-l h_rt=12:00:00"],
    "node_h" => ["-l node_h=1", "-l h_rt=24:00:00"],
    "node_f" => ["-l node_f=1", "-l h_rt=24:00:00"],
    "gpu_1" => ["-l gpu_1=1", "-l h_rt=6:00:00"],
    "long_q" => ["-l node_q=1", "-l h_rt=72:00:00"],
)

# Escalation for retry.jl when a RESOURCE_PERMANENT failure (OOM / timeout) is
# classified.
#
# **READ THIS BEFORE ASSUMING IT FIXES AN OOM.** These steps buy WALLTIME and
# CPU, not VRAM. `node_h` is two H100s and `node_f` is four, and this codebase is
# single-device — `grep -riE "multi.?gpu|CUDA.device!|device_id" src ext` returns
# nothing — so a job that exhausted one 80 GB card exhausts exactly the same card
# on the wider profile, and does it at 2x then 4x the billing rate before the
# ladder gives up.
#
# So the ladder is right for a TIMEOUT (12h → 24h → 72h via `long_q`) and cannot
# help an OOM. `classify_failure` returns RESOURCE_PERMANENT for both causes and
# does not distinguish them; `_escalation_can_help` below says so at the point of
# use rather than letting the operator infer it from a bill. Fixing an OOM means
# a smaller grid, `dtype: f32`, or fewer saved snapshots — not a bigger profile.
#
# `nothing` = no escalation, retry policy gives up.
const UGE_PROFILE_ESCALATION = Dict{String, Union{Nothing, String}}(
    "default" => "node_h",
    "node_h" => "node_f",
    "node_f" => nothing,
    "gpu_1" => "default",
    "long_q" => nothing,
)

"""
    _escalation_can_help(cause::Symbol) -> Bool

Whether moving up `UGE_PROFILE_ESCALATION` can plausibly fix `cause`.

`:timeout` yes — every step raises `h_rt`. `:oom` no — every step adds GPUs, and
nothing in this codebase uses more than one. Separated so the useless case is
stated where the decision is made instead of discovered on an invoice.
"""
_escalation_can_help(cause::Symbol) = cause !== :oom

# ── struct + constructor ─────────────────────────────────────────────

"""
    UGEBackend(;
        ssh_host = nothing,             # nothing → run qsub locally
        max_concurrent = nothing,       # nothing → no autopilot-side cap
        project_root = pwd(),           # remote SpinorBEC.jl checkout
        remote_runs_root = nothing,     # required when ssh_host is set
        compute_group = "",             # `qsub -g <group>` billing
        julia_path = "julia",           # remote julia binary
        cuda_module = "",               # `module load <cuda_module>` if non-empty
        sync_code = false,              # `git checkout code_sha` on remote
    )

Submits jobs to a UGE scheduler. The script is rendered on the fly from
`UGE_PROFILE_DIRECTIVES[entry.profile]` via `render_uge_script` — no
static `.sh` files in `scripts/`.

When `ssh_host` is set, dispatch goes over SSH and data movement uses
`rsync`. All transfers are PC-initiated (the dashboard never reads
remote FS, so a flaky link degrades to "stale local mirror" instead of
wedging the catalog).

`compute_group` is the TSUBAME-style billing group (e.g.
`tga-kozuma-kouhi`). On TSUBAME 4 this is REQUIRED for normal-queue
jobs; submission without it routes to the wrong account or rejects.

`cuda_module` adds a `module load <name>` line above the julia call —
needed on TSUBAME because the GPU runtime is module-managed.
"""
struct UGEBackend <: AutopilotBackend
    ssh_host::Union{Nothing, String}
    max_concurrent::Union{Nothing, Int}
    project_root::String
    remote_runs_root::Union{Nothing, String}
    compute_group::String
    julia_path::String
    julia_depot::String   # `JULIA_DEPOT_PATH` for the submitted script (compute nodes don't inherit login env)
    sysimage_path::String # `-J <path>` for the submitted julia; empty = no sysimage (full JIT each job)
    cuda_module::String
    sync_code::Bool
end

UGEBackend(;
    ssh_host::Union{Nothing, AbstractString}=nothing,
    max_concurrent::Union{Nothing, Int}=nothing,
    project_root::AbstractString=pwd(),
    remote_runs_root::Union{Nothing, AbstractString}=nothing,
    compute_group::AbstractString="",
    julia_path::AbstractString="julia",
    julia_depot::AbstractString="",
    sysimage_path::AbstractString="",
    cuda_module::AbstractString="",
    sync_code::Bool=false,
) = UGEBackend(
    ssh_host === nothing ? nothing : String(ssh_host),
    max_concurrent,
    String(project_root),
    remote_runs_root === nothing ? nothing : String(remote_runs_root),
    String(compute_group),
    String(julia_path),
    String(julia_depot),
    String(sysimage_path),
    String(cuda_module),
    sync_code,
)

_uge_remote_run_dir(b::UGEBackend, entry::QueueEntry) =
    if (b.ssh_host === nothing || b.remote_runs_root === nothing)
        entry.run_dir
    else
        joinpath(b.remote_runs_root, basename(entry.run_dir))
    end

_uge_remote_spec_path(b::UGEBackend, entry::QueueEntry) =
    joinpath(_uge_remote_run_dir(b, entry), basename(entry.spec_path))

# UGE rejects job names that start with a digit ("not a valid object
# name"). Content IDs are hex, so prefix unconditionally. Used by both
# dispatch (as `qsub -N`) and reconcile (as the search key in
# `qstat`'s name column) so the two halves agree.
_uge_jobname(cid::AbstractString) = "sb_" * String(cid)

# ── render ───────────────────────────────────────────────────────────

"""
    render_uge_script(profile, config_path; project_root, julia_path,
                       cuda_module, jobname, compute_group) -> String

Render the full UGE submission script. The body cd's into `project_root`,
optionally `module load`s CUDA, sets `JULIA_NUM_THREADS` from the slot count
the profile asked for, and invokes `julia run_yaml <config_path>` — same shape
as the LocalBackend subprocess invocation, for byte-for-byte run-artifact
parity.

The script is the job's ENTIRE environment: `_uge_qsub_cmd` passes neither
`-V` nor `-v`, so anything the run needs from the environment has to be
exported here. `qsub -v JULIA_NUM_THREADS=<n>` still wins, because the export
defaults through it.
"""
function render_uge_script(profile::AbstractString, config_path::AbstractString;
    project_root::AbstractString,
    log_dir::AbstractString,
    julia_path::AbstractString="julia",
    julia_depot::AbstractString="",
    sysimage_path::AbstractString="",
    cuda_module::AbstractString="",
    jobname::AbstractString="spinorbec",
    compute_group::AbstractString="",  # kept in signature for symmetry; placed on qsub CLI, not in script
)
    prof = String(profile)
    haskey(UGE_PROFILE_DIRECTIVES, prof) ||
        throw(
            ArgumentError(
                "unknown UGE profile $prof; known: " *
                join(collect(keys(UGE_PROFILE_DIRECTIVES)), ","),
            ),
        )
    profile_lines = UGE_PROFILE_DIRECTIVES[prof]

    # Two non-portable conventions baked in:
    # (1) TSUBAME 4's qsub wrapper REJECTS `#$ -g <group>` as a script
    #     directive ("ERROR! invalid option argument '-g'"). The compute
    #     group is instead passed on the qsub command line by dispatch!
    #     via `_uge_qsub_cmd`. Keep this renderer free of -g.
    # (2) Absolute -o/-e paths land logs in the run_dir. `-cwd` plus
    #     relative `stdout.log`/`stderr.log` would land them in $HOME
    #     instead — ssh to TSUBAME starts in $HOME and qsub uses that
    #     as the job's initial cwd. The script body then `cd`s into
    #     project_root for the julia invocation.
    fixed = String[
        "#\$ -N $(jobname)",
        "#\$ -o $(log_dir)/stdout.log",
        "#\$ -e $(log_dir)/stderr.log",
    ]
    profile_directives = ["#\$ " * d for d in profile_lines]

    module_line = isempty(cuda_module) ? "" : "module load $(cuda_module)"
    depot_line = isempty(julia_depot) ? "" :
                 "export JULIA_DEPOT_PATH=\"$(julia_depot)\""
    sysimage_arg = isempty(sysimage_path) ? "" : "-J $(sysimage_path)"

    body = """
    #!/bin/bash
    $(join(fixed, "\n"))
    $(join(profile_directives, "\n"))
    #
    # Auto-generated by SpinorBEC.render_uge_script — profile=$(prof).
    # Edit UGE_PROFILE_DIRECTIVES in backends_uge.jl to change resource
    # caps. Submission writes a fresh script per job.

    set -euo pipefail
    . /etc/profile.d/modules.sh
    $(module_line)
    cd "$(project_root)" || exit 1

    # Compute nodes on TSUBAME do NOT inherit the login-node depot env,
    # so without this every job sees an empty ~/.julia and fails
    # with "Package X is required but does not seem to be installed".
    # Point at the lab's shared depot installed once on the login node.
    $(depot_line)

    # This script IS the whole environment the job gets: `_uge_qsub_cmd`
    # passes no `-V` and no `-v`, so nothing is inherited from the submitting
    # shell. Without this line every autopilot-dispatched run executed Julia
    # at its default of ONE thread, on a profile that had asked for 48 cores —
    # and the CPU hot paths are threaded (spin density, spin mixing,
    # singlet-pair, tensor, the DDI k-space contraction, the Euler spin
    # rotation, the Bogoliubov scan). UGE exports NSLOTS = the slot count the
    # profile requested; the `:-4` fallback matches scripts/tsubame_setup.sh
    # for the case where the rendered script is run by hand outside UGE.
    export JULIA_NUM_THREADS="\${JULIA_NUM_THREADS:-\${NSLOTS:-4}}"

    # Same snippet shape as LocalBackend's _LOCAL_RUN_SNIPPET so local
    # and remote dispatch produce byte-for-byte identical artefacts.
    # CUDA isn't `using`'d explicitly — SpinorBEC's extension fires
    # when CUDA is loaded (it lives in the project's deps).
    #
    # `-J <sysimage>` (when set) loads a pre-baked PackageCompiler
    # sysimage so first-output latency drops from ~30 s (cold JIT) to
    # ~2 s. Operator builds the sysimage once via the CLI helper —
    # rebuild only on Project.toml / Manifest.toml change.
    "$(julia_path)" $(sysimage_arg) --project=. -e 'using SpinorBEC; SpinorBEC.run_yaml(ARGS[1])' "$(config_path)"
    """
    return body
end

# ── command builders (separate so tests can assert shape) ────────────
#
# The SSH ControlMaster + rsync transport is shared with UMSBackend and
# lives in ssh_transport.jl (`_ssh_cm`, `_rsync_*`, Manifest-hash
# helpers). The `_uge_*` wrappers below adapt a UGEBackend to those
# primitives so the call sites (stage_in / pull_live / collect! /
# dispatch!) and the command-shape tests are unchanged.

_uge_mkdir_cmd(b::UGEBackend, remote_dir::AbstractString) =
    _ssh_mkdir_cmd(b.ssh_host, remote_dir)

_uge_rsync_config_cmd(b::UGEBackend, entry::QueueEntry,
    remote_dir::AbstractString) =
    _rsync_push_cmd(b.ssh_host, entry.spec_path, remote_dir)

_uge_pull_live_cmd(b::UGEBackend, entry::QueueEntry,
    remote_dir::AbstractString) =
    _rsync_pull_missing_cmd(b.ssh_host, "$(remote_dir)/_live_status.json",
        "$(entry.run_dir)/_live_status.json")

_uge_collect_cmd(b::UGEBackend, entry::QueueEntry,
    remote_dir::AbstractString) =
    _rsync_collect_cmd(b.ssh_host, remote_dir, entry.run_dir)

_uge_rsync_script_cmd(b::UGEBackend, local_script::AbstractString,
    remote_script::AbstractString) =
    _rsync_file_cmd(b.ssh_host, local_script, remote_script)

_uge_code_sync_cmd(b::UGEBackend) =
    _rsync_code_sync_cmd(b.ssh_host, _ssh_local_project_root(), b.project_root)

# Tested directly (test_autopilot.jl) — keep as a thin alias over the
# shared helper.
_uge_local_manifest_hash() = _ssh_local_manifest_hash()

"""
    _uge_instantiate_if_needed(b::UGEBackend) -> Bool

After `_uge_code_sync_cmd` rsyncs the local tree, run `Pkg.instantiate`
on the remote iff the local Manifest.toml hash differs from the remote's.
No-op when ssh_host is unset. Delegates to `_ssh_instantiate_if_needed`.
"""
_uge_instantiate_if_needed(b::UGEBackend) =
    if b.ssh_host === nothing
        false
    else
        _ssh_instantiate_if_needed(b.ssh_host, b.project_root, b.julia_path, b.julia_depot)
    end

function _uge_qsub_cmd(b::UGEBackend, remote_script::AbstractString)
    # On TSUBAME 4 `-g <group>` MUST be on the qsub command line (not as
    # a `#$ -g` script directive — the TSUBAME qsub wrapper rejects that
    # with "invalid option argument"). Skip the flag when compute_group
    # is unset — qsub then falls back to its "trial" mode (non-billed).
    base = if isempty(b.compute_group)
        `qsub $(remote_script)`
    else
        `qsub -g $(b.compute_group) $(remote_script)`
    end
    b.ssh_host === nothing ? base : `$(_ssh_cm(b.ssh_host)) $base`
end

_uge_qstat_cmd(b::UGEBackend, job_id::AbstractString) =
    b.ssh_host === nothing ?
    `qstat -j $(job_id)` :
    `$(_ssh_cm(b.ssh_host)) qstat -j $(job_id)`

_uge_qdel_cmd(b::UGEBackend, job_id::AbstractString) =
    b.ssh_host === nothing ?
    `qdel $(job_id)` :
    `$(_ssh_cm(b.ssh_host)) qdel $(job_id)`

# qstat plain listing: name in col 3, jobid in col 1. We grep by name
# for reconciliation. -u<user> would be more precise but $USER on the
# remote may differ from local; rely on the per-user default of qstat.
_uge_qstat_list_cmd(b::UGEBackend) =
    b.ssh_host === nothing ? `qstat` : `$(_ssh_cm(b.ssh_host)) qstat`

_uge_qacct_cmd(b::UGEBackend, job_id::AbstractString) =
    b.ssh_host === nothing ?
    `qacct -j $(job_id)` :
    `$(_ssh_cm(b.ssh_host)) qacct -j $(job_id)`

# ── data movement ────────────────────────────────────────────────────

function stage_in(b::UGEBackend, entry::QueueEntry)
    b.ssh_host === nothing && return nothing
    b.remote_runs_root === nothing && throw(
        ArgumentError(
            "UGEBackend stage_in: ssh_host=$(b.ssh_host) but remote_runs_root " *
            "is not set — pass remote_runs_root=<runs/ path on $(b.ssh_host)>"),
    )
    remote_dir = _uge_remote_run_dir(b, entry)
    run(_uge_mkdir_cmd(b, remote_dir))
    run(_uge_rsync_config_cmd(b, entry, remote_dir))
    if b.sync_code
        run(_uge_code_sync_cmd(b))
        # Auto Pkg.instantiate when local Manifest.toml has changed
        # since the last instantiate on this remote — cheap no-op
        # when unchanged (one ssh + cat of a 64-char file).
        _uge_instantiate_if_needed(b)
    end
    return nothing
end

function pull_live(b::UGEBackend, entry::QueueEntry)
    (b.ssh_host === nothing || b.remote_runs_root === nothing) && return nothing
    remote_dir = _uge_remote_run_dir(b, entry)
    isdir(entry.run_dir) || mkpath(entry.run_dir)
    try
        run(_uge_pull_live_cmd(b, entry, remote_dir))
    catch err
        @warn "pull_live rsync failed (treating as transient)" cid=entry.content_id exception=err
    end
    return nothing
end

function collect!(b::UGEBackend, entry::QueueEntry)
    (b.ssh_host === nothing || b.remote_runs_root === nothing) && return nothing
    remote_dir = _uge_remote_run_dir(b, entry)
    isdir(entry.run_dir) || mkpath(entry.run_dir)
    run(_uge_collect_cmd(b, entry, remote_dir))
    return nothing
end

# ── dispatch ─────────────────────────────────────────────────────────

# qsub stdout format: "Your job NNNN ("name") has been submitted" — pull
# the first all-digits token from the first non-empty line.
function _parse_qsub_jobid(out::AbstractString)
    for line in eachsplit(strip(out), '\n')
        isempty(line) && continue
        m = match(r"\b(\d+)\b", line)
        m === nothing || return String(m.captures[1])
    end
    throw(ErrorException("qsub returned no jobid: $(strip(out))"))
end

function dispatch!(b::UGEBackend, entry::QueueEntry)
    profile = isempty(entry.profile) ? "default" : entry.profile
    eff_config_path = _uge_remote_spec_path(b, entry)
    script = render_uge_script(profile, eff_config_path;
        project_root=b.project_root,
        log_dir=_uge_remote_run_dir(b, entry),
        julia_path=b.julia_path,
        julia_depot=b.julia_depot,
        sysimage_path=b.sysimage_path,
        cuda_module=b.cuda_module,
        jobname=_uge_jobname(entry.content_id),
        compute_group=b.compute_group)

    script_dir = joinpath(entry.run_dir, ".autopilot")
    isdir(script_dir) || mkpath(script_dir)
    local_script_path = joinpath(script_dir, "submit.uge.sh")
    open(local_script_path, "w") do io
        write(io, script)
    end

    remote_script = if b.ssh_host === nothing
        local_script_path
    else
        rs = joinpath(_uge_remote_run_dir(b, entry), "submit.uge.sh")
        run(_uge_rsync_script_cmd(b, local_script_path, rs))
        rs
    end

    out = read(_uge_qsub_cmd(b, remote_script), String)
    job_id = _parse_qsub_jobid(out)
    entry.job_id = job_id
    return true
end

# ── status / cancel / reconcile / failure reason ─────────────────────

# UGE job_state codes (from `man qstat`, listing mode column 5):
#   r/t = running/transferring
#   qw/hqw/hRwq = pending (queued, waiting, restart-pending)
#   E* (Eqw etc.) = error state
#   d* = being deleted
#
# Why listing mode, not `qstat -j`: on TSUBAME 4 the detail output of
# `qstat -j <id>` does NOT include a `job_state:` field (it contains
# `job_number`, `submission_time`, `script_file`, ... but no state).
# The state lives in the plain `qstat` table, column 5. So we parse
# the listing and key off the job-ID column.
# Pre-fetch the full `qstat` listing once per tick (shared across all
# running entries for this backend). The reap loop calls this and
# passes the result back into `job_status` via `snapshot=`.
prepare_status_snapshot(b::UGEBackend) =
    try
        read(pipeline(_uge_qstat_list_cmd(b); stderr=devnull), String)
    catch
        nothing
    end

function job_status(b::UGEBackend, entry::QueueEntry;
    snapshot::Union{Nothing, AbstractString}=nothing)
    entry.job_id === nothing && return :unknown
    job_id = entry.job_id
    listing = if snapshot !== nothing
        snapshot   # tick supplied a cached listing — no round-trip
    else
        out = try
            read(pipeline(_uge_qstat_list_cmd(b); stderr=devnull), String)
        catch
            return :unknown   # transient ssh / qstat failure; next tick retries
        end
        out
    end
    state = _uge_extract_job_state_from_listing(listing, job_id)
    if state == "pending"
        return :pending
    elseif state == "running"
        return :running
    elseif state == "failed"
        return :failed
    elseif state == "absent"
        # Not in the active listing → scheduler considers it terminal.
        # `_exit_summary.json`, collected from the node, is the authoritative
        # done/failed signal (qacct can lag minutes on TSUBAME and often returns
        # "not found" for short jobs).
        #
        # This read `outcome.toml` and its comment called it "landed by
        # `collect!`". `collect!` does not write that file and nothing else does
        # either — the only writer was the dry-run synthetic in `tick.jl`. Since
        # `run_dir` is content-addressed and the rsync collect carries no
        # `--delete`, a dry run left `terminal = "done"` where a LATER LIVE run
        # of the same spec would find it, and any live job that vanished from
        # `qstat` — crash, OOM, node failure — was returned `:done`. A crashed
        # job reported as successfully completed, then credited to its recipe's
        # trust store.
        collect!(b, entry)
        let d = _read_exit_summary(entry)
            if d !== nothing
                get(d, "completed", false) === true && return :done
                # A summary that exists and says otherwise is a real failure;
                # its CAUSE is `_classify_terminal_failure`'s job, not this
                # function's.
                return :failed
            end
        end
        # No `_exit_summary.json` yet — last resort, try qacct. If still no
        # record, return :unknown (next tick retries).
        return _uge_terminal_state(b, job_id)
    end
    return :unknown
end

# Parse plain `qstat` table output, find the row for `job_id`, and
# normalise the state column (5) into pending / running / failed /
# absent. Listing format:
#   job-ID  prior  name  user  state  submit/start at  queue ...  slots
# Header lines are skipped (first column is not all-digits).
function _uge_extract_job_state_from_listing(listing::AbstractString,
    job_id::AbstractString)
    for line in eachsplit(listing, '\n')
        cols = split(strip(line))
        length(cols) >= 5 || continue
        all(isdigit, cols[1]) || continue
        cols[1] == String(job_id) || continue
        state = cols[5]
        occursin(r"^(qw|hqw|hRwq)$"i, state) && return "pending"
        (startswith(state, "r") || startswith(state, "t")) && return "running"
        (startswith(state, "E") || startswith(state, "d")) && return "failed"
        return "running"   # unknown active state code; assume in-flight
    end
    return "absent"
end

# Last-resort terminal classification via qacct. Used only when the
# job is no longer in qstat AND `_exit_summary.json` has not landed yet. qacct
# on TSUBAME can lag minutes after job exit and may return
# "error: job id N not found" for short jobs that didn't make it into
# accounting (e.g. early script failure with bad directives).
function _uge_terminal_state(b::UGEBackend, job_id::AbstractString)
    out = try
        read(pipeline(_uge_qacct_cmd(b, job_id); stderr=devnull), String)
    catch
        return :unknown
    end
    m = match(r"^exit_status\s+(\d+)"m, out)
    m === nothing && return :unknown
    return parse(Int, m.captures[1]) == 0 ? :done : :failed
end

function cancel!(b::UGEBackend, entry::QueueEntry)
    entry.job_id === nothing && return false
    try
        run(_uge_qdel_cmd(b, entry.job_id))
        return true
    catch err
        @warn "qdel failed" job_id=entry.job_id exception=err
        return false
    end
end

# Reconciliation: scan `qstat` for a job whose name column matches the
# `sb_<cid>` shape dispatch used. The caller passes `entry.content_id`
# raw, so wrap with `_uge_jobname` to stay symmetric with dispatch.
function find_job_by_name(b::UGEBackend, name::AbstractString)
    out = try
        read(_uge_qstat_list_cmd(b), String)
    catch err
        @warn "qstat probe failed" exception=err
        return nothing
    end
    target = _uge_jobname(name)
    for line in eachsplit(out, '\n')
        cols = split(strip(line))
        length(cols) >= 3 || continue
        # Header lines start with letters / dashes; skip.
        all(isdigit, cols[1]) || continue
        cols[3] == target || continue
        return String(cols[1])
    end
    return :no_such_job
end

# Backend-side failure reason: prefer qacct's failed/exit_status line.
function backend_failure_reason(b::UGEBackend, entry::QueueEntry)
    entry.job_id === nothing && return "no job_id"
    out = try
        read(_uge_qacct_cmd(b, entry.job_id), String)
    catch
        return "qacct probe failed"
    end
    failed = match(r"^failed\s+(.+?)$"m, out)
    exit_status = match(r"^exit_status\s+(\d+)", out)
    parts = String[]
    failed === nothing || push!(parts, "failed=" * strip(String(failed.captures[1])))
    exit_status === nothing || push!(parts, "exit_status=" * String(exit_status.captures[1]))
    isempty(parts) && return "qacct returned no failed/exit_status fields"
    return join(parts, " ")
end

# ── retry-escalation hook ────────────────────────────────────────────

# Backend-aware next_profile so retry.jl's resource-permanent escalation
# walks the UGE table when the entry was dispatched on a UGEBackend.
# Default fallback on AutopilotBackend (in backends.jl) returns nothing.
next_profile(::UGEBackend, current::AbstractString) =
    get(UGE_PROFILE_ESCALATION, String(current), nothing)
