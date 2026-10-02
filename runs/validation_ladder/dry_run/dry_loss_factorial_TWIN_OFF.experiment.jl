# TWIN CONTROL (auto-generated). Companion of:
#   runs/validation_ladder/dry_run/dry_loss_factorial.experiment.jl
# Regenerate with:
#   julia --project=. scripts/validation/generate_twin_controls.jl
# LHY and loss blocks stripped; everything else preserved.
# Comments from the original YAML are lost on the round-trip.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 10000,
            "omega_ref" => 691.15,
        ),
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.01 Gauss",
            ),
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(),
            "dt" => 0.005,
            "grid" => Dict{String, Any}(
                "box" => [20, 20, 20],
                "n" => [32, 32, 32],
            ),
            "initial_state" => "m_plus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 10000,
                "c1_ratio" => 0.0,
                "omega_ref" => 691.15,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "n_steps" => 3000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.182],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 0.14,
                    "from" => 0.01,
                    "to" => 2.6e-5,
                ),
            ),
            "dt" => 0.0005,
            "duration" => 0.14,
            "save" => Dict{String, Any}(
                "every" => 280,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "2.6e-5 Gauss",
            ),
            "dt" => 0.0001,
            "duration" => 10.0,
            "noise_seed" => 42,
            "save" => Dict{String, Any}(
                "every" => 200,
            ),
            "seed_amplitude" => 1.0e-6,
            "seed_k_cut" => 2.5,
        ),
    )],
    "scan" => Dict{String, Any}(
        "comparison_runs" => [Dict{String, Any}(
            "name" => "K3off_gdroff",
            "override" => Dict{String, Any}(
                "pipeline.2.loss" => false,
            ),
        ), Dict{String, Any}(
            "name" => "K3off_gdron",
            "override" => Dict{String, Any}(
                "pipeline.2.loss" => Dict{String, Any}(
                    "gamma_dr" => 0.02,
                ),
            ),
        ), Dict{String, Any}(
            "name" => "K3on_gdroff",
            "override" => Dict{String, Any}(
                "pipeline.2.loss" => Dict{String, Any}(
                    "K3_per_m_si" => ["1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s"],
                ),
            ),
        ), Dict{String, Any}(
            "name" => "K3on_gdron",
            "override" => Dict{String, Any}(),
        )],
    ),
)
