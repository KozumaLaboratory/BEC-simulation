# Generated from ../config.experiment.jl — do not edit manually.
# Stir rate phi = -4.524 dimless (Barnett ± pair).

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "rotating_basis",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_klaus_phys" => Dict{String, Any}(
            "atom" => "Eu151",
            "gauge_fix" => false,
            "grid" => Dict{String, Any}(
                "box" => [20.0, 20.0, 10.0],
                "n" => [32, 32, 16],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 60000,
                "c1" => 131.3,
                "omega_ref" => 314.159,
            ),
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 2.6],
                "type" => "harmonic",
            ),
        ),
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 26700.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
            ),
            "dt" => 0.005,
            "init_m_idx" => 1,
            "init_sigma" => 1.5,
            "lhy" => Dict{String, Any}(
                "kind" => "scalar",
            ),
            "n_steps" => 1500,
            "tol" => 1.0e-9,
            "use" => ["eu151_klaus_phys"],
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "phi" => Dict{String, Any}(
                    "rate" => 0.0,
                ),
                "theta" => Dict{String, Any}(
                    "duration" => 6.28,
                    "from" => 0.0,
                    "to" => 0.611,
                ),
            ),
            "dt" => 0.001,
            "duration" => 6.28,
            "epsilon" => 1.0e-6,
            "integrator" => "yoshida4",
            "save" => Dict{String, Any}(
                "every" => 200,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "phi" => Dict{String, Any}(
                    "rate" => Dict{String, Any}(
                        "duration" => 15.71,
                        "from" => 0.0,
                        "to" => -4.524,
                    ),
                ),
                "theta" => 0.611,
            ),
            "dt" => 0.001,
            "duration" => 15.71,
            "epsilon" => 1.0e-6,
            "integrator" => "yoshida4",
            "save" => Dict{String, Any}(
                "every" => 200,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "phi" => Dict{String, Any}(
                    "rate" => -4.524,
                ),
                "theta" => 0.611,
            ),
            "dt" => 0.001,
            "duration" => 314.16,
            "epsilon" => 1.0e-6,
            "integrator" => "yoshida4",
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s"],
                "gamma_dr" => 0.02,
            ),
            "save" => Dict{String, Any}(
                "every" => 500,
            ),
        ),
    )],
)
