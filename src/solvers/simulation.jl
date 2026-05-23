# --- Real/imaginary-time simulation driver umbrella ---
#
# 438-line monolith split into 3 sub-files (2026-05-11 refactor):
#
#   simulation/callbacks.jl  — SimulationCallbacks event-driven hooks,
#                              _record_snapshot!, _check_energy_drift
#   simulation/run_loops.jl  — _run_simulation_standard! +
#                              _run_simulation_leapfrog! (the actual
#                              per-step machinery, including the Bug-4
#                              RTP-analogue DDI substep fix)
#   simulation/entry.jl      — run_simulation! (public dispatch) and
#                              run_simulation_checkpointed! (resumable
#                              wrapper)
#
# Public API unchanged; exports preserved at each sub-file's
# definition site (flat namespace via SpinorBEC umbrella pattern).

include("simulation/callbacks.jl")
include("simulation/run_loops.jl")
include("simulation/entry.jl")
