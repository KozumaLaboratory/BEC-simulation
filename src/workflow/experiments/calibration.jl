# --- Calibration subsystem (real submodule) ---
#
# Lab-hardware-units → simulation-units conversions:
#
#   core.jl  — CalibrationSet / CoilCalibration / FORTCalibration /
#              RabiCalibration structs, DEFAULT_CALIBRATION,
#              load_calibration / apply_calibration!,
#              run_yaml_calibrated, CalibrationHistory + CSV loaders +
#              interpolate_calibration
#   drift.jl — sample_trap_drift_omegas, trap_drift_waveforms,
#              apply_trap_drift (built on top of CalibrationHistory)

module Calibration

using YAML
using Dates
using Printf
using LinearAlgebra

# Cross-module imports.
using ..SpinorBEC: AbstractPotential, TimeDependentTrap
using ..SpinorBEC: run_yaml
using ..SpinorBEC: PiecewiseLinearWaveform

include("calibration/core.jl")
include("calibration/drift.jl")

end # module Calibration
