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
include("validation/stability_spec.jl")         # 3-valued energetic-stability gate
include("validation/error_budget.jl")           # is a numerical knob justified? (mandatory positive control)
include("validation/accuracy_knobs.jl")         # what trades accuracy, and what the most accurate setting is
include("validation/accuracy_profiles.jl")      # :reference / :production / :fast, derived from the registry
include("validation/ground_state_preflight.jl") # one gate before spending compute: the traps that actually cost time
include("validation/save_operator_rhs.jl")      # Level-10 hand-off (operator_rhs.jld2 + MANIFEST)
include("validation/convenience.jl")            # audit / hand_off / diff_yamls — top-level 1-liners
include("validation/show.jl")                   # Base.show pretty printing for REPL
include("validation/twin_audit.jl")             # Level-12 production audit (twin control check)
include("validation/run_observables.jl")        # snapshot trajectories + collapse classifier
include("validation/scalar_summary.jl")          # run_scalar_summary + write_run_summary (catalog fuel)
include("validation/campaign_gate.jl")          # CAMPAIGN.md §4 guard 1, executed rather than described
include("validation/claim_ledger.jl")           # a claim's status as a FIELD, not as prose
include("validation/variational_bound.jl")    # one-sided bound: which side of a disagreement is wrong
include("validation/observable_definition.jl")  # window / reduction / boundary — the ledger's own three fields
include("validation/reanalysis.jl")           # re-read stored output; carries its vintage and its own inadmissibility
