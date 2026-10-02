# R37 — F=6 triple-point hunting (Eu thesis-grade)
#
# Run R36 AL → detect_triple_points → trace 3 boundary curves from
# each candidate. Goal: find 3+ phase coexistence points in the F=6
# Eu phase diagram. Literature has F=1,2,3 triple points (FL/CSV/PCV)
# but no F=6 mapping — this is the publication candidate.
#
# Same physics as R36 (24³, Eu thesis) but the analyze step records
# `phase_classify_distance` so detect_triple_points can read the
# scores list.

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
