# ─────────────────────────────────────────────────────────────────────────
#  EdH quench verification (2026-07-20): spin-texture sanity check.
#
#  Purpose: confirm whether the xy-plane spin texture at t=4 ms is physically
#  sensible after a SUDDEN quench from a fully polarized state.
#
#  Protocol:
#    - Ground state prepared at Bz = 3.0 G  (strongly polarized → pure m=-6).
#    - At t=0 the field is quenched INSTANTLY to Bz = 26 µG (= 2.6e-5 G) and
#      held constant for the whole dynamics (sudden non-adiabatic quench).
#    - Evolve 4 ms  (internal duration = 4e-3 s * omega_ref[691.15] = 2.7646).
#    - Save psi snapshots so the xy (z-mid) spin texture can be inspected.
#
#  EdH only (no Flower / no adiabatic-ramp sibling here).
#
#  Physics knobs match the validated eu151_edh_phys mixin (32³ / box18 /
#  Eu151 / N=5e4 / c1=1/36 / trap (1,1,1.182)). DDI is EXPLICITLY enabled and
#  EXPLICITLY non-secular in BOTH steps (per lab convention: never rely on the
#  secular default, always state secular: false).
#
#  A tiny symmetry-breaking seed (1e-8) is added to the dynamics so the
#  transverse (spin-flip) instability is not frozen out by exact polar
#  symmetry. Compare against the no-seed sibling to see whether the seed is
#  what nucleates the winding.
# ─────────────────────────────────────────────────────────────────────────
# --- Ground state at 3.0 G (fully polarized, m=-6) ---
# Start from the fully polarized m=-6 spin-coherent state (theta=pi points
# along -z; g_F>0 Eu + +Bz => m=-F ground state). This is the TRUE 3 G
# ground state, so LBFGS stays there. Starting from the default polar (m=0)
# state gets stuck: the Zeeman gradient (-p F_z + q F_z^2) VANISHES on a pure
# m=0 component, so m=0 is an (unstable) fixed point LBFGS cannot leave.
# --- Sudden quench to 26 µG, hold, evolve 4 ms ---

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
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
                "n" => [32, 32, 32],
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
                "Bz" => "3.0 Gauss",
            ),
            "cache" => "runs/eu151_edh_quench_verify/cache/gs_3G_32.jld2",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "init_state_params" => Dict{String, Any}(
                "init_phi" => 0.0,
                "init_theta" => 3.141592653589793,
            ),
            "initial_state" => "spin_coherent",
            "method" => "lbfgs",
            "n_steps" => 400,
            "tol" => 1.0e-9,
            "use" => ["eu151_edh_phys"],
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "2.6e-5 Gauss",
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.001,
            "duration" => 2.7646,
            "noise_seed" => 42,
            "save" => Dict{String, Any}(
                "every" => 138,
                "precision" => "f32",
                "psi" => true,
            ),
            "seed_amplitude" => 1.0e-8,
            "seed_k_cut" => 2.5,
        ),
    )],
)
