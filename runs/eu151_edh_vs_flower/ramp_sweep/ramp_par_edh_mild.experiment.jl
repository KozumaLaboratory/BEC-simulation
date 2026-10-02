# Mild parabolic EdH ramp — Goto difference-imaging checkerboard-inversion probe.
#
# Designed 2026-07-23. Goal: a parabolic Bz ramp gentler than the flower-forming
# one (ramp_par_flower120 = parabola -> 120 uG + seed => adiabatic flower texture,
# symmetric difference image, NO checkerboard). Here the same parabolic SHAPE ends
# at the mild 26 uG endpoint (proven from ramp_par_T90), keeping the cloud in the
# EdH regime, then HOLDS at 26 uG long enough — finely sampled — to watch the Goto
# difference-image checkerboard (transverse <Fx> texture) Larmor-precess and INVERT.
#
# Physics sizing: at 26 uG the transverse-spin Larmor rate p = gF*uB*B/(hbar*w_ref)
# ~ 0.385 per w^-1  =>  precession period ~16 w^-1, checkerboard sign-flip every
# ~8 w^-1 (half period). The 60 w^-1 hold sampled every 1.0 w^-1 (every 500 steps)
# therefore captures ~3-4 full inversions with ~16 points/period.
#
# Discriminator: EdH  => difference image (dif_col, odd-in-theta) shows an
# alternating (checkerboard) sign pattern that INVERTS in time  =>  asym < 0.
#          flower => sum-in-theta (<Fz>) dominates, symmetric, no inversion => asym > 0.
# EdH starts from a FULLY POLARIZED m=−6 stretched state. The GS field carries
# q=0 (explicit) so the linear Zeeman alone makes m=−6 the ground state — without
# this the auto-derived quadratic Zeeman q(∝|B|²) at 10 mG dominates and the
# default initial_state=:polar (m=0) gets stuck at m=0 (Fz|0⟩=0 ⇒ no gradient).
# initial_state=:m_minus_F seeds the stretched state directly. Dynamics keep the
# physical auto-q.
# --- parabolic ramp: 10 mG -> 26 uG over 90 w^-1 (decelerating at the low-field
#     end; identical profile to the proven ramp_par_T90) ---
# --- HOLD at 26 uG, finely sampled (every 1.0 w^-1) to resolve the checkerboard
#     inversion over ~3-4 Larmor periods ---

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
                    "piecewise" => Dict{String, Any}(
                        "times" => [0.0, 5.625, 11.25, 16.875, 22.5, 28.125, 33.75, 39.375, 45.0, 50.625, 56.25, 61.875, 67.5, 73.125, 78.75, 84.375, 90.0],
                        "values" => [0.01, 0.0087922109375, 0.00766234375, 0.0066103984375, 0.005636375, 0.0047402734375, 0.00392209375, 0.0031818359375, 0.0025195, 0.0019350859375, 0.00142859375, 0.0010000234375, 0.000649375, 0.0003766484375, 0.00018184375, 6.49609375e-5, 2.6e-5],
                    ),
                ),
            ),
            "dt" => 0.002,
            "duration" => 90.0,
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s", "2.1e-41 m^6/s"],
            ),
            "save" => Dict{String, Any}(
                "every" => 1125,
                "precision" => "f32",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "2.6e-5 Gauss",
            ),
            "dt" => 0.002,
            "duration" => 60.0,
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
