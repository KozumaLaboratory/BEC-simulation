# R35 — B-1 boundary trace (FL vs uniform polarization)
#
# Eu thesis B-1 experiment: trace the phase boundary in (c₁_ratio, c_dd_ratio)
# where FL (flux-closure) and uniform polarization energies cross.
# trace_phase_boundary takes a F(θ) = E_FL - E_uniform closure built
# via make_phase_diff_eval, then walks the curve via predictor +
# Newton corrector with warm-start ψ.
#
# Eu sets the boundary near c₁ = 0 (the canonical polar↔FM line) but
# c_dd shifts it. R35 traces that 1-D curve.
#
# This config is the BASELINE for the GS at each candidate point. The
# trace driver builds two such GS evaluations (one with phase_A_init,
# one with phase_B_init) per call to F.
# No analyzers — trace driver consumes the GS energy directly.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "eu151_thesis_24" => Dict{String, Any}(
            "N_atoms" => 30000,
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "c_dd_ratio" => 1.0,
                "enabled" => true,
            ),
            "grid" => Dict{String, Any}(
                "box" => [16, 16, 16],
                "n" => [24, 24, 24],
            ),
            "interactions" => Dict{String, Any}(
                "c1_ratio" => 0.0,
            ),
            "m_lbfgs" => 10,
            "method" => "lbfgs",
            "n_steps" => 500,
            "omega_ref" => 691.15,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.182],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-7,
        ),
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "1.0 Gauss",
            ),
            "use" => ["eu151_thesis_24"],
        ),
    )],
)
