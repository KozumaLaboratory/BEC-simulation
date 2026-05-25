# --- Validation subsystem umbrella ---
#
# Typed views over jld2 run artifacts + spec-driven verdicts. Designed
# to subsume the ad-hoc `scripts/validation/*.jl` patterns that have
# accumulated bugs from API drift (e.g. stale `interactions_c_extra`
# key, `HarmonicTrap(1.0f0)`, `cp` same-path crash, duplicate analyzer
# implementations).
#
# Public surface (10 symbols, exported via SpinorBEC umbrella):
#
#   Types
#     RunResult, RunSweep, RunComparison
#     DynamicsTimeSeries, CheckResult
#     ConservationSpec, OperatorRHSSpec
#
#   Operations
#     open_result, sweep_runs, compare_runs, check, save_operator_rhs
#
# Phase 0 (this file) ships types only — operations land in subsequent
# phases. See docs/validation/validation_api_migration.md for the full
# rollout schedule.

include("validation/types.jl")
include("validation/observable_dispatch.jl")    # Base.getproperty(RunResult, ...)
include("validation/open_result.jl")            # JLD2 → RunResult loader
include("validation/operations.jl")             # sweep_runs / compare_runs
include("validation/specs.jl")                  # Specs + check() dispatch
include("validation/save_operator_rhs.jl")      # Level-10 hand-off (operator_rhs.jld2 + MANIFEST)
include("validation/convenience.jl")            # audit / hand_off / diff_yamls — top-level 1-liners
include("validation/show.jl")                   # Base.show pretty printing for REPL
include("validation/twin_audit.jl")             # Level-12 production audit (twin control check)
