# --- YAML schema validation ---

export validate_pipeline!, validate_config!

# Catches typos and invalid values before a multi-hour GPU run starts.
# Design: each schema is a Dict{String, FieldSpec}. validate_config! walks
# the pipeline dict and reports unknown keys as warnings, missing required
# keys and out-of-range values as errors.

struct FieldSpec
    required::Bool
    type::Type
    default::Any
    range::Union{Nothing, Tuple{Float64, Float64}}
    enum::Union{Nothing, Vector{String}}
    schema::Union{Nothing, Dict{String, FieldSpec}}  # for nested dicts
end

FieldSpec(;
    required=false, type=Any, default=nothing, range=nothing, enum=nothing, schema=nothing
) = FieldSpec(
    required, type, default, range, enum, schema
)

const GRID_SCHEMA = Dict{String, FieldSpec}(
    "n" => FieldSpec(; required=true, type=Union{Vector, Int}),
    "box" => FieldSpec(; required=true, type=Union{Vector, Float64}),
)

const INTERACTIONS_SCHEMA =
    let s = Dict{String, FieldSpec}(
            "N_atoms" => FieldSpec(; type=Number),
            "omega_ref" => FieldSpec(; type=Number, range=(0.0, 1e10)),
            "c_total" => FieldSpec(; type=Number),
            "c0" => FieldSpec(; type=Number),
            "c1" => FieldSpec(; type=Number),
            "c1_ratio" => FieldSpec(; type=Number, range=(-1.0, 1.0)),
        )
        # Sparse c_N keys (c2, c4, ..., c12) declare higher-rank tensor
        # couplings directly. The parser (`_parse_higher_rank_c_n`,
        # parsing_blocks.jl) consumes any `cN` for N ≥ 2. Whitelist them
        # so strict-mode validation doesn't reject `c2: 2.0` etc.
        # Range up to N=12 covers Eu-151 F=6 (channels S=0..12).
        for n in 2:12
            s["c$n"] = FieldSpec(; type=Number)
        end
        s
    end

# LHY block — replaces the split (interactions.c_lhy + ground_state.spinor_lhy).
# `kind` chooses the dispatch path; the other fields are kind-specific.
# `c_lhy` is auto-derived via Lima-Pelster Q5(ε_dd) when unset and kind ∈
# {none, scalar, quasi_2d}. `n_max` defaults to 3 × max(|psi_init|²) at
# workspace-build time.
const LHY_SCHEMA = Dict{String, FieldSpec}(
    "kind" => FieldSpec(; type=String, default="none",
        enum=["none", "scalar", "quasi_2d", "polar_two_channel", "full_bdg",
            "polar_contact", "polar_dipolar", "fm_contact", "fm_dipolar",
            "icosahedral", "spatial"]),
    "c_lhy" => FieldSpec(; type=Number),       # scalar/quasi_2d explicit override
    "n_max" => FieldSpec(; type=Number),       # null → 3 × max(|psi_init|²)
    "n_points" => FieldSpec(; type=Integer, default=200, range=(3, 10000)),
    # `spatial` only: |⟨F⟩|/F bins, one BdG solve per OCCUPIED bin. A cost knob.
    "n_bins" => FieldSpec(; type=Integer, default=12, range=(2, 64)),
)

# Unified `B:` Zeeman block (replaces the legacy step-level `zeeman:` /
# `B_hat:` keys; those are rejected outright in `_reject_unknown_step_keys!`
# inside `schema/B_block.jl`). Three coord-system inputs, auto-detected
# by `b_block_builders.jl:_detect_b_coord`:
#   :dimless    `p`, `q`, `bx`, `by`            (dimensionless, ℏω_ref units)
#   :cartesian  `Bx`, `By`, `Bz`                (Gauss; scalar or waveform)
#   :spherical  `B_mag`, `theta`, `phi`         (Gauss; + `q` auto-derived
#                                               from |B|² unless explicit)
# Lab-units (`p_mv`, `coil_mode`) work alongside `:spherical` — they expand
# through the calibration table to `B_mag: "X Gauss"` before reaching here.
#
# Each field accepts either a scalar (Number / String when units are
# attached) or a waveform dict (e.g. `Bz: {from: 0.01, to: 0.0,
# duration: 0.0}` for a ramp); leaving the type unconstrained as `Any`
# keeps the validator from blocking the legitimate waveform forms.
const B_SCHEMA = Dict{String, FieldSpec}(
    "p" => FieldSpec(),        # dimensionless linear Zeeman
    "q" => FieldSpec(),        # quadratic Zeeman (coord-orthogonal scalar)
    "bx" => FieldSpec(),       # dimensionless transverse Bx
    "by" => FieldSpec(),       # dimensionless transverse By
    "Bx" => FieldSpec(),       # Gauss Cartesian
    "By" => FieldSpec(),
    "Bz" => FieldSpec(),
    "B_mag" => FieldSpec(),    # Gauss spherical: |B| magnitude
    "theta" => FieldSpec(),    # polar angle
    "phi" => FieldSpec(),      # azimuthal angle
    "p_mv" => FieldSpec(),     # coil-calibration lab-units (→ B_mag via calib)
    "coil_mode" => FieldSpec(; type=String),
)

