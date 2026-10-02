# FINALIZE the mid-field soft/frustrated region with the confirmed convergence
# recipe: ITP → LBFGS → newton_polish (Newton-CG escapes the high-E metastable
# traps LBFGS+pin get stuck in; reaches |∇E|~2e-7). pin is the weak-field tool
# and does nothing here, so it is OFF. 3 seeds (canted-FM / polar / flower)
# compete; min-E = GS. Gate the ordering on the saved grad_norm, NOT conv (which
# false-negatives at |∇E|~2e-7).
#   5 (Bz) × 4 (κ) = 20 points × 3 seeds = 60 solves @ 64³.

Dict{String, Any}(
    "dealias" => Dict{String, Any}(
        "auto_dt" => true,
        "dt_safety" => 10.0,
        "enabled" => true,
        "k_cut" => 10.0,
    ),
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.0 Gauss",
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
                "n" => [64, 64, 64],
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
            "n_steps" => 6000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
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
            "tol" => 1.0e-10,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify_distance" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "multipole_order" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "majorana_order" => Dict{String, Any}(),
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
            "name" => "polar",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
            ),
        ), Dict{String, Any}(
            "name" => "flower",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "flower",
            ),
        )],
        "product" => Dict{String, Any}(
            "pipeline.0.B.Bz" => ["2.5e-5 Gauss", "4.0e-5 Gauss", "4.8e-5 Gauss", "5.5e-5 Gauss", "6.2e-5 Gauss"],
            "pipeline.0.potential.omega.2" => [1.3, 1.6, 1.9, 2.2],
        ),
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
