# R33 MFBO Eu phase scan — Phase 2 measurement
#
# Target: validate the 2.4-3.1× synthetic MFBO speedup on real Eu
# physics. Two-tier MFBO over (c_1_ratio, c_dd_ratio) at fixed
# (B_field, trap, atom = Eu151) — minimise total energy as the
# objective.
#
# Run pair (set externally via `multi_fidelity_optimize_config`):
#   eval_low  : grid 16³, n_steps 500   (~ 1-2 min/eval)
#   eval_high : grid 32³, n_steps 4000  (~ 30 min/eval)
#   cost_ratio (expected): 30-60
#
# This config is the BASELINE that the MFBO wrapper modifies via
# `low_overrides` and `high_overrides`. The wrapper script
# (TSUBAME job) will issue
#
#   res = multi_fidelity_optimize_config(
#       "runs/measurement_R3x_eu/r33_mfbo_eu_phase/config.experiment.jl",
#       ["pipeline.0.ground_state.interactions.c1_ratio",
#        "pipeline.0.ground_state.ddi.c_dd_ratio"],
#       [(-0.05, 0.05), (0.5, 1.5)];
#       objective_fn = bo_objective_min_energy,
#       low_overrides  = Dict(
#           "pipeline.0.ground_state.grid.n"  => [16, 16, 16],
#           "pipeline.0.ground_state.n_steps" => 500,
#       ),
#       high_overrides = Dict(),    # use config-default high tier
#       cost_ratio = 30.0,
#       n_init_low = 12, n_init_high = 3,
#       n_iter = 25, budget_high = 8,
#       minimise = true,
#       save_history_to = "runs/measurement_R3x_eu/r33_mfbo_eu_phase/history.jld2",
#   )

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_thesis" => Dict{String, Any}(
            "N_atoms" => 30000,
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "c_dd_ratio" => 1.0,
                "enabled" => true,
            ),
            "grid" => Dict{String, Any}(
                "box" => [20, 20, 20],
                "n" => [32, 32, 32],
            ),
            "initial_state" => "m_plus_F",
            "interactions" => Dict{String, Any}(
                "c1_ratio" => 0.0,
            ),
            "m_lbfgs" => 10,
            "method" => "lbfgs",
            "n_steps" => 4000,
            "omega_ref" => 691.15,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.182],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "1.0 Gauss",
            ),
            "sobolev_alpha" => 0.0,
            "use" => ["eu151_thesis"],
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "bogoliubov" => Dict{String, Any}(
                "k_max" => 8.0,
                "n_k" => 32,
            ),
        ), Dict{String, Any}(
            "summary_json" => Dict{String, Any}(
                "path" => "summary.json",
            ),
        )],
    )],
)
