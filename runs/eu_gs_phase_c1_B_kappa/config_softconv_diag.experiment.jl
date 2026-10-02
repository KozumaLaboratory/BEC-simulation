# DIAGNOSTIC: why does the mid-field cell (B=48µG κ=1.6) floor at |∇E|~1?
# Test whether a CLEAN single-domain seed (m∓F) + Newton-CG polish escapes the
# m=±6 frustrated domain-wall stall that pin/LBFGS get stuck in. 48³ local.

Dict{String, Any}(
    "dealias" => Dict{String, Any}(
        "auto_dt" => true,
        "dt_safety" => 10.0,
        "enabled" => true,
        "k_cut" => 8.0,
    ),
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "4.8e-5 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.002,
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 12.0],
                "n" => [48, 48, 48],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.0277777778,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "method" => "itp",
            "n_steps" => 8000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.6],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "m_lbfgs" => 20,
            "method" => "lbfgs",
            "n_steps" => 2000,
            "newton_polish" => true,
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify_distance" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        )],
    )],
    "scan" => Dict{String, Any}(
        "comparison_runs" => [Dict{String, Any}(
            "name" => "mminusF",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "m_minus_F",
            ),
        ), Dict{String, Any}(
            "name" => "mplusF",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "m_plus_F",
            ),
        ), Dict{String, Any}(
            "name" => "polar",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
            ),
        )],
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
