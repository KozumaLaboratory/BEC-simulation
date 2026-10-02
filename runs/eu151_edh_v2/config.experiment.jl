# ─────────────────────────────────────────────────────────────────────
#  Eu-151 Einstein-de Haas (EdH) — Matsui-aligned canonical, v2.
#  Reference: Matsui et al., Science 391, 384–388 (2026), Fig. 2.
#
#  Successor / improvement of:
#    runs/eu151_edh/                — baseline (1.5 ms only, c1=0, N=10k)
#    runs/eu151_edh_c1phys/         — added c1=0.003 (still N=10k)
#    runs/eu151_edh_K3_long/        — extended to 14.5 ms with K3 + γ_dr
#    runs/eu151_edh_k3_compare/     — A/B K3 comparison
#    runs/eu151_edh_loss_factorial/ — 2×2 K3 × γ_dr factorial
#    runs/matsui_baseline/          — N=5e4, c1=1/36, 40 ms loss-free + K3 sweep
#
#  v2 consolidates the best choices from all of the above:
#    • N = 50 000              (real Matsui scale, from matsui_baseline)
#    • c1/c0 = 1/36            (Matsui best-fit, from matsui_baseline)
#    • m_minus_F + Bz<0        (project sign convention; m=-F stretched)
#    • box [12, 12, 12]        (matsui_baseline; finer dx than [20,20,20])
#    • lhy: none               (scalar LHY = no-LHY at F=6, verified)
#    • K3 calibrated to Matsui's ~40% loss (NOT γ_dr — K3 alone is enough)
#    • full 40 ms hold         (Matsui Fig. 2 timeline)
#    • defaults.interactions.{N_atoms, omega_ref} propagate into every
#      step (needed for K3 SI conversion at every dynamics phase per
#      eu151_edh_K3_long comment)
#    • scan: comparison_runs   (loss-free reference + K3-calibrated)
#
#  Three improvements over the calibration runs in matsui_baseline:
#    (1) Single canonical YAML (was 6 separate matsui_40ms_lossy_*.experiment.jl).
#    (2) Direct A/B comparison via comparison_runs (one dispatch, two
#        cells: K3=0 and K3=2.1e-40).
#    (3) trajectory + ring extraction scripts co-located in this dir,
#        following the eu151_edh_K3_long pattern.
#
#  Calibration provenance:
#    K3 fine bracket at factor ∈ {5, 10, 15, 20, 25, 30, 100} × proxy
#    (where proxy = 1.0×10⁻⁴¹ m⁶/s, Dy164 order-of-magnitude):
#      K3 / proxy   N(40 ms)/N(0)
#         5         0.865
#        10         0.762
#        15         0.681
#        20         0.615   ←─ matches Matsui experimental ~0.60
#        25         0.561
#        30         0.516
#       100         0.244
#    Linear interpolation: K3 ≈ 21 × proxy = 2.1×10⁻⁴⁰ m⁶/s → 0.60.
# ─────────────────────────────────────────────────────────────────────
# N_atoms + omega_ref propagate into every step's `interactions:` so
# the K3_per_m_si SI conversion has the inputs it needs at every
# dynamics phase (per eu151_edh_K3_long convention).
# Phase 0 — m=-6 stretched ground state at Matsui prep field B = -1 μT.
# Sign convention (project): Bz<0 makes m=-F the GS for Eu (g_F > 0).
# Phase 1 — Zeeman quench Bz : -1 μT → -2.6 nT in 0.14 ω_ref⁻¹ ≈ 0.20 ms.
# Phase 2 — weak-field hold (EdH-active) for 27.646 ω_ref⁻¹ ≈ 40 ms.
# `loss:` block is the comparison_runs scan target below; this default
# carries the K3-calibrated value.

Dict{String, Any}(
    "dealias" => Dict{String, Any}(
        "auto_dt" => true,
        "dt_safety" => 10.0,
        "enabled" => true,
        "k_cut" => 16.0,
    ),
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 50000,
            "omega_ref" => 691.1504,
        ),
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_matsui_phys" => Dict{String, Any}(
            "atom" => "Eu151",
            "gauge_fix" => false,
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 12.0],
                "n" => [64, 64, 64],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.0277777778,
                "omega_ref" => 691.1504,
            ),
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.181818],
                "type" => "harmonic",
            ),
        ),
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.01 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => true,
            ),
            "dt" => 0.005,
            "init_sigma" => 1.5,
            "initial_state" => "m_minus_F",
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "n_steps" => 2000,
            "tol" => 1.0e-9,
            "use" => ["eu151_matsui_phys"],
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 0.14,
                    "from" => 0.01,
                    "to" => 2.6e-5,
                ),
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.0005,
            "duration" => 0.14,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "save" => Dict{String, Any}(
                "every" => 50,
                "precision" => "f64",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "2.6e-5 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 27.646,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["2.1e-40 m^6/s", "2.1e-40 m^6/s", "2.1e-40 m^6/s", "2.1e-40 m^6/s", "2.1e-40 m^6/s", "2.1e-40 m^6/s", "2.1e-40 m^6/s", "2.1e-40 m^6/s", "2.1e-40 m^6/s", "2.1e-40 m^6/s", "2.1e-40 m^6/s", "2.1e-40 m^6/s", "2.1e-40 m^6/s"],
            ),
            "save" => Dict{String, Any}(
                "every" => 200,
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
        )],
    )],
)
