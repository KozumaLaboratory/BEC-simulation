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

const TEST_TIER = lowercase(get(ENV, "SPINORBEC_TEST_TIER", "full"))

# ── Fast tier: pure unit tests, no find_ground_state / run_simulation ──
const FAST_TESTS = [
    "test_atoms.jl",
    "test_grid.jl",
    "test_spin_matrices.jl",
    "test_propagators.jl",
    "test_spin_mixing.jl",
    "test_observables.jl",
    "test_ddi.jl",
    "test_potentials.jl",
    "test_physics_level0.jl",
    "test_physics_level1.jl",
    "test_optics.jl",
    "test_thomas_fermi.jl",
    "test_laser_potential.jl",
    "test_raman.jl",
    "test_unitful.jl",
    "test_texture_observables.jl",
    "test_vorticity_berry.jl",
    "test_majorana.jl",
    "test_diagnostics.jl",
    "test_lhy.jl",
    "test_nematic.jl",
    "test_batched_kinetic.jl",
    "test_ddi_padded.jl",
    "test_clebsch_gordan.jl",
    "test_general_f.jl",
    "test_interactions_constraint.jl",
    "test_io.jl",
    "test_nematic_tensor.jl",
    "test_spherical_harmonics.jl",
    "test_spectral.jl",
    "test_tof.jl",
    "test_bogoliubov.jl",
    "test_phase_scan.jl",
    "test_initialization.jl",
    "test_spinor_utils.jl",
    "test_types_validation.jl",
    "test_currents.jl",
    "test_lhy_2d.jl",
    "test_bogoliubov_enhanced.jl",
    "test_spinor_lhy.jl",
    "test_absorbing_boundary.jl",
    "test_waveform.jl",
    "test_raman_timedep.jl",
    "test_vtk_export.jl",
    "test_infrastructure.jl",
    "test_zeeman_levels.jl",
]

# ── CI tier: fast + core integration tests that run ITP/RTP ──
const CI_EXTRA = [
    "test_split_step.jl",
    "test_simulation.jl",
    "test_ground_state.jl",
    "test_checkpoint.jl",
    "test_energy.jl",
    "test_losses.jl",
    "test_config.jl",
    "test_experiment.jl",
    "test_zeeman_midpoint.jl",
    "test_calibration.jl",
    "test_phase4.jl",
]

# ── Full tier: everything (ci + remaining heavy tests) ──
const FULL_EXTRA = [
    "test_3d.jl",
    "test_adaptive_dt.jl",
    "test_analytic_ground_states.jl",
    "test_analytical_validation.jl",
    "test_angular_momentum.jl",
    "test_continuation.jl",
    "test_phase_boundary.jl",
    "test_physics_level2.jl",
    "test_physics_level3.jl",
    "test_quasi_2d.jl",
    "test_quasi_2d_api.jl",
    "test_tensor_interaction.jl",
    "test_lbfgs.jl",
    "test_pipeline.jl",
    "test_pause_resume.jl",
    "test_twa.jl",
    "test_binary_simulation.jl",
    "test_synthetic_dimension.jl",
    "test_calibration_drift.jl",
]

# ── Physics tier: analytic validation + physics level tests ──
const PHYSICS_TESTS = [
    "test_physics_level0.jl",
    "test_physics_level1.jl",
    "test_physics_level2.jl",
    "test_physics_level3.jl",
    "test_analytic_ground_states.jl",
    "test_analytical_validation.jl",
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
