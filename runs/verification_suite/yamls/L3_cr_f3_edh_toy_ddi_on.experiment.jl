# L3 — Cr-52 F=3 EdH toy (DDI on, no loss, no LHY)
# Anko's validation ladder (2026-05-22) Level 3: Kawaguchi & Ueda canonical EdH.
# Initial m=-F spin-polarized BEC under DDI in weak Bz should transfer spin
# angular momentum to orbital angular momentum (EdH), with each component
#   ψ_m(r,φ,z) = e^{i (Jz - m) φ} η_m(r,z)
# so m=-F+1 grows with winding ℓ=1, m=-F+2 with ℓ=2, etc.
# Total angular momentum Jz = Lz + Fz is exactly conserved (closed system).
#
# This is BEFORE Eu Hamiltonian-only — Cr is the canonical EdH textbook system
# with known a_s and DDI strength, no LHY/loss complications, no unknown
# scattering channels.
#
# Companion: L3_cr_f3_edh_toy_ddi_off.experiment.jl (control; DDI off should kill the EdH signature).
#
# Pass criteria (anko ladder, Level 3):
#   - Fz(t) decreases monotonically from -F
#   - Lz(t) increases (mirror image of Fz drop)
#   - Jz(t) = Fz + Lz conserved to ~1e-6 absolute
#   - m=-F+1 component winding ℓ ≈ 1 from ∮ ∇ arg(ψ_{m=-F+1}) · dℓ / (2π)
#   - m=-F+2 component winding ℓ ≈ 2 (if populated)
#   - DDI off (companion YAML) shows none of the above

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
                "secular" => false,
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
                "path" => "runs/verification_suite/outputs/L3_cr_f3_edh_toy_ddi_on.json",
            ),
        )],
    )],
)
