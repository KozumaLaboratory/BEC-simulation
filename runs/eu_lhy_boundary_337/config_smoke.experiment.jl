# SMOKE for the #337 criterion-B measurement. One field, two competing seeds,
# every LHY arm — enough to prove each arm BUILDS, RUNS and CHANGES the energy,
# and to time one cell, in a couple of minutes. It answers nothing physical: the
# step count is far below convergence on purpose.
#
# Geometry and knobs are copied from config_texture_bscan.experiment.jl so that the arms
# differ from the campaign in the LHY block and nothing else.

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
                "Bz" => "4.4e-5 Gauss",
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
                "c1_ratio" => 0.0277777778,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "m_lbfgs" => 20,
            "method" => "lbfgs",
            "n_steps" => 120,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-8,
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
            "name" => "fm_none",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "m_plus_F",
            ),
        ), Dict{String, Any}(
            "name" => "polar_none",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
            ),
        ), Dict{String, Any}(
            "name" => "fm_scalar",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "m_plus_F",
                "pipeline.0.lhy" => Dict{String, Any}(
                    "kind" => "scalar",
                ),
            ),
        ), Dict{String, Any}(
            "name" => "polar_scalar",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
                "pipeline.0.lhy" => Dict{String, Any}(
                    "kind" => "scalar",
                ),
            ),
        ), Dict{String, Any}(
            "name" => "fm_fmdip",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "m_plus_F",
                "pipeline.0.lhy" => Dict{String, Any}(
                    "kind" => "fm_dipolar",
                ),
            ),
        ), Dict{String, Any}(
            "name" => "polar_polcon",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
                "pipeline.0.lhy" => Dict{String, Any}(
                    "kind" => "polar_contact",
                ),
            ),
        ), Dict{String, Any}(
            "name" => "fm_spatial",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "m_plus_F",
                "pipeline.0.lhy" => Dict{String, Any}(
                    "kind" => "spatial",
                ),
            ),
        ), Dict{String, Any}(
            "name" => "polar_spatial",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
                "pipeline.0.lhy" => Dict{String, Any}(
                    "kind" => "spatial",
                ),
            ),
        ), Dict{String, Any}(
            "name" => "fm_ctrl30",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "m_plus_F",
                "pipeline.0.lhy" => Dict{String, Any}(
                    "c_lhy" => 177564.0,
                    "kind" => "scalar",
                ),
            ),
        ), Dict{String, Any}(
            "name" => "polar_ctrl30",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
                "pipeline.0.lhy" => Dict{String, Any}(
                    "c_lhy" => 177564.0,
                    "kind" => "scalar",
                ),
            ),
        )],
        "product" => Dict{String, Any}(
            "pipeline.0.B.Bz" => ["4.4e-5 Gauss"],
        ),
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
