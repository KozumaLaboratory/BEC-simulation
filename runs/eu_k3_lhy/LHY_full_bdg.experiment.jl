# LHY kind was `icosahedral` until 2026-07-30. `IcosahedralLHY`'s closed form
# is c0^(5/2) + 3|lambda_spin|^(5/2); the absolute value made it symmetric under
# c1 -> -c1 and returned a real energy where the spin-Goldstone branch is
# dynamically unstable. This config runs at c1_ratio < 0, i.e. OUTSIDE that
# domain -- `epsilon_LHY_F6_Ih` now returns NaN and the table build throws.
# `full_bdg` diagonalises the coupled problem with no ansatz and is valid here.
# Gated by test/oracles/test_lhy_config_validity_domain.jl.
#
# ┌ PAIRED ARM (2026-07-31). A sibling `LHY_fm_dipolar*` config runs the SAME cell
# │ (same K3, same `initial_state: m_minus_F`) with `kind: fm_dipolar`. Both exist
# │ because two independent renames of the old `LHY_icosahedral*` file chose
# │ different targets; kept deliberately, because the pair MEASURES how much the
# │ scheme dependence below is worth: V_LHY(n=3.7e-3) = 0.59327 here vs 0.553422
# │ for fm_dipolar, a 7 % spread.
# │
# │ CORRECTION to the line above: "`full_bdg` … is valid here" is true about the
# │ ANSATZ and false about the state. full_bdg has its own validity condition —
# │ mean-field stability — and this ladder breaks it: max Im omega = 0.396 at
# │ (c0=3270.05, c1=-16.3502, m_minus_F). Its own warning: the zero-point sum
# │ drops the complex branches while the counterterms still subtract all 13, so
# │ eps_LHY is SCHEME-DEPENDENT here. THIS ARM IS THE COMPARATOR, NOT THE ANSWER.
# │
# │ The instability is entirely dipolar — DDI off gives max Im omega exactly 0 at
# │ eps_dd = 0.5402, and full_bdg then agrees with the FM closed form to six
# │ significant figures. The fm_dipolar sibling is the arm whose ansatz matches
# │ the state (c1 < 0 makes FM the mean-field ground state) and whose eps_dd sits
# │ inside Petrov's domain. Record: docs/validation/full_bdg_scheme_dependence_eu_f6.md
# │
# └ `factorial_2x4.json` has NO row for either arm — it predates them, and its
#   rows are measured values that nobody has re-run. Do not read the manifest as
#   covering this cell's LHY axis.
# Task #19C — LHY interference at K3=200× cigar regime.
# Source: scripts/validation/eu_k3_lhy_gen.jl
# LHY kind = full_bdg. Renamed from LHY_icosahedral.experiment.jl 2026-07-30 so the file
# name matches its content, as the convention requires; the one doc that cited
# the old path was updated in the same commit.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 30000,
            "omega_ref" => 628.3,
        ),
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.01 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "gauge_fix" => false,
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 12.0],
                "n" => [32, 32, 32],
            ),
            "init_sigma" => 1.5,
            "initial_state" => "m_minus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 30000,
                "c1_ratio" => -0.005,
                "omega_ref" => 628.3,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "full_bdg",
            ),
            "n_steps" => 2000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 0.25],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 0.0,
                    "from" => 0.01,
                    "to" => 2.6e-5,
                ),
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 20.0,
            "lhy" => Dict{String, Any}(
                "kind" => "full_bdg",
            ),
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s"],
            ),
            "save" => Dict{String, Any}(
                "every" => 50,
                "precision" => "f64",
                "psi" => true,
            ),
            "seed_amplitude" => 1.0e-6,
            "seed_k_cut" => 2.5,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "winding_map" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        )],
    )],
)
