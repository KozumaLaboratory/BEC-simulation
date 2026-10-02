# ─────────────────────────────────────────────────────────────────────
#  Eu151 EdH long hold × K_3 — does collapse get suppressed?
#
#  Companion to eu151_edh_k3_compare (0.3 ω⁻¹ A/B short test). Same 32³
#  setup but Phase 2 extended to 10 ω⁻¹ (≈ 14.5 ms) so we can tell
#  whether the K_3 collapse-mitigation holds out, just delays the
#  Townes-like singularity, or fails.
#
#  K3 routing was fixed on 2026-05-13 (commit 6bfe9d9). K3_per_m_si
#  now flows into LossParams.K3_per_m_cubic (quadratic-in-n true 3-body
#  loss), not the legacy linear-in-n L3_per_m field. So this is the
#  first proper test of "K3 suppresses Eu151 EdH collapse over Matsui
#  timescales".
#
#  Setup matches eu151_edh_postfix_local 32³ for apples-to-apples
#  comparison: scalar LHY + gamma_dr=0.02 + K3_per_m_si=1e-41 m^6/s
#  (Dy164 order-of-magnitude proxy; Eu has no measured K_3 yet).
# ─────────────────────────────────────────────────────────────────────
# N_atoms + omega_ref propagate into every step's `interactions:` so
# the K3_per_m_si SI conversion (n0=N/a_ho³, factor=n0²/ω_ref) has the
# inputs it needs at every dynamics phase.
# Phase 0: m = +F stretched ground state in the Matsui prep field
# B = 1.0 μT (= 0.01 Gauss). Scalar LHY for FM-polarized GS
# stabilisation near the dipolar instability boundary.
# Phase 1: rapid Zeeman quench  Bz : 1.0 μT → 2.6 nT  in 0.14 ω⁻¹
# (≈ 0.20 ms). Numeric Gauss values: 0.01 → 2.6e-5 (ramp dicts can't
# carry unit strings).
# Phase 2: weak-field hold — the EdH-active phase.  Bz = 2.6 nT for
# 10 ω⁻¹ ≈ 14.5 ms (~7× the Townes-collapse timescale seen pre-fix
# at 1.5 ms). 100k steps at dt=1e-4, save every 200 → ~500 snapshots.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 10000,
            "omega_ref" => 691.15,
        ),
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_edh_phys" => Dict{String, Any}(
            "atom" => "Eu151",
            "grid" => Dict{String, Any}(
                "box" => [20, 20, 20],
                "n" => [32, 32, 32],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 10000,
                "c1_ratio" => 0.0,
                "omega_ref" => 691.15,
            ),
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.182],
                "type" => "harmonic",
            ),
        ),
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.01 Gauss",
            ),
            "dt" => 0.005,
            "initial_state" => "m_plus_F",
            "lhy" => Dict{String, Any}(
                "kind" => "scalar",
            ),
            "n_steps" => 3000,
            "tol" => 1.0e-9,
            "use" => ["eu151_edh_phys"],
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 0.14,
                    "from" => 0.01,
                    "to" => 2.6e-5,
                ),
            ),
            "dt" => 0.0005,
            "duration" => 0.14,
            "save" => Dict{String, Any}(
                "every" => 280,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "2.6e-5 Gauss",
            ),
            "dt" => 0.0001,
            "duration" => 10.0,
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s"],
                "gamma_dr" => 0.02,
            ),
            "noise" => Dict{String, Any}(
                "initial" => Dict{String, Any}(
                    "coherent" => Dict{String, Any}(
                        "amplitude" => 1.0e-6,
                        "k_cut" => 2.5,
                    ),
                ),
                "seed" => 42,
            ),
            "save" => Dict{String, Any}(
                "every" => 200,
            ),
        ),
    )],
)
