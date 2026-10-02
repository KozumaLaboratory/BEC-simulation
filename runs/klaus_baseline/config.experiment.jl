# ─────────────────────────────────────────────────────────────────────
#  Klaus 2022 magnetostir — atom comparison (Eu151 vs Dy164).
#
#  Same protocol (35° tilt → 226 Hz stir × 500 ms), different atoms +
#  Klaus-regime p value. Two comparison runs at every scan point;
#  here scan: is empty so we get exactly two runs.
#
#  Verified Dy164: m=+F 0.9995 → 0.9999 (frozen spinor),
#  Lz [-0.52, +0.43] (orbital response). Klaus paper reproduction.
# ─────────────────────────────────────────────────────────────────────
# Atom + Klaus-regime p comparison (Eu151 g_F vs Dy164 g_J differs).

Dict{String, Any}(
    "accuracy" => 1.0e-6,
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "rotating_basis",
    ),
    "mixins" => Dict{String, Any}(
        "klaus_phys" => Dict{String, Any}(
            "N_atoms" => 60000,
            "dt" => 0.005,
            "gauge_fix" => false,
            "grid" => Dict{String, Any}(
                "box" => [20, 20, 10],
                "n" => [24, 24, 12],
            ),
            "init_m_idx" => 1,
            "n_steps" => 250,
            "omega_ref" => 314.159,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 2.6],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-7,
        ),
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 26700.0,
            ),
            "atom" => "Eu151",
            "interactions" => Dict{String, Any}(
                "c1" => 0.0,
            ),
            "use" => ["klaus_phys"],
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "phi" => Dict{String, Any}(
                    "rate" => 0.0,
                ),
                "theta" => Dict{String, Any}(
                    "duration" => 6.28,
                    "from" => 0.0,
                    "to" => 0.611,
                ),
            ),
            "duration" => 6.28,
            "save" => Dict{String, Any}(
                "every" => 200,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "phi" => Dict{String, Any}(
                    "rate" => Dict{String, Any}(
                        "duration" => 15.7,
                        "from" => 0.0,
                        "to" => 4.524,
                    ),
                ),
                "theta" => 0.611,
            ),
            "duration" => 15.7,
            "save" => Dict{String, Any}(
                "every" => 200,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "phi" => Dict{String, Any}(
                    "rate" => 4.524,
                ),
                "theta" => 0.611,
            ),
            "duration" => 157.0,
            "save" => Dict{String, Any}(
                "every" => 200,
            ),
        ),
    )],
    "scan" => Dict{String, Any}(
        "comparison_runs" => [Dict{String, Any}(
            "name" => "eu151",
            "override" => Dict{String, Any}(
                "pipeline.0.ground_state.B.p" => 26700.0,
                "pipeline.0.ground_state.atom" => "Eu151",
            ),
        ), Dict{String, Any}(
            "name" => "dy164",
            "override" => Dict{String, Any}(
                "pipeline.0.ground_state.B.p" => 28428.0,
                "pipeline.0.ground_state.atom" => "Dy164",
            ),
        )],
    ),
)
