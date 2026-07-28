# Tier membership — the single source of truth for which test files run in
# each tier. Shared by runtests.jl (the runner) and run_chunk.jl, so a file
# like test_tier_membership.jl still sees FAST_TESTS / MANUAL_TESTS_ALLOWLIST
# / select_tests when it runs inside a parallel chunk process. Tier
# membership stays explicit (CLAUDE.md commitment #7).

# ── Fast tier: pure unit tests, no find_ground_state / run_simulation ──
const FAST_TESTS = [
    "test_quality.jl",
    # Meta-test: every test_*.jl under test/ is in exactly one tier or the
    # MANUAL allowlist (enforces CLAUDE.md commitment #7 structurally).
    "test_tier_membership.jl",
    "test_level1_scalar_exact.jl",
    "test_level2_strang_convergence.jl",
    "test_level3_zeeman_only.jl",
    "test_cn_gS_basis_mapping.jl",
    "test_interactions_dict_api.jl",
    "test_level10_hpsi_self_consistency.jl",
    "test_reference_rhs.jl",
    "test_level12_production_audit.jl",
    "test_level0_gpu_cpu_consistency.jl",
    "analysis/test_faraday.jl",
    "analysis/test_spin_rotation.jl",
    "analysis/test_sign_pattern.jl",
    "analysis/test_polyhedral_classifier.jl",
    "analysis/test_spinor_fingerprint.jl",
    "analysis/test_larmor_adiabaticity.jl",
    # TODO(dipole_field): re-add when test/analysis/test_dipole_field.jl lands —
    # the referenced file was never committed (left a dangling include that
    # reddened the full suite). src/analysis/dipole_field.jl is likewise absent.
    # "analysis/test_dipole_field.jl",
    "workflow/test_phi_omega_convention.jl",
    "workflow/test_schema_validation_edge_cases.jl",
    "workflow/test_calibration_edge_cases.jl",
    "workflow/test_loss_block_edge_cases.jl",
    "workflow/test_dynamics_lhy_plumbing.jl",
    "workflow/test_lhy_texture_warning.jl",
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
    "workflow/test_gs_stage_cache.jl",
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
    "oracles/test_scalar_lhy_si_roundtrip.jl",
    "validation/test_k3_unit_audit.jl",
    "validation/test_L5_operator_rhs_compare.jl",
    "dynamics/test_tdhfb_f1_validation.jl",
    "hamiltonian/test_ddi_convention_factorial.jl",
    "foundation/test_atoms.jl",
    "foundation/test_grid.jl",
    "foundation/test_preset.jl",
    "foundation/test_noise_waveform.jl",
    "foundation/test_waveform_bandwidth.jl",
    "hamiltonian/test_zeeman_builders.jl",
    "analysis/test_spin_snapshot.jl",
    "foundation/test_spin_matrices.jl",
    "hamiltonian/test_propagators.jl",
    "hamiltonian/test_spin_mixing.jl",
    "analysis/test_observables.jl",
    "hamiltonian/test_ddi.jl",
    "hamiltonian/test_ddi_nyquist_xy_symmetry.jl",
    "hamiltonian/test_ddi_truncated_kernel.jl",
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
    "analysis/test_bogoliubov.jl",
    "workflow/test_phase_scan.jl",
    "workflow/test_initialization.jl",
    "workflow/test_state_zoo_macro_equivalence.jl",
    "workflow/test_state_zoo_physics.jl",
    "analysis/test_spinor_utils.jl",
    "foundation/test_property_based.jl",
    "foundation/test_types_validation.jl",
    "analysis/test_currents.jl",
    "analysis/test_superfluid_fraction.jl",
    "analysis/test_superfluid_fraction_gp_twist.jl",
    "solvers/test_scalar_ddi_transverse_pad.jl",
    "hamiltonian/test_lhy_2d.jl",
    "analysis/test_bogoliubov_enhanced.jl",
    "hamiltonian/test_spinor_lhy.jl",
    "hamiltonian/test_tabulated_lhy_propagator_parity.jl",
    "hamiltonian/test_lhy_energy_convention.jl",
    "hamiltonian/test_spatial_lhy.jl",
    "hamiltonian/test_lhy_gradient_all_modes.jl",
    "hamiltonian/test_spinor_lhy_validation.jl",
    "hamiltonian/test_icosahedral_lhy.jl",
    "hamiltonian/test_lhy_modes_round45.jl",
    "analysis/test_sinatra_diagnostics.jl",
    "analysis/test_grid_resolution.jl",
    "dynamics/test_waveform.jl",
    "hamiltonian/test_raman_timedep.jl",
    "workflow/test_vtk_export.jl",
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
    # Evaporation model + euv3 calibration units (pure 0-D kinetics / table
    # lookups, no ITP/RTP) — merged from main's evaporation-ramp-optimizer.
    "solvers/test_evaporation.jl",
    "solvers/test_condensate.jl",
    "workflow/test_euv3_coils.jl",
    "workflow/test_feshbach.jl",
]

