# L4 — Eu-151 Matsui Hamiltonian-only (no loss, no LHY, DDI on)
# Anko's validation ladder (2026-05-22) Level 4: Eu Hamiltonian-only validation.
# DERIVED from runs/eu151_matsui_edh/configs/matsui_edh_baseline.experiment.jl with these
# DELIBERATE differences:
#   - lhy.kind: scalar → none        (Hamiltonian-only — no Lee-Huang-Yang)
#   - loss block:       (absent → explicit no-loss)
#   - K3, gamma_dr:     (none) — never set
#   - precision:        f64 (was f32; need exact Jz/E conservation check)
#   - grid:             [32,32,32] preview; companion L4_eu_..._64.experiment.jl for convergence
# All other parameters (N, ω_ref, c1_ratio, Bz quench, trap, init m=-F) match the
# baseline so a per-step Hamiltonian comparison with Ueda code is meaningful.
#
# Pass criteria (anko ladder, Level 4):
#   - GS converges to m=-F polarized state
#   - Bz step quench triggers EdH transfer per K&U
#   - DDI is the ONLY non-conservative spin-flip (no LHY/loss source)
#   - Jz = Fz + Lz approximately conserved (deviations should be numerical only,
#     ≤ grid/dt/box resolution band; checked in L4 convergence sweep)
# Compare-with-Ueda checklist (see [[validation-ladder-2026-05-22]] parameter contract):
#   DDI coefficient (1/4π?), μ convention, kernel sign, m ordering, B sign,
#   initial state, secular vs full, K3=0 (here), ψ normalization.
# NO loss block — Hamiltonian-only

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
                "secular" => false,
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
                "path" => "runs/verification_suite/outputs/L4dealiasv6_kcut11_eu_matsui_hamiltonian_only_32.json",
            ),
        )],
    )],
)
