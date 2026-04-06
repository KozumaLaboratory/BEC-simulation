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
using SpecialFunctions: erfcx

const TIMER = TimerOutput()

# 1. Type definitions (must be first)
include("types.jl")

# 2. Units (needed by atoms.jl and others)
include("io/units.jl")

# 3. Mathematical foundation
include("math/grid.jl")
include("math/fft_utils.jl")
include("math/backend.jl")
include("math/spin_matrices.jl")
include("math/spinor_utils.jl")
include("math/clebsch_gordan.jl")
include("math/spherical_harmonics.jl")

# 4. Interactions
include("interactions/interactions.jl")
include("interactions/spin_mixing.jl")
include("interactions/nematic.jl")
include("interactions/tensor_interaction.jl")
include("interactions/ddi.jl")
include("interactions/ddi_padded.jl")
include("interactions/lhy.jl")
include("interactions/losses.jl")

# 5. Potentials
include("potentials/potentials.jl")
include("potentials/zeeman.jl")
include("potentials/raman.jl")
include("potentials/optics.jl")  # Must be before laser_potential (defines OpticalBeam)
include("potentials/laser_potential.jl")
include("potentials/optical_trap.jl")

# 6. Propagators (depend on interactions & potentials)
include("physics/propagators.jl")
include("physics/yoshida.jl")

# 7. Time evolution core
include("physics/split_step.jl")
include("physics/adaptive.jl")

# 8. Initialization
include("initial/atoms.jl")
include("initial/thomas_fermi.jl")
include("initial/initialization.jl")

# 9. Monitoring system
include("monitoring/ascii_plot.jl")
include("monitoring/logging.jl")
include("monitoring/resource_monitor.jl")
include("monitoring/notifications.jl")
include("monitoring/progress.jl")
include("monitoring/live_monitor.jl")

# 10. Simulation engines
include("physics/simulation.jl")
include("physics/ground_state.jl")

# 11. Analysis & observables
include("analysis/observables.jl")
include("analysis/energy.jl")
include("analysis/currents.jl")
include("analysis/vorticity.jl")
include("analysis/diagnostics.jl")
include("analysis/majorana.jl")
include("analysis/tof.jl")
include("analysis/stability_analysis.jl")

# 12. Experiment scenarios (must be before phases)
include("experiments/adaptive_advice.jl")
include("experiments/experiment.jl")  # Defines PhaseConfig, GroundStateConfig, etc.
include("experiments/experiment_runner.jl")
include("experiments/config.jl")  # Uses types from experiment.jl
include("experiments/config_runner.jl")

# 13. Phase exploration
include("phases/phase_classification.jl")
include("phases/phase_boundary.jl")
include("phases/phase_scan.jl")
include("phases/continuation.jl")
include("phases/bogoliubov.jl")

# 14. I/O (units.jl already included earlier)
include("io/io.jl")
include("io/unitful_support.jl")

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
export simulate_tof

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

# Config types
export ConstantValue, LinearRamp, RampOrConstant, interpolate_value
export PotentialConfig, PhaseConfig, GroundStateConfig, DDIConfig, SystemConfig
export ScanValues, ScanAxis, ContinuationConfig, ScanStabilityConfig, ScanPointOverride
export MultiStartConfig, AbstractScanSpec, ParameterScan, ConstrainedJzScan
export AbstractExperimentSpec, GroundStateExperiment, DynamicsExperiment, ScanExperiment
export PerturbationConfig, OutputConfig, ObservablesConfig, UnifiedConfig
export load_config, load_config_from_string, run_config, seed_noise

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
