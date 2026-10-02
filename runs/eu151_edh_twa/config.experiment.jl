# ─────────────────────────────────────────────────────────────────────
#  Eu151 EdH protocol with Truncated Wigner ensemble.
#  Same Hamiltonian as runs/eu151_edh_postfix_local/, but Phase 2 hold
#  runs as TWA ensemble (5 trajectories, vacuum noise on GS).
#
#  Diagnostic question: does quantum fluctuation averaging suppress the
#  deterministic-GP "Townes-like collapse" observed in single-trajectory
#  runs? If ensemble-mean density profile differs significantly from
#  single-traj, the collapse is partially a numerical / classical-field
#  artefact. If they agree, the collapse is robust to quantum noise.
#
#  Computational note: 5 trajectories × ~3 min/traj ≈ 15 min on RTX 5070
#  Ti for 32³. Existing run_twa uses Welford online accumulation so VRAM
#  cost is the same as single-traj.
# ─────────────────────────────────────────────────────────────────────

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "interactions" => Dict{String, Any}(
            "omega_ref" => 691.15,
        ),
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_edh_phys" => Dict{String, Any}(
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
            "use" => ["eu151_edh_phys"],
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
