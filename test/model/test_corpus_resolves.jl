# The corpus gate for `yaml_to_model` — cutover step 1b's acceptance criterion.
#
# Step 3 flips admission from the legacy cache key to `artifact_id`, and it can
# only do that for configs `yaml_to_model` resolves. So "which configs resolve"
# is not a statistic, it is the cutover's scope, and it has to be a fact the
# suite maintains rather than a number in a report that rots. Every config under
# `runs/` is resolved here, and every one that does NOT resolve is listed below
# by name with the reason — so the list can only shrink by a deliberate edit,
# and a config that stops resolving is red on the same commit.
#
# Four arms:
#
#   1. CENSUS. The set of non-resolving configs equals `CORPUS_UNRESOLVED`
#      exactly, and each one still fails for its declared reason. Both
#      directions: fixing a config is red until it leaves the list, and a newly
#      unresolvable config is red until someone writes down why.
#
#   2. THE PHYSICS ARRIVED. For every config that resolves, the model's atom /
#      grid / N / omega_ref / c0 / c1 / c_dd / lhy kind / potential / p is
#      checked against the config's own YAML, with the derived quantities
#      RECOMPUTED here from CODATA constants and the constraint algebra. A model
#      that constructed but carried defaults passes arm 1 and fails this one.
#      Five configs additionally carry LITERAL value pins (arm 4).
#
#   3. ORDER INDEPENDENCE. `yaml_to_model(a)` does not depend on which configs
#      were resolved before it in the same session. This is not hypothetical:
#      `_run_yaml_prepare` is the prepare half of a prepare/execute pair and
#      leaves the dealias Refs set, so before the `finally` in `yaml_to_model`
#      the `GridSpec` of every config resolved after a dealias-carrying one was
#      silently rewritten.
#
#   4. LITERAL PINS. Arm 2 recomputes; a recomputation shares assumptions with
#      the thing it checks. Five configs therefore carry hand-copied numbers.
#
# READING THE YAML HERE IS THE POINT. `src/` must have exactly one parser of
# `potential:` / `B:` / `lhy:` / `ddi:` — that is what `resolve_gs` is for. A
# TEST that reads the config text and asserts the resolver agreed with it is the
# independent statement, not a second declaration.

using Test
using SpinorBEC
using SpinorBEC: yaml_to_model, Model, model_from_toml, to_toml,
    DEALIAS_2_3_ENABLED, DEALIAS_K_CUTOFF, _DEALIAS_PENDING_SNAPSHOT,
    restore_dealias_refs!, resolve_atom, n_terms
using YAML

const CORPUS_ROOT = normpath(joinpath(@__DIR__, "..", "..", "runs"))
const REPO_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

# CODATA, written out rather than imported from `Units`: arm 2 must not be able
# to agree with the resolver by sharing its constants.
const CD_HBAR = 1.054571817e-34
const CD_MU_B = 9.2740100783e-24
const CD_MU_0 = 1.25663706212e-6

