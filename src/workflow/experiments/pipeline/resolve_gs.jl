# --- resolve_gs: the ONE resolution of a `ground_state:` block ---
#
# Cutover step 1b. Flipping admission to `artifact_id` (step 3) needs a resolver
# from raw YAML to a `Model`, and there was none. The tempting shape — a second
# function that re-reads `potential:` / `B:` / `lhy:` / `ddi:` — is a parallel
# declaration of the same physics, which is the disease this whole design
# deletes: two readers of one block drift, and the drift is silent because each
# is self-consistent.
#
# So there is one resolver with two consumers:
#
#   `_run_step(::GroundStateStep, …)`  →  the objects the solver takes
#   `yaml_to_model(path)`              →  `gs_model(r)`, a pure function of the
#                                          SAME resolved objects
#
# `gs_model` never touches `p`. Everything it needs that the solver does not
# (`N_atoms`, `omega_ref`, the light-shift coupling triple, the dealias globals)
# is read HERE, once, and carried in `GSResolved`. If a future edit finds itself
# reading `p["potential"]` outside this file, that is the second parser
# reappearing.
#
# `resolve_gs` has exactly the failure modes `_run_step` had before the
# extraction — it is the same code in the same order. Building a `Model` can
# fail where a solve would not (a config with no `N_atoms`, a tabulated LHY with
# no resolved `n_max`), so that failure lives in `gs_model`, which only
# `yaml_to_model` calls. `_run_step`'s behaviour therefore does not change.
#
# NOT GENERALIZABLE: the `@noinline` + `::ConcreteType` boundary is load-bearing
# here for the same reason it is in `run_step_ground_state.jl` — see that file's
# header and CLAUDE.md §"Type stability boundaries".

export resolve_gs, gs_model, yaml_to_model, GSResolved, gs_physics_kwargs

# ---------------------------------------------------------------------------
# The per-slot resolvers (moved verbatim from run_step_ground_state.jl)
# ---------------------------------------------------------------------------

"""
Resolve the atom for a GS step: parse from p["atom"] when present (and
populate derived params), else inherit from atom_prev. Throws when neither
is available. @noinline boundary plus the `::AtomSpecies` return assertion
in the caller keeps the `Dict{String,Any}` typed parsing local — preserving
the inference fence pattern that prevents a Workspace JIT cascade
(see CLAUDE.md "Type stability boundaries").

MUTATES `p`: `_resolve_derived_params!` writes `ddi["c_dd"]`, `ddi["l_z"]`,
`interactions["c_lhy"]`, `p["lhy_kind"]` and `p["lhy_opts"]`. Every later
resolver reads those, so this must run FIRST — and on an inheriting step
(no `atom:` key) it does not run at all, which is why such a step has no
derived `c_dd` and no `lhy_opts`.
"""
@noinline function _resolve_gs_atom(p::Dict{String, Any}, atom_prev; verbose::Bool=true)
    if haskey(p, "atom")
        a = resolve_atom(Symbol(p["atom"]))
        _resolve_derived_params!(p, a; verbose)
        return a
    elseif atom_prev !== nothing
        return atom_prev
    else
        throw(ArgumentError("ground_state step requires 'atom' (no previous step to inherit from)"))
    end
end

@noinline function _resolve_gs_grid(p::Dict{String, Any}, grid_prev)
    if haskey(p, "grid")
        return _setup_grid_from_params(p)
    elseif grid_prev !== nothing
        return (grid_prev, length(grid_prev.config.n_points))
    else
        throw(ArgumentError("ground_state step requires 'grid' (no previous step to inherit from)"))
    end
end

@noinline function _resolve_gs_interactions(p::Dict{String, Any}, ws_prev, atom)
    if haskey(p, "interactions")
        return _parse_gs_interactions(p["interactions"], atom)
    elseif ws_prev !== nothing
        return ws_prev.interactions
    else
        return _parse_gs_interactions(Dict{String, Any}(), atom)
    end
end

"""
DDI resolution with inheritance: explicit `ddi:` re-parses; otherwise
inherit from `ws_prev.ddi`; final fallback derives from `interactions:`
alone (works only on a fresh GS step where N_atoms+omega_ref are both
present).

The `ws_prev` arm is LOSSY and cannot be otherwise: `DDIParams`
(`foundation/types/ddi_loss.jl:17`) carries `C_dd`, the six `Q` tensors and
`box_size` — the secular / quasi-2-D / truncation / padding flags are baked
into the kernels and are not fields, so an inheriting step cannot recover
its predecessor's declaration and rebuilds a bare unpadded kernel.
"""
@noinline function _resolve_gs_ddi_inheritance(p::Dict{String, Any}, ws_prev, atom)
    if haskey(p, "ddi")
        return _parse_gs_ddi(p["ddi"], get(p, "interactions", Dict()), atom)
    elseif ws_prev !== nothing && ws_prev.ddi !== nothing
        return (true, ws_prev.ddi.C_dd, false, false, 0.0, NaN, false, 2.0)
    elseif haskey(p, "interactions")
        return _parse_gs_ddi(Dict{String, Any}(), p["interactions"], atom)
    else
        return (false, NaN, false, false, 0.0, NaN, false, 2.0)
    end
