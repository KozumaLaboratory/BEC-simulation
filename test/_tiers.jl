# Tier membership — the single source of truth for which test files run in
# each tier. Shared by runtests.jl (the runner) and run_chunk.jl, so a file
# like test_tier_membership.jl still sees FAST_TESTS / MANUAL_TESTS_ALLOWLIST
# / select_tests when it runs inside a parallel chunk process. Tier
# membership stays explicit (CLAUDE.md commitment #7).

# ── Fast tier: pure unit tests, no find_ground_state / run_simulation ──
const FAST_TESTS = [
    # Pins that SPIN_TAYLOR_TOL is a control at the angles production runs
    # at. Three src comments said it was inert there, from an R three orders
    # too small; nothing checked them.
    "hamiltonian/test_taylor_tolerance_binds.jl",
    "test_quality.jl",
    # Meta-test: every test_*.jl under test/ is in exactly one tier or the
    # MANUAL allowlist (enforces CLAUDE.md commitment #7 structurally).
    "test_tier_membership.jl",
    # The CONTRIBUTING.md scripts/ charter, gated: set equality between
    # scripts/ on disk and the in-test allowlist (306→76 cleanup, 2026-08-18).
    "test_scripts_allowlist.jl",
    # 24 docs must be true; the other 143 must be dated. Nothing may be neither.
    "test_docs_live_set.jl",
    "test_calibrated_scan.jl",
    "test_docs_examples_avoid_removed_keys.jl",
    "test_state_doc_is_current.jl",
    "test_claude_md_citations_resolve.jl",
    # A3:R-DOC-01 asked for a CHECK; the design docs must stay terminal-readable.
    "test_design_docs_have_no_latex.jl",
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
    # A spin-F magnetic vortex has component windings v_m = -m, i.e. up to
    # ±6 for Eu. The plaquette detector caps at ±1 and non_abelian_holonomy
    # returns cis(phase), ~1 for every integer; this pins the detector that
    # reads them, and that it REFUSES when under-sampled rather than
    # returning a clean wrong integer (#336).
    "analysis/test_component_phase_winding.jl",
    # The #335 loop-width extractor refuses to report until its controls pass;
    # that refusal is the guarantee, so it is gated rather than left to --selftest.
    "analysis/test_hysteresis_conversion_depth.jl",
    "analysis/test_spin_rotation.jl",
    "analysis/test_sign_pattern.jl",
    "analysis/test_polyhedral_classifier.jl",
    "analysis/test_spinor_fingerprint.jl",
    "analysis/test_larmor_adiabaticity.jl",
    "analysis/test_dipole_field.jl",
    "analysis/test_resonance_dip_nonuniform.jl",
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
    "workflow/test_gs_cache_hit_physics.jl",
    "solvers/test_lbfgs_forward_coverage.jl",
    "solvers/test_precond_default_is_off.jl",
    "bench/test_ab_report.jl",
    "oracles/test_lhy_table_path_coverage.jl",
    "workflow/test_lhy_texture_warning.jl",
    "workflow/test_lhy_block_wiring.jl",
    "workflow/test_interactions_roundtrip.jl",
    # CLAUDE.md commitment #4 (same spec ⇒ same outdir) had no test at all until
    # the mutation harness reversed the canonical key sort and nothing went red.
    "workflow/test_content_id_determinism.jl",
    # `thermal_noise_amplitude` had no test anywhere: dropping the /4 left 57
    # workflow files green (mutation harness, 2026-07-31).
    "workflow/test_thermal_seed_amplitude.jl",
    # auto_grid, the spherical B angles and the error budget's positive-control
    # guard were each invisible to all 59 workflow files (mutation, 2026-07-31).
    # Four autopilot invariants that 63 workflow files did not cover
    # (mutation, 2026-08-01): the budget gate's queued work, the daily cap,
    # OOM-is-permanent, and the on_complete lineage bound.
    "workflow/test_autopilot_invariants.jl",
    "workflow/test_profile_vram_uses_the_registry.jl",
    "workflow/test_docs_teach_real_analyzers.jl",
    "workflow/test_full_bdg_advisory_fires.jl",
    "workflow/test_no_second_atom_F_table.jl",
    "workflow/test_every_dynamics_path_reports_liveness.jl",
    "workflow/test_oom_reaches_resource_permanent.jl",
    "workflow/test_preflight_can_fail.jl",
    "workflow/test_slack_alerts_report_delivery.jl",
    "workflow/test_inert_dynamics_keys_are_refused.jl",
    "hamiltonian/test_absorbing_boundary_honours_the_step.jl",
    "hamiltonian/test_two_spin_step_guards_agree.jl",
    "workflow/test_absence_is_not_reported_as_health.jl",
    "hamiltonian/test_kinetic_phase_uploads_k2_once.jl",
    "workflow/test_plan_cache_is_keyed_on_the_box.jl",
    "workflow/test_failure_evidence_reaches_the_reader.jl",
    "workflow/test_dashboard_does_not_invent_a_time_axis.jl",
    # Analyzer-name routing and the ground-state interactions precedence —
    # 64 workflow files covered neither (mutation, 2026-08-01).
    "workflow/test_pipeline_name_and_precedence.jl",
    "workflow/test_auto_grid_derivation.jl",
    "workflow/test_b_block_spherical_angles.jl",
    "workflow/validation/test_error_budget_positive_control.jl",
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
    "workflow/validation/test_accuracy_profiles.jl",
    "workflow/validation/test_ground_state_preflight.jl",
    "workflow/validation/test_save_operator_rhs.jl",
    "workflow/validation/test_show.jl",
    "workflow/validation/test_twin_audit.jl",
    "workflow/validation/test_scalar_summary.jl",
    "workflow/test_state_zoo_wrappers_runnable.jl",
    "workflow/test_checkpoint.jl",
    "workflow/test_checkpointed_sweep.jl",
    "workflow/test_gs_stage_cache.jl",
    # Does what a run WRITES reach what the reaper READS? The autopilot suite
    # drives `is_divergent_status` with dicts it builds itself, so it passed
    # while the writer and the reader shared no keys at all.
    "workflow/test_live_status_reaches_the_detector.jl",
    # A name the autopilot reads must be a name something writes.
    "workflow/test_terminal_record_has_a_producer.jl",
    # The budget read the pre-2026 flat save_* keys the schema now rejects.
    "workflow/test_budget_reads_the_save_block.jl",
    # A YAML key a maintained doc teaches must be one the schema accepts.
    "workflow/test_docs_yaml_against_schema.jl",
    # A schema enum must name what the implementation can actually do.
    "workflow/test_schema_enum_matches_implementation.jl",
    # One diverging TWA member used to NaN the mean for every member after it.
    "solvers/test_twa_rejects_diverged_members.jl",
    # Model / Stage layer + the provenance cutover's steps 1, 1b and 2.
    "model/test_model_shape.jl",
    "model/test_model_toml_roundtrip.jl",
    "model/test_artifact_id.jl",
    # A revision naming bytes the process is not running is worse than none.
    "model/test_code_rev_refuses_under_sysimage.jl",
    # Why `artifact_id` had to stop being `content_id(spec)`: prose participates
    # in the latter, so harvesting 302 `metadata:` blocks moved 302 names.
    "model/test_prose_does_not_move_identity.jl",
    # Step 1b. `yaml_to_model` is the resolver from raw YAML to a `Model`;
    # `test_resolve_gs_is_shared.jl` is what keeps it and `_run_step` from
    # becoming two parsers of the same physics; `test_ddi_trunc_radius…` gates
    # the three-state union that unblocks the corpus.
    "model/test_yaml_to_model.jl",
    "model/test_resolve_gs_is_shared.jl",
    "model/test_ddi_trunc_radius_three_states.jl",
    # Step 1b's acceptance criterion, and step 3's scope: `yaml_to_model` over
    # EVERY config under `runs/`, with the ones it cannot resolve listed by name
    # and reason so the list only shrinks deliberately.
    "model/test_corpus_resolves.jl",
    "model/test_admission_requires_marker.jl",
    "model/test_record_provenance.jl",
    "model/test_completion_marker.jl",
    # W2: the marker carries the solve's verdict and admission can require it.
    # W3: the grandfather arm is bounded by a dated cutoff.
    "model/test_marker_verdict.jl",
    # …and the arm none of the three marker files has: does the verdict
    # describe the payload it is attached to?
    "model/test_verdict_truth.jl",
    # …and what that gate FOUND: the step returned three descriptions of its
    # answer — saved psi, analysed workspace, reported energy — and with a
    # rotating frame they were three different states.
    "model/test_gs_step_returns_one_state.jl",
    "model/test_marker_cutoff.jl",
    # W4: the cache's fail-safes reach a file, not only a log line.
    "model/test_cache_stats_reported.jl",
    # Step 3. The GS stage cache admits on `artifact_id`; `_gs_cache_key` and
    # `_hashable` are deleted. 31 knobs, ONE assertion each — a single bundled
    # assertion is how a 19-key list rots into a 17-key list — plus the
    # partition of `GS_SCHEMA` that makes a new key red until it is classified,
    # and the fail-safe (a config with no `Model` has no id and never hits).
    "model/test_gs_admission_axes.jl",
    # Step 4. Ambient module-level `Ref`s are the one input class `artifact_id`
    # cannot see: not in the declaration, not in `code_tree_hash`. A pure file
    # scan over `src/` + `ext/` against a PINNED set, so a new one is red until
    # someone writes down why it may be ambient.
    "model/test_no_ambient_module_refs.jl",
    # Step 4's one KEPT ambient Ref: the Horner degree clamp is the positive
    # control test_taylor_tolerance_criterion.jl needs, so it cannot be frozen —
    # but it moves psi by 5.9e-2 at cap 0 and is in no Stage, so `run_pipeline`
    # refuses to run while it is clamped.
    "model/test_taylor_degree_cap_guard.jl",
    # Step 4's measurement, one assertion per ambient Ref: does flipping it move
    # `artifact_id`? `:moves` for the dealias pair (pinning them INTO the id),
    # `:blind` for the rest, each with the reason it is still open — so closing
    # one is a visible diff here. Also covers the `dealias_k_cut` half, which
    # `test_gs_admission_axes.jl` arm C29 does not: unhooking only that half from
    # `GridSpec` leaves C29 green at 124/124 (measured).
    "model/test_ambient_refs_vs_artifact_id.jl",
    # THE gate cutover step 2 exists for: interrupt a real solve mid-flight and
    # assert the next run recomputes instead of serving the partial output.
    # Nothing else in the suite exercises the swallowed `InterruptException`.
    # Two files because there are two swallowing loops — the ITP and the two
    # RTP loops — and forcing the RTP half to report "not interrupted" left the
    # ITP file green (canary B6, 2026-08-01).
    "model/test_interrupted_run_recomputes.jl",
    "model/test_interrupted_dynamics_recomputes.jl",
    # The writer / admission sites a YAML SCAN and `Experiment` actually use.
    # Four independent canaries (D1 / D2 / D3b / D4b) passed against the suite
    # without it, which is step 1's finding M10 in the scan path.
    "model/test_scan_path_admission.jl",
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
    # Composer order from the COEFFICIENTS, on 8×8 matrices — no grid, no
    # Workspace. Milliseconds for what test_yoshida_ddi_order.jl spends 14 s on
    # in `full`, and it names the coefficient rather than the stack.
    "hamiltonian/test_composer_order_conditions.jl",
    # `_spin_chain_reason` is the one list of what the fused half-step would
    # otherwise drop, and it has twice gained an entry with no arm. This gates the
    # list against test/ so an unarmed entry cannot be added silently.
    "hamiltonian/test_spin_chain_decline_reasons.jl",
    # Gates the dt < 0 half-line that every high-order composer needs. FAST on
    # purpose: the order tests that also see this defect are in FULL_EXTRA, so
    # the PR gate never ran them (PR #183 shipped a 4th → 2nd order collapse).
    "oracles/test_negative_dt_substeps.jl",
    "validation/test_k3_unit_audit.jl",
    # The type-C registry: which published numbers this repo actually checks
    # itself against, and — the load-bearing half — which of the targets
    # CLAUDE.md names have no gate at all. Pure table + file/tier lookups.
    "validation/test_type_c_claims.jl",
    # One word ("Klaus") named the paper, the fast-Larmor regime and this
    # project's own protocol at once, and a "correction" denying the paper's
    # existence sat above a citation to it (#344). Pure text scan over the
    # maintained tree, every arm through `calibrated_scan`.
    "validation/test_klaus_name_disambiguation.jl",
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
    # Instrument gate for the vortex counter: n imprinted -> n counted, ZERO on a
    # vortex-free field (a KZ defect count sits on a thermal background), and
    # threshold-independent.
    "analysis/test_vortex_counter_control.jl",
    # g1(r) + coherence length: the KZ observable that replaced defect counting.
    # Gated on a coherent field (no decay), white noise (decay within a cell), and
    # recovery of an IMPOSED correlation length as it is scaled.
    "analysis/test_coherence_length.jl",
    "dynamics/test_thermal_cfield.jl",
    # test_spgpe_equilibrium_number.jl is NOT here: main moved it to FULL_EXTRA
    # with a cost of 1266 s after it timed out the 15-minute per-PR job. Taking my
    # side of this conflict would have put it back and reddened CI again — a union
    # of both sides is not a resolution when one side is a fix.
    "dynamics/test_spgpe_projector_composition.jl",
    "workflow/test_measurement_provenance.jl",
    "hamiltonian/test_majorana.jl",
    "analysis/test_diagnostics.jl",
    "analysis/test_phase_classification_polyhedral.jl",
    "hamiltonian/test_lhy.jl",
    "hamiltonian/test_lhy_level8_unit.jl",
    "hamiltonian/test_singlet_pair.jl",
    "hamiltonian/test_batched_kinetic.jl",
    "hamiltonian/test_ddi_padded.jl",
    "hamiltonian/test_ddi_bufs_are_empty_when_padded.jl",
    # energy and gradient must come from the SAME DDI kernel; test_ddi_padded.jl
    # never calls either face
    "hamiltonian/test_ddi_gradient_padding_parity.jl",
    "hamiltonian/test_ddi_padded_zero_pad_invariant.jl",
    # Taylor-Horner spin rotation on the CPU, against the exact Euler 5-stage it
    # replaces. Reads the same SPIN_TAYLOR_TOL as the CUDA gate, so relaxing
    # the accuracy contract turns both red.
    "hamiltonian/test_cpu_spin_rotation_taylor_parity.jl",
    # RK4IP must be MEASURED at order 4, with the DDI-off control: composition
    # schemes hit nominal order without the DDI and collapse to ~1 with it.
    "hamiltonian/test_rk4ip_convergence_order.jl",
    # A k-space scratch buffer must carry ψ's precision, because the FFT plan
    # beside it does. Pairing a ComplexF32 in-place plan with a ComplexF64
    # buffer degrades `plan * buf` to the out-of-place method, so the buffer is
    # never transformed and the reduction reads real-space ψ: the F32 kinetic
    # energy came out 77 % low, silently, on both the energy and the gradient
    # face. CPU-only and ~10 s, so it belongs where it will actually run —
    # `gpu/test_mixed_precision*.jl` DID catch this, in a nightly that had not
    # been green since 2026-05-08.
    "hamiltonian/test_mixed_precision_kinetic_buffer.jl",
    "foundation/test_clebsch_gordan.jl",
    "foundation/test_general_f.jl",
    "foundation/test_optical_pumping_rate_eq.jl",
    "analysis/test_forward_image.jl",
    "analysis/test_fisher.jl",
    "hamiltonian/test_interactions_constraint.jl",
    "workflow/test_io.jl",
    # summary.json is what every document and figure cites, and until 2026-08-02
    # it recorded nothing about what produced it — measured across 226 stored
    # results. Pure dict + file I/O.
    "workflow/test_summary_provenance.jl",
    # The run dir is keyed on the config BYTES, not the commit, so the same YAML
    # under different code reuses cached points silently. This pins the gate that
    # stops it, and the widened 16-hex directory suffix.
    "workflow/test_run_dir_provenance_gate.jl",
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
    "analysis/test_orbital_angular_momentum_vector.jl",
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
    # (physics block × solver path) table: the term must be LIVE on the
    # Workspace after a YAML run, on every path. Drives run_config, so `ci`
    # rather than `fast`. Replaces the per-incident plumbing files — a new path
    # is a row, not a new file.
    "workflow/test_yaml_physics_reaches_workspace.jl",
    # `SPIN_TAYLOR_TOL` is not a knob a caller should reason about — this pins
    # the RELATIONSHIP it exists to satisfy (truncation ≪ splitting error), so
    # the number can change and the criterion still holds. Runs
    # find_ground_state, hence ci and not fast.
    "hamiltonian/test_taylor_tolerance_criterion.jl",
    # Noether ledger for the EdH / Barnett program: at B=0 the DDI conserves
    # J_z = L_z + F_z exactly, and the drift is set by the box, not by dt.
    "oracles/test_jz_conservation_ddi.jl",
    # classify_spinor_phase on 32³ state_zoo imprints (the threshold-setting
    # run, pinned). 17 imprints + fingerprints — ci rather than fast.
    "analysis/test_spinor_phase_classifier.jl",
    "validation/test_dipolar_supersolid_tube.jl",
    # The `:evolve` Stage producer: the DYNAMICS_SCHEMA partition is total, a
    # model-level key is refused rather than dropped, and the real-time ambient
    # switches finally move an artifact id.
    "model/test_evolve_stage.jl",
    # `refs/klaus2022.toml` + `ref`: the second source in the registry, and the
    # refusal that follows from it — a paper with no re-measurable record has
    # only `read_off` rows, none arbitrate, and a :C Claim against them throws.
    "validation/test_klaus2022_ref.jl",
    # Klaus 2022 magnetostirring: the coefficient chain, the directional
    # magnetostriction oracle (coarse-grid ITP), and the pre-registered
    # thresholds re-applied to the stored production verdicts.
    "validation/test_klaus2022_vortex_stripes.jl",
    # Why that reproduction runs on the scalar eGPE and not the spinor solver,
    # as a computation over the scale hierarchy rather than a paragraph.
    "validation/test_klaus_model_selection.jl",
    # Calibration of the Klaus residual-image hole/stripe detector: every
    # assertion paired with the pattern that must NOT be found.
    "analysis/test_vortex_stripes.jl",
    # The truncated-Wigner seed and its basis. Pins the seeded atom fraction:
    # drawn on plane waves instead of trap eigenstates it came out at 102 % of N.
    "solvers/test_scalar_thermal_seed.jl",
    # Magnitude oracle for the dipolar kernel. The existing kernel test pins
    # symmetry and direction only — a kernel scaled by any constant passes it.
    "oracles/test_dipolar_magnetostriction_magnitude.jl",
    # The `kind: scalar_egpe` YAML wiring: parse, step types, refusals, one
    # end-to-end run. The solver existed for two months with no way to reach it.
    "workflow/test_scalar_egpe_yaml.jl",
    # Pins the Fig. 4B dip centre / width read off the published Matsui dataset,
    # so the type-C target cannot drift when the fixture or the metric changes.
    # Pure I/O + arithmetic, but reads a fixture — ci rather than fast.
    "validation/test_matsui_fig4_dip.jl",
    # `refs/matsui2025.toml` + `ref` + `Claim`. Same fixture, one level up: that
    # file gates the METRIC against the fixture, this one gates the REFERENCE
    # FILE against both — every measured row is re-measured rather than read,
    # and the three constructor refusals that are the whole enforceable content
    # of the A/B/C taxonomy each get one assertion. Resolves one production
    # config, hence ci.
    "validation/test_matsui2025_ref.jl",
    # Cutover step 6: the harvest of what lived in run-config prose. Set
    # equality over 300 item ids with every count pinned as a literal, so the
    # inventory of migrated knowledge cannot silently shrink — plus the arm
    # asserting the verbatim `metadata:` dump covers every config that still
    # carries a block, which is what makes the deletion safe by construction
    # rather than by how carefully the sampling was done. Pure TOML + a
    # `walkdir` over `runs/`, no solve.
    "validation/test_config_prose_harvest.jl",
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
    "solvers/test_lbfgs_history_precision.jl",
    "solvers/test_lbfgs_line_search_fused_gradient.jl",
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
    # Heavy-YAML Bayesian-optimisation drivers. Both were in the MANUAL
    # allowlist as "heavy YAML (SPINORBEC_RUN_HEAVY_YAML)" — but they already
    # carry their own `_SKIP_HEAVY_YAML_*` guard, so with the flag off they cost
    # 0.0 s and with it on (the nightly) they cost 19.7 s and 50.2 s. Measured
    # 2026-07-31: both pass, both ways. The environment reason had stopped
    # being true and nobody had checked.
    "workflow/test_active_learning_yaml.jl",
    "workflow/test_multi_fidelity_yaml.jl",
    # Klaus et al. 2022 magnetostir plumbing smoke. Was MANUAL as "heavy YAML scenario
    # pending schema audit" since 2026-05-25; the schema was fine and the
    # `initial_state` was inverted (see the file header). Runs in ~68 s.
    "workflow/test_klaus_validation.jl",
    # Dashboard HTTP round-trip. Was the last MANUAL entry ("spawns dashboard
    # server on a TCP port"); it hung forever for two reasons, both fixed
    # 2026-08-02 — a keep-alive read with no `Connection: close`, and a
    # teardown by `Base.throwto` on a task parked in `accept`. 10 s.
    "workflow/test_live_monitor.jl",
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
    "oracles/test_bfield_sign_declared_once.jl",
    "oracles/test_hamiltonian_hermiticity.jl",
    "oracles/test_kinetic_trap_analytic.jl",
    "oracles/test_zeeman_diagonal_analytic.jl",
    "oracles/test_zeeman_full_analytic.jl",
    "oracles/test_propagator_unitarity.jl",
    "oracles/test_spin_operator_algebra.jl",
    "oracles/test_energy_operator_identity.jl",
    "oracles/test_ddi_uniform_zero.jl",
    "oracles/test_flux_closure_ddi_identity.jl",
    "oracles/test_itp_dt_limited_advisory.jl",
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
    # The DDI half of the homogeneous BdG, which nothing gated: the normal block
    # was the Hartree term (zero for a uniform cloud, since Q(q=0) = 0) instead
    # of the exchange term, so it was 2x on a polarized state and identically
    # zero on a polar one (#361).
    "oracles/test_dipolar_bogoliubov_anchor.jl",
    # What the six unmeasured Eu scattering channels CANNOT move: the stretched
    # pair |−F,−F⟩ and its first magnon are pure S = 2F, so a `c1_ratio` sweep at
    # fixed c_total leaves them exact. Each invariance carries a control that
    # moves (#342, `docs/campaign/as_dependency_map.md`).
    "oracles/test_stretched_channel_invariance.jl",
    "oracles/test_lhy_analytic.jl",
    "oracles/test_lhy_full_bdg_closed_form_parity.jl",
    "oracles/test_light_shift_analytic.jl",
    "oracles/test_magnetic_gradient_analytic.jl",
    "oracles/test_tensor_analytic.jl",
    "oracles/test_raman_analytic.jl",
    "oracles/test_term_legacy_equivalence.jl",
    "oracles/test_term_consistency.jl",
    "oracles/test_energy_operator_ratio.jl",
    # The coverage claim `test_term_consistency.jl` makes in its header and does
    # not keep: `apply_operator!` differenced against `energy_contribution` for
    # EVERY slot of H_TERMS_CANONICAL_ORDER, with the coverage itself asserted so
    # a fixture that stops activating a term cannot take its gate with it.
    "oracles/test_term_fd_registry_coverage.jl",
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
    # KNOWN-LIMIT gaps (empty since the raman RHS landed 2026-07-31).
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
    "oracles/test_full_bdg_config_stability.jl",
    "oracles/test_doc_run_citations_resolve.jl",
    # Mode-coverage sibling of the above, one level down: LHYTerm is ONE
    # registry term with ten interchangeable tables behind it, so "the term
    # is gated" was true while three of its faces were broken at once.
    # Driven by LHY_SCHEMA["kind"].enum, so a new mode cannot ship ungated.
    "oracles/test_lhy_mode_face_coverage.jl",
    # Magnitude sibling of the above: the closed forms had a consistency oracle
    # and no SI anchor, and were exactly N_atoms too large in that gap.
    "oracles/test_lhy_magnitude_si_anchor.jl",
    # The same anchor at production couplings. The one above holds only at
    # uniform g_S (c₁ = 0) and no DDI, and neither is true of any Eu run —
    # c1_ratio is +1/36 or −0.005 and ε_dd = 0.54. This pins the identity that
    # licenses #337's scheme choice (fm_dipolar IS the fully-polarised dipolar
    # LHY of the literature) plus the c_dd → ε_dd conversion nothing asserted.
    "oracles/test_lhy_fm_dipolar_is_the_scalar_scheme.jl",
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
    # Trapped spinor excitation FREQUENCIES (trapped_bdg_frequencies): the
    # uniform-limit ω anchor against the homogeneous BdG + the analytic F=1
    # polar density/magnon closed forms, the `λ is NOT ω` category pin
    # (ω = √(λ₋λ₊)/2, and λ₋ ∝ k² where ω ∝ k), the Goldstone-vs-gauge
    # classification, and the spurious-null-space regression (the projector's
    # own null space leaking into the LOBPCG basis as a converged fake zero).
    "oracles/test_trapped_bdg_frequencies.jl",
    # S(k,ω) by real-time impulse response (bragg_response): peak ≡ the
    # Bogoliubov branch per channel, + the three controls a spectrum needs
    # (channel selectivity, linearity in the kick, zero-kick ⇒ no line).
    "oracles/test_bragg_response_spectrum.jl",
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
    # The configuration every CI runner is in: CUDA.jl loaded, no driver. Runs
    # a `CUDA_VISIBLE_DEVICES=-1` subprocess, so it is a real skip-path test
    # even when the host has a GPU. Gates the unguarded scan-loop
    # `CUDA.reclaim()` and the three GPU test files whose top-level
    # `return nothing` guard never stopped their own include — between them,
    # four of the standing `full`-tier reds.
    "gpu/test_cpu_only_runner.jl",

    # Moved up from FULL_EXTRA 2026-08-02, on mutation-sweep evidence (#276,
    # jobs 8315814/8315815). It is the SOLE file that catches two cataloged
    # defect classes, and it was in no required check — required is
    # fast + oracles + integration, and integration derives from THIS list:
    #
    #   yaml_calibration_not_applied  [fatal] — `p_mv`/`coil_mode` stop resolving
    #     to Gauss before parsing, so every downstream number is off by the coil
    #     calibration factor while the run looks entirely normal.
    #   save_every_off_by_one         [major] — `save.every` no longer divides the
    #     step count, so the last snapshot is not the final state.
    #
    # Every other escapee from that sweep had a catcher already inside a required
    # tier. These two did not, and the file costs 17 s.
    "workflow/test_pipeline.jl",
]