# ---------------------------------------------------------------------------
# The configs `yaml_to_model` does NOT resolve, by name and reason.
#
# Measured 2026-08-02 over 429 YAML files under `runs/`; 351 resolve.
#
# Categories:
#
#   :lhy_n_max      A tabulated LHY kind with no `n_max`. `LHYTableOpts.n_max =
#                   NaN` means "3 x max|psi_init|^2", which makes the LHY
#                   functional a function of the SEED — the same model with two
#                   seeds would not be the same physics. Fixable per config by
#                   writing `lhy: {kind: ..., n_max: <n>}`.
#   :no_N_atoms     Bare `c0`/`c1` and no `N_atoms` anywhere. Nothing downstream
#                   recovers N from the resolved couplings, and every SI
#                   conversion in the layer is per-N.
#   :two_gs_steps   Two `ground_state:` steps, so the choice must be explicit.
#                   `index=1` DOES resolve all five (asserted below); the second
#                   step is method-only (`method`/`n_steps`/`tol`/`m_lbfgs`/`pin`)
#                   and inherits its physics from step 1's workspace, which
#                   `yaml_to_model` does not build.
#   :q_autoderive   87Rb with B != 0 and no explicit `q`. `q_geometry = 0` on
#                   that entry, so the Breit-Rabi auto-derivation refuses. This
#                   is `_build_zeeman_from_b_block` refusing, not the model
#                   layer: `run_yaml` fails the same way.
#   :dropped_physics  A tilted `B` on the spinor path. `B_direction` is only read
#                   by the rotating-basis runner, so the field silently runs
#                   along +z; a model would describe physics the run drops.
#   :schema_strict  `N_atoms` / `omega_ref` at STEP level instead of under
#                   `interactions:`. Refused by `_run_yaml_prepare`, which is the
#                   same function `run_yaml` calls (`run_registry.jl:205`) — so
#                   these nine configs are unrunnable today, independently of
#                   anything in the model layer.
#   :no_spinor_gs   Only a `rotating_basis` ground state. Out of scope by
#                   construction: admission keys on the spinor GS step.
#   :not_a_pipeline Not a run config at all (an expectations table).
#   :yaml_unparseable  Not a run config at all (a suite manifest), and YAML.jl
#                   rejects it outright: `id: 08` is read as octal.
#
# The reason strings are SUBSTRINGS of the thrown message. They are literal on
# purpose — deriving them from the source that produces them would make this
# gate agree with itself.
const CORPUS_UNRESOLVED = [
    # --- :lhy_n_max (22) ---
    (
        "runs/config_texture_stir_movie_f5bf647e.pre_masscurrent/config.yaml",
        :lhy_n_max,
        "needs a resolved n_max",
    ),
    (
        "runs/config_texture_stir_movie_f5bf647e.pre_strict/config.yaml",
        :lhy_n_max,
        "needs a resolved n_max",
    ),
    (
        "runs/eu_gs_phase_c1_B_kappa/config_texture_bscan_lhy_full_bdg.yaml",
        :lhy_n_max,
        "needs a resolved n_max",
    ),
    (
        "runs/eu_gs_phase_c1_B_kappa/config_texture_bscan_lhy_smoke.yaml",
        :lhy_n_max,
        "needs a resolved n_max",
    ),
    (
        "runs/eu_gs_phase_c1_B_kappa/config_texture_quench_movie.yaml",
        :lhy_n_max,
        "needs a resolved n_max",
    ),
    (
        "runs/eu_gs_phase_c1_B_kappa/config_texture_quench_movie_smoke.yaml",
        :lhy_n_max,
        "needs a resolved n_max",
    ),
    (
        "runs/eu_gs_phase_c1_B_kappa/config_texture_stir_movie.yaml",
        :lhy_n_max,
        "needs a resolved n_max",
    ),
    ("runs/eu_k3_lhy/LHY_fm_dipolar.yaml", :lhy_n_max, "needs a resolved n_max"),
    ("runs/eu_k3_lhy/LHY_full_bdg.yaml", :lhy_n_max, "needs a resolved n_max"),
    ("runs/eu_k3_lhy/LHY_polar_contact.yaml", :lhy_n_max, "needs a resolved n_max"),
    ("runs/eu_k3_lhy_control/LHY_fm_dipolar_K0.yaml", :lhy_n_max, "needs a resolved n_max"),
    ("runs/eu_k3_lhy_control/LHY_full_bdg_K0.yaml", :lhy_n_max, "needs a resolved n_max"),
    ("runs/eu_k3_lhy_control/LHY_polar_contact_K0.yaml", :lhy_n_max, "needs a resolved n_max"),
    ("runs/eu_lhy_longtime/LHY_fm_dipolar_100ms.yaml", :lhy_n_max, "needs a resolved n_max"),
    ("runs/eu_lhy_longtime/LHY_fm_dipolar_200ms.yaml", :lhy_n_max, "needs a resolved n_max"),
    ("runs/eu_lhy_longtime/LHY_fm_dipolar_50ms.yaml", :lhy_n_max, "needs a resolved n_max"),
    ("runs/eu_lhy_longtime/LHY_full_bdg_100ms.yaml", :lhy_n_max, "needs a resolved n_max"),
    ("runs/eu_lhy_longtime/LHY_full_bdg_200ms.yaml", :lhy_n_max, "needs a resolved n_max"),
    ("runs/eu_lhy_longtime/LHY_full_bdg_50ms.yaml", :lhy_n_max, "needs a resolved n_max"),
    ("runs/eu_lhy_longtime/LHY_polar_contact_100ms.yaml", :lhy_n_max, "needs a resolved n_max"),
    ("runs/eu_lhy_longtime/LHY_polar_contact_200ms.yaml", :lhy_n_max, "needs a resolved n_max"),
    ("runs/eu_lhy_longtime/LHY_polar_contact_50ms.yaml", :lhy_n_max, "needs a resolved n_max"),
    # --- :no_N_atoms (16) — two copies of the same eight-config suite ---
    (
        "runs/spinorbec_verification_yamls/spinorbec_verification_yamls/yamls/00_scalar_free_uniform_stationary.yaml",
        :no_N_atoms,
        "has no N_atoms",
    ),
    (
        "runs/spinorbec_verification_yamls/spinorbec_verification_yamls/yamls/01_scalar_harmonic_oscillator_ground.yaml",
        :no_N_atoms,
        "has no N_atoms",
    ),
    (
        "runs/spinorbec_verification_yamls/spinorbec_verification_yamls/yamls/02_spin1_polar_contact_ground.yaml",
        :no_N_atoms,
        "has no N_atoms",
    ),
    (
        "runs/spinorbec_verification_yamls/spinorbec_verification_yamls/yamls/03_spin1_ferromagnetic_contact_ground.yaml",
        :no_N_atoms,
        "has no N_atoms",
    ),
    (
        "runs/spinorbec_verification_yamls/spinorbec_verification_yamls/yamls/04_spin2_cyclic_contact_ground.yaml",
        :no_N_atoms,
        "has no N_atoms",
    ),
    (
        "runs/spinorbec_verification_yamls/spinorbec_verification_yamls/yamls/05_spin1_zeeman_phase_only.yaml",
        :no_N_atoms,
        "has no N_atoms",
    ),
    (
        "runs/spinorbec_verification_yamls/spinorbec_verification_yamls/yamls/06_spin1_sma_spin_mixing.yaml",
        :no_N_atoms,
        "has no N_atoms",
    ),
    (
        "runs/spinorbec_verification_yamls/spinorbec_verification_yamls/yamls/07_spin1_polar_bogoliubov_stable.yaml",
        :no_N_atoms,
        "has no N_atoms",
    ),
    (
        "runs/verification_suite/yamls/00_scalar_free_uniform_stationary.yaml",
        :no_N_atoms,
        "has no N_atoms",
    ),
    (
        "runs/verification_suite/yamls/01_scalar_harmonic_oscillator_ground.yaml",
        :no_N_atoms,
        "has no N_atoms",
    ),
    (
        "runs/verification_suite/yamls/02_spin1_polar_contact_ground.yaml",
        :no_N_atoms,
        "has no N_atoms",
    ),
    (
        "runs/verification_suite/yamls/03_spin1_ferromagnetic_contact_ground.yaml",
        :no_N_atoms,
        "has no N_atoms",
    ),
    (
        "runs/verification_suite/yamls/04_spin2_cyclic_contact_ground.yaml",
        :no_N_atoms,
        "has no N_atoms",
    ),
    (
        "runs/verification_suite/yamls/05_spin1_zeeman_phase_only.yaml",
        :no_N_atoms,
        "has no N_atoms",
    ),
    ("runs/verification_suite/yamls/06_spin1_sma_spin_mixing.yaml", :no_N_atoms, "has no N_atoms"),
    (
        "runs/verification_suite/yamls/07_spin1_polar_bogoliubov_stable.yaml",
        :no_N_atoms,
        "has no N_atoms",
    ),
    # --- :two_gs_steps (5) — `index=1` resolves all five, asserted below ---
    ("runs/eu_gs_phase_c1_B_kappa/config_midfield_newton.yaml", :two_gs_steps, "pass index"),
    ("runs/eu_gs_phase_c1_B_kappa/config_phase_repr.yaml", :two_gs_steps, "pass index"),
    ("runs/eu_gs_phase_c1_B_kappa/config_softconv_diag.yaml", :two_gs_steps, "pass index"),
    ("runs/eu_gs_phase_c1_B_kappa/config_vortex_verify_48.yaml", :two_gs_steps, "pass index"),
    ("runs/eu_gs_phase_c1_B_kappa/config_vortex_verify_64.yaml", :two_gs_steps, "pass index"),
    # --- :q_autoderive (5) ---
    (
        "runs/barnett_week1/scalar_rotation_om0p0.yaml",
        :q_autoderive,
        "quadratic-Zeeman cannot be auto-derived",
    ),
    (
        "runs/barnett_week1/scalar_rotation_om0p3.yaml",
        :q_autoderive,
        "quadratic-Zeeman cannot be auto-derived",
    ),
    (
        "runs/barnett_week1/scalar_rotation_om0p5.yaml",
        :q_autoderive,
        "quadratic-Zeeman cannot be auto-derived",
    ),
    (
        "runs/barnett_week1/scalar_rotation_om0p7.yaml",
        :q_autoderive,
        "quadratic-Zeeman cannot be auto-derived",
    ),
    (
        "runs/barnett_week1/scalar_rotation_om0p9.yaml",
        :q_autoderive,
        "quadratic-Zeeman cannot be auto-derived",
    ),
    # --- :dropped_physics (2) ---
    (
        "runs/klaus_hybrid/klaus_hybrid_magnetostir_omega_m0p74.yaml",
        :dropped_physics,
        "does not read",
    ),
    ("runs/klaus_hybrid/klaus_hybrid_nostir_control.yaml", :dropped_physics, "does not read"),
    # --- :schema_strict (9) — unrunnable today, `run_yaml` refuses them too ---
    (
        "runs/berry_crossover_scan/config.yaml",
        :schema_strict,
        "Unknown key 'pipeline.1.ground_state.omega_ref'",
    ),
    (
        "runs/eu151_phase_diagram_lbfgs/config.yaml",
        :schema_strict,
        "Unknown key 'pipeline.1.ground_state.omega_ref'",
    ),
    (
        "runs/klaus_baseline/config.yaml",
        :schema_strict,
        "Unknown key 'pipeline.1.ground_state.omega_ref'",
    ),
    (
        "runs/measurement_R3x_eu/r33_mfbo_eu_phase/config.yaml",
        :schema_strict,
        "Unknown key 'pipeline.1.ground_state.omega_ref'",
    ),
    (
        "runs/measurement_R3x_eu/r35_b1_boundary_trace/config.yaml",
        :schema_strict,
        "Unknown key 'pipeline.1.ground_state.omega_ref'",
    ),
    (
        "runs/measurement_R3x_eu/r36_4d_phase_al/config.yaml",
        :schema_strict,
        "Unknown key 'pipeline.1.ground_state.omega_ref'",
    ),
    (
        "runs/measurement_R3x_eu/r37_triple_point_hunt/config.yaml",
        :schema_strict,
        "Unknown key 'pipeline.1.ground_state.omega_ref'",
    ),
    (
        "runs/measurement_R3x_eu/r39_bdg_along_b1/config.yaml",
        :schema_strict,
        "Unknown key 'pipeline.1.ground_state.omega_ref'",
    ),
    (
        "runs/phi_omega_scan/config.yaml",
        :schema_strict,
        "Unknown key 'pipeline.1.ground_state.omega_ref'",
    ),
    # --- :no_spinor_gs (15) ---
    ("runs/eu151_klaus_barnett/config.yaml", :no_spinor_gs, "no spinor ground_state step"),
    (
        "runs/eu151_klaus_barnett/phi_+4.524/config.yaml",
        :no_spinor_gs,
        "no spinor ground_state step",
    ),
    (
        "runs/eu151_klaus_barnett/phi_+4.524_1s/config.yaml",
        :no_spinor_gs,
        "no spinor ground_state step",
    ),
    (
        "runs/eu151_klaus_barnett/phi_-4.524/config.yaml",
        :no_spinor_gs,
        "no spinor ground_state step",
    ),
    (
        "runs/eu151_klaus_barnett/phi_-4.524_1s/config.yaml",
        :no_spinor_gs,
        "no spinor ground_state step",
    ),
    ("runs/eu151_klaus_phi_phys/config.yaml", :no_spinor_gs, "no spinor ground_state step"),
    ("runs/eu151_klaus_phi_phys/phi_1.0/config.yaml", :no_spinor_gs, "no spinor ground_state step"),
    (
        "runs/eu151_klaus_phi_phys/phi_12.0/config.yaml",
        :no_spinor_gs,
        "no spinor ground_state step",
    ),
    (
        "runs/eu151_klaus_phi_phys/phi_18.0/config.yaml",
        :no_spinor_gs,
        "no spinor ground_state step",
    ),
    ("runs/eu151_klaus_phi_phys/phi_2.0/config.yaml", :no_spinor_gs, "no spinor ground_state step"),
    ("runs/eu151_klaus_phi_phys/phi_3.0/config.yaml", :no_spinor_gs, "no spinor ground_state step"),
    (
        "runs/eu151_klaus_phi_phys/phi_4.524/config.yaml",
        :no_spinor_gs,
        "no spinor ground_state step",
    ),
    ("runs/eu151_klaus_phi_phys/phi_6.0/config.yaml", :no_spinor_gs, "no spinor ground_state step"),
    ("runs/eu151_klaus_phi_phys/phi_8.0/config.yaml", :no_spinor_gs, "no spinor ground_state step"),
    ("runs/yan_li_saito_f1_torus_gs/config.yaml", :no_spinor_gs, "no spinor ground_state step"),
    # --- :not_a_pipeline (2) ---
    (
        "runs/spinorbec_verification_yamls/spinorbec_verification_yamls/checks/expected_observables.yaml",
        :not_a_pipeline,
        "must have a 'pipeline:' key",
    ),
    (
        "runs/verification_suite/checks/expected_observables.yaml",
        :not_a_pipeline,
        "must have a 'pipeline:' key",
    ),
    # --- :yaml_unparseable (2) ---
    (
        "runs/spinorbec_verification_yamls/spinorbec_verification_yamls/verify_suite_manifest.yaml",
        :yaml_unparseable,
        "invalid base 8 digit",
    ),
    ("runs/verification_suite/manifest.yaml", :yaml_unparseable, "invalid base 8 digit"),
]