# ── CI tier: fast + core integration tests that run ITP/RTP ──
const CI_EXTRA = [
    "validation/test_dipolar_supersolid_tube.jl",
    "hamiltonian/test_split_step.jl",
    "solvers/test_simulation.jl",
    "solvers/test_ground_state.jl",
    "solvers/test_polished_ground_state.jl",
    "solvers/test_checkpoint.jl",
    "solvers/test_itp_checkpoint_hook.jl",
    "analysis/test_energy.jl",
    # Evaporation OPTIMIZATION/SCAN tools run the scalar model in loops
    # (optimizer, parameter scans, K3 fit) — aggregate-heavy, kept out of the
    # per-push fast tier. Merged from main's evaporation-ramp-optimizer.
    "solvers/test_evaporation_tools.jl",
    # Demoted from FAST 2026-06-15 (#15): run find_ground_state / run_simulation!
    # / run_yaml-scan / full pipeline (ITP/RTP), violating the fast-tier "no
    # ITP/RTP" contract. Validation-ladder anchors (Level 4/11) still gate here
    # + nightly full.
    "test_level4_f1_phase_emergence.jl",
    "test_level4_general_F_phase_emergence.jl",
    "test_level11_convergence_sweep.jl",
    "test_dealias_2_3.jl",
    "dynamics/test_twa_N_scan.jl",
    "solvers/test_absorbing_boundary.jl",
    "workflow/test_infrastructure.jl",
    # Spatial / B(r,t) Zeeman + TOF (#14): split_step / simulate_* (per-voxel
    # propagation, multi-frame TOF) — integration weight, not fast-tier units.
    "analysis/test_tof.jl",
    "analysis/test_spatial_zeeman.jl",
    "analysis/test_zeeman_field_brt.jl",
    "analysis/test_tof_multiframe.jl",
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
    "oracles/test_hamiltonian_hermiticity.jl",
    "oracles/test_kinetic_trap_analytic.jl",
    "oracles/test_zeeman_diagonal_analytic.jl",
    "oracles/test_zeeman_full_analytic.jl",
    "oracles/test_propagator_unitarity.jl",
    "oracles/test_spin_operator_algebra.jl",
    "oracles/test_energy_operator_identity.jl",
    "oracles/test_ddi_uniform_zero.jl",
    "oracles/test_contact_meanfield_analytic.jl",
    "oracles/test_strang_energy_conservation.jl",
    "oracles/test_parity_symmetry.jl",
    "oracles/test_transverse_zeeman_analytic.jl",
    "oracles/test_spin_c1_analytic.jl",
    "oracles/test_ddi_qtensor_relations.jl",
    "oracles/test_meanfield_energy_half.jl",
    "oracles/test_spin_density_consistency.jl",
    "oracles/test_magnetization_conservation_rtp.jl",
    "oracles/test_harmonic_virial.jl",
    "oracles/test_velocity_planewave.jl",
    "oracles/test_global_phase_covariance.jl",
    "oracles/test_ddi_translation_covariance.jl",
    "oracles/test_coriolis_energy_sign.jl",
    "oracles/test_ddi_energy_potential_crosscheck.jl",
    "oracles/test_kinetic_translation_covariance.jl",
    "oracles/test_continuity_equation.jl",
    "oracles/test_energy_decomposition_sum.jl",
    "oracles/test_apply_operator_accumulates.jl",
    "oracles/test_loss_nonunitarity.jl",
    "oracles/test_registry_completeness.jl",
    "oracles/test_lhy_analytic.jl",
    "oracles/test_lhy_full_bdg_closed_form_parity.jl",
    "oracles/test_light_shift_analytic.jl",
    "oracles/test_magnetic_gradient_analytic.jl",
    "oracles/test_tensor_analytic.jl",
    "oracles/test_raman_analytic.jl",
    "oracles/test_term_legacy_equivalence.jl",
    "oracles/test_term_consistency.jl",
    # Single-source gate for the F₊ ladder coefficient √(F(F+1)−m(m+1)) and the
    # singlet-pair sign (−1)^{F−m}. Pins every spin-ladder propagator/energy/
    # gradient to `fp_ladder_coeff` / `singlet_pair_sign`, so the formula can no
    # longer drift independently across c₁ / Raman / spatial-Zeeman / DDI sites.
    "oracles/test_spin_ladder_single_source.jl",
    # Imaginary-time propagator generator == registry operator (spin-mixing
    # + DDI). Gates the 2026-06-15 per-voxel exp(-(m+F)θ) density-bias class
    # that only the propagator↔operator generator comparison can see.
    "oracles/test_imag_time_propagator_generator.jl",
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
    # Trapped non-Hermitian BdG (dynamical axis) ≡ homogeneous BdG in the
    # uniform limit: matrix-free σ_z[L M; M* L*] from the gated HvP vs the
    # CG-sum homogeneous matrices at the box k-modes + quartet symmetry.
    "oracles/test_trapped_bdg_spectrum.jl",
    # gate-2 eigensolver: preconditioned block LOBPCG (trapped_bdg_low_modes)
    # ≡ bare Lanczos (trapped_bdg_lowest_eigenvalue) on λ_min, + Kato–Temple
    # two-sided certificate bracket.
    "oracles/test_bdg_low_modes_lobpcg.jl",
    # StabilitySpec three-valued gate: replays the non-stationary /
    # non-converged false-verdict class (mistake_stability_verdict_from_
    # nonstationary_point) — gate returns :indeterminate, not a confident
    # λ_min, when stationarity or the Lanczos Ritz residual is unmet, and
    # abstains overall while the trapped dynamical BdG axis is unbuilt.
    "oracles/test_stability_indeterminate.jl",
    # Sneaky-prover (adversarial verifier hardening): hands the StabilitySpec
    # gate a stationary SADDLE (polar at c1<0) and asserts the energetic axis
    # catches its negative mode (:fail) — a false ACCEPT would be a Lanczos
    # hidden-mode hole. The active-adversary upgrade of the frozen replay.
    "oracles/test_stability_sneaky_prover.jl",
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
    "analysis/test_larmor_precession.jl",
    "solvers/test_quasi_2d.jl",
    "solvers/test_quasi_2d_api.jl",
    "hamiltonian/test_tensor_interaction.jl",
    "solvers/test_lbfgs.jl",
    "solvers/test_lbfgs_accuracy_floor.jl",
    "workflow/test_pipeline.jl",
    "solvers/test_pause_resume.jl",
    "dynamics/test_twa.jl",
    "solvers/test_binary_simulation.jl",
    "solvers/test_synthetic_dimension.jl",
    "workflow/test_calibration_drift.jl",
    "workflow/test_dynamics_knobs.jl",
    "gpu/test_cuda_equivalence.jl",
    "gpu/test_superfluid_fraction_gpu.jl",
    # GPU=CPU parity for the projected-GP momentum cutoff. Gates the host-array
    # mask broadcast bug (ws.grid.k_squared is a host Array even on a GPU
    # workspace); no-op on CPU-only CI. CPU high-k-removal sanity always runs.
    "gpu/test_projected_gp_parity.jl",
    "gpu/test_gpu_tabulated_lhy_parity.jl",
    "hamiltonian/test_tdhfb_gpu_phase5ab.jl",
    "hamiltonian/test_tdhfb_gpu_phase5c_expm.jl",
    "hamiltonian/test_tdhfb_gpu_phase5c_hf.jl",
    # Option γ magnetostir pipeline (kind: rotating_basis). The standalone
    # RotatingBasisWS engine + its equivalence-gate / integrator-order tests were
    # retired 2026-06-21 (docs/design/rotating_basis_unification.md): the
    # magnetostir GS+dynamics now run on the standard split-step path, validated
    # by the pipeline-parsing test, the self-contained physics gate, and the
    # dict-based analyzers.
    "rotating_basis/test_rotating_basis_analyzers.jl",
    "rotating_basis/test_rotating_basis_pipeline_parsing.jl",
    "rotating_basis/test_magnetostir_pipeline_physics.jl",
    # First-principles φ̇≠0 gate: lab-frame pipeline vs exact single-spin
    # reference. Arbitrated the engine retirement — the retired engine's
    # rotating-frame inertial term was ~1.8e-3 off; the unified path matches
    # the exact dynamics to ~1e-5.
    "rotating_basis/test_magnetostir_rotating_field_analytic.jl",
    "hamiltonian/test_adaptive_dt.jl",
    # Lima-Pelster Q5 + scalar eGPE
    "hamiltonian/test_lima_pelster_q5.jl",
    "rotating_basis/test_scalar_egpe_dipole_kernel.jl",
    "rotating_basis/test_scalar_egpe_smoke.jl",
    # Round-1..3 regression pins
    "rotating_basis/test_rotating_frame_regression.jl",
    "analysis/test_bogoliubov_goldstone.jl",
    "dynamics/test_sgpe_fdr.jl",
    "dynamics/test_sgpe_stoof.jl",
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
    "solvers/test_ddi_strang_order.jl",               # DDI 2nd-order (midpoint MF)
    "solvers/test_yoshida_ddi_order.jl",              # DDI 4th-order (midpoint triple-jump)
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
    "analysis/test_larmor_precession.jl",
    "analysis/test_analytic_ground_states.jl",
    "analysis/test_analytical_validation.jl",
]

