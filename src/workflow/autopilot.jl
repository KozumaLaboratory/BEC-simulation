# --- Autopilot subsystem umbrella ---
#
# Queue + tick + backends + on_complete + retry. Designed as a thin
# meta-loop over existing pieces (CAS, Experiment, inspect_config,
# notify_slack, _live_status.json) — see docs/guides/autopilot.md for
# the architecture overview.
#
# Composition is strictly bottom-up:
#   queue.jl       — types + serialization + enqueue/dequeue
#   backends.jl    — Local subprocess dispatch
#   backends_uge.jl — UGE (TSUBAME) dispatch
#   monitor.jl     — _live_status.json divergence detector
#   on_complete.jl — callback registry + lineage
#   tick.jl        — autopilot_tick! orchestration
#   retry.jl       — _exit_summary.json classification
#
# All public exports are flat under SpinorBEC.

using Printf

include("autopilot/types.jl")       # AutopilotConfig, AutopilotStats, AutopilotBackend
include("autopilot/queue.jl")
include("autopilot/queue_toml.jl")  # QueueEntry ⇄ state.toml (de)serialization + migrations
include("autopilot/backends.jl")
include("autopilot/backends_uge.jl")
include("autopilot/monitor.jl")
include("autopilot/on_complete.jl")
include("autopilot/tick.jl")
include("autopilot/retry.jl")
include("autopilot/cli.jl")          # pause/drain/resume/status/why
include("autopilot/budget.jl")       # quarter+daily caps, dispatch gate
include("autopilot/qw_history.jl")   # historical-median qw-wait estimator
include("autopilot/failure_analysis.jl") # "why did this fail?" summariser
include("autopilot/profile_recommend.jl") # grid → suggested UGE profile
include("autopilot/trust.jl")        # autonomy gradient + calibration history
include("autopilot/archive.jl")      # done/killed_* retention
include("autopilot/recipes.jl")      # Day-1 recipes (next_random / refine / analyze)
include("autopilot/breakers.jl")     # circuit breakers (recipe / lineage / rate / kill)
include("autopilot/observability.jl") # metrics.jsonl + errors.log + success-rate