# Measured 2026-08-02. A floor, not an equality: adding a config that resolves
# must not redden the suite, while a config that STOPS resolving is caught by the
# census arm naming it.
const CORPUS_RESOLVED_FLOOR = 351

const NON_SPINOR_GS_KINDS = ("binary", "rotating_basis", "option_gamma")

corpus_files() = sort!(
    String[
        joinpath(r, f)
        for (r, _, fs) in walkdir(CORPUS_ROOT) for f in fs
        if endswith(f, ".yaml") || endswith(f, ".yml")
    ],
)

corpus_rel(p) = replace(relpath(p, REPO_ROOT), '\\' => '/')

"""
The effective `ground_state:` block, read from the config's own YAML. Applies
`_run_yaml_prepare` (units / templates / mixins / calibration / schema defaults
/ B-block — preprocessing, no physics resolution) and the `defaults:` seeding,
then hands back the RAW keys. Restores the dealias Refs, or the reader becomes
the leak arm 3 is about.
"""
function corpus_gs_block(path)
    e0, k0, p0 = DEALIAS_2_3_ENABLED[], DEALIAS_K_CUTOFF[], _DEALIAS_PENDING_SNAPSHOT[]
    d = try
        SpinorBEC._run_yaml_prepare(String(path), false, false)
    finally
        _DEALIAS_PENDING_SNAPSHOT[] = p0
        restore_dealias_refs!(e0, k0)
    end
    defaults = get(d, "defaults", nothing)
    for s in d["pipeline"]
        s isa AbstractDict || continue
        ks = collect(keys(s))
        (length(ks) == 1 && String(string(ks[1])) == "ground_state") || continue
        inner = Dict{String, Any}(string(k) => v for (k, v) in s[ks[1]])
        if defaults isa AbstractDict
            merged = Dict{String, Any}(string(k) => v for (k, v) in defaults)
            for (k, v) in inner
                merged[k] = v
            end
            inner = merged
        end
        kind = get(inner, "kind", nothing)
        kind !== nothing && String(string(kind)) in NON_SPINOR_GS_KINDS && continue
        return inner
    end
    nothing
