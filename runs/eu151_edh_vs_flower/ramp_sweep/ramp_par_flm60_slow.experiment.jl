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
                        "values" => [0.01, 0.009381074219, 0.008781796875, 0.008202167969, 0.0076421875, 0.007101855469, 0.006581171875, 0.006080136719, 0.00559875, 0.005137011719, 0.004694921875, 0.004272480469, 0.0038696875, 0.003486542969, 0.003123046875, 0.002779199219, 0.002455, 0.002150449219, 0.001865546875, 0.001600292969, 0.0013546875, 0.001128730469, 0.000922421875, 0.000735761719, 0.00056875, 0.000421386719, 0.000293671875, 0.000185605469, 9.71875e-5, 2.8417969e-5, -2.0703125e-5, -5.0175781e-5, -6.0e-5],
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
                "Bz" => "-6e-05 Gauss",
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
