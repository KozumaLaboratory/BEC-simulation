# Klaus 2-phase quench protocol — auto-generated.
# Source: scripts/validation/klaus_quench_gen.jl
#
# Cell : klaus_quench_omm0p5
#   Ω/ω_⊥ rotation prep   : -0.5
#   Ω/ω_⊥ quench + hold   : 0.0 / 0.0
#   DDI in dynamics       : true
#   B quench applied      : true
#   rotation kept in hold : false
#
# Pipeline:
#   GS (Ω=0, B=0.01 G, DDI on)
#   → rotation_prep (10.0 ms, B=0.01 G, Ω=-0.5, DDI=true)
#   → B_quench (1.0 ms, B ramp true, Ω=0.0, DDI=true)
#   → weak_field_hold (10.0 ms, B=2.6e-5 G, Ω=0.0, DDI=true)
#
# anti-aligned-seed: the EdH cascade only runs from the Zeeman-HIGHEST stretched
#   state. Measured 2026-08-19 (#343): rotation contrast +16.5 % anti-aligned
#   against -0.45 % aligned, and peak P_adj 0.53 against 0.24. This is the
#   standard Einstein-de Haas preparation (Kawaguchi-Saito-Ueda PRL 96, 080405).
#   Authority: docs/campaign/edh_quench_polarisation_decision.md

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 10000,
            "omega_ref" => 691.1504,
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
                "secular" => true,
            ),
            "dt" => 0.005,
            "gauge_fix" => false,
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 12.0],
                "n" => [32, 32, 32],
            ),
            "init_sigma" => 1.5,
            "initial_state" => "m_plus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 10000,
                "c1_ratio" => 0.02778,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "n_steps" => 3000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.181818],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.01 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 6.9115,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "rotating_frame_omega" => -0.5,
            "save" => Dict{String, Any}(
                "every" => 100,
                "precision" => "f64",
                "psi" => true,
            ),
            "seed_amplitude" => 1.0e-6,
            "seed_k_cut" => 2.5,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 0.6911504,
                    "from" => 0.01,
                    "to" => 2.6e-5,
                ),
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.001,
            "duration" => 0.69115,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "rotating_frame_omega" => 0.0,
            "save" => Dict{String, Any}(
                "every" => 50,
                "precision" => "f64",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "2.6e-5 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 6.9115,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "rotating_frame_omega" => 0.0,
            "save" => Dict{String, Any}(
                "every" => 100,
                "precision" => "f64",
                "psi" => true,
            ),
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
