module SpinorBEC

using LinearAlgebra
using StaticArrays
using FFTW
using JLD2
using YAML
using Unitful
using TimerOutputs
using Random
using Printf
using Dates
using SHA
using SpecialFunctions: erfcx

const TIMER = TimerOutput()

# ========================================
# FOUNDATION: Core types, math, backend
# ========================================

# 1. Type definitions (must be first)
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

# 4. Potentials
include("hamiltonian/potentials/potentials.jl")
include("hamiltonian/potentials/zeeman.jl")
include("hamiltonian/potentials/raman.jl")
include("hamiltonian/potentials/optics.jl")  # Must be before laser_potential (defines OpticalBeam)
include("hamiltonian/potentials/laser_potential.jl")
include("hamiltonian/potentials/optical_trap.jl")

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
include("workflow/initialization/thermal_noise.jl")

# 8. I/O
include("workflow/io/io.jl")
include("workflow/io/unitful_support.jl")

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
include("workflow/experiments/experiment.jl")  # Defines PhaseConfig, GroundStateConfig, etc.
include("workflow/experiments/experiment_runner.jl")
include("workflow/experiments/pipeline.jl")
include("workflow/experiments/run_registry.jl")

# ========================================
# ANALYSIS: Observables & diagnostics
# ========================================

# 11. Analysis (needed by solvers)
include("analysis/observables.jl")
include("analysis/energy.jl")
include("analysis/currents.jl")
include("analysis/vorticity.jl")
include("analysis/diagnostics.jl")
include("analysis/majorana.jl")
include("analysis/tof.jl")
include("analysis/tomography.jl")
include("analysis/faraday.jl")
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
include("solvers/continuation.jl")

# Types
export GridConfig, Grid, SpinSystem, SpinMatrices
export AtomSpecies, InteractionParams, ZeemanParams, LossParams, TensorInteractionCache
export SimParams,
    SimState, FFTPlans, RFFTPlans, Workspace, AdaptiveDtParams, IntegratorConfig
export TOFParams, BdGResult, InstabilityMap, HysteresisResult, RotonParams, SupersolidPrediction
export HarmonicTrap, NoPotential, GravityPotential, CompositePotential
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

# Laser beam potential
export LaserBeamPotential, crossed_laser_trap

# Thomas-Fermi
export thomas_fermi_density, init_psi_thomas_fermi
export add_thermal_noise!, add_thermal_noise, thermal_noise_amplitude, bec_critical_temperature
export simulate_tof, spin_tomography, tomography_sinogram
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

# Raman coupling
export RamanCoupling, apply_raman_step!

# Split-step
export split_step!, prepare_kinetic_phase

# Observables
export total_density, component_density, magnetization
export spin_density_vector, total_norm, total_energy, energy_decomposition
export structure_factor, modulation_contrast
export probability_current, orbital_angular_momentum
export superfluid_velocity, total_angular_momentum, spin_texture_charge
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
export scan_phase_diagram_2d
export find_phase_boundary
export run_simulation!, run_simulation_checkpointed!
export run_simulation_adaptive!, run_simulation_yoshida!, make_workspace, init_psi

# Monitoring & Callbacks
export SimulationCallbacks, LiveMonitor

# I/O
export save_state, load_state

# Pipeline API
export parse_pipeline, run_pipeline, PipelineConfig
export load_config, load_config_from_string, run_config
export run_yaml, run_status, list_runs, compute_run_dir
export apply_override!, apply_overrides, expand_scan_points, parse_override_map
export OverrideScan, ConstrainedJzScan, ScanStabilityConfig
export PotentialConfig, ConstantValue, LinearRamp, interpolate_value

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
function animate_dynamics end
export plot_density, plot_spinor, plot_spin_texture, animate_dynamics

end # module
