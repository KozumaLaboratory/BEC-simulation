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
    "analysis/test_dipole_field.jl",
    "workflow/test_phi_omega_convention.jl",
    "workflow/test_schema_validation_edge_cases.jl",
    "workflow/test_seed_from.jl",
    "workflow/test_spinor_gs_from_jld2.jl",
    "workflow/test_run_root_env.jl",
    "workflow/test_config_zeeman_seed_agreement.jl",
    "workflow/test_calibration_edge_cases.jl",
    "workflow/test_loss_block_edge_cases.jl",
    "workflow/test_dynamics_lhy_plumbing.jl",
    "workflow/test_dynamics_lhy_normalisation.jl",
    "solvers/test_lbfgs_forward_coverage.jl",
    "oracles/test_lhy_table_path_coverage.jl",
    "workflow/test_lhy_texture_warning.jl",
    "workflow/test_lhy_block_wiring.jl",
    "workflow/test_interactions_roundtrip.jl",
    "workflow/test_b_block_normalize.jl",
    "workflow/test_waveform_inner_duration.jl",
    "workflow/validation/test_run_result.jl",
    "workflow/validation/test_observable_dispatch.jl",
    "workflow/validation/test_open_result.jl",
    "workflow/validation/test_specs_and_check.jl",
    # The accuracy-knob registry: every entry a real knob, the reference switch
    # moves and restores all of them (including on exception), and the report
    # names the per-run knobs it does NOT set.
    "workflow/validation/test_accuracy_knobs.jl",
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
    "oracles/test_lhy_no_bare_device_broadcast.jl",
    "oracles/test_scalar_lhy_si_roundtrip.jl",
    "oracles/test_dimensionless_coefficient_si_roundtrip.jl",
    "validation/test_k3_unit_audit.jl",
    "validation/test_L5_operator_rhs_compare.jl",
    "dynamics/test_tdhfb_f1_validation.jl",
    "hamiltonian/test_ddi_convention_factorial.jl",
    "foundation/test_atoms.jl",
    "foundation/test_fft_nyquist_null.jl",
    "foundation/test_no_unguarded_fft_derivative.jl",
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
    "hamiltonian/test_ddi_padded_zero_pad_invariant.jl",
    # Taylor-Horner spin rotation on the CPU, against the exact Euler 5-stage it
    # replaces. Reads the same SPIN_TAYLOR_TOL[] as the CUDA gate, so relaxing
    # the accuracy contract turns both red.
    "hamiltonian/test_cpu_spin_rotation_taylor_parity.jl",
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
    "hamiltonian/test_full_bdg_n_atoms_branches.jl",
    "hamiltonian/test_tabulated_lhy_propagator_parity.jl",
    "hamiltonian/test_lhy_energy_convention.jl",
    "hamiltonian/test_spatial_lhy.jl",
    "hamiltonian/test_spatial_lhy_spin_substep.jl",
    "hamiltonian/test_lhy_gradient_all_modes.jl",
    "hamiltonian/test_spinor_lhy_validation.jl",
    "hamiltonian/test_lhy_zeeman_reaches_bdg.jl",
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
    "workflow/test_vortex_density_movie.jl",
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
    # `SPIN_TAYLOR_TOL` is not a knob a caller should reason about — this pins
    # the RELATIONSHIP it exists to satisfy (truncation ≪ splitting error), so
    # the number can change and the criterion still holds. Runs
    # find_ground_state, hence ci and not fast.
    "hamiltonian/test_taylor_tolerance_criterion.jl",
    # Noether ledger for the EdH / Barnett program: at B=0 the DDI conserves
    # J_z = L_z + F_z exactly, and the drift is set by the box, not by dt.
    "oracles/test_jz_conservation_ddi.jl",
    "validation/test_dipolar_supersolid_tube.jl",
    "hamiltonian/test_split_step.jl",
    "solvers/test_simulation.jl",
    "solvers/test_ground_state.jl",
    "solvers/test_polished_ground_state.jl",
    "solvers/test_checkpoint.jl",
    "solvers/test_itp_checkpoint_hook.jl",
    "solvers/test_itp_tol_drho.jl",
    # In CI, not FULL, on purpose: every other L-BFGS test lives in FULL_EXTRA,
    # so a green `ci` run executes none of them. Both are 12x12x8 F=1 problems
    # — cheap enough to belong where they will actually run.
    "solvers/test_lbfgs_line_search_and_de.jl",
    "solvers/test_lbfgs_fast_path_equivalence.jl",
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
    # Validity-DOMAIN sibling of the above: a config can name a live `lhy.kind`
    # and still sit outside that mode's domain. The `icosa` cells did, and it
    # reached a committed json, a figure and two claims before anyone noticed.
    "oracles/test_lhy_config_validity_domain.jl",
    # Mode-coverage sibling of the above, one level down: LHYTerm is ONE
    # registry term with ten interchangeable tables behind it, so "the term
    # is gated" was true while three of its faces were broken at once.
    # Driven by LHY_SCHEMA["kind"].enum, so a new mode cannot ship ungated.
    "oracles/test_lhy_mode_face_coverage.jl",
    # Magnitude sibling of the above: the closed forms had a consistency oracle
    # and no SI anchor, and were exactly N_atoms too large in that gap.
    "oracles/test_lhy_magnitude_si_anchor.jl",
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
    # Full SPGPE gates: reservoir coefficients vs Rooney PRA 86 053634's own
    # published (γ̄, ℳ̄); the ∇·j = Σ Im(ψ*∇²ψ) identity the energy-damping kernel
    # rests on; exact number conservation + monotone energy decay (Eq. 29) —
    # the sign oracle for the scattering term.
    "dynamics/test_spgpe.jl",
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
    # Same bug class: a public analysis entry point that scalar-indexed a
    # device array and threw. Lz is the observable the EdH/Barnett J_z ledger
    # is written in, and those runs are on GPU.
    "gpu/test_gpu_orbital_angular_momentum.jl",
    # GPU=CPU parity for the projected-GP momentum cutoff. Gates the host-array
    # mask broadcast bug (ws.grid.k_squared is a host Array even on a GPU
    # workspace); no-op on CPU-only CI. CPU high-k-removal sanity always runs.
    "gpu/test_projected_gp_parity.jl",
    # Same bug class for the SPGPE energy-damping kernel, which broadcasts THREE
    # host k-space arrays (k², 1/|k|, √(1/|k|)) against device buffers.
    "gpu/test_spgpe_gpu_cpu_parity.jl",
    "gpu/test_gpu_tabulated_lhy_parity.jl",
    "gpu/test_gpu_lhy_term_faces.jl",
    "gpu/test_gpu_spin_rotation_taylor_parity.jl",
    # Bit-identity of the zero-padded DDI layout against the contiguous one, for
    # both the fused spin-density corner write and the rotation's in-place read
    # of a padded Φ. Padding is the DEFAULT since 9c117c05, so this is the
    # production layout; no-op on CPU-only CI.
    "gpu/test_gpu_padded_corner_parity.jl",
    # Fused k-space DDI contraction vs the three broadcasts it replaces. The
    # contraction was 25-31 % of the padded convolution on an H100; GPU-only, so
    # a green ci tier says nothing about it.
    "gpu/test_gpu_ddi_contraction_parity.jl",
    # The fused diagonal kernel with a TABULATED LHY against the generic
    # broadcast propagator it replaces. Every production Eu run is tabulated and
    # every one of them took the fallback; GPU-only.
    "gpu/test_gpu_tabulated_lhy_fused_diagonal_parity.jl",
    # Bit-identity of the fused `diag·SM·DDI·SM·diag` half-step against the
    # operator-by-operator one, plus one arm per eligibility rule. GPU-only
    # (the fused realization is a CUDA kernel); no-op on CPU-only CI.
    "oracles/test_spin_chain_fusion_parity.jl",
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
    # rotating_basis ⇄ standard-path parity, and the pin that their `Fz` fields
    # are DIFFERENT quantities (⟨F·B̂(t)⟩ vs lab ⟨F_z⟩).
    "rotating_basis/test_rotating_basis_standard_parity.jl",
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
    "dynamics/test_spgpe_reservoir.jl",   # 0-D evaporation → (T(t), μ(t)) bridge
    # Orphan-test audit 2026-05-25: promoted from unregistered → FULL_EXTRA.
    # All run ITP / RTP / find_ground_state and require the "full" tier.
    # The two Bug-4 regression pins are particularly load-bearing.
    "analysis/test_bogoliubov_along_boundary.jl",
    "gpu/test_mixed_precision.jl",
    "gpu/test_mixed_precision_phase3.jl",
    "hamiltonian/test_combined_spin_step.jl",
    "solvers/test_rtp_combined_step_selection.jl",
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
# Per-file cost estimate (seconds) on the GitHub 4-vCPU runner, used only to
# balance the parallel chunks (LPT bin-packing in runtests.jl). Only files above
# ~6 s need an entry; the long tail defaults to _DEFAULT_COST. A wrong
# estimate costs balance, never correctness — but a silently-stale estimate lets
# CI wall-time regress unnoticed, which `warn_cost_drift` (below) guards against.
# Lives here (not runtests.jl) so the chunk processes (run_chunk.jl) can run the
# drift check against the same numbers. Every key must reference a real file —
# the Cost-model meta-test in test_tier_membership.jl enforces that, so a
# renamed/retired test can't leave dead weight in the balancer.
const _DEFAULT_COST = 3.0
const _COST = Dict{String, Float64}(
    "oracles/test_spin_chain_fusion_parity.jl" => 260.0,
    # ── Measured on the CI runner: median over 4 green `fast` + `oracles`
    # runs (2026-07-28), every file whose median exceeded 6 s. Regenerate by
    # medianing the per-file timing tables that each chunk prints.
    "oracles/test_propagator_references.jl" => 91.5,
    "oracles/test_master_oracle.jl" => 84.2,
    "test_reference_rhs.jl" => 59.4,
    "oracles/test_hamiltonian_sign_oracles.jl" => 52.0,
    "oracles/test_lhy_full_bdg_closed_form_parity.jl" => 51.8,
    "workflow/test_autopilot.jl" => 49.1,
    "test_level10_hpsi_self_consistency.jl" => 47.7,
    "test_quality.jl" => 45.7,
    "workflow/test_active_learning.jl" => 35.7,
    "hamiltonian/test_ddi.jl" => 33.6,
    "dynamics/test_tdhfb_f1_validation.jl" => 30.3,
    "oracles/test_bdg_fd_hessian.jl" => 23.8,
    # F=6 propagator comparisons × 6 LHY types × 2 time directions, plus a
    # SpatialLHY table build (BdG solves) — measured 22.2s.
    "hamiltonian/test_tabulated_lhy_propagator_parity.jl" => 22.0,
    "oracles/test_imag_time_propagator_generator.jl" => 22.8,
    "validation/test_L5_operator_rhs_compare.jl" => 22.6,
    "hamiltonian/test_ddi_padded.jl" => 97.8,
    "workflow/test_dynamics_lhy_normalisation.jl" => 3.0,
    "solvers/test_lbfgs_forward_coverage.jl" => 2.0,
    "oracles/test_lhy_table_path_coverage.jl" => 2.0,
    "analysis/test_diagnostics.jl" => 21.3,
    "oracles/test_zeeman_diagonal_analytic.jl" => 19.9,
    "hamiltonian/test_ddi_convention_factorial.jl" => 18.2,
    "analysis/test_superfluid_fraction.jl" => 16.6,
    "workflow/test_dynamics_lhy_plumbing.jl" => 16.1,
    "foundation/test_property_based.jl" => 16.0,
    "oracles/test_stability_indeterminate.jl" => 15.5,
    "oracles/test_term_properties.jl" => 15.5,
    "hamiltonian/test_lhy.jl" => 15.2,
    "analysis/test_phase_classification_polyhedral.jl" => 15.1,
    "oracles/test_registry_completeness.jl" => 14.4,
    "hamiltonian/test_spatial_lhy.jl" => 13.7,   # single run (landed 2026-07-27)
    "manuscript/test_f12_icosahedral.jl" => 13.1,
    "oracles/test_bdg_low_modes_lobpcg.jl" => 12.9,
    "workflow/validation/test_save_operator_rhs.jl" => 12.8,
    "test_level2_strang_convergence.jl" => 12.4,
    "oracles/test_fisher_identifiability.jl" => 12.1,
    "oracles/test_meanfield_energy_half.jl" => 11.7,
    "workflow/test_schema_validation_edge_cases.jl" => 10.9,
    "workflow/test_lhy_texture_warning.jl" => 10.9,
    "oracles/test_hamiltonian_hermiticity.jl" => 10.8,
    "manuscript/test_f9_f11_polyhedral.jl" => 10.7,
    "analysis/test_paper3_validation.jl" => 10.6,
    "oracles/test_trapped_bdg_spectrum.jl" => 10.6,
    "oracles/test_apply_operator_accumulates.jl" => 10.3,
    "oracles/test_stability_sneaky_prover.jl" => 10.3,
    "oracles/test_path_coverage.jl" => 10.0,
    "oracles/test_lhy_mode_face_coverage.jl" => 17.0,  # 9 modes x 3 faces + FD
    "analysis/test_texture_observables.jl" => 9.8,
    "foundation/test_noise_waveform.jl" => 9.6,
    "manuscript/test_f5_f7_polyhedral.jl" => 9.5,
    "workflow/test_calibration_edge_cases.jl" => 9.3,
    "analysis/test_forward_image.jl" => 9.3,
    "analysis/test_spinor_fingerprint.jl" => 9.2,
    "oracles/test_global_phase_covariance.jl" => 8.7,
    "test_level1_scalar_exact.jl" => 8.5,
    "workflow/validation/test_scalar_summary.jl" => 8.4,
    "analysis/test_vorticity_berry.jl" => 8.4,
    "analysis/test_physics_level1.jl" => 7.8,
    "workflow/test_inspect_config.jl" => 7.7,
    "analysis/test_observables.jl" => 7.7,
    "oracles/test_physics_aware_sign_oracles.jl" => 7.6,
    "workflow/test_catalog_index.jl" => 7.4,
    "analysis/test_bogoliubov.jl" => 7.3,
    "analysis/test_superfluid_fraction_gp_twist.jl" => 7.3,
    "oracles/test_energy_operator_identity.jl" => 7.3,
    "hamiltonian/test_ddi_truncated_kernel.jl" => 7.0,
    "solvers/test_condensate.jl" => 6.8,
    "oracles/test_light_shift_analytic.jl" => 6.8,
    "workflow/test_checkpoint.jl" => 6.7,
    "foundation/test_spherical_harmonics.jl" => 6.6,
    "oracles/test_energy_decomposition_sum.jl" => 6.4,
    "oracles/test_spin_c1_analytic.jl" => 6.2,
    "analysis/test_physics_level0.jl" => 6.1,
    "oracles/test_gpu_cpu_per_term_parity.jl" => 6.1,
    "analysis/test_imaging.jl" => 6.0,
    # ── Heavy `ci`/`full`-tier files, not exercised by the per-push CI jobs;
    # estimates carried over from the full-tier measurement.
    "workflow/test_multi_fidelity_bo.jl" => 161.0,
    "workflow/test_triple_point.jl" => 127.0,
    "test_dealias_2_3.jl" => 76.0,
    "solvers/test_continuation.jl" => 58.0,
    "workflow/test_pipeline.jl" => 17.0,
    "workflow/test_infrastructure.jl" => 15.0,
    # Was 13.0 when it only built tables; #179 added a run_yaml A/B
    # (`method: lbfgs` reaches the tabulated LHY), which dominates. Now the
    # heaviest single file in the fast tier — measured 255.9 s.
    "workflow/test_lhy_block_wiring.jl" => 255.9,
    "hamiltonian/test_lhy_gradient_all_modes.jl" => 7.0,  # 4 F=6 table builds + FD
    "test_level4_general_F_phase_emergence.jl" => 13.0,
    "analysis/test_tof_multiframe.jl" => 9.5,
    "gpu/test_mixed_precision.jl" => 9.0,
    "analysis/test_physics_invariants.jl" => 8.0,
    "solvers/test_simulation.jl" => 8.0,
    "solvers/test_lbfgs_sobolev_preconditioner.jl" => 6.5,
    "solvers/test_lbfgs_fast_path_equivalence.jl" => 6.0,
    "rotating_basis/test_rotating_basis_pipeline_parsing.jl" => 6.0,
    "solvers/test_lbfgs_accuracy_floor.jl" => 6.0,
    "solvers/test_3d.jl" => 5.0,
    "dynamics/test_twa.jl" => 5.0,
    "solvers/test_lbfgs.jl" => 5.0,
    "solvers/test_lbfgs_line_search_and_de.jl" => 15.0,
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