# `loss:` block — three input shapes accepted by `_parse_loss_params`:
#   * Bool / Number (e.g. `loss: false`, `loss: 0.02`)
#   * Mapping with the keys below (validated here)
# `K3_per_m` (alias of `K3_per_m_cubic`) was removed 2026-05-24; canonical-only.
const LOSS_SCHEMA = Dict{String, FieldSpec}(
    "gamma_dr" => FieldSpec(; type=Number, range=(0.0, 1e10)),
    "L3" => FieldSpec(; type=Number, range=(0.0, 1e10)),
    "L3_per_m" => FieldSpec(; type=Vector),
    "K3_cubic" => FieldSpec(; type=Number, range=(0.0, 1e10)),
    "K3_per_m_cubic" => FieldSpec(; type=Vector),
    "K3_per_m_si" => FieldSpec(; type=Vector),  # SI-unit strings
    "evap_energy_cutoff" => FieldSpec(; type=Number, range=(0.0, 1e10)),
    "evap_rate" => FieldSpec(; type=Number, range=(0.0, 1e10)),
)

# `seed_mode:` block — deterministic single-mode symmetry-breaking seed
# (added 2026-05-22 alongside the random `seed_amplitude` / `seed_k_cut`
# pair). See `add_deterministic_mode_seed!` in
# `src/workflow/initialization/thermal_noise.jl`.
const SEED_MODE_SCHEMA = Dict{String, FieldSpec}(
    "k_vec" => FieldSpec(; required=true, type=Vector),  # ndim-length wavevector
    "amplitude" => FieldSpec(; required=true, type=Number, range=(0.0, 1.0)),
    "phase" => FieldSpec(; type=Number, range=(-1e6, 1e6)),  # radians
)

# `save:` block (dynamics output sub-block).
const SAVE_SCHEMA = Dict{String, FieldSpec}(
    "every" => FieldSpec(; type=Integer, range=(0.0, 1e9)),
    "n_snapshots" => FieldSpec(; type=Integer, range=(0.0, 1e6)),
    "psi" => FieldSpec(; type=Bool),
    "compression" => FieldSpec(; type=Union{Bool, String}),
    "precision" => FieldSpec(; type=String, enum=["f32", "f64"]),
)

# `magnetic_gradient:` block (dynamics + GS).
const MAGNETIC_GRADIENT_SCHEMA = Dict{String, FieldSpec}(
    "gradient" => FieldSpec(; required=true),  # scalar or waveform dict
    "axis" => FieldSpec(; type=Integer, range=(1.0, 3.0)),
    "g_F" => FieldSpec(; type=Number),
)

# `raman:` block. Optional all-around.
const RAMAN_SCHEMA = Dict{String, FieldSpec}(
    "Omega_R" => FieldSpec(; type=Number),
    "delta" => FieldSpec(; type=Number),
    "k_eff" => FieldSpec(; type=Vector),
    "omega_wf" => FieldSpec(; type=Dict),  # waveform mapping
    "delta_wf" => FieldSpec(; type=Dict),
)

# `absorbing_boundary:` block.
const ABSORBING_SCHEMA = Dict{String, FieldSpec}(
    "strength" => FieldSpec(; required=true, type=Number, range=(0.0, 1e10)),
    "width" => FieldSpec(; required=true, type=Number, range=(0.0, 1e6)),
    "power" => FieldSpec(; type=Integer, range=(1.0, 16.0)),
)

# `light_shift:` block. Parser path in `pipeline_dispatch.jl:_parse_light_shift`.
# eta_tensor + (eta_vector / polarization) is the supported branch; the
# alpha_* / profile keys are accepted at the schema level so users can write
# the keys without typo warnings, but the parser will throw ArgumentError if
# they are present (current implementation limit).
const LIGHT_SHIFT_SCHEMA = Dict{String, FieldSpec}(
    "eta_tensor" => FieldSpec(; type=Number),
    "eta_vector" => FieldSpec(; type=Number),
    "polarization" => FieldSpec(; type=Vector),
    "alpha_tensor" => FieldSpec(; type=Number),     # parser-error path
    "alpha_vector" => FieldSpec(; type=Number),     # parser-error path
    "profile" => FieldSpec(; type=Vector),          # parser-error path
)

# `twa:` block (`_parse_twa_config` in pipeline_dispatch.jl + `store_trajectories`
# read inline in run_step_dynamics.jl). n_trajectories is the only required key.
const TWA_SCHEMA = Dict{String, FieldSpec}(
    "n_trajectories" => FieldSpec(; required=true, type=Integer, range=(1.0, 1e9)),
    "seed_base" => FieldSpec(; type=Integer),
    "cutoff_energy" => FieldSpec(; type=Number),
    "observables" => FieldSpec(; type=Vector),
    "store_trajectories" => FieldSpec(; type=Bool, default=false),
)

