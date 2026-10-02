# 01 — Noninteracting harmonic oscillator ground state
# Physics: scalar F=0 GPE with c0=0. In dimensionless units, E/N = 3/2 for omega=(1,1,1).
# Expected: Gaussian ground state, zero spin order, energy converges to 1.5 per particle.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
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
            "dt" => 0.002,
            "grid" => Dict{String, Any}(
                "box" => [10.0, 10.0, 10.0],
                "n" => [32, 32, 32],
            ),
            "initial_state" => "polar",
            "interactions" => Dict{String, Any}(
                "c0" => 0.0,
                "c1" => 0.0,
            ),
            "method" => "itp",
            "n_steps" => 3000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-10,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "phase_classify" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "summary_json" => Dict{String, Any}(
                "path" => "verify_outputs/01_scalar_ho_summary.json",
            ),
        )],
    )],
)
