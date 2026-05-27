# ── Autopilot type declarations ───────────────────────────────────────
#
# Pulled into their own file so on_complete.jl and tick.jl can refer to
# AutopilotConfig / AutopilotStats without a circular include order.

export AutopilotConfig, AutopilotStats

# Forward-declared abstract base for backends. Concrete backends
# (LocalBackend, SlurmBackend) are defined in backends.jl with their
# own dispatch methods.
abstract type AutopilotBackend end

"""
    AutopilotConfig

Configuration knobs for `autopilot_tick!`. See `tick.jl` for usage.
"""
Base.@kwdef struct AutopilotConfig
    backend::AutopilotBackend
    qr  # ::QueueRoot — forward-typed because QueueRoot lives in queue.jl
    inspect_before_dispatch::Bool = true
    respect_budget::Bool = true
    max_dispatches_per_tick::Int = 16
    on_complete_max_descendants::Int = 64
    notify_slack_on_failure::Bool = false
    # Dry-run mode — when true, dispatch is intercepted: tick logs what
    # it WOULD have submitted (cid / profile / recipe / wall estimate)
    # and advances the entry through running → done immediately. No
    # sbatch / no run!. Inspector + budget + autonomy gates still fire.
    # First-dispatch safety net.
    dry_run::Bool = false
end

"""
    AutopilotStats

Lightweight per-tick summary — returned by `autopilot_tick!` so callers
(cron logs, tests, dashboard) can verify the tick did work.
"""
Base.@kwdef mutable struct AutopilotStats
    dispatched::Int = 0
    completed::Int = 0
    failed::Int = 0
    inspected_blocked::Int = 0
    on_complete_fired::Int = 0
    killed_divergent::Int = 0
    n_pending::Int = 0
    n_running::Int = 0
end
