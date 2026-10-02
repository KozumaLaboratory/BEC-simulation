# L4 — Eu-151 Matsui Hamiltonian-only DDI OFF (control)
# Companion to L4_eu_matsui_hamiltonian_only_32.experiment.jl.
# DDI off → no spin-to-orbital transfer mechanism → EdH signature should vanish.
# If EdH-like signal appears here, the mechanism is NOT DDI (e.g., spin-mixing
# c1 + initial seed could be producing it), which would invalidate Matsui-style
# claims regardless of K3.
#
# Pass criteria (anko ladder, Level 4 DDI-off control):
#   - Fz(t) ≈ -F throughout (no transfer)
#   - Lz(t) ≈ 0 throughout (no orbital AM generated)
#   - m=-F population stays ≈ 1
#   - peak_density stable (no collapse from DDI; contact + LHY=off only)
#   - Energy decomposition: E_ddi == 0
# This is the mechanism test that PRECEDES K3 discussion.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 30000,
            "omega_ref" => 628.3,
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
                "N_atoms" => 30000,
                "c1_ratio" => -0.005,
                "omega_ref" => 628.3,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "n_steps" => 1500,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 0.0,
                    "from" => 0.01,
                    "to" => 2.6e-5,
                ),
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => false,
            ),
            "dt" => 0.01,
            "duration" => 6.28,
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
                "path" => "runs/verification_suite/outputs/L4_eu_matsui_hamiltonian_only_ddi_off_32.json",
            ),
        )],
    )],
)
