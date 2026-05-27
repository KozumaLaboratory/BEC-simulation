# ── Dispatch backends ─────────────────────────────────────────────────
#
# Each backend implements three operations:
#
#   dispatch!(backend, entry)        # start the run; mutates entry.job_id
#   job_status(backend, entry)       # → :running | :done | :failed | :unknown
#   cancel!(backend, entry)          # request cancellation
#
# `LocalBackend` executes `run!` inline — used by tests and the
# single-machine workflow. `SlurmBackend` shells out via sbatch/squeue/
# scancel (optionally over SSH).

export LocalBackend, SlurmBackend,
    dispatch!, job_status, cancel!,
    find_job_by_name, backend_failure_reason,
    PROFILE_TEMPLATES, next_profile

# Profile → sbatch template path. Each profile maps to a script with
# different resource declarations (mem, walltime, GPU type). Escalation
# (default → single_h100 → ...) is used by retry.jl for OOM failures
# so the next attempt has more headroom.
const PROFILE_TEMPLATES = Dict{String, String}(
    "default" => "scripts/slurm/eu151_h100_single.sbatch",
    "single_h100" => "scripts/slurm/eu151_h100_single.sbatch",
)

# Linear chain of escalation. Returns the next profile in the table, or
# `nothing` if no further headroom is registered.
const PROFILE_ESCALATION = Dict{String, Union{Nothing, String}}(
    "default" => "single_h100",
    "single_h100" => nothing,
)

next_profile(current::AbstractString) = get(PROFILE_ESCALATION, String(current), nothing)

# `AutopilotBackend` abstract type is declared in types.jl.

# Local in-process backend ─────────────────────────────────────────────

"""
    LocalBackend(; max_concurrent=1)

Run jobs in the same Julia process via `run!(Experiment(...))`.
`max_concurrent=1` means strict serial — appropriate for testing and
single-GPU desktops. Sets `entry.job_id = entry.content_id` for tracking.
"""
struct LocalBackend <: AutopilotBackend
    max_concurrent::Int
    _running::Dict{String, Task}    # content_id => Task
end

LocalBackend(; max_concurrent::Int=1) = LocalBackend(max_concurrent, Dict{String, Task}())

n_running(b::LocalBackend) = count(t -> !istaskdone(t), values(b._running))

function dispatch!(b::LocalBackend, entry::QueueEntry)
    n_running(b) >= b.max_concurrent && return false   # backend full
    t = Threads.@spawn try
        exp = Experiment(entry.spec_path)
        run!(exp)
    catch err
        @warn "LocalBackend run! threw" entry=entry.content_id exception=err
        rethrow(err)
    end
    b._running[entry.content_id] = t
    entry.job_id = entry.content_id
    return true
end

function job_status(b::LocalBackend, entry::QueueEntry)
    job_id = entry.job_id
    job_id === nothing && return :unknown
    t = get(b._running, String(job_id), nothing)
    t === nothing && return :unknown
    if !istaskdone(t)
        return :running
    elseif istaskfailed(t)
        return :failed
    else
        return :done
    end
end

function cancel!(b::LocalBackend, entry::QueueEntry)
    @warn "LocalBackend.cancel! is a no-op (Julia tasks can't be killed)" cid=entry.content_id
    return false
end

function find_job_by_name(b::LocalBackend, name::AbstractString)
    haskey(b._running, String(name)) ? String(name) : :no_such_job
end

function backend_failure_reason(b::LocalBackend, entry::QueueEntry)
    job_id = entry.job_id
    job_id === nothing && return "no job_id"
    t = get(b._running, String(job_id), nothing)
    t === nothing && return "unknown (task not in local table)"
    if istaskfailed(t)
        return "LocalBackend task threw: " * sprint(showerror, t.exception)
    end
    return "completed without failure"
end

# SLURM backend ────────────────────────────────────────────────────────

"""
    SlurmBackend(;
        sbatch_template = "scripts/slurm/eu151_h100_single.sbatch",
        ssh_host = nothing,             # nothing → run sbatch locally
        max_concurrent = nothing,       # nothing → let SLURM fair-share decide
    )

Shells out to `sbatch <template> <config.yaml>`. When `ssh_host` is set,
prepends `ssh <host>` so the autopilot can run on a non-SLURM machine
(e.g. WSL) while the cluster sits behind SSH.
"""
struct SlurmBackend <: AutopilotBackend
    sbatch_template::String
    ssh_host::Union{Nothing, String}
    max_concurrent::Union{Nothing, Int}
