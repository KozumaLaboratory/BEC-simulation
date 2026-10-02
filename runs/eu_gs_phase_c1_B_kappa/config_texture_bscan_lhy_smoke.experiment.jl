# Smoke for config_texture_bscan_lhy_full_bdg.experiment.jl: every code path the real run
# takes — full_bdg LHY table build, DDI, all five seeds, the analyzer — on a
# coarse grid with few iterations. Cheap enough to run before a launch, useless
# as physics. CPU success does not imply GPU works, so run this on the backend
# the real job will use.

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
                "Bz" => "5.0e-5 Gauss",
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
                "n" => [16, 16, 32],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.0,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "full_bdg",
            ),
            "m_lbfgs" => 20,
            "method" => "lbfgs",
            "n_steps" => 20,
            "newton_polish" => false,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 0.0001,
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
            "pipeline.0.B.Bz" => ["5.0e-5 Gauss"],
            "pipeline.0.interactions.c1_ratio" => [0.0],
        ),
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
