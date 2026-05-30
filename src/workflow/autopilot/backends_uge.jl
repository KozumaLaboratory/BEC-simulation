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

# Escalation for retry.jl when a RESOURCE_PERMANENT failure (OOM / timeout)
# is classified. Goes wider on memory/CPU (node_q → node_h → node_f) then
# stops. `nothing` = no escalation, retry policy gives up.
const UGE_PROFILE_ESCALATION = Dict{String, Union{Nothing, String}}(
    "default" => "node_h",
    "node_h" => "node_f",
    "node_f" => nothing,
    "gpu_1" => "default",
    "long_q" => nothing,
)

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
    cuda_module::AbstractString="",
    sync_code::Bool=false,
) = UGEBackend(
    ssh_host === nothing ? nothing : String(ssh_host),
    max_concurrent,
    String(project_root),
    remote_runs_root === nothing ? nothing : String(remote_runs_root),
    String(compute_group),
    String(julia_path),
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

# ── render ───────────────────────────────────────────────────────────

"""
    render_uge_script(profile, config_path; project_root, julia_path,
                       cuda_module, jobname, compute_group) -> String

Render the full UGE submission script. The body cd's into `project_root`,
optionally `module load`s CUDA, and invokes `julia run_yaml <config_path>`
— same shape as the LocalBackend subprocess invocation, for byte-for-byte run-artifact parity.
"""
function render_uge_script(profile::AbstractString, config_path::AbstractString;
    project_root::AbstractString,
    julia_path::AbstractString="julia",
    cuda_module::AbstractString="",
    jobname::AbstractString="spinorbec",
    compute_group::AbstractString="",
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

    fixed = String[
        "#\$ -cwd",
        "#\$ -N $(jobname)",
        "#\$ -o stdout.log",
        "#\$ -e stderr.log",
    ]
    isempty(compute_group) || push!(fixed, "#\$ -g $(compute_group)")
    profile_directives = ["#\$ " * d for d in profile_lines]

    module_line = isempty(cuda_module) ? "" : "module load $(cuda_module)"

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

    "$(julia_path)" --project=. -e '
        using CUDA, SpinorBEC
        report_cuda_state()
        estimate_run_budget(ARGS[1])
        run_yaml(ARGS[1])
    ' "$(config_path)"
    """
    return body
end

# ── command builders (separate so tests can assert shape) ────────────

_uge_mkdir_cmd(b::UGEBackend, remote_dir::AbstractString) =
    `ssh $(b.ssh_host) mkdir -p $(remote_dir)`

_uge_rsync_config_cmd(b::UGEBackend, entry::QueueEntry,
    remote_dir::AbstractString) =
    `rsync -e ssh $(entry.spec_path) $(b.ssh_host):$(remote_dir)/`

_uge_pull_live_cmd(b::UGEBackend, entry::QueueEntry,
    remote_dir::AbstractString) =
    `rsync -e ssh --ignore-missing-args $(b.ssh_host):$(remote_dir)/_live_status.json $(entry.run_dir)/_live_status.json`

_uge_collect_cmd(b::UGEBackend, entry::QueueEntry,
    remote_dir::AbstractString) =
    `rsync -av -e ssh --exclude=state.toml --exclude=.state.lock $(b.ssh_host):$(remote_dir)/ $(entry.run_dir)/`

_uge_rsync_script_cmd(b::UGEBackend, local_script::AbstractString,
    remote_script::AbstractString) =
    `rsync -e ssh $(local_script) $(b.ssh_host):$(remote_script)`

function _uge_code_sync_cmd(b::UGEBackend, code_sha::AbstractString)
    sha = replace(code_sha, r"-dirty$" => "")
    snippet =
        "cd $(b.project_root) && git fetch --quiet && " *
        "git checkout --quiet $(sha) && " *
        "$(b.julia_path) --project=. -e 'using Pkg; Pkg.instantiate()'"
    `ssh $(b.ssh_host) bash -lc $(snippet)`
end

_uge_qsub_cmd(b::UGEBackend, remote_script::AbstractString) =
    b.ssh_host === nothing ?
    `qsub $(remote_script)` :
    `ssh $(b.ssh_host) qsub $(remote_script)`

_uge_qstat_cmd(b::UGEBackend, job_id::AbstractString) =
    b.ssh_host === nothing ?
    `qstat -j $(job_id)` :
    `ssh $(b.ssh_host) qstat -j $(job_id)`

_uge_qdel_cmd(b::UGEBackend, job_id::AbstractString) =
    b.ssh_host === nothing ?
    `qdel $(job_id)` :
    `ssh $(b.ssh_host) qdel $(job_id)`

# qstat plain listing: name in col 3, jobid in col 1. We grep by name
# for reconciliation. -u<user> would be more precise but $USER on the
# remote may differ from local; rely on the per-user default of qstat.
_uge_qstat_list_cmd(b::UGEBackend) =
    b.ssh_host === nothing ? `qstat` : `ssh $(b.ssh_host) qstat`

_uge_qacct_cmd(b::UGEBackend, job_id::AbstractString) =
    b.ssh_host === nothing ?
    `qacct -j $(job_id)` :
    `ssh $(b.ssh_host) qacct -j $(job_id)`

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
    if b.sync_code && !isempty(entry.code_sha)
        run(_uge_code_sync_cmd(b, entry.code_sha))
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
        julia_path=b.julia_path,
        cuda_module=b.cuda_module,
        jobname=entry.content_id,
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

# UGE job_state codes (from `man qstat`):
#   r/t = running/transferring
#   qw/hqw/hRwq = pending (queued, waiting, restart-pending)
#   E* (Eqw etc.) = error state
#   d* = being deleted
# When qstat -j <id> says the job doesn't exist (returns nonzero), the
# job is terminal — fall back to qacct -j <id> for the exit_status.
function job_status(b::UGEBackend, entry::QueueEntry)
    entry.job_id === nothing && return :unknown
    job_id = entry.job_id
    state = try
        _uge_extract_job_state(read(_uge_qstat_cmd(b, job_id), String))
    catch
        # qstat -j errors when the job is no longer in the active list.
        return _uge_terminal_state(b, job_id)
    end
    isempty(state) && return _uge_terminal_state(b, job_id)
    if occursin(r"^(qw|hqw|hRwq)$"i, state)
        return :pending
    elseif startswith(state, "r") || startswith(state, "t")
        return :running
    elseif startswith(state, "E") || startswith(state, "d")
        return :failed
    end
    return :unknown
end

# Pull the "job_state" field from `qstat -j <id>` output (free-form KEY VALUE
# lines). UGE prints state on a line like "job_state                   r".
function _uge_extract_job_state(out::AbstractString)
    for line in eachsplit(out, '\n')
        m = match(r"^job_state\s+(\S+)", line)
        m === nothing && continue
        return String(m.captures[1])
    end
    return ""
end

function _uge_terminal_state(b::UGEBackend, job_id::AbstractString)
    out = try
        read(_uge_qacct_cmd(b, job_id), String)
    catch
        # qacct unavailable / job not yet recorded → caller treats as :unknown,
        # next tick retries.
        return :unknown
    end
    m = match(r"^exit_status\s+(\d+)", out)
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

# Reconciliation: scan `qstat` for a job whose name (col 3) == content_id.
function find_job_by_name(b::UGEBackend, name::AbstractString)
    out = try
        read(_uge_qstat_list_cmd(b), String)
    catch err
        @warn "qstat probe failed" exception=err
        return nothing
    end
    for line in eachsplit(out, '\n')
        cols = split(strip(line))
        length(cols) >= 3 || continue
        # Header lines start with letters / dashes; skip.
        all(isdigit, cols[1]) || continue
        cols[3] == String(name) || continue
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
