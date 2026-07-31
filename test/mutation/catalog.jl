# test/mutation/catalog.jl — the defect classes this simulator actually has.
#
# Every entry is a defect that HAPPENED here (see `incident`), reduced to the
# smallest textual edit that reproduces its shape. The catalog is the executable
# form of the incident log: instead of remembering "we once dropped the LHY
# table on the LBFGS path", we re-inject it and ask which test goes red.
#
# What the harness answers, that reading tests cannot:
#   • a mutant NO test catches            → a real gap, ranked by how bad the
#                                            physics error is
#   • a test file that catches nothing    → deletion candidate, on evidence
#     another file doesn't already catch
#   • the minimum-cost file subset that   → what `fast` should contain
#     catches every mutant
#
# Anchors are plain `Regex` that must match EXACTLY ONCE in their file. A
# refactor that moves or rewords the site turns the mutant STALE, and the
# harness reports that loudly rather than silently testing nothing — the same
# failure mode (`_spin_chain_reason` had no `ddi_padded` arm) the catalog exists
# to prevent.
#
# `severity` is the physics error the mutation causes, used to rank escapes:
#   :fatal   wrong sign / wrong ground state / wrong order of accuracy
#   :gross   O(1) factor on a term that dominates the energy
#   :subtle  few-% error, or an error confined to one code path

struct Mutant
    id::Symbol
    file::String            # relative to repo root
    pattern::Regex
    replacement::String
    class::Symbol           # :sign :factor :drop :path_default
    severity::Symbol
    incident::String
    note::String
end

