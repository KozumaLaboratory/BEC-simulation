# SMOKE: exercises every code path of config.experiment.jl at low res in ≤ ~2 min.
# 24³ grid, 2×2×2 scan, short ITP. NOT physics — path validation only.

Dict{String, Any}(
    "dealias" => Dict{String, Any}(
        "auto_dt" => true,
        "dt_safety" => 10.0,
        "enabled" => true,
        "k_cut" => 4.0,
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
            "dt" => 0.002,
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 12.0],
                "n" => [24, 24, 24],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.0277777778,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "method" => "itp",
            "n_steps" => 420,
            "noise" => Dict{String, Any}(
                "initial" => Dict{String, Any}(
                    "thermal" => 0.4,
                ),
                "seed" => 20260722,
            ),
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-6,
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
        "product" => Dict{String, Any}(
            "pipeline.0.B.Bz" => ["0.0 Gauss", "6.0e-5 Gauss"],
            "pipeline.0.interactions.c1_ratio" => [-0.015, 0.0277777778],
            "pipeline.0.potential.omega.2" => Dict{String, Any}(
                "from" => 1.0,
                "n" => 2,
                "to" => 2.2,
            ),
        ),
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