end

# `"0.01 Gauss"` / `"3157.2 Hz"` / `0.01` all appear in the corpus.
corpus_num(x) = x isa AbstractString ? parse(Float64, first(split(strip(x)))) : Float64(x)
corpus_is_hz(x) = x isa AbstractString && occursin("Hz", x)

@testset "corpus: every config under runs/ resolves, or is listed with its reason" begin
    files = corpus_files()
    @test length(files) >= 400          # the tree still has its corpus

    resolved = Dict{String, Model}()
    failed = Dict{String, String}()
    for f in files
        rel = corpus_rel(f)
        try
            resolved[rel] = yaml_to_model(f)
        catch err
            failed[rel] = err isa ArgumentError ? err.msg : sprint(showerror, err)
        end
    end

    # ---------------------------------------------------------------
    # Arm 1: the census
    # ---------------------------------------------------------------
    @testset "census" begin
        known = Dict(p => (c, r) for (p, c, r) in CORPUS_UNRESOLVED)
        @test length(known) == length(CORPUS_UNRESOLVED)   # no duplicate paths

        newly_broken = sort!(collect(setdiff(keys(failed), keys(known))))
        isempty(newly_broken) || println(
            "  configs that no longer resolve and are NOT listed:\n    ",
            join(newly_broken, "\n    "))
        @test isempty(newly_broken)

        now_fixed = sort!(collect(setdiff(keys(known), keys(failed))))
        isempty(now_fixed) || println(
            "  listed as unresolvable but now RESOLVE — delete them from " *
            "CORPUS_UNRESOLVED:\n    ", join(now_fixed, "\n    "))
        @test isempty(now_fixed)

        # ... and each still fails for the reason written down, not some other
        # one that happens to also be a failure.
        wrong_reason = String[]
        for (p, (_, reason)) in known
            haskey(failed, p) || continue
            occursin(reason, failed[p]) ||
                push!(
                    wrong_reason, "$p: expected $(repr(reason)) in $(repr(first(failed[p], 160)))"
                )
        end
        isempty(wrong_reason) ||
            println("  wrong failure reason:\n    ", join(sort!(wrong_reason), "\n    "))
        @test isempty(wrong_reason)

        println(
            "  corpus: $(length(files)) configs, $(length(resolved)) resolve, " *
            "$(length(failed)) do not",
        )
        @test length(resolved) >= CORPUS_RESOLVED_FLOOR
    end

    # ---------------------------------------------------------------
    # Arm 1b: the two-ground_state configs resolve WITH an index. The refusal
    # above is a choice, not a limit — but the SECOND step really is
    # unresolvable in isolation, and that is a limit.
    # ---------------------------------------------------------------
    @testset "two ground_state steps: index=1 resolves, index=2 cannot" begin
        two = [p for (p, c, _) in CORPUS_UNRESOLVED if c === :two_gs_steps]
        @test length(two) == 5
        for rel in two
            p = joinpath(REPO_ROOT, rel)
            m = yaml_to_model(p; index=1)
            @test m isa Model
            @test m.interactions.n_atoms > 0
            # The second step carries method knobs only and inherits its physics
            # from step 1's workspace, which `yaml_to_model` does not build.
            err = try
                yaml_to_model(p; index=2)
                nothing
            catch e
                e isa ArgumentError ? e.msg : sprint(showerror, e)
            end
            @test err !== nothing
            @test occursin("requires 'atom'", err)
        end
    end

    # ---------------------------------------------------------------
    # Arm 2: the physics the YAML asked for actually arrived
    # ---------------------------------------------------------------
    @testset "resolved models carry their config's physics" begin
        bad = String[]
        note(rel, msg) = push!(bad, "$rel: $msg")
        n_checked = 0
        n_assert = 0
        for (rel, m) in resolved
            p = corpus_gs_block(joinpath(REPO_ROOT, rel))
            p === nothing && (note(rel, "resolved but no spinor GS block found"); continue)
            n_checked += 1

            # --- atom ------------------------------------------------
            a = resolve_atom(Symbol(String(string(p["atom"]))))
            n_assert += 2
            m.atom.name == a.name || note(rel, "atom $(m.atom.name) != $(a.name)")
            m.atom.F == a.F || note(rel, "F $(m.atom.F) != $(a.F)")

            # --- grid ------------------------------------------------
            g = p["grid"]
            n = Tuple(Int.(g["n"]))
            box = Tuple(corpus_num.(g["box"]))
            n_assert += 3
            m.grid.ndim == length(n) || note(rel, "ndim $(m.grid.ndim) != $(length(n))")
            m.grid.n_points[1:length(n)] == n ||
                note(rel, "n_points $(m.grid.n_points) != $n")
            all(abs.(m.grid.box[1:length(box)] .- box) .< 1e-12) ||
                note(rel, "box $(m.grid.box) != $box")

            # --- interactions ---------------------------------------
            inter = get(p, "interactions", Dict{String, Any}())
            N = Int(inter["N_atoms"])
            w = corpus_num(inter["omega_ref"])
            a_ho = sqrt(CD_HBAR / (m.atom.mass * w))
            n_assert += 2
            m.interactions.n_atoms == N || note(rel, "N $(m.interactions.n_atoms) != $N")
            m.interactions.omega_ref == w ||
                note(rel, "omega_ref $(m.interactions.omega_ref) != $w")
            if haskey(inter, "c1_ratio")
                r = corpus_num(inter["c1_ratio"])
                n_assert += 1
                abs(m.interactions.c1 - r * m.interactions.c0) <=
                1e-12 * max(1.0, abs(m.interactions.c0)) ||
                    note(rel, "c1/c0 $(m.interactions.c1 / m.interactions.c0) != c1_ratio $r")
                # The F-manifold sum rule, recomputed from a_s: it pins the
                # MAGNITUDE that the ratio alone leaves free.
                if !haskey(inter, "c_total")
                    n_assert += 1
                    lhs = m.interactions.c0 + m.atom.F^2 * m.interactions.c1
                    want = 4pi * (m.atom.a_s / a_ho) * N
                    abs(lhs - want) <= 1e-9 * abs(want) ||
                        note(rel, "c0 + F^2 c1 = $lhs != 4pi a_s/a_ho N = $want")
                end
            end
            # `c_total` names the sum directly.
            if haskey(inter, "c_total")
                n_assert += 1
                ct = corpus_num(inter["c_total"])
                lhs = m.interactions.c0 + m.atom.F^2 * m.interactions.c1
                abs(lhs - ct) <= 1e-9 * max(1.0, abs(ct)) ||
                    note(rel, "c0 + F^2 c1 = $lhs != c_total $ct")
            end

            # --- ddi -------------------------------------------------
            ddi = get(p, "ddi", nothing)
            on = ddi isa AbstractDict && get(ddi, "enabled", true) != false
            n_assert += 1
            if on
                want = if haskey(ddi, "c_dd")
                    corpus_num(ddi["c_dd"])
                else
                    N * CD_MU_0 * (m.atom.mu_mag / m.atom.F)^2 / (CD_HBAR * w * a_ho^3)
                end
                abs(m.ddi.c_dd - want) <= 1e-6 * abs(want) ||
                    note(rel, "c_dd $(m.ddi.c_dd) != independent $want")
                n_assert += 1
                m.ddi.secular == Bool(get(ddi, "secular", false)) ||
                    note(rel, "secular $(m.ddi.secular) != $(get(ddi, "secular", false))")
            else
                m.ddi.c_dd == 0.0 ||
                    note(rel, "ddi absent/disabled but c_dd = $(m.ddi.c_dd)")
            end

            # --- lhy -------------------------------------------------
            lhy = get(p, "lhy", nothing)
            want_kind =
                lhy isa AbstractDict ?
                Symbol(String(string(get(lhy, "kind", "none")))) : :none
            n_assert += 1
            m.lhy.kind === want_kind || note(rel, "lhy $(m.lhy.kind) != $want_kind")

            # --- potential -------------------------------------------
            pot = get(p, "potential", nothing)
            if pot isa AbstractDict && String(string(get(pot, "type", ""))) == "harmonic" &&
                haskey(pot, "omega")
                om = Tuple(
                    map(v -> corpus_is_hz(v) ? 2pi * corpus_num(v) : corpus_num(v),
                        pot["omega"]),
                )
                n_assert += 2
                length(m.potential.harmonic) == 1 ||
                    note(rel, "$(length(m.potential.harmonic)) harmonic terms, want 1")
                if length(m.potential.harmonic) == 1
                    got = m.potential.harmonic[1].omega
                    all(abs.(got[1:length(om)] .- om) .<= 1e-9 .* max.(1.0, abs.(om))) ||
                        note(rel, "trap omega $got != $om")
                end
            elseif pot isa AbstractDict && String(string(get(pot, "type", ""))) == "none"
                n_assert += 1
                n_terms(m.potential) == 0 ||
                    note(rel, "potential: none but $(n_terms(m.potential)) terms")
            end

            # --- B ---------------------------------------------------
            #
            # Two spellings, both live. `Bz` is lab Gauss and goes through the
            # sign that `Units.bfield_to_p` declares once; `p` is already
            # dimensionless and must arrive untouched. Covering only `Bz` left
            # the 36 configs that spell `p:` unchecked, and with them the whole
            # `_zeeman_spec_of(::ZeemanParams, …)` arm — canary K8 (flip the sign
            # there) came back GREEN against the Bz-only version.
            B = get(p, "B", nothing)
            _static(v) = v isa Real || v isa AbstractString
            if B isa AbstractDict && haskey(B, "Bz") && _static(B["Bz"])
                bz = corpus_num(B["Bz"])
                want_p = -m.atom.g_F * CD_MU_B * (bz * 1e-4) / (CD_HBAR * w)
                n_assert += 1
                if m.zeeman.p isa Real
                    abs(m.zeeman.p - want_p) <= 1e-9 * max(1.0, abs(want_p)) ||
                        note(rel, "p $(m.zeeman.p) != -g_F mu_B B/(hbar w) = $want_p")
                else
                    note(rel, "p is a waveform on a static Bz")
                end
            elseif B isa AbstractDict && haskey(B, "p") && _static(B["p"])
                want_p = corpus_num(B["p"])
                n_assert += 1
                if m.zeeman.p isa Real
                    abs(m.zeeman.p - want_p) <= 1e-12 * max(1.0, abs(want_p)) ||
                        note(rel, "p $(m.zeeman.p) != declared dimensionless p $want_p")
                else
                    note(rel, "p is a waveform on a static declared p")
                end
            end
            # An explicit `q` is dimensionless too and is never derived.
            if B isa AbstractDict && haskey(B, "q") && _static(B["q"])
                want_q = corpus_num(B["q"])
                n_assert += 1
                if m.zeeman.q isa Real
                    abs(m.zeeman.q - want_q) <= 1e-12 * max(1.0, abs(want_q)) ||
                        note(rel, "q $(m.zeeman.q) != declared q $want_q")
                else
                    note(rel, "q is a waveform on a static declared q")
                end
            end
        end
        isempty(bad) || println("  physics mismatches (", length(bad), "):\n    ",
            join(sort!(bad), "\n    "))
        @test isempty(bad)
        println("  physics: $n_assert independent checks over $n_checked resolved configs")
        # A fixture that checked nothing would also report zero mismatches.
        @test n_checked >= CORPUS_RESOLVED_FLOOR
        @test n_assert >= 10 * n_checked
    end

    # ---------------------------------------------------------------
    # Arm 2b: every resolved model survives its own serialisation
    # ---------------------------------------------------------------
    @testset "every resolved model round-trips through TOML" begin
        bad = String[]
        for (rel, m) in resolved
            s = to_toml(m)
            ok = try
                back = model_from_toml(s)
                back == m && to_toml(back) == s
            catch err
                push!(bad, "$rel: $(sprint(showerror, err))")
                false
            end
            ok || push!(bad, rel)
        end
        isempty(bad) || println("  round-trip failures:\n    ", join(unique(sort!(bad)), "\n    "))
        @test isempty(bad)
    end

    # ---------------------------------------------------------------
    # Arm 3: order independence
    # ---------------------------------------------------------------
    @testset "resolution does not depend on what was resolved before it" begin
        # `_run_yaml_prepare` applies a top-level `dealias:` block to module Refs
        # and leaves them set; `run_yaml` restores them in the execute half's
        # `finally`, which `yaml_to_model` never runs. Without its own restore,
        # the config below resolved to dealias=false alone and dealias=true after
        # the one with the block.
        plain = joinpath(REPO_ROOT, "runs/validation_level10/L10_F1_smoke.yaml")
        withd = joinpath(REPO_ROOT, "runs/eu_gs_phase_c1_B_kappa/config_boundary_64.yaml")
        @test isfile(plain) && isfile(withd)

        before = yaml_to_model(plain)
        other = yaml_to_model(withd)
        after = yaml_to_model(plain)
        @test after == before
        @test to_toml(after) == to_toml(before)

        # The pair must actually DISAGREE about dealias, or the equality above is
        # vacuous — this is the positive control for the arm.
        @test before.grid.dealias_two_thirds == false
        @test before.grid.dealias_k_cut == 0.0
        @test other.grid.dealias_two_thirds == true
        @test other.grid.dealias_k_cut == 10.0

        # ... and the call leaves the globals exactly as it found them, for the
        # sake of every other test in the session.
        e0, k0, p0 = DEALIAS_2_3_ENABLED[], DEALIAS_K_CUTOFF[], _DEALIAS_PENDING_SNAPSHOT[]
        yaml_to_model(withd)
        @test DEALIAS_2_3_ENABLED[] == e0
        @test DEALIAS_K_CUTOFF[] == k0
        @test _DEALIAS_PENDING_SNAPSHOT[] === p0
        # Even when it throws.
        try
            yaml_to_model(joinpath(REPO_ROOT, "runs/eu_k3_lhy/LHY_full_bdg.yaml"))
        catch
        end
        @test DEALIAS_2_3_ENABLED[] == e0
        @test DEALIAS_K_CUTOFF[] == k0
        @test _DEALIAS_PENDING_SNAPSHOT[] === p0
    end

    # ---------------------------------------------------------------
    # Arm 4: literal pins. Arm 2 recomputes, and a recomputation shares
    # assumptions with what it checks; these numbers were copied off a run and
    # are not derived from anything the resolver can move.
    # ---------------------------------------------------------------
    @testset "six configs pinned by value" begin
        m = resolved["runs/eu_k3_lhy/LHY_scalar.yaml"]
        @test m.atom.name == "151Eu" && m.atom.F == 6
        @test m.grid.n_points == (32, 32, 32) && m.grid.box == (12.0, 12.0, 12.0)
        @test m.interactions.n_atoms == 30000
        @test m.interactions.omega_ref == 628.3
        @test m.interactions.c0 ≈ 3270.049111341537 atol = 1e-9
        @test m.interactions.c1 ≈ -16.350245556707684 atol = 1e-11
        @test m.ddi.c_dd ≈ 120.7188510532178 atol = 1e-10
        @test m.ddi.secular == false
        @test m.ddi.padded == true
        @test m.ddi.trunc_radius === nothing            # auto
        @test m.lhy.kind === :scalar
        @test m.lhy.c_lhy ≈ 2441.7648537501423 atol = 1e-9
        @test m.potential.harmonic[1].omega == (1.0, 1.0, 0.25)
        @test m.zeeman.p ≈ -162.75546899825991 atol = 1e-9
        @test m.zeeman.q ≈ 0.0014215177337385363 atol = 1e-16

        # 87Rb, F=1, g_F < 0, DDI explicitly disabled, no dealias block.
        r = resolved["runs/validation_level10/L10_F1_smoke.yaml"]
        @test r.atom.name == "87Rb" && r.atom.F == 1
        @test r.interactions.c0 ≈ 2.4567252413684244 atol = 1e-12
        @test r.interactions.c1 ≈ 0.024567252413684244 atol = 1e-14
        @test r.ddi.c_dd == 0.0
        @test r.lhy.kind === :none
        @test r.zeeman.p == 0.0 && r.zeeman.q == 0.0

        # 52Cr, F=3 — the scattering-lengths atom (c1 = 0 by construction, the
        # tensor cache carries every channel) and a TRANSVERSE field.
        c = resolved["runs/verification_suite/yamls/L2_ddi_axis_flip_Bx.yaml"]
        @test c.atom.name == "52Cr" && c.atom.F == 3
        @test c.interactions.c0 ≈ 533.890403077037 atol = 1e-10
        @test c.interactions.c1 == 0.0
        @test c.ddi.c_dd ≈ 24.034276103734303 atol = 1e-12
        @test c.zeeman.p == 0.0
        @test c.zeeman.bx ≈ -2799.3315483654897 atol = 1e-9
        @test c.zeeman.by == 0.0

        # An EXPLICIT c_dd in the YAML overrides the atom-derived one: 152 is
        # 2.4x natural (63.3 x 1.3/0.54), and the model must carry what was
        # asked for, not what the atom implies.
        s = resolved["runs/saito_li_torus/config.yaml"]
        @test s.ddi.c_dd == 152.0
        @test s.grid.n_points == (64, 64, 64) && s.grid.box == (3.0, 3.0, 3.0)
        @test s.potential.harmonic[1].omega == (0.01, 0.01, 0.01)
        @test s.lhy.kind === :scalar
        @test s.lhy.c_lhy ≈ 972.5577760865442 atol = 1e-10

        # `secular: true`. Same c_dd / c0 / c1 / p as LHY_scalar above, which is
        # what makes the flag the only difference between the two models.
        sec = resolved["runs/eu_ham_only_conservation/eu_ham_only_24_sec.yaml"]
        @test sec.ddi.secular == true
        @test sec.ddi.c_dd ≈ 120.7188510532178 atol = 1e-10
        @test sec.grid.n_points == (24, 24, 24)
        @test sec.ddi != m.ddi              # ... and it reaches the DDISpec
        @test sec.interactions == m.interactions

        # A `dealias:` block that reaches the GridSpec, and 691.1504 rather than
        # 691.15 — the `units:` path, not a typo.
        b = resolved["runs/eu_gs_phase_c1_B_kappa/config_boundary_64.yaml"]
        @test b.grid.dealias_two_thirds == true
        @test b.grid.dealias_k_cut == 10.0
        @test b.grid.n_points == (64, 64, 64)
        @test b.interactions.omega_ref == 691.1504
        @test b.interactions.n_atoms == 50000
        @test b.interactions.c0 ≈ 2343.6331553134137 atol = 1e-9
        @test b.interactions.c1 ≈ 65.1009210330089 atol = 1e-11
        @test b.ddi.c_dd ≈ 211.02144615413027 atol = 1e-10
        @test b.ddi.secular == false
    end
end
