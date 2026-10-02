# 07 — Bogoliubov stability benchmark for spin-1 polar phase
# Physics: stable polar state for c1>0 and q>=0. The BdG analyzer should not report growing modes.
# Expected: max growth rate zero within numerical tolerance; dispersion has real modes.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.4,
            ),
            "atom" => "Na23",
            "ddi" => Dict{String, Any}(
                "enabled" => false,
            ),
            "dt" => 0.003,
            "grid" => Dict{String, Any}(
                "box" => [10.0, 10.0, 10.0],
                "n" => [24, 24, 24],
            ),
            "initial_state" => "polar",
            "interactions" => Dict{String, Any}(
                "c0" => 100.0,
                "c1" => 2.0,
            ),
            "method" => "itp",
            "n_steps" => 3500,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "bogoliubov" => Dict{String, Any}(
                "directions" => "auto",
                "k_max" => 6.0,
                "n_directions" => 12,
                "n_k" => 80,
            ),
        ), Dict{String, Any}(
            "bogoliubov_dispersion" => Dict{String, Any}(
                "direction" => [1.0, 0.0, 0.0],
                "k_max" => 6.0,
                "n_k" => 80,
            ),
        ), Dict{String, Any}(
            "summary_json" => Dict{String, Any}(
                "path" => "verify_outputs/07_spin1_polar_bdg_summary.json",
            ),
        )],
    )],
)
