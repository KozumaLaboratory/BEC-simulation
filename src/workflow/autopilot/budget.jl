# ── Budget tracker (Tsubame allocation safety net) ────────────────────
#
# Tsubame's GPU allocations consume in real time and are shared with lab
# mates; running the autopilot 24h could exhaust a quarterly allocation
# in 1–2 weeks. This module:
#
#   1. Polls the scheduler (`qacct` on TSUBAME UGE, or any other usage
#      source) to track realized hours and writes to `<qr.path>/budget.toml`.
#   2. Predicts in-flight usage as Σ(entry.estimated_walltime_hours × n_gpu)
#      for status ∈ {pending, running}.
#   3. Gates the dispatch loop with both:
#        - hard ceiling (e.g. 80% of quarter)
#        - daily soft cap (e.g. 50 GPU·hours/day)
#   4. Returns a `BudgetDecision` consumed by `autopilot_tick!`.
#
# Tonight's implementation is intentionally minimal — scheduler
# integration is stubbed so the gate works on `gpu_hours_realized`
# already written into state.toml by the autopilot's run loop. Plug in
# a real qacct/scheduler poller later (`refresh_budget!` is the seam).

export AutopilotBudget,
    BudgetDecision,
    budget_status, refresh_budget!, budget_gate,
    set_budget!, get_budget

const BUDGET_FILENAME = "budget.toml"

"""
    AutopilotBudget

Quarter / daily caps + realized counters. Stored in `<qr.path>/budget.toml`.
The autopilot consults this before every dispatch and refuses if either
gate would be exceeded.
"""
Base.@kwdef mutable struct AutopilotBudget
    quarter_cap_gpu_hours::Float64 = 0.0       # 0 = unlimited
    daily_cap_gpu_hours::Float64 = 0.0         # 0 = unlimited
    realized_total::Float64 = 0.0
    realized_today::Float64 = 0.0
    today::Date = today()
end

"""
    BudgetDecision

Returned by `budget_gate`. `allow == false` means the autopilot should
NOT dispatch this tick; `reason` is a human-readable explanation.
`would_exceed_predicted` is true when the cap is breached only when
in-flight predicted usage is added; useful for telemetry.
"""
struct BudgetDecision
    allow::Bool
    reason::String
    realized::Float64
    predicted::Float64
    quarter_cap::Float64
    daily_cap::Float64
end

# ── Persistence ─────────────────────────────────────────────────────

_budget_path(qr::QueueRoot) = joinpath(qr.path, BUDGET_FILENAME)

function get_budget(qr::QueueRoot=autopilot_queue_root())
    p = _budget_path(qr)
    if !isfile(p)
        b = AutopilotBudget()
        set_budget!(b; qr=qr)
        return b
    end
    d = try
        TOML.parsefile(p)
    catch
        ;
        return AutopilotBudget()
    end
    AutopilotBudget(;
        quarter_cap_gpu_hours=Float64(get(d, "quarter_cap_gpu_hours", 0.0)),
        daily_cap_gpu_hours=Float64(get(d, "daily_cap_gpu_hours", 0.0)),
        realized_total=Float64(get(d, "realized_total", 0.0)),
        realized_today=Float64(get(d, "realized_today", 0.0)),
        today=Date(String(get(d, "today", string(today())))),
    )
end

function set_budget!(b::AutopilotBudget; qr::QueueRoot=autopilot_queue_root())
    isdir(qr.path) || mkpath(qr.path)
    p = _budget_path(qr)
    d = Dict{String, Any}(
        "quarter_cap_gpu_hours" => b.quarter_cap_gpu_hours,
        "daily_cap_gpu_hours" => b.daily_cap_gpu_hours,
        "realized_total" => b.realized_total,
        "realized_today" => b.realized_today,
        "today" => string(b.today),
    )
    tmp = p * ".tmp"
    open(tmp, "w") do io
        TOML.print(io, d)
    end
    mv(tmp, p; force=true)
    return b
end

# ── Refresh + decide ────────────────────────────────────────────────

