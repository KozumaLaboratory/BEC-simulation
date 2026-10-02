# ─────────────────────────────────────────────────────────────────────
#  #337 criterion B, second axis — the FM/polar line in c1_ratio.
#
#  WHY NOT THE FIELD AXIS. config_arms.experiment.jl scanned Bz and answered the physics
#  but not the boundary question: at c1_ratio = 1/36 the stretched branch is
#  ALREADY below the polar one at B = 0 (ΔE = −0.085), so the baseline crossing
#  lies outside B ≥ 0 and only the two LHY arms that push ΔE positive have a
#  boundary to report. The campaign's own precision axis is c1 — see
#  config_c1_precise_B0k1.experiment.jl, which pins c1* ≈ 0.028–0.029 at B = 0, κ = 1 —
#  and that is where every arm's crossing exists.
#
#  B = 5 µG, NOT 0. At B = 0 the stretched branch sits on an exactly degenerate
#  spin manifold and the solver stalls: measured |∇E| = 5.7e-1 at B = 0 against
#  4.8e-6 at 5 µG, same everything else. 5 µG breaks the degeneracy and costs
#  nothing on the polar branch, whose energy is B-independent to 1e-9 across the
#  whole 0–70 µG scan (Mz = 0, and q ~ 1e-8).
#
#  SENSITIVITY, from config_arms.experiment.jl at c1 = 1/36, B = 5 µG. ΔE and its shift
#  against the `none` arm:
#      none            −0.1195
#      one functional  −0.1101   δ = +0.0094
#      own ansatz      +0.1896   δ = +0.3091
#      spatial         +0.2069   δ = +0.3264
#      scalar ×10      −0.0811   δ = +0.0384
#  With ∂ΔE/∂c1 ≈ 70 (from c1* ≈ 0.029 and ΔE(1/36) = −0.085 at B = 0) the
#  crossings are predicted at c1* ≈ 0.0290 (none), 0.0289 (one functional),
#  0.0246 (own ansatz), 0.0243 (spatial), 0.0277 (×30 control). The window below
#  brackets all five with ≥ 2 points either side at a 0.001 step.
#
#  REJECTION CRITERION, written before launch. If the ×30 control fails to move
#  c1* by ≥ 0.001 the instrument is blind and no verdict may be read off the
#  physics arms. If it passes, the answer to #337-B is δc1* per arm, converted to
#  µG through the field slope measured in config_arms.experiment.jl.
#
#  11 c1 × 9 comparison runs = 99 solves, submitted as 11 array tasks.
#
#  RE-RUN 2026-08-19 against the corrected homogeneous BdG (`7e6770c2`, #361/#367):
#  `_bdg_ddi_matrices` had built its normal block from the Hartree term, which is
#  zero for a uniform condensate. It was 2x too large on a polarised state and
#  IDENTICALLY ZERO on a polar one. Every `full_bdg`- and `spatial`-derived number
#  in the first pass of this campaign came from that code. This comment changes
#  the config bytes, hence the content-addressed run directory, so the whole scan
#  recomputes rather than mixing pre- and post-fix cells -- a dataset that is half
#  one and half the other is not a dataset.
# ─────────────────────────────────────────────────────────────────────
# POSITIVE CONTROL at ×30 rather than ×10: at ×10 the predicted c1* shift is
# 0.00055, barely one step of this grid. A control that lands inside the
# resolution proves nothing.

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
                "Bz" => "5.0e-6 Gauss",
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
                "c1_ratio" => 0.027,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "m_lbfgs" => 20,
            "method" => "lbfgs",
            "n_steps" => 4000,
            "newton_polish" => true,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify_distance" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        )],
    )],
    "scan" => Dict{String, Any}(
        "comparison_runs" => [Dict{String, Any}(
            "name" => "fm_none",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "m_plus_F",
            ),
        ), Dict{String, Any}(
            "name" => "polar_none",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
            ),
        ), Dict{String, Any}(
            "name" => "fm_fmdip",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "m_plus_F",
                "pipeline.0.lhy" => Dict{String, Any}(
                    "kind" => "fm_dipolar",
                ),
            ),
        ), Dict{String, Any}(
            "name" => "polar_fmdip",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
                "pipeline.0.lhy" => Dict{String, Any}(
                    "kind" => "fm_dipolar",
                ),
            ),
        ), Dict{String, Any}(
            "name" => "polar_polcon",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
                "pipeline.0.lhy" => Dict{String, Any}(
                    "kind" => "polar_contact",
                ),
            ),
        ), Dict{String, Any}(
            "name" => "fm_spatial",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "m_plus_F",
                "pipeline.0.lhy" => Dict{String, Any}(
                    "kind" => "spatial",
                    "n_points" => 40,
                ),
            ),
        ), Dict{String, Any}(
            "name" => "polar_spatial",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
                "pipeline.0.lhy" => Dict{String, Any}(
                    "kind" => "spatial",
                    "n_points" => 40,
                ),
            ),
        ), Dict{String, Any}(
            "name" => "fm_ctrl30",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "m_plus_F",
                "pipeline.0.lhy" => Dict{String, Any}(
                    "c_lhy" => 177564.0,
                    "kind" => "scalar",
                ),
            ),
        ), Dict{String, Any}(
            "name" => "polar_ctrl30",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
                "pipeline.0.lhy" => Dict{String, Any}(
                    "c_lhy" => 177564.0,
                    "kind" => "scalar",
                ),
            ),
        )],
        "product" => Dict{String, Any}(
            "pipeline.0.interactions.c1_ratio" => Dict{String, Any}(
                "from" => 0.022,
                "n" => 11,
                "to" => 0.032,
            ),
        ),
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
