# L2 — DDI axis flip: B along x (companion to L2_ddi_axis_flip_Bz reference)
# Anko's validation ladder Level 2: DDI kernel convention check via axis sensitivity.
#
# Reference frame for spin-polarized DDI:
#   B along z → cloud stretches along z (head-to-tail attractive) if prolate-compatible
#   B along x → cloud should stretch along x (DDI kernel must transform consistently)
# If both axes give identical density evolution, DDI kernel is direction-blind (BUG).
# If B-axis flip rotates the response, kernel transforms correctly.
#
# Companion: L2_ddi_axis_flip_Bz uses the existing 08_ddi_spherical_polarized_zero_kernel
# (B=0 baseline). This file sets Bz=0 and θ=π/2 (B along x), keeping all else identical.
#
# Pass criteria (anko ladder Level 2):
#   - DDI energy decomposition (analyze/energy_decomposition) reports E_ddi non-zero
#   - density anisotropy aligns with B direction (qualitative; quantitative via post-hoc moments)
#   - rotating B axis 90° rotates the elongation 90°
#   - phase remains FM (m=+F or m=-F)

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bx" => "0.1 Gauss",
            ),
            "atom" => "Cr52",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "gauge_fix" => false,
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 12.0],
                "n" => [32, 32, 32],
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
            "n_steps" => 2500,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
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
                "path" => "runs/verification_suite/outputs/L2_ddi_axis_flip_Bx.json",
            ),
        )],
    )],
)
