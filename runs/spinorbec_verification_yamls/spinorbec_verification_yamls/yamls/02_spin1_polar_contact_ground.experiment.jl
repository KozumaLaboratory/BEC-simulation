# 02 — Spin-1 polar contact benchmark
# Physics: E_spin=(c1/2)|F|^2. For c1>0, polar state minimizes |F|.
# Expected: phase_classify -> polar-like, spin_order ~ 0, Mz ~ 0.

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
            "n_steps" => 4000,
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
            "energy_decomposition" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "bogoliubov" => Dict{String, Any}(
                "directions" => "auto",
                "k_max" => 4.0,
                "n_directions" => 6,
                "n_k" => 40,
            ),
        ), Dict{String, Any}(
            "summary_json" => Dict{String, Any}(
                "path" => "verify_outputs/02_spin1_polar_summary.json",
            ),
        )],
    )],
)
