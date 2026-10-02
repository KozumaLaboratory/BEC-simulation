# SMOKE for ramp_par_edh_mild — 32^3, tiny GS + short dynamics. Validates the
# full GPU runtime path (GS compute -> ramp -> seeded hold -> psi save + CUDA
# kernels) in a few minutes before the real 64^3 launch. NOT physically meaningful.

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
                "n" => [32, 32, 32],
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
                "q" => 0.0,
            ),
            "cache" => "runs/eu151_edh_vs_flower/cache/gs_10mG_polm6_smoke_32.jld2",
            "initial_state" => "m_minus_F",
            "method" => "lbfgs",
            "n_steps" => 40,
            "tol" => 1.0e-6,
            "use" => ["eu151_edh_phys"],
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 4.0,
                    "from" => 0.01,
                    "to" => 2.6e-5,
                ),
            ),
            "dt" => 0.002,
            "duration" => 4.0,
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s"],
            ),
            "save" => Dict{String, Any}(
                "every" => 1000,
                "precision" => "f32",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "2.6e-5 Gauss",
            ),
            "dt" => 0.002,
            "duration" => 4.0,
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s"],
            ),
            "noise_seed" => 42,
            "save" => Dict{String, Any}(
                "every" => 1000,
                "precision" => "f32",
                "psi" => true,
            ),
            "seed_amplitude" => 1.0e-8,
            "seed_k_cut" => 2.5,
        ),
    )],
)
