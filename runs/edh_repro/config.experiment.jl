# FULL EXPERIMENT-REPRODUCTION EdH -- Julia SpinorBEC.jl side, IDENTICAL to
# config/edh_repro.nml on the Eu-Fortran side.  Parameters verified against the
# papers (Miyazawa BEC 2022, Matsui EdH Science 2026, Kawaguchi-Ueda Phys.Rep.
# 520, Goto thesis):
#   ground state at Bz = 0.3 mT = 3 G (fully polarized m=-6), sudden quench to
#   the observed weak field Bz = 2.6 nT = 26 uG (2.6e-5 G), hold 40 ms.
#   32^3->48^3? -> 48^3 / box 16 / trap (1,1,1.182) [= (110,110,130) Hz] /
#   Eu151 / N=5e4 / a_s=110 a0 / c1_ratio=1/36 (c1>0 antiferro) / DDI zero-padded
#   / no symmetry-breaking seed (DDI couples m=-6->m=-5) / f64 / save every 100.
# NOT touching any SpinorBEC.jl source -- config only.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 50000,
            "omega_ref" => 691.1504,
        ),
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_repro" => Dict{String, Any}(
            "atom" => "Eu151",
            "grid" => Dict{String, Any}(
                "box" => [16, 16, 16],
                "n" => [48, 48, 48],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.027777777777777776,
                "omega_ref" => 691.1504,
            ),
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.1818182],
                "type" => "harmonic",
            ),
        ),
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.01 Gauss",
            ),
            "cache" => "runs/edh_repro/cache/gs_3G_48.jld2",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "pad_factor" => 2.0,
                "padded" => true,
                "secular" => false,
            ),
            "init_state_params" => Dict{String, Any}(
                "init_phi" => 0.0,
                "init_theta" => 3.141592653589793,
            ),
            "initial_state" => "spin_coherent",
            "method" => "lbfgs",
            "n_steps" => 500,
            "tol" => 1.0e-9,
            "use" => ["eu151_repro"],
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "2.6e-5 Gauss",
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "pad_factor" => 2.0,
                "padded" => true,
                "secular" => false,
            ),
            "dt" => 0.001,
            "duration" => 27.646,
            "save" => Dict{String, Any}(
                "every" => 276,
                "precision" => "f32",
                "psi" => true,
            ),
            "seed_amplitude" => 0.0,
        ),
    )],
)
