# Matsui et al. (2025) Fig. 4B — B-scan WITH atom loss, 32³.
#
# Why: the measurement is not atom-number-conserving and both simulations are.
# Summing the published experimental sheet at 5 ms gives a total that runs from
# 45.8k in the wings down to 27.6k at the dip — 8 % to 45 % below 5e4, and the
# loss is DEEPEST WHERE THE DIP IS. Fig. 4B plots absolute N_{-6}, so that
# field-dependent deficit sits inside the very quantity being compared, and
# neither their loss-free curve nor ours contains any of it.
#
# This arm asks whether three-body loss can produce it. K3 is scanned over the
# two published 151Eu determinations and an order of magnitude above the larger,
# crossed with the field:
#   1.2e-29 cm^6/s  Miyazawa 2021 direct
#   3.6e-29         3x
#   1.2e-28         10x, far above anything measured — a deliberate over-estimate
# If even the 10x arm loses a few percent at 5 ms, the answer is no, and the
# experimental deficit is not condensate three-body loss.
#
# Everything else is identical to fig4b_scan_n32.experiment.jl, so the difference between
# the two IS the loss.
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
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s"],
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
            "pipeline.1.B.Bz.to" => Dict{String, Any}(
                "from" => -0.00013,
                "step" => 5.0e-6,
                "to" => 9.0e-5,
            ),
            "pipeline.1.loss.K3_per_m_si" => [["1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s", "1.2e-29 cm^6/s"], ["3.6e-29 cm^6/s", "3.6e-29 cm^6/s", "3.6e-29 cm^6/s", "3.6e-29 cm^6/s", "3.6e-29 cm^6/s", "3.6e-29 cm^6/s", "3.6e-29 cm^6/s", "3.6e-29 cm^6/s", "3.6e-29 cm^6/s", "3.6e-29 cm^6/s", "3.6e-29 cm^6/s", "3.6e-29 cm^6/s", "3.6e-29 cm^6/s"], ["1.2e-28 cm^6/s", "1.2e-28 cm^6/s", "1.2e-28 cm^6/s", "1.2e-28 cm^6/s", "1.2e-28 cm^6/s", "1.2e-28 cm^6/s", "1.2e-28 cm^6/s", "1.2e-28 cm^6/s", "1.2e-28 cm^6/s", "1.2e-28 cm^6/s", "1.2e-28 cm^6/s", "1.2e-28 cm^6/s", "1.2e-28 cm^6/s"]],
        ),
    ),
)
