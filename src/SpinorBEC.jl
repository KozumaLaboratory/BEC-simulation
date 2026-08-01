module SpinorBEC

using LinearAlgebra
using StaticArrays
using FFTW
using JLD2
using CodecZlib: ZlibCompressor
using CodecZstd: ZstdCompressor
using YAML
using Unitful
using TimerOutputs
using Random
using Printf
using Dates
using SHA
import JSON
using SpecialFunctions: erfcx
using Sockets
# WriteVTK + HTTP are now weak deps (see ext/SpinorBECVTKExt,
# ext/SpinorBECHTTPExt). No top-level `using` statements for them here.

const TIMER = TimerOutput()

# Default `verbose` for solver entry points (find_ground_state, lbfgs,
# run_pipeline, …). Quiet under CI so test output stays a few hundred
# lines instead of thousands of "ITP step k/N" prints. Users running
# locally still get progress output; explicit `verbose=true/false`
# always overrides.
@inline _default_solver_verbose() = !haskey(ENV, "CI")

include("foundation.jl")    # types + math primitives + backends
include("hamiltonian.jl")   # interactions + potentials + integrators
include("model.jl")         # Model: resolved physics as ONE concrete value (additive; nothing uses it yet)

# ========================================
# WORKFLOW: Initialization, I/O, monitoring, experiments
# ========================================

include("workflow/io/units.jl")        # Units module (needed by atoms.jl)
include("workflow/initialization.jl")  # atoms + init_psi + Workspace factory + state zoo
include("workflow/io.jl")              # save_state + dashboard + VTK + run summary + budget
include("workflow/monitoring.jl")      # Slack webhook notifications (notify_slack)

include("workflow/experiments.jl")     # schema + runtime + pipeline + analyzers
include("workflow/experiments/euv3_coils.jl")  # euv3 lab coil/field calibration
include("workflow/validation.jl")      # RunResult + spec-driven validation (Phase 0: types only)
include("workflow/checkpoint.jl")          # general keyed JLD2 store + refine + fork
include("workflow/checkpointed_sweep.jl")  # thin sweep wrapper over Checkpoint
include("solvers/projected_gp.jl")
include("solvers/photon_heating.jl")
include("solvers/sgpe.jl")
include("solvers/spgpe.jl")   # full SPGPE: growth + energy-damping reservoirs (Rooney PRA 86 053634)
# Klaus-regime rotating-basis + scalar-eGPE used to live as a vertical
# slice at src/rotating_basis/; 2026-06-02 dispersed into proper layers
# (foundation/, hamiltonian/integrator/, analysis/, solvers/,
# workflow/experiments/analyzers/). See docs/architecture/rotating_basis.md.

include("workflow/experiments/pipeline/pipeline_api.jl")
include("workflow/experiments/pipeline/pipeline_continuation.jl")
include("workflow/experiments/pipeline/run_registry.jl")
include("workflow/experiments/diff_dicts.jl")
include("workflow/experiments/inspect.jl")          # check framework + entry points + per-step traces + CLI/JSON
include("workflow/experiments/inspect_checks.jl")   # concrete A/B/C/D checks + registry registration
include("workflow/experiments/inspect_batch.jl")

# Calibration subsystem (real submodule, 2 files: core + drift).
include("workflow/experiments/calibration.jl")  # `module Calibration`
using .Calibration:
    CalibrationSet, CoilCalibration, FORTCalibration, RabiCalibration,
    DEFAULT_CALIBRATION, load_calibration, apply_calibration!, run_yaml_calibrated,
    coil_mv_to_gauss, fort_mw_to_trap_hz, rabi_mw_to_rad_s,
    CalibrationHistory, load_calibration_history, load_calibration_csv,
    interpolate_calibration,
    sample_trap_drift_omegas, trap_drift_waveforms, apply_trap_drift
# Internal: pulled in for `run_yaml`'s pre-schema calibration block parser
# (run_registry.jl). Not exported.
using .Calibration: _calibration_from_dict
export CalibrationSet, CoilCalibration, FORTCalibration, RabiCalibration
export DEFAULT_CALIBRATION, load_calibration, apply_calibration!, run_yaml_calibrated
export coil_mv_to_gauss, fort_mw_to_trap_hz, rabi_mw_to_rad_s
export CalibrationHistory, load_calibration_history, load_calibration_csv
export interpolate_calibration
export sample_trap_drift_omegas, trap_drift_waveforms, apply_trap_drift

# ========================================
# ANALYSIS: Observables & diagnostics
# ========================================