end

SlurmBackend(;
sbatch_template::AbstractString="scripts/slurm/eu151_h100_single.sbatch",
ssh_host::Union{Nothing, AbstractString}=nothing,
max_concurrent::Union{Nothing, Int}=nothing
) = SlurmBackend(String(sbatch_template),
    ssh_host === nothing ? nothing : String(ssh_host),
    max_concurrent)

function dispatch!(b::SlurmBackend, entry::QueueEntry)
    # Profile override on the entry > backend default template.
    template = if entry.profile == "default"
        b.sbatch_template
    else
        haskey(PROFILE_TEMPLATES, entry.profile) ||
            throw(
                ArgumentError(
                    "Unknown profile $(entry.profile); known: $(keys(PROFILE_TEMPLATES))"
                ),
            )
        PROFILE_TEMPLATES[entry.profile]
    end
    # --job-name=<content_id> enables reconciliation after mid-submit
    # crash: squeue --name=<content_id> can re-locate the job.
    cmd = if b.ssh_host === nothing
        `sbatch --parsable --job-name=$(entry.content_id) $template $(entry.spec_path)`
    else
        `ssh $(b.ssh_host) sbatch --parsable --job-name=$(entry.content_id) $template $(entry.spec_path)`
    end
    job_id = strip(read(cmd, String))
    isempty(job_id) && throw(ErrorException("sbatch returned empty job id"))
    entry.job_id = String(job_id)
    return true
end

function job_status(b::SlurmBackend, entry::QueueEntry)
    job_id = entry.job_id
    job_id === nothing && return :unknown
    cmd = if b.ssh_host === nothing
        `squeue --noheader -j $(job_id) -h -o "%T"`
    else
        `ssh $(b.ssh_host) squeue --noheader -j $(job_id) -h -o "%T"`
    end
    state = try
        strip(read(cmd, String))
    catch
        return :unknown
    end
    if isempty(state)
        return _slurm_terminal_state(b, job_id)
    elseif state in ("PENDING", "CONFIGURING")
        return :pending
    elseif state in ("RUNNING", "COMPLETING")
        return :running
    elseif state == "COMPLETED"
        return :done
    else
        return :failed
    end
end

function _slurm_terminal_state(b::SlurmBackend, job_id::AbstractString)
    cmd = if b.ssh_host === nothing
        `sacct --noheader -j $(job_id) --format=State -P`
    else
        `ssh $(b.ssh_host) sacct --noheader -j $(job_id) --format=State -P`
    end
    state = try
        first(split(strip(read(cmd, String)), '\n'))
    catch
        return :unknown
    end
    state == "COMPLETED" ? :done : :failed
end

function cancel!(b::SlurmBackend, entry::QueueEntry)
    job_id = entry.job_id
    job_id === nothing && return false
    cmd = if b.ssh_host === nothing
        `scancel $(job_id)`
    else
        `ssh $(b.ssh_host) scancel $(job_id)`
    end
    try
        run(cmd)
        return true
    catch err
        @warn "scancel failed" job_id=job_id exception=err
        return false
    end
end

# Reconciliation: look up a job by its sbatch --job-name. Returns the job
# ID if SLURM still sees it, :no_such_job if not, nothing on probe error.
function find_job_by_name(b::SlurmBackend, name::AbstractString)
    cmd = if b.ssh_host === nothing
        `squeue --noheader -h --name=$(name) -o "%i"`
    else
        `ssh $(b.ssh_host) squeue --noheader -h --name=$(name) -o "%i"`
    end
    out = try
        strip(read(cmd, String))
    catch err
        @warn "squeue --name probe failed" exception=err
        return nothing
    end
    isempty(out) && return :no_such_job
    return String(first(split(out, '\n')))
end

# Post-mortem reason from sacct (OOM_KILLED / TIMEOUT / NODE_FAIL / ...).
function backend_failure_reason(b::SlurmBackend, entry::QueueEntry)
    job_id = entry.job_id
    job_id === nothing && return "no job_id"
    cmd = if b.ssh_host === nothing
        `sacct --noheader -j $(job_id) --format=State,Reason,ExitCode -P`
    else
        `ssh $(b.ssh_host) sacct --noheader -j $(job_id) --format=State,Reason,ExitCode -P`
    end
    line = try
        first(split(strip(read(cmd, String)), '\n'))
    catch
        return "sacct probe failed"
    end
    return String(line)
end