end

@noinline function _resolve_gs_potential(p::Dict{String, Any}, ws_prev, ndim::Int)
    if haskey(p, "potential")
        return _parse_and_build_potential(p["potential"], ndim)
    elseif ws_prev !== nothing
        return ws_prev.potential
    else
        return _parse_and_build_potential(Dict("type" => "harmonic", "omega" => ones(ndim)), ndim)
    end
end

# ---------------------------------------------------------------------------
# GSResolved
# ---------------------------------------------------------------------------

# GS_SCHEMA keys that name PHYSICS the spinor ground-state runner never reads.
# Each is a real schema-admits / runner-ignores gap, listed here so a model
# built over such a config fails loudly instead of quietly describing something
# the run did not do.
#
#   quasi_2d / l_z  — declared at `schema.jl:324-325` and accepted by
#                     `find_ground_state`, but `_run_step(::GroundStateStep, …)`
#                     never reads either (only `quasi_2d_ddi`, which comes from
#                     the `ddi:` block).
#   raman           — declared at `schema.jl:330`; `find_ground_state` has no
#                     `raman` kwarg at all, so the block is dropped.
#   B_direction     — written by `apply_B_block_normalize!` from `B.theta` /
#                     `B.phi`; ONLY the rotating-basis path reads it
#                     (`run_step_rotating/ground_state.jl:147`), so on this path
#                     a tilted field silently runs along +z.
#   a_s             — scattering length in BOHR RADII, read only by
#                     `_scalar_egpe_couplings` (`kind: scalar_egpe`). On the
#                     spinor path the run silently uses the ATOM_REGISTRY value
#                     instead, which for ¹⁶²Dy is 122 a₀ against the 109-112 a₀
#                     a dipolar-vortex paper works at — a 10 % error in ε_dd
#                     that nothing would print.
#   ddi_pad         — per-axis zero-pad factors for the SCALAR dipolar
#                     convolution (`ScalarDDIPad`). The spinor path has its own
#                     `ddi.padded` / `ddi.pad_factor`; this key does not reach it.
#   B_magnitude_gauss — carried for `spin_treatment_report` only. The scalar
#                     path has no Zeeman term at all; the field enters solely as
#                     a direction, so this is provenance, not physics.
#
# The partition of GS_SCHEMA into {reaches a Model slot, reaches Stage/Initial,
# dropped} is pinned in `test/model/test_yaml_to_model.jl`; adding a schema key
# without classifying it is red there.
const GS_KEYS_DROPPED_PHYSICS = ("quasi_2d", "l_z", "raman", "B_direction",
    "a_s", "ddi_pad", "B_magnitude_gauss")

"""
    GSResolved

Everything one `ground_state:` block resolves to. The first block is what the
solver takes (types unchanged from before the extraction); the second is what
`gs_model` needs and the solver does not.

`grid`, `potential`, `zeeman`, `light_shift` and `backend` are declared with
the same abstract types `make_workspace` declares for its own kwargs — they were
inferred as `Any` at the old call site, so this is no looser, and the DDI eight
are strictly narrower here than the union-of-tuples they used to be destructured
from.
"""
struct GSResolved
    # --- what the solver consumes ---
    method::Symbol
    atom::AtomSpecies
    grid::Grid
    ndim::Int
    interactions::InteractionParams
    potential::AbstractPotential
    backend::AbstractBackend
    tol::Float64
    n_steps::Int
    dt::Float64
    duration::Float64
    zeeman::Union{ZeemanParams, TimeDependentZeeman, ZeemanField}
    light_shift::Union{Nothing, LightShift}
    # Named for the kwarg it feeds, and named at all so that it travels beside
    # `lhy_opts`: `test/oracles/test_lhy_table_path_coverage.jl` invariant 1
    # requires the pair in every file that carries either, because splitting
    # them is defect #174 — `lhy_opts` carries `n_atoms`, so a defaulted one
    # makes every table N_atoms too strong. Calling this `lhy_kind` split the
    # pair and reddened that oracle.
    spinor_lhy::Union{Nothing, Symbol}
    lhy_opts::LHYTableOpts
    rf_omega::Float64
    # the eight the `ddi:` block resolves to, named instead of positional
    enable_ddi::Bool
    c_dd::Float64
    secular::Bool
    quasi_2d_ddi::Bool
    l_z_ddi::Float64
    ddi_trunc::Float64
    ddi_padded::Bool
    ddi_pad_factor::Union{Float64, NTuple{1, Float64}, NTuple{2, Float64}, NTuple{3, Float64}}
    # --- what only the model needs ---
    n_atoms::Union{Nothing, Int}
    omega_ref::Union{Nothing, Float64}
    light_shift_spec::LightShiftSpec
    dealias_two_thirds::Bool
    dealias_k_cut::Float64
    dropped_physics::Vector{String}
