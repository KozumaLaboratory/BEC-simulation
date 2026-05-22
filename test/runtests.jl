using Test
using SpinorBEC

# ── Test tier system ──────────────────────────────────────────────
# SPINORBEC_TEST_TIER controls which tests run:
#   fast     ~30s   lightweight unit tests only (no ITP/RTP)
#   ci       ~3min  fast + core integration (split_step, simulation, ground_state)
#   full     ~6min  everything (default)
#   physics  validation-only subset (analytic + physics levels)
#
# Usage:
#   SPINORBEC_TEST_TIER=fast julia --project=. -e 'using Pkg; Pkg.test()'
#   SPINORBEC_TEST_TIER=ci   julia --project=. -e 'using Pkg; Pkg.test()'
#
# Layout: test/ mirrors src/ subdirs (foundation, hamiltonian, solvers,
# workflow, analysis, rotating_basis, dynamics, gpu). Each entry below
# is a relative path from this file.

const TEST_TIER = lowercase(get(ENV, "SPINORBEC_TEST_TIER", "full"))

# ── Fast tier: pure unit tests, no find_ground_state / run_simulation ──
const FAST_TESTS = [
    "foundation/test_atoms.jl",
    "foundation/test_grid.jl",
    "foundation/test_spin_matrices.jl",
    "hamiltonian/test_propagators.jl",
    "hamiltonian/test_spin_mixing.jl",
    "analysis/test_observables.jl",
    "hamiltonian/test_ddi.jl",
    "hamiltonian/test_potentials.jl",
    "analysis/test_physics_level0.jl",
    "analysis/test_physics_level1.jl",
    "analysis/test_optics.jl",
    "analysis/test_thomas_fermi.jl",
    "hamiltonian/test_laser_potential.jl",
    "hamiltonian/test_raman.jl",
    "foundation/test_unitful.jl",
    "analysis/test_texture_observables.jl",
    "analysis/test_vorticity_berry.jl",
    "hamiltonian/test_majorana.jl",
    "analysis/test_diagnostics.jl",
    "analysis/test_phase_classification_polyhedral.jl",
    "hamiltonian/test_lhy.jl",
    "hamiltonian/test_singlet_pair.jl",
    "hamiltonian/test_batched_kinetic.jl",
    "hamiltonian/test_ddi_padded.jl",
    "foundation/test_clebsch_gordan.jl",
    "foundation/test_general_f.jl",
    "hamiltonian/test_interactions_constraint.jl",
    "workflow/test_io.jl",
    "workflow/test_recommend_backend_dtype.jl",
    "analysis/test_nematic_tensor.jl",
    "foundation/test_spherical_harmonics.jl",
    "analysis/test_spectral.jl",
    "analysis/test_tof.jl",
    "analysis/test_bogoliubov.jl",
    "workflow/test_phase_scan.jl",
    "workflow/test_initialization.jl",
    "workflow/test_state_zoo_macro_equivalence.jl",
    "analysis/test_spinor_utils.jl",
    "foundation/test_property_based.jl",
    "foundation/test_types_validation.jl",
    "analysis/test_currents.jl",
    "hamiltonian/test_lhy_2d.jl",
    "analysis/test_bogoliubov_enhanced.jl",
    "hamiltonian/test_spinor_lhy.jl",
    "hamiltonian/test_icosahedral_lhy.jl",
    "hamiltonian/test_lhy_modes_round45.jl",
    "dynamics/test_sinatra_helpers.jl",
    "dynamics/test_utils_resolution_sinatra.jl",
    "dynamics/test_twa_N_scan.jl",
    "solvers/test_absorbing_boundary.jl",
    "dynamics/test_waveform.jl",
    "hamiltonian/test_raman_timedep.jl",
    "workflow/test_vtk_export.jl",
    "workflow/test_infrastructure.jl",
    "hamiltonian/test_zeeman_levels.jl",
    "hamiltonian/test_zeeman_accessors.jl",
    # TDHFB local-approximation engine (channel kernel + Δ + voxel BdG step
    # + energy functional + conservation suite).
    "foundation/test_tdhfb_state.jl",
    "hamiltonian/test_tdhfb_hf_matrix.jl",
    "hamiltonian/test_tdhfb_hf_matrix_generic.jl",
    "hamiltonian/test_tdhfb_ku_c01_to_g_S.jl",
    "hamiltonian/test_tdhfb_strang_step.jl",
    "hamiltonian/test_tdhfb_y4_midpoint.jl",
    "hamiltonian/test_tdhfb_evolve.jl",
    "hamiltonian/test_tdhfb_hfb_modes.jl",
    "hamiltonian/test_tdhfb_pair_potential.jl",
    "hamiltonian/test_tdhfb_conservation.jl",
]

