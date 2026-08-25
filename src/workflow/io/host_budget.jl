# --- Host resource budget: every limit DERIVED from the host, none chosen. ----
#
# WHY THIS EXISTS
#
# The same run has to be right on a laptop, on WSL2 beside a browser the user is
# typing into, inside a container, and on a compute node the scheduler has carved
# out. The usual answer is a table of hostnames or a fudge factor ("use half the
# cores, leave 4 GB"). Both rot, and neither can say why its number is that
# number. So there is no number here: each limit is READ from the host, and the
# report names which file or environment variable it came from.
#
# The ladder, per quantity, most authoritative first:
#
#   1. the batch allocation      — SLURM / UGE (TSUBAME) / PBS. When a scheduler
#                                  has granted the job N cpus and M bytes, that
#                                  IS the answer and the node's totals are a lie.
#   2. the cgroup v2 limit       — containers, systemd slices, WSL2. What the
#                                  kernel will actually enforce on us.
#   3. what the OS lets us see   — the CPU AFFINITY MASK (not the machine's core
#                                  count) and MemAvailable, which is the kernel's
#                                  own estimate of "how much can be allocated
#                                  without swapping". That estimate is exactly
#                                  the quantity wanted, already computed, and it
#                                  is measured rather than guessed.
#
# On top of that, one term that only exists on an interactive host:
#
#   4. the interactive reserve   — `memory.peak - memory.current` of the user's
#                                  login session. That is how much MORE the
#                                  desktop has historically needed than it holds
#                                  right now: a measured growth headroom, not a
#                                  chosen margin. Where no login session cgroup
#                                  exists there is no desktop to protect and the
#                                  term is zero BY OBSERVATION. Where the session
#                                  exists but the counter cannot be read, this
#                                  REFUSES — an unreadable reserve must not be
#                                  spelled the same as a reserve of zero.
#
# WHAT IS DELIBERATELY NOT HERE
#
# `MemoryHigh`. Measured 2026-08-24 on this tree: a cgroup with MemoryHigh below
# MemoryMax and swap forbidden does not die, it LIVELOCKS in reclaim —
# `memory.events` read `high 2560, max 0, oom_kill 0` with the process pinned at
# the cap making no progress. A hung job that never reports is worse than a
# killed one, so the enforcement uses MemoryMax alone, which was measured to give
# a clean `CONSTRAINT_MEMCG` kill and exit status 137 with the global swap
# unchanged to the byte.
#
# `CPUQuota`. The goal is that the user's own typing stays responsive, and a
# quota buys that by leaving the machine idle when the user is not typing.
# `CPUWeight` at the cgroup interface's own defined minimum buys it without the
# waste: the job yields whenever anything else runs, and takes the whole machine
# when nothing does. The minimum of a documented range is not a magic number.

export HostBudget, BlindBudget, detect_host_budget
export budget_report, budget_env, budget_scope_properties

"""
    BlindBudget(quantity, source, detail)

Thrown when a quantity is observably PRESENT but could not be read.

This is the distinction the whole file turns on. "There is no login session, so
the reserve is zero" is a determination. "There is a login session but its
`memory.peak` would not open" is a failure to measure, and filling it with zero
would hand the job the desktop's headroom while reporting a derived number.
Absent is missing; it is never a default.
"""
struct BlindBudget <: Exception
    quantity::Symbol
    source::String
    detail::String
end

function Base.showerror(io::IO, e::BlindBudget)
    print(io, "BlindBudget: could not derive ", e.quantity, " from ", e.source,
        ". ", e.detail,
        "\nRefusing to substitute a default — a budget nobody measured must not ",
        "read as a budget that is safe. Set the matching SPINORBEC_HOST_* ",
        "override to state the value deliberately.")
end

"""
    HostBudget

What this host will give a run, with the provenance of every term.

`*_source` fields name where the number came from, so a report can never claim a
value was derived when it was overridden or fell back.
"""
struct HostBudget
    cpu_threads::Int
    cpu_source::Symbol              # :slurm :uge :pbs :cgroup :affinity :override
    cpu_origin::String              # the literal file or variable read
    memory_bytes::Int
    memory_source::Symbol           # :slurm :cgroup :memavailable :override
    memory_origin::String
    interactive::Bool
    interactive_reserve_bytes::Int
    swap_containable::Bool
    swap_total_bytes::Int
    gpu_free_bytes::Union{Nothing, Int}
    fft_plan::Symbol                # :estimate | :measure
    notes::Vector{String}
end

# --- primitive readers --------------------------------------------------------

_read_int_file(path) = begin
    isfile(path) || return nothing
    s = strip(read(path, String))
    s == "max" ? typemax(Int) : tryparse(Int, s)
end