"""
    refresh_budget!(; qr=autopilot_queue_root()) -> AutopilotBudget

Recompute realized usage from the queue's terminal-state entries. Resets
`realized_today` when the date rolls over. This is the seam for plugging
in a live scheduler-accounting poller later (qacct on UGE, etc.) —
for now, state.toml's `gpu_hours_realized` is authoritative.
"""
function refresh_budget!(; qr::QueueRoot=autopilot_queue_root())
    b = get_budget(qr)
    new_today = today()
    if new_today != b.today
        b.today = new_today
        b.realized_today = 0.0
    end
    total = 0.0
    today_sum = 0.0
    cutoff_24h = now() - Hour(24)
    for st in (:done, :killed_data, :killed_bug, :running)
        for e in list_queue(st; qr=qr)
            total += e.gpu_hours_realized
            if e.enqueued_at >= cutoff_24h
                today_sum += e.gpu_hours_realized
            end
        end
    end
    # ABSENCE MUST NOT READ AS HEALTH. `gpu_hours_realized` is documented as
    # "filled in by qacct/scheduler poller" and **no such poller exists** — grep
    # the tree: the field is only ever read back from TOML or defaulted to 0.0,
    # never computed from a completed run. So this loop sums zeros, the caps
    # compare 0.0 against them, and the budget gate has never been able to trip.
    #
    # Reporting 0.0 spent is indistinguishable from "well under budget", which is
    # the direction that costs money. The material for a real number is on the
    # entry (`cluster_started_at`, `terminal_at`, `profile`), but choosing the
    # formula — queue time or run time, GPUs per profile, or qacct as the
    # authority on TSUBAME — is a decision, not a derivation, so this warns
    # instead of inventing one.
    n_terminal = 0
    n_zero = 0
    for st in (:done, :killed_data, :killed_bug)
        for e in list_queue(st; qr=qr)
            n_terminal += 1
            e.gpu_hours_realized == 0.0 && (n_zero += 1)
        end
    end
    if n_terminal > 0 && n_zero == n_terminal
        @warn "budget: every one of $n_terminal terminal entries reports " *
            "gpu_hours_realized == 0.0, so the caps are comparing against " *
            "nothing. No writer for that field exists (it is documented as " *
            "filled by a qacct poller that was never built). Treat the " *
            "budget gate as OFF until one lands." _module = nothing _file = nothing
    end

    b.realized_total = total
    b.realized_today = today_sum
    set_budget!(b; qr=qr)
    return b
end

"""
    budget_gate(; qr=autopilot_queue_root(),
                hard_ratio=0.8) -> BudgetDecision

Should the autopilot dispatch this tick? Returns `BudgetDecision(allow,
reason, ...)`. Caps of 0.0 mean "unlimited". `hard_ratio` controls when
to start refusing dispatch as a fraction of `quarter_cap` — default 0.8.
"""
function budget_gate(;
    qr::QueueRoot=autopilot_queue_root(),
    hard_ratio::Float64=0.8,
)
    b = get_budget(qr)
    # Predicted = sum of remaining work that's already queued.
    predicted = 0.0
    for st in (:pending, :running)
        for e in list_queue(st; qr=qr)
            predicted += e.estimated_walltime_hours
        end
    end
    realized = b.realized_total

    if b.quarter_cap_gpu_hours > 0
        ceiling = hard_ratio * b.quarter_cap_gpu_hours
        if realized + predicted > b.quarter_cap_gpu_hours
            return BudgetDecision(false,
                "would exceed quarter cap (realized $(round(realized; digits=1)) + " *
                "predicted $(round(predicted; digits=1)) > cap " *
                "$(round(b.quarter_cap_gpu_hours; digits=1)))",
                realized, predicted, b.quarter_cap_gpu_hours, b.daily_cap_gpu_hours)
        end
        if realized > ceiling
            return BudgetDecision(false,
                "realized hours $(round(realized; digits=1)) > " *
                "$(Int(round(hard_ratio * 100)))% of quarter cap " *
                "($(round(b.quarter_cap_gpu_hours; digits=1))) — back off",
                realized, predicted, b.quarter_cap_gpu_hours, b.daily_cap_gpu_hours)
        end
    end
    if b.daily_cap_gpu_hours > 0 && b.realized_today > b.daily_cap_gpu_hours
        return BudgetDecision(false,
            "daily cap reached: $(round(b.realized_today; digits=1)) > " *
            "$(round(b.daily_cap_gpu_hours; digits=1))",
            realized, predicted, b.quarter_cap_gpu_hours, b.daily_cap_gpu_hours)
    end
    return BudgetDecision(true, "ok",
        realized, predicted, b.quarter_cap_gpu_hours, b.daily_cap_gpu_hours)
end

# ── Status summary ─────────────────────────────────────────────────

function budget_status(; qr::QueueRoot=autopilot_queue_root())
    b = get_budget(qr)
    d = budget_gate(; qr=qr)
    Dict{String, Any}(
        "quarter_cap_gpu_hours" => b.quarter_cap_gpu_hours,
        "daily_cap_gpu_hours" => b.daily_cap_gpu_hours,
        "realized_total" => b.realized_total,
        "realized_today" => b.realized_today,
        "predicted_in_flight" => d.predicted,
        "today" => string(b.today),
        "allow" => d.allow,
        "reason" => d.reason,
    )
end
