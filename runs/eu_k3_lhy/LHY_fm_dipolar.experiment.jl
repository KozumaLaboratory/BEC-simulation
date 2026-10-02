# LHY kind was `icosahedral` until 2026-07-30, then `full_bdg`, now `fm_dipolar`.
#
# 1. `icosahedral` is invalid here. `IcosahedralLHY`'s closed form is
#    c0^(5/2) + 3|lambda_spin|^(5/2); the absolute value made it symmetric under
#    c1 -> -c1 and returned a real energy where the spin-Goldstone branch is
#    dynamically unstable. This config runs at c1_ratio < 0, i.e. OUTSIDE that
#    domain -- `epsilon_LHY_F6_Ih` returns NaN and the table build throws.
#
# 2. `full_bdg` RUNS here but is not quotable. It has no ansatz to violate, but
#    it has its own validity condition -- mean-field stability -- and these
#    parameters break it: max Im omega = 0.396 at (c0=3270.05, c1=-16.35,
#    m_minus_F). Its own warning: the zero-point sum drops the complex branches
#    while the counterterms still subtract all 13, so eps_LHY is
#    SCHEME-DEPENDENT there.
#
# 3. `fm_dipolar` is valid, and it is the ansatz that matches the state.
#    Measured 2026-07-30:
#      * the instability is ENTIRELY DIPOLAR -- switch the DDI off and
#        max Im omega is exactly 0. eps_dd = 0.5402.
#      * `lima_pelster_Q5` applies Petrov's prescription, zeroing the integrand
#        where 1 + eps_dd(3cos^2 t - 1) < 0, so the unstable angles are excluded
#        rather than half-counted. eps_dd < 1 is inside that domain
#        (fm_dipolar.jl:26) -- checked, not merely silent.
#      * with the DDI off, full_bdg and the FM closed form agree to six
#        significant figures (0.380007 vs 0.380006), cross-validating both.
#      * this suite's state is `initial_state: m_minus_F`, i.e. FM, and c1 < 0
#        makes FM the mean-field ground state -- so the FM ansatz matches.
#    V_LHY(n=3.7e-3) = 0.553422, finite and unwarned.
#
# Filename now matches the content (CLAUDE.md: file name = content). It said
# `icosahedral` while carrying `full_bdg`, which the naming convention forbids.
# Record: docs/validation/full_bdg_scheme_dependence_eu_f6.md
# Gated by test/oracles/test_lhy_config_validity_domain.jl.
#
# ┌ PAIRED ARM (2026-07-31). A sibling `LHY_full_bdg*` config runs the SAME cell
# │ with `kind: full_bdg`. Both exist because two independent renames of the old
# │ `LHY_icosahedral*` file chose different targets; kept deliberately, because
# │ the pair measures the size of full_bdg's scheme dependence at this ladder:
# │ 0.59327 there vs 0.553422 here, a 7 % spread. THIS arm is the one whose
# │ ansatz matches the state; that one is the comparator.
# │
# └ `factorial_2x4.json` has NO row for either arm — it predates them and its
#   rows are measured values nobody has re-run.
# Task #19C — LHY interference at K3=200× cigar regime.
# Source: scripts/validation/eu_k3_lhy_gen.jl
# LHY kind = full_bdg (was icosahedral; see the note at the top of this file).
# The FILENAME still says icosahedral. Left as-is because docs cite these paths,
# but it is a naming lie by this repo's own convention (file name = content) and
# the next reader will believe the name before the body.

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 30000,
            "omega_ref" => 628.3,
        ),
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.01 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "gauge_fix" => false,
            "grid" => Dict{String, Any}(
                "box" => [12.0, 12.0, 12.0],
                "n" => [32, 32, 32],
            ),
            "init_sigma" => 1.5,
            "initial_state" => "m_minus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 30000,
                "c1_ratio" => -0.005,
                "omega_ref" => 628.3,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "fm_dipolar",
            ),
            "n_steps" => 2000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 0.25],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 0.0,
                    "from" => 0.01,
                    "to" => 2.6e-5,
                ),
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 20.0,
            "lhy" => Dict{String, Any}(
                "kind" => "fm_dipolar",
            ),
            "loss" => Dict{String, Any}(
                "K3_per_m_si" => ["2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s", "2.0e-39 m^6/s"],
            ),
            "save" => Dict{String, Any}(
                "every" => 50,
                "precision" => "f64",
                "psi" => true,
            ),
            "seed_amplitude" => 1.0e-6,
            "seed_k_cut" => 2.5,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "winding_map" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        )],
    )],
)
