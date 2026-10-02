# config_scan_B_pm120_v2.experiment.jl
# ============================
# Project A — ±120 μG sweep v2: DDI Nyquist symmetry fix + relative ITP convergence
#
# Changes from v1:
#   - DDI: odd-in-k off-diagonals Q_xy/Q_xz/Q_yz zeroed on every odd-axis
#     Nyquist plane (rfft +k_Nyq vs fft -k_Nyq mismatch broke x<->y symmetry
#     and squished the cloud in y). Root cause + fix:
#     scripts/ddi_nyquist_xy_asymmetry_probe.jl,
#     test/hamiltonian/test_ddi_nyquist_xy_symmetry.jl
#   - ITP: convergence criterion is now RELATIVE  dE/|E| < tol  (src/solvers/ground_state/itp_loop.jl)
#   - tol: 1.0e-7  (relative; v1 used 1.0e-9 absolute which never triggered)
#   - thermal noise removed (clean symmetric init for the symmetry study)
#
# RUN_ROOT: ~/bec-runs/projectA_ground_state/survey_B_secular_false_pm120_v2
# Estimated wall time: ~10-16 h (27 points x GPU; ITP exits early when converged)
# ============================

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
        "eu151_fullDDI_pm120" => Dict{String, Any}(
            "atom" => "Eu151",
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 12.0],
                "n" => [32, 32, 32],
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
            "tol" => 1.0e-7,
            "use" => ["eu151_fullDDI_pm120"],
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        )],
    )],
    "scan" => Dict{String, Any}(
        "comparison_runs" => [Dict{String, Any}(
            "name" => "g01_Bn120uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "-1.2e-4 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g02_Bn100uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "-1.0e-4 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g03_Bn80uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "-8.0e-5 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g04_Bn60uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "-6.0e-5 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g05_Bn40uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "-4.0e-5 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g06_Bn30uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "-3.0e-5 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g07_Bn20uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "-2.0e-5 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g08_Bn15uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "-1.5e-5 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g09_Bn10uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "-1.0e-5 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g10_Bn8uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "-8.0e-6 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g11_Bn6uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "-6.0e-6 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g12_Bn4uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "-4.0e-6 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g13_Bn2uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "-2.0e-6 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g14_B0",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "0.0 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g15_B2uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "2.0e-6 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g16_B4uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "4.0e-6 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g17_B6uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "6.0e-6 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g18_B8uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "8.0e-6 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g19_B10uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "1.0e-5 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g20_B15uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "1.5e-5 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g21_B20uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "2.0e-5 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g22_B30uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "3.0e-5 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g23_B40uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "4.0e-5 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g24_B60uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "6.0e-5 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g25_B80uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "8.0e-5 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g26_B100uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "1.0e-4 Gauss",
            ),
        ), Dict{String, Any}(
            "name" => "g27_B120uG",
            "override" => Dict{String, Any}(
                "pipeline.0.B.Bz" => "1.2e-4 Gauss",
            ),
        )],
    ),
)
