# ─────────────────────────────────────────────────────────────────────────
#  JULIA (SpinorBEC.jl) vs FORTRAN (Eu-Fortran) quantitative cross-check.
#  IDENTICAL run to config/cmp_jl_10mG_32.nml on the Fortran side:
#    - Ground state at Bz = 10 mG (0.01 G), fully polarized m=-6.
#    - Sudden quench to Bz = 26 uG (2.6e-5 G) at t=0, hold, evolve 40 ms
#      (internal duration = 40e-3 * omega_ref[691.15] = 27.646).
#    - 32^3 / box 18 / trap (1,1,1.182) / Eu151 / N=5e4 / a_s=110 / c1=1/36.
#    - DDI: zero-padded (fully aperiodic), pad_factor 2 -- matches Fortran.
#    - No symmetry-breaking seed (DDI itself couples m=-6 -> m=-5), matching the
#      unseeded Fortran run, for an apples-to-apples numerical comparison.
#    - Save psi every 100 steps in f64, so analysis/standard.py sees identical
#      frame cadence.  NOT touching any SpinorBEC.jl source -- config only.
# ─────────────────────────────────────────────────────────────────────────
# --- Ground state at 10 mG (fully polarized m=-6) ---
# --- Sudden quench to 26 uG, hold, evolve 40 ms ---

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 50000,
            "omega_ref" => 691.15,
        ),
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_edh_phys" => Dict{String, Any}(
            "atom" => "Eu151",
            "grid" => Dict{String, Any}(
                "box" => [18, 18, 18],
                "n" => [32, 32, 32],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.027777777777777776,
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
            "cache" => "runs/cmp_fortran_10mG_32/cache/gs_10mG_32.jld2",
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
            "n_steps" => 400,
            "tol" => 1.0e-9,
            "use" => ["eu151_edh_phys"],
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
                "every" => 100,
                "precision" => "f64",
                "psi" => true,
            ),
            "seed_amplitude" => 0.0,
        ),
    )],
)
