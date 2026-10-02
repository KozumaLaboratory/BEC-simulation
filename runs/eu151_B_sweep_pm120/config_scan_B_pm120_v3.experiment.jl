# config_scan_B_pm120_v3.experiment.jl
# ============================
# Project A — ±120 μG sweep v3: 47-point sweep, 64³ grid, array-job ready
#
# Changes from v2 (config_scan_B_pm120_v2.experiment.jl):
#   - Grid: 32³ → 64³  (same box 12³ → halved spacing, 8× memory)
#   - Points: 27 → 47  (denser around ±50/55/60/65/70 μG band)
#   - Scan form: comparison_runs → scan.product with explicit unit-string
#     list. This makes each Bz point an outer scan.points[i], so the
#     array-job hook SPINORBEC_SCAN_ONLY_INDEX selects exactly one point
#     per UGE task. (comparison_runs are the INNER loop and the hook does
#     not filter them.)
#   - Output dir: survey_B_secular_false_pm120_v3
#   - Same physics: full DDI (secular=false), c1=1/36, thermal=0.40,
#     initial_state=m_minus_F, ITP tol=1e-7 relative.
#   - Nyquist DDI symmetry fix (kx/ky/kz odd off-diagonals zeroed,
#     commit 091367fd on main) is now in effect.
#
# RUN: see runs/eu151_B_sweep_pm120/submit_array.sh
#   qsub -g <GROUP> runs/eu151_B_sweep_pm120/submit_array.sh
#
# Per-task output: point_<TASK_ID>.jld2  (1..47, NaN-padded to 003 prefix)
# ============================
# 47-point Bz sweep as an explicit list (μG units → Gauss strings).
# Ordered most-negative → most-positive. Array task i picks element i.
#
# Index | Bz (μG)
#   1   | -120        13  | -40         24  |   0         35  |  +45
#   2   | -110        14  | -35         25  |  +2         36  |  +50
#   3   | -100        15  | -30         26  |  +4         37  |  +55
#   4   |  -90        16  | -25         27  |  +6         38  |  +60
#   5   |  -80        17  | -20         28  |  +8         39  |  +65
#   6   |  -75        18  | -15         29  | +10         40  |  +70
#   7   |  -70        19  | -10         30  | +15         41  |  +75
#   8   |  -65        20  |  -8         31  | +20         42  |  +80
#   9   |  -60        21  |  -6         32  | +25         43  |  +90
#  10   |  -55        22  |  -4         33  | +30         44  | +100
#  11   |  -50        23  |  -2         34  | +35         45  | +110
#  12   |  -45                                            46  | +120
#                                                        47  | (reserved; trim to 1-47 in -t)

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
        "eu151_fullDDI_pm120_v3" => Dict{String, Any}(
            "atom" => "Eu151",
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
                "Bz" => "0.0 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "initial_state" => "m_minus_F",
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "method" => "itp",
            "n_steps" => 12000,
            "noise" => Dict{String, Any}(
                "initial" => Dict{String, Any}(
                    "thermal" => 0.4,
                ),
                "seed" => 20260610,
            ),
            "tol" => 1.0e-7,
            "use" => ["eu151_fullDDI_pm120_v3"],
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        )],
    )],
    "scan" => Dict{String, Any}(
        "product" => Dict{String, Any}(
            "pipeline.0.B.Bz" => ["-1.20e-4 Gauss", "-1.10e-4 Gauss", "-1.00e-4 Gauss", "-9.0e-5 Gauss", "-8.0e-5 Gauss", "-7.5e-5 Gauss", "-7.0e-5 Gauss", "-6.5e-5 Gauss", "-6.0e-5 Gauss", "-5.5e-5 Gauss", "-5.0e-5 Gauss", "-4.5e-5 Gauss", "-4.0e-5 Gauss", "-3.5e-5 Gauss", "-3.0e-5 Gauss", "-2.5e-5 Gauss", "-2.0e-5 Gauss", "-1.5e-5 Gauss", "-1.0e-5 Gauss", "-8.0e-6 Gauss", "-6.0e-6 Gauss", "-4.0e-6 Gauss", "-2.0e-6 Gauss", "0.0 Gauss", "2.0e-6 Gauss", "4.0e-6 Gauss", "6.0e-6 Gauss", "8.0e-6 Gauss", "1.0e-5 Gauss", "1.5e-5 Gauss", "2.0e-5 Gauss", "2.5e-5 Gauss", "3.0e-5 Gauss", "3.5e-5 Gauss", "4.0e-5 Gauss", "4.5e-5 Gauss", "5.0e-5 Gauss", "5.5e-5 Gauss", "6.0e-5 Gauss", "6.5e-5 Gauss", "7.0e-5 Gauss", "7.5e-5 Gauss", "8.0e-5 Gauss", "9.0e-5 Gauss", "1.00e-4 Gauss", "1.10e-4 Gauss", "1.20e-4 Gauss"],
        ),
    ),
)
