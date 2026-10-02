# Canonical 1/N TWA-validity test: N=10000 with c_total / c_dd PINNED
# at the Eu-151 N=10⁴ baseline (the auto-derived natural value, so this
# config is effectively identical to the original `runs/twa_N_scan/N10000.experiment.jl`
# but written explicitly for symmetry across the pinned-coupling 3-run set).

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "omega_ref" => 691.15,
        ),
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_edh_phys_pinned" => Dict{String, Any}(
            "atom" => "Eu151",
            "grid" => Dict{String, Any}(
                "box" => [20, 20, 20],
                "n" => [32, 32, 32],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 10000,
                "c1_ratio" => 0.0,
                "c_total" => 937.453,
                "omega_ref" => 691.15,
            ),
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.182],
                "type" => "harmonic",
            ),
        ),
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.01 Gauss",
            ),
            "ddi" => Dict{String, Any}(
                "c_dd" => 42.204,
            ),
            "dt" => 0.005,
            "initial_state" => "m_plus_F",
            "lhy" => Dict{String, Any}(
                "kind" => "scalar",
            ),
            "n_steps" => 3000,
            "tol" => 1.0e-9,
            "use" => ["eu151_edh_phys_pinned"],
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 0.14,
                    "from" => 0.01,
                    "to" => 2.6e-5,
                ),
            ),
            "dt" => 0.0005,
            "duration" => 0.14,
            "save" => Dict{String, Any}(
                "every" => 280,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "2.6e-5 Gauss",
            ),
            "dt" => 0.0001,
            "duration" => 1.0,
            "twa" => Dict{String, Any}(
                "cutoff_energy" => 6.0,
                "n_trajectories" => 50,
                "observables" => ["density", "magnetization", "component_density"],
                "seed_base" => 42,
            ),
        ),
    )],
)
