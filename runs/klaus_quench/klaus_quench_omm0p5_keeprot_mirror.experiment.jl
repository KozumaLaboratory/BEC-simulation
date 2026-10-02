# Klaus 2-phase quench protocol (batch 3 killer controls) — auto-generated.
# Source: scripts/validation/klaus_quench_batch3_gen.jl
#
# Cell : klaus_quench_omm0p5_keeprot_mirror
#   initial state         : m_minus_F   (m_sign = -F)
#   Ω/ω_⊥ scan magnitude  : -0.5
#   Ω applied in          : prep=true  quench=true  hold=true
#   DDI in dynamics       : true
#   B quench applied      : true
#   B_rot / B_final       : 0.01 G  /  2.6000000000000002e-5 G  (2.6 nT magnitude)
#   dt scale              : 1.0
#   N_atoms               : 10000
#
# mirror-pair: klaus_quench_omp0p5_keeprot.experiment.jl
#
# B_z is NEGATIVE here and positive in the partner, and that is the point.
# The chirality-reversing mirror (y -> -y) acts on EVERY axial quantity:
# L_z -> -L_z (so Omega flips), F -> mirrored (so m flips), and B is axial too
# (so B_z flips). Flipping only Omega and m gives a pair that is not a mirror.
#
# History, because this pair has been broken once already. It was a genuine
# mirror pair until 2026-07-29, when bce2068f flipped B_z on the 211 configs
# pinning m=-F and — correctly, given what it could know — left the m=+F ones
# alone. Each file was then right and the PAIR was broken: both sat at
# B_z = +0.01 G, so the sheet's "(init m x Omega sign) reversal symmetry"
# gate was comparing an uphill Zeeman cascade against a downhill one. Repaired
# 2026-08-19 (#343): the mirror ROLE recovers the intent bce2068f could not, and
# arm G of that measurement reproduced the partner to five digits.
#
# Retargeted the same day: the whole corpus moved to the ANTI-ALIGNED
# preparation, so this file now carries m=-F (highest at B_z<0) against the
# partner's m=+F (highest at B_z>0). Both ends of the mirror are anti-aligned,
# which is the only regime in which the effect being mirrored exists at all.
# Gated by test/workflow/test_mirror_pairs_flip_every_axial_quantity.jl.
#
# anti-aligned-seed: the EdH cascade only runs from the Zeeman-HIGHEST stretched
#   state. Measured 2026-08-19 (#343): rotation contrast +16.5 % anti-aligned
#   against -0.45 % aligned, and peak P_adj 0.53 against 0.24. This is the
#   standard Einstein-de Haas preparation (Kawaguchi-Saito-Ueda PRL 96, 080405).
#   Authority: docs/campaign/edh_quench_polarisation_decision.md

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 10000,
            "omega_ref" => 691.1504,
        ),
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "-0.01 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => true,
            ),
            "dt" => 0.005,
            "gauge_fix" => false,
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 12.0],
                "n" => [32, 32, 32],
            ),
            "init_sigma" => 1.5,
            "initial_state" => "m_minus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 10000,
                "c1_ratio" => 0.02778,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "n_steps" => 3000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.181818],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "-0.01 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 6.9115,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "rotating_frame_omega" => -0.5,
            "save" => Dict{String, Any}(
                "every" => 100,
                "precision" => "f64",
                "psi" => true,
            ),
            "seed_amplitude" => 1.0e-6,
            "seed_k_cut" => 2.5,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 0.6911504,
                    "from" => -0.01,
                    "to" => -2.6000000000000002e-5,
                ),
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.001,
            "duration" => 0.69115,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "rotating_frame_omega" => -0.5,
            "save" => Dict{String, Any}(
                "every" => 50,
                "precision" => "f64",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "-2.6000000000000002e-5 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 6.9115,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "rotating_frame_omega" => -0.5,
            "save" => Dict{String, Any}(
                "every" => 100,
                "precision" => "f64",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "winding_map" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        )],
    )],
)
