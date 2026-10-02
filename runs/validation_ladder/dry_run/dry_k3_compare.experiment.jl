# [run_experiment] starting run_experiment: runs/eu151_edh_k3_compare/config.experiment.jl
# [run_experiment] loading config: runs/eu151_edh_k3_compare/config.experiment.jl
# [run_experiment] checking required top-level keys
# [run_experiment] expanding templates and mixins
# [run_experiment] injecting schema defaults
# [run_experiment] applying units block
# [run_experiment] applying accuracy and auto-grid defaults
# [run_experiment] normalizing B blocks
# [run_experiment] normalizing noise blocks
# [run_experiment] validating schema
# [run_experiment] pipeline: 3 step(s): ground_state -> dynamics -> dynamics
# [run_experiment] dry-run complete; printing normalized YAML
# === run_experiment dry-run (post calibration + units + validation) ===
# original: runs/eu151_edh_k3_compare/config.experiment.jl
#
# Stages applied:
#   1. calibration:  lab-control values → physical units
#   2. units:        bare Reals → unit-bearing strings
#   3. schema:       unknown-key + range + enum validation
#
# Numerics defaults (dt, save_every, n_steps) are still expressed
# in their YAML form here; final resolved values are logged when
# the actual run starts. To inspect resolved values without running,
# use a 1-step ground_state with verbose=true.
#
# Scan comparison preview:
#   comparison_runs: 2
#   - baseline_no_K3: 0 override(s)
#       effective pipeline.2.loss = Dict{Any, Any}("gamma_dr" => 0.02)
#   - K3_dy_like: 1 override(s)
#       pipeline.2.loss.K3_per_m_si = ["1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 ...
#       effective pipeline.2.loss = Dict{Any, Any}("K3_per_m_si" => ["1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^...
#

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 10000,
            "omega_ref" => 691.15,
        ),
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.01 Gauss",
            ),
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(),
            "dt" => 0.005,
            "grid" => Dict{String, Any}(
                "box" => [20, 20, 20],
                "n" => [32, 32, 32],
            ),
            "initial_state" => "m_plus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 10000,
                "c1_ratio" => 0.0,
                "omega_ref" => 691.15,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "scalar",
            ),
            "n_steps" => 3000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.182],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
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
            "duration" => 0.3,
            "loss" => Dict{String, Any}(
                "gamma_dr" => 0.02,
            ),
            "noise_seed" => 42,
            "save" => Dict{String, Any}(
                "every" => 200,
            ),
            "seed_amplitude" => 1.0e-6,
            "seed_k_cut" => 2.5,
        ),
    )],
    "scan" => Dict{String, Any}(
        "comparison_runs" => [Dict{String, Any}(
            "name" => "baseline_no_K3",
            "override" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "name" => "K3_dy_like",
            "override" => Dict{String, Any}(
                "pipeline.2.loss.K3_per_m_si" => ["1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s"],
            ),
        )],
    ),
)
