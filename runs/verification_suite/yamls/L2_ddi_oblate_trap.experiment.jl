# L2 — DDI in oblate trap (pancake, B along symmetry axis = z)
# Companion to L2_ddi_prolate_trap.experiment.jl.
# Oblate trap (ωz large, ωx=ωy small) creates pancake in x-y.
# With B along z (out-of-plane), dipoles are perpendicular to pancake →
# side-by-side configuration → REPULSIVE in plane → GS energy higher than DDI off.
# This is the standard DDI anisotropy test.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.1 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "atom" => "Cr52",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "gauge_fix" => false,
            "grid" => Dict{String, Any}(
                "box" => [16.0, 16.0, 8.0],
                "n" => [48, 48, 24],
            ),
            "init_sigma" => 1.5,
            "initial_state" => "m_minus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 10000,
                "omega_ref" => 628.3,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "n_steps" => 3000,
            "potential" => Dict{String, Any}(
                "omega" => [0.5, 0.5, 2.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "summary_json" => Dict{String, Any}(
                "path" => "runs/verification_suite/outputs/L2_ddi_oblate_trap.json",
            ),
        )],
    )],
)