# `sgpe:` block (`_build_sgpe_callback` in pipeline_callbacks.jl).
const SGPE_SCHEMA = Dict{String, FieldSpec}(
    "gamma" => FieldSpec(; required=true, type=Number, range=(0.0, 1e10)),
    "T" => FieldSpec(; required=true, type=Number, range=(0.0, 1e10)),
    "mu" => FieldSpec(; type=Number),
    "k_cut" => FieldSpec(; type=Number, range=(0.0, 1e10)),
    "every" => FieldSpec(; type=Integer, range=(1.0, 1e9)),
    "seed" => FieldSpec(; type=Integer),
)

# `projected_gp:` block (`_build_pgp_callback`).
const PROJECTED_GP_SCHEMA = Dict{String, FieldSpec}(
    "k_cut" => FieldSpec(; required=true, type=Number, range=(0.0, 1e10)),
    "smooth" => FieldSpec(; type=Bool, default=false),
    "every" => FieldSpec(; type=Integer, range=(1.0, 1e9)),
)

# `photon_scattering:` block (`_build_photon_callback`). Canonical
# `Gamma_sc` only; the lowercase `gamma_sc` alias was removed 2026-05-24.
const PHOTON_SCATTERING_SCHEMA = Dict{String, FieldSpec}(
    "Gamma_sc" => FieldSpec(; required=true, type=Number, range=(0.0, 1e10)),
    "seed" => FieldSpec(; type=Integer),
)

# `live_monitor:` block (`_build_live_callback`).
const LIVE_MONITOR_SCHEMA = Dict{String, FieldSpec}(
    "every" => FieldSpec(; type=Integer, range=(1.0, 1e9))
)

# Single entry in `pulse_sequence:` list. `compile_pulse_sequence` reads
# `t` + `apply` as positional; everything else is target-specific (B → p/q/bx/by,
# raman → Omega/delta/k_eff, interactions → c0/c1, trap → omega/center).
# Keys vary per `apply` target, so we leave the per-target params untyped
# but at least enforce the `t` / `apply` envelope.
const PULSE_EVENT_SCHEMA = Dict{String, FieldSpec}(
    "t" => FieldSpec(; required=true, type=Number, range=(0.0, 1e6)),
    # NOT "trap". `PULSE_TARGETS` (`runtime/pulse_sequence.jl:19`) is the set
    # `compile_pulse_sequence` actually compiles, and its own docstring records
    # that `apply: trap` was "documented in yaml_schema_reference.md but never
    # implemented" — it parsed, grouped, and compiled to NOTHING. Admitting it
    # here made that silent no-op reachable from a config that validates.
    "apply" => FieldSpec(; required=true, type=String,
        enum=["B", "raman", "interactions"]),
    "duration" => FieldSpec(; type=Number, range=(0.0, 1e6)),
    # Per-target params (left permissive; `_apply_pulse_sequence` validates):
    "p" => FieldSpec(), "q" => FieldSpec(), "bx" => FieldSpec(), "by" => FieldSpec(),
    "Omega" => FieldSpec(), "delta" => FieldSpec(), "k_eff" => FieldSpec(; type=Vector),
    "c0" => FieldSpec(), "c1" => FieldSpec(),
    "omega" => FieldSpec(), "center" => FieldSpec(; type=Vector),
)

const ADAPTIVE_DT_SCHEMA = Dict{String, FieldSpec}(
    "dt_init" => FieldSpec(; type=Number, range=(1e-8, 1.0)),
    "dt_min" => FieldSpec(; type=Number, range=(1e-10, 1.0)),
    "dt_max" => FieldSpec(; type=Number, range=(1e-8, 1.0)),
    "tol" => FieldSpec(; type=Number, range=(1e-12, 1.0)),
    "error_mode" => FieldSpec(; type=String,
        enum=["step_change", "richardson"]),
)

const DDI_SCHEMA = Dict{String, FieldSpec}(
    "enabled" => FieldSpec(; type=Bool, default=true),     # was false, flipped 2026-04-30
    "c_dd" => FieldSpec(; type=Union{Number, Dict}),
    "secular" => FieldSpec(; type=Bool, default=false),
    "quasi_2d" => FieldSpec(; type=Bool, default=false),
    "l_z" => FieldSpec(; type=Number, range=(0.0, 100.0)),
    # Ronen spherical-truncation radius (Tier A): a number (physical R),
    # "auto"/"box_half" for the largest radius the padding admits, or
    # "none"/"off" for the bare periodic kernel. Defaults to auto.
    "trunc_radius" => FieldSpec(; type=Union{Number, String}),
    # Tier B: zero-padded, image-free convolution + optional anisotropic pad.
    "padded" => FieldSpec(; type=Bool, default=true),   # was false, flipped 2026-07-29
    # A number, a per-axis vector, or "auto" (size the padding so the cutoff can
    # reach max(box) instead of being capped by the short axis).
    "pad_factor" => FieldSpec(; type=Union{Number, Vector, String}),
)