end

"""
    gs_physics_kwargs(r::GSResolved) -> NamedTuple

The seventeen physics kwargs, spelled with the names `make_workspace`,
`find_ground_state` and `find_ground_state_lbfgs` all three accept.

`run_step_ground_state.jl` called those three functions with this bundle written
out LONGHAND at each site. Seventeen kwargs, three copies, one function — and on
2026-08-02 two branches independently added the same three entries to one of the
copies, git merged both without a conflict, and the package stopped parsing
(`fix: the merge duplicated three make_workspace kwargs`). The copies are what
made a textual merge plausible; a merge cannot duplicate a function call.

Runtime and solver knobs are NOT here: `sim_params`, `psi_init`, `n_steps`,
`tol`, `dt`, `verbose`, and the LBFGS/ITP-specific options differ per call site
because they genuinely differ. This bundle is exactly the part that must not.

Concretely typed throughout (every `GSResolved` field is declared), so splatting
it into a kwarg call keeps the inference fence `run_step_ground_state.jl`'s
header describes — CLAUDE.md §"Type stability boundaries".
"""
gs_physics_kwargs(r::GSResolved) = (
    grid=r.grid,
    atom=r.atom,
    interactions=r.interactions,
    zeeman=r.zeeman,
    potential=r.potential,
    enable_ddi=r.enable_ddi,
    c_dd=r.c_dd,
    secular_ddi=r.secular,
    quasi_2d_ddi=r.quasi_2d_ddi,
    l_z_ddi=r.l_z_ddi,
    ddi_trunc_radius=r.ddi_trunc,
    ddi_padding=r.ddi_padded,
    ddi_pad_factor=r.ddi_pad_factor,
    backend=r.backend,
    light_shift=r.light_shift,
    spinor_lhy=r.spinor_lhy,
    lhy_opts=r.lhy_opts,
)

# `gs_ddi_tuple(r)` — the eight DDI values as the positional tuple
# `_parse_gs_ddi` returns — lived here to feed `_gs_cache_key`, which hashed
# them. Cutover step 3 deleted that key: the DDI half of the id is `DDISpec` now,
# built from the named fields, and the tuple had no other consumer. Deleted
# rather than kept "in case", which is how a second declaration of the DDI block
# would come back.

# `_parse_light_shift` builds a `LightShift`, which holds the MATERIALISED
# profile and the eigenvectors of the already-diagonalised operator — the two
# coupling strengths and the polarization are gone by then. So the spec is read
# off the same raw block, here, next to the call that consumes it: one site, two
# products. `test/model/test_yaml_to_model.jl` gates the pair (a raw block that
# yields a `LightShift` must yield an ACTIVE spec, and vice versa).
function _light_shift_spec(raw)
    raw isa Dict || return LightShiftSpec()
    haskey(raw, "eta_tensor") || return LightShiftSpec()
    LightShiftSpec(;
        eta_tensor=Float64(raw["eta_tensor"]),
        eta_vector=Float64(get(raw, "eta_vector", 0.0)),
        polarization=NTuple{3, Float64}(Tuple(Float64.(get(raw, "polarization", [0, 0, 1])))))
end

_is_trivial_direction(d) =
    !(d isa AbstractDict) ||
    all(k -> !haskey(d, k) || Float64(d[k]) == 0.0, ("theta", "phi"))