# ── Full tier: everything (ci + remaining heavy tests) ──
const FULL_EXTRA = [
    # 1266 s on its own — three independent SPGPE equilibrium solves at
    # n = 48, each run to steady state from both directions. It was in
    # FAST_TESTS, where the job budget is 15 min: no worker count can help,
    # because a parallel makespan is bounded below by the slowest single
    # file. Three per-PR runs died at 15m18s / 15m21s / 15m20s against
    # `timeout-minutes: 15`, and the identical seconds are what gave it away
    # as a budget rather than a race. `full` (30 min) is the only tier it
    # fits, and it eats two thirds of that — worth making cheaper at the
    # source rather than leaving here.
    "dynamics/test_spgpe_equilibrium_number.jl",
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
    "solvers/test_pause_resume.jl",
    "dynamics/test_twa.jl",
    "solvers/test_binary_simulation.jl",
    "solvers/test_synthetic_dimension.jl",
    "workflow/test_calibration_drift.jl",
    "workflow/test_dynamics_knobs.jl",
    "gpu/test_cuda_equivalence.jl",
    # Coarse CUDA backend smoke. Was MANUAL as "gated, but needs GPU to be
    # useful" — it guards on `CUDA.functional()` like every other gpu/ file, so
    # on a CPU-only runner it is the same no-op they are. 3.9 s on a GPU host.
    "gpu/test_cuda.jl",
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
    "gpu/test_gpu_device_caches_key_on_the_object.jl",
    "gpu/test_gpu_lhy_term_faces.jl",
    # Same bug class again, this time in the dispatch itself: `energy_gradient!`
    # chose CPU vs GPU from `psi`, while computing on `ws.state.psi` and writing
    # `grad`. A ground state read back from jld2 is a host Array whatever wrote
    # it, so the GS stage-cache audit — host ψ, GPU workspace — took the CPU
    # branch and scalar-indexed. Needs a cache HIT to appear: the run that fills
    # the cache never loads from it, so only the SECOND GPU run of a given
    # ground state dies.
    "gpu/test_gpu_energy_gradient_host_psi.jl",
    "gpu/test_gpu_spin_rotation_taylor_parity.jl",
    # The OTHER pair of realizations on the device: the warp-cooperative fused
    # Euler kernels vs the one-thread-per-voxel ones. Replaces
    # `bench/verify_euler_warp.jl`, which flipped `_DDI_EULER_WARP[]` and then
    # called a path that takes Taylor first for D ≤ 16 — it compared the Taylor
    # kernel against itself and printed OK. `_SM_EULER_WARP` had no coverage.
    "gpu/test_gpu_euler_warp_parity.jl",
    "gpu/test_lbfgs_stall_fixed_point.jl",   # floor stop gives up nothing, on device
    # Bit-identity of the zero-padded DDI layout against the contiguous one, for
    # both the fused spin-density corner write and the rotation's in-place read
    # of a padded Φ. Padding is the DEFAULT since 9c117c05, so this is the
    # production layout; no-op on CPU-only CI.
    "gpu/test_gpu_padded_corner_parity.jl",
    # Fused k-space DDI contraction vs the three broadcasts it replaces. The
    # contraction was 25-31 % of the padded convolution on an H100; GPU-only, so
    # a green ci tier says nothing about it.
    "gpu/test_gpu_ddi_contraction_parity.jl",
    # the padded DDI GRADIENT face reads a strided corner view of Phi_*_pad;
    # the contraction gate above stops before apply_operator!
    "gpu/test_gpu_ddi_gradient_padding_parity.jl",
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
    "rotating_basis/test_transverse_spin_is_measured.jl",
    "rotating_basis/test_dt_matches_the_integrator_that_runs.jl",
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
# EMPTY, 2026-08-02. Every `test_*.jl` under test/ is now in a tier.
#
# This held five files / 53 assertions that no tier ran, untouched since
# 2026-05-25, each with an environment reason nobody had rechecked. Run one by
# one, three needed no code change at all; the two that did were broken for
# reasons that had nothing to do with the environment they were filed under
# (an inverted `initial_state`, and an HTTP read that never saw EOF).
#
# Keep it empty. A file that cannot run is a file to fix or delete — parking it
# here is how 53 assertions stopped being tests for ten weeks. If something
# genuinely must be manual, it needs an entry in test/MANUAL_TESTS.md stating a
# reason that was MEASURED, and the tier-membership meta-test asserts the two
# lists agree.
const MANUAL_TESTS_ALLOWLIST = String[]

# Derived view (NOT a partition list): every `oracles/` gate, regardless of which
# tier list it lives in. The `oracles` pseudo-tier runs JUST these so the per-PR
# CI can gate the bug classes cheaply (the full `ci` tier is ~30-45 min and only
# runs nightly — that is how 5 oracle gates rotted RED unprotected, 2026-06-21).
# Auto-maintaining: a new `test/oracles/<x>.jl` added to any tier list is picked
# up here for free.
const ORACLE_TESTS = filter(t -> startswith(t, "oracles/"), vcat(FAST_TESTS, CI_EXTRA, FULL_EXTRA))

# Derived view (NOT a partition list): the `ci`-tier files that no per-PR
# required check runs. `fast` covers FAST_TESTS and `oracles` covers every
# `oracles/` gate, which together leave exactly CI_EXTRA's non-oracle files —
# the ITP/RTP integration tests, ground state, config/experiment plumbing —
# gated only by the nightly `full` run. That is the same hole the `oracles`
# pseudo-tier was cut to close, one level out: a PR could break
# `solvers/test_ground_state.jl` or `hamiltonian/test_split_step.jl` and merge
# green, because "required checks are green" and "the ci tier passes" were
# different statements.
#
# Running fast + oracles + integration as three per-PR jobs covers the whole
# `ci` tier without any job paying for all of it serially. Derived from
# CI_EXTRA rather than hand-listed, so it cannot drift from it.
const INTEGRATION_TESTS = filter(t -> !startswith(t, "oracles/"), CI_EXTRA)

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
    # Three coarse-grid scalar-eGPE ITP solves for the magnetostriction
    # direction oracle; the rest is table lookups against a stored JSON.
    "validation/test_klaus2022_vortex_stripes.jl" => 25.0,
    # Three coarse ITP solves against the dipolar Thomas-Fermi closed form.
    "oracles/test_dipolar_magnetostriction_magnitude.jl" => 100.0,
    # One 24³ ground state + 100 dynamics steps through the YAML entry point.
    "workflow/test_scalar_egpe_yaml.jl" => 40.0,
    # Measured here, not on the runner (2026-08-02, 10-core box): 1266 s,
    # against the 3.0 s default it had been taking. The default made it the
    # LAST file handed out, which is the worst possible order for the one
    # file that sets the makespan on its own. The absolute number is
    # machine-dependent and the ordering it buys is not — nothing else in
    # any tier is within a factor of four of it.
    "dynamics/test_spgpe_equilibrium_number.jl" => 1266.0,
    # Measured, not guessed. An unregistered file is handed out as 3.0, not as
    # "probably small", and the 1266 s entry above exists because a heavy file
    # carrying a 3.0 estimate went out last and blew the 15-minute job.
    "dynamics/test_spgpe_projector_composition.jl" => 12.8,
    "dynamics/test_thermal_cfield.jl" => 2.4,
    "workflow/test_measurement_provenance.jl" => 0.7,
    "oracles/test_spin_chain_fusion_parity.jl" => 260.0,
    # Measured locally 2026-08-19 (10-core box): 128 s of solver time for the
    # ITP-vs-L-BFGS pair plus one L-BFGS control. Registered so it goes out
    # early rather than last.
    "oracles/test_itp_dt_limited_advisory.jl" => 150.0,
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
    # Five real (tiny) ITP solves plus one interrupted 2e6-step solve: the cache
    # MISS arms have to actually solve, or the positive controls that arm the
    # whole gate are not there.
    "model/test_admission_requires_marker.jl" => 29.0,
    # One `run_yaml` interrupted mid-ITP + one full recomputation of the same
    # cell (2e6-step budget, 64 points, 1-D, CPU).
    #
    # These five, like every other entry here, are SERIAL measurements. Under
    # `SPINORBEC_TEST_WORKERS=auto` (10 workers on this box) the first three took
    # 110.3 / 62.3 / 3.2 s — roughly 2.2× on the two that solve, and ~1× on the
    # one that only touches the filesystem. `_COST` is only the hand-out order,
    # so what has to be right is the ranking, not the absolute number.
    "model/test_interrupted_run_recomputes.jl" => 50.0,
    "model/test_completion_marker.jl" => 3.0,
    # Filesystem-only, like `test_completion_marker.jl`: no solve runs in either.
    "model/test_marker_verdict.jl" => 3.0,
    "model/test_marker_cutoff.jl" => 3.0,
    # Filesystem-only arms are ~2 s; the end-to-end arm runs the same two-point
    # scan twice (once cold, once fully cached) and is the other 33 s.
    "model/test_cache_stats_reported.jl" => 35.0,
    # Two RTP loops driven directly (5.9 s) + one `run_yaml` interrupted
    # mid-dynamics and recomputed in full, 1e6 steps (48.8 s).
    "model/test_interrupted_dynamics_recomputes.jl" => 55.0,
    # Six 2-point `run_yaml` scans (47.8 s) + a scan with a dynamics step
    # (4.7 s) + filesystem-only `Experiment` admission arms (0.6 s).
    "model/test_scan_path_admission.jl" => 53.0,
    # Two real `run_yaml` round trips (1-D, 16 points, 20 ITP steps) — the
    # two `run_registry.jl` writer sites cannot be reached any other way.
    "model/test_record_provenance.jl" => 46.0,
    "model/test_model_toml_roundtrip.jl" => 9.0,
    # 380 assertions. ~3 s of TOML + fixture measurement (the whole reference
    # file is re-measured several times over, including four break-and-restore
    # canaries), ~10 s for the one `yaml_to_model` on the production Fig. 4B
    # config that makes the type-A claim's evidence a real Stage.
    "validation/test_matsui2025_ref.jl" => 24.0,
    # Two TOML parses (~5 MB total) plus one `walkdir` over the 429 configs
    # under `runs/` reading each first line-block. No SpinorBEC call at all.
    "validation/test_config_prose_harvest.jl" => 5.0,
    # ~12 `_run_yaml_prepare` + resolve passes over throwaway configs, no solve.
    "model/test_yaml_to_model.jl" => 12.0,
    # One real (1-step, 8³, Eu F=6) ITP solve — the `_run_step` consumer has to
    # actually run, or arm C observes only one of the two consumers.
    "model/test_resolve_gs_is_shared.jl" => 20.0,
    # Three 16³ Q-tensor builds plus pure value work.
    "model/test_ddi_trunc_radius_three_states.jl" => 6.0,
    # ~40 resolve-only id computations (no solve) plus six real tiny solves:
    # the site-by-value arm, the fail-safe pair, its positive control and the
    # `seed_from` refusal + its control all have to run `_run_step` for real.
    # Measured 38.2 s serial, 123 assertions.
    "model/test_gs_admission_axes.jl" => 40.0,
    # 429 configs resolved, 351 of them also round-tripped through TOML and
    # re-read from their own YAML. No solve and no workspace: `resolve_gs` stops
    # at the resolved objects, so the cost is YAML parsing + O(n) grid setup.
    "model/test_corpus_resolves.jl" => 22.0,
    # Reads ~700 .jl files line by line. No Julia compute at all; measured 0.5 s.
    "model/test_no_ambient_module_refs.jl" => 1.0,
    # One tiny 1-D 5-step ITP through `run_pipeline` (the positive control) plus
    # a throw-before-solve arm; measured 25.5 s, dominated by first-call JIT.
    "model/test_taylor_degree_cap_guard.jl" => 26.0,
    # Seven resolve-only id computations, two per Ref. No solve; measured 5.8 s.
    "model/test_ambient_refs_vs_artifact_id.jl" => 6.0,
    # F=6 propagator comparisons × 6 LHY types × 2 time directions, plus a
    # SpatialLHY table build (BdG solves) — measured 22.2s.
    "hamiltonian/test_tabulated_lhy_propagator_parity.jl" => 22.0,
    "oracles/test_imag_time_propagator_generator.jl" => 22.8,
    "validation/test_L5_operator_rhs_compare.jl" => 22.6,
    "hamiltonian/test_ddi_padded.jl" => 97.8,
    "workflow/test_dynamics_lhy_normalisation.jl" => 3.0,
    "solvers/test_lbfgs_forward_coverage.jl" => 2.0,
    "solvers/test_precond_default_is_off.jl" => 4.0,
    "bench/test_ab_report.jl" => 2.0,
    "oracles/test_lhy_table_path_coverage.jl" => 2.0,
    "analysis/test_diagnostics.jl" => 21.3,
    "oracles/test_zeeman_diagonal_analytic.jl" => 19.9,
    "hamiltonian/test_ddi_convention_factorial.jl" => 18.2,
    "analysis/test_superfluid_fraction.jl" => 16.6,
    "workflow/test_dynamics_lhy_plumbing.jl" => 16.1,
    "foundation/test_property_based.jl" => 16.0,
    "oracles/test_stability_indeterminate.jl" => 15.5,
    "oracles/test_term_properties.jl" => 15.5,
    "oracles/test_term_fd_registry_coverage.jl" => 125.0,  # 36 s locally, 125.4 s on the runner
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
    "oracles/test_trapped_bdg_frequencies.jl" => 26.0,  # 6 LOBPCG fixtures + dense
    "oracles/test_bragg_response_spectrum.jl" => 13.0,  # 7 real-time runs
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
    "analysis/test_spinor_phase_classifier.jl" => 10.3,
    "oracles/test_global_phase_covariance.jl" => 8.7,
    "test_level1_scalar_exact.jl" => 8.5,
    "workflow/validation/test_scalar_summary.jl" => 8.4,
    "analysis/test_vorticity_berry.jl" => 8.4,
    "analysis/test_physics_level1.jl" => 7.8,
    "workflow/test_inspect_config.jl" => 7.7,
    "workflow/test_vortex_density_movie.jl" => 6.0,
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
    # 0.0 s with SPINORBEC_RUN_HEAVY_YAML off, these with it on.
    # MEASURED ON THE RUNNER, not on a workstation. 50.2 s was this file on a
    # 10-core box with a warm depot; the 4-vCPU CI runner takes 776.3 s — 15x —
    # because it is GP fitting, and `_COST` sets the HAND-OUT ORDER. Declared at
    # 50 s it was handed out late, so a worker was still inside it at the
    # 1800 s cap and the whole `full` tier died with "unrun files" (nightly run
    # 30668378491, 2026-07-31: all four workers killed, zero assertion
    # failures). Longest file in the suite; it must be handed out first.
    "workflow/test_multi_fidelity_yaml.jl" => 776.0,
    # 68 s here; declared high because a runner estimate is what this model
    # needs and the nightly timing table will correct it downward if generous.
    "workflow/test_klaus_validation.jl" => 180.0,
    "workflow/test_live_monitor.jl" => 30.0,   # 10 s here; a runner is slower
    "workflow/test_active_learning_yaml.jl" => 21.7,
    "hamiltonian/test_mixed_precision_kinetic_buffer.jl" => 9.7,
    # 4.8 s here against a warm depot; the CI runner pays a cold precompile
    # inside the subprocess, so reserve for that rather than under-book it.
    "gpu/test_cpu_only_runner.jl" => 9.0,   # reserved 60 for a cold subprocess precompile; measured 8.7
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
    "solvers/test_lbfgs_history_precision.jl" => 8.0,
    "solvers/test_lbfgs_line_search_fused_gradient.jl" => 6.0,
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
    elseif tier == "integration"
        return INTEGRATION_TESTS
    else
        @warn "Unknown SPINORBEC_TEST_TIER=$tier, falling back to full"
        return vcat(FAST_TESTS, CI_EXTRA, FULL_EXTRA)
    end
end