# `kind` selects the solver path:
#   spinor          (default)  — full F=2F+1 spinor GP, Larmor sub-cycled
#                              Use for static B / weak-field experiments.
#   binary                     — two-component miscible/immiscible GP
#                              (species_A, species_B blocks required).
#   rotating_basis             — B̂(t) rotating-direction frame (Option γ; see docs/design/option_gamma_rotating_basis.md)
#                              that absorbs Larmor analytically. Use for
#                              Klaus-style protocols where B direction
#                              evolves and p·F·dt would otherwise blow up.
const GS_SCHEMA = Dict{String, FieldSpec}(
    "kind" => FieldSpec(; type=String,
        enum=["spinor", "binary", "rotating_basis", "option_gamma"]),
    "dtype" => FieldSpec(; type=String, default="f64", enum=["f32", "f64"]),
    "species_A" => FieldSpec(; type=Dict),    # binary path
    "species_B" => FieldSpec(; type=Dict),    # binary path
    "B_direction" => FieldSpec(; type=Dict),        # rotating_basis path
    "F" => FieldSpec(; type=Integer, range=(0, 12)),   # rotating_basis F override
    "gauge_fix" => FieldSpec(; type=Bool, default=true),  # rotating_basis
    "init_m_idx" => FieldSpec(; type=Integer, range=(1, 25)),
    "init_sigma" => FieldSpec(; type=Number, range=(0.0, 100.0)),
    "method" => FieldSpec(; type=String, default="itp", enum=["itp", "lbfgs"]),
    "atom" => FieldSpec(; type=String),
    "grid" => FieldSpec(; type=Dict, schema=GRID_SCHEMA),
    "interactions" => FieldSpec(; type=Dict, schema=INTERACTIONS_SCHEMA),
    "ddi" => FieldSpec(; type=Union{Dict, Bool}),
    "B" => FieldSpec(; type=Dict, schema=B_SCHEMA),
    "potential" => FieldSpec(; type=Union{Dict, Vector}),
    "dt" => FieldSpec(; type=Number, default=0.001, range=(1e-8, 1.0)),
    "n_steps" => FieldSpec(; type=Number, default=100000, range=(0.0, 1e9)),
    "tol" => FieldSpec(; type=Number, default=1e-8, range=(1e-16, 1.0)),
    "tol_drho" => FieldSpec(; type=Number, default=0.0, range=(0.0, 1.0)),
    "m_lbfgs" => FieldSpec(; type=Number, default=10, range=(1.0, 100.0)),
    # Append a 2nd-order Newton-CG trust-region pass after LBFGS to drive the
    # stationarity residual below the first-order √eps gradient floor. Needed
    # when ∇E (not just E) must be tight — Hessian λ_min / Bogoliubov near
    # instabilities require a genuinely stationary ψ. lbfgs-only.
    "newton_polish" => FieldSpec(; type=Bool, default=false),
    # eigenvector-residual final polish (order-4 HvP) that breaks the √eps
    # first-order gradient floor (1e-7 → 1e-12); use when the fine GS ordering
    # (near-degenerate phases) needs a genuinely converged ψ. lbfgs-only.
    "residual_polish" => FieldSpec(; type=Bool, default=false),
    "initial_state" => FieldSpec(; type=String, default="polar",
        enum=["polar", "m_plus_F", "m_minus_F",
            "uniform", "antiferromagnetic", "random",
            "spin_coherent", "radial_spin_vortex", "flower", "spin_helix",
            "cyclic", "biaxial_nematic", "polar_core_vortex",
            "bright_soliton", "dark_soliton", "skyrmion",
            "gaussian_wavepacket", "domain_wall", "two_packets",
            "chiral_spin_vortex", "magnetic_domain",
            "vortex_lattice", "skyrmion_lattice",
            # `from_jld2`: load the initial ψ from a prior run's
            # result.jld2 instead of seeding a Gaussian. Pair with
            # `init_state_params: {path: ..., snap: last|N}`. Used to
            # continue a long Klaus / EdH run beyond its original
            # endpoint without re-running the spin-up phase.
            "from_jld2"]),
    "backend" => FieldSpec(; type=String, default="cpu", enum=["cpu", "gpu"]),
    "target_magnetization" => FieldSpec(; type=Number),
    "temperature_ratio" => FieldSpec(; type=Number, range=(0.0, 1.0)),
    "lhy" => FieldSpec(; type=Dict, schema=LHY_SCHEMA),
    "init_state_params" => FieldSpec(; type=Dict),
    # `seed_from: {run: <dir of point_*.jld2>, upsample: true}` — warm-start this
    # GS solve from a prior run's converged ψ, matched by the resolved cell
    # signature (c1/Bz/κ/initial_state) and spectrally upsampled to this grid.
    # Cost-compressed continuation (docs/design/eu_phase_diagram_adaptive_mapping.md).
    "seed_from" => FieldSpec(; type=Dict),
    # `pin: {kind: transverse, epsilon_ramp: [4.0e-3, 2.0e-3, 1.0e-3, 5.0e-4]}`
    # — lbfgs-only. Adds a symmetry-breaking transverse field b_x=ε, warm-ramps
    # ε→0, and reports the ε→0-extrapolated energy. Lifts the weak-field
    # soft-manifold Goldstone floor (|∇E|~0.05 un-pinned → ~1e-5). See
    # src/solvers/ground_state/pinned.jl + the phase-diagram design doc.
    "pin" => FieldSpec(; type=Dict),
    "cache" => FieldSpec(; type=String),
    "quasi_2d" => FieldSpec(; type=Bool),
    "l_z" => FieldSpec(; type=Number, range=(0.0, 100.0)),
    "noise_seed" => FieldSpec(; type=Number),
    "rotating_frame_omega" => FieldSpec(; type=Number),
    "light_shift" => FieldSpec(; type=Dict, schema=LIGHT_SHIFT_SCHEMA),
    "raman" => FieldSpec(; type=Dict, schema=RAMAN_SCHEMA),
)

