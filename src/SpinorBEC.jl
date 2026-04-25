module SpinorBEC

using LinearAlgebra
using StaticArrays
using FFTW
using JLD2
using CodecZlib: ZlibCompressor
using YAML
using Unitful
using TimerOutputs
using Random
using Printf
using Dates
using SHA
using SpecialFunctions: erfcx
using Sockets
using WriteVTK

const TIMER = TimerOutput()

# ========================================
# FOUNDATION: Core types, math, backend
# ========================================

# 1. Type definitions (must be first)
include("foundation/waveform.jl")
include("foundation/types.jl")

# 2. Mathematical foundation
include("foundation/grid.jl")
include("foundation/fft_utils.jl")
include("foundation/backend.jl")
include("foundation/spin_matrices.jl")
include("foundation/spinor_utils.jl")
include("foundation/clebsch_gordan.jl")
include("foundation/spherical_harmonics.jl")

# ========================================
# HAMILTONIAN: Interactions & Potentials
# ========================================

# 3. Interactions
include("hamiltonian/interactions/interactions.jl")
include("hamiltonian/interactions/spin_mixing.jl")
include("hamiltonian/interactions/nematic.jl")
include("hamiltonian/interactions/tensor_interaction.jl")
include("hamiltonian/interactions/ddi.jl")
include("hamiltonian/interactions/ddi_padded.jl")
include("hamiltonian/interactions/lhy.jl")
include("hamiltonian/interactions/losses.jl")
include("hamiltonian/interactions/absorbing_boundary.jl")

# 4. Potentials
include("hamiltonian/potentials/potentials.jl")
include("hamiltonian/potentials/zeeman.jl")
include("hamiltonian/potentials/raman.jl")
include("hamiltonian/potentials/optics.jl")  # Must be before laser_potential (defines OpticalBeam)
include("hamiltonian/potentials/laser_potential.jl")
include("hamiltonian/potentials/optical_trap.jl")
include("hamiltonian/potentials/light_shift.jl")

# 5. Propagators
include("hamiltonian/propagators.jl")
include("hamiltonian/yoshida.jl")
include("hamiltonian/split_step.jl")

# ========================================
# WORKFLOW: Initialization, I/O, monitoring, experiments
# ========================================

# 6. Units (needed by atoms.jl and others)
include("workflow/io/units.jl")

# 7. Initialization
include("workflow/initialization/atoms.jl")
include("workflow/initialization/thomas_fermi.jl")
include("workflow/initialization/initialization.jl")
include("workflow/initialization/state_zoo.jl")
include("foundation/binary_state.jl")
include("workflow/initialization/thermal_noise.jl")
include("workflow/initialization/vacuum_noise.jl")

# 8. I/O
include("workflow/io/io.jl")
include("workflow/io/unitful_support.jl")
include("workflow/io/dashboard.jl")
include("workflow/io/vtk_export.jl")
include("workflow/io/run_summary.jl")
include("workflow/io/html_report.jl")
include("workflow/io/budget.jl")
include("workflow/io/scan_summary.jl")

# 9. Monitoring system (needed by solvers)
include("workflow/monitoring/ascii_plot.jl")
include("workflow/monitoring/logging.jl")
include("workflow/monitoring/resource_monitor.jl")
include("workflow/monitoring/notifications.jl")
include("workflow/monitoring/progress.jl")
include("workflow/monitoring/live_monitor.jl")

# 10. Experiments (defines config types needed by phases)
include("workflow/experiments/adaptive_advice.jl")
include("workflow/experiments/config_override.jl")  # OverrideMap + scan expansion
include("workflow/experiments/schema.jl")           # YAML validation
include("workflow/experiments/helpers_types.jl")
include("workflow/experiments/helpers_utils.jl")
include("workflow/experiments/helpers_parsers.jl")
include("workflow/experiments/helpers_builders.jl")
include("workflow/experiments/zeeman_levels.jl")
include("workflow/experiments/pipeline_types.jl")
include("workflow/experiments/pipeline_analyzers.jl")
include("workflow/experiments/pipeline_runner.jl")
include("workflow/experiments/pulse_sequence.jl")
include("workflow/experiments/sta_counter_diabatic.jl")
include("workflow/experiments/feshbach_ramp.jl")
include("solvers/projected_gp.jl")
include("solvers/photon_heating.jl")
include("solvers/sgpe.jl")

