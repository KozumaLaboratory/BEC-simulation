# 00 — Exact stationary scalar benchmark
# Physics: F=0, no trap, no interaction, uniform k=0 state.
# Expected: only a global phase; norm, energy, populations constant to roundoff.

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
            "atom" => "Ca40",
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
                "p" => 0.0,
                "q" => 0.0,
            ),
            "dt" => 0.001,
            "duration" => 1.0,
            "save" => Dict{String, Any}(
                "every" => 100,
                "precision" => "f64",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "summary_json" => Dict{String, Any}(
                "path" => "verify_outputs/00_scalar_free_uniform_summary.json",
            ),
        )],
    )],
)
