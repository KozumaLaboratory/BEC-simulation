# Matsui et al. (2025) Fig. 4B — N_atoms scan, CORRECTED. The one parameter their release
# is DEMONSTRABLY inconsistent about.
#
# Their shipped setup_parameters says Ntot = 3.5e4; the published curves total
# 49999.9. We assumed 5e4 because that is what the data says, but the couplings
# in the run that produced the data are not observable from the data — every
# coupling scales with N, and the plotted populations are absolute numbers that
# could have been produced at one N and reported at another.
#
# All of c_dd, c0 and c1 scale linearly with N here, so this is a single axis.
# Scaling: mu ∝ c0^(2/5) ∝ N^(2/5), n_peak = mu/c0 ∝ N^(-3/5), so the dipolar
# mean field c_dd*n_peak ∝ N^(2/5) — going 5e4 -> 3.5e4 weakens it by 13 %.
# That is the right size and the right direction for the ~20 % transfer excess.
# It is the WRONG direction for the centre, which is the whole puzzle: no single
# scalar moves both the way the data demands.
#
# CORRECTION 2026-07-31. The first version of this scan overrode only
# `pipeline.0.interactions.N_atoms`, leaving `defaults.interactions.N_atoms:
# 50000` to be injected into the dynamics step. The N = 3.5e4 arm therefore ran a
# 3.5e4 GROUND STATE under 5e4 DYNAMICS couplings — an out-of-equilibrium state
# that expands, which is exactly what the diagnostic showed: its 5 ms rms radius
# came out 3.121 a_ho against 2.948 at N = 5e4, when a smaller N must give a
# SMALLER cloud (Thomas-Fermi: 2.663 vs 2.860). The arm measured the wrong thing
# and its result is retracted.
#
# The irony is the point: this is precisely the initial-state/dynamics mismatch
# I had hypothesised in THEIR code, reproduced by accident in my own config
# because one knob lives in three places.
#
# Now every N_atoms moves together — defaults, ground_state, and an explicit
# interactions block on dynamics so nothing can be injected behind it.
#
# Positive controls: (1) the two arms must differ in population, and (2) the
# 3.5e4 arm's cloud must be SMALLER, not larger. (2) is the one that caught this.
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
# the scan axis and must not be injected
# NO loss block — their Fig. 2/4 theory curves are loss-free.
# m=-6 → -5 transfer is DRIVEN by DDI, not seeded
# of the hold — point_001's saved psi cannot be trusted

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
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
                    "to" => 2.5e-5,
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
                "N_atoms" => 50000,
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
            "pipeline.0.interactions.N_atoms" => [50000, 35000],
            "pipeline.1.interactions.N_atoms" => [50000, 35000],
        ),
    ),
)
