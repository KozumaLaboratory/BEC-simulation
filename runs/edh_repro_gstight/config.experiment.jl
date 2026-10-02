Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 50000,
            "omega_ref" => 691.1504,
        ),
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_repro" => Dict{String, Any}(
            "atom" => "Eu151",
            "grid" => Dict{String, Any}(
                "box" => [16, 16, 16],
                "n" => [48, 48, 48],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.027777777777777776,
                "omega_ref" => 691.1504,
            ),
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.1818182],
                "type" => "harmonic",
            ),
        ),
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.01 Gauss",
            ),
            "cache" => "runs/edh_repro_gstight/gs.jld2",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "pad_factor" => 2.0,
                "padded" => true,
                "secular" => false,
            ),
            "init_state_params" => Dict{String, Any}(
                "init_phi" => 0.0,
                "init_theta" => 3.141592653589793,
            ),
            "initial_state" => "spin_coherent",
            "method" => "lbfgs",
            "n_steps" => 3000,
            "tol" => 1.0e-11,
            "use" => ["eu151_repro"],
        ),
    )],
)
