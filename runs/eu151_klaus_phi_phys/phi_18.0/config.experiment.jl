# ─────────────────────────────────────────────────────────────────────
#  Eu151 Klaus magnetostir × phi_omega scan — Eu physics on (long)
#
#  Klaus protocol (tilt 35° → spinup 226 Hz → steady stir) with full
#  Eu mean-field (c1 ≠ 0, DDI on, LHY scalar). 32 × 32 × 16, 1 s steady
#  stir per phi_omega point. ε = 1e-6 mandatory in the Klaus regime.
#
#  Times in ω_ref⁻¹ units (ω_ref = 2π·50 rad/s ⇒ 1 ω⁻¹ ≈ 3.183 ms):
#    tilt 20 ms     ≈  6.28 ω⁻¹
#    spinup 50 ms   ≈ 15.71 ω⁻¹
#    steady 1000 ms ≈ 314.16 ω⁻¹
#
#  Mixin only seeds the GS step (grid / atom / interactions / potential
#  / gauge_fix); dynamics steps inherit the workspace built by GS so
#  they don't carry a `use:` line — DYNAMICS_SCHEMA rejects grid/atom
#  fields that the mixin would otherwise drop into them.
# ─────────────────────────────────────────────────────────────────────
# GS in tilted-prep field. Eu mean-field; DDI auto from atom + N + ω_ref;
# LHY scalar.
# tilt 0 → 35° over ≈ 20 ms (6.28 ω⁻¹)
# spinup 0 → stir freq over ≈ 50 ms (15.71 ω⁻¹)
# steady stir 1 s ≈ 314.16 ω⁻¹ — vortex-lattice evolution past formation

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "rotating_basis",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_klaus_phys" => Dict{String, Any}(
            "atom" => "Eu151",
            "gauge_fix" => false,
            "grid" => Dict{String, Any}(
                "box" => [20.0, 20.0, 10.0],
                "n" => [32, 32, 16],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 60000,
                "c1" => 131.3,
                "omega_ref" => 314.159,
            ),
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 2.6],
                "type" => "harmonic",
            ),
        ),
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 26700.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
            ),
            "dt" => 0.005,
            "init_m_idx" => 1,
            "init_sigma" => 1.5,
            "lhy" => Dict{String, Any}(
                "kind" => "scalar",
            ),
            "n_steps" => 1500,
            "tol" => 1.0e-9,
            "use" => ["eu151_klaus_phys"],
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "phi" => Dict{String, Any}(
                    "rate" => 0.0,
                ),
                "theta" => Dict{String, Any}(
                    "duration" => 6.28,
                    "from" => 0.0,
                    "to" => 0.611,
                ),
            ),
            "dt" => 0.001,
            "duration" => 6.28,
            "epsilon" => 1.0e-6,
            "integrator" => "yoshida4",
            "save" => Dict{String, Any}(
                "every" => 200,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "phi" => Dict{String, Any}(
                    "rate" => Dict{String, Any}(
                        "duration" => 15.71,
                        "from" => 0.0,
                        "to" => 18.0,
                    ),
                ),
                "theta" => 0.611,
            ),
            "dt" => 0.001,
            "duration" => 15.71,
            "epsilon" => 1.0e-6,
            "integrator" => "yoshida4",
            "save" => Dict{String, Any}(
                "every" => 200,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "phi" => Dict{String, Any}(
                    "rate" => 18.0,
                ),
                "theta" => 0.611,
            ),
            "dt" => 0.001,
            "duration" => 314.16,
            "epsilon" => 1.0e-6,
            "integrator" => "yoshida4",
            "save" => Dict{String, Any}(
                "every" => 500,
            ),
        ),
    )],
)
