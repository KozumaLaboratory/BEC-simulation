# Step 5 — Eu151 Hamiltonian-only EdH sanity probe.
#
# Per 2026-05-25 next_session_priorities.md Step 5:
#   loss off, LHY off, DDI on, EdH short-time
#   Sanity before adding K3 / LHY layers.
#
# Stripped down from runs/verification_suite/yamls/L4_eu_matsui_hamiltonian_only_32.experiment.jl:
#   - Grid 32³ → 24³ (faster CPU smoke; convergence happens at L4_*_64)
#   - n_steps ITP 1500 → 400 (sanity, NOT GS convergence demo)
#   - dynamics duration 6.28 → 0.5 (short-time only, no Townes-collapse risk)
#   - backend: gpu → cpu (CI-friendly)
#
# Pass = norm conserved < 1e-6, energy stable, ⟨F_z⟩+⟨L_z⟩ drift small at short time.
# NO loss block — Hamiltonian-only

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
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
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "gauge_fix" => false,
            "grid" => Dict{String, Any}(
                "box" => [10.0, 10.0, 10.0],
                "n" => [24, 24, 24],
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
            "n_steps" => 400,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-7,
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
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 0.5,
            "save" => Dict{String, Any}(
                "every" => 10,
                "precision" => "f64",
                "psi" => true,
            ),
            "seed_amplitude" => 1.0e-6,
            "seed_k_cut" => 2.5,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "winding_map" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "summary_json" => Dict{String, Any}(
                "path" => "runs/step5_eu_hamiltonian_only_sanity/summary.json",
            ),
        )],
    )],
)
