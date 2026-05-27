# ── Circuit breakers ──────────────────────────────────────────────────
#
# Cheap fault detectors that run before/during `autopilot_tick!`. Where
# trust/budget are *predictive* (gate behaviour before fault),
# breakers are *reactive* (cut the circuit after fault). Each is a small
# pure function returning a `BreakerTrip` enum — the caller decides what
# to do (typically `autopilot_pause!()` + Slack).
#
# Four breakers, all queue-walking (no separate metric store needed):
#   per_recipe_failure_rate  — recipe X has K_kill/N > threshold recently
#   lineage_depth            — any chain of parent_id > max_depth (loop bug)
#   dispatch_rate            — dispatched/hour > cap (runaway)
#   kill_rate                — kills_per_hour > dispatches_per_hour (threshold mis-set)

export BreakerTrip, BreakerThresholds, check_breakers,
    per_recipe_failure_rate, lineage_depth_max,
    dispatch_rate_per_hour, kill_rate_ratio

@enum BreakerTrip BREAKER_OK BREAKER_RECIPE_FAILURE BREAKER_LINEAGE_DEPTH BREAKER_DISPATCH_RATE BREAKER_KILL_RATE

Base.@kwdef struct BreakerThresholds
    recipe_failure_rate::Float64 = 0.7      # ≥70% of last N → trip
    recipe_failure_window::Int = 5        # last-N window for the rate
    max_lineage_depth::Int = 16       # transitive parent_id chain cap
    max_dispatches_per_hour::Int = 64       # runaway dispatcher cap
    max_kill_ratio::Float64 = 1.0      # kills/dispatches in trailing 1h
end

const _DEFAULT_BREAKER_THRESHOLDS = Ref{BreakerThresholds}(BreakerThresholds())
breaker_thresholds() = _DEFAULT_BREAKER_THRESHOLDS[]
set_breaker_thresholds!(t::BreakerThresholds) = (_DEFAULT_BREAKER_THRESHOLDS[] = t)

"""
    per_recipe_failure_rate(entries, recipe; window=5)

Recent-N failure rate (killed_data + killed_bug) over the last `window`
terminal entries of the given recipe. Returns `(rate, n_observed)`.
`rate` is 0.0 when fewer than 2 entries observed.
"""
function per_recipe_failure_rate(entries::AbstractVector{<:QueueEntry},
    recipe::Symbol; window::Int=5)
    relevant = [
        e for e in entries
        if e.recipe_name === recipe &&
        e.status in (:done, :killed_data, :killed_bug)
    ]
    isempty(relevant) && return (0.0, 0)
    sort!(relevant; by=e -> e.enqueued_at, rev=true)
    sample = first(relevant, min(window, length(relevant)))
    n_kill = count(e -> e.status in (:killed_data, :killed_bug), sample)
    (n_kill / length(sample), length(sample))
end

"""
    lineage_depth_max(entries) -> (depth, deepest_cid)

Longest transitive parent_id chain across the queue. Bounded
deterministically — a cycle would hit the visited set and stop.
"""
function lineage_depth_max(entries::AbstractVector{<:QueueEntry})
    cid_to_entry = Dict(e.content_id => e for e in entries)
    deepest = 0
    deepest_cid = ""
    for e in entries
        depth = 0
        cur = e.parent_id
        visited = Set{String}([e.content_id])
        while cur !== nothing && !(cur in visited)
            depth += 1
            push!(visited, cur)
            parent = get(cid_to_entry, cur, nothing)
            parent === nothing && break
            cur = parent.parent_id
        end
        if depth > deepest
            deepest, deepest_cid = depth, e.content_id
        end
    end
    (depth=deepest, deepest_cid=deepest_cid)
end

"""
    dispatch_rate_per_hour(entries; window_s=3600)

Count of entries that transitioned to `:running` in the last `window_s`
seconds. Approximated as `enqueued_at` within the window for entries
that have left `:pending` — close enough for breaker purposes.
"""
function dispatch_rate_per_hour(entries::AbstractVector{<:QueueEntry};
    window_s::Real=3600)
    cutoff = now() - Second(round(Int, window_s))
    count(e -> e.enqueued_at >= cutoff &&
               e.status in (:running, :done, :killed_data, :killed_bug),
        entries)
end

"""
    kill_rate_ratio(entries; window_s=3600) -> (ratio, kills, dispatches)

Ratio of (killed_data + killed_bug) / (running + done + killed_*) in
the trailing window. Ratio > 1 isn't mathematically possible (every
kill was also a dispatch), so the value is bounded in [0, 1]. A high
value indicates the divergence threshold may be mis-set.
"""
function kill_rate_ratio(entries::AbstractVector{<:QueueEntry};
    window_s::Real=3600)
    cutoff = now() - Second(round(Int, window_s))
    recent = filter(e -> e.enqueued_at >= cutoff, entries)
    n_disp = count(e -> e.status in (:running, :done, :killed_data, :killed_bug), recent)
    n_kill = count(e -> e.status in (:killed_data, :killed_bug), recent)
    ratio = n_disp == 0 ? 0.0 : n_kill / n_disp
    (ratio=ratio, kills=n_kill, dispatches=n_disp)
end

"""
    check_breakers(; qr=autopilot_queue_root(),
                     thresholds=breaker_thresholds())
        -> (trip::BreakerTrip, details::Dict)

Run all four breakers and return the first trip encountered (priority:
recipe failure → lineage → dispatch rate → kill rate). The `details`
dict carries metric values for logging / Slack.
"""
function check_breakers(;
    qr::QueueRoot=autopilot_queue_root(),
    thresholds::BreakerThresholds=breaker_thresholds(),
)
    entries = list_queue(:all; qr=qr)
    details = Dict{String, Any}()

    # 1. per-recipe failure rate
    seen_recipes = unique(e.recipe_name for e in entries if e.recipe_name !== nothing)
    for r in seen_recipes
        rate, n = per_recipe_failure_rate(entries, r;
            window=thresholds.recipe_failure_window)
        details["recipe_$(r)_rate"] = rate
        details["recipe_$(r)_n"] = n
        if n >= 3 && rate >= thresholds.recipe_failure_rate
            details["tripped_recipe"] = String(r)
            return (BREAKER_RECIPE_FAILURE, details)
        end
    end

    # 2. lineage depth
    depth_info = lineage_depth_max(entries)
    details["max_lineage_depth"] = depth_info.depth
    if depth_info.depth > thresholds.max_lineage_depth
        details["deepest_cid"] = depth_info.deepest_cid
        return (BREAKER_LINEAGE_DEPTH, details)
    end

    # 3. dispatch rate
    rate = dispatch_rate_per_hour(entries)
    details["dispatch_per_hour"] = rate
    if rate > thresholds.max_dispatches_per_hour
        return (BREAKER_DISPATCH_RATE, details)
    end

    # 4. kill rate ratio
    kr = kill_rate_ratio(entries)
    details["kill_ratio"] = kr.ratio
    details["kills"] = kr.kills
    details["dispatches"] = kr.dispatches
    if kr.dispatches >= 4 && kr.ratio > thresholds.max_kill_ratio
        return (BREAKER_KILL_RATE, details)
    end

    return (BREAKER_OK, details)
end
