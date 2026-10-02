# BOUNDARY EXTENSION — close B_c(κ) at high oblateness. At κ=1.9, 2.2 the
# cyclic→FM transition is above the 96µG window of config_boundary_64, so probe
# B = 105–145 µG there. Same machinery: explicit (Bz, κ) points via zip,
# seed_from nearest off the coarse 64³ map + pin. 10 points × 2 seeds = 20 solves.

Dict{String, Any}(
    "dealias" => Dict{String, Any}(
        "auto_dt" => true,
        "dt_safety" => 10.0,
        "enabled" => true,
        "k_cut" => 10.0,
    ),
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.0 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 12.0],
                "n" => [64, 64, 64],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.0277777778,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "m_lbfgs" => 20,
            "method" => "lbfgs",
            "n_steps" => 800,
            "pin" => Dict{String, Any}(
                "epsilon_ramp" => [0.004, 0.002, 0.001, 0.0005],
                "kind" => "transverse",
            ),
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "seed_from" => Dict{String, Any}(
                "nearest" => true,
                "run" => "runs/config_promote_64_6221dc7f",
                "upsample" => false,
            ),
            "tol" => 1.0e-7,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify_distance" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "multipole_order" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "majorana_order" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        )],
    )],
    "scan" => Dict{String, Any}(
        "comparison_runs" => [Dict{String, Any}(
            "name" => "stretched",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "m_plus_F",
            ),
        ), Dict{String, Any}(
            "name" => "polar",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
            ),
        )],
        "zip" => Dict{String, Any}(
            "pipeline.0.B.Bz" => ["1.05e-4 Gauss", "1.15e-4 Gauss", "1.25e-4 Gauss", "1.35e-4 Gauss", "1.45e-4 Gauss", "1.05e-4 Gauss", "1.15e-4 Gauss", "1.25e-4 Gauss", "1.35e-4 Gauss", "1.45e-4 Gauss"],
            "pipeline.0.potential.omega.2" => [1.9, 1.9, 1.9, 1.9, 1.9, 2.2, 2.2, 2.2, 2.2, 2.2],
        ),
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
