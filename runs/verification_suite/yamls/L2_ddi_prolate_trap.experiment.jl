# L2 — DDI in prolate trap (cigar along z, B along z)
# Anko's validation ladder Level 2: DDI is attractive head-to-tail.
# Prolate trap (ωz small, ωx=ωy large) creates cigar along z.
# With B along z, spin polarized along z aligns dipoles head-to-tail
# inside the cigar → attractive → should be MORE BOUND than DDI-off case.
# Oblate version (pancake) gets repulsive in-plane → LESS BOUND.
#
# Pass criteria (anko ladder Level 2):
#   - Prolate + DDI on: ground state energy lower than DDI off
#   - Oblate variant (companion file): GS energy higher than DDI off
#   - The sign of (E_ddi_on - E_ddi_off) flips with trap aspect ratio
# Run this together with L2_ddi_oblate_trap.experiment.jl and L2_ddi_spherical_baseline.experiment.jl.

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
                "box" => [8.0, 8.0, 16.0],
                "n" => [24, 24, 48],
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
                "omega" => [2.0, 2.0, 0.5],
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
                "path" => "runs/verification_suite/outputs/L2_ddi_prolate_trap.json",
            ),
        )],
    )],
)
