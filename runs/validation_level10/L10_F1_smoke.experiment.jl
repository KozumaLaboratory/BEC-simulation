# Level 10 smoke test: tiny F=1 polar ground state, exports
# operator_rhs.jld2 for round-trip verification of the export tool.
#
# Physical setup: Rb87, harmonic trap, c1>0 polar phase, 8³ grid, 50 ITP
# steps. Designed to converge in seconds on CPU; not a physics result —
# just a smoke test for the export pipeline.

Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => 0.0,
                "q" => 0.0,
            ),
            "atom" => "Rb87",
            "ddi" => Dict{String, Any}(
                "enabled" => false,
            ),
            "dt" => 0.01,
            "grid" => Dict{String, Any}(
                "box" => [4.0, 4.0, 4.0],
                "n" => [8, 8, 8],
            ),
            "init_sigma" => 1.0,
            "initial_state" => "polar",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 1000,
                "c1_ratio" => 0.01,
                "omega_ref" => 1.0,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "n_steps" => 50,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-6,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "hpsi_export" => Dict{String, Any}(),
        )],
    )],
)
