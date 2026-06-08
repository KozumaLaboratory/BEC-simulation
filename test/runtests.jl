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
    "test_quality.jl",
    "test_dealias_2_3.jl",
    "test_level1_scalar_exact.jl",
    "test_level2_strang_convergence.jl",
    "test_level3_zeeman_only.jl",
    "test_level4_f1_phase_emergence.jl",
    "test_level4_general_F_phase_emergence.jl",
    "test_cn_gS_basis_mapping.jl",
    "test_interactions_dict_api.jl",
    "test_level10_hpsi_self_consistency.jl",
    "test_reference_rhs.jl",
    "test_level11_convergence_sweep.jl",
    "test_level12_production_audit.jl",
    "test_level0_gpu_cpu_consistency.jl",
    "analysis/test_faraday.jl",
    "analysis/test_sign_pattern.jl",
    "analysis/test_polyhedral_classifier.jl",
    "workflow/test_phi_omega_convention.jl",
    "workflow/test_schema_validation_edge_cases.jl",
    "workflow/test_calibration_edge_cases.jl",
    "workflow/test_loss_block_edge_cases.jl",
    "workflow/test_dynamics_lhy_plumbing.jl",
    "workflow/test_b_block_normalize.jl",
    "workflow/test_waveform_inner_duration.jl",
    "workflow/validation/test_run_result.jl",
    "workflow/validation/test_observable_dispatch.jl",
    "workflow/validation/test_open_result.jl",
    "workflow/validation/test_specs_and_check.jl",
    "workflow/validation/test_save_operator_rhs.jl",
    "workflow/validation/test_show.jl",
    "workflow/validation/test_twin_audit.jl",
    "workflow/validation/test_scalar_summary.jl",
    "workflow/test_state_zoo_wrappers_runnable.jl",
    "workflow/test_checkpoint.jl",
    "workflow/test_checkpointed_sweep.jl",
    "manuscript/test_lemma1_general_S.jl",
    "manuscript/test_f5_f7_polyhedral.jl",
    "manuscript/test_f9_f11_polyhedral.jl",
    "manuscript/test_f12_icosahedral.jl",
    "manuscript/test_f12_rational.jl",
    "manuscript/test_f_systematic_lemma1_predictions.jl",
    "manuscript/test_sign_pattern_6j.jl",
    "manuscript/test_D2_H_irrep_character_proof.jl",
    "manuscript/test_rank2_cross_channel_vanishing.jl",
    "manuscript/test_paper3_audit.jl",
    "validation/test_k3_unit_audit.jl",
    "validation/test_L5_operator_rhs_compare.jl",
    "dynamics/test_tdhfb_f1_validation.jl",
    "hamiltonian/test_ddi_convention_factorial.jl",
    "foundation/test_atoms.jl",
    "foundation/test_grid.jl",
    "foundation/test_preset.jl",
    "hamiltonian/test_zeeman_builders.jl",
    "analysis/test_spin_snapshot.jl",
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
    "hamiltonian/test_lhy_level8_unit.jl",
    "hamiltonian/test_singlet_pair.jl",
    "hamiltonian/test_batched_kinetic.jl",
    "hamiltonian/test_ddi_padded.jl",
    "foundation/test_clebsch_gordan.jl",
    "foundation/test_general_f.jl",
    "foundation/test_optical_pumping_rate_eq.jl",
    "analysis/test_forward_image.jl",
    "analysis/test_fisher.jl",
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
    "workflow/test_state_zoo_physics.jl",
    "analysis/test_spinor_utils.jl",
    "foundation/test_property_based.jl",
    "foundation/test_types_validation.jl",
    "analysis/test_currents.jl",
    "hamiltonian/test_lhy_2d.jl",
    "analysis/test_bogoliubov_enhanced.jl",
    "hamiltonian/test_spinor_lhy.jl",
    "hamiltonian/test_spinor_lhy_validation.jl",
    "hamiltonian/test_icosahedral_lhy.jl",
    "hamiltonian/test_lhy_modes_round45.jl",
    "analysis/test_sinatra_diagnostics.jl",
    "analysis/test_grid_resolution.jl",
    "dynamics/test_twa_N_scan.jl",
    "solvers/test_absorbing_boundary.jl",
    "dynamics/test_waveform.jl",
    "hamiltonian/test_raman_timedep.jl",
    "workflow/test_vtk_export.jl",
    "workflow/test_infrastructure.jl",
    "hamiltonian/test_b_block_builders.jl",
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
    # Orphan-test audit 2026-05-25: promoted from unregistered → FAST_TESTS.
    # All are pure unit tests (no ITP / RTP / find_ground_state / run_yaml).
    "analysis/test_imaging.jl",
    "analysis/test_paper3_validation.jl",
    "hamiltonian/test_lhy_factory.jl",
    "hamiltonian/test_lhy_polar.jl",
    "hamiltonian/test_multipole_q_spectrum.jl",
    "solvers/test_compare.jl",
    "solvers/test_pseudo_arclength.jl",
    "workflow/test_active_learning.jl",
    "workflow/test_inspect_config.jl",
    "workflow/test_diff_dicts.jl",
    "workflow/test_inspect_batch.jl",
    "workflow/test_autopilot.jl",
    "workflow/test_catalog.jl",
    "workflow/test_catalog_index.jl",
]