# Leading integer of a value like "72(x2)" (SLURM_JOB_CPUS_PER_NODE).
function _leading_int(s::AbstractString)
    m = match(r"^\s*(\d+)", s)
    m === nothing ? nothing : parse(Int, m.captures[1])
end

function _meminfo_bytes(key::AbstractString)
    isfile("/proc/meminfo") || return nothing
    for line in eachline("/proc/meminfo")
        startswith(line, key * ":") || continue
        m = match(r"(\d+)\s*kB", line)
        m === nothing && return nothing
        return parse(Int, m.captures[1]) * 1024
    end
    return nothing
end

"Count of CPUs this process may actually run on — the affinity mask, not the machine."
function _affinity_cpus()
    isfile("/proc/self/status") || return nothing
    for line in eachline("/proc/self/status")
        startswith(line, "Cpus_allowed_list:") || continue
        spec = strip(split(line, ':')[2])
        n = 0
        for part in split(spec, ',')
            isempty(part) && continue
            if occursin('-', part)
                lo, hi = split(part, '-')
                n += parse(Int, hi) - parse(Int, lo) + 1
            else
                n += 1
            end
        end
        return n
    end
    return nothing
end

function _self_uid()
    isfile("/proc/self/status") || return nothing
    for line in eachline("/proc/self/status")
        startswith(line, "Uid:") || continue
        return parse(Int, split(strip(split(line, ':')[2]))[1])
    end
    return nothing
end

"Every cgroup v2 directory from this process's own cgroup up to the root."
function _cgroup_chain()
    isfile("/proc/self/cgroup") || return String[]
    rel = nothing
    for line in eachline("/proc/self/cgroup")
        parts = split(line, ':'; limit=3)
        length(parts) == 3 && parts[1] == "0" && (rel = parts[3])
    end
    rel === nothing && return String[]
    root = "/sys/fs/cgroup"
    isdir(root) || return String[]
    out = String[]
    p = normpath(joinpath(root, lstrip(rel, '/')))
    while startswith(p, root)
        isdir(p) && push!(out, p)
        p == root && break
        p = dirname(p)
    end
    out
end

# --- the ladder, one rung per quantity ----------------------------------------

function _scheduler_cpus()
    for (src, var) in ((:slurm, "SLURM_CPUS_PER_TASK"), (:slurm, "SLURM_JOB_CPUS_PER_NODE"),
        (:uge, "NSLOTS"), (:pbs, "PBS_NCPUS"), (:pbs, "PBS_NP"))
        v = get(ENV, var, "")
        isempty(v) && continue
        n = _leading_int(v)
        n === nothing && throw(
            BlindBudget(:cpu_threads, var,
                "is set to $(repr(v)), which carries no leading integer, so the " *
                "scheduler's grant cannot be read."),
        )
        n > 0 && return (n, src, var)
    end
    return nothing
end

function _scheduler_memory()
    for (var, scale) in (("SLURM_MEM_PER_NODE", 1024 * 1024),)
        v = get(ENV, var, "")
        isempty(v) && continue
        n = _leading_int(v)
        n === nothing && throw(
            BlindBudget(:memory_bytes, var,
                "is set to $(repr(v)), which carries no leading integer."),
        )
        return (n * scale, :slurm, var)
    end
    v = get(ENV, "SLURM_MEM_PER_CPU", "")
    if !isempty(v)
        n = _leading_int(v)
        n === nothing && throw(
            BlindBudget(:memory_bytes, "SLURM_MEM_PER_CPU",
                "is set to $(repr(v)), which carries no leading integer."),
        )
        c = _scheduler_cpus()
        c === nothing && throw(
            BlindBudget(:memory_bytes, "SLURM_MEM_PER_CPU",
                "is per-cpu but no scheduler cpu grant is exported, so the product " *
                "is unknown."),
        )
        return (n * 1024 * 1024 * c[1], :slurm, "SLURM_MEM_PER_CPU x $(c[3])")
    end
    return nothing
end

"Tightest finite `memory.max` anywhere in our own cgroup chain."
function _cgroup_memory_max()
    best, origin = typemax(Int), ""
    for dir in _cgroup_chain()
        v = _read_int_file(joinpath(dir, "memory.max"))
        (v === nothing || v == typemax(Int)) && continue
        v < best && ((best, origin) = (v, joinpath(dir, "memory.max")))
    end
    best == typemax(Int) ? nothing : (best, :cgroup, origin)
end

"Tightest finite `cpu.max` quota in our own cgroup chain, in whole CPUs."
function _cgroup_cpus()
    best, origin = typemax(Int), ""
    for dir in _cgroup_chain()
        path = joinpath(dir, "cpu.max")
        isfile(path) || continue
        parts = split(strip(read(path, String)))
        length(parts) == 2 || continue
        parts[1] == "max" && continue
        quota = tryparse(Int, parts[1]);
        period = tryparse(Int, parts[2])
        (quota === nothing || period === nothing || period == 0) && continue
        n = max(1, cld(quota, period))
        n < best && ((best, origin) = (n, path))
    end
    best == typemax(Int) ? nothing : (best, :cgroup, origin)
