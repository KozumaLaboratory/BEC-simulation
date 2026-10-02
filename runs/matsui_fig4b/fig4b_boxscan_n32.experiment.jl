# Matsui et al. (2025) Fig. 4B — box scan at FIXED dx = 0.5 a_ho.
#
# Separates BOX from RESOLUTION, which fig4b_scan_n64 could not: that varied dx
# at fixed box and found convergence, leaving the box untested. Here dx is held
# and only the box moves, 16 -> 24 -> 32 a_ho (n = 32, 48, 64), against a cloud
# of R_TF = 5.78 a_ho.
#
# Measured on the completed box-16 run, the density reaching the outermost cell
# is 6e-5 and the fraction beyond |x| = 6 a_ho is 5.3e-3, so this is not about
# the wavefunction hitting the wall. It is about whether anything else in the
# problem — trap truncation, the DDI at the cloud's own scale, the periodic
# spectral derivative — cares about how much vacuum surrounds the cloud.
#
# Target (measured off test/fixtures/matsui2025/dataset_fig4_theo.csv by
# `resonance_dip`, pinned in test/validation/test_matsui_fig4_dip.jl):
#     their simulation : dip centre -2.5495 nT, half-depth width 15.0224 nT
#     their experiment : dip centre -3.2048 nT, half-depth width 14.5414 nT
#
# Parameters reconstructed from time.f90 in Zenodo 17303925, NOT read off it:
# the shipped `setup_parameters` carries Ntot = 3.5e4 where the published curves
# total 5.0e4, and initial.f90 builds its ground state with cc0_eff = 1 /
# cc1_eff = 0 against time.f90's cc0_eff = 0.5 / cc1_eff = 50. See
# docs/validation/parameter_contract_with_Ueda.md §0.4.
#
#   N = 5.0e4, m_F = -6, (ω_x, ω_y, ω_z) = 2π·(110, 110, 130) Hz
#   cc0_eff = 0.5 with cc1 = cc0/36  ⇔  our c1_ratio = 1/36 under the
#     c₀ + 36c₁ = 4π(a_s/a_ho)N constraint (verified: both give c₀ = 2343.63)
#   ZeemanQ = 1.0 Hz, a LITERAL input in their code — not derived from |B|².
#     q/h = 1 Hz moves the m=-6 → -5 spacing by 11 Hz out of 42.3, i.e. 0.68 nT
#     of resonance position. It is not optional.
#   B: 10.4 mG ramped to the target with τ = 50 µs, then held; 5 ms total.
#   Loss-free (their L3loss = 0 AND L3loss_eff = 0).
# NO loss block — their Fig. 2/4 theory curves are loss-free.
# m=-6 → -5 transfer is DRIVEN by DDI, not seeded
# of the hold — point_001's saved psi cannot be trusted

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 50000,
            "omega_ref" => 691.1504,
        ),
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.0104 Gauss",
                "phi" => 0.0,
                "q" => 0.00909116,
                "theta" => 0.0,
            ),
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "pad_factor" => 2,
                "padded" => true,
                "secular" => true,
            ),
            "dt" => 0.005,
            "gauge_fix" => false,
            "grid" => Dict{String, Any}(
                "box" => [16.0, 16.0, 16.0],
                "n" => [32, 32, 32],
            ),
            "init_sigma" => 1.5,
            "initial_state" => "m_minus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.027777777777777776,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "n_steps" => 4000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.181818],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-10,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 0.1037,
                    "from" => 0.0104,
                    "to" => -0.0002,
                ),
                "phi" => 0.0,
                "q" => 0.00909116,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "pad_factor" => 2,
                "padded" => true,
                "secular" => false,
            ),
            "dt" => 0.001,
            "duration" => 3.4558,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "save" => Dict{String, Any}(
                "every" => 108,
                "precision" => "f64",
                "psi" => false,
            ),
            "seed_amplitude" => 0.0,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        )],
    )],
    "scan" => Dict{String, Any}(
        "product" => Dict{String, Any}(
            "pipeline.0.grid" => [Dict{String, Any}(
                "box" => [16.0, 16.0, 16.0],
                "n" => [32, 32, 32],
            ), Dict{String, Any}(
                "box" => [24.0, 24.0, 24.0],
                "n" => [48, 48, 48],
            ), Dict{String, Any}(
                "box" => [32.0, 32.0, 32.0],
                "n" => [64, 64, 64],
            )],
            "pipeline.1.B.Bz.to" => Dict{String, Any}(
                "from" => -6.0e-5,
                "step" => 5.0e-6,
                "to" => 0.0,
            ),
        ),
    ),
)
