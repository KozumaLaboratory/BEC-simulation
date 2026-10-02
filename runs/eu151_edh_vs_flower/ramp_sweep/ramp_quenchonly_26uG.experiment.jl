# PURE QUENCH to 26 uG — the Matsui-style protocol, for direct comparison against
# our quench+parabola (ramp_quench500_par.experiment.jl).
#
#   GS (m=-6, 10 mG, q=0)  ->  quench 10 mG -> 26 uG (4 w^-1 = 5.8 ms)  ->  hold 26 uG (80 w^-1 = 116 ms)
#
# Everything else is identical to ramp_quench500_par.experiment.jl: same atom, grid, trap,
# c1_ratio = 1/36, K3, seed, secular:false, and the SAME ground-state cache (so the GS
# is loaded instantly). Total sequence 121 ms, matching the quench+parabola run, so the
# two can be overlaid on a common time axis.
#
# psi snapshots ON: <Lz>(t) has to be computed from the wavefunction.
# --- phase A: full quench 10 mG -> 26 uG (no intermediate parabola at all) ---
# --- phase B: hold at 26 uG + symmetry-breaking seed (same seed as the comparison run) ---

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
                "n" => [64, 64, 64],
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
                "q" => 0.0,
            ),
            "cache" => "runs/eu151_edh_vs_flower/cache/gs_10mG_polm6_64.jld2",
            "initial_state" => "m_minus_F",
            "method" => "lbfgs",
            "n_steps" => 800,
            "tol" => 1.0e-8,
            "use" => ["eu151_edh_phys"],
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 4.0,
                    "from" => 0.01,
                    "to" => 2.6e-5,
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
                "Bz" => "2.6e-5 Gauss",
            ),
            "ddi" => Dict{String, Any}(
                "secular" => false,
            ),
            "dt" => 0.002,
            "duration" => 80.0,
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
