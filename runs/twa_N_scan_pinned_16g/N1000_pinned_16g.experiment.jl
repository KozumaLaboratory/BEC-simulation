# Sinatra-clean 1/N TWA validity test: N=1000 with c_total / c_dd PINNED
# at the Eu N=10⁴ baseline AND grid coarsened to 16³ × box=10.
#
# Resolution preservation: dx = 10/16 = 0.625 a_ho, identical to the
# original 32³ × box=20 setup (20/32 = 0.625). The cloud's z-elongated
# filament (FWHM_z ≈ 3.75 a_ho from the deterministic EdH baseline) fits
# in the smaller box (3.75 / 10 ≈ 38% of box), so the ground-state
# physics is preserved while the Sinatra ratio drops 8× from 425k modes
# to 53k modes per spinor.
#
# Sinatra ratio at N=1000: 16³ × 13 / 1000 = 53.2 (still in danger zone
# — this point will probe how σ/μ behaves at high contamination AT this
# grid).

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "omega_ref" => 691.15,
        ),
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_edh_phys_pinned_16g" => Dict{String, Any}(
            "atom" => "Eu151",
            "grid" => Dict{String, Any}(
                "box" => [10, 10, 10],
                "n" => [16, 16, 16],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 1000,
                "c1_ratio" => 0.0,
                "c_total" => 937.453,
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
            "ddi" => Dict{String, Any}(
                "c_dd" => 42.204,
            ),
            "dt" => 0.005,
            "initial_state" => "m_plus_F",
            "lhy" => Dict{String, Any}(
                "kind" => "scalar",
            ),
            "n_steps" => 3000,
            "tol" => 1.0e-9,
            "use" => ["eu151_edh_phys_pinned_16g"],
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 0.14,
                    "from" => 0.01,
                    "to" => 2.6e-5,
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
                "Bz" => "2.6e-5 Gauss",
            ),
            "dt" => 0.0001,
            "duration" => 1.0,
            "twa" => Dict{String, Any}(
                "cutoff_energy" => 6.0,
                "n_trajectories" => 50,
                "observables" => ["density", "magnetization", "component_density"],
                "seed_base" => 42,
            ),
        ),
    )],
)