include("analysis.jl")  # observables + diagnostics + phase exploration umbrella
include("manuscript.jl")  # manuscript figure registry + builders

# ========================================
# VALIDATION: self-contained reference RHS
# ========================================
# Independent, deliberately-redundant Hamiltonian statements used as diff
# oracles for the self-contained validation chain (gated redundancy,
# architectural commitment #3): reference_rhs (term-by-term Hψ oracle) +
# dumb_reference (master-oracle anchor). See src/validation.jl header.
include("validation.jl")

# ========================================
# EXPERIMENT / BATCH: unified workflow model
# ========================================
# Cheap lifecycle object: (spec, outdir, lazy obs cache). Subsumes
# scattered run_yaml / open_result / classify_collapse / sweep patterns.
# Depends on: open_result, run_yaml, walk_dicts!, total_density,
#             run_observables (find_run_dir, peak_density_trajectory,
#             spin_populations_trajectory, classify_collapse), and
#             runfactory's internal _set_path!.
include("workflow/experiment.jl")               # CAS + Experiment type + lifecycle + memo + check/compare/audit
include("workflow/experiment_observables.jl")   # observables (plain functions on Experiment)
include("workflow/experiment_collections.jl")   # spec_diff / sweep / twin / tabulate
include("workflow/io/cluster.jl")  # cluster helpers (needs Experiment)
include("workflow/autopilot.jl")   # queue + tick + on_complete + retry

# ========================================
# SOLVERS: Ground state & time evolution
# ========================================

include("solvers.jl")  # ground_state + simulation + lbfgs + continuation + twa + binary umbrella

# Optimization subsystem (real submodule) — loaded after analysis so
# `classify_phase_distance` / `DEFAULT_PHASE_REFERENCES` are in scope.
include("workflow/experiments/optimization.jl")  # `module Optimization` (5 files)

using .Optimization:
    fit_faraday_param, load_target_faraday,
    bayesian_optimize, gp_predict, expected_improvement,
    multi_fidelity_optimize_2tier, MultiFidelityBOResult,
    bayesian_optimize_yaml, multi_fidelity_optimize_yaml,
    bo_objective_max_m_transfer, bo_objective_max_lz, bo_objective_min_energy,
    active_learn_phase_scan, active_learn_phase_scan_yaml,
    phase_entropy_uncertainty, default_phase_classifier_extractor
export fit_faraday_param, load_target_faraday
export bayesian_optimize, gp_predict, expected_improvement
export multi_fidelity_optimize_2tier, MultiFidelityBOResult
export bayesian_optimize_yaml, multi_fidelity_optimize_yaml
export bo_objective_max_m_transfer, bo_objective_max_lz, bo_objective_min_energy
export active_learn_phase_scan, active_learn_phase_scan_yaml
export phase_entropy_uncertainty, default_phase_classifier_extractor

# Dashboard subsystem (real submodule) — must be loaded after analysis +
# workflow/experiments so that total_density / spin_density_vector /
# list_runs / run_status are exported by SpinorBEC.
include("workflow/io/dashboard.jl")  # `module Dashboard` (21 source files)

# Re-export Dashboard's public surface at the umbrella level so existing
# `using SpinorBEC; serve_dashboard(...)` call sites keep working.
using .Dashboard:
    serve_dashboard,
    generate_dashboard_data,
    export_dashboard,
    RunMetadata,
    load_run_metadata
export serve_dashboard, generate_dashboard_data, export_dashboard
export RunMetadata, load_run_metadata

# All public symbols are now `export`ed at their definition sites under
# src/foundation/, src/hamiltonian/, src/analysis/, src/solvers/, and
# src/workflow/. The umbrella module here only declares cross-cutting
# extension stubs (e.g. Makie visualisation placeholders).

export Units
export TIMER, enable_tracing!, disable_tracing!, reset_tracing!

function enable_tracing!()
    TimerOutputs.enable_debug_timings(SpinorBEC)
    enable_timer!(TIMER)
end
disable_tracing!() = disable_timer!(TIMER)
reset_tracing!() = TimerOutputs.reset_timer!(TIMER)

# Makie ext placeholders (real methods in ext/SpinorBECMakieExt).
function plot_density end
function plot_spinor end
function plot_spin_texture end
function plot_dipole_field end
function animate_dynamics end
function plot_sweep end
export plot_density, plot_spinor, plot_spin_texture, plot_dipole_field
export animate_dynamics, plot_sweep

include("precompile.jl")

function __init__()
    __init_templates__()
end

end # module
