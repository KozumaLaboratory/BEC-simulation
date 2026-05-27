# ── Observability ─────────────────────────────────────────────────────
#
# Timeseries + per-tick error log. Operator visibility into 24/7 behaviour
# beyond the instantaneous `autopilot_status()` snapshot.
#
# Two files at qr.path:
#   .autopilot.metrics.jsonl   — per-tick rolling metrics (one JSON / line)
#   .autopilot.errors.log      — recoverable error events (one stanza / event)
#
# Both append-only; rotate externally (logrotate / systemd-journald).

export append_metric_sample!,
    recent_metric_samples,
    append_error_event!, recent_error_events,
    autopilot_recipe_success_rate

const METRICS_FILENAME = ".autopilot.metrics.jsonl"
const ERRORS_FILENAME = ".autopilot.errors.log"

"""
    append_metric_sample!(stats, breaker_details; qr=autopilot_queue_root())

Append one JSONL record summarising the just-completed tick. Used by
`autopilot_tick!` as a side-effect, by `cli.jl autopilot metrics` to
emit a digest, and by the dashboard's metrics tab.
"""
function append_metric_sample!(stats::AutopilotStats,
    breaker_details::AbstractDict=Dict{String, Any}();
    qr::QueueRoot=autopilot_queue_root(),
)
    isdir(qr.path) || mkpath(qr.path)
    p = joinpath(qr.path, METRICS_FILENAME)
    payload = Dict{String, Any}(
        "ts" => string(now()),
        "dispatched" => stats.dispatched,
        "completed" => stats.completed,
        "failed" => stats.failed,
        "inspected_blocked" => stats.inspected_blocked,
        "on_complete_fired" => stats.on_complete_fired,
        "killed_divergent" => stats.killed_divergent,
        "n_pending" => stats.n_pending,
        "n_running" => stats.n_running,
        "breaker" => breaker_details,
    )
    open(p, "a") do io
        JSON.print(io, payload)
        println(io)
    end
    return p
end

"""
    recent_metric_samples(n=288; qr=autopilot_queue_root()) -> Vector{Dict}

Read the last `n` samples from the metrics jsonl. Default 288 = 1 day
at 5-min cadence. Parsed lazily so a multi-MB log doesn't blow memory
on dashboard polls.
"""
function recent_metric_samples(n::Int=288;
    qr::QueueRoot=autopilot_queue_root())
    p = joinpath(qr.path, METRICS_FILENAME)
    isfile(p) || return Dict{String, Any}[]
    lines = readlines(p)
    isempty(lines) && return Dict{String, Any}[]
    tail = lines[max(1, length(lines) - n + 1):end]
    out = Dict{String, Any}[]
    for line in tail
        try
            push!(out, JSON.parse(line))
        catch
        end
    end
    out
end

"""
    append_error_event!(event::AbstractString, details=Dict; qr=...)

Append a recoverable error (panic, lock-stale, backend-unreachable) to
`autopilot.errors.log`. The systemd unit's `Restart=on-failure` policy
catches Julia-side crashes; this file captures the in-Julia errors that
the tick recovered from without exiting.
"""
function append_error_event!(event::AbstractString,
    details::AbstractDict=Dict{String, Any}();
    qr::QueueRoot=autopilot_queue_root(),
)
    isdir(qr.path) || mkpath(qr.path)
    p = joinpath(qr.path, ERRORS_FILENAME)
    open(p, "a") do io
        println(io, "---")
        println(io, "ts: ", now())
        println(io, "event: ", event)
        for (k, v) in details
            println(io, "  $k: ", v)
        end
    end
    return p
end

function recent_error_events(n::Int=64;
    qr::QueueRoot=autopilot_queue_root())
    p = joinpath(qr.path, ERRORS_FILENAME)
    isfile(p) || return String[]
    lines = readlines(p)
    # Each event is a `---`-separated stanza; tail the last `n` stanzas.
    stanzas = String[]
    cur = String[]
    for line in lines
        if line == "---" && !isempty(cur)
            push!(stanzas, join(cur, "\n"))
            empty!(cur)
        else
            push!(cur, line)
        end
    end
    isempty(cur) || push!(stanzas, join(cur, "\n"))
    isempty(stanzas) ? String[] : stanzas[max(1, length(stanzas) - n + 1):end]
end

"""
    autopilot_recipe_success_rate(recipe::Symbol; qr=...) -> (rate, n, last_24h)

Trust-calibration trajectory: of the entries for `recipe` that have
terminated, what fraction landed in `:done`? Returns (rate, total
observations, rate over the last 24h). Used by the dashboard to plot
each recipe's success-rate over time.
"""
function autopilot_recipe_success_rate(recipe::Symbol;
    qr::QueueRoot=autopilot_queue_root())
    entries = list_queue(:all; qr=qr)
    terminal = [
        e for e in entries
        if e.recipe_name === recipe &&
        e.status in (:done, :killed_data, :killed_bug)
    ]
    isempty(terminal) && return (rate=0.0, n=0, last_24h=0.0)
    total_rate = count(e -> e.status === :done, terminal) / length(terminal)
    cutoff = now() - Hour(24)
    recent = filter(e -> e.enqueued_at >= cutoff, terminal)
    rate_24h = isempty(recent) ? 0.0 :
               count(e -> e.status === :done, recent) / length(recent)
    (rate=total_rate, n=length(terminal), last_24h=rate_24h)
end
