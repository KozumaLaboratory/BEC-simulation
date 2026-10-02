# L3 — Cr-52 F=3 EdH toy (DDI OFF — control)
# Companion to L3_cr_f3_edh_toy_ddi_on.experiment.jl. DDI is the only mechanism
# for spin-to-orbital angular momentum transfer in this setup; with DDI off,
# m=-F population should stay ~1 and Lz(t) should stay ~0.
#
# Pass criteria (anko ladder, Level 3, DDI-OFF control):
#   - Fz(t) ≈ -F constant (no transfer)
#   - Lz(t) ≈ 0 constant
#   - m=-F population stays ≈ 1
#   - No winding develops in any component
# If DDI-off run STILL shows EdH-like behavior, the mechanism is misidentified
# (e.g., contact-c1 spin mixing alone is producing the transfer).

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 10000,
            "omega_ref" => 628.3,
        ),
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => 0.0,
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "atom" => "Cr52",
            "ddi" => Dict{String, Any}(
                "enabled" => false,
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
            "n_steps" => 2000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => 0.0,
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => false,
            ),
            "dt" => 0.005,
            "duration" => 8.0,
            "save" => Dict{String, Any}(
                "every" => 50,
                "precision" => "f64",
                "psi" => true,
            ),
            "seed_amplitude" => 1.0e-6,
            "seed_k_cut" => 2.5,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "winding_map" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "summary_json" => Dict{String, Any}(
                "path" => "runs/verification_suite/outputs/L3_cr_f3_edh_toy_ddi_off.json",
            ),
        )],
    )],
)
