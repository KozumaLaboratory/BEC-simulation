# c1=0 ABLATION of the quench-then-parabolic EdH run (2026-07-24).
# Purpose: test the hypothesis that the clean 38 ms checkerboard inversion is a
# c1 (contact spin-mixing) effect vs a pure-DDI effect.
#
# CLEAN isolation of c1: we set c_total=2343.5, c1_ratio=0  =>  c0=2343.5, c1=0.
# The baseline quench run has c_total=4687, c1_ratio=1/36 => c0=2343.5, c1=65.1.
# So c0 (spin-INDEPENDENT density interaction) is IDENTICAL to the baseline; only c1
# (spin-mixing) is removed. The density profile is therefore unchanged and any change
# in the spin texture / inversion is attributable to c1 alone (not to a density shift).
# DDI (c_dd from the Eu151 moment) is unchanged and still ON.
#
# Everything else (grid, trap, N, ramp schedule, K3, seed) is identical to
# ramp_quench500_par.experiment.jl so the two runs are directly comparable.
# GS cache is a SEPARATE file (the c1=0 ground state differs from c1=1/36).
# --- phase A: fast quench 10 mG -> 500 uG (inert region; m=-6 unchanged) ---
# --- phase B: parabolic 500 uG -> 26 uG over 19.62 w^-1 (same rate as pure tail) ---
# --- phase C: hold at 26 uG + symmetry-breaking seed ---

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
        "eu151_edh_phys_c1zero" => Dict{String, Any}(
            "atom" => "Eu151",
            "grid" => Dict{String, Any}(
                "box" => [18, 18, 18],
                "n" => [64, 64, 64],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.0,
                "c_total" => 2343.5,
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
                "q" => 0.0,
            ),
            "cache" => "runs/eu151_edh_vs_flower/cache/gs_10mG_polm6_64_c1zero.jld2",
            "initial_state" => "m_minus_F",
            "method" => "lbfgs",
            "n_steps" => 800,
            "tol" => 1.0e-8,
            "use" => ["eu151_edh_phys_c1zero"],
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 4.0,
                    "from" => 0.01,
                    "to" => 0.0005,
                ),
            ),
            "ddi" => Dict{String, Any}(
                "secular" => false,
            ),
            "dt" => 0.002,
            "duration" => 4.0,
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s"],
            ),
            "save" => Dict{String, Any}(
                "every" => 500,
                "precision" => "f32",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "piecewise" => Dict{String, Any}(
                        "times" => [0, 1.962, 3.924, 5.886, 7.848, 9.81, 11.772, 13.734, 15.696, 17.658, 19.62],
                        "values" => [0.0005, 0.00040994, 0.00032936, 0.00025826, 0.00019664, 0.0001445, 0.00010184, 6.866e-5, 4.496e-5, 3.074e-5, 2.6e-5],
                    ),
                ),
            ),
            "ddi" => Dict{String, Any}(
                "secular" => false,
            ),
            "dt" => 0.002,
            "duration" => 19.62,
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s"],
            ),
            "save" => Dict{String, Any}(
                "every" => 500,
                "precision" => "f32",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "2.6e-5 Gauss",
            ),
            "ddi" => Dict{String, Any}(
                "secular" => false,
            ),
            "dt" => 0.002,
            "duration" => 60.0,
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s"],
            ),
            "noise_seed" => 42,
            "save" => Dict{String, Any}(
                "every" => 500,
                "precision" => "f32",
                "psi" => true,
            ),
            "seed_amplitude" => 1.0e-8,
            "seed_k_cut" => 2.5,
        ),
    )],
)
