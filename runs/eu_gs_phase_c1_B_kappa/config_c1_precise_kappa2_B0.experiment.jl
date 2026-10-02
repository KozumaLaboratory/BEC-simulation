# Extend the c1*(κ) first-order line to MORE OBLATE traps (κ=ω_z ∈ {2.0, 2.5}) to
# test whether the order-parameter jump Δm_F keeps shrinking to 0 — i.e. whether a
# TRICRITICAL POINT κ_tc sits above 1.5, where the c1-driven FM->polar transition
# turns continuous. κ=0.5/1.0/1.5 already gave Δm_F = 0.684/0.628/0.576 (shrinking)
# with c1* = 0.0262/0.0278/0.0288 (rising, decelerating). c1 window [0.026,0.034]
# brackets the extrapolated c1*≈0.029-0.030 for both κ with margin and captures the
# pre-jump softening. 0.0005 step, two bare seeds, newton_polish + tol 1e-9. Grid/box
# match the other precise runs (box_z=24 >> the compressed z-cloud; if E/mF come out
# jagged the tighter trap is under-resolved and this needs a finer grid). 17 c1 × 2 κ.

Dict{String, Any}(
    "dealias" => Dict{String, Any}(
        "auto_dt" => true,
        "dt_safety" => 10.0,
        "enabled" => true,
        "k_cut" => 5.0,
    ),
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.0 Gauss",
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
            "interactions" => Dict{String, Any}(
                "N_atoms" => 50000,
                "c1_ratio" => 0.03,
                "omega_ref" => 691.1504,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "m_lbfgs" => 20,
            "method" => "lbfgs",
            "n_steps" => 2500,
            "newton_polish" => true,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify_distance" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        )],
    )],
    "scan" => Dict{String, Any}(
        "comparison_runs" => [Dict{String, Any}(
            "name" => "stretched",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "m_plus_F",
            ),
        ), Dict{String, Any}(
            "name" => "polar",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
            ),
        )],
        "product" => Dict{String, Any}(
            "pipeline.0.interactions.c1_ratio" => Dict{String, Any}(
                "from" => 0.026,
                "n" => 17,
                "to" => 0.034,
            ),
            "pipeline.0.potential.omega.2" => [2.0, 2.5],
        ),
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