"""
    resolve_gs(p, grid_prev, atom_prev, ws_prev; verbose=true) -> GSResolved

Resolve one `ground_state:` step's params. `p` is the step dict as
`parse_pipeline` produced it — i.e. AFTER `_run_yaml_prepare` (dealias pop,
calibration, mixins, schema defaults, units, B-block) and AFTER the top-level
`defaults:` seeding, which 414 of 416 committed configs rely on.

Mutates `p` through `_resolve_gs_atom` exactly as the pre-extraction code did.
Idempotent in effect: `_resolve_derived_params!` guards `ddi["c_dd"]` with
`haskey` and rewrites the other slots to the same values.
"""
@noinline function resolve_gs(p::Dict{String, Any}, grid_prev, atom_prev, ws_prev;
    verbose::Bool=true)::GSResolved
    method = Symbol(get(p, "method", "itp"))

    atom = _resolve_gs_atom(p, atom_prev; verbose)::AtomSpecies
    grid, ndim = _resolve_gs_grid(p, grid_prev)
    interactions = _resolve_gs_interactions(p, ws_prev, atom)::InteractionParams
    gs_ddi = _resolve_gs_ddi_inheritance(p, ws_prev, atom)
    enable_ddi, c_dd_val, secular, q2d, lz, ddi_trunc, ddi_padded_b, ddi_pf = gs_ddi
    potential = _resolve_gs_potential(p, ws_prev, ndim)

    backend = if haskey(p, "backend")
        _resolve_backend(Symbol(p["backend"]))
    elseif ws_prev !== nothing
        ws_prev.backend
    else
        CPUBackend()
    end

    tol = Float64(get(p, "tol", 1e-8))
    n_steps = Int(get(p, "n_steps", method === :lbfgs ? 500 : 100000))
    dt = Float64(get(p, "dt", 0.001))
    duration = dt * n_steps
    zeeman = if haskey(p, "B")
        _build_zeeman_from_b_block(p["B"], duration, atom, p)
    elseif ws_prev !== nothing
        ws_prev.zeeman
    else
        _parse_zeeman(Dict(), duration)
    end

    # Hoisted above the cache branch by this extraction: before it, these four
    # were resolved ~170 lines below the cache-hit `return`, so a cached GS
    # rebuilt its workspace with no LHY, no light shift and no rotating frame.
    # The trap is evaluated only when there IS a light shift — `_parse_light_shift`
    # returns `nothing` for a non-Dict block, so the grid-sized array was pure
    # cost on the ~100 % of steps that declare none.
    ls_raw = get(p, "light_shift", nothing)
    gs_light_shift = if ls_raw isa Dict
        _parse_light_shift(ls_raw, atom.F, evaluate_potential(potential, grid),
            backend)
    else
        nothing
    end
    # `_resolve_lhy_block!` writes the resolved LHY mode (from the user-facing
    # `lhy: {kind: ...}` block) into the internal `lhy_kind` slot. Prior to
    # 2026-05-22 this read `p["spinor_lhy"]` — a stale reference to the old
    # YAML key — which was never written by the new resolver, silently
    # disabling non-scalar LHY modes (polar_contact / icosahedral / ...)
    # for every YAML pipeline run.
    spinor_lhy_mode = let v = get(p, "lhy_kind", nothing)
        v === nothing ? nothing : Symbol(String(v))
    end
    # `::LHYTableOpts` narrows the `Any` a Dict lookup yields — CLAUDE.md
    # "type stability boundaries": an Any-typed local reaching make_workspace
    # is what turns into a multi-minute JIT hang with no stack trace.
    gs_lhy_opts = get(p, "lhy_opts", LHYTableOpts())::LHYTableOpts
    gs_rf_omega = Float64(get(p, "rotating_frame_omega", 0.0))

    # --- model-only reads, all of them here so `gs_model` touches no dict ---
    inter_raw = get(p, "interactions", nothing)
    n_atoms = _gs_opt_int(inter_raw, "N_atoms", p)
    omega_ref = _gs_opt_float(inter_raw, "omega_ref", p)
    dropped = String[k for k in GS_KEYS_DROPPED_PHYSICS if haskey(p, k)]
    # A `B_direction` of θ=φ=0 is what `apply_B_block_normalize!` leaves behind
    # for a purely axial field; it names no physics the run dropped.
    _is_trivial_direction(get(p, "B_direction", nothing)) &&
        filter!(!=("B_direction"), dropped)

    GSResolved(method, atom, grid, ndim, interactions, potential, backend,
        tol, n_steps, dt, duration, zeeman, gs_light_shift, spinor_lhy_mode,
        gs_lhy_opts, gs_rf_omega,
        Bool(enable_ddi), Float64(c_dd_val), Bool(secular), Bool(q2d), Float64(lz),
        Float64(ddi_trunc), Bool(ddi_padded_b), _gs_pad_factor(ddi_pf),
        n_atoms, omega_ref, _light_shift_spec(ls_raw),
        DEALIAS_2_3_ENABLED[], _dealias_k_cut_value(), dropped)
end

_gs_pad_factor(x::Real) = Float64(x)
_gs_pad_factor(x::Tuple) = NTuple{length(x), Float64}(Float64.(x))
_gs_pad_factor(x::AbstractVector) = _gs_pad_factor(Tuple(x))

# `N_atoms` / `omega_ref` normally live under `interactions:`; several configs
# and both `_resolve_omega_ref` (`b_block_builders.jl:88`) and
# `_auto_grid_from_physics` (`auto_defaults.jl:98`) already accept them at step
# level, so the same fallback applies here.
function _gs_opt_int(inter_raw, key::String, p::Dict{String, Any})
    v = inter_raw isa AbstractDict ? get(inter_raw, key, nothing) : nothing
    v === nothing && (v = get(p, key, nothing))
    v === nothing ? nothing : Int(v)
end
function _gs_opt_float(inter_raw, key::String, p::Dict{String, Any})
    v = inter_raw isa AbstractDict ? get(inter_raw, key, nothing) : nothing
    v === nothing && (v = get(p, key, nothing))
    v === nothing ? nothing : Float64(v)
end