const DYNAMICS_SCHEMA = Dict{String, FieldSpec}(
    "duration" => FieldSpec(; required=true, type=Number, range=(0.0, 1e6)),
    "dt" => FieldSpec(; required=true, type=Number, range=(1e-8, 1.0)),
    # LHY block override for dynamics. When absent, scalar LHY propagates
    # automatically via the inherited `prev_interactions.c_lhy` from the
    # preceding GS step; non-scalar (table-based) LHY does NOT propagate
    # implicitly and must be re-declared here. When present, the dynamics
    # step builds its own LHY at make_workspace time (overrides any
    # implicit inheritance). Mirrors `GROUND_STATE_SCHEMA["lhy"]`.
    "lhy" => FieldSpec(; type=Dict, schema=LHY_SCHEMA),
    # Unified `save:` block. Sub-keys: every (steps) | n_snapshots (frames)
    # | psi (Bool) | compression (Bool) | precision ("f32"|"f64").
    "save" => FieldSpec(; type=Dict, schema=SAVE_SCHEMA),
    "rotating_frame_omega" => FieldSpec(; type=Number),    # spatial (rotating bucket)
    "ddi" => FieldSpec(; type=Union{Dict, Bool}),
    "B" => FieldSpec(; type=Dict, schema=B_SCHEMA),
    "interactions" => FieldSpec(; type=Dict),
    "potential" => FieldSpec(; type=Union{Dict, Vector}),
    "temperature_ratio" => FieldSpec(; type=Number, range=(0.0, 1.0)),
    "seed_amplitude" => FieldSpec(; type=Number, range=(0.0, 1.0)),
    "seed_k_cut" => FieldSpec(; type=Number, range=(0.0, 1.0e6)),
    "seed_mode" => FieldSpec(; type=Dict, schema=SEED_MODE_SCHEMA),
    "hard_polarize" => FieldSpec(; type=Number, range=(-12.0, 12.0)),
    "noise_seed" => FieldSpec(; type=Number),
    # Standard dynamics path uses {strang, yoshida, adaptive, richardson};
    # rotating_basis uses {strang, yoshida4, yoshida6, cfet4}. Merged here
    # so a single DYNAMICS_SCHEMA entry covers both — kind dispatch picks
    # the right runtime path. The schema previously declared `integrator`
    # twice; the second declaration silently shadowed the first, causing
    # spurious "not valid" rejections of yoshida/adaptive/richardson on
    # the standard path.
    "integrator" => FieldSpec(; type=Union{String, Dict}),
    "backend" => FieldSpec(; type=String, enum=["cpu", "gpu"]),
    "raman" => FieldSpec(; type=Dict, schema=RAMAN_SCHEMA),
    "absorbing_boundary" => FieldSpec(; type=Dict, schema=ABSORBING_SCHEMA),
    "light_shift" => FieldSpec(; type=Dict, schema=LIGHT_SHIFT_SCHEMA),
    "twa" => FieldSpec(; type=Dict, schema=TWA_SCHEMA),
    "magnetic_gradient" => FieldSpec(; type=Dict, schema=MAGNETIC_GRADIENT_SCHEMA),
    "pulse_sequence" => FieldSpec(; type=Vector),
    "sgpe" => FieldSpec(; type=Union{Dict, Bool}, schema=SGPE_SCHEMA),
    "projected_gp" => FieldSpec(; type=Union{Dict, Bool}, schema=PROJECTED_GP_SCHEMA),
    "photon_scattering" => FieldSpec(; type=Union{Dict, Bool}, schema=PHOTON_SCATTERING_SCHEMA),
    "loss" => FieldSpec(; type=Union{Dict, Bool, Number}, schema=LOSS_SCHEMA),
    "adaptive_dt" => FieldSpec(; type=Dict, schema=ADAPTIVE_DT_SCHEMA),
    "live_monitor" => FieldSpec(; type=Union{Bool, Dict}, schema=LIVE_MONITOR_SCHEMA),
    # Two-component / binary GP path (Phase 4/5 #51 scaffold).
    "kind" => FieldSpec(; type=String, enum=["binary", "rotating_basis"]),
    "couplings" => FieldSpec(; type=Dict),
    # Option γ rotating-basis dynamics
    "B_direction" => FieldSpec(; type=Dict),
    "epsilon" => FieldSpec(; type=Number, range=(1e-15, 1.0)),
)

