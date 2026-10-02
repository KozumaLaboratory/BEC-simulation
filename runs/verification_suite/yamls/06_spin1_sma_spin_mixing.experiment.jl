# 06 — Spin-1 coherent spin-mixing benchmark
# Physics: spin-exchange collision 2|m=0> <-> |m=+1>+|m=-1>.
# Expected: N and Mz conserved; component populations oscillate after a small seed.
# This is a qualitative/SMA-conservation test, not a strict period test unless post-fit to SMA ODE.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.05,
            ),
            "atom" => "Na23",
            "ddi" => Dict{String, Any}(
                "enabled" => false,
            ),
            "dt" => 0.003,
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 12.0],
                "n" => [24, 24, 24],
            ),
            "initial_state" => "polar",
            "interactions" => Dict{String, Any}(
                "c0" => 80.0,
                "c1" => 1.0,
            ),
            "method" => "itp",
            "n_steps" => 2500,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.05,
            ),
            "dt" => 0.002,
            "duration" => 8.0,
            "interactions" => Dict{String, Any}(
                "c0" => 80.0,
                "c1" => 1.0,
            ),
            "noise_seed" => 1234,
            "save" => Dict{String, Any}(
                "every" => 50,
                "precision" => "f32",
                "psi" => true,
            ),
            "seed_amplitude" => 0.0001,
            "seed_k_cut" => 1.0,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "summary_json" => Dict{String, Any}(
                "path" => "verify_outputs/06_spin1_sma_spinmix_summary.json",
            ),
        )],
    )],
)
