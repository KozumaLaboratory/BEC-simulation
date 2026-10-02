# ─────────────────────────────────────────────────────────────────────
#  Eu151 Barnett-effect spin pumping at K3_long-level weak Bz
#
#  Klaus 1G run (rotating_basis + loss) showed: secular DDI structurally
#  zeros the spin-orbit coupling channel, no Barnett pumping at any time.
#  Berry connection alone gives mixing only at A/p ~ 1.7e-4 (saturated
#  not growing).
#
#  Fix: drop Bz to K3_long level (2.6 nT, p ≈ 0.69, p·F/c_dd·n ratio
#  ~17 ≪ secular advisory threshold of 100). At this Bz the full DDI
#  off-diagonal F_+L_- + F_-L_+ exchange channel is ACTIVE — same regime
#  where K3_long showed EdH vortex tower formation. Adding rotation
#  injects definite Lz; with off-diagonal DDI on the rotation direction
#  biases the spin pumping direction.
#
#  Spinor path (kind: spinor) because rotating_basis at p < 100 has no
#  speed advantage and the gauge connection is the wrong frame choice
#  when Larmor isn't dominant. Cartesian Bx/By/Bz with sinusoidal time
#  dependence drives the stir.
#
#  Tilt 35° at total B_mag = 2.6e-5 G:
#    B_z = 2.6e-5 · cos(35°) = 2.13e-5 G   (constant)
#    B_x = 2.6e-5 · sin(35°) · cos(Ω·t) = 1.49e-5 G · cos(Ω·t)
#    B_y = 2.6e-5 · sin(35°) · sin(Ω·t) = 1.49e-5 G · sin(Ω·t)
#
#  Sinusoidal frequency = Ω/(2π) (waveform is sin(2π·freq·t + phase)).
#  Sign of freq flips rotation direction (CCW ↔ CW).
#
#  Time scales (ω_ref = 691.15, 1 ω⁻¹ ≈ 1.45 ms):
#    Larmor at p=0.69: T_L = 2π/0.69 ≈ 9 ω⁻¹
#    EdH (from K3_long): τ_EdH ≈ 4 ω⁻¹
#    Stir Ω = ±0.5: T_stir = 2π/0.5 ≈ 12.6 ω⁻¹ (slightly slower than Larmor → adiabatic)
#
#  Scan zip (2 points first cut, sign-asymmetry test):
#    Ω = +0.5  → CCW slow stir
#    Ω = -0.5  → CW slow stir
#
#  Loss: same as K3_long — K3 1e-41 m^6/s × 13 components + gamma_dr 0.02,
#  LHY scalar. This is the proven EdH-active dissipation channel.
# ─────────────────────────────────────────────────────────────────────
# Phase 0: m=+F stretched GS at strong prep Bz = 0.01 G = 1 μT.
# Same as K3_long Phase 0 — ensures clean m=+F start.
# Phase 1: rapid Bz quench 1.0 μT → 2.13e-5 G (= weak hold field's
# z component for 35° tilt) over 0.14 ω⁻¹ ≈ 0.20 ms. Same protocol
# shape as K3_long Phase 1.
# Phase 2: weak-field rotating B + loss. Cartesian tilted-rotating
# B field at full amplitude (no smooth ramp — instant-on at t=0+).
# 30 ω⁻¹ ≈ 43 ms covers ~10 EdH timescales and ~3 stir periods.
# phase choice: at t=0, B_perp = (+amp, 0) along +x.
#   Bx = amp·sin(Ωt + π/2) = amp·cos(Ωt)
#   By = amp·sin(Ωt)

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 10000,
            "omega_ref" => 691.15,
        ),
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_phys" => Dict{String, Any}(
            "atom" => "Eu151",
            "grid" => Dict{String, Any}(
                "box" => [20, 20, 20],
                "n" => [32, 32, 32],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 10000,
                "c1_ratio" => 0.0,
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
            ),
            "dt" => 0.005,
            "initial_state" => "m_plus_F",
            "lhy" => Dict{String, Any}(
                "kind" => "scalar",
            ),
            "n_steps" => 3000,
            "tol" => 1.0e-9,
            "use" => ["eu151_phys"],
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 0.14,
                    "from" => 0.01,
                    "to" => 2.13e-5,
                ),
            ),
            "dt" => 0.0005,
            "duration" => 0.14,
            "save" => Dict{String, Any}(
                "every" => 280,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bx" => Dict{String, Any}(
                    "sinusoidal" => Dict{String, Any}(
                        "amplitude" => 1.49e-5,
                        "frequency" => 0.0,
                        "phase" => 1.5707963267948966,
                    ),
                ),
                "By" => Dict{String, Any}(
                    "sinusoidal" => Dict{String, Any}(
                        "amplitude" => 1.49e-5,
                        "frequency" => 0.0,
                        "phase" => 0.0,
                    ),
                ),
                "Bz" => "2.13e-5 Gauss",
            ),
            "dt" => 0.0001,
            "duration" => 30.0,
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s", "1.0e-41 m^6/s"],
                "gamma_dr" => 0.02,
            ),
            "save" => Dict{String, Any}(
                "every" => 1000,
            ),
        ),
    )],
    "scan" => Dict{String, Any}(
        "zip" => Dict{String, Any}(
            "pipeline.2.dynamics.B.Bx.sinusoidal.frequency" => [0.0795775, -0.0795775],
            "pipeline.2.dynamics.B.By.sinusoidal.frequency" => [0.0795775, -0.0795775],
        ),
    ),
)
