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
#   superfluid_fraction            — phase-twist f_s (Leggett plane-average
#       bound + full variational relaxation)
#   vortex_extraction              — per-m vortex line tracing (3D)
#   diagnostics                    — Zeeman/healing-length/TF radius helpers
#   sinatra_diagnostics/grid_resolution — TWA-validity (Sinatra) per-knob
#       helpers + grid/box planning (suggest_grid via ATOM_REGISTRY)
#   majorana                       — Majorana stars + icosahedral order
#   tof/tomography/faraday/imaging — synthetic detection + imaging models
#   topology/synthetic_dimension — winding, monopole, holonomy,
#       synthetic-dim observables
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
include("analysis/superfluid_fraction.jl")  # phase-twist f_s (Leggett bound + relaxed)
include("analysis/vortex_extraction.jl")
include("analysis/diagnostics.jl")
include("analysis/sinatra_diagnostics.jl")  # TWA-validity (Sinatra) per-knob helpers
include("analysis/grid_resolution.jl")  # planning: suggest_grid + sinatra_check (ATOM_REGISTRY)
include("analysis/canonical_polyhedral_states.jl")
include("analysis/majorana.jl")
include("analysis/tof.jl")
include("analysis/tof_multiframe.jl")  # multi-frame (3-layer × far-field) TOF skeleton
include("analysis/tomography.jl")
include("analysis/faraday.jl")
include("analysis/imaging.jl")
include("analysis/fisher.jl")
include("analysis/topology.jl")
include("analysis/synthetic_dimension.jl")
include("analysis/stability_analysis.jl")
include("analysis/spin_rotation.jl")
include("analysis/dipole_field.jl")  # dipolar magnetic field radiated by a (spin-polarised) cloud
include("analysis/larmor_adiabaticity.jl")  # local-field tilt + Larmor vs rotation rate
include("analysis/resonance_dip.jl")  # dip centre + half-depth width of a scanned resonance

# Phase exploration (needs experiments for ScanExperiment).
include("analysis/phases/phase_classification.jl")
include("analysis/phases/phase_boundary.jl")
include("analysis/phases/bogoliubov.jl")
include("analysis/phases/bogoliubov/scan.jl")
include("analysis/phases/sign_pattern.jl")  # Paper #3 §VI Sign Pattern Lemma 1
include("analysis/phases/F6_phase_diagram.jl")  # Paper #2 (g_10, g_12) scan
include("analysis/phases/polyhedral_classifier.jl")  # σ_S fingerprint classifier + direct ΔE
include("analysis/phases/spinor_fingerprint.jl")  # gauge/frame-invariant spinor-texture fingerprint
include("analysis/sweep_contract.jl")    # SweepResult / SweepAxis / Hypothesis + dominant-m margin
include("analysis/sweep_colormaps.jl")   # frozen reference LUTs + per-cell hex + positive-clip range
include("analysis/sweep_golden.jl")      # golden per-cell table + VSUP-lite quality alpha
include("analysis/sweep_viewspec.jl")    # Vega-Lite viewspec dispatcher
