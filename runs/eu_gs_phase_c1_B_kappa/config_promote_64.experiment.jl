# ─────────────────────────────────────────────────────────────────────
#  STAGE B — 64³ PROMOTION of the (c1 × Bz × κ) Eu F=6 GS phase diagram.
#  Design ladder step (docs/design/eu_phase_diagram_adaptive_mapping.md):
#  which-phase is resolution-robust, so the FULL map is drawn at 64³ (cheap,
#  converged), and only selected headline/boundary/texture cells are later
#  promoted to 128³ (config_promote.experiment.jl). 64³ keeps the whole map ~13 GB,
#  well inside the /gs/fs group quota (128³-all would be ~104 GB).
#
#  Each cell warm-starts from its OWN 32³ recon winner (config_recon result),
#  spectrally upsampled 32³→64³, then a short L-BFGS polish. continuation is
#  OFF (default) ⇒ every cell seeds independently from seed_from — no
#  hysteresis; UGE-array-parallel over the 120 points.
#
#  Scan: 3 (c1) × 8 (Bz) × 5 (κ) = 120 points × 2 seeds = 240 polishes @ 64³.
# ─────────────────────────────────────────────────────────────────────
# Symmetry-breaking pin: lift the weak-field soft-manifold Goldstone floor
# (un-pinned |∇E| floors ~0.05) so LBFGS reaches an isolated minimum, then
# extrapolate ε→0 for the certified energy. FM (high-Bz) cells are
# unaffected (ε→0 recovers the unique polarised GS). Both bx and trap pins
# were validated to the same E0 in prior weak-field Eu work.

Dict{String, Any}(
    "dealias" => Dict{String, Any}(
        "auto_dt" => true,
        "dt_safety" => 10.0,
        "enabled" => true,
        "k_cut" => 10.0,
    ),
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.0 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 12.0],
                "n" => [64, 64, 64],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.0277777778,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "m_lbfgs" => 20,
            "method" => "lbfgs",
            "n_steps" => 800,
            "pin" => Dict{String, Any}(
                "epsilon_ramp" => [0.004, 0.002, 0.001, 0.0005],
                "kind" => "transverse",
            ),
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "seed_from" => Dict{String, Any}(
                "run" => "runs/config_recon_335a2216",
                "upsample" => true,
            ),
            "tol" => 1.0e-7,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify_distance" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "multipole_order" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "majorana_order" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        )],
    )],
    "scan" => Dict{String, Any}(
        "comparison_runs" => [Dict{String, Any}(
            "name" => "stretched",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "m_plus_F",
            ),
        ), Dict{String, Any}(
            "name" => "polar",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
            ),
        )],
        "product" => Dict{String, Any}(
            "pipeline.0.B.Bz" => ["0.0 Gauss", "2.5e-5 Gauss", "4.0e-5 Gauss", "4.8e-5 Gauss", "5.5e-5 Gauss", "6.2e-5 Gauss", "7.5e-5 Gauss", "1.0e-4 Gauss"],
            "pipeline.0.interactions.c1_ratio" => [-0.015, 0.0, 0.0277777778],
            "pipeline.0.potential.omega.2" => Dict{String, Any}(
                "from" => 1.0,
                "n" => 5,
                "to" => 2.2,
            ),
        ),
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
