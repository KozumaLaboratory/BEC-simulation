# Pilot: competing-seed GS at B=100µG (above the ~60µG crossover) to check that
# the flower/CSV/PCV textures appear as GS and the fingerprint classifier separates
# them. FM-region c1, kappa=1. Each cell solved from 5 seeds; min-E = the phase.

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
                "Bz" => "1.0e-4 Gauss",
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
                "c1_ratio" => 0.0,
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
            "tol" => 1.0e-8,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify_distance" => Dict{String, Any}(),
        )],
    )],
    "scan" => Dict{String, Any}(
        "comparison_runs" => [Dict{String, Any}(
            "name" => "flower",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "flower",
            ),
        ), Dict{String, Any}(
            "name" => "csv",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "chiral_spin_vortex",
            ),
        ), Dict{String, Any}(
            "name" => "pcv",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar_core_vortex",
            ),
        ), Dict{String, Any}(
            "name" => "fm",
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
            "pipeline.0.interactions.c1_ratio" => [-0.012, 0.0, 0.018],
            "pipeline.0.potential.omega.2" => [1.0],
        ),
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
