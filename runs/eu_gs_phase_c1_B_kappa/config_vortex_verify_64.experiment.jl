# VERIFY the discovered coreless/polar-core VORTEX is the true GS (not a seed-
# trapped metastable). At the 3 orphan cells (physical Eu, mid-B/high-κ) run 4
# DIVERSE seeds FROM SCRATCH (no seed_from bias) + pin ε-continuation, take min-E.
# If the vortex seed wins converged, the vortex is the GS. Pair with the 48³
# variant for lattice-independence.
#   3 cells × 4 seeds = 12 solves @ 64³.

Dict{String, Any}(
    "dealias" => Dict{String, Any}(
        "auto_dt" => true,
        "dt_safety" => 10.0,
        "enabled" => true,
        "k_cut" => 10.0,
    ),
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.0 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.002,
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 12.0],
                "n" => [64, 64, 64],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.0277777778,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "method" => "itp",
            "n_steps" => 4000,
            "noise" => Dict{String, Any}(
                "initial" => Dict{String, Any}(
                    "thermal" => 0.4,
                ),
                "seed" => 20260724,
            ),
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-7,
        ),
    ), Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "m_lbfgs" => 20,
            "method" => "lbfgs",
            "n_steps" => 800,
            "pin" => Dict{String, Any}(
                "epsilon_ramp" => [0.004, 0.002, 0.001, 0.0005],
                "kind" => "transverse",
            ),
            "tol" => 1.0e-7,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify_distance" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "multipole_order" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "majorana_order" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        )],
    )],
    "scan" => Dict{String, Any}(
        "comparison_runs" => [Dict{String, Any}(
            "name" => "vortex",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar_core_vortex",
            ),
        ), Dict{String, Any}(
            "name" => "flower",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "flower",
            ),
        ), Dict{String, Any}(
            "name" => "polar",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
            ),
        ), Dict{String, Any}(
            "name" => "fm",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "m_plus_F",
            ),
        )],
        "zip" => Dict{String, Any}(
            "pipeline.0.B.Bz" => ["2.5e-5 Gauss", "4.8e-5 Gauss", "7.5e-5 Gauss"],
            "pipeline.0.potential.omega.2" => [1.3, 1.6, 2.2],
        ),
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
