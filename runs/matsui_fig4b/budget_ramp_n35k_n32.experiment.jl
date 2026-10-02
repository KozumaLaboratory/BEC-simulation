# ERROR BUDGET, arm A — their exponential ramp, at N = 3.5e4.
#
# Baseline (fig4b_scan_n35k_n32): centre -2.510 against their -2.549, residual
# +0.039 nT. At N = 5e4 the ramp was worth 0.070 nT, which is LARGER than the
# residual — so the remaining candidates must be partially cancelling, and the
# only way to see that is signed, one at a time.
#
# B(t) = (B_ini - B_fin) exp(-t/tau) + B_fin, tau = 50 us. Since B_ini = 1.04 uT
# is ~80x any B_fin, (B_ini - B_fin) = B_ini to 1.2 %, so the ramp separates into
# a constant (the scan axis) plus a fixed exponential tail sampled
# piecewise-linearly at tau/6.
#
# At +2.5 nT, N = 3.5e4 reproduces their own 5 ms state (dataset_fig1/F.txt) on
# three independent observables at once: m=-6 fraction 0.4158 vs 0.4273 (2.7 %),
# rms radius 2.687 vs 2.619 a_ho (2.6 %), aspect ratio 0.877 vs 0.899 (2.4 %).
# At N = 5e4 the transfer was off by 38 %. Nothing else tried in this campaign
# moved all three together.
#
# 3.5e4 is the value shipped in their setup_parameters, while the published
# curves total 49999.9 — i.e. the run used 3.5e4 couplings and the output was
# normalised to 5e4 for plotting.
#
# This checks the dip itself. PREDICTION, recorded before the run: c_dd*n_peak
# goes as N^(2/5), so a smaller N weakens the dipolar field and pulls the
# resonance TOWARD zero — away from their -2.5495. If the centre instead moves
# toward theirs, that scaling argument is wrong and the offset is not a simple
# mean-field shift.
#
# N_atoms is in lockstep in all three places it can enter.
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
            "N_atoms" => 35000,
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
                "N_atoms" => 35000,
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
                    "sum" => [-0.00013, Dict{String, Any}(
                        "piecewise" => Dict{String, Any}(
                            "times" => [0.0, 0.0057596, 0.0115192, 0.0172788, 0.0230383, 0.0287979, 0.0345575, 0.0403171, 0.0460767, 0.0518363, 0.0575959, 0.0633555, 0.069115, 0.0748746, 0.0806342, 0.0863938, 0.0921534, 0.097913, 0.1036726, 0.1094321, 0.1151917, 0.1209513, 0.1267109, 0.1324705, 0.1382301, 0.1439897, 0.1497493, 0.1555088, 0.1612684, 0.167028, 0.1727876, 0.1785472, 0.1843068, 0.1900664, 0.1958259, 0.2015855, 0.2073451, 0.2131047, 0.2188643, 0.2246239, 0.2303835, 0.2361431, 0.2419026, 0.2476622, 0.2534218, 0.2591814, 0.264941, 0.2707006, 0.2764602, 0.2822197, 0.2879793, 0.2937389, 0.2994985, 0.3052581, 0.3110177, 0.3167773, 0.3225369, 0.3282964, 0.334056, 0.3398156, 0.3455752, 0.5, 3.4558],
                            "values" => [0.0104, 0.00880341, 0.007451926, 0.006307919, 0.005339538, 0.004519821, 0.003825946, 0.003238594, 0.00274141, 0.002320554, 0.001964306, 0.001662749, 0.001407487, 0.001191412, 0.001008508, 0.000853684, 0.0007226279, 0.0006116913, 0.0005177855, 0.000438296, 0.0003710095, 0.0003140528, 0.0002658399, 0.0002250287, 0.0001904826, 0.0001612401, 0.0001364868, 0.0001155336, 9.779705e-5, 8.278342e-5, 7.007465e-5, 5.931691e-5, 5.021068e-5, 4.250242e-5, 3.597752e-5, 3.045432e-5, 2.577902e-5, 2.182147e-5, 1.847148e-5, 1.563577e-5, 1.323539e-5, 1.120352e-5, 9.483572e-6, 8.027671e-6, 6.795277e-6, 5.752077e-6, 4.869028e-6, 4.121544e-6, 3.488811e-6, 2.953215e-6, 2.499843e-6, 2.116071e-6, 1.791215e-6, 1.516231e-6, 1.283462e-6, 1.086427e-6, 9.196407e-7, 7.78459e-7, 6.589513e-7, 5.577903e-7, 4.721593e-7, 0.0, 0.0],
                        ),
                    )],
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
            "interactions" => Dict{String, Any}(
                "N_atoms" => 35000,
                "c1_ratio" => 0.027777777777777776,
                "omega_ref" => 691.1504,
            ),
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
        "zip" => Dict{String, Any}(
            "pipeline.1.B.Bz.sum.0" => Dict{String, Any}(
                "from" => -0.00013,
                "step" => 5.0e-6,
                "to" => 9.0e-5,
            ),
        ),
    ),
)