# ── Manual allowlist: tests intentionally NOT run by any tier ──
# These depend on environment conditions the default runner cannot
# guarantee (GPU hardware, opt-in heavy YAML, a free TCP port). They are
# documented in test/MANUAL_TESTS.md with the exact invocation. Listed
# here so the tier-membership meta-test counts them as "accounted for"
# (i.e. they are deliberately manual, not orphaned). Run them by hand.
const MANUAL_TESTS_ALLOWLIST = [
    "gpu/test_cuda.jl",                              # coarse CUDA smoke (gated, but needs GPU to be useful)
    "workflow/test_active_learning_yaml.jl",         # heavy YAML (SPINORBEC_RUN_HEAVY_YAML)
    "workflow/test_multi_fidelity_yaml.jl",          # heavy YAML (SPINORBEC_RUN_HEAVY_YAML)
    "workflow/test_klaus_validation.jl",             # heavy YAML scenario pending schema audit
    "workflow/test_live_monitor.jl",                 # spawns dashboard server on a TCP port
]

# Derived view (NOT a partition list): every `oracles/` gate, regardless of which
# tier list it lives in. The `oracles` pseudo-tier runs JUST these so the per-PR
# CI can gate the bug classes cheaply (the full `ci` tier is ~30-45 min and only
# runs nightly — that is how 5 oracle gates rotted RED unprotected, 2026-06-21).
# Auto-maintaining: a new `test/oracles/<x>.jl` added to any tier list is picked
# up here for free.
const ORACLE_TESTS = filter(t -> startswith(t, "oracles/"), vcat(FAST_TESTS, CI_EXTRA, FULL_EXTRA))

