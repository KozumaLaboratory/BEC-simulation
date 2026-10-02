# Klaus hybrid Cell B — MAGNETOSTIR + weak-field EdH readout.
# GS → tilt-up → spin-up → steady Klaus magnetostir → B quench → weak-field readout.

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
                "B_mag" => "0.01 Gauss",
                "phi" => 0.0,
                "theta" => 3.14159,
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
            "initial_state" => "m_minus_F",
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
                "B_mag" => "0.01 Gauss",
                "phi" => 0.0,
                "theta" => Dict{String, Any}(
                    "duration" => 3.45575,
                    "from" => 3.14159,
                    "to" => 2.53059,
                ),
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => true,
            ),
            "dt" => 0.005,
            "duration" => 3.45575,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "save" => Dict{String, Any}(
                "every" => 200,
                "precision" => "f64",
                "psi" => true,
            ),
            "seed_amplitude" => 1.0e-6,
            "seed_k_cut" => 2.5,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "B_mag" => "0.01 Gauss",
                "phi" => Dict{String, Any}(
                    "rate" => Dict{String, Any}(
                        "duration" => 3.45575,
                        "from" => 0.0,
                        "to" => -0.74,
                    ),
                ),
                "theta" => 2.53059,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => true,
            ),
            "dt" => 0.005,
            "duration" => 3.45575,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "save" => Dict{String, Any}(
                "every" => 200,
                "precision" => "f64",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "B_mag" => "0.01 Gauss",
                "phi" => Dict{String, Any}(
                    "rate" => -0.74,
                ),
                "theta" => 2.53059,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => true,
            ),
            "dt" => 0.005,
            "duration" => 217.02123,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "save" => Dict{String, Any}(
                "every" => 1000,
                "precision" => "f64",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "B_mag" => Dict{String, Any}(
                    "duration" => 0.69115,
                    "from" => 0.01,
                    "to" => 2.6e-5,
                ),
                "phi" => Dict{String, Any}(
                    "rate" => -0.74,
                ),
                "theta" => 2.53059,
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
            "save" => Dict{String, Any}(
                "every" => 50,
                "precision" => "f64",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "B_mag" => "2.6e-5 Gauss",
                "phi" => 0.0,
                "theta" => 2.53059,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 13.82301,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
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
