# --- Monitoring subsystem umbrella ---
#
# Console + log + system telemetry + notifications + live JSON status
# files for ongoing simulations.
#
#   ascii_plot       — terminal density/energy plots
#   logging          — structured log helpers
#   resource_monitor — host RAM / GPU VRAM watchers
#   notifications    — desktop + Slack webhook (HTTP via ext)
#   progress         — TTY progress bar + ETA
#   live_monitor     — JSON status file writer for the dashboard

include("monitoring/ascii_plot.jl")
include("monitoring/logging.jl")
include("monitoring/resource_monitor.jl")
include("monitoring/notifications.jl")
include("monitoring/progress.jl")
include("monitoring/live_monitor.jl")
