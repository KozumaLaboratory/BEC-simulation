# Static-trap ω_eff scan @ canonical EdH protocol (hold_only, delay=2 ms,
# B_hold = 10.4 nT, m=+F).  ω_⊥,eff / ω_⊥ = 0.750
# Source: scripts/validation/klaus_weff_scan_gen.jl
#
# anti-aligned-seed: the EdH cascade only runs from the Zeeman-HIGHEST stretched
#   state. Measured 2026-08-19 (#343): rotation contrast +16.5 % anti-aligned
#   against -0.45 % aligned. Authority:
#   docs/campaign/edh_quench_polarisation_decision.md
#
# NO ROTATION ANYWHERE. The enhancement is centrifugal, not Coriolis (§9.3): a
#   static radial trap at ω_eff reproduces the rotating result to 0.06 % across
#   the range. `rotating_frame_omega` is 0.0 in every step; the hold step
#   overrides `potential:` instead.
#
# Built-in control: at ω_eff = 1.000 this must return the unweakened baseline.
#   If the per-step `potential:` override were silently ignored, EVERY arm would
#   return that same value — so a flat scan is a plumbing failure, not a null.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 10000,
            "omega_ref" => 691.1504,
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
                "secular" => true,
            ),
            "dt" => 0.005,
            "gauge_fix" => false,
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 12.0],
                "n" => [32, 32, 32],
            ),
            "init_sigma" => 1.5,
            "initial_state" => "m_plus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 10000,
                "c1_ratio" => 0.02778,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "n_steps" => 3000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.181818],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.01 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 6.9115,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "rotating_frame_omega" => 0.0,
            "save" => Dict{String, Any}(
                "every" => 100,
                "precision" => "f64",
                "psi" => true,
            ),
            "seed_amplitude" => 1.0e-6,
            "seed_k_cut" => 2.5,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 0.6911504,
                    "from" => 0.01,
                    "to" => 0.00010400000000000001,
                ),
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.001,
            "duration" => 0.69115,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "rotating_frame_omega" => 0.0,
            "save" => Dict{String, Any}(
                "every" => 50,
                "precision" => "f64",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.00010400000000000001 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 1.3823,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "rotating_frame_omega" => 0.0,
            "save" => Dict{String, Any}(
                "every" => 50,
                "precision" => "f64",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.00010400000000000001 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 5.5292,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "potential" => Dict{String, Any}(
                "omega" => [0.75, 0.75, 1.181818],
                "type" => "harmonic",
            ),
            "rotating_frame_omega" => 0.0,
            "save" => Dict{String, Any}(
                "every" => 100,
                "precision" => "f64",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "winding_map" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        )],
    )],
)
