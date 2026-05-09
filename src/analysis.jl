# --- Analysis subsystem umbrella ---
#
# Observable extraction + diagnostic computations on a wavefunction. Files
# are grouped by topic; all are flat-namespace contributors that export
# their public API at their definition sites.
#
#   compare/observables/ensemble — generic comparison metric, density +
#       spin observables, ensemble stat helpers
#   energy/currents/vorticity     — energy decomposition, probability
#       current, superfluid velocity/vorticity
#   vortex_extraction              — per-m vortex line tracing (3D)
#   diagnostics                    — Zeeman/healing-length/TF radius helpers
#   majorana                       — Majorana stars + icosahedral order
#   tof/tomography/faraday/imaging — synthetic detection + imaging models
#   topology/synthetic_dimension/time_resolved — winding, monopole,
#       holonomy, synthetic-dim observables, time-resolved tomography
#   stability_analysis             — splitting error + conservation checks
#   spin_rotation                  — spin rotation matrix + EdH/FL helpers
#   phases/{phase_classification,phase_boundary,bogoliubov,bogoliubov/scan}
#       — phase classification + Bogoliubov spectrum + instability scans

include("analysis/compare.jl")
include("analysis/observables.jl")
include("analysis/ensemble.jl")
include("analysis/energy.jl")
include("analysis/currents.jl")
include("analysis/vorticity.jl")
include("analysis/vortex_extraction.jl")
include("analysis/diagnostics.jl")
include("analysis/majorana.jl")
include("analysis/tof.jl")
include("analysis/tomography.jl")
include("analysis/faraday.jl")
include("analysis/imaging.jl")
include("analysis/topology.jl")
include("analysis/synthetic_dimension.jl")
include("analysis/time_resolved.jl")
include("analysis/stability_analysis.jl")
include("analysis/spin_rotation.jl")

# Phase exploration (needs experiments for ScanExperiment).
include("analysis/phases/phase_classification.jl")
include("analysis/phases/phase_boundary.jl")
include("analysis/phases/bogoliubov.jl")
include("analysis/phases/bogoliubov/scan.jl")