const STEP_SCHEMAS = Dict{String, Dict{String, FieldSpec}}(
    "ground_state" => GS_SCHEMA,
    "dynamics" => DYNAMICS_SCHEMA,
)

# Top-level YAML keys recognised by the runner. Anything else triggers
# a typo warning so users catch e.g. `pipline:` vs `pipeline:` early.
const TOP_LEVEL_KEYS = Set([
    "pipeline",
    "scan",
    "calibration",
    "calibration_history",
    "target_date",
    "units",             # opt-in lab-unit interpretation of bare Reals
    "defaults",          # per-step seeded fallbacks (DRY across pipeline)
    "mixins",            # named parameter sets pulled into the config
    "accuracy",          # ε accuracy budget — seeds rotating_basis epsilon
    "auto_grid",         # bool — enable TF-radius grid auto-derivation
    # `metadata` was here until the step-6 cutover. A structured slot with no
    # readers is a name nothing looks up: 59 keys across 302 configs, and the
    # only thing that can happen to a field nothing reads is that it rots —
    # `generator:` named a script that does not exist in 156 of them, each
    # under a header reading "auto-generated, do not hand-edit", and five of
    # the 59 "keys" were the wreckage of an unquoted comma in a flow mapping.
    # The blocks are preserved verbatim in
    # `docs/validation/config_metadata_blocks.toml`. Do not re-add: the point
    # is that provenance lives where it is READ (refs/*.toml via `ref`, the
    # A/B/C taxonomy via `Claim`), not in a slot that cannot be wrong.
    #
    # `name`, `notes` and `version` left with it, for the same reason and at no
    # cost: measured 2026-08-03, they have zero readers under `src/` and zero
    # occurrences across the 302 configs in `runs/`. They were three more slots
    # that could be written and never contradicted — and, because
    # `_canonical_bytes!` hashes every key it is handed, three more ways for a
    # label to move `content_id` and orphan a cached run. A comment does the
    # same job: `#` never reaches the hasher.
])

"""
    validate_config!(params::Dict, schema::Dict, path::String; strict::Bool=false)

Validate a YAML config dict against a schema.
- Unknown keys → warning (typo detection)
- Missing required keys → error
- Wrong type or out-of-range → error
- Invalid enum value → error
"""
function validate_config!(params::Dict, schema::Dict, path::String=""; strict::Bool=false)
    errors = String[]
    known = Set(keys(schema))

    # Check for unknown keys (likely typos). Suggest the closest match
    # via Levenshtein distance — catches "phi" → "phi_omega", etc.
    for k in keys(params)
        if !(k in known)
            full_key = isempty(path) ? string(k) : "$path.$k"
            suggestion = _suggest_key(string(k), known)
            base = "Unknown key '$full_key'"
            msg = if suggestion !== nothing
                "$base — did you mean '$suggestion'? Known keys: $(sort(collect(known)))"
            else
                "$base — possible typo? Known keys: $(sort(collect(known)))"
            end
            if strict
                push!(errors, msg)
            else
                @warn msg
            end
        end
    end

    # Check required keys
    for (k, spec) in schema
        if spec.required && !haskey(params, k)
            push!(errors, "Required key '$(isempty(path) ? k : "$path.$k")' is missing")
        end
    end

    # Type, range, and enum checks
    for (k, v) in params
        haskey(schema, k) || continue
        spec = schema[k]
        full_key = isempty(path) ? k : "$path.$k"

        # Type check
        if spec.type !== Any && !(v isa spec.type)
            # Allow Number → Bool promotion, Int → Float64, etc.
            ok =
                (spec.type <: Number && v isa Number) ||
                (spec.type === String && v isa AbstractString) ||
                (spec.type === Bool && v isa Bool) ||
                (spec.type isa Union && any(T -> v isa T, Base.uniontypes(spec.type)))
            if !ok
                push!(errors, "'$full_key' expected $(spec.type), got $(typeof(v))")
            end
        end

        # Range check
        if spec.range !== nothing && v isa Number
            lo, hi = spec.range
            (lo <= Float64(v) <= hi) || push!(errors,
                "'$full_key' = $v is out of range [$lo, $hi]")
        end

        # Enum check
        if spec.enum !== nothing && v isa AbstractString
            String(v) in spec.enum || push!(errors,
                "'$full_key' = '$v' is not valid. Options: $(spec.enum)")
        end

        # Nested schema
        if spec.schema !== nothing && v isa Dict
            validate_config!(v, spec.schema, full_key; strict)
        end
    end

    if !isempty(errors)
        throw(ArgumentError("Config validation errors:\n" * join(["  • $e" for e in errors], "\n")))
    end
