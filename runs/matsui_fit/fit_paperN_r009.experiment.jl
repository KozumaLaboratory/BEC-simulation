# c1_ratio = 0.1111111111111111 at the PAPER's atom number N = 5e4 — arm 3 of 5.
#
# Redo of the earlier c1_ratio scan, which ran at N = 3.5e4 (their shipped code's
# Ntot) and was interpreted against the wrong targets. The paper states the trap
# held ~5e4 atoms with a negligible thermal component, so 5e4 is the setting for
# anything experiment-facing.
#
# IS c1_ratio FREE? Partly. The paper fixes c0 = 2*pi*hbar^2*a12/M and
# c1 = (1/18)*pi*hbar^2*a12/M, i.e. r = 1/36, "determined to best reproduce the
# observed spatial profiles". But the discriminator was the RING COUNT in the
# m = -4 component: c1 ~ 0 and c1 < 0 give two rings, the experiment shows three.
# That constrains the sign and the order of magnitude; it does not single out
# 1/36 among the values that also give three rings. The c0/c1 truncation is
# itself declared an approximation ("for simplicity"), and six of Eu's seven
# scattering channels remain unmeasured.
#
# WHAT THIS CAN AND CANNOT MEASURE. The dip CENTRE cannot be used: the Fig. 4
# caption states the field axis carries "an offset error of up to 10 nT", which
# is 250x the residual the campaign chased. The usable observables are the
# half-depth WIDTH (experiment 11.800 +- 0.279 on the matched window) and the dip
# DEPTH (0.3148 +- 0.0046) — both ratios, immune to the field offset.
#
# Caveat on the depth: the published theory curve is the IN-SITU population while
# the experimental points are taken after a 0.1 mT ramp, 2.7 ms expansion,
# Stern-Gerlach and 16 ms of free fall, and the paper attributes 38 percent of
# atom loss over 40 ms to spin-dependent three-body collisions this loss-free
# model does not contain. A depth mismatch is expected and is not a clean
# constraint on c1.
#
# Primary-source parameters: docs/validation/matsui_experiment_parameters.md
#
# N_atoms is patched in all three places; c1_ratio in both.
# metadata（旧 top-level キー、9e5d7c8c で schema から削除。参照されないためコメント化）:
# suite: matsui_fig4b
# ladder_level: 12
# reference: Matsui_2025_EdH_Zenodo_17303925
# claim_type: C
# target: fit_paperN_r009
# grid_n: 32
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
                "c1_ratio" => 0.1111111111111111,
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
                "N_atoms" => 50000,
                "c1_ratio" => 0.1111111111111111,
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
            "pipeline.1.B.Bz.to" => Dict{String, Any}(
                "from" => -0.00013,
                "step" => 5.0e-6,
                "to" => 9.0e-5,
            ),
        ),
    ),
)
