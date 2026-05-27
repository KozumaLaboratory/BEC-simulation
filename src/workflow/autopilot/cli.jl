# ── Operator CLI ──────────────────────────────────────────────────────
#
# Day-to-day operator commands. Backs scripts/autopilot.jl. Daemon-side
# operations should also go through this layer (one truth, two
# consumers) — see _route_autopilot_op for the dashboard POST surface.

export autopilot_pause!, autopilot_resume!, autopilot_drain_wait,
    autopilot_status, autopilot_why

# ── pause / drain / resume ───────────────────────────────────────────

"""
    autopilot_pause!(; qr=autopilot_queue_root()) -> String

Touch `<qr.path>/.autopilot.paused`. The next tick (and all subsequent
ticks) will skip new dispatches. Already-running jobs continue. Returns
the sentinel path.
"""
function autopilot_pause!(; qr::QueueRoot=autopilot_queue_root())
    p = joinpath(qr.path, ".autopilot.paused")
    isdir(qr.path) || mkpath(qr.path)
    open(p, "w") do io
        println(io, "paused_at: ", now())
        println(io, "by: ", get(ENV, "USER", "unknown"))
    end
    return p
end

"""
    autopilot_resume!(; qr=autopilot_queue_root()) -> Bool

Remove the pause sentinel. Returns true if a sentinel existed.
"""
function autopilot_resume!(; qr::QueueRoot=autopilot_queue_root())
    p = joinpath(qr.path, ".autopilot.paused")
    isfile(p) || return false
    rm(p; force=true)
    return true
end

"""
    autopilot_drain_wait(; timeout_s=3600, qr=autopilot_queue_root(),
                        poll_s=10) -> Bool

Pause new dispatches, then block until every `:running` entry has
transitioned to a terminal state. Returns true if drained cleanly,
false on timeout. Polling cadence is `poll_s` seconds.
"""
function autopilot_drain_wait(;
    timeout_s::Real=3600,
    qr::QueueRoot=autopilot_queue_root(),
    poll_s::Real=10,
)
    autopilot_pause!(; qr)
    deadline = time() + Float64(timeout_s)
    while time() < deadline
        n_running = length(list_queue(:running; qr=qr))
        n_running == 0 && return true
        sleep(Float64(poll_s))
    end
    return false
end

# ── status snapshot ──────────────────────────────────────────────────

"""
    AutopilotStatusSnapshot

Compact status report. Counts per state, budget proxy, throughput over
the last 24h. Used by both CLI (text print) and dashboard JSON.
"""
struct AutopilotStatusSnapshot
    counts::Dict{Symbol, Int}                # state → count
    paused::Bool
    lock_held::Bool
    throughput_24h::Int                     # entries moved to done/killed_* in last 24h
    gpu_hours_realized_24h::Float64
    gpu_hours_realized_total::Float64
end

function autopilot_status(; qr::QueueRoot=autopilot_queue_root())
    counts = Dict{Symbol, Int}()
    by_state = Dict{Symbol, Vector{QueueEntry}}()
    for st in QUEUE_STATES
        es = list_queue(st; qr=qr)
        counts[st] = length(es)
        by_state[st] = es
    end
    now_ = now()
    cutoff = now_ - Hour(24)
    throughput = 0
    hours_24h = 0.0
    hours_total = 0.0
    for st in (:done, :killed_data, :killed_bug)
        for e in by_state[st]
            hours_total += e.gpu_hours_realized
            if e.enqueued_at >= cutoff
                throughput += 1
                hours_24h += e.gpu_hours_realized
            end
        end
    end
    AutopilotStatusSnapshot(
        counts,
        is_autopilot_paused(qr),
        isfile(joinpath(qr.path, ".autopilot.lock")),
        throughput,
        hours_24h,
        hours_total,
    )
end

function Base.show(io::IO, s::AutopilotStatusSnapshot)
    println(io, "autopilot status")
    println(io, "  paused:    ", s.paused)
    println(io, "  lock held: ", s.lock_held)
    println(io, "  states:")
    for st in QUEUE_STATES
        println(io, "    ", rpad(String(st), 12), get(s.counts, st, 0))
    end
    println(io, "  throughput (24h): ", s.throughput_24h, " entries")
    @printf(io, "  gpu·h (24h):      %.2f\n", s.gpu_hours_realized_24h)
    @printf(io, "  gpu·h (total):    %.2f\n", s.gpu_hours_realized_total)
end

# ── why <cid>: trace provenance chain ────────────────────────────────

"""
    autopilot_why(content_id; qr=autopilot_queue_root()) -> Vector{QueueEntry}

Trace this entry back through its `parent_id` chain. Returns the chain
oldest-first. Used to answer "why is this run here" — surrogate
suggestions get tagged with the parent's content_id so closed-loop
lineage is recoverable.
"""
function autopilot_why(content_id::AbstractString;
    qr::QueueRoot=autopilot_queue_root())
    by_cid = Dict{String, QueueEntry}()
    for e in list_queue(:all; qr=qr)
        by_cid[e.content_id] = e
    end
    chain = QueueEntry[]
    cursor = String(content_id)
    safety = 100
    while !isempty(cursor) && haskey(by_cid, cursor) && safety > 0
        e = by_cid[cursor]
        push!(chain, e)
        cursor = e.parent_id === nothing ? "" : String(e.parent_id)
        safety -= 1
    end
    reverse!(chain)            # oldest first
    return chain
end

function print_why(io::IO, chain::Vector{QueueEntry})
    if isempty(chain)
        println(io, "  (no entry found)")
        return nothing
    end
    for (i, e) in enumerate(chain)
        prefix = i == 1 ? "  " : "  " * "  "^(i-1) * "↳ "
        println(io, prefix, "[", e.content_id[1:min(8, length(e.content_id))],
            "] status=", e.status, "  by=", e.enqueued_by)
        if e.recipe_name !== nothing
            println(io, " " ^ (length(prefix)),
                "    recipe=", e.recipe_name, " params=", e.recipe_params)
        end
        if !isempty(e.kill_reason)
            println(io, " " ^ (length(prefix)), "    kill=", e.kill_reason)
        end
    end
end
print_why(chain::Vector{QueueEntry}) = print_why(stdout, chain)
