# Watch vortices enter: stir the weak-field Eu texture with a ROTATING
# transverse field and film it.
#
# Why this and not the B quench (config_texture_quench_movie.experiment.jl): an
# instantaneous 100 -> 20 µG jump changes bz by ~1.2, and with F = 6 that is an
# energy of order 7 against µ = 7.7 — the whole condensate's worth, dumped in one
# step. Measured result: the cloud goes phase-turbulent, and the defect count is
# almost entirely threshold — 170 defects at a 1% density floor, 6 at 30%. You
# cannot watch vortices form in that.
#
# A rotating b_perp injects angular momentum gradually instead, which is the
# classic nucleation route and the knob this repo already has evidence for
# (project_eu_adiabatic_protocol: a rotating b_perp opens the J_z sector).
#
#   Bx = A·sin(Ωt + π/2) = A·cos(Ωt)
#   By = A·sin(Ωt)
#
# so b_perp starts along +x and rotates in the +φ sense for Ω > 0. NOTE
# `SinusoidalWaveform` is **sin**, not cos — the π/2 phase on Bx is what makes
# this a rotation starting on the x axis rather than a different initial
# condition (memory: the Barnett chirality arms were not mirror images because
# this was assumed to be cos).
#
# Ω = 0.5 (dimensionless) → frequency = Ω/2π = 0.0795775, the same stir rate the
# Barnett runs used. Period 2π/Ω = 12.6, so 20 time units is ~1.6 turns. Larmor
# at bz ≈ -1.48 has period ~4.2, i.e. FAST compared to the stir: the spin follows
# the field adiabatically, which is the regime where the transfer happens.
#
# Bz is held at the ground state's own 100 µG, so there is no quench and the
# ground_state block is byte-identical to the quench config — the GS stage cache
# hits and only the dynamics is recomputed.
#
# `dealias` OFF, with the same open question as config_texture_quench_movie.experiment.jl
# — with it on this cell loses 94% of its norm in 20 steps, but the filter is an
# exact projector, so that number may be measuring the dynamics rather than a
# bug. Not settled; quote `norm_rel_drift` with anything taken from this run.

Dict{String, Any}(
    "dealias" => Dict{String, Any}(
        "enabled" => false,
    ),
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "1.0e-4 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 24.0],
                "n" => [32, 32, 64],
            ),
            "initial_state" => "flower",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.0,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "full_bdg",
            ),
            "m_lbfgs" => 20,
            "method" => "lbfgs",
            "n_steps" => 1500,
            "newton_polish" => true,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-6,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bx" => Dict{String, Any}(
                    "sinusoidal" => Dict{String, Any}(
                        "amplitude" => 3.0e-5,
                        "frequency" => 0.0795775,
                        "phase" => 1.5707963267948966,
                    ),
                ),
                "By" => Dict{String, Any}(
                    "sinusoidal" => Dict{String, Any}(
                        "amplitude" => 3.0e-5,
                        "frequency" => 0.0795775,
                        "phase" => 0.0,
                    ),
                ),
                "Bz" => "1.0e-4 Gauss",
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.0005,
            "duration" => 20.0,
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "full_bdg",
            ),
            "save" => Dict{String, Any}(
                "every" => 200,
            ),
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "vortex_density_movie" => Dict{String, Any}(
                "axis" => 3,
                "output_dir" => "figs/eu_texture_stir_movie",
            ),
        )],
    )],
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