# ── CI tier: fast + core integration tests that run ITP/RTP ──
const CI_EXTRA = [
    "hamiltonian/test_split_step.jl",
    "solvers/test_simulation.jl",
    "solvers/test_ground_state.jl",
    "solvers/test_checkpoint.jl",
    "analysis/test_energy.jl",
    "workflow/test_losses.jl",
    "workflow/test_config.jl",
    "workflow/test_experiment.jl",
    "hamiltonian/test_zeeman_midpoint.jl",
    "workflow/test_calibration.jl",
    "workflow/test_phase4.jl",
    "analysis/test_physics_invariants.jl",
]

# ── Full tier: everything (ci + remaining heavy tests) ──
const FULL_EXTRA = [
    "solvers/test_3d.jl",
    "solvers/test_adaptive_dt.jl",
    "analysis/test_analytic_ground_states.jl",
    "analysis/test_analytical_validation.jl",
    "analysis/test_angular_momentum.jl",
    "solvers/test_continuation.jl",
    "workflow/test_phase_boundary.jl",
    "analysis/test_physics_level2.jl",
    "analysis/test_physics_level3.jl",
    "solvers/test_quasi_2d.jl",
    "solvers/test_quasi_2d_api.jl",
    "hamiltonian/test_tensor_interaction.jl",
    "solvers/test_lbfgs.jl",
    "workflow/test_pipeline.jl",
    "solvers/test_pause_resume.jl",
    "dynamics/test_twa.jl",
    "solvers/test_binary_simulation.jl",
    "solvers/test_synthetic_dimension.jl",
    "workflow/test_calibration_drift.jl",
    "workflow/test_dynamics_knobs.jl",
    "gpu/test_cuda_equivalence.jl",
    "hamiltonian/test_tdhfb_gpu_phase5ab.jl",
    "hamiltonian/test_tdhfb_gpu_phase5c_expm.jl",
    "hamiltonian/test_tdhfb_gpu_phase5c_hf.jl",
    # Option γ rotating-basis tests (added 2026-04-27..29).
    "rotating_basis/test_rotating_basis_gpe.jl",
    "rotating_basis/test_rotating_basis_analyzers.jl",
    "rotating_basis/test_rotating_basis_phase_ii.jl",
    "rotating_basis/test_rotating_basis_phase_iii.jl",
    "rotating_basis/test_rotating_basis_pipeline_parsing.jl",
    "rotating_basis/test_rotating_basis_f32.jl",
    # Higher-order integrator tests
    "hamiltonian/test_higher_order_integrators.jl",
    "hamiltonian/test_integrator_order_meanfield.jl",
    "hamiltonian/test_cfet4_order.jl",
    "hamiltonian/test_adaptive_dt.jl",
    # Lima-Pelster Q5 + scalar eGPE
    "hamiltonian/test_lima_pelster_q5.jl",
    "rotating_basis/test_scalar_egpe_dipole_kernel.jl",
    "rotating_basis/test_scalar_egpe_smoke.jl",
    # Round-1..3 regression pins
    "rotating_basis/test_rotating_frame_regression.jl",
    "analysis/test_bogoliubov_goldstone.jl",
    "dynamics/test_sgpe_fdr.jl",
]

# ── Physics tier: analytic validation + physics level tests ──
const PHYSICS_TESTS = [
    "analysis/test_physics_level0.jl",
    "analysis/test_physics_level1.jl",
    "analysis/test_physics_level2.jl",
    "analysis/test_physics_level3.jl",
    "analysis/test_analytic_ground_states.jl",
    "analysis/test_analytical_validation.jl",
]

function select_tests(tier::String)
    if tier == "fast"
        return FAST_TESTS
    elseif tier == "ci"
        return vcat(FAST_TESTS, CI_EXTRA)
    elseif tier == "full"
        return vcat(FAST_TESTS, CI_EXTRA, FULL_EXTRA)
    elseif tier == "physics"
        return PHYSICS_TESTS
    else
        @warn "Unknown SPINORBEC_TEST_TIER=$tier, falling back to full"
        return vcat(FAST_TESTS, CI_EXTRA, FULL_EXTRA)
    end
end

@testset "SpinorBEC (tier=$TEST_TIER)" begin
    for f in select_tests(TEST_TIER)
        include(f)
    end
end
