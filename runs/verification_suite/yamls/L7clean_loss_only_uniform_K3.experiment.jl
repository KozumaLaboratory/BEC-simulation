# L7clean — loss-only validation with ITP-skipped uniform IC.
# Variant of L7_loss_only_uniform_K3.experiment.jl: drops the 20-step ITP that
# perturbed the uniform initial state. Uses n_steps=0 so the GS step
# returns the initial uniform state unchanged. K3 loss should then
# match analytic n(t) = n0 / sqrt(1 + 2 K3 n0² t) to high precision
# (limited by dt² Strang-split error + integration discretisation).

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 100000,
            "omega_ref" => 628.3,
        ),
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => 0.0,
            ),
            "atom" => "Cr52",
            "ddi" => Dict{String, Any}(
                "enabled" => false,
            ),
            "dt" => 0.001,
            "gauge_fix" => false,
            "grid" => Dict{String, Any}(
                "box" => [4.0, 4.0, 4.0],
                "n" => [16, 16, 16],
            ),
            "init_sigma" => 1.5,
            "initial_state" => "uniform",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 100000,
                "c0" => 0.0,
                "c1" => 0.0,
                "omega_ref" => 628.3,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "n_steps" => 0,
            "potential" => Dict{String, Any}(
                "type" => "none",
            ),
            "tol" => 1.0e-12,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => false,
            ),
            "dt" => 0.0005,
            "duration" => 1.0,
            "interactions" => Dict{String, Any}(
                "N_atoms" => 100000,
                "c0" => 0.0,
                "c1" => 0.0,
                "omega_ref" => 628.3,
            ),
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s"],
            ),
            "save" => Dict{String, Any}(
                "every" => 50,
                "precision" => "f64",
                "psi" => false,
            ),
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "summary_json" => Dict{String, Any}(
                "path" => "runs/verification_suite/outputs/L7clean_loss_only_uniform_K3.json",
            ),
        )],
    )],
)