# `DEALIAS_K_CUTOFF[]` is `Union{Nothing, Float64}`; `GridSpec` spells "no
# explicit cutoff" as 0.0, and its constructor rejects a negative value, so the
# two vocabularies meet exactly here.
_dealias_k_cut_value() =
    let v = DEALIAS_K_CUTOFF[]
        v === nothing ? 0.0 : Float64(v)
    end

# ---------------------------------------------------------------------------
# gs_model — GSResolved → Model. Reads no dict.
# ---------------------------------------------------------------------------

"""
    gs_model(r::GSResolved) -> Model

The resolved physics of `r`, as one value.

Fails rather than guessing. A `Model` that silently substituted a default for a
number the config never gave would be a wrong answer wearing a content id, and
the store is shared — so every gap throws, naming the slot and the reason.

Slots a ground-state step cannot set take their inactive value, and which those
are is pinned in `test/model/test_yaml_to_model.jl` against `GS_SCHEMA` rather
than assumed here.
"""
function gs_model(r::GSResolved)::Model
    isempty(r.dropped_physics) || throw(
        ArgumentError(
            "ground_state step declares " * join(r.dropped_physics, ", ") *
            ", which the spinor ground-state runner does not read — a model over this " *
            "config would describe physics the run drops. Move the block to the " *
            "dynamics step, or delete it."),
    )
    r.n_atoms === nothing && throw(
        ArgumentError(
            "ground_state step has no N_atoms; a model needs it (the tabulated LHY and " *
            "every SI conversion in the layer are per-N) and nothing downstream can " *
            "recover it from the resolved couplings"),
    )
    r.omega_ref === nothing && throw(
        ArgumentError(
            "ground_state step has no omega_ref; it is the anchor for every conversion " *
            "in the layer (Gauss->p, Hz->dimensionless, SI K3->dimensionless), so the " *
            "rest of the model is not interpretable without it"),
    )
    # Found by cutover step 3's acceptance condition (`artifact_id` must be at
    # least as discriminating as the key it replaces, and `c_lhy` was one of that
    # key's 19 entries). `_resolve_lhy_block!` copies `lhy.c_lhy` into
    # `interactions.c_lhy` for ANY kind but only sets `lhy_kind` when the kind is
    # not `none` — so `lhy: {kind: none, c_lhy: 5.0}` reaches `make_workspace`
    # with `spinor_lhy === nothing` and a nonzero `c_lhy`, which builds a
    # `ScalarLHY` (`make_workspace.jl:435`). `_lhy_spec` would return the
    # INACTIVE `LHYSpec()` for it, i.e. a model claiming there is no LHY over a
    # run that has one. Refused, not repaired: repairing it would mean guessing
    # which kind the user meant. No committed config is this shape.
    if r.spinor_lhy === nothing || r.spinor_lhy === :none
        r.interactions.c_lhy == 0.0 || throw(
            ArgumentError(
                "ground_state step resolves to c_lhy = $(r.interactions.c_lhy) with no LHY " *
                "kind (lhy_kind = $(repr(r.spinor_lhy))). make_workspace builds a ScalarLHY " *
                "from a nonzero c_lhy regardless, so the run HAS an LHY term and a model " *
                "over it would say it does not. Declare `lhy: {kind: scalar, c_lhy: ...}`"),
        )
    end

    pot, grad = _potential_and_gradient_specs(r)
    Model(;
        grid=_grid_spec(r),
        atom=r.atom,
        interactions=_interaction_spec(r),
        potential=pot,
        zeeman=_zeeman_spec(r),
        ddi=_ddi_spec(r),
        lhy=_lhy_spec(r),
        light_shift=r.light_shift_spec,
        magnetic_gradient=grad,
        frame=FrameSpec(; rotating_omega=r.rf_omega),
        # A ground-state step reaches none of these: `raman` and `quasi_2d`/`l_z`
        # are refused above (GS_KEYS_DROPPED_PHYSICS), and `absorbing_boundary`,
        # `sgpe`, `projected_gp`, `photon_scattering` and `loss` are
        # DYNAMICS_SCHEMA keys with no ground-state spelling at all.
        raman=RamanSpec(),
        geometry=GeometrySpec(),
        reservoir=ReservoirSpec(),
        loss=LossParams(),
    )
end

_grid_spec(r::GSResolved) = GridSpec(;
    ndim=r.ndim,
    n_points=r.grid.config.n_points,
    box=r.grid.config.box_size,
    dealias_two_thirds=r.dealias_two_thirds,
    dealias_k_cut=r.dealias_k_cut)

# `InteractionParams.c` is a rank => coupling Dict. Ranks 0 and 1 are `c0`/`c1`;
# the even ranks >= 2 are the extra contact channels, carried as sorted parallel
# vectors because a Dict has no canonical iteration order.
function _interaction_spec(r::GSResolved)
    c = r.interactions.c
    ranks = sort!([k for k in keys(c) if k >= 2])
    InteractionSpec(;
        n_atoms=r.n_atoms::Int,
        omega_ref=r.omega_ref::Float64,
        c0=get(c, 0, 0.0),
        c1=get(c, 1, 0.0),
        c_extra_ranks=ranks,
        c_extra_values=Float64[c[k] for k in ranks])
