# --- workflow/initialization entry point (split 2026-05-02) ---
#
# This file used to hold init_psi (327 lines) + make_workspace (321 lines)
# + small helpers. It was split into:
#
#   state_dispatch.jl  ← init_psi + small helpers
#   make_workspace.jl  ← make_workspace + _rebuild_workspace
#
# Both are loaded directly by SpinorBEC.jl; this file remains as a
# placeholder for any future cross-cutting helpers that don't fit into
# either bucket.
