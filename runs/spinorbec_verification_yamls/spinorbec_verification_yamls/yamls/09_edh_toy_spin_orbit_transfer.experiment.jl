# 09 — Toy Einstein-de Haas spin-orbit-transfer sanity check
# Physics: DDI couples spin and orbital angular momentum. In a closed system, Jz=Lz+Sz should be approximately conserved.
# Expected: small spin depolarization and nonzero orbital/winding signal; not a quantitative Matsui reproduction.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 2000,
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
            "ddi" => Dict{String, Any}(
                "enabled" => true,
            ),
            "dt" => 0.004,
            "grid" => Dict{String, Any}(
                "box" => [16.0, 16.0, 16.0],
                "n" => [32, 32, 32],
            ),
            "initial_state" => "m_plus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 2000,
                "c1_ratio" => 0.0,
                "omega_ref" => 691.15,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "scalar",
            ),
            "method" => "itp",
            "n_steps" => 3500,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.1],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-8,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "2.6e-5 Gauss",
            ),
            "dt" => 0.0005,
            "duration" => 0.8,
            "noise_seed" => 42,
            "save" => Dict{String, Any}(
                "every" => 40,
                "precision" => "f32",
                "psi" => true,
            ),
            "seed_amplitude" => 1.0e-5,
            "seed_k_cut" => 1.5,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "winding_map" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "vortex_detect" => Dict{String, Any}(
                "component" => 1,
                "threshold" => 0.05,
            ),
        ), Dict{String, Any}(
            "summary_json" => Dict{String, Any}(
                "path" => "verify_outputs/09_edh_toy_summary.json",
            ),
        )],
    )],
)