end

function _ddi_spec(r::GSResolved)
    # `_parse_gs_ddi` returns `c_dd = NaN` for a disabled block and for one it
    # could not derive; both mean "no dipole interaction", which a model states
    # by carrying zero strength.
    (r.enable_ddi && isfinite(r.c_dd)) || return DDISpec()
    DDISpec(; c_dd=r.c_dd, secular=r.secular, padded=r.ddi_padded,
        pad_factor=if r.ddi_pad_factor isa Real
            ntuple(_ -> Float64(r.ddi_pad_factor), r.ndim)
        else
            r.ddi_pad_factor
        end,
        trunc_radius=ddi_trunc_radius_from_kwarg(r.ddi_trunc),
        quasi_2d=r.quasi_2d_ddi, l_z=r.l_z_ddi)
end

function _lhy_spec(r::GSResolved)
    r.spinor_lhy === nothing && return LHYSpec()
    kind = r.spinor_lhy::Symbol
    kind === :none && return LHYSpec()
    kind in LHY_CLOSED_SCALAR_KINDS &&
        return LHYSpec(; kind, c_lhy=r.interactions.c_lhy)
    # The tabulated kinds. `LHYTableOpts.n_max = NaN` means "3 x max|psi_init|^2",
    # which makes the LHY functional a function of the SEED — two runs of the
    # same model with different seeds would not be the same physics.
    #
    # There is deliberately no `isfinite` guard here. One was written, and the
    # canary that broke it came back GREEN: `LHYSpec`'s own `n_max > 0` check
    # already refuses `NaN` (and every non-positive value, which the guard did
    # not), with a message that also names `n_max`. A second refusal of the same
    # state is a second declaration — exactly what this layer deletes — so the
    # one in `LHYSpec` is left as the only one.
    LHYSpec(; kind, c_lhy=r.interactions.c_lhy, n_max=r.lhy_opts.n_max,
        n_points=r.lhy_opts.n_points, n_bins=r.lhy_opts.n_bins)
end

# --- zeeman ---------------------------------------------------------------
#
# From the RESOLVED field, never from `p["B"]`: `_build_zeeman_from_b_block` is
# where lab Gauss becomes `p` (through `Units.bfield_to_p`, the one declaration
# of that sign) and where `q` is derived from |B|². Re-reading the block would
# be a second copy of both.
#
# One honest leak: a ramped knob is sampled over `duration = dt * n_steps`, so a
# `Model` containing a `PiecewiseLinearWaveform` moves with `dt` — a method
# parameter reaching the physics id. It is the same `duration`
# `_build_zeeman_from_b_block` itself was given, so the model says what ran; it
# is named rather than hidden. Every committed ground-state step carries a
# static `B`, so nothing in the corpus exercises it.

_zeeman_spec(r::GSResolved) = _zeeman_spec_of(r.zeeman, r.duration)

_zeeman_spec_of(z::ZeemanParams, ::Float64) = ZeemanSpec(; p=z.p, q=z.q)

_zeeman_spec_of(z::TimeDependentZeeman, duration::Float64) = ZeemanSpec(;
    p=to_model_waveform(z.p_wf, duration),
    q=to_model_waveform(z.q_wf, duration),
    bx=z.bx_wf === nothing ? 0.0 : to_model_waveform(z.bx_wf, duration),
    by=z.by_wf === nothing ? 0.0 : to_model_waveform(z.by_wf, duration))

function _zeeman_spec_of(z::ZeemanField{Nothing}, duration::Float64)
    wf(k) = z.waveforms[k] === nothing ? z.scalars[k] :
            to_model_waveform(z.waveforms[k], duration)
    ZeemanSpec(; bx=wf(1), by=wf(2), p=wf(3), q=wf(4))
end

_zeeman_spec_of(z::ZeemanField, ::Float64) = throw(
    ArgumentError(
        "a spatial Zeeman field inherited from a previous step's workspace is a BUILT " *
        "object — `SpatialZeemanField` holds four grid-sized arrays and the functional " *
        "arm holds four closures in its type parameters, so neither the named shape nor " *
        "its parameters survive. Declare `B:` on this step instead of inheriting it."),
)

# --- potential ------------------------------------------------------------
#
# Decomposes the RESOLVED `AbstractPotential` that `_build_potential` produced;
# it does not re-read `potential:`. `MagneticGradient` is a trap-shaped
# `AbstractPotential` that `Model` keeps in its own slot (it is a HamTerm with
# its own sign declaration and oracle), so the walk returns both.

