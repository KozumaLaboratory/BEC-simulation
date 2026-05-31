# GET /api/budget — current autopilot budget snapshot.
#
# Wraps `budget_status` so the dashboard can render a persistent
# widget (TSUBAME points / day burn / projected exhaustion). Burn-rate
# projection uses today's realized GPU-hours as the rate; for v1 that's
# simple and conservative (assumes today's pace continues, no
# week-over-week trend). v2 could integrate `recent_metric_samples` for
# a multi-day moving average.

using ..SpinorBEC: budget_status, refresh_budget!

function _route_autopilot_budget()
    try
        refresh_budget!()
    catch err
        @warn "budget refresh threw" exception=err
    end
    snap = try
        budget_status()
    catch err
        return (500, "application/json",
            "{\"ok\":false,\"error\":\"budget_status threw: $(typeof(err).name.name)\"}")
    end

    quarter_cap = Float64(get(snap, "quarter_cap_gpu_hours", 0.0))
    realized = Float64(get(snap, "realized_total", 0.0))
    today_burn = Float64(get(snap, "realized_today", 0.0))
    remaining = max(0.0, quarter_cap - realized)
    # Days-to-exhaust projection: only meaningful when there's any
    # burn today and a non-zero cap. -1 sentinel means "no projection".
    days_left = if quarter_cap > 0 && today_burn > 0
        round(remaining / today_burn; digits=1)
    else
        -1.0
    end

    body =
        "{" *
        "\"ok\":true," *
        "\"quarter_cap_gpu_hours\":$(quarter_cap)," *
        "\"daily_cap_gpu_hours\":$(Float64(get(snap, "daily_cap_gpu_hours", 0.0)))," *
        "\"realized_total\":$(realized)," *
        "\"realized_today\":$(today_burn)," *
        "\"predicted_in_flight\":$(Float64(get(snap, "predicted_in_flight", 0.0)))," *
        "\"remaining\":$(remaining)," *
        "\"days_to_exhaust\":$(days_left)," *
        "\"today\":\"$(String(get(snap, "today", "")))\"," *
        "\"allow\":$(Bool(get(snap, "allow", true)))," *
        "\"reason\":\"$(_jsonesc(String(get(snap, "reason", ""))))\"" *
        "}"
    return (200, "application/json", body)
end
