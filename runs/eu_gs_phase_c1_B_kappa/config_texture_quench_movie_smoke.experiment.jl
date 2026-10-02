# Smoke for config_texture_quench_movie.experiment.jl — every path the real movie run
# takes (full_bdg LHY, DDI, the quench dynamics, the movie analyzer, the JLD2
# archive the renderer reads) on a coarse grid in a couple of minutes. Useless
# as physics; the point is that the chain runs to an mp4.

Dict{String, Any}(
    "dealias" => Dict{String, Any}(
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
                "n" => [16, 16, 32],
            ),
            "initial_state" => "flower",
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
            "n_steps" => 40,
            "newton_polish" => false,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 0.0001,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "2.0e-5 Gauss",
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.001,
            "duration" => 0.3,
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "full_bdg",
            ),
            "save" => Dict{String, Any}(
                "every" => 10,
            ),
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "vortex_density_movie" => Dict{String, Any}(
                "axis" => 3,
                "output_dir" => "figs/eu_quench_movie_smoke",
            ),
        )],
    )],
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
