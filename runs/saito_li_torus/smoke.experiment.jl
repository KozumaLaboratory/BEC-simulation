# Smoke test for runs/saito_li_torus/config.experiment.jl (issue #336).
#
# Same code path as production — free-space potential, azimuthal spin-coherent
# seed, DDI, scalar LHY, L-BFGS — at 32³ with a handful of iterations. This
# config had never been executed, so the first failure is wiring, not physics.
# Physics numbers from this file mean nothing; it is a wiring check only.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => 0,
            ),
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(),
            "grid" => Dict{String, Any}(
                "box" => [6, 6, 6],
                "n" => [32, 32, 32],
            ),
            "init_state_params" => Dict{String, Any}(
                "init_phi" => 1.5707963267948966,
                "init_theta" => 1.5707963267948966,
                "init_vortex_charge" => 1,
            ),
            "initial_state" => "spin_coherent",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 15000,
                "c1_ratio" => 0.0,
                "c_total" => 584.37,
                "omega_ref" => 691.15,
            ),
            "lhy" => Dict{String, Any}(
                "c_lhy" => 276.28,
                "kind" => "scalar",
            ),
            "method" => "lbfgs",
            "n_steps" => 25,
            "potential" => Dict{String, Any}(
                "type" => "none",
            ),
            "tol" => 1.0e-9,
        ),
    )],
)