# CUDA-graph-accelerated split_step (extended by SpinorBECCUDAExt).
# Default implementation = plain split_step! so CPU workspaces work unchanged.
"""
    split_step_captured!(ws) → Nothing

GPU-accelerated variant of `split_step!` that captures the kernel sequence
into a CUDA Graph on first call, then replays it via a single driver call on
subsequent steps. Eliminates the ~5-10 μs per-kernel launch overhead that
dominates large-D F32 runs.

For CPU workspaces this falls back to plain `split_step!`. Requires
`using CUDA` to load the optimised implementation.
"""
function split_step_captured! end
split_step_captured!(ws::Workspace) = split_step!(ws)

"""
    invalidate_split_step_graph!(ws) → Nothing

Drop the cached CUDA Graph for this workspace. No-op on CPU.
"""
function invalidate_split_step_graph! end
invalidate_split_step_graph!(::Workspace) = nothing
include("workflow/experiments/pipeline_api.jl")
include("workflow/experiments/pipeline_continuation.jl")
include("workflow/experiments/run_registry.jl")
include("workflow/experiments/calibration.jl")
include("workflow/experiments/faraday_fit.jl")
include("workflow/experiments/bayesian_opt.jl")

# ========================================
# ANALYSIS: Observables & diagnostics
# ========================================

# 11. Analysis (needed by solvers)
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
include("analysis/time_resolved.jl")
include("analysis/stability_analysis.jl")
include("analysis/spin_rotation.jl")

# 12. Phase exploration (needs experiments for ScanExperiment)
include("analysis/phases/phase_classification.jl")
include("analysis/phases/phase_boundary.jl")
include("analysis/phases/phase_scan.jl")
include("analysis/phases/bogoliubov.jl")

# ========================================
# SOLVERS: Ground state & time evolution
# ========================================

# 13. Solvers (depend on observables and monitoring)
include("solvers/ground_state.jl")
include("solvers/simulation.jl")
include("solvers/adaptive.jl")
include("solvers/embedded_adaptive.jl")
include("solvers/lbfgs_ground_state.jl")
include("solvers/continuation.jl")
include("solvers/twa.jl")

# Types
export GridConfig, Grid, SpinSystem, SpinMatrices
export AtomSpecies, InteractionParams, ZeemanParams, LossParams, AbsorbingBoundary, LightShift, TensorInteractionCache
export SimParams,
    SimState, FFTPlans, RFFTPlans, Workspace, AdaptiveDtParams, IntegratorConfig
export SimulationResult, TWAConfig, EnsembleResult
export TOFParams, BdGResult, InstabilityMap, HysteresisResult, RotonParams, SupersolidPrediction
export HarmonicTrap, NoPotential, GravityPotential, CompositePotential
export RingPotential, BoxPotential, OpticalLatticePotential, DoubleWellPotential, QuarticPotential
export LaguerreGaussBeam, PlugBeam, ShakenLatticePotential
export MagneticGradient, TimeDependentMagneticGradient
export TimeDependentTrap, TimeDependentInteractions, interactions_at
export AbstractBackend, CPUBackend, CUDABackend
export AbstractLHY, ScalarLHY, Quasi2DLHY, SpinorLHYTable

# Grid
export make_grid,
    make_fft_plans, make_rfft_plans, rfft_output_shape, cell_volume, n_spatial_points
export load_fftw_wisdom, save_fftw_wisdom

# Spin
export spin_matrices

# Atoms — alkali metals
export Li7, Na23, K39, K41, Rb85, Rb87, Cs133
# Atoms — magnetic lanthanides
export Cr52, Dy164, Dy162, Er168, Er166, Eu151
# Atoms — spinless
export Ca40, Sr84, Sr86, Sr88, Yb170, Yb174, Yb176
# Atoms — metastable
export He4star
# Atom registry
export ATOM_REGISTRY, resolve_atom

# Interactions
export compute_interaction_params,
    compute_interaction_params_general_f, compute_c0, compute_c_dd, compute_a_dd
export interaction_params_from_constraint,
    compute_c_total, compute_c_dd_dimless, linear_zeeman_p
