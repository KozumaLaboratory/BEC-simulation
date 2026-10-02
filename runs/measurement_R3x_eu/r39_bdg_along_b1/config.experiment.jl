# R39 — BdG spectrum along R35 B-1 boundary
#
# Post-process the R35 boundary trace by computing the Bogoliubov
# spectrum at each accepted point. Yields the thesis figure
# "roton softening across the B-1 boundary".
#
# Reuses the same R35 baseline GS config; bogoliubov_along_boundary_curve
# warm-starts from each previous boundary point and computes the BdG
# spectrum at the converged ψ.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_thesis_24" => Dict{String, Any}(
            "N_atoms" => 30000,
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "c_dd_ratio" => 1.0,
                "enabled" => true,
            ),
            "grid" => Dict{String, Any}(
                "box" => [16, 16, 16],
                "n" => [24, 24, 24],
            ),
            "interactions" => Dict{String, Any}(
                "c1_ratio" => 0.0,
            ),
            "m_lbfgs" => 10,
            "method" => "lbfgs",
            "n_steps" => 500,
            "omega_ref" => 691.15,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.182],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-7,
        ),
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "1.0 Gauss",
            ),
            "use" => ["eu151_thesis_24"],
        ),
    )],
)
