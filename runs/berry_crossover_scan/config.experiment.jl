# berry_crossover scan — single-file form. Eu151 spinor-orbital crossover
# scan over B-field strength (dimless p). p = 10 → 3000: spinor-active
# (p=10) → Klaus-frozen (p≥100).
#
# `units:` block below is for *future* lab-unit fields (B in Gauss,
# durations in ms — the schema applies these to quantity-string entries
# like `omega: ["50 Hz", ...]` and `duration: "20 ms"`). The bare-Real
# `B: {p: 1000.0}` here is the dimensionless Zeeman energy
# `p = ω_L / ω_ref`, not Gauss; the unit declaration is therefore
# unused for `B.p` in this file. Both forms coexist by design — see
# CLAUDE.md "YAML schema overhaul".

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
                "p" => 1000.0,
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
            "pipeline.0.ground_state.B.p" => [10.0, 30.0, 100.0, 300.0, 1000.0, 3000.0],
        ),
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
        "t" => "ms",
    ),
)
