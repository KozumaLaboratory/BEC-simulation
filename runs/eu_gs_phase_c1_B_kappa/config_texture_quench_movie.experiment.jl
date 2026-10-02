# Watch the weak-field Eu texture respond to a B quench: where the vortices come
# from, how the density reacts, what the spin does — as a movie.
#
# The excitation is the campaign's own physics. The ground state is prepared
# ABOVE the ~50µG crossover, where the texture pins axial; the field is then
# dropped BELOW it, where the spin manifold is soft. The state it was in is no
# longer the state it wants, and it can only get there through the phase — which
# is what puts defects in.
#
# The quench is INSTANTANEOUS (a new dynamics phase at the new field), not a
# ramp. That is the cleaner protocol here, and it also sidesteps a real bug:
# `units: {B: Gauss}` rewrites a ramp's `from`/`to` into Gauss STRINGS
# (units_block.jl:94, deliberately, inheriting the parent's unit type) while the
# ramp builder does `Float64(spec["from"])` (builders_phase.jl:125) and throws
# MethodError. Gauss + `{from, to, duration}` cannot currently be combined.
#
# `save.every` yields 200 snapshots, which at 30 fps is a ~6.7 s movie — enough
# to hit 5 s after the renderer resamples. Snapshot cost is
# 32*32*64*13 complex128 = 13.6 MB/frame ⇒ ~2.7 GB of scratch. Fine here; check
# before scaling the grid.
#
# LHY is on (full_bdg): the F=6 phases this texture chooses between are
# mean-field degenerate.
# DEALIAS OFF here, but do NOT read that as "off is correct" — the question is
# open and the reasoning that led here was partly wrong.
#
# Measured on this exact cell (duration 0.1, everything else identical):
#   enabled: false -> column sum 18.963 at EVERY frame (conserved to 5 s.f.)
#   enabled: true  -> 18.963 -> 1.202 -> ... -> 0.669, norm_rel_drift = 0.993
#
# I first blamed `k_cut` (wrong: removing it reproduces the loss to 3 s.f.) and
# then the DDI F-filter (also wrong: F enters as a unitary spin rotation, so
# filtering it cannot change the norm at all).
#
# The resolution landed separately: the psi filter is an EXACT SPECTRAL
# PROJECTOR, so the norm it removes IS the above-cut weight, and a large drift
# measures how much weight the dynamics push past 2/3 k_Nyq rather than
# indicating a bug. On that reading, disabling the filter does not fix anything
# — the content aliases back into low k and the clean norm is a trap.
#
# UNRESOLVED for these configs: the dealias-OFF states measured here carry
# 0.0% of their weight above the 2/3 cut at t=0.1 AND at t=20, which does not
# fit "the dynamics generate several % per step". Until that is reconciled,
# treat BOTH settings as suspect and quote `norm_rel_drift` with any result.
# See memory gotcha_dealias_block_destroys_norm_in_ddi_dynamics_2026_07_28.
# Prepared above the crossover — axial flux-closure texture.
# 1e-6, not 1e-8. The weak-field texture sits on a soft (Goldstone)
# manifold: measured here, |∇E| falls to 6.3e-7 by iteration ~500 and then
# stops moving, so a 1e-8 target just burns the remaining 1000 iterations
# at an unchanged state. The B-scan campaign settled at 1e-5 for the same
# reason.
# Quenched to 20 µG — below the crossover. Nucleation and the subsequent
# motion both happen here, which is what the movie is for.

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
                "Bz" => "2.0e-5 Gauss",
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
                "output_dir" => "figs/eu_texture_quench_movie",
            ),
        )],
    )],
    "units" => Dict{String, Any}(
        "B" => "Gauss",
    ),
)
