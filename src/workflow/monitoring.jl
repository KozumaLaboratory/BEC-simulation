# --- Monitoring subsystem umbrella ---
#
# Console + log + system telemetry + notifications.
#
#   ascii_plot       — terminal density/energy plots
#   logging          — structured log helpers
#   resource_monitor — host RAM / GPU VRAM watchers
#   notifications    — desktop + Slack webhook (HTTP via ext)
#   progress         — TTY progress bar + ETA
#
# Live JSON status (for the dashboard) is built in the pipeline via
# `_build_live_callback` (see workflow/experiments/pipeline/pipeline_callbacks.jl) —
# a plain SimulationCallbacks.on_step that atomically writes JSON. No
# separate LiveMonitor type; direct Julia callers can write the same
# 5-line callback or pass a checkpoint=Checkpoint(...) to find_ground_state.

include("monitoring/ascii_plot.jl")
include("monitoring/logging.jl")
include("monitoring/resource_monitor.jl")
include("monitoring/notifications.jl")
include("monitoring/progress.jl")