function _potential_and_gradient_specs(r::GSResolved)
    acc = _PotAcc()
    _accumulate_potential!(acc, r.potential, r.duration)
    (
        PotentialSpec(; harmonic=acc.harmonic, lattice=acc.lattice, ring=acc.ring,
            box=acc.box, gravity=acc.gravity, double_well=acc.double_well,
            beam=acc.beam, dipole_trap=acc.dipole_trap),
        acc.gradient)
end

Base.@kwdef mutable struct _PotAcc
    harmonic::Vector{HarmonicSpec} = HarmonicSpec[]
    lattice::Vector{LatticeSpec} = LatticeSpec[]
    ring::Vector{RingSpec} = RingSpec[]
    box::Vector{BoxSpec} = BoxSpec[]
    gravity::Vector{GravitySpec} = GravitySpec[]
    double_well::Vector{DoubleWellSpec} = DoubleWellSpec[]
    beam::Vector{BeamSpec} = BeamSpec[]
    dipole_trap::Vector{DipoleTrapSpec} = DipoleTrapSpec[]
    gradient::GradientSpec = GradientSpec()
end

_accumulate_potential!(::_PotAcc, ::NoPotential, ::Float64) = nothing

_accumulate_potential!(a::_PotAcc, v::HarmonicTrap, ::Float64) =
    push!(a.harmonic, HarmonicSpec(; omega=v.omega))

_accumulate_potential!(a::_PotAcc, v::QuarticPotential, ::Float64) =
    push!(a.harmonic, HarmonicSpec(; omega=v.omega, lambda=v.lambda))

_accumulate_potential!(a::_PotAcc, v::OpticalLatticePotential, ::Float64) =
    push!(a.lattice, LatticeSpec(; depth=v.depth, period=v.period, phase=v.phase))

_accumulate_potential!(a::_PotAcc, v::ShakenLatticePotential, duration::Float64) =
    push!(
        a.lattice,
        LatticeSpec(; depth=v.depth, period=v.period,
            phase=map(w -> to_model_waveform(w, duration), v.shake_wf)),
    )

_accumulate_potential!(a::_PotAcc, v::RingPotential, ::Float64) =
    push!(a.ring, RingSpec(; radius=v.radius, strength=v.strength, width=v.width))

_accumulate_potential!(a::_PotAcc, v::BoxPotential, ::Float64) =
    push!(a.box, BoxSpec(; size=v.size, wall_strength=v.wall_strength,
        wall_width=v.wall_width))

_accumulate_potential!(a::_PotAcc, v::GravityPotential, ::Float64) =
    push!(a.gravity, GravitySpec(; g=v.g, axis=v.axis))

_accumulate_potential!(a::_PotAcc, v::DoubleWellPotential, ::Float64) =
    push!(
        a.double_well,
        DoubleWellSpec(; separation=v.separation, barrier=v.barrier,
            omega=v.omega, axis=v.axis),
    )

_accumulate_potential!(a::_PotAcc, v::CrossedDipoleTrap, ::Float64) =
    push!(a.dipole_trap,
        DipoleTrapSpec(; beams=collect(v.beams), polarizability=v.polarizability))

# `V = -polarizability*power * (rho^2)^l * exp(-rho^2)`, `rho = sqrt(2) r / waist`
# (`evaluate_potential.jl:117-131`) — the same rho `BeamSpec` documents, so the
# waist passes through and only the amplitude is folded.
function _accumulate_potential!(a::_PotAcc, v::LaguerreGaussBeam, ::Float64)
    v.p_mode == 0 || throw(
        ArgumentError(
            "LaguerreGaussBeam p_mode=$(v.p_mode) has no slot in BeamSpec (which carries " *
            "amplitude, waist and l_mode only). Refused rather than dropped."),
    )
    push!(
        a.beam,
        BeamSpec(; amplitude=-v.polarizability * v.power, waist=v.waist,
            l_mode=abs(v.l_mode)),
    )
end

# The one conversion in the walk. `PlugBeam` evaluates
# `strength * exp(-r^2 / (2 w^2))` (`evaluate_potential.jl:133-144`) while
# `BeamSpec` is `amplitude * exp(-rho^2)`, `rho = sqrt(2) r / waist` — equal iff
# `waist = 2w`, i.e. `PlugBeam.waist` is HALF the 1/e^2 intensity radius. Both
# forms are in the tree; the factor lives here, once, and
# `test/model/test_yaml_to_model.jl` gates it against the evaluator numerically
# rather than against this comment.
_accumulate_potential!(a::_PotAcc, v::PlugBeam, ::Float64) =
    push!(a.beam, BeamSpec(; amplitude=v.strength, waist=2 * v.waist, l_mode=0))

_accumulate_potential!(a::_PotAcc, v::MagneticGradient, ::Float64) =
    (a.gradient = GradientSpec(; gradient=v.gradient, axis=v.axis, g_F=v.g_F))

