# Klaus-II adiabatic prototype — addresses the null result of the sudden-tilt
# Klaus-II batch.  In the sudden-tilt version (theta jumps 0 → π/4 at hold
# start), the spin failed to track the new B direction, so DDI anisotropy
# rotation had no spin sector to act on.  Here we ramp theta slowly at
# strong B (where ω_L ≫ dθ/dt), let the spin polarisation track the B
# direction, then ramp phi rate up, then quench to weak field with rotation
# preserved.  If the spin co-rotates with B through the quench, the
# weak-field hold should see a genuine rotating-DDI-axis drive.
#
# 6-stage dynamics pipeline:
#   1. GS at z-aligned strong B  (m=+F polarised along +z)
#   2. tilt-up   : theta 0 → π/4 over 5 ms, B_mag = 0.01 G, phi=0
#   3. spin-up   : phi rate 0 → +0.5 over 5 ms at theta = π/4
#   4. steady    : theta = π/4, phi rate = +0.5, 5 ms
#   5. B quench  : B_mag 0.01 → 2.6e-5 G over 1 ms, theta + phi rate preserved
#   6. hold      : B_mag = 2.6e-5 G, theta = π/4, phi rate = +0.5, 10 ms
#
# Matched chirality with m=+F initial state ⇒ Ω = +0.5 (per Gate 4).
# If P_{+5,+4} > Klaus-II sudden-tilt value (0.219), adiabatic ramp works.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 10000,
            "omega_ref" => 691.1504,
        ),
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "B_mag" => "0.01 Gauss",
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
                "n" => [32, 32, 32],
            ),
            "init_sigma" => 1.5,
            "initial_state" => "m_plus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 10000,
                "c1_ratio" => 0.02778,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "n_steps" => 3000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.181818],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "B_mag" => "0.01 Gauss",
                "phi" => 0.0,
                "theta" => Dict{String, Any}(
                    "duration" => 3.456,
                    "from" => 0.0,
                    "to" => 0.7854,
                ),
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 3.456,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "save" => Dict{String, Any}(
                "every" => 100,
                "precision" => "f64",
                "psi" => true,
            ),
            "seed_amplitude" => 1.0e-6,
            "seed_k_cut" => 2.5,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "B_mag" => "0.01 Gauss",
                "phi" => Dict{String, Any}(
                    "rate" => Dict{String, Any}(
                        "duration" => 3.456,
                        "from" => 0.0,
                        "to" => 0.5,
                    ),
                ),
                "theta" => 0.7854,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 3.456,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "save" => Dict{String, Any}(
                "every" => 100,
                "precision" => "f64",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "B_mag" => "0.01 Gauss",
                "phi" => Dict{String, Any}(
                    "rate" => 0.5,
                ),
                "theta" => 0.7854,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 3.456,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "save" => Dict{String, Any}(
                "every" => 100,
                "precision" => "f64",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "B_mag" => Dict{String, Any}(
                    "duration" => 0.691,
                    "from" => 0.01,
                    "to" => 2.6e-5,
                ),
                "phi" => Dict{String, Any}(
                    "rate" => 0.5,
                ),
                "theta" => 0.7854,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.001,
            "duration" => 0.691,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "save" => Dict{String, Any}(
                "every" => 50,
                "precision" => "f64",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "B_mag" => "2.6e-5 Gauss",
                "phi" => Dict{String, Any}(
                    "rate" => 0.5,
                ),
                "theta" => 0.7854,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 6.9115,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "save" => Dict{String, Any}(
                "every" => 100,
                "precision" => "f64",
                "psi" => true,
            ),
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
