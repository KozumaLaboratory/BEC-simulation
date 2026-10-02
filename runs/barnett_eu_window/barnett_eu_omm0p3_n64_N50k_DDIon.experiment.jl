# Klaus/Barnett — experimental-scale production target at Ω/ω_⊥ = -0.3.
# Source: hand-derived from barnett_eu_omm0p3_n64_DDIon.experiment.jl.
# Goal: lift N from 1e4 (window-scan scale) to 5e4 (Matsui experimental
# scale) at the recommended Ω. Single cell; pairs with the 64³ Ω=-0.3
# anchor at N=1e4 — together they verify both grid- AND scale-stability
# of the Barnett recommendation.

Dict{String, Any}(
    "dealias" => Dict{String, Any}(
        "auto_dt" => true,
        "dt_safety" => 10.0,
        "enabled" => true,
        "k_cut" => 16.0,
    ),
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 50000,
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
                "secular" => false,
            ),
            "dt" => 0.005,
            "gauge_fix" => false,
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 12.0],
                "n" => [64, 64, 64],
            ),
            "init_sigma" => 1.5,
            "initial_state" => "m_minus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.02778,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "n_steps" => 2000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.181818],
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
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 10.0,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "rotating_frame_omega" => -0.3,
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
