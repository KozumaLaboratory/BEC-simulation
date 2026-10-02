# ⚠️ DO NOT RUN AS-IS (2026-07-30). `full_bdg`'s own BdG check reports the mean
# field dynamically unstable at EVERY (Bz, c1, seed) cell here, seed and converged
# alike, so eps_LHY is scheme-dependent by the code's own statement. The
# instability is ENTIRELY DIPOLAR — switch the DDI off and max Im omega is exactly
# 0 for all five seeds, at eps_dd = 0.5402 — so this is a question about how the
# dipolar term is treated, not about the atom being out of reach.
#
# That means a `*_dipolar` closed form IS valid for an individual state
# (Petrov's prescription zeros the unstable angles; eps_dd < 1 is inside its
# domain). What is NOT available is a single functional covering all five
# competing textures: four have |<F>|/F = 1 and want fm_dipolar, `polar` wants
# polar_dipolar, and the only one covering all five is full_bdg -- the
# scheme-dependent one. So THE COMPARISON is what is blocked, not the physics.
# Measurements + options: docs/validation/full_bdg_scheme_dependence_eu_f6.md
#
# Three plumbing bugs also had to be fixed before this could even be measured —
# #179 (lbfgs had no spinor_lhy kwarg at all), and both halves of #201 (the
# tabulated table could not reach a GPU kernel; the BdG table was always built
# at zero field). Any output from this config predating those is mean-field.
#
# The LHY-on twin of config_texture_bscan.experiment.jl — same cells, same seeds, the
# ONLY difference is `lhy.kind`. Its job is the A/B: does "PCV wins at 50µG,
# uniform axial from 60µG" survive beyond mean field?
#
# It has to be asked, because the F=6 ground-state phases the competing seeds
# are meant to separate are mean-field DEGENERATE — g₂/g₄/g₈ vanish and it is
# the LHY term that picks one. Every earlier cell in this campaign ran
# `lhy: {kind: none}`, so its phase assignments are provisional by construction.
#
# `full_bdg` and not `scalar`: the scalar LHY is c·n^(3/2), spin-INDEPENDENT, so
# it cannot lift a degeneracy between spinors at all — it would change the
# density and leave the ordering exactly where mean field left it. full_bdg is
# the general-spinor path, gated against the closed forms to ~1e-4 since the UV
# counterterm fix.
#
# CAVEAT to quote with any result from this file: the LHY table is built ONCE in
# make_workspace from the SEED spinor and then held fixed, so the five competing
# seeds are compared under five slightly different functionals. Cross-check the
# winner by rebuilding the table from the CONVERGED state before believing a
# close call (dE ~ 1e-3 in the mean-field run).

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
                "Bz" => "6.0e-5 Gauss",
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
            "tol" => 1.0e-8,
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify_distance" => Dict{String, Any}(),
        )],
    )],
    "scan" => Dict{String, Any}(
        "comparison_runs" => [Dict{String, Any}(
            "name" => "flower",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "flower",
            ),
        ), Dict{String, Any}(
            "name" => "csv",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "chiral_spin_vortex",
            ),
        ), Dict{String, Any}(
            "name" => "pcv",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar_core_vortex",
            ),
        ), Dict{String, Any}(
            "name" => "fm",
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
            "pipeline.0.B.Bz" => ["5.0e-5 Gauss", "6.0e-5 Gauss", "7.0e-5 Gauss", "8.0e-5 Gauss"],
            "pipeline.0.interactions.c1_ratio" => [0.0, 0.018],
        ),
    ),
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
