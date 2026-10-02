# RECONSTRUCTION of the Ch.5 §5.2 five-mode LHY ablation, 2026-07-31.
#
# NOT a reproduction. `runs/lhy_mode_ablation/` has never existed in any commit,
# and §5.2.2 states only four parameters (Eu F=6, a_s = 110 a_B, N = 1e4,
# 32³ box=10). A collapse claim also needs the trap, c1, the field and the DDI
# treatment. Those are taken from the sibling report this section cites,
# docs/research_notes/eu_collapse_lhy_insufficient.md — same physical system,
# same species, same N — and are ASSUMPTIONS, not recovered values:
#
#   trap  omega = (1.0, 1.0, 1.182)      sibling line 71
#   Bz    0.01 G                          sibling line 74 (its GS phase)
#   c1_ratio -0.005                       the Eu convention these suites use
#   ddi   secular: false                  full MDDI, as the collapse claim needs
#
# One stated parameter is inconsistent with that sibling and is NOT silently
# resolved: §5.2.2 says box=10, the sibling says box=[20,20,20]. box=20 is used
# here because a 1-voxel filament at box=10 on 32³ is a different resolution
# claim; a box=10 arm should be run before quoting either.
#
# §5.2 is an ITP / ground-state ablation. The sibling is post-quench dynamics.
# The 2026-07-29 re-derivation covered the sibling, so it does NOT answer §5.2.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
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
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "grid" => Dict{String, Any}(
                "box" => [20.0, 20.0, 20.0],
                "n" => [32, 32, 32],
            ),
            "init_sigma" => 1.5,
            "initial_state" => "m_minus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 10000,
                "c1_ratio" => -0.005,
                "omega_ref" => 691.15,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "full_bdg",
            ),
            "n_steps" => 3000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.182],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        )],
    )],
)
