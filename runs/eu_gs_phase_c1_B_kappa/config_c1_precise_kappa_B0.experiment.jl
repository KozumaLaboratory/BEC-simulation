# Precision c1*(κ) map of the FIRST-ORDER FM->polar line at B=0, to see whether the
# transition character strengthens (oblate) or softens toward continuous (prolate)
# with trap geometry — connecting the c1-driven line to the B-driven tricritical arc
# (project_eu_coreless_vortex_demag_bc). κ=1 is already pinned (c1*≈0.028, first-order
# via config_c1_precise_B0k1). Here κ ∈ {0.5, 1.5} at the same 0.0005 c1 step. The c1
# window [0.023,0.031] brackets BOTH refine-grid collapses (κ=0.5 in (0.025,0.027);
# κ=1.5 in (0.027,0.029)). Two bare seeds (m_plus_F FM vs polar), no pin; newton_polish
# + tol 1e-9 + extra ITP steps for the soft near-spinodal FM branch. Grid/box match the
# refine + κ=1 precise runs. 17 c1 × 2 κ = 34 tasks × 2 seeds.

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
                "c1_ratio" => 0.028,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "m_lbfgs" => 20,
            "method" => "lbfgs",
            "n_steps" => 2500,
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
            "pipeline.0.interactions.c1_ratio" => Dict{String, Any}(
                "from" => 0.023,
                "n" => 17,
                "to" => 0.031,
            ),
            "pipeline.0.potential.omega.2" => [0.5, 1.5],
        ),
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
