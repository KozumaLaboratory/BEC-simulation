# ─────────────────────────────────────────────────────────────────────
#  BOUNDARY REFINEMENT — resolve the cyclic↔FM line B_c(κ) at physical Eu
#  (c1 = +1/36). Instead of a dense 2D fill, we search ONLY the transition
#  bracket per κ (from the coarse 64³ map), as explicit (Bz, κ) points via
#  `zip` — no Cartesian waste. Each point warm-starts (seed_from nearest) off
#  the closest coarse 64³ winner and pins, so the fine B points that have no
#  exact coarse seed still converge cheaply.
#
#  18 boundary points × 2 seeds = 36 solves @ 64³ (vs 400 for a dense grid).
# ─────────────────────────────────────────────────────────────────────
# nearest: warm-start each fine boundary point off the closest coarse
# 64³ winner (same c1 + seed, nearest in Bz/κ). Same grid ⇒ no upsample.
# Explicit boundary points: parallel (Bz, κ) arrays — each column is one cell,
# concentrated inside each κ's cyclic→FM bracket read off the coarse map.

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
            "pipeline.0.B.Bz" => ["4.2e-5 Gauss", "4.4e-5 Gauss", "4.6e-5 Gauss", "6.4e-5 Gauss", "6.7e-5 Gauss", "7.0e-5 Gauss", "7.3e-5 Gauss", "8.0e-5 Gauss", "8.5e-5 Gauss", "9.0e-5 Gauss", "9.5e-5 Gauss", "7.8e-5 Gauss", "8.4e-5 Gauss", "9.0e-5 Gauss", "9.6e-5 Gauss", "8.4e-5 Gauss", "9.0e-5 Gauss", "9.6e-5 Gauss"],
            "pipeline.0.potential.omega.2" => [1.0, 1.0, 1.0, 1.3, 1.3, 1.3, 1.3, 1.6, 1.6, 1.6, 1.6, 1.9, 1.9, 1.9, 1.9, 2.2, 2.2, 2.2],
        ),
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
