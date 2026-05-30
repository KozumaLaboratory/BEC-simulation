# ── Autopilot type declarations ───────────────────────────────────────
#
# Pulled into their own file so on_complete.jl and tick.jl can refer to
# AutopilotConfig / AutopilotStats without a circular include order.

export AutopilotConfig, AutopilotStats, resolve_backend

# Forward-declared abstract base for backends. Concrete backends
# (LocalBackend, UGEBackend) are defined in backends.jl / backends_uge.jl
# with their own dispatch methods.
abstract type AutopilotBackend end

"""
    AutopilotConfig

Configuration knobs for `autopilot_tick!`. See `tick.jl` for usage.

`backends` is a registry mapping `:local` / `:uge` (the value carried
by `entry.backend_type`) to a concrete `AutopilotBackend`. The tick
resolves the backend per entry via `resolve_backend(config, entry)`, so
a single tick loop can mix locally-run and remote-run jobs picked from
one queue.

Back-compat: passing `backend=<single AutopilotBackend>` to the kw
constructor wraps it as `Dict(:local => backend)`.
"""
struct AutopilotConfig
    backends::Dict{Symbol, AutopilotBackend}
    qr  # ::QueueRoot — forward-typed because QueueRoot lives in queue.jl
    inspect_before_dispatch::Bool
    respect_budget::Bool
    max_dispatches_per_tick::Int
    on_complete_max_descendants::Int
    notify_slack_on_failure::Bool
    dry_run::Bool
end

function AutopilotConfig(;
    backends::Union{Nothing, Dict{Symbol, <:AutopilotBackend}}=nothing,
    backend::Union{Nothing, AutopilotBackend}=nothing,
    qr,
    inspect_before_dispatch::Bool=true,
    respect_budget::Bool=true,
    max_dispatches_per_tick::Int=16,
    on_complete_max_descendants::Int=64,
    notify_slack_on_failure::Bool=false,
    dry_run::Bool=false,
)
    if backends !== nothing && backend !== nothing
        throw(ArgumentError(
            "AutopilotConfig: pass either backends= or backend=, not both"))
    end
    resolved = if backends !== nothing
        Dict{Symbol, AutopilotBackend}(backends)
    elseif backend !== nothing
        Dict{Symbol, AutopilotBackend}(:local => backend)
    else
        Dict{Symbol, AutopilotBackend}()
    end
    AutopilotConfig(resolved, qr,
        inspect_before_dispatch, respect_budget, max_dispatches_per_tick,
        on_complete_max_descendants, notify_slack_on_failure, dry_run)
end

"""
    resolve_backend(config::AutopilotConfig, entry::QueueEntry) -> AutopilotBackend

Look up the backend instance for `entry.backend_type` in
`config.backends`. Throws a descriptive error if the entry asks for a
backend the config never registered — this is the signal that an
operator queued a `:uge` job but the autopilot is running in a
local-only config (or vice versa), so dispatch must surface it loudly
rather than silently route to a wrong backend.
"""
function resolve_backend(config::AutopilotConfig, entry)
    haskey(config.backends, entry.backend_type) || throw(
        ErrorException(
            "AutopilotConfig has no backend registered for entry.backend_type=" *
            string(entry.backend_type) *
            " (registered: " *
            join(string.(collect(keys(config.backends))), ",") * ")",
        ),
    )
    return config.backends[entry.backend_type]
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
