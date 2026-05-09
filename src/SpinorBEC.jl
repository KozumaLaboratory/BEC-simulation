module SpinorBEC

using LinearAlgebra
using StaticArrays
using FFTW
using JLD2
using CodecZlib: ZlibCompressor, GzipCompressor, transcode
using CodecZstd: ZstdCompressor
using YAML
using Unitful
using TimerOutputs
using Random
using Printf
using Dates
using SHA
using Base64: base64encode
import JSON
using SpecialFunctions: erfcx
using Sockets
# WriteVTK + HTTP are now weak deps (see ext/SpinorBECVTKExt,
# ext/SpinorBECHTTPExt). No top-level `using` statements for them here.

const TIMER = TimerOutput()

include("foundation.jl")    # types + math primitives + backends
include("hamiltonian.jl")   # interactions + potentials + integrators

# ========================================
# WORKFLOW: Initialization, I/O, monitoring, experiments
# ========================================

include("workflow/io/units.jl")        # Units module (needed by atoms.jl)
include("workflow/initialization.jl")  # atoms + init_psi + Workspace factory + state zoo
include("workflow/io.jl")              # save_state + dashboard + VTK + run summary + budget
include("workflow/monitoring.jl")      # logging + telemetry + LiveMonitor

include("workflow/experiments.jl")     # schema + runtime + pipeline + analyzers
include("solvers/projected_gp.jl")
include("solvers/photon_heating.jl")
include("solvers/sgpe.jl")
include("rotating_basis.jl")  # Klaus-regime (rotating-basis + scalar-eGPE) umbrella

include("cuda_graph_stubs.jl")

include("workflow/experiments/pipeline/pipeline_api.jl")
include("workflow/experiments/pipeline/pipeline_continuation.jl")
include("workflow/experiments/pipeline/run_registry.jl")
include("workflow/experiments/calibration.jl")
include("workflow/io/calibration_drift.jl")

# ========================================
# ANALYSIS: Observables & diagnostics
# ========================================

include("analysis.jl")  # observables + diagnostics + phase exploration umbrella

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
# extension stubs (CUDA Graph hooks, Makie visualisation placeholders).

export split_step_captured!, invalidate_split_step_graph!
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
function animate_dynamics end
export plot_density, plot_spinor, plot_spin_texture, animate_dynamics

include("precompile.jl")

function __init__()
    __init_templates__()
end

end # module
