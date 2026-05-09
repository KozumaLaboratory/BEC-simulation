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

# 10. Experiments (defines config types needed by phases)
include("workflow/experiments/runtime/adaptive_advice.jl")
include("workflow/experiments/schema/config_override.jl")  # OverrideMap + scan expansion
include("workflow/experiments/schema/schema.jl")           # YAML validation
include("workflow/experiments/schema/units_block.jl")      # opt-in `units:` rewrite
include("workflow/experiments/schema/templates_block.jl")  # template + mixin expansion
include("workflow/experiments/schema/auto_defaults.jl")    # accuracy: + auto_grid:
include("workflow/experiments/schema/B_block.jl")          # B: → zeeman + B_hat split
include("workflow/experiments/schema/noise_block.jl")      # noise: → temperature/twa/sgpe split
include("workflow/experiments/schema/schema_defaults.jl")  # auto-inject ddi:{} etc.
include("workflow/experiments/schema/helpers_types.jl")            # ConstantValue, LinearRamp, PotentialConfig
include("workflow/experiments/runtime/runtime_misc.jl")             # scale_interactions_quasi_2d, grid normalise, noise seed
include("workflow/experiments/runtime/runtime_io.jl")               # JLD2 result-file writers
include("workflow/experiments/schema/parsing_units.jl")            # Unit-aware numeric (B-field, freq, time)
include("workflow/experiments/schema/parsing_blocks.jl")           # Per-block YAML parsers (zeeman/ddi/inter/loss/potential/scan)
include("workflow/experiments/schema/builders_potential.jl")       # _build_potential / _build_beam / _parse_and_build_potential
include("workflow/experiments/schema/builders_phase.jl")           # waveforms + zeeman + raman builders
include("workflow/experiments/runtime/zeeman_levels.jl")
include("workflow/experiments/pipeline/pipeline_types.jl")
include("workflow/experiments/analyzers.jl")  # 8-file analyzers/ subdir umbrella
include("workflow/experiments/pipeline/pipeline_analyzers.jl")       # _run_analyzer dispatch (delegates to all the above)
include("workflow/experiments/pipeline/pipeline_dispatch.jl")    # save_every / b_hat / dt-from-eps / twa / light_shift parsers
include("workflow/experiments/pipeline/pipeline_callbacks.jl")    # sgpe / projected_gp / photon_scattering / live_monitor callback builders
include("workflow/experiments/pipeline/runner.jl")               # parse_pipeline + run_pipeline + _step_dispatch! + AnalyzeStep
include("workflow/experiments/pipeline/run_step_ground_state.jl") # _run_step(::GroundStateStep) + 5 GS helpers
include("workflow/experiments/pipeline/run_step_dynamics.jl")     # _run_step(::DynamicsStep) + dyn helpers + streaming
include("workflow/experiments/pipeline/run_step_binary.jl")       # _run_step(::Binary*Step) + binary helpers
include("workflow/experiments/pipeline/run_step_rotating.jl")     # _run_step(::RotatingBasis*Step) + chirp helpers
include("workflow/experiments/runtime/pulse_sequence.jl")
include("workflow/experiments/runtime/sta_counter_diabatic.jl")
include("workflow/experiments/runtime/feshbach_ramp.jl")
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
include("workflow/experiments/optimization.jl")  # 5-file optimization/ umbrella

# ========================================
# ANALYSIS: Observables & diagnostics
# ========================================

include("analysis.jl")  # observables + diagnostics + phase exploration umbrella

# ========================================
# SOLVERS: Ground state & time evolution
# ========================================

include("solvers.jl")  # ground_state + simulation + lbfgs + continuation + twa + binary umbrella

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
