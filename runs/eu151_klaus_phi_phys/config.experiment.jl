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
# ANTI-ALIGNED, via `prepare_anti_aligned: true` on the ground_state step.
#   The EdH cascade needs the Zeeman-HIGHEST stretched state, which at p > 0 is
#   m=-F. That is NOT a seed choice: ITP is a projector onto the LOWEST state, so
#   `init_m_idx: 13` gets exp(-12·p·dt) = exp(-1602) here, underflows in one step
#   and returned psi identically zero (measured 2026-08-20).
#   The preparation relaxes in the REVERSED field and reverses it back for the
#   dynamics — the Zeeman-lowest state of -B is the Zeeman-highest state of +B,
#   and it is a true ground state of the field it was relaxed in. `q` does not
#   flip; it is even in B.
#   Authority: docs/campaign/edh_quench_polarisation_decision.md
# GS in tilted-prep field. Eu mean-field; DDI auto from atom + N + ω_ref;
# LHY scalar.
# THE PREPARATION, and the one line that decides which end of the Zeeman
# ladder this run starts from. ITP relaxes at p = -26700 and the dynamics
# below runs at +26700, so the state handed over is the Zeeman-HIGHEST one
# the EdH cascade needs.
#
# History, because the shape recurs: 2026-08-19 tried `init_m_idx: 13` for
# this. The run COMPLETED and returned 212992 exact zeros with E = 0.0 —
# exp(-12·p·dt) = exp(-1602) underflows Float64 in ONE step. It was not a
# wrong configuration; it was inexpressible, and it only surfaced once the
# energy was reported at all. The underflow is now a hard error.
#
# No `init_m_idx` here on purpose: the default follows the ITP field, so it
# is already the right end. Naming it would re-introduce the coupling
# between two keys that has to agree.
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
            "init_sigma" => 1.5,
            "lhy" => Dict{String, Any}(
                "kind" => "scalar",
            ),
            "n_steps" => 1500,
            "prepare_anti_aligned" => true,
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
                        "to" => 4.524,
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
                    "rate" => 4.524,
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
    "scan" => Dict{String, Any}(
        "zip" => Dict{String, Any}(
            "pipeline.2.dynamics.B.phi.rate.to" => [1.0, 2.0, 3.0, 4.524, 6.0, 8.0, 12.0, 18.0],
            "pipeline.3.dynamics.B.phi.rate" => [1.0, 2.0, 3.0, 4.524, 6.0, 8.0, 12.0, 18.0],
        ),
    ),
)
