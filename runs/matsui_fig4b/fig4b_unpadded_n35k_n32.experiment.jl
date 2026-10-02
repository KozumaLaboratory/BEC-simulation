# UNPADDED DDI kernel — a speed/accuracy A/B against fig4b_scan_n35k_n32.experiment.jl.
#
# Zero-padding the DDI convolution costs, measured on the H100 (UGE 8318420):
# 21 % of the step at 32^3 (0.604 -> 0.477 ms) and 50 % at 128^3 (25.07 ->
# 12.50). Over this 45-point campaign that is ~19 s of the 528 s job.
#
# It is not free: unpadded is the periodic kernel, so the cloud sees its own
# images. The campaign's kernel factorial (fig4b_ddikernel_n32) put the effect
# on the dip centre at 0.0016 nT — but that was measured at N = 5e4, and this
# config runs N = 3.5e4. Whether a kernel difference transfers across a 30 %
# change in atom number is exactly the kind of assumption this campaign has been
# burned by, so it is being re-measured here rather than inherited.
#
# PREDICTION, recorded before the run: centre within 0.005 nT of the padded
# -2.5099 and width within 0.02 nT of 12.740. If the centre moves by more than
# 0.01 nT the saving is not worth taking, because the unexplained residual is
# only 0.040 nT and this would eat a quarter of it.
#
# Everything else is bit-identical to fig4b_scan_n35k_n32.experiment.jl.
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
                "padded" => false,
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
                "padded" => false,
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
            "pipeline.1.B.Bz.to" => Dict{String, Any}(
                "from" => -0.00013,
                "step" => 5.0e-6,
                "to" => 9.0e-5,
            ),
        ),
    ),
)
