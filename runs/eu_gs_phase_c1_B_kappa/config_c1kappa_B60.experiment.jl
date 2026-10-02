# ─────────────────────────────────────────────────────────────────────
#  ¹⁵¹Eu (F=6) GS phase map — c1 × κ plane at B = 60 µG.
#
#  Same c1 (uncertain, FM→AFM) × κ (cigar→pancake) plane as the B=0/10µG
#  slices, but at a MID field near the known transition band (B_eq≈40–62µG).
#  Here the linear Zeeman already breaks the transverse symmetry, so NO pin
#  is needed — two physical seeds (m_plus_F, polar) + newton_polish suffice;
#  min-E = GS. Together the 3 slices show how the c1/geometry phase map
#  moves with field.
#
#  Axes:  c1_ratio ∈ [−0.024, +0.048]  (13 pts; stays > singularity −1/36)
#         κ = ω_z/ω_r ∈ [0.3, 2.2]     (15 pts; cigar → pancake)
#  Taller z-box [.,.,24] holds the cigar cloud at κ=0.3.
#  195 (c1×κ) tasks × 2 seeds. Post-process → eu_phase_fingerprint → contour.
# ─────────────────────────────────────────────────────────────────────

Dict{String, Any}(
    "dealias" => Dict{String, Any}(
        "auto_dt" => true,
        "dt_safety" => 10.0,
        "enabled" => true,
        "k_cut" => 5.0,
    ),
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "6.0e-5 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 24.0],
                "n" => [32, 32, 64],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.0,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "m_lbfgs" => 20,
            "method" => "lbfgs",
            "n_steps" => 1000,
            "newton_polish" => true,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-8,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify_distance" => Dict{String, Any}(),
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
            "pipeline.0.interactions.c1_ratio" => Dict{String, Any}(
                "from" => -0.024,
                "n" => 13,
                "to" => 0.048,
            ),
            "pipeline.0.potential.omega.2" => Dict{String, Any}(
                "from" => 0.3,
                "n" => 15,
                "to" => 2.2,
            ),
        ),
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
