# ─────────────────────────────────────────────────────────────────────
#  ¹⁵¹Eu (F=6) GS phase map — c1 × κ plane at B = 0 µG.
#
#  Motivation: c1 for Eu is NOT pinned by data (7 unknown channels; the
#  +1/36 "Matsui AFM" value is a dynamics best-fit). So treat c1 as an
#  UNCERTAIN axis spanning FM (c1<0) → AFM (c1>0), and cross the trap
#  geometry from cigar (κ<1, DDI head-to-tail) to pancake (κ>1, DDI
#  side-by-side). This weak-field slice: q≈0, Zeeman just tilts the soft manifold.
#
#  Axes:  c1_ratio ∈ [−0.024, +0.048]  (13 pts; stays > singularity −1/36)
#         κ = ω_z/ω_r ∈ [0.3, 2.2]     (15 pts; cigar → pancake)
#  Taller z-box [.,.,24] holds the cigar cloud (a_z=1/√0.3≈1.83× at κ=0.3).
#  Weak field ⇒ soft manifold ⇒ pin (transverse ε-continuation) certifies
#  the ε→0 flower/flux-closure GS. Two seeds (m_plus_F, polar); min-E = GS.
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
                "Bz" => "1.0e-5 Gauss",
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
            "pin" => Dict{String, Any}(
                "epsilon_ramp" => [0.004, 0.002, 0.001, 0.0005],
                "kind" => "transverse",
            ),
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