end

"""
    _interactive_reserve() -> (bytes, observed::Bool, origin)

Memory the login session has historically needed BEYOND what it holds now.

Zero when no login-session cgroup exists — that is a compute node, and there is
no desktop to keep responsive. Throws when the session exists but its counters
will not read, because that is a failure to measure and not a reserve of zero.
"""
function _interactive_reserve()
    uid = _self_uid()
    uid === nothing && return (0, false, "no /proc/self/status")
    base = "/sys/fs/cgroup/user.slice/user-$(uid).slice/user@$(uid).service"
    isdir(base) || return (0, false, "no $(base) — no login session to protect")
    reserve, seen = 0, String[]
    for slice in ("app.slice", "session.slice")
        dir = joinpath(base, slice)
        isdir(dir) || continue
        cur = _read_int_file(joinpath(dir, "memory.current"))
        peak = _read_int_file(joinpath(dir, "memory.peak"))
        if cur === nothing || peak === nothing
            throw(
                BlindBudget(:interactive_reserve, dir,
                    "the login session is present but memory.current/memory.peak " *
                    "would not read (cgroup v1, or an older kernel without " *
                    "memory.peak)."),
            )
        end
        reserve += max(0, peak - cur)
        push!(seen, slice)
    end
    isempty(seen) && return (0, false, "$(base) has no app/session slice")
    (reserve, true, "$(base)/{$(join(seen, ','))}: memory.peak - memory.current")
end

function _gpu_free_bytes(notes)
    exe = Sys.which("nvidia-smi")
    if exe === nothing
        push!(notes, "no nvidia-smi on PATH — no GPU memory budget derived")
        return nothing
    end
    out = try
        readchomp(`$exe --query-gpu=memory.free --format=csv,noheader,nounits`)
    catch err
        push!(notes, "nvidia-smi failed ($(sprint(showerror, err))) — no GPU budget")
        return nothing
    end
    vals = Int[]
    for line in split(out, '\n')
        s = strip(line)
        isempty(s) && continue
        v = tryparse(Int, s)
        v === nothing && throw(
            BlindBudget(:gpu_free_bytes, "nvidia-smi",
                "returned $(repr(s)), which is not a MiB count."),
        )
        push!(vals, v)
    end
    isempty(vals) && (push!(notes, "nvidia-smi reported no devices"); return nothing)
    minimum(vals) * 1024 * 1024
end

"Can a child cgroup be made swap-proof on this host?"
function _swap_containable(notes)
    if Sys.which("systemd-run") === nothing
        push!(notes, "systemd-run absent — swap cannot be forbidden per-job here")
        return false
    end
    uid = _self_uid()
    ctl = if uid === nothing
        nothing
    else
        "/sys/fs/cgroup/user.slice/user-$(uid).slice/user@$(uid).service/cgroup.controllers"
    end
    if ctl === nothing || !isfile(ctl)
        push!(notes, "no delegated user cgroup — swap cannot be forbidden per-job")
        return false
    end
    if !occursin("memory", read(ctl, String))
        push!(notes, "memory controller not delegated in $(ctl)")
        return false
    end
    true
end

"A deliberately stated value, or `nothing`. Unset is not an error; unparseable is."
function _override(var)
    v = get(ENV, var, "")
    isempty(v) && return nothing
    n = tryparse(Int, v)
    n === nothing &&
        throw(BlindBudget(:override, var, "is set to $(repr(v)), not an integer."))
    n
end

