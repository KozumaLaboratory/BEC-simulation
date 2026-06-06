# --- Monitoring subsystem umbrella ---
#
# Notifications (Slack webhook via HTTP ext).
#
#   notifications    — Slack webhook stub + notify_slack public API
#
# Live JSON status (for the dashboard) is built in the pipeline via
# `_build_live_callback` (see workflow/experiments/pipeline/pipeline_callbacks.jl) —
# a plain SimulationCallbacks.on_step that atomically writes JSON. No
# separate LiveMonitor type; direct Julia callers can write the same
# 5-line callback or pass a checkpoint=Checkpoint(...) to find_ground_state.

include("monitoring/notifications.jl")
