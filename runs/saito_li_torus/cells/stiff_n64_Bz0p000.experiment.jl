Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "saito_li_droplet" => Dict{String, Any}(
            "atom" => "Eu151",
            "grid" => Dict{String, Any}(
                "box" => [6, 6, 6],
                "n" => [64, 64, 64],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 15000,
                "c1_ratio" => 0.0,
                "c_total" => 584.37,
                "omega_ref" => 691.15,
            ),
            "potential" => Dict{String, Any}(
                "type" => "none",
            ),
        ),
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.0 Gauss",
            ),
            "ddi" => Dict{String, Any}(),
            "init_state_params" => Dict{String, Any}(
                "init_phi" => 1.5707963267948966,
                "init_theta" => 1.5707963267948966,
                "init_vortex_charge" => 1,
            ),
            "initial_state" => "spin_coherent",
            "lhy" => Dict{String, Any}(
                "c_lhy" => 276.28,
                "kind" => "scalar",
            ),
            "method" => "lbfgs",
            "n_steps" => 4000,
            "tol" => 1.0e-9,
            "use" => ["saito_li_droplet"],
        ),
    )],
)