end

"""
    validate_pipeline!(data::Dict)

Validate a full pipeline YAML dict. Checks each step against its schema.
"""
function validate_pipeline!(data::Dict; strict::Bool=false)
    # Top-level typo guard. In strict mode (production runner default)
    # unknown keys become errors — silent drops here have caused entire
    # physics regressions (2026-04-27 `trap:` incident: pancake YAML ran
    # in isotropic trap because `trap:` was not recognized and the
    # @warn was easy to miss in the noise).
    unknown_top = String[]
    for k in keys(data)
        sk = String(k)
        sk in TOP_LEVEL_KEYS && continue
        push!(unknown_top, sk)
    end
    if !isempty(unknown_top)
        msg = "Unknown top-level YAML key(s) $unknown_top — typo? Recognised: $(sort(collect(TOP_LEVEL_KEYS)))"
        strict ? throw(ArgumentError(msg)) : @warn msg
    end

    pipeline = get(data, "pipeline", nothing)
    pipeline === nothing && throw(ArgumentError("YAML must have a 'pipeline:' key"))
    pipeline isa Vector || throw(ArgumentError("'pipeline' must be a list of steps"))

    for (i, step) in enumerate(pipeline)
        step isa Dict || throw(ArgumentError("Pipeline step $i must be a dict"))
        step_keys = collect(keys(step))
        length(step_keys) == 1 || throw(ArgumentError(
            "Pipeline step $i must have exactly one key, got: $step_keys"))
        step_type = String(step_keys[1])
        step_params = step[step_keys[1]]

        if haskey(STEP_SCHEMAS, step_type) && step_params isa Dict
            validate_config!(step_params, STEP_SCHEMAS[step_type],
                "pipeline.$i.$step_type"; strict)
            # Cross-field F-dependent validation.
            if step_type == "ground_state"
                _validate_ground_state_physics!(step_params,
                    "pipeline.$i.ground_state", data; strict)
            elseif step_type == "dynamics"
                _validate_dynamics_physics!(step_params,
                    "pipeline.$i.dynamics"; strict)
            end
        elseif !(step_type in ("ground_state", "dynamics", "analyze"))
            msg = "Unknown pipeline step kind '$step_type' (line $i) — typo? Recognised: ground_state, dynamics, analyze"
            strict ? throw(ArgumentError(msg)) : @warn msg
        end
    end
end

