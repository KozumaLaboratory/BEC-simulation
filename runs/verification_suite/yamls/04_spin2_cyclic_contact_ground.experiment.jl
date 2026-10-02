# 04 — Spin-2 cyclic contact benchmark
# Physics: F=2 mean-field energy contains c1|F|^2 and c2|A00|^2.
# For c1>0 and c2>0, the cyclic state minimizes both spin and singlet-pair amplitudes.
# Expected: phase_classify -> cyclic-like; spin_order ~ 0; singlet-pair amplitude ~ 0 if reported.
# YAML parser accepts sparse tensor keys c2, c4, ...; here c2 is the singlet-pair coupling.

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
            "atom" => "Rb85",
            "ddi" => Dict{String, Any}(
                "enabled" => false,
            ),
            "dt" => 0.003,
            "grid" => Dict{String, Any}(
                "box" => [10.0, 10.0, 10.0],
                "n" => [24, 24, 24],
            ),
            "initial_state" => "cyclic",
            "interactions" => Dict{String, Any}(
                "c0" => 100.0,
                "c1" => 2.0,
                "c2" => 2.0,
            ),
            "method" => "itp",
            "n_steps" => 5000,
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
            "majorana_order" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "summary_json" => Dict{String, Any}(
                "path" => "verify_outputs/04_spin2_cyclic_summary.json",
            ),
        )],
    )],
)
