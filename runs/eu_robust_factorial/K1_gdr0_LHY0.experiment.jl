# Eu robust factorial — auto-generated, do not hand-edit.
# Source: scripts/validation/eu_robust_factorial_gen.jl
# See docs/validation/self_contained_validation_report.md for design.
#
# Factorial cell:
#   K3_on  = true
#   gdr_on = false
#   LHY_on = false
# CUDA loader issues that broke the GPU
# smoke run; still ~few-min per cell

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 30000,
            "omega_ref" => 628.3,
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
                "secular" => false,
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
                "N_atoms" => 30000,
                "c1_ratio" => -0.005,
                "omega_ref" => 628.3,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "n_steps" => 1500,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
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
            "dt" => 0.01,
            "duration" => 6.28,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s"],
            ),
            "save" => Dict{String, Any}(
                "every" => 50,
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