const MUTANTS = Mutant[

    # ── signs ────────────────────────────────────────────────────────
    Mutant(:zeeman_b_to_p_sign,
        "src/workflow/io/units.jl",
        r"    -g_F \* BOHR_MAGNETON \* B_T / \(HBAR \* omega_ref\)",
        "    g_F * BOHR_MAGNETON * B_T / (HBAR * omega_ref)",
        :sign, :fatal,
        "mistake_zeeman_groundstate_direction_inverted_2026_06_10",
        "B→p is declared once here; +Bz on g_F>0 must land the ground state at m=-F."),
    Mutant(:zeeman_quadratic_sign,
        "src/hamiltonian/terms/zeeman.jl",
        r"\[\(-z\.p \* m \+ z\.q \* m\^2\) for m in sys\.m_values\]",
        "[(-z.p * m - z.q * m^2) for m in sys.m_values]",
        :sign, :fatal,
        "mistake_zeeman_dumb_reference_field_axis_q_drift_2026_06_21",
        "`zeeman_energies` is the ACCESSOR arm; `_diag_coef` is the registry arm. \
         Flipping one and not the other is per-path sign drift by construction."),
    Mutant(:spin_mixing_c1_sign,
        "src/hamiltonian/terms/contact/spin_mixing.jl",
        r"    θ = c1 \* f_mag \* dt_frac",
        "    θ = -c1 * f_mag * dt_frac",
        :sign, :fatal,
        "docs/conventions/hamiltonian_sign_audit.md (SpinC1 row)",
        "Propagator-only flip: the energy face still reads the correct c1, so \
         only an energy↔propagator differential or a directional oracle sees it."),
    Mutant(:yoshida_w0_sign,
        "src/hamiltonian/integrator/split_step_composers.jl",
        r"const _YOSHIDA_W0 = 1\.0 - 2\.0 \* _YOSHIDA_W1",
        "const _YOSHIDA_W0 = 1.0 + 2.0 * _YOSHIDA_W1",
        :sign, :fatal,
        "CLAUDE.md 'conventions (do NOT fix)': _YOSHIDA_W0 < 0 is correct",
        "Breaks Σwᵢ = 1, so the composer is no longer consistent: caught only by \
         an ORDER test, never by a tolerance on one dt."),

    # ── factors ──────────────────────────────────────────────────────
    Mutant(:kinetic_propagator_factor,
        "src/hamiltonian/terms/kinetic.jl",
        r"fft_buf \.\*= \(0\.5 \.\* k_squared_dev\)",
        "fft_buf .*= (1.0 .* k_squared_dev)",
        :factor, :fatal,
        "synthetic — ħ²k²/2m is the one factor every other term is measured against",
        "Propagator only. The energy face keeps 0.5, so E and the dynamics disagree."),
    Mutant(:kinetic_energy_factor,
        "src/hamiltonian/terms/kinetic.jl",
        r"    0\.5 \* E\b",
        "    1.0 * E",
        :factor, :fatal,
        "synthetic — the mirror of :kinetic_propagator_factor",
        "Energy face only. Virial and FD-consistency oracles should both see it."),
    Mutant(:trap_omega_not_squared,
        "src/hamiltonian/terms/trap/evaluate_potential.jl",
        r"            s \+= T\(trap\.omega\[d\]\)\^2 \* grid\.x\[d\]\[I\[d\]\]\^2",
        "            s += T(trap.omega[d]) * grid.x[d][I[d]]^2",
        :factor, :fatal,
        "synthetic — the ω=1 blind spot",
        "IDENTITY at ω=1, which is what almost every test grid uses. A suite that \
         only ever traps at ω=1 cannot see this at all — that is the point."),
    Mutant(:lhy_tabulated_energy_2p5,
        "src/hamiltonian/terms/lhy/lhy_term.jl",
        r"        E \+= _lhy_energy_density\(lhy\.densities, lhy\.potential_values, cum, ni\)",
        "        E += 2.5 * _lhy_energy_density(lhy.densities, lhy.potential_values, cum, ni)",
        :factor, :gross,
        "CLAUDE.md: 'Tabulated LHY energy is ∫₀ⁿ V dn′, not n·V(n)' (fixed 2026-07-28)",
        "The exact historical defect: n·V = 2.5ε for ε ∝ n^(5/2). Energy face only \
         — the propagator was right, so only the reported number was wrong."),
    Mutant(:ddi_qtensor_trace,
        "src/hamiltonian/terms/ddi/qtensor.jl",
        r"            Q_xx\[I\] = \(kv_x \* kv_x \* inv_k2 - third\) \* hx",
        "            Q_xx[I] = (kv_x * kv_x * inv_k2 - half) * hx",
        :factor, :gross,
        "CLAUDE.md conventions: Q_αβ = k̂_α k̂_β − δ_αβ/3, Q(k=0) = 0",
        "Breaks tr Q = 0 and Q(k=0) = 0 — algebraic properties, checkable with no \
         reference solution at all."),
    Mutant(:ddi_offdiagonal_2x,
        "src/hamiltonian/terms/ddi/qtensor.jl",
        r"            Q_xy\[I\] = kv_x \* kv_y \* inv_k2 \* hx",
        "            Q_xy[I] = 2 * kv_x * kv_y * inv_k2 * hx",
        :factor, :gross,
        "gotcha_ddi_kernel_breaks_jz_only_for_rough_states_2026_07_29",
        "Off-diagonal only: invisible for any state whose spin lies along z, which \
         is most fixtures. Needs a generic (rough, tilted) state to show up."),

    # ── path defaults / drops ────────────────────────────────────────
    Mutant(:dealias_k_cut_half,
        "src/hamiltonian/integrator/dealias.jl",
        r"safe_k_cut_boundary\(n_grid::Int, box_L::Float64\) = 2 \* \(π \* n_grid / box_L\) / 3",
        "safe_k_cut_boundary(n_grid::Int, box_L::Float64) = 2 * (π * n_grid / box_L) / 2",
        :path_default, :subtle,
        "gotcha_orszag_dealias_cuts_occupied_band_small_grid_2026_07_27",
        "Filters part of the OCCUPIED band. Norm-preserving-looking, physics-eating."),
    # The `ddi_padded` entry this used to target was REMOVED from
    # `_spin_chain_reason` by 9c117c05, which made the fusion handle the padded
    # convolution instead of declining it — the harness reported the anchor STALE
    # on 2026-07-29, which is the mechanism working. Retargeted at the Raman
    # entry, which is still live and is the same claim: an operator that sits
    # BETWEEN the two rotations must decline the fusion, or the fused path drops
    # it silently.
    Mutant(:spin_chain_fuses_over_raman,
        "src/hamiltonian/integrator/spin_chain.jl",
        r"    ws\.raman === nothing \|\| return \"Raman sits between them\"",
        "    # mutant: Raman guard removed",
        :path_default, :fatal,
        "gotcha_yaml_default_flip_disabled_rtp_fusion_2026_07_29",
        "`_spin_chain_reason` is the one list of what the fused half-step would \
         otherwise silently drop, so every entry in it needs an arm. Removing one \
         makes the fusion swallow an operator that sits between the rotations."),
    # The Raman entry above is one of fifteen. Three more, chosen because each
    # disables a DIFFERENT shape of guard: a whole line, a compound condition,
    # and a negation.
    Mutant(:spin_chain_fuses_over_light_shift,
        "src/hamiltonian/integrator/spin_chain.jl",
        r"    ws\.light_shift === nothing \|\| return \"light shift sits between them\"",
        "    # mutant: light-shift guard removed",
        :path_default, :fatal,
        "gotcha_yaml_default_flip_disabled_rtp_fusion_2026_07_29",
        "The light shift is a spin rotation sitting between the two spin-mixing \
         rotations. Fusing over it drops it from every RTP step."),
    Mutant(:spin_chain_fuses_over_transverse_zeeman,
        "src/hamiltonian/integrator/spin_chain.jl",
        r"\(bx != 0\.0 \|\| by != 0\.0\) &&",
        "false &&",
        :path_default, :fatal,
        "gotcha_yaml_default_flip_disabled_rtp_fusion_2026_07_29",
        "Keeps the reason in the list but makes it unreachable — the shape a \
         guard takes when a condition is edited rather than deleted, and the one \
         a text-scanning completeness gate cannot see."),
    Mutant(:spin_chain_fuses_over_magnetic_gradient,
        "src/hamiltonian/integrator/spin_chain.jl",
        r"    ws\.magnetic_gradient === nothing \|\|",
        "    true ||",
        :path_default, :fatal,
        "mistake_config_zeeman_sign_drift_211_files_2026_07_29",
        "A magnetic gradient mutates V around the diagonal step, so the fused \
         kernel would carry the wrong diagonal phase."),
    # Not a physics defect: this one checks that the COMPLETENESS gate works. It
    # adds a new, plausible entry to the list that no test names. Nothing about
    # the stepping changes (`ws.loss` is nothing in the fixtures), so every
    # physics gate stays green — only a test that reads the list itself can see
    # that an entry was added unarmed, which is the failure mode this list has
    # had twice.
    Mutant(:spin_chain_unlisted_new_reason,
        "src/hamiltonian/integrator/spin_chain.jl",
        r"    SPIN_CHAIN_FUSION_ENABLED\[\] \|\| return \"SPIN_CHAIN_FUSION_ENABLED\[\] is off\"\n",
        "    SPIN_CHAIN_FUSION_ENABLED[] || return \"SPIN_CHAIN_FUSION_ENABLED[] is off\"\n" *
        "    ws.loss !== nothing && return \"a loss channel sits between them\"\n",
        :missing_gate, :major,
        "gotcha_cheap_gate_must_canary_and_keep_structure_2026_07_29",
        "A new decline reason with no arm anywhere under test/. Invisible to \
         every physics gate by construction."),

    # ── workflow layer: claims nothing modelled ───────────────────────
    # Five more surfaces where a wrong value reaches every run without ever
    # touching a Hamiltonian term, so no term-level oracle can see it.
    Mutant(:atom_eu_g_f_swaps_I_and_J,
        "src/workflow/initialization/atoms.jl",
        r"lande_g_factor\(6, 5 // 2, 7 // 2; g_J=_EU_G_J\);   # was 7/12",
        "lande_g_factor(6, 7 // 2, 5 // 2; g_J=_EU_G_J);   # was 7/12",
        :factor, :fatal,
        "the hand-typed 7/12·g_J this line replaced",
        "Swaps the nuclear and electronic spins in Eu151's Landé factor, so \
         g_F is wrong and every Zeeman energy, every B→p conversion and the \
         auto-derived q scale with it. The value stays plausible, which is how \
         the hand-typed 7/12·g_J survived. Anchored on the Eu151 line \
         specifically — via the trailing comment, since Eu153 repeats every \
         constant and the bare call matches twice. The harness refused to run \
         until that was fixed, which is the anchor mechanism working."),
    Mutant(:thermal_seed_drops_the_quarter,
        "src/workflow/initialization/thermal_noise.jl",
        r"    sqrt\(T_over_Tc\^3 / 4\)",
        "    sqrt(T_over_Tc^3)",
        :factor, :major,
        "the heuristic seed is documented as η = √((T/T_c)³/4)",
        "Doubles the symmetry-breaking kick. The seed is a HEURISTIC, so no \
         physics oracle can bound it — the only claim available is that it is \
         the documented formula, and that claim needs a test or the formula is \
         decoration."),
    Mutant(:quadratic_zeeman_linear_in_p,
        "src/hamiltonian/coefficients.jl",
        r"    Float64\(p_dimless\)\^2 \* omega_ref",
        "    Float64(p_dimless) * omega_ref",
        :factor, :fatal,
        "gotcha_b_mag_spherical_form",
        "q ∝ B² is what makes the B-block's auto-derived q a function of |B|. \
         Linear in p, it is still monotonic in B and still zero at zero field, \
         so a scan reads as merely rescaled."),
    Mutant(:inspect_demotes_block_to_warn,
        "src/workflow/experiments/inspect_checks.jl",
        r"sev = rule\.zero_meaning === :error \? :block : :warn",
        "sev = :warn",
        :missing_gate, :major,
        "the 4-severity pre-flight inspector; :block is what stops a launch",
        "Demotes every boundary-value blocker to a warning, so autopilot \
         launches a config the inspector already knows is degenerate. The run \
         then fails as :killed_bug hours later on a GPU node."),
    Mutant(:save_every_off_by_one,
        "src/workflow/experiments/pipeline/pipeline_dispatch.jl",
        r"        return Int\(save_block\[\"every\"\]\)",
        "        return Int(save_block[\"every\"]) + 1",
        :off_by_one, :major,
        "gotcha_scan_point_jld2_reading_pitfalls",
        "Shifts which steps are saved. `save.every` must DIVIDE the step count \
         or the last snapshot is not the final state — the +1 breaks exactly \
         that divisibility while leaving a plausible number of snapshots."),

    # ── workflow layer, round 2: schema -> runtime -> report ──────────
    # Chosen for the same reason as the last batch: each is a single
    # declaration that reaches every run without passing through a Hamiltonian
    # term, so the whole oracle suite is green by construction.
    Mutant(:b_theta_degrees_not_converted,
        "src/workflow/experiments/runtime/b_block_builders.jl",
        r"        θ = deg2rad\(evaluate\(theta_wf, t\)\)",
        "        θ = evaluate(theta_wf, t)",
        :factor, :fatal,
        "the YAML key is `theta_deg`; the builder works in radians",
        "Reads the tilt angle as radians. |B| is unchanged, the field still \
         rotates with the knob and still points along +z at 0, so a scan looks \
         like a scan — it is just a different field at every nonzero angle."),
    Mutant(:auto_grid_box_drops_safety,
        "src/workflow/experiments/schema/auto_defaults.jl",
        r"    box = \[R \* _DEFAULT_TF_BOX_SAFETY for R in R_TF\]",
        "    box = [R for R in R_TF]",
        :factor, :major,
        "auto_grid derives the box from the Thomas-Fermi radius",
        "Sizes the box AT the TF radius instead of outside it, so the cloud \
         touches the wall. The run completes, the norm is conserved, and the \
         density is clipped — visible only if something checks the edge."),
    Mutant(:tf_chemical_potential_exponent,
        "src/workflow/experiments/schema/auto_defaults.jl",
        r"\(15\.0 \* N_atoms \* a_s / a_ho\)\^\(2\.0 / 5\.0\)",
        "(15.0 * N_atoms * a_s / a_ho)^(2.0 / 3.0)",
        :factor, :major,
        "μ_TF/ℏω = ½(15 N a_s/a_ho)^{2/5}, isotropic harmonic",
        "The 2/5 is the 3-D Thomas-Fermi exponent. Any exponent still grows \
         with N and still gives a positive radius, so the derived grid stays \
         plausible while being wrong by a power."),
    # Not a physics defect: this one removes a DISCIPLINE the code enforces.
    Mutant(:error_budget_skips_positive_control,
        "src/workflow/validation/error_budget.jl",
        r"    if !\(b\.control >= bound\)",
        "    if false",
        :missing_gate, :fatal,
        "mistake_null_from_a_degenerate_knob_2026_07_31",
        "`NegligibleErrorSpec` refuses to return a PASS when the control does \
         not breach the bound — a comparison that cannot fail is not evidence \
         that the approximation is good. Removing the guard turns every vacuous \
         budget into a green one, and nothing downstream can tell."),
    Mutant(:save_state_drops_the_channel_dict,
        "src/workflow/io/io.jl",
        r"        c_dict=ws\.interactions\.c,",
        "        c_dict=Dict{Int, Float64}(),",
        :missing_gate, :fatal,
        "mistake_config_zeeman_sign_drift_211_files_2026_07_29",
        "Writes an EMPTY channel dict, so every reload silently loses c₂ and \
         every higher even-rank channel while c₀ and c₁ survive. The file \
         opens, the state loads, the physics is a different Hamiltonian."),

    # ── workflow layer: the parser is a physics surface ───────────────
    # These reproduce defects that lived entirely above the Hamiltonian, where
    # every term-level oracle is green by construction because it never goes
    # through the parser. A suite whose grounded tests all call `make_workspace`
    # directly cannot see any of them.
    Mutant(:yaml_ddi_padding_default_off,
        "src/workflow/experiments/schema/parsing_blocks.jl",
        r"const DDI_PADDED_DEFAULT = true",
        "const DDI_PADDED_DEFAULT = false",
        :path_default, :gross,
        "project_ddi_production_runs_bare_unpadded_kernel_2026_07_29 (fixed 9c117c05)",
        "Every production run took the bare unpadded kernel: 2-5 % field error, \
         flat in n. A default in the PARSER, invisible to every test that builds \
         a workspace directly — which is what `bench/profile_rtp.jl` did."),
    Mutant(:yaml_lbfgs_drops_lhy_table,
        "src/workflow/experiments/pipeline/run_step_ground_state.jl",
        r"                spinor_lhy=spinor_lhy_mode,\n                lhy_opts=gs_lhy_opts,",
        "                lhy_opts=gs_lhy_opts,",
        :drop, :fatal,
        "gotcha_lhy_table_dropped_per_path_not_per_sign_2026_07_29 (#179)",
        "`method: lbfgs` ran every ground state with NO tabulated LHY while the \
         ITP arm three lines up was correct. The registry single-declares the \
         SIGN; it does not make the term reach every PATH. Six paths have \
         dropped `ws.lhy` this way."),
    Mutant(:yaml_calibration_not_applied,
        "src/workflow/experiments/pipeline/run_registry.jl",
        # Exactly-8-space indentation pins the single-block arm; the
        # `calibration_history` arm three lines down is indented 12.
        r"\n        apply_calibration!\(data, calib\)\n",
        "\n        # mutant: calibration parsed, then discarded\n",
        :drop, :fatal,
        "synthetic — the lab-units surface has no term-level oracle at all",
        "Lab-unit fields (`p_mv`, `coil_mode`) resolve to Gauss BEFORE downstream \
         parsing. Skipping it leaves the raw millivolts in the field, so every \
         downstream number is wrong by the coil calibration factor."),

    # ── guards and warnings: the class the catalog was blind to ───────
    # Added 2026-07-30. The workflow probe reported
    # `test_dynamics_lhy_plumbing.jl` and `test_lhy_texture_warning.jl` as
    # catching NOTHING, which read as "delete candidates" — and reading them
    # showed why that was wrong: their claims are that a bad config THROWS and
    # that a risky one WARNS, and the catalog had no mutant that stops a guard
    # throwing or a warning firing. An instrument that cannot see a kind of
    # coverage will always propose deleting the tests that provide it.
    Mutant(:make_workspace_silent_zero_guard,
        "src/workflow/initialization/make_workspace.jl",
        # `identity(` instead of `throw(`: the ArgumentError is still built and
        # then discarded, so control falls through and the run proceeds with LHY
        # off — the silent zero itself. An earlier version of this mutant reworded
        # the MESSAGE and escaped, correctly: the test asserts
        # `@test_throws ArgumentError`, which pins the type, not the prose. A
        # message-pinning test would have been a pin, and there is rightly none.
        r"        throw\(\n            ArgumentError\(\n                \"spinor_lhy=:",
        "        identity(\n            ArgumentError(\n                \"spinor_lhy=:",
        :drop, :fatal,
        "the guard added after `ws.lhy` was dropped on six separate paths",
        "Turns the refusal into a fall-through: `make_workspace` returns a \
         workspace with no LHY for a config that asked for it, which is the \
         failure the guard exists to make loud."),
    Mutant(:lhy_texture_warning_muted,
        "src/workflow/initialization/make_workspace.jl",
        r"    spread <= _LHY_TEXTURE_WARN && return nothing",
        "    return nothing",
        :drop, :subtle,
        "gotcha_spatial_lhy_not_a_tabulated_lhy_2026_07_28 (single-spinor caveat)",
        "Mutes the one thing telling a user their textured state is being given a \
         single-spinor LHY table. Costs up to ~5 % in ε_LHY with a sign that flips \
         along a B-scan, so silence here is a wrong number nobody sees."),
    # ── workflow claims the catalog did not model ─────────────────────
    # Added 2026-07-30. After the guard/warning classes, these are the remaining
    # things test/workflow/ actually asserts, taken from the testset names rather
    # than guessed: a schema rejection, a calibration interpolation that clamps
    # instead of extrapolating, its date ordering, the checkpoint memo, and the
    # catalog's family grouping. Until a claim is modelled, the file defending it
    # reads as dead weight.
    Mutant(:schema_c1_ratio_singularity_guard,
        "src/workflow/experiments/schema/schema.jl",
        r"        if cr <= bound \+ 1e-10",
        "        if false",
        :drop, :fatal,
        "docs: `c1_ratio > -1/F²`; `interaction_params_from_constraint` gives c0 → ∞",
        "Lets a config through at or below the -1/F² singularity, where \
         c0 = c_total/(1 + F²·c1_ratio) is infinite or negative. The run then \
         proceeds with a non-physical coupling instead of being refused."),
    Mutant(:calibration_extrapolates,
        "src/workflow/experiments/calibration/core.jl",
        r"    if target <= hist\.dates\[1\]\n        return _stamped\(hist\.entries\[1\], target\)",
        "    if false\n        return _stamped(hist.entries[1], target)",
        :drop, :subtle,
        "the clamp comment: 'drift outside the measured window is unsafe'",
        "Removes the low-side clamp, so a target date before the first measured \
         epoch extrapolates the coil/FORT drift instead of pinning to the nearest \
         measurement — a silently wrong field for a date nobody calibrated."),
    Mutant(:calibration_history_unsorted,
        "src/workflow/experiments/calibration/core.jl",
        r"        issorted\(dates\) \|\| throw\(ArgumentError\(\"calibration dates must be sorted ascending\"\)\)",
        "        # mutant: ordering invariant dropped",
        :drop, :subtle,
        "CalibrationHistory's constructor invariant",
        "`interpolate_calibration` finds its bracket with `searchsortedlast`, which \
         needs sorted dates. Dropping the invariant makes the bracket meaningless \
         and the interpolation silently wrong."),
    Mutant(:checkpoint_never_reuses,
        "src/workflow/checkpoint.jl",
        r"    if !force\n        cached = load_checkpoint\(cp, key\)",
        "    if false\n        cached = load_checkpoint(cp, key)",
        :drop, :subtle,
        "the checkpoint primitive's whole purpose",
        "`get_or_compute!` stops reusing a stored result, so every resume recomputes \
         from scratch. Cheap to miss — the answers stay right and only the cost \
         changes, which is exactly why it needs a test rather than a reviewer."),
    Mutant(:catalog_family_keeps_hash,
        "src/workflow/io/catalog_index.jl",
        r"    s = replace\(String\(name\), r\"_\[0-9a-f\]\{8,\}\$\" => \"\"\)",
        "    s = String(name)",
        :drop, :subtle,
        "run_family's grouping contract",
        "Leaves the content-addressed hash on the family name, so every run becomes \
         its own family and the catalog's grouping collapses to one row per run."),
    Mutant(:cas_canonical_bytes_unsorted,
        "src/workflow/experiment.jl",
        # `rev=true`, not "drop the sort": dropping it is a NO-OP for these specs,
        # because Julia's Dict iteration order is a function of the key hashes, not
        # of insertion order — measured, two specs built in different orders both
        # iterate ["alpha","zeta","mid"]. Reversing the sort genuinely changes the
        # canonical bytes, so this mutant asks the question the ineffective one
        # could not: does anything pin the content id at all?
        r"        for k in sort!\(collect\(keys\(x\)\); by=string\)",
        "        for k in sort!(collect(keys(x)); by=string, rev=true)",
        :drop, :fatal,
        "CLAUDE.md commitment #4: content_id deterministic across dict-iteration order",
        "Drops the key sort, so `content_id(spec)` depends on Dict iteration order. \
         The same spec then lands in different outdirs on different runs and the \
         cache never hits — the whole content-addressing guarantee."),
    Mutant(:conservation_spec_always_passes,
        "src/workflow/validation/specs.jl",
        r"            \(v, v < bound\)",
        "            (v, true)",
        :drop, :fatal,
        "ConservationSpec is the bound-checking half of the validation ladder",
        "The bound is evaluated and then ignored, so every run reports PASS. A \
         validator that cannot fail is worse than no validator: it launders a \
         diverging run as a checked one."),
    Mutant(:loss_k3_alias_guard_removed,
        "src/workflow/experiments/schema/parsing_blocks.jl",
        r"    haskey\(node, \"K3_per_m\"\) && throw\(",
        "    false && throw(",
        :drop, :gross,
        "gotcha_K3_routing_pre_2026_05_13 (the alias removed 2026-05-24)",
        "The removed `K3_per_m` alias becomes silently ignored instead of refused, \
         so a config carrying a 3-body rate under the old name runs with NO 3-body \
         loss — the shape of the original K3-routing defect."),
    Mutant(:state_zoo_spin_coherent_drops_phi,
        "src/workflow/initialization/state_zoo.jl",
        r"    init_theta=theta, init_phi=phi\)",
        "    init_theta=theta, init_phi=0.0)",
        :drop, :gross,
        "CLAUDE.md: 'Wrap, don't fork' — a named state must be the same physics",
        "The named wrapper stops forwarding `phi`, so every caller asking for an \
         in-plane direction gets phi = 0. `:transverse_x` is exactly this call, and \
         the wrapper's whole contract is that it is `init_psi` with a name."),
    Mutant(:gs_cache_key_ignores_interactions,
        "src/workflow/experiments/pipeline/run_step_ground_state.jl",
        r"        \"c\" => _hashable\(interactions\.c\),",
        "        # mutant: interaction channels dropped from the cache key",
        :drop, :fatal,
        "the GS stage cache's 'sensitivity to real physics' contract",
        "Drops the scattering channels from the cache key, so changing c0/c1 hits a \
         STALE cached ground state. The run reports success and reuses the wrong \
         physics — the worst shape a cache bug can take, because nothing looks \
         broken."),
    Mutant(:gs_cache_key_includes_metadata,
        "src/workflow/experiments/pipeline/run_step_ground_state.jl",
        r"        \"v\" => 1,                                    # key-schema version",
        "        \"v\" => 1, \"analyze\" => _hashable(get(p, \"analyze\", nothing)),",
        :drop, :subtle,
        "the cache's 'INSENSITIVE to non-physics' contract",
        "Folds a NON-physics key (the analyze block) into the cache key, so adding an \
         analyzer invalidates a ground state that is physically identical. Silent: \
         the answers stay right and only the cost changes."),
    Mutant(:b_block_cartesian_direction_guard,
        "src/workflow/experiments/schema/B_block.jl",
        r"    has_cartesian && has_direction &&\n        throw\(",
        "    false &&\n        throw(",
        :drop, :gross,
        "the B block's 'the forms are mutually exclusive' rule",
        "Accepts Cartesian components together with a theta/phi direction, which \
         over-determines the field. One of the two is then silently ignored, and \
         which one depends on the downstream path."),
    Mutant(:save_operator_rhs_missing_hpsi_guard,
        "src/workflow/validation/save_operator_rhs.jl",
        r"    r\.hpsi === nothing && throw\(",
        "    false && throw(",
        :drop, :gross,
        "'the operator-RHS diff is meaningless without Hψ'",
        "Writes an operator-RHS bundle with no Hψ in it, so the Level-10 A/B diff \
         later compares nothing and reports agreement."),
    # ── analysis: the observables themselves ─────────────────────────
    # Added 2026-07-31. Everything above mutates the Hamiltonian or the workflow;
    # nothing asked whether the OBSERVABLES that read a state are right. These
    # break the three that every result is quoted in terms of.
    Mutant(:magnetization_m_index_flipped,
        "src/analysis/observables/density_spin.jl",
        r"        Mz \+= m \* sum\(abs2, view\(psi, idx\.\.\.\)\) \* dV",
        "        Mz -= m * sum(abs2, view(psi, idx...)) * dV",
        :sign, :fatal,
        "CLAUDE.md layout: `c=1 → m=F`, `c=D → m=−F`",
        "Flips the sign of ⟨F_z⟩ for every state. Every magnetisation, every \
         m-resolved population plot and every Zeeman directional claim is read \
         through this one sum."),
    Mutant(:probability_current_sign,
        "src/analysis/currents.jl",
        r"                j\[d\]\[I\] \+= imag\(conj\(psi_c\[I\]\) \* dpsi\[I\]\)",
        "                j[d][I] -= imag(conj(psi_c[I]) * dpsi[I])",
        :sign, :fatal,
        "j = Im(ψ* ∇ψ) — the superfluid flow direction",
        "Reverses every current, so a plane wave flows backwards and any \
         circulation / vortex-charge readout changes sign. A magnitude-only test \
         cannot see it."),
    Mutant(:orbital_angular_momentum_sign,
        "src/analysis/currents.jl",
        r"            Lz \+= real\(conj\(psi_c\[I\]\) \* \(-im\) \* \(x \* dpsi_y\[I\] - y \* dpsi_x\[I\]\)\) \* dV",
        "            Lz += real(conj(psi_c[I]) * (-im) * (y * dpsi_x[I] - x * dpsi_y[I])) * dV",
        :sign, :fatal,
        "⟨L_z⟩ = ∫ ψ*(-i)(x∂_y − y∂_x)ψ — the rotation-sense convention",
        "Swaps the cross-product order, so ⟨L_z⟩ changes sign. The Coriolis sign \
         oracle (+Ω ⇒ ⟨L_z⟩ > 0) and every vortex-chirality claim are read \
         through it."),
    # ── solvers: the loops themselves ────────────────────────────────
    # Added 2026-07-31. Nothing had asked whether the ITP / L-BFGS loops do what
    # they claim: renormalise, stop for the right reason, and only accept a step
    # that decreases the energy.
    Mutant(:itp_skips_renormalisation,
        "src/solvers/ground_state/itp_loop.jl",
        r"                _normalize_psi!\(ws\.state\.psi, ws\.grid, n_comp_ws, N_dim\)",
        "                # mutant: renormalisation skipped",
        :drop, :fatal,
        "imaginary time is not norm-preserving — the renormalisation IS the method",
        "Without it ψ decays toward the lowest mode's amplitude instead of being \
         projected onto it, so the energy is evaluated on an unnormalised state \
         and every reported number is scaled by a drifting norm."),
    Mutant(:itp_converges_immediately,
        "src/solvers/ground_state/itp_loop.jl",
        r"                if dE < tol && \(tol_drho <= 0\.0 \|\| drho < tol_drho\)",
        "                if true",
        :drop, :fatal,
        "`converged` is the ITP flag every downstream check reads",
        "Declares convergence at the first check regardless of dE or the density \
         change, so a run that has not converged reports `converged = true` and \
         its ground state is used as if it had."),
    Mutant(:lbfgs_line_search_accepts_anything,
        "src/solvers/lbfgs/helpers.jl",
        r"    accept\(α, E\) = slope < 0 \? \(E ≤ E0 \+ c1 \* α \* slope\) : \(E < E0\)",
        "    accept(α, E) = true",
        :drop, :fatal,
        "the Armijo condition is what makes L-BFGS a descent method",
        "Accepts the first trial step whatever it does to the energy, so the \
         iteration can climb. The variational principle — the only reason a \
         ground-state energy means anything — stops holding."),
    # ── foundation: the primitives everything is built on ────────────
    # Added 2026-07-31. `test/foundation/` was the last unmeasured directory. If a
    # spin matrix or a k-grid is wrong, every term, every observable and every
    # oracle inherits it — and they would all agree with each other.
    Mutant(:spin_ladder_lowers_instead_of_raises,
        "src/foundation/spin_matrices.jl",
        r"        if m\[i\] == m\[j\] \+ 1",
        "        if m[i] == m[j] - 1",
        :sign, :fatal,
        "F+ raises m by 1: F+|F,m⟩ = √(F(F+1)−m(m+1))|F,m+1⟩",
        "Turns F+ into F−, so Fx stays Hermitian and correct-looking while Fy \
         changes sign and every raising/lowering-derived quantity flips. The spin \
         algebra itself, which no downstream test re-derives."),
    Mutant(:grid_k_missing_2pi,
        "src/foundation/grid.jl",
        r"        dk = T\(2π\) / L",
        "        dk = T(1) / L",
        :factor, :fatal,
        "k = 2π n / L — the spectral grid every FFT derivative uses",
        "Drops the 2π from the wavenumber grid, so every kinetic energy, every \
         spectral derivative and every current is off by (2π)² or 2π. Uniformly \
         wrong, therefore self-consistent: only an absolute reference catches it."),
    Mutant(:spin_pair_eigenvalue_offset,
        "src/foundation/spin_matrices.jl",
        r"@inline spin_pair_eigenvalue\(S::Integer, F::Integer\) =",
        "@inline spin_pair_eigenvalue(S::Integer, F::Integer) = 1 +",
        :factor, :fatal,
        "λ_S = (S(S+1) − 2F(F+1))/2 — the ⟨F_i·F_j⟩ eigenvalue in the pair basis",
        "Shifts every spin-pair eigenvalue by a constant, which moves the c↔g \
         channel map AND the Sign Pattern Lemma's β_S together. Both would still \
         agree with each other — this is a single declaration two subsystems read, \
         so only an absolute reference can see it."),
]

"""
    check_anchors(root) -> Vector{(Mutant, n_matches)}

Every mutant must match its anchor exactly once. Returns the STALE ones
(0 or ≥2 matches) — a refactor that moves a site must surface here, not as a
mutant that quietly tests nothing.
"""
function check_anchors(root::AbstractString)
    stale = Tuple{Mutant, Int}[]
    for m in MUTANTS
        path = joinpath(root, m.file)
        n = isfile(path) ? count(m.pattern, read(path, String)) : -1
        n == 1 || push!(stale, (m, n))
    end
    return stale
end
