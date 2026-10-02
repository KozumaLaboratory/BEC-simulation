Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 50000,
            "omega_ref" => 691.15,
        ),
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_edh_phys" => Dict{String, Any}(
            "atom" => "Eu151",
            "grid" => Dict{String, Any}(
                "box" => [18, 18, 18],
                "n" => [64, 64, 64],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.027777777777777776,
                "omega_ref" => 691.15,
            ),
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.182],
                "type" => "harmonic",
            ),
        ),
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.01 Gauss",
            ),
            "cache" => "runs/eu151_edh_vs_flower/cache/gs_10mG_c1_36_64_resim.jld2",
            "method" => "lbfgs",
            "n_steps" => 1,
            "tol" => 1.0e-9,
            "use" => ["eu151_edh_phys"],
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "piecewise" => Dict{String, Any}(
                        "times" => [0.0, 75.0, 150.0, 225.0, 300.0, 375.0, 450.0, 525.0, 600.0, 675.0, 750.0, 825.0, 900.0, 975.0, 1050.0, 1125.0, 1200.0, 1275.0, 1350.0, 1425.0, 1500.0, 1575.0, 1650.0, 1725.0, 1800.0, 1875.0, 1950.0, 2025.0, 2100.0, 2175.0, 2250.0, 2325.0, 2400.0],
                        "values" => [0.01, 0.009384765625, 0.0087890625, 0.008212890625, 0.00765625, 0.007119140625, 0.0066015625, 0.006103515625, 0.005625, 0.005166015625, 0.0047265625, 0.004306640625, 0.00390625, 0.003525390625, 0.0031640625, 0.002822265625, 0.0025, 0.002197265625, 0.0019140625, 0.001650390625, 0.00140625, 0.001181640625, 0.0009765625, 0.000791015625, 0.000625, 0.000478515625, 0.0003515625, 0.000244140625, 0.00015625, 8.7890625e-5, 3.90625e-5, 9.765625e-6, 0.0],
                    ),
                ),
            ),
            "dt" => 0.002,
            "duration" => 2400.0,
            "save" => Dict{String, Any}(
                "every" => 20000,
                "precision" => "f32",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0 Gauss",
            ),
            "dt" => 0.002,
            "duration" => 600.0,
            "noise_seed" => 42,
            "save" => Dict{String, Any}(
                "every" => 20000,
                "precision" => "f32",
                "psi" => true,
            ),
            "seed_amplitude" => 1.0e-8,
            "seed_k_cut" => 2.5,
        ),
    )],
)