# ── Parallel-balance cost model ───────────────────────────────────────
# Per-file cost estimate (seconds), measured on the full tier, used only to
# balance the parallel chunks (LPT bin-packing in runtests.jl). Only the heavy
# outliers need an entry; the long tail defaults to _DEFAULT_COST. A wrong
# estimate costs balance, never correctness — but a silently-stale estimate lets
# CI wall-time regress unnoticed, which `warn_cost_drift` (below) guards against.
# Lives here (not runtests.jl) so the chunk processes (run_chunk.jl) can run the
# drift check against the same numbers. Every key must reference a real file —
# the Cost-model meta-test in test_tier_membership.jl enforces that, so a
# renamed/retired test can't leave dead weight in the balancer.
const _DEFAULT_COST = 3.0
const _COST = Dict{String, Float64}(
    "workflow/test_multi_fidelity_bo.jl" => 161.0,
    "workflow/test_triple_point.jl" => 127.0,
    "test_dealias_2_3.jl" => 76.0,
    "solvers/test_continuation.jl" => 58.0,
    "test_quality.jl" => 48.0,           # Aqua/JET static analysis (warm-measured)
    "workflow/test_active_learning.jl" => 41.0,  # GP/BO, no spinor workspace — real file cost
    "workflow/test_pipeline.jl" => 17.0,
    # F=6 propagator comparisons × 6 LHY types × 2 time directions, plus a
    # SpatialLHY table build (BdG solves) — measured 22.2s.
    "hamiltonian/test_tabulated_lhy_propagator_parity.jl" => 22.0,
    "workflow/test_infrastructure.jl" => 15.0,
    "test_level4_general_F_phase_emergence.jl" => 13.0,
    "test_level10_hpsi_self_consistency.jl" => 12.0,
    "workflow/test_autopilot.jl" => 12.0,
    "oracles/test_propagator_references.jl" => 11.0,
    "oracles/test_master_oracle.jl" => 11.0,
    "oracles/test_path_coverage.jl" => 10.0,
    "analysis/test_tof_multiframe.jl" => 9.5,
    "gpu/test_mixed_precision.jl" => 9.0,
    "dynamics/test_tdhfb_f1_validation.jl" => 8.5,
    "analysis/test_physics_invariants.jl" => 8.0,
    "solvers/test_simulation.jl" => 8.0,
    "test_reference_rhs.jl" => 7.5,
    "solvers/test_lbfgs_sobolev_preconditioner.jl" => 6.5,
    "rotating_basis/test_rotating_basis_pipeline_parsing.jl" => 6.0,
    "solvers/test_3d.jl" => 5.0,
    "dynamics/test_twa.jl" => 5.0,
    "solvers/test_lbfgs.jl" => 5.0,
    "solvers/test_lbfgs_accuracy_floor.jl" => 6.0,
)