function _accumulate_potential!(a::_PotAcc, v::CompositePotential, duration::Float64)
    for c in v.components
        _accumulate_potential!(a, c, duration)
    end
end

_accumulate_potential!(::_PotAcc, v::AbstractPotential, ::Float64) = throw(
    ArgumentError(
        "$(typeof(v)) has no PotentialSpec term. `LaserBeamPotential` is direct-Julia " *
        "only (no parser reaches it) and `TimeDependentTrap` is subsumed by a " *
        "waveform-valued HarmonicSpec.omega; adding a trap kind means adding a field to " *
        "PotentialSpec, which is a reviewed diff by design."),
)

# ---------------------------------------------------------------------------
# yaml_to_model
# ---------------------------------------------------------------------------

"""
    yaml_to_model(path::AbstractString; index=nothing, verbose=false) -> Model
    yaml_to_model(config::AbstractDict; index=nothing, verbose=false) -> Model

The resolved physics of a config's `ground_state:` step.

Applies the preprocessing `run_yaml` applies — `_run_yaml_prepare` (dealias pop,
calibration, templates + mixins, schema defaults, units, auto-defaults, B-block,
noise-block, strict validation) followed by `parse_pipeline`'s `defaults:`
seeding, which 414 of 416 committed configs depend on and which lives in neither
normaliser. A resolver fed raw YAML would get the wrong step params for almost
every config in the tree.

`index` selects among multiple ground-state steps (1-based over the
ground-state steps, not over the pipeline); with one step it may be omitted, and
with several an explicit choice is required rather than guessed.

Fails loudly and by name. There is no partially-filled `Model`: every slot a
config cannot resolve throws, with the config path in the message.

**Pure in the dealias globals.** `_run_yaml_prepare` is only the PREPARE half of
a prepare/execute pair: it applies a top-level `dealias:` block to
`DEALIAS_2_3_ENABLED[]` / `DEALIAS_K_CUTOFF[]` and leaves them set, and it is
`run_yaml`'s execute half that restores them in a `finally`
(`run_registry.jl:421-445`). `yaml_to_model` runs prepare alone, so it must do
that restore itself — otherwise resolving a config that carries the block
rewrites the `GridSpec` of every config resolved AFTER it in the same session,
and `yaml_to_model(a) == yaml_to_model(a)` is false. That is fatal for a
resolver whose output is a content id. Measured on the corpus rather than
argued: `runs/validation_level10/L10_F1_smoke.yaml` resolved to
`dealias_two_thirds=false, k_cut=0.0` alone and to `true, 10.0` after
`runs/eu_gs_phase_c1_B_kappa/config_boundary_64.yaml`. Gated by the
order-independence arm of `test/model/test_corpus_resolves.jl`.
"""
function yaml_to_model(path::AbstractString; index::Union{Nothing, Int}=nothing,
    verbose::Bool=false)
    isfile(path) || throw(ArgumentError("yaml_to_model: no such config: $path"))
    # Restore BOTH the globals and the pending-snapshot slot, so the subsystem is
    # left exactly as found. Clearing the slot outright would discard a restore
    # point some earlier half-run `run_yaml` is still owed.
    was_enabled, was_k_cut = DEALIAS_2_3_ENABLED[], DEALIAS_K_CUTOFF[]
    was_pending = _DEALIAS_PENDING_SNAPSHOT[]
    # `_run_yaml_prepare` is INSIDE the try: strict schema validation lives
    # there, and a config that fails it is one `yaml_to_model` cannot resolve —
    # so it must be named the same way as every other refusal.
    try
        yaml_to_model(_run_yaml_prepare(String(path), verbose, false); index, verbose)
    catch err
        err isa ArgumentError || rethrow()
        throw(ArgumentError("$path: $(err.msg)"))
    finally
        _DEALIAS_PENDING_SNAPSHOT[] = was_pending
        restore_dealias_refs!(was_enabled, was_k_cut)
    end
end

function yaml_to_model(config::AbstractDict; index::Union{Nothing, Int}=nothing,
    verbose::Bool=false)
    cfg = parse_pipeline(Dict{Any, Any}(config))
    gs = [s for s in cfg.steps if s isa GroundStateStep]
    isempty(gs) && throw(
        ArgumentError(
            "no spinor ground_state step in this pipeline (steps: " *
            join(String.(nameof.(typeof.(cfg.steps))), ", ") * ")"),
    )
    i = if index === nothing
        if length(gs) == 1
            1
        else
            throw(
                ArgumentError(
                    "$(length(gs)) ground_state steps; pass index=1..$(length(gs)) rather " *
                    "than letting the choice be implicit"),
            )
        end
    else
        1 <= index <= length(gs) ||
            throw(ArgumentError("index=$index outside 1:$(length(gs)) ground_state steps"))
        index
    end
    gs_model(resolve_gs(Dict{String, Any}(gs[i].params), nothing, nothing, nothing; verbose))
end
