# 08 — DDI kernel convention benchmark
# Physics: a spherical spin-polarized cloud has near-zero net dipolar mean-field energy
# because Q_ab is traceless. This catches sign, 4π, k=0, and axis convention mistakes.
# Expected: DDI energy small and converges toward zero with larger n/box.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 2.0,
                "q" => 0.0,
            ),
            "atom" => "Cr52",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
            ),
            "dt" => 0.003,
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 12.0],
                "n" => [32, 32, 32],
            ),
            "initial_state" => "m_plus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 2000,
                "c1_ratio" => 0.0,
                "omega_ref" => 628.319,
            ),
            "method" => "itp",
            "n_steps" => 3500,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-8,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "summary_json" => Dict{String, Any}(
                "path" => "verify_outputs/08_ddi_spherical_summary.json",
            ),
        )],
    )],
)
