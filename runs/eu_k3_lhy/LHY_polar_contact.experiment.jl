# Task #19C — LHY interference at K3=200× cigar regime.
# Source: scripts/validation/eu_k3_lhy_gen.jl
# LHY kind = polar_contact (applied outside nominal regime; see scope note).
#
# ANSATZ MISMATCH, left in place deliberately (noted 2026-07-30). This arm's
# state is `m_minus_F`, i.e. FM, while `polar_contact` is the closed form for
# the polar state (zeta = delta_{m,0}). runs/eu_k3_lhy/*.experiment.jl label this
# "applied outside nominal regime", so the mismatch is the study design across
# this family, not an accident — but the number it produces is NOT a validated
# closure for this state and must not be read as one. The matching closed
# form is `fm_contact` (any F since 2026-07-27, gated against full_bdg at
# F=1..8); the general path is `full_bdg`. The sibling `icosahedral` arm had
# the same defect and could no longer run at all once the I_h form began
# refusing lambda_spin < 0, so it moved to full_bdg. This arm fails QUIETLY
# instead, which is the more dangerous half. Neither the "scope note" nor any
# generator named in these headers exists in the tree.

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
                "kind" => "polar_contact",
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
                "kind" => "polar_contact",
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