"""
    _validate_ground_state_physics!(step_params, path, top_level; strict)

F-dependent cross-field validation that the static schema cannot express:

- `c1_ratio > -1/F²` (singularity in `interaction_params_from_constraint`:
  `c0 = c_total / (1 + F²·c1_ratio)`, so values at or below `-1/F²` give
  `c0 ≤ 0` — non-physical density attraction).
- `lhy.kind` ↔ F mapping: `polar_two_channel` is polar-only-up-to-F=2,
  `icosahedral` is F=6 specific, `full_bdg` on an ansatz that has a closed
  form is correct but ~100× slower (advisory only).
- Lab-units `B.{p_mv, coil_mode}` requires a top-level `calibration:`
  (or `calibration_history:`) block to expand against.

The schema's `c1_ratio` range `(-1.0, 1.0)` is generous on purpose so
F=1 (singularity at -1) and F=6 (singularity at -1/36) share one declaration.
This function tightens it once `F` is known.
"""
function _validate_ground_state_physics!(step_params::Dict, path::String,
    top_level::Dict; strict::Bool=false)
    # Resolve F: prefer `atom:` lookup, fall back to F=1 if neither given.
    atom_str = get(step_params, "atom", nothing)
    F = if atom_str !== nothing
        a = resolve_atom(Symbol(String(atom_str)))
        a !== nothing ? a.F : 1
    else
        1
    end

    inter = get(step_params, "interactions", nothing)
    if inter isa Dict && haskey(inter, "c1_ratio")
        cr_raw = inter["c1_ratio"]
        cr = if cr_raw isa Number
            Float64(cr_raw)
        else
            (cr_raw isa Dict && haskey(cr_raw, "from") ? Float64(cr_raw["from"]) : 0.0)
        end
        bound = -1.0 / F^2
        if cr <= bound + 1e-10
            msg =
                "$path.interactions[1]_ratio = $cr is at or below the singularity " *
                "-1/F² = $(round(bound; sigdigits=4)) for F=$F. " *
                "interaction_params_from_constraint gives c0 → ∞ or c0 ≤ 0 (non-physical). " *
                "Use c1_ratio > $(round(bound; sigdigits=4))."
            strict ? throw(ArgumentError(msg)) : @warn msg
        end
    end

    # LHY kind ↔ F constraints (memory: `lhy_refactor_2026_05_12.md`).
    lhy = get(step_params, "lhy", nothing)
    if lhy isa Dict
        kind = String(get(lhy, "kind", "none"))
        init = String(get(step_params, "initial_state", "polar"))
        if kind == "polar_two_channel" && F > 2
            msg =
                "$path.lhy.kind = polar_two_channel is exact at F=1, ~1% off at F=2, " *
                "30-70% off at F=$F. Use `polar_contact` / `polar_dipolar` for polar " *
                "(or `fm_contact` / `fm_dipolar` for ferromagnetic, " *
                "`icosahedral` for F=6 I_h)."
            strict ? throw(ArgumentError(msg)) : @warn msg
        elseif kind == "icosahedral" && F != 6
            msg = "$path.lhy.kind = icosahedral is F=6 specific (I_h symmetry); got F=$F."
            strict ? throw(ArgumentError(msg)) : @warn msg
        elseif kind == "full_bdg" && init in ("polar", "ferromagnetic")
            @info "$path.lhy.kind = full_bdg is the general-spinor BdG path; for the " *
                "$init ansatz the closed form is ~100× cheaper and agrees to ~1e-4 " *
                "(gated by test/oracles/test_lhy_full_bdg_closed_form_parity.jl). " *
                "Consider `polar_contact` / `polar_dipolar` / `fm_contact` / `fm_dipolar`."
        end
    end

    # Lab-units calibration requirement: `B.{p_mv, coil_mode}` needs a
    # top-level calibration block to resolve against.
    b = get(step_params, "B", nothing)
    if b isa Dict && (haskey(b, "p_mv") || haskey(b, "coil_mode"))
        has_calib = haskey(top_level, "calibration") || haskey(top_level, "calibration_history")
        if !has_calib
            msg =
                "$path.B uses lab-units (p_mv / coil_mode) but no top-level " *
                "`calibration:` or `calibration_history:` block is present. " *
                "Add the calibration block, or use direct Gauss / dimensionless input."
            strict ? throw(ArgumentError(msg)) : @warn msg
        end
    end
end

"""
    _validate_dynamics_physics!(step_params, path; strict)

Cross-field validation for `dynamics:` steps:

- `spin_rotating_frame_omega ≠ 0` requires `ddi.secular = true` (full DDI
  off-diagonals only Larmor-average to zero in the secular limit; the
  runtime check in `make_workspace.jl:131` reproduces this).
"""
function _validate_dynamics_physics!(step_params::Dict, path::String; strict::Bool=false)
    sro = get(step_params, "spin_rotating_frame_omega", nothing)
    if sro isa Number && abs(Float64(sro)) > 1e-15
        ddi = get(step_params, "ddi", nothing)
        secular = ddi isa Dict ? get(ddi, "secular", false) : false
        if !(secular === true || secular == true)
            msg =
                "$path.spin_rotating_frame_omega = $sro ≠ 0 but `ddi.secular` is " *
                "not set to true. Full DDI off-diagonals only Larmor-average to " *
                "zero in the secular limit; set `ddi: {secular: true}` (or use a " *
                "non-rotating spin frame)."
            strict ? throw(ArgumentError(msg)) : @warn msg
        end
    end
end

# Levenshtein distance for typo suggestions. Returns the closest key in
# `known` if its distance to `k` is ≤ max(2, |k|/3) — close enough to
# almost certainly be a typo. nothing otherwise.
function _suggest_key(k::String, known::Set)
    isempty(known) && return nothing
    threshold = max(2, length(k) ÷ 3)
    best, best_d = nothing, threshold + 1
    for cand in known
        c = string(cand)
        d = _levenshtein(k, c)
        if d < best_d
            best, best_d = c, d
        end
    end
    best_d <= threshold ? best : nothing
end

function _levenshtein(a::AbstractString, b::AbstractString)
    m, n = length(a), length(b)
    m == 0 && return n
    n == 0 && return m
    av, bv = collect(a), collect(b)
    prev = collect(0:n)
    curr = zeros(Int, n + 1)
    for i in 1:m
        curr[1] = i
        for j in 1:n
            cost = av[i] == bv[j] ? 0 : 1
            curr[j + 1] = min(curr[j] + 1, prev[j + 1] + 1, prev[j] + cost)
        end
        prev, curr = curr, prev
    end
    prev[n + 1]
end
