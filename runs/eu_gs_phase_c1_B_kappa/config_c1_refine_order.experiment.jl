# ─────────────────────────────────────────────────────────────────────
#  Transition-ORDER refinement across the FM↔polar band, Eu F=6.
#
#  The honest raw map left one thing unresolved: is the FM→polar drop at
#  c1~+0.025-0.035 a FIRST-ORDER jump (discontinuous mF, bistable) or a
#  CONTINUOUS crossover? Coarse Δc1=0.006 could not tell. Here: fine
#  c1 line-scans at fixed κ ∈ {0.5,1,1.5}, for B ∈ {0,60µG}.
#
#  Method for an ORDER diagnosis (NOT a pinned soft-manifold GS):
#   • NO pin — we want the BARE two-seed competition. m_plus_F (FM branch)
#     and polar (polar branch) each relax to their nearest stationary state;
#     if they stay DISTINCT with an energy crossing E_FM=E_polar ⇒ first-order
#     + coexistence. If a single branch carries mF smoothly through ⇒ continuous.
#   • tol 1e-9 + newton_polish so each branch is genuinely converged (the honest
#     map showed a high-grad tail exactly in this band).
#
#  16 (c1) × 3 (κ) × 2 (B) = 96 points × 2 seeds. Grid/box match production.
# ─────────────────────────────────────────────────────────────────────

Dict{String, Any}(
    "dealias" => Dict{String, Any}(
        "auto_dt" => true,
        "dt_safety" => 10.0,
        "enabled" => true,
        "k_cut" => 5.0,
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
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 24.0],
                "n" => [32, 32, 64],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.03,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "m_lbfgs" => 20,
            "method" => "lbfgs",
            "n_steps" => 1500,
            "newton_polish" => true,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify_distance" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "majorana_order" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        )],
    )],
    "scan" => Dict{String, Any}(
        "comparison_runs" => [Dict{String, Any}(
            "name" => "stretched",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "m_plus_F",
            ),
        ), Dict{String, Any}(
            "name" => "polar",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
            ),
        )],
        "product" => Dict{String, Any}(
            "pipeline.0.B.Bz" => ["0.0 Gauss", "6.0e-5 Gauss"],
            "pipeline.0.interactions.c1_ratio" => Dict{String, Any}(
                "from" => 0.015,
                "n" => 16,
                "to" => 0.045,
            ),
            "pipeline.0.potential.omega.2" => [0.5, 1.0, 1.5],
        ),
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
