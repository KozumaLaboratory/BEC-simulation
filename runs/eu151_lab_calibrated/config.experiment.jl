# ─────────────────────────────────────────────────────────────────────
#  Lab-unit calibration showcase. The user writes control-deck values
#  (mV on the coil, mW on the FORT laser) and a calibration_history
#  table; `apply_calibration!` interpolates between dated snapshots to
#  the `target_date` and rewrites the YAML into physical units before
#  the schema parser sees it.
#
#  Effect at target_date 2026-04-08 (interpolated from 04-01 + 04-15):
#     t = 7d / 14d = 0.5
#     coil_strong: gauss_per_mv 0.41, gauss_offset 0.045  (linear avg)
#     fort:        sqrt_coeffs_hz [446.5, 446.5, 598.0]   (linear avg)
#     B.p_mv: 2.5 + coil_mode: strong → B.p = 0.41 · 2.5 + 0.045 = 1.07 Gauss
#     fort_power_mw: [50, 50, 100] → omega = sqrt_coeff · sqrt(power_mw)
#                                          = [3157, 3157, 5980] Hz
#  (Earlier comment quoted 1.04 G / 3134 Hz — that's not the interpolation;
#   3134 Hz is the 04-15 endpoint alone (sqrt_coeff=443·√50), and 1.04 G
#   doesn't match either endpoint or the midpoint. Updated 2026-05-02.)
# ─────────────────────────────────────────────────────────────────────

Dict{String, Any}(
    "calibration_history" => [Dict{String, Any}(
        "coil_strong" => Dict{String, Any}(
            "gauss_offset" => 0.05,
            "gauss_per_mv" => 0.4,
        ),
        "coil_weak" => Dict{String, Any}(
            "gauss_offset" => 0.002,
            "gauss_per_mv" => 0.04,
        ),
        "date" => "2026-04-01",
        "fort" => Dict{String, Any}(
            "sqrt_coeffs_hz" => [450, 450, 600],
        ),
        "microwave" => Dict{String, Any}(
            "rad_per_s_per_mw" => 1.2e6,
        ),
    ), Dict{String, Any}(
        "coil_strong" => Dict{String, Any}(
            "gauss_offset" => 0.04,
            "gauss_per_mv" => 0.42,
        ),
        "coil_weak" => Dict{String, Any}(
            "gauss_offset" => 0.003,
            "gauss_per_mv" => 0.038,
        ),
        "date" => "2026-04-15",
        "fort" => Dict{String, Any}(
            "sqrt_coeffs_hz" => [443, 443, 596],
        ),
        "microwave" => Dict{String, Any}(
            "rad_per_s_per_mw" => 1.18e6,
        ),
    )],
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "coil_mode" => "strong",
                "p_mv" => 2.5,
            ),
            "atom" => "Eu151",
            "dt" => 0.005,
            "grid" => Dict{String, Any}(
                "box" => [12, 12, 8],
                "n" => [32, 32, 24],
            ),
            "initial_state" => "polar",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 30000,
                "c1_ratio" => 0.028,
                "omega_ref" => 691.15,
            ),
            "n_steps" => 4000,
            "potential" => Dict{String, Any}(
                "fort_power_mw" => [50, 50, 100],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-7,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "summary_json" => Dict{String, Any}(
                "path" => "summary.json",
            ),
        )],
    )],
    "target_date" => "2026-04-08",
)
