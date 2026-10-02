# ─────────────────────────────────────────────────────────────────────
#  Eu151 Klaus magnetostir × ±phi_omega × K3 + γ_dr — Barnett spin pumping
#
#  Hypothesis (user's framing): rotating B in the Klaus regime
#  (strong static Bz + tilt + steady stir) injects orbital angular
#  momentum via the Berry connection. With dissipation enabled (K3 +
#  γ_dr + LHY scalar), the orbital sector drains into the spin sector
#  via DDI exchange, producing a net Barnett magnetization. Sign of
#  ⟨F_z⟩ drift should follow rotation direction (+φ vs -φ).
#
#  Exactly the eu151_klaus_phi_phys setup (rotating_basis, p=26700,
#  tilt 35°, 1 s steady stir, 32×32×16, yoshida4) PLUS a loss block on
#  the steady-stir step. Loss support in rotating_basis was added
#  2026-05-15: K3 / γ_dr act on |ψ̃|² (basis-invariant) so the spinor-
#  path apply_loss_step! works directly on ψ̃. Strang sandwiches the
#  loss around the unitary core; Y4 handles loss at the macro-step
#  level (avoiding negative-w₀ anti-loss).
#
#  Scan: ±phi pair only (fastest demo of sign-asymmetry). Both run
#  in parallel; ~7h each based on klaus_phi batch-2 timing.
# ─────────────────────────────────────────────────────────────────────
# GS in tilted-prep field (Klaus regime). Eu mean-field (DDI auto + LHY scalar).
# Tilt 0 → 35° over ≈ 20 ms (6.28 ω⁻¹). No loss yet — pure unitary
# tilt to align ψ with the new B direction.
# Spinup 0 → stir freq over ≈ 50 ms (15.71 ω⁻¹). Still no loss.
# Steady stir 5 s ≈ 1570.8 ω⁻¹ — Barnett demo + relaxation timescale scan.
# 1s pilot showed ΔFz(±φ) ~ 5e-4 oscillation, not clear signal. 5s covers
# ~5 candidate EdH-suppressed-relaxation periods so we can locate the
# crossover where coherent oscillation thermalises into Fz sign-asymmetry.
# save_every=2000 → ~785 snapshots × 1.7 MB ≈ 1.3 GB per run.

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
            "duration" => 1570.8,
            "epsilon" => 1.0e-6,
            "integrator" => "yoshida4",
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s"],
                "gamma_dr" => 0.02,
            ),
            "save" => Dict{String, Any}(
                "every" => 2000,
            ),
        ),
    )],
    "scan" => Dict{String, Any}(
        "zip" => Dict{String, Any}(
            "pipeline.2.dynamics.B.phi.rate.to" => [4.524, -4.524],
            "pipeline.3.dynamics.B.phi.rate" => [4.524, -4.524],
        ),
    ),
)
