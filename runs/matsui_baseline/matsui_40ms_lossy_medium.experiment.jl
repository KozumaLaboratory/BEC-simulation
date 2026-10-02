# Matsui 2026 Eu-151 EdH — loss-on variant (medium K3)
# Source: hand-derived from matsui_40ms_dynamics_n64.experiment.jl + eu_k3_sweep_gen.jl loss-block convention.
# Goal: bridge from loss-free EdH cascade to experimental ~40% population decay at 40 ms.
# Differs from matsui_40ms_dynamics_n64.experiment.jl only in the dynamics loss block.
#
# K3 = 30 × Dy proxy = 3.0e-40 m^6/s. Intermediate value; K3 sweep
# (cigar regime) put factor 30 between "delay" and "sacrificial".
# Matsui geometry is near-isotropic so loss strength will be different
# from cigar — this is the medium probe; pair with _strong variant.

Dict{String, Any}(
    "dealias" => Dict{String, Any}(
        "auto_dt" => true,
        "dt_safety" => 10.0,
        "enabled" => true,
        "k_cut" => 16.0,
    ),
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
                "Bz" => "0.01 Gauss",
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
                "n" => [64, 64, 64],
            ),
            "init_sigma" => 1.5,
            "initial_state" => "m_minus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.0277777778,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "n_steps" => 2000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.181818],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 0.0,
                    "from" => 0.01,
                    "to" => 2.6e-5,
                ),
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 27.646,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["3.0e-40 m^6/s", "3.0e-40 m^6/s", "3.0e-40 m^6/s", "3.0e-40 m^6/s", "3.0e-40 m^6/s", "3.0e-40 m^6/s", "3.0e-40 m^6/s", "3.0e-40 m^6/s", "3.0e-40 m^6/s", "3.0e-40 m^6/s", "3.0e-40 m^6/s", "3.0e-40 m^6/s", "3.0e-40 m^6/s"],
            ),
            "save" => Dict{String, Any}(
                "every" => 200,
                "precision" => "f64",
                "psi" => true,
            ),
            "seed_amplitude" => 1.0e-6,
            "seed_k_cut" => 2.5,
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