export compute_eu151_interactions
export lima_pelster_Q5, compute_c_lhy_with_ddi
export compute_lhy_2d_params
export compute_spinor_lhy_two_channel, compute_spinor_lhy_table
export scale_interactions_quasi_2d

# DDI
export DDIParams,
    DDIBuffers, DDIPaddedContext, make_ddi_params, make_ddi_buffers, make_ddi_padded
export compute_ddi_potential!, apply_ddi_step!

# Potentials
export evaluate_potential

# Zeeman
export zeeman_diagonal, zeeman_energies, TimeDependentZeeman, zeeman_at

# Optical trap
export GaussianBeam, CrossedDipoleTrap

# Optics (Gaussian beam with complex q, ABCD)
export OpticalBeam, propagate, waist_radius, rayleigh_length
export radius_of_curvature, divergence_angle, peak_intensity, beam_intensity
export abcd_free_space, abcd_thin_lens, abcd_curved_mirror, abcd_flat_mirror
export mode_overlap, fiber_coupling

# Light shift
export make_light_shift, make_light_shift_from_trap, apply_light_shift_step!

# Laser beam potential
export LaserBeamPotential, crossed_laser_trap

# Thomas-Fermi
export thomas_fermi_density, init_psi_thomas_fermi
export add_thermal_noise!, add_thermal_noise, thermal_noise_amplitude, bec_critical_temperature,
       add_symmetry_breaking_seed!
export simulate_tof, simulate_tof_with_gradient, sg_separation_peaks
export gaussian_psf_convolve, apply_shot_noise, apply_saturation
export synthesise_absorption_image, faraday_polarization_components
export faraday_snr, momentum_distribution
export winding_number_field, monopole_charge_3d, total_monopole_charge
export non_abelian_holonomy, time_resolved_tomography
export spin_tomography, tomography_sinogram
export FaradayParams, faraday_image, faraday_differential, detect_vortices_faraday

# Spin rotation & EdH/FL reproduction
export spin_rotation_matrix, rotate_quantization_axis
export dipolar_field, apply_edh_rotation, apply_fl_alignment, column_density

# Propagators
export apply_kinetic_step!, apply_kinetic_step_batched!, apply_diagonal_potential_step!
export BatchedKineticCache

# Spin mixing
export apply_spin_mixing_step!

# Nematic
export apply_nematic_step!

# Tensor interaction (general-F)
export apply_tensor_interaction_step!, make_tensor_interaction_cache

# Clebsch-Gordan / Wigner coefficients
export wigner_3j,
    clebsch_gordan, wigner_6j, precompute_cg_table, precompute_cg_array, CGArrayTable

# Losses
export apply_loss_step!

# Absorbing boundary
export AbsorbingBoundary, compute_absorbing_mask, apply_absorbing_boundary!

# Waveform
export AbstractWaveform, Waveform
export ConstantWaveform, RampWaveform, PiecewiseLinearWaveform, FunctionWaveform
export SinusoidalWaveform, ChirpedSinusoidalWaveform, GaussianPulseWaveform, InterpolatedWaveform, CompositeWaveform
export StepWaveform
export evaluate, load_waveform_csv

# Raman coupling
export RamanCoupling, TimeDependentRaman, apply_raman_step!, raman_at
export apply_uniform_spin_rotation!

# Split-step
export split_step!, prepare_kinetic_phase

# Observables
export total_density, component_density, magnetization
export spin_density_vector, total_norm, total_energy, energy_decomposition
export structure_factor, modulation_contrast
export probability_current, orbital_angular_momentum
export superfluid_velocity, total_angular_momentum, spin_texture_charge
export circulation
export extract_vortex_lines_per_m
export wigner_correct_density, ensemble_correlation, ensemble_stderr
export superfluid_vorticity, berry_curvature, singlet_pair_amplitude
export pair_amplitude, pair_amplitude_spectrum
export majorana_stars, icosahedral_order_parameter, detect_point_group
export spherical_harmonic, spinor_angular_density
export nematic_tensor_eigenvalues, biaxiality_parameter
export multipole_order_parameters, multipole_spectrum
export get_cn

