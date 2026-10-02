# ─────────────────────────────────────────────────────────────────────
#  STAGE B — 128³ PROMOTION of the (c1 × Bz × κ) Eu F=6 GS phase diagram,
#  cost-compressed per docs/design/eu_phase_diagram_adaptive_mapping.md.
#
#  Each cell warm-starts from its OWN 32³ recon winner (config_recon result,
#  runs/config_recon_335a2216), spectrally upsampled 32³→128³, then a short
#  L-BFGS polish converges it at the fine grid. No fresh ITP per cell:
#  which-phase is resolution-robust, so the expensive multi-seed basin search
#  already happened at 32³; here we only refine on the fine grid.
#
#  seed_from matches each cell to its recon point by the resolved signature
#  (c1/Bz/κ/initial_state) — the scan below is IDENTICAL to config_recon.experiment.jl,
#  so every (cell × seed) auto-pairs. Two seeds (stretched, polar) → min-E GS.
#
#  Scan: 3 (c1) × 8 (Bz) × 5 (κ) = 120 points × 2 seeds = 240 polishes @ 128³.
#  UGE array: -t 1-120, SPINORBEC_SCAN_ONLY_INDEX per task (2 seeds inner).
# ─────────────────────────────────────────────────────────────────────
# IDENTICAL scan to config_recon.experiment.jl so seed_from pairs each cell 1:1.
# Override paths OMIT `.ground_state` (auto-unwrapped single-key step).

Dict{String, Any}(
    "dealias" => Dict{String, Any}(
        "auto_dt" => true,
        "dt_safety" => 10.0,
        "enabled" => true,
        "k_cut" => 20.0,
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
                "n" => [128, 128, 128],
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
