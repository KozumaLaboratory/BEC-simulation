# R36 — 4-D Eu phase active learning
#
# Active-learning scan over (c₁_ratio, c_dd_ratio, p_zeeman, q_zeeman)
# with phase_classify_distance entropy as acquisition. Replaces 4-D
# grid scan (50⁴ = 6 × 10⁶ runs, infeasible) with 200-500 AL samples
# concentrated on the boundary surface.
#
# Pre-flight (synthetic 2-D): 66.7 % boundary concentration vs 40 %
# random (commit e3030ac).

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_thesis_24" => Dict{String, Any}(
            "N_atoms" => 30000,
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "c_dd_ratio" => 1.0,
                "enabled" => true,
            ),
            "grid" => Dict{String, Any}(
                "box" => [16, 16, 16],
                "n" => [24, 24, 24],
            ),
            "interactions" => Dict{String, Any}(
                "c1_ratio" => 0.0,
            ),
            "m_lbfgs" => 10,
            "method" => "lbfgs",
            "n_steps" => 500,
            "omega_ref" => 691.15,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.182],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-7,
        ),
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.0,
            ),
            "initial_state" => "m_plus_F",
            "use" => ["eu151_thesis_24"],
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify_distance" => Dict{String, Any}(
                "threshold" => 0.4,
            ),
        ), Dict{String, Any}(
            "summary_json" => Dict{String, Any}(
                "path" => "summary.json",
            ),
        )],
    )],
)
