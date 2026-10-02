# ─────────────────────────────────────────────────────────────────────
#  Eu151 ground-state phase diagram via LBFGS polish + 2D scan.
#
#  Find the GS at each (c1_ratio, q_factor) point with high-precision
#  L-BFGS, then classify the phase (FM / AFM / polar / cyclic / nematic).
#
#  Cost: 11 × 11 = 121 points × (ITP warmup + LBFGS polish) ≈ 30 s/point
#  on GPU = ~1 hour total. Use `comparison_runs` to seed each point with
#  both stretched (m=+F) and polar (m=0) initial states; the lower-energy
#  result wins as the GS.
# ─────────────────────────────────────────────────────────────────────
# 2D Cartesian product over (c1_ratio, q_override).
# At each point, both stretched and polar initial seeds are run; the
# minimum-energy result is the true GS.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_phys" => Dict{String, Any}(
            "N_atoms" => 60000,
            "atom" => "Eu151",
            "grid" => Dict{String, Any}(
                "box" => [12, 12, 8],
                "n" => [32, 32, 24],
            ),
            "omega_ref" => 314.159,
            "potential" => Dict{String, Any}(
                "omega" => ["50 Hz", "50 Hz", "130 Hz"],
                "type" => "harmonic",
            ),
        ),
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.1 Gauss",
            ),
            "interactions" => Dict{String, Any}(
                "c1_ratio" => 0.0,
            ),
            "m_lbfgs" => 10,
            "method" => "lbfgs",
            "n_steps" => 500,
            "tol" => 1.0e-9,
            "use" => ["eu151_phys"],
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "bogoliubov" => Dict{String, Any}(
                "k_max" => 8.0,
                "n_k" => 32,
            ),
        ), Dict{String, Any}(
            "summary_json" => Dict{String, Any}(
                "path" => "summary.json",
            ),
        )],
    )],
    "scan" => Dict{String, Any}(
        "comparison_runs" => [Dict{String, Any}(
            "name" => "stretched",
            "override" => Dict{String, Any}(
                "pipeline.0.ground_state.init_m_idx" => 1,
            ),
        ), Dict{String, Any}(
            "name" => "polar",
            "override" => Dict{String, Any}(
                "pipeline.0.ground_state.init_m_idx" => 7,
            ),
        )],
        "product" => Dict{String, Any}(
            "pipeline.0.ground_state.B.q" => Dict{String, Any}(
                "from" => -50.0,
                "n" => 11,
                "to" => 50.0,
            ),
            "pipeline.0.ground_state.interactions.c1_ratio" => Dict{String, Any}(
                "from" => -0.05,
                "n" => 11,
                "to" => 0.05,
            ),
        ),
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
