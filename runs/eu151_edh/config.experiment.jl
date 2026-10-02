# ─────────────────────────────────────────────────────────────────────
#  Eu151 Einstein-de Haas (EdH) protocol — Matsui et al. parameters.
#
#  Reference: Matsui et al., Science 391, 384–388 (2026), Fig. 2.
#
#  Field schedule, **as quoted in the paper** (we keep B in Gauss because
#  the YAML normalizer rejects unit-strings inside ramp dicts; numeric
#  Gauss is the codebase default and Bz-strings are accepted for
#  constants):
#
#    Phase 0  GS prep    Bz = 1.0 μT  = 0.01 Gauss   (m = −6 stretched)
#    Phase 1  quench     Bz : 1.0 μT → 2.6 nT        (≈ 0.20 ms, "momentary")
#    Phase 2  weak hold  Bz = 2.6 nT = 2.6e-5 Gauss  (≈ 40 ms, EdH-active)
#
#  Trap (110, 110, 130) Hz with z vertical → ω_ref = 2π · 110 Hz,
#  λ_z = 130/110 = 1.182. N ≈ 5·10⁴ Eu151 atoms, m = −6 initial polarization
#  set by the 1.0 μT bias. After the quench the MDDI dominates Zeeman
#  (Larmor freq ~ 45 Hz at 2.6 nT vs. dipole field ≲ 8 nT) and angular
#  momentum is transferred from the atomic spin (Δ⟨F_z⟩) to the orbital
#  sector (Δ⟨L_z⟩) coherently — total angular momentum is conserved.
# ─────────────────────────────────────────────────────────────────────
# roton-instability threshold so the cloud doesn't collapse into a
# quantum-droplet filament during the weak-field hold (5·10⁴ does).
# Phase 0: m = +F stretched ground state in the Matsui prep field B = 1.0 μT.
# `lhy: {kind: scalar}` enables Lima–Pelster Q5 LHY stabilisation — Eu151 is
# near the dipolar instability boundary (ε_dd ≈ 0.54), so without LHY the
# weak-field hold collapses into a sub-voxel pencil after ~1 ms.
# Phase 1: rapid Zeeman quench  Bz : 1.0 μT → 2.6 nT  in 0.14 ω_ref⁻¹ ≈ 0.20 ms.
# (Numeric Gauss values: 0.01 → 2.6e-5; ramp dicts cannot carry unit strings.)
# Phase 2: weak-field hold  Bz = 2.6 nT  for 1.0 ω_ref⁻¹ ≈ 1.45 ms.
# Short hold by design: the longer Matsui-Fig.-2A protocol (27.6 ω_ref⁻¹
# ≈ 40 ms) produces a Townes-like density singularity within ~1.5 ms
# under our scalar-LHY approximation (the F=6 spinor LHY two-channel
# table is incomplete — see CLAUDE.md "Known limitations"). Stopping
# before that runaway captures the early EdH spin redistribution
# cleanly. To probe the full Matsui timeline either (a) add
# `loss: {gamma_dr: 0.02}` to dissipate the runaway core or (b) extend
# the F=6 LHY table.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "omega_ref" => 691.15,
        ),
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_edh_phys" => Dict{String, Any}(
            "atom" => "Eu151",
            "grid" => Dict{String, Any}(
                "box" => [20, 20, 20],
                "n" => [64, 64, 64],
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
            "n_steps" => 100000,
            "tol" => 1.0e-10,
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
            "duration" => 1.0,
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
