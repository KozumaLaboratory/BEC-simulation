# ─────────────────────────────────────────────────────────────────────
#  ¹⁵¹Eu (F=6) ground-state quantum phase diagram — 3-axis exploration.
#
#  Axes (full Cartesian product):
#    1. c1_ratio  spin-dependent contact (FM c1<0 ↔ AFM c1>0), crosses 0
#    2. Bz        weak-field linear Zeeman (µG regime; DDI-competition)
#    3. κ = ω_z/ω_r   trap oblateness → DDI demagnetization / transition order
#
#  Physics target: how the trap oblateness (demag) and c1 jointly control
#  the ground-state order of dipolar F=6 Eu at weak field. κ restricted to
#  the OBLATE side [1.0, 2.2] where (a) the box stays safe (cloud shrinks
#  in z; radial fixed) and (b) the tricritical 1st-order jump lives
#  (κ_tc≈0.95 from prior work). Crossover side κ<1 needs a taller z-box
#  and is deferred.
#
#  Grid 128³ (H100 device-resident energy+gradient makes this cheap after
#  the 2026-07 perf work). Full DDI (secular=false). Two initial seeds
#  (stretched m=+F, polar m=0) per point; min-energy result is the GS.
#
#  Scan size: 7 (c1) × 7 (Bz) × 5 (κ) = 245 points × 2 seeds = 490 solves.
#  UGE array: -t 1-245, each task runs one (c1,Bz,κ) point × 2 seeds via
#  SPINORBEC_SCAN_ONLY_INDEX (comparison_runs are the inner loop).
# ─────────────────────────────────────────────────────────────────────
# 3-axis product with INFORMED, non-uniform sampling: dense (B × κ) with B
# concentrated in the known transition band [40–62 µG], c1 sampled COARSELY
# as a background band (per docs/design/eu_phase_diagram_adaptive_mapping.md:
# "don't densely map >2D"; at µG, c1 is a fixed background, not a live axis).
#   3 (c1) × 8 (Bz) × 5 (κ) = 120 points × 2 seeds = 240 solves.
# NOTE override paths OMIT `.ground_state`: pipeline[0] = {ground_state: {...}}
# is a single-key dict that apply_override! auto-unwraps, so paths address
# keys INSIDE ground_state directly (proven form; see eu151_B_sweep_pm120).

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
            "dt" => 0.002,
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
            "method" => "itp",
            "n_steps" => 12000,
            "noise" => Dict{String, Any}(
                "initial" => Dict{String, Any}(
                    "thermal" => 0.4,
                ),
                "seed" => 20260722,
            ),
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
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
