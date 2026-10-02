# phi_omega scan — single-file form. Klaus magnetostir on Eu151 with
# stir frequency varied 1.0 → 18.0 dimless (= 50 → 900 Hz at ω_ref =
# 2π·50 Hz). The phase-2 spinup endpoint slaves to the steady value via
# the zip scan with two coupled axes.
# tilt: 0 → 35° over 20 ms
# spinup: 0 → stir freq over 50 ms
# steady stir 500 ms — scan target
# 8-point scan over stir frequency. The chirp endpoint slaves so the
# spinup ramps to the steady value (zip — both axes vary together).

Dict{String, Any}(
    "accuracy" => 1.0e-6,
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "rotating_basis",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_klaus_phys" => Dict{String, Any}(
            "N_atoms" => 60000,
            "atom" => "Eu151",
            "dt" => 0.005,
            "gauge_fix" => false,
            "grid" => Dict{String, Any}(
                "box" => [20.0, 20.0, 10.0],
                "n" => [24, 24, 12],
            ),
            "init_m_idx" => 1,
            "init_sigma" => 1.5,
            "n_steps" => 250,
            "omega_ref" => 314.159,
            "potential" => Dict{String, Any}(
                "omega" => ["50 Hz", "50 Hz", "130 Hz"],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-7,
        ),
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.819 Gauss",
            ),
            "interactions" => Dict{String, Any}(
                "c1" => 0.0,
            ),
            "use" => ["eu151_klaus_phys"],
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "phi" => Dict{String, Any}(
                    "rate" => 0.0,
                ),
                "theta" => Dict{String, Any}(
                    "duration" => "20 ms",
                    "from" => 0.0,
                    "to" => 0.611,
                ),
            ),
            "duration" => "20 ms",
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "phi" => Dict{String, Any}(
                    "rate" => Dict{String, Any}(
                        "duration" => "50 ms",
                        "from" => 0.0,
                        "to" => 4.524,
                    ),
                ),
                "theta" => 0.611,
            ),
            "duration" => "50 ms",
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "phi" => Dict{String, Any}(
                    "rate" => 4.524,
                ),
                "theta" => 0.611,
            ),
            "duration" => "500 ms",
        ),
    )],
    "scan" => Dict{String, Any}(
        "zip" => Dict{String, Any}(
            "pipeline.2.dynamics.B.phi.rate.to" => [1.0, 2.0, 3.0, 4.524, 6.0, 8.0, 12.0, 18.0],
            "pipeline.3.dynamics.B.phi.rate" => [1.0, 2.0, 3.0, 4.524, 6.0, 8.0, 12.0, 18.0],
        ),
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
        "t" => "ms",
    ),
)
