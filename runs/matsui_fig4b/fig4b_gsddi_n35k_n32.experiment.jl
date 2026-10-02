# Matsui et al. (2025) Fig. 4B — does their non-self-consistent ground state matter?
#
# FOUND BY READING initial.f90, not by measuring. Their ground-state solver
# `timeGP_3D_spin1_fix` carries `+ cdd*INT0_n*MatSZ(im)` in its Hamiltonian, but
# BOTH calls that would update INT0 inside the Crank-Nicolson iteration are
# commented out:
#
#     call calcSPIN_3D_pol(phi,Nall,spinZ)
#!    call calcDD_3D_pol(DD0,spinZ,INT0)          <- disabled
#
# INT0 is set once, at main:1775, from the Thomas-Fermi seed, and then frozen for
# the whole ITP. So their ground state relaxes under a dipolar field computed for
# a cloud that is not the one it converges to — in particular, for a seed that
# carries no magnetostriction. Ours is self-consistent.
#
# Their state sits BETWEEN the two arms here, so this brackets the effect:
#   ground_state ddi.enabled: true   our self-consistent GS (baseline, N = 3.5e4)
#   ground_state ddi.enabled: false  no dipolar field in the GS at all
# The dynamics keeps the full MDDI in both arms; only the initial state differs.
#
# If the bracket is much wider than the 1.2 % rms residual, the frozen field is a
# live candidate for it. If it is much narrower, the GS DDI is not the answer and
# this rules it out.
#
# Positive control: the two ground states MUST differ in shape. With the DDI the
# cloud is magnetostricted along z, <x2>/<z2> = 0.777; without it the bare trap
# gives 1.397. If both arms report the same shape the axis did not apply.
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
        "product" => Dict{String, Any}(
            "pipeline.0.ddi.enabled" => [true, false],
            "pipeline.1.B.Bz.to" => Dict{String, Any}(
                "from" => -0.00013,
                "step" => 5.0e-6,
                "to" => 9.0e-5,
            ),
        ),
    ),
)