_cost(f) = get(_COST, f, _DEFAULT_COST)

"""
    warn_cost_drift(timings; factor=3.0, abs_gap=15.0, floor_s=8.0) -> stale

Degradation guard for the `_COST` balance model. If a file's *measured* time
grossly exceeds its estimate, the LPT balancer mis-packs the chunks and CI
wall-time regresses silently. Emit a GitHub-Actions `::warning` annotation (so it
surfaces on the run) for each such file. One-directional — only under-estimates
hurt makespan; an over-estimate merely over-reserves a slot. Returns the stale
entries (for tests).
"""
function warn_cost_drift(
    timings; factor::Float64=3.0, abs_gap::Float64=15.0, floor_s::Float64=8.0
)
    stale = NamedTuple{(:file, :measured, :estimate), Tuple{String, Float64, Float64}}[]
    for (f, t) in timings
        est = _cost(f)
        if t > floor_s && t > factor * est && (t - est) > abs_gap
            push!(stale, (file=f, measured=t, estimate=est))
        end
    end
    isempty(stale) && return stale
    ci = lowercase(get(ENV, "GITHUB_ACTIONS", "")) == "true"
    for s in stale
        msg = string(
            s.file, " took ", round(s.measured; digits=1), "s but _COST estimates ",
            round(s.estimate; digits=1), "s — update _COST in test/_tiers.jl to keep ",
            "parallel CI balanced",
        )
        println(ci ? "::warning title=Stale test-cost estimate::$msg" : "⚠️  cost drift: $msg")
    end
    return stale
end

function select_tests(tier::String)
    if tier == "fast"
        return FAST_TESTS
    elseif tier == "ci"
        return vcat(FAST_TESTS, CI_EXTRA)
    elseif tier == "full"
        return vcat(FAST_TESTS, CI_EXTRA, FULL_EXTRA)
    elseif tier == "physics"
        return PHYSICS_TESTS
    elseif tier == "oracles"
        return ORACLE_TESTS
    else
        @warn "Unknown SPINORBEC_TEST_TIER=$tier, falling back to full"
        return vcat(FAST_TESTS, CI_EXTRA, FULL_EXTRA)
    end
end
