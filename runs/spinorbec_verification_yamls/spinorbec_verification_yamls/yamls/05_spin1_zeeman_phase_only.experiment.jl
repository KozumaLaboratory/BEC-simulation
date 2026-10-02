# 05 — Pure Zeeman phase benchmark
# Physics: with c0=c1=0, no trap and no DDI, diagonal Zeeman terms only rotate phases.
# Expected: populations and total magnetization are exactly constant; no spin transfer.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.0,
            ),
            "atom" => "Na23",
            "ddi" => Dict{String, Any}(
                "enabled" => false,
            ),
            "dt" => 0.001,
            "grid" => Dict{String, Any}(
                "box" => [16.0],
                "n" => [32],
            ),
            "initial_state" => "uniform",
            "interactions" => Dict{String, Any}(
                "c0" => 0.0,
                "c1" => 0.0,
            ),
            "method" => "itp",
            "n_steps" => 20,
            "potential" => Dict{String, Any}(
                "type" => "none",
            ),
            "tol" => 1.0e-12,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 2.0,
                "q" => 0.4,
            ),
            "dt" => 0.001,
            "duration" => 2.0,
            "save" => Dict{String, Any}(
                "every" => 100,
                "precision" => "f64",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "summary_json" => Dict{String, Any}(
                "path" => "verify_outputs/05_spin1_zeeman_phase_summary.json",
            ),
        )],
    )],
)
