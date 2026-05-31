# ── Historical qw-wait estimator ─────────────────────────────────────
#
# TSUBAME's `qstat -j <jobid>` includes a `scheduling info` field that
# would tell us "estimated start in N minutes", but it's disabled on
# TSUBAME 4 by default ("Collecting of scheduler job information is
# turned off"). Without that, ETAs for pending entries are bounded
# below by `estimated_walltime_hours` only — we can't tell the operator
# whether qw will take 30 s or 6 h.
#
# This module fills the gap with a **historical median**: for each
# (backend_type, profile) pair, walk recently-terminal entries that
# have both `dispatched_at` and `cluster_started_at` stamped, compute
# `(cluster_started_at - dispatched_at)` per entry, take the median.
# Tightens the lower-bound ETA into "likely ~5m wait" rather than "≥
# 6h" for entries that match a profile with history.
#
# Cache: results recompute on demand. At <1000 done entries the walk
# is sub-millisecond so no TTL needed.

export historical_qw_medians, _entry_qw_seconds

"""
    historical_qw_medians(; qr=autopilot_queue_root(),
                            window_days=14, min_samples=3)
        -> Dict{Tuple{Symbol,String}, Float64}

Median qw-wait seconds keyed on `(backend_type, profile)`. Only entries
that landed terminal within the last `window_days` and have at least
`min_samples` data points per profile contribute — a single recent
outlier doesn't dominate the estimator, and stale 6-month-old waits
don't override current cluster load.
"""
function historical_qw_medians(;
    qr::QueueRoot=autopilot_queue_root(),
    window_days::Int=14,
    min_samples::Int=3,
)
    cutoff = now() - Day(window_days)
    by_profile = Dict{Tuple{Symbol, String}, Vector{Float64}}()
    for state in (:done, :killed_data, :killed_bug)
        for entry in list_queue(state; qr=qr)
            entry.terminal_at === nothing && continue
            entry.terminal_at < cutoff && continue
            wait_s = _entry_qw_seconds(entry)
            wait_s === nothing && continue
            key = (entry.backend_type, entry.profile)
            push!(get!(by_profile, key, Float64[]), wait_s)
        end
    end
    medians = Dict{Tuple{Symbol, String}, Float64}()
    for (key, samples) in by_profile
        length(samples) < min_samples && continue
        sort!(samples)
        medians[key] = samples[max(1, div(length(samples) + 1, 2))]
    end
    return medians
end

"""
    _entry_qw_seconds(entry) -> Union{Nothing, Float64}

(cluster_started_at - dispatched_at) in seconds, or `nothing` when
either timestamp is missing (legacy entry, or scheduler skipped a
state). Used as the per-entry contribution to the historical median.
"""
function _entry_qw_seconds(entry::QueueEntry)
    (entry.dispatched_at === nothing || entry.cluster_started_at === nothing) &&
        return nothing
    Float64(Millisecond(entry.cluster_started_at - entry.dispatched_at).value) / 1000
end