# Diagnostics
export spin_mixing_period, spin_mixing_period_si, quadratic_zeeman_from_field
export compute_quadratic_zeeman, compute_quadratic_zeeman_dimless
export healing_length_contact, healing_length_spin, healing_length_ddi
export thomas_fermi_radius, thomas_fermi_radius_harmonic
export phase_diagram_point, component_populations, make_conservation_monitor
export classify_phase, classify_phase_detailed
export estimate_splitting_error, validate_conservation
export power_spectrum
export analyze_stability
export bogoliubov_spectrum, bogoliubov_instability_scan, suggest_grid_params
export fibonacci_sphere_directions, detect_roton, predict_supersolid_params
export instability_angular_map

# Simulation
export find_ground_state, find_ground_state_multistart, scan_continuation,
    scan_continuation_bidirectional
export resume_ground_state, refine_ground_state, load_itp_checkpoint, ITPCheckpoint
export scan_phase_diagram_2d
export find_phase_boundary
export run_simulation!, run_simulation_checkpointed!
export run_simulation_adaptive!, run_simulation_yoshida!, run_simulation_embedded!
export find_ground_state_lbfgs
export run_twa, add_vacuum_noise
export make_workspace, init_psi

# Monitoring & Callbacks
export SimulationCallbacks, LiveMonitor

# I/O
export save_state, load_state, generate_dashboard_data, export_dashboard, serve_dashboard
export estimate_run_budget
export export_vtk, export_vtk_series

# Pipeline API
export parse_pipeline, run_pipeline, PipelineConfig
export sta_counter_diabatic_q_quench, build_sta_zeeman
export feshbach_ramp, feshbach_c0_wf
export apply_projected_gp!, projected_gp_callback
export apply_photon_scattering!, photon_scattering_callback
export apply_sgpe_step!, sgpe_callback
export split_step_captured!, invalidate_split_step_graph!
export load_config, load_config_from_string, run_config
export run_yaml, run_status, list_runs, compute_run_dir
export print_run_summary, compare_runs, generate_html_report
export load_target_faraday, fit_faraday_param
export bayesian_optimize, gp_predict, expected_improvement
export CalibrationSet, CoilCalibration, FORTCalibration, RabiCalibration
export DEFAULT_CALIBRATION, load_calibration, apply_calibration!, run_yaml_calibrated
export coil_mv_to_gauss, fort_mw_to_trap_hz, rabi_mw_to_rad_s
export CalibrationHistory, load_calibration_history, load_calibration_csv,
       interpolate_calibration
export BinaryCouplings, BinaryState, find_binary_ground_state,
       is_immiscible, droplet_regime_petrov,
       binary_overlap, binary_separation_radius,
       SpinorBinaryCouplings, SpinorBinaryState, find_spinor_binary_ground_state
export init_psi_polar, init_psi_ferromagnetic, init_psi_ferromagnetic_min,
       init_psi_uniform, init_psi_antiferromagnetic, init_psi_random,
       init_psi_spin_coherent, init_psi_fl_vortex, init_psi_spin_helix,
       init_psi_cyclic, init_psi_biaxial_nematic, init_psi_polar_core_vortex,
       init_psi_bright_soliton, init_psi_dark_soliton, init_psi_skyrmion,
       init_psi_wavepacket, init_psi_domain_wall, init_psi_two_packets,
       init_psi_chiral_spin_vortex, init_psi_magnetic_domain,
       init_psi_vortex_lattice, init_psi_skyrmion_lattice
export apply_override!, apply_overrides, expand_scan_points, parse_override_map
export OverrideScan, ConstrainedJzScan
export PotentialConfig, ConstantValue, LinearRamp, interpolate_value
export validate_pipeline!, validate_config!
export scan_summary, scan_energy_comparison, print_scan_summary

# Units
export Units

# Tracing
export TIMER, enable_tracing!, disable_tracing!, reset_tracing!

function enable_tracing!()
    TimerOutputs.enable_debug_timings(SpinorBEC)
    enable_timer!(TIMER)
end

function disable_tracing!()
    disable_timer!(TIMER)
end

function reset_tracing!()
    TimerOutputs.reset_timer!(TIMER)
end

# Visualization (defined in extension, exported here for discoverability)
function plot_density end
function plot_spinor end
function plot_spin_texture end
function save_column_density_png end
function animate_dynamics end
export plot_density, plot_spinor, plot_spin_texture, animate_dynamics, save_column_density_png

end # module
