# Barnett ladder Week 1 — scalar rotation benchmark.
# Source: scripts/validation/barnett_week1_gen.jl
# Ω = 0.3  (rotating-frame angular velocity, in units of ω_ref).
# 2D-like anisotropic trap (pancake). The y/x slight anisotropy
# breaks rotation symmetry → vortex formation possible at large Ω.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 5000,
            "omega_ref" => 100.0,
        ),
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => 0.0,
            ),
            "atom" => "Rb87",
            "ddi" => Dict{String, Any}(
                "enabled" => false,
            ),
            "dt" => 0.01,
            "grid" => Dict{String, Any}(
                "box" => [10.0, 10.0, 10.0],
                "n" => [32, 32, 32],
            ),
            "init_sigma" => 1.5,
            "initial_state" => "m_plus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 5000,
                "c1_ratio" => 0.0,
                "omega_ref" => 100.0,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "n_steps" => 2000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.05, 4.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "ddi" => Dict{String, Any}(
                "enabled" => false,
            ),
            "dt" => 0.005,
            "duration" => 20.0,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "rotating_frame_omega" => 0.3,
            "save" => Dict{String, Any}(
                "every" => 200,
                "precision" => "f64",
                "psi" => true,
            ),
            "seed_amplitude" => 1.0e-5,
            "seed_k_cut" => 2.5,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        )],
    )],
)
