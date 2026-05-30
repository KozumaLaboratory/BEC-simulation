# ── Dispatch backends (ExecutionTarget contract) ──────────────────────
#
# Each backend implements the contract below. The dashboard / catalog /
# inspector NEVER branch on backend: they only ever read canonical local
# `runs/<cid>/`. Every backend is responsible for making its run_dir
# appear there — local does so by being local (no-ops), remote does so
# by `stage_in` (push config out) + `pull_live` (refresh live status) +
# `collect!` (pull results back). This confines remote-ness to one place.
#
#   stage_in(b, entry)         # place config + code where the job runs
#   dispatch!(b, entry)        # start the run; mutates entry.job_id
#   job_status(b, entry)       # → :pending | :running | :done | :failed | :unknown
#   pull_live(b, entry)        # refresh _live_status.json in local runs/
#   collect!(b, entry)         # mirror results into local runs/<cid>/
#   cancel!(b, entry)          # request cancellation
#   find_job_by_name(b, name)  # reconcile after mid-submit crash
#   backend_failure_reason(b, entry)  # post-mortem string
#   next_profile(b, profile)   # retry-escalation: next resource tier or nothing
#
# `stage_in`, `pull_live`, `collect!` have default no-op fallbacks on
# `AutopilotBackend` so a fully-local backend declares nothing extra.
# `next_profile` defaults to `nothing` (no escalation) so a backend
# without a profile ladder simply caps at its current tier.
#
# `LocalBackend` runs jobs in a **detached subprocess** writing to
# `runs/<cid>/` (same shape the UGE submit script writes), so kill /
# GPU isolation / concurrency match the remote backend and the
# dashboard process never holds the GPU. `UGEBackend` lives in
# `backends_uge.jl`.

export LocalBackend,
    stage_in, dispatch!, job_status, pull_live, collect!, cancel!,
    find_job_by_name, backend_failure_reason, next_profile

# Default no-op contract methods. Local execution lives in the canonical
# place already, so a backend that doesn't override these is implicitly
# local-shape (entry.run_dir IS where the job runs and where results land).
stage_in(::AutopilotBackend, entry) = nothing
pull_live(::AutopilotBackend, entry) = nothing
collect!(::AutopilotBackend, entry) = nothing

# Default retry-escalation: no further resource tier. Backends with a
# profile ladder (UGEBackend) override this.
next_profile(::AutopilotBackend, current::AbstractString) = nothing

# `AutopilotBackend` abstract type is declared in types.jl.

# Local subprocess backend ────────────────────────────────────────────

# Julia snippet the subprocess runs. Identical-shape to the UGE script
# body (render_uge_script) so local and remote dispatch produce
# byte-for-byte identical run artefacts under runs/<cid>/.
const _LOCAL_RUN_SNIPPET = """
using SpinorBEC
SpinorBEC.run_yaml(ARGS[1])
"""

"""
    LocalBackend(; max_concurrent=1, project_root=pwd(),
                 julia_bin="julia", extra_env=Pair{String,String}[])

Run jobs in a **detached subprocess** via
`julia --project=<project_root> -e 'using SpinorBEC; run_yaml(ARGS[1])'
<spec_path>`. The spawned process writes `summary.json` / `outcome.toml`
/ `_live_status.json` / `*.jld2` into `entry.run_dir` — the same layout
the UGE submit script produces — so the dashboard and
`run_catalog_index` never need to branch on local-vs-remote.

`max_concurrent=1` is the single-GPU desktop default. `cancel!` actually
kills the subprocess (was a no-op under the old `Threads.@spawn` model).
`LD_LIBRARY_PATH=/usr/lib/wsl/lib` is set automatically when not already
present — required for WSL2 GPU runs, harmless otherwise.

`entry.job_id` is set to the subprocess's OS pid (string). `_running`
keys on `content_id` so `find_job_by_name(content_id)` reconciles a
zombie after a mid-submit crash in the same process — for cross-process
recovery (autopilot restart), the subprocess will have been re-parented
to init and we can't adopt it; the next tick falls through to
`:gave_up` and the entry rolls to `:killed_bug`.
"""
struct LocalBackend <: AutopilotBackend
    max_concurrent::Int
    project_root::String
    julia_bin::String
    extra_env::Vector{Pair{String, String}}
    _running::Dict{String, Base.Process}    # content_id => Process
end

function LocalBackend(;
    max_concurrent::Int=1,
    project_root::AbstractString=pwd(),
    julia_bin::AbstractString="julia",
    extra_env=Pair{String, String}[],
)
    env_vec = Pair{String, String}[String(k) => String(v) for (k, v) in extra_env]
    LocalBackend(max_concurrent, String(project_root), String(julia_bin),
        env_vec, Dict{String, Base.Process}())
end

function n_running(b::LocalBackend)
    n = 0
    for (_, p) in b._running
        process_running(p) && (n += 1)
    end
    return n
end

function dispatch!(b::LocalBackend, entry::QueueEntry)
    n_running(b) >= b.max_concurrent && return false   # backend full

    log_dir = joinpath(entry.run_dir, ".autopilot")
    isdir(log_dir) || mkpath(log_dir)
    out_path = joinpath(log_dir, "stdout.log")
    err_path = joinpath(log_dir, "stderr.log")

    cmd = `$(b.julia_bin) --project=$(b.project_root) -e $(_LOCAL_RUN_SNIPPET) $(entry.spec_path)`

    env = copy(ENV)
    haskey(env, "LD_LIBRARY_PATH") || (env["LD_LIBRARY_PATH"] = "/usr/lib/wsl/lib")
    for (k, v) in b.extra_env
        env[k] = v
    end

    p = try
        run(pipeline(detach(setenv(cmd, env));
                stdout=out_path, stderr=err_path); wait=false)
    catch err
        @warn "LocalBackend dispatch! failed to spawn subprocess" cid=entry.content_id exception=err
        return false
    end

    b._running[entry.content_id] = p
    entry.job_id = string(getpid(p))
    return true
end

function job_status(b::LocalBackend, entry::QueueEntry)
    entry.job_id === nothing && return :unknown
    p = get(b._running, entry.content_id, nothing)
    p === nothing && return :unknown
    if process_running(p)
        return :running
    elseif success(p)
        return :done
    else
        return :failed
    end
end

function cancel!(b::LocalBackend, entry::QueueEntry)
    p = get(b._running, entry.content_id, nothing)
    p === nothing && return false
    process_running(p) || return false
    try
        kill(p)
        return true
    catch err
        @warn "LocalBackend kill failed" cid=entry.content_id exception=err
        return false
    end
end

# Returns the subprocess pid (string) when we still have a handle; only
# useful for in-process zombie reconciliation. Across-process recovery
# is not supported — a fresh LocalBackend has an empty table.
function find_job_by_name(b::LocalBackend, name::AbstractString)
    p = get(b._running, String(name), nothing)
    p === nothing && return :no_such_job
    return string(getpid(p))
end

function backend_failure_reason(b::LocalBackend, entry::QueueEntry)
    p = get(b._running, entry.content_id, nothing)
    p === nothing && return "unknown (subprocess not in local table)"
    process_running(p) && return "still running"
    code = p.exitcode
    code == 0 && return "completed (exit 0)"
    tail = try
        err_path = joinpath(entry.run_dir, ".autopilot", "stderr.log")
        if isfile(err_path)
            sz = stat(err_path).size
            open(err_path, "r") do io
                seek(io, max(0, sz - 4096))
                String(read(io))
            end
        else
            ""
        end
    catch
        ""
    end
    return "subprocess exit $(code)" * (isempty(tail) ? "" : " | tail: $(tail)")
end
