# --- pipeline_runner entry point (split 2026-05-02) ---
#
# This file used to hold all 8 _run_step methods + helpers in 1645 lines.
# Split by step kind into pipeline/:
#   runner.jl                    ← parse_pipeline + run_pipeline + _step_dispatch! + AnalyzeStep
#   run_step_ground_state.jl     ← _run_step(::GroundStateStep) + GS helpers
#   run_step_dynamics.jl         ← _run_step(::DynamicsStep) + dyn helpers + streaming
#   run_step_binary.jl           ← binary GS + Dynamics dispatch
#   run_step_rotating.jl         ← Option γ rotating-basis GS + Dynamics + chirp helpers
