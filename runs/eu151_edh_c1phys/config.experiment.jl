# Eu151 Einstein-de Haas (EdH) — c1 = physical 0.003 ratio variant.
#
# Derived from runs/eu151_edh/config.experiment.jl. Only difference: c1_ratio
# 0.0 → 0.003 (= natural-estimate spin-mixing / contact ratio for Eu151;
# the 7 unknown scattering channels per CLAUDE.md "¹⁵¹Eu" leave c1 in
# the 1e-3 range as practical estimate. The 0.028 in
# `eu151_lab_calibrated/config.experiment.jl` was an exploratory upper-bound).
#
# With c1 ≠ 0 the spin sector evolves under both Larmor + spin-mixing
# during the weak-field hold. Force-Gradient integrator (split_step_forcegrad!)
# is diagonal-only and won't apply; standard path uses split_step! (Strang)
# automatically. Y4-midpoint not exposed via YAML for kind: spinor.
#
# Fastest currently-runnable variant for EdH with physical c1.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "omega_ref" => 691.15,
        ),
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_edh_phys" => Dict{String, Any}(
            "atom" => "Eu151",
            "grid" => Dict{String, Any}(
                "box" => [20, 20, 20],
                "n" => [64, 64, 64],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 10000,
                "c1_ratio" => 0.003,
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
            "dt" => 0.005,
            "initial_state" => "m_plus_F",
            "lhy" => Dict{String, Any}(
                "kind" => "scalar",
            ),
            "n_steps" => 100000,
            "tol" => 1.0e-10,
            "use" => ["eu151_edh_phys"],
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
            "noise" => Dict{String, Any}(
                "initial" => Dict{String, Any}(
                    "coherent" => Dict{String, Any}(
                        "amplitude" => 1.0e-6,
                        "k_cut" => 2.5,
                    ),
                ),
                "seed" => 42,
            ),
            "save" => Dict{String, Any}(
                "every" => 200,
            ),
        ),
    )],
)
