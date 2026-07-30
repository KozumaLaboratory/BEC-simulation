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
         along a B-scan, so silence here is a wrong number nobody sees.")]

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