# ── CI tier: fast + core integration tests that run ITP/RTP ──
const CI_EXTRA = [
    "hamiltonian/test_split_step.jl",
    "solvers/test_simulation.jl",
    "solvers/test_ground_state.jl",
    "solvers/test_polished_ground_state.jl",
    "solvers/test_checkpoint.jl",
    "solvers/test_itp_checkpoint_hook.jl",
    "analysis/test_energy.jl",
    "workflow/test_losses.jl",
    "workflow/test_config.jl",
    "workflow/test_experiment.jl",
    "hamiltonian/test_zeeman_midpoint.jl",
    "workflow/test_calibration.jl",
    "workflow/test_phase4.jl",
    "analysis/test_physics_invariants.jl",
    # Sign-bug-proof architecture oracle suite (Phase 1-3 deliverables).
    # Each test runs in seconds; CI tier inclusion gates the bug class
    # documented in `docs/conventions/sign_bug_proof_architecture.md`.
    "oracles/test_hamiltonian_sign_oracles.jl",
    "oracles/test_term_legacy_equivalence.jl",
    "oracles/test_term_consistency.jl",
    # Rename regression: HamTerm subtype names no longer shadow potential types.
    "oracles/test_registry_collision_regression.jl",
    # [GAP-2] closure: MagneticGradientTerm energy/gradient/sign-oracle.
    "oracles/test_magnetic_gradient_gap.jl",
    # Phase 5: registry breakdown bit-identical to legacy energy_decomposition
    # (modulo the now-restored MG slot).
    "oracles/test_registry_energy_decomposition_parity.jl",
    # Physics-aware per-term directional oracles for the high-risk GS-phase
    # terms (SpinC1 / DDI / LHY / Tensor). Replaces formula-tautology
    # placeholders with real physics: FM vs polar GS, prolate vs oblate DDI,
    # n^{5/2} convexity, singlet polar vs FM.
    "oracles/test_physics_aware_sign_oracles.jl",
    # GPU per-term parity gate — covers the 7 terms not exercised by
    # test_level0_gpu_cpu_consistency.jl (TransverseZeeman, DDI, LHY,
    # Tensor, Raman, LightShift, MagneticGradient). Closes the same
    # blind-spot class as the 2026-06-04 GPU-Coriolis miss.
    # Gates on CUDA.functional(); no-op on CPU-only CI.
    "oracles/test_gpu_cpu_per_term_parity.jl",
    # Consolidated term property suite (docs/design/term_oracle_bootstrap.md):
    # step0 FD trust bootstrap (ε-scaling valley) + harness canaries.
    # Grows to absorb the per-term FD / Hermiticity / canary oracles.
    "oracles/test_term_properties.jl",
    # T-CG: CG projection-structure oracle — the magnitude blind-spot
    # killer (arch doc §4.3). Three independent routes (KU / 6j /
    # channel_kernel) + literature inverse anchors, F-swept.
    "oracles/test_cg_projection_oracle.jl",
    # Master oracle: dumb reference vs production registry per term —
    # the gated-redundancy mechanism behind commitment #3. Includes the
    # set-equivalence meta-test and both sides of the declared
    # KNOWN-LIMIT gaps (raman/tensor RHS).
    "oracles/test_master_oracle.jl",
    # Propagator references: per-term dt-valleys (step residual vs the
    # dumb RHS, slope ≈ 1) + Strang order slope vs dumb RK4 (slope ≈ 2).
    # Limit-class oracles for the face where both 2026-06 sign bugs lived.
    "oracles/test_propagator_references.jl",
    # Config-path coverage: counts (term × config) not per term — the
    # meta-test that would have RED-flagged padded-DDI and the absorbing
    # epilogue omission (each a gate-less variant of a "covered" term).
    "oracles/test_path_coverage.jl",
    # Directional / parity gates pinning the ungated physics-duplication
    # clusters the 2026-06-07 redundancy audit upheld as drift-risks
    # (vortex / monopole sign, manuscript spinors vs SSoT, init_psi vs
    # classifier candidates, spin_texture_xy Fx/Fy orientation).
    "oracles/test_redundancy_gates.jl",
    # BdG / Bogoliubov analytic-dispersion anchor: the linearize/Hessian
    # functor every stability (saddle-rejection) verdict rides on, pinned
    # to the known Ueda F=1 polar/FM closed forms + universal polar
    # density branch (was correct-but-ungated; declaration-independent).
    "oracles/test_bogoliubov_anchor.jl",
    # BdG ≡ FD-Hessian of the gated gradient: matrix-level anchor of BOTH
    # blocks (normal 2·h_mf + anomalous M_anom) to the finite-difference
    # Hessian of energy_gradient!, F-swept to Eu F=6 — the
    # chains-off-the-gated-gradient counterpart (anomalous block carries
    # the soft modes the saddle-rejection verdict rides on).
    "oracles/test_bdg_fd_hessian.jl",
    # Fisher identifiability: the preflight instrument for the
    # no-anchor SBI regime (trust ledger column 3) — linearity anchors,
    # θ-valley, degenerate-protocol detection, channel-space chain.
    "oracles/test_fisher_identifiability.jl",
    # Registry ctx-vs-plain gradient identity per term — registered
    # 2026-06-06 with the apply_operator! consolidation.
    "oracles/test_registry_gradient_parity.jl",
    # Fused production diagonal kernel ≡ Σ per-term operators (Δt → 0):
    # the fused==unfused identity gate — the one place the dt-valley
    # suite does not reach (it tests per-term apply_step!, not the
    # fused production kernel). Registered 2026-06-06.
    "oracles/test_operator_trinity_fused_face.jl",
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
    # Orphan-test audit 2026-05-25: promoted from unregistered → FULL_EXTRA.
    # All run ITP / RTP / find_ground_state and require the "full" tier.
    # The two Bug-4 regression pins are particularly load-bearing.
    "analysis/test_bogoliubov_along_boundary.jl",
    "gpu/test_mixed_precision.jl",
    "gpu/test_mixed_precision_phase3.jl",
    "hamiltonian/test_combined_spin_step.jl",
    "hamiltonian/test_light_shift.jl",
    "solvers/test_conservation_properties.jl",
    "solvers/test_itp_ddi_strang_save_every.jl",      # Bug-4 ITP regression pin
    "solvers/test_lbfgs_sobolev_preconditioner.jl",
    "solvers/test_rtp_ddi_strang_save_every.jl",      # Bug-4 RTP regression pin
    "workflow/test_phase_diff_eval.jl",
    # BO-heavy tests: pure Julia (no SpinorBEC physics) but GP fitting is
    # >100s wall, so they live in FULL not FAST.
    "workflow/test_multi_fidelity_bo.jl",
    "workflow/test_triple_point.jl",
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