"""
    detect_host_budget() -> HostBudget

Read this host and return what it will give a run, with provenance per term.

Throws [`BlindBudget`](@ref) rather than defaulting when a quantity is present
but unreadable. `SPINORBEC_HOST_CPUS` / `SPINORBEC_HOST_MEMORY_BYTES` state a
value deliberately; the resulting `*_source` is `:override`, so a report can
never present a stated number as a measured one.
"""
function detect_host_budget()
    notes = String[]

    cpu_o = _override("SPINORBEC_HOST_CPUS")
    cpus, cpu_src, cpu_origin = if cpu_o !== nothing
        (cpu_o, :override, "SPINORBEC_HOST_CPUS")
    else
        sched = _scheduler_cpus()
        cg = _cgroup_cpus()
        aff = _affinity_cpus()
        if sched !== nothing
            sched
        elseif cg !== nothing
            cg
        elseif aff !== nothing
            (aff, :affinity, "/proc/self/status Cpus_allowed_list")
        else
            push!(
                notes,
                "no affinity mask readable; fell back to Sys.CPU_THREADS, " *
                "which reports the MACHINE and not this job's allotment",
            )
            (Sys.CPU_THREADS, :affinity, "Sys.CPU_THREADS (machine-wide fallback)")
        end
    end

    reserve, interactive, reserve_origin = _interactive_reserve()

    mem_o = _override("SPINORBEC_HOST_MEMORY_BYTES")
    mem, mem_src, mem_origin = if mem_o !== nothing
        (mem_o, :override, "SPINORBEC_HOST_MEMORY_BYTES")
    else
        sched = _scheduler_memory()
        if sched !== nothing
            # The scheduler isolates the job; the node's totals describe other
            # people's jobs and must not enter.
            sched
        else
            avail = _meminfo_bytes("MemAvailable")
            avail === nothing && throw(
                BlindBudget(:memory_bytes, "/proc/meminfo",
                    "MemAvailable is absent, so the kernel's own no-swap headroom " *
                    "estimate cannot be read."),
            )
            best = avail - reserve
            origin = "MemAvailable - interactive reserve ($(reserve_origin))"
            cg = _cgroup_memory_max()
            src = :memavailable
            if cg !== nothing && cg[1] < best
                best, src, origin = cg[1], :cgroup, cg[3]
            end
            (best, src, origin)
        end
    end

    mem <= 0 && throw(
        BlindBudget(:memory_bytes, mem_origin,
            "derived a non-positive ceiling ($(mem) B). The interactive session's " *
            "historical peak exceeds what is available now; nothing can be run " *
            "without either freeing memory or stating a ceiling deliberately."),
    )

    swap_total = something(_meminfo_bytes("SwapTotal"), 0)
    containable = swap_total == 0 ? true : _swap_containable(notes)
    swap_total == 0 && push!(notes, "host has no swap — nothing to forbid")

    gpu = _gpu_free_bytes(notes)

    # #407: the FFTW planner's scratch explodes on a mixed-radix length only when
    # it is threaded AND allowed to MEASURE. Threads are derived above, so the
    # planner follows from a measured quantity rather than a preference.
    plan = cpus > 1 ? :estimate : :measure
    cpus > 1 && push!(notes,
        "planner forced to ESTIMATE: $(cpus) threads, and MEASURE on a " *
        "non-power-of-two edge was measured at up to 12 GB (#407)")

    HostBudget(cpus, cpu_src, cpu_origin, mem, mem_src, mem_origin,
        interactive, reserve, containable, swap_total, gpu, plan, notes)
end

# --- emission ------------------------------------------------------------------

_gib(b) = round(b / 2^30; digits=2)

"""
    budget_env(b) -> Vector{String}

`KEY=VALUE` strings the run should be launched with. Only knobs whose value is
derived above appear; nothing is set on a hunch.
"""
function budget_env(b::HostBudget)
    env = ["JULIA_NUM_THREADS=$(b.cpu_threads)",
        "SPINORBEC_FFT_PLAN=$(b.fft_plan)"]
    b.gpu_free_bytes === nothing ||
        push!(env, "JULIA_CUDA_HARD_MEMORY_LIMIT=$(b.gpu_free_bytes)")
    env
end

"""
    budget_scope_properties(b) -> Vector{String}

`systemd-run` properties that make the run swap-proof and yielding.

`MemoryHigh` is deliberately absent — see this file's header for the measured
livelock it causes. `CPUWeight=1` is the cgroup interface's own documented
minimum, not a tuning constant.
"""
function budget_scope_properties(b::HostBudget)
    b.swap_containable || return String[]
    ["MemoryMax=$(b.memory_bytes)", "MemorySwapMax=0", "CPUWeight=1"]
end

"""
    budget_report(b; io=stdout)

Print each term with the file or variable it was read from.
"""
function budget_report(b::HostBudget; io::IO=stdout)
    println(io, "host budget")
    println(io, "  cpu threads        $(b.cpu_threads)  [$(b.cpu_source)] $(b.cpu_origin)")
    println(
        io,
        "  memory ceiling     $(_gib(b.memory_bytes)) GiB  [$(b.memory_source)] $(b.memory_origin)",
    )
    if b.interactive
        println(
            io,
            "  interactive reserve $(_gib(b.interactive_reserve_bytes)) GiB  (login session present; subtracted)",
        )
    else
        println(io, "  interactive reserve none  (no login session observed — compute node)")
    end
    println(
        io,
        "  swap               $(b.swap_containable ? "forbidden for the job (MemorySwapMax=0)" : "NOT containable on this host")"
        *
        "  [host SwapTotal $(_gib(b.swap_total_bytes)) GiB]",
    )
    println(
        io,
        "  gpu free           $(b.gpu_free_bytes === nothing ? "unknown" : "$(_gib(b.gpu_free_bytes)) GiB")",
    )
    println(io, "  fft planner        $(b.fft_plan)")
    for n in b.notes
        println(io, "  note: ", n)
    end
    io
end
