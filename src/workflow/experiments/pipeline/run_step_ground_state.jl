# NOT GENERALIZABLE: `@noinline + ::ConcreteType` boundary is load-bearing.
# Reason: type-inference
# Why: each helper parses Dict{String,Any} and must return a concrete type so
#   the caller's inference doesn't widen to Any. Removing @noinline (or the
#   return-type assertion) re-introduces the Workspace JIT cascade observed
#   2026-03 (30-min compile hang on first ws construction). Keep both.
# See: CLAUDE.md §"Type stability boundaries", MEMORY pitfall_pipeline_inference

# --- GroundStateStep dispatch + parsing helpers ---
#
# The per-slot resolvers this file used to open with (`_resolve_gs_atom`,
# `_resolve_gs_grid`, `_resolve_gs_interactions`, `_resolve_gs_ddi_inheritance`,
# `_resolve_gs_potential`) moved to `resolve_gs.jl` together with the light
# shift / LHY / rotating-frame reads that used to sit ~170 lines below the cache
# branch. There is now ONE resolution of a `ground_state:` block, and this method
# is one of its two consumers; `yaml_to_model` is the other. A second reader of
# `potential:` / `B:` / `lhy:` / `ddi:` anywhere is the failure that extraction
# exists to prevent.

# --- seed_from: warm-start a GS solve from a prior run's converged ψ, spectrally
#     upsampled to this step's grid. Cost-compressed continuation
#     (docs/design/eu_phase_diagram_adaptive_mapping.md, Pillar 1): a cheap
#     coarse multi-seed recon is promoted to a fine grid by seed + short polish
#     instead of a fresh fine ITP per cell. The source point is matched by the
#     RESOLVED cell signature (c1 / Bz / κ / initial_state), so a scan auto-pairs
#     each cell to its own recon winner with no index coupling. Fails loud when
#     nothing matches — never silently falls back to a Gaussian seed.

_seed_bz_gauss(x::Real) = Float64(x)
_seed_bz_gauss(x::AbstractString) = parse(Float64, split(String(x))[1])

# Resolved (post-override) cell signature read off the step params dict.
@noinline function _seed_cell_signature(p::Dict{String, Any})
    c1 = haskey(p, "interactions") ? Float64(get(p["interactions"], "c1_ratio", NaN)) : NaN
    bz = haskey(p, "B") ? _seed_bz_gauss(get(p["B"], "Bz", 0.0)) : 0.0
    om = haskey(p, "potential") ? get(p["potential"], "omega", nothing) : nothing
    kap = (om isa AbstractVector && length(om) >= 3) ? Float64(om[3]) : NaN
    st = String(get(p, "initial_state", "polar"))
    (c1, bz, kap, st)
end

# Same signature read from a source point's saved `override` dict (dotted keys).
@noinline function _seed_override_signature(ov)
    c1 = Float64(get(ov, "pipeline.0.interactions.c1_ratio", NaN))
    bz = _seed_bz_gauss(get(ov, "pipeline.0.B.Bz", 0.0))
    kap = Float64(get(ov, "pipeline.0.potential.omega.2", NaN))
    st = String(get(ov, "pipeline.0.initial_state", "polar"))
    (c1, bz, kap, st)
end

_seed_sig_match(a, b) =
    a[4] == b[4] &&
    isapprox(a[1], b[1]; atol=1e-9, rtol=1e-6) &&
    isapprox(a[2], b[2]; atol=1e-12, rtol=1e-6) &&
    isapprox(a[3], b[3]; atol=1e-9, rtol=1e-6)

@noinline function _resolve_seed_from(sf, p::Dict{String, Any}, grid, atom)::Array{ComplexF64, 4}
    sf isa AbstractDict ||
        throw(ArgumentError("seed_from must be a mapping {run: <dir>, upsample: <bool>}"))
    run = get(sf, "run", get(sf, "path", nothing))
    run === nothing &&
        throw(ArgumentError("seed_from requires 'run' (a directory of point_*.jld2)"))
    isdir(run) || throw(ArgumentError("seed_from.run is not a directory: $run"))
    do_upsample = get(sf, "upsample", true) == true
    # `nearest: true` seeds from the CLOSEST computed point (same initial_state +
    # same c1, nearest in (Bz, κ)) instead of requiring an exact cell match. This
    # is what lets a boundary-refinement scan warm-start off a coarser map's
    # winners at brand-new (Bz, κ) points that have no exact seed.
    nearest = get(sf, "nearest", false) == true
    sig = _seed_cell_signature(p)
    match = nothing
    best_d = Inf
    for f in readdir(run)
        (startswith(f, "point_") && endswith(f, ".jld2")) || continue
        path = joinpath(run, f)
        ov = try
            JLD2.load(path, "override")
        catch
            continue
        end
        osig = _seed_override_signature(ov)
        if nearest
            # discrete axes (initial_state, c1) must match; minimise scaled
            # distance in the continuous (Bz [µG-ish], κ) plane.
            osig[4] == sig[4] || continue
            isapprox(osig[1], sig[1]; atol=1e-9, rtol=1e-6) || continue
            d = ((osig[2] - sig[2]) / 100)^2 + ((osig[3] - sig[3]) / 1.2)^2
            if d < best_d
                best_d = d
                match = path
            end
        elseif _seed_sig_match(osig, sig)
            match = path
            break
        end
    end
    match === nothing &&
        throw(
            ArgumentError(
                "seed_from: no point in $run matches cell (c1=$(sig[1]), Bz=$(sig[2]) G, κ=$(sig[3]), state=$(sig[4]))"
            ),
        )
    psi = load_point_psi(match)   # resolves a light point's gs_ref from the stage store
    n = grid.config.n_points[1]
    if size(psi, 1) != n
        do_upsample ||
            throw(
                ArgumentError(
                    "seed_from: seed side $(size(psi, 1)) ≠ grid side $n and upsample=false"
                ),
            )
        psi = upsample_spinor(psi, n)
    end
    _to_host(psi)::Array{ComplexF64, 4}
end

# --- pin: symmetry-breaking ε-continuation for the weak-field soft manifold.
#     Reads the cell's DIMENSIONLESS linear/quadratic Zeeman (p, q) — NOT lab
#     Gauss (static_zeeman's `Bz` kwarg is the p slot) — and builds the built-in
#     transverse conjugate-field pin b_x=ε. find_ground_state_lbfgs warm-ramps
#     ε→0 and returns the ε→0-extrapolated certified energy. Empty ramp ⇒ no pin.
# Unified accessors cover ZeemanParams / TimeDependentZeeman / ZeemanField{…}
# (the last is what a GS step inherits from a prior step's workspace).
_zeeman_pq(z) = (linear_p(z), quadratic_q(z))

# Split from the closure builder by cutover step 3: `pin` selects a BRANCH of the
# soft manifold, so it is an input to the artifact id, and the id runs above the
# cache branch while the closure is built inside the LBFGS arm. A closure cannot
# be hashed at all (`_enc` refuses `Function` — every closure site is its own
# type), so the id takes the two values this parse produces and the closure is
# reconstructed from them plus the model's own Zeeman.
#
# The parse is unconditional, i.e. it now also runs for `method: itp`, which
# ignores `pin`. That is deliberate: a method-gated parse would leave the id
# blind to `pin` on any step whose method later learns to honour it, and blind is
# the failure this step exists to end. Two committed configs pair `pin:` with
# `method: itp` (`config_vortex_verify_{48,64}.yaml`) and both parse.
@noinline function _parse_pin_block(pin_block)
    pin_block === nothing && return (nothing, Float64[])
    pin_block isa AbstractDict ||
        throw(ArgumentError("pin: must be a mapping {kind: transverse, epsilon_ramp: [...]}"))
    ramp = get(pin_block, "epsilon_ramp", nothing)
    ramp === nothing &&
        throw(
            ArgumentError(
                "pin: requires epsilon_ramp (descending εs, e.g. [4.0e-3, 2.0e-3, 1.0e-3, 5.0e-4])"
            ),
        )
    eps = Float64.(collect(ramp))
    isempty(eps) && throw(ArgumentError("pin.epsilon_ramp is empty"))
    kind = Symbol(get(pin_block, "kind", "transverse"))
    kind === :transverse ||
        throw(
            ArgumentError(
                "pin.kind=$kind unsupported via yaml (only :transverse — conjugate field b_x=ε)"
            ),
        )
    (kind, eps)
end

_pin_closure(::Nothing, _) = nothing
function _pin_closure(kind::Symbol, zeeman)
    kind === :transverse ||
        throw(ArgumentError("pin.kind=$kind has no closure builder"))
    p_lin, q_quad = _zeeman_pq(zeeman)
    pin_transverse_field(; Bz=p_lin, q=q_quad)
end

# --- Automatic content-addressed GS stage cache -------------------------------
# The expensive ITP/LBFGS ground-state solve is a pure function of its RESOLVED
# physics inputs, not of the downstream `analyze:` block or the enclosing
# scan/config. Keying a shared artifact on those inputs lets any config (a
# refined c1 grid, an extended κ range, a changed analyzer list, or an
# overlapping [1-10] vs [5-10] scan) reuse a ground state computed by any other —
# closing the per-config / per-scan-index CAS reuse gap. This only AUTO-populates
# the existing manual `cache:` path (loaded just below, saved near the end of this
# function); the load/save machinery is unchanged. Opt-in via SPINORBEC_STAGE_CACHE.
_stage_cache_enabled() =
    lowercase(get(ENV, "SPINORBEC_STAGE_CACHE", "0")) in ("1", "true", "on", "yes")

# Stage 1: when on, a scan point whose GS was stage-cached is written as a LIGHT
# point (a `gs_ref` pointer + scalars/analyze, no inline psi) — the heavy psi
# lives once in the stage store; open_result resolves it back. Requires the stage
# cache to be producing refs, so it implies _stage_cache_enabled().
_light_points_enabled() =
    lowercase(get(ENV, "SPINORBEC_LIGHT_POINTS", "0")) in ("1", "true", "on", "yes")

_gs_stage_dir() = get(ENV, "SPINORBEC_STAGE_DIR",
    joinpath(get(ENV, "SPINORBEC_STORE", "runs"), "_stage", "gs"))

# --- The id that admits (cutover step 3) --------------------------------------
#
# `docs/design/research_spec_and_provenance_architecture.md` §6, step 3. What was
# here until this commit — `_gs_cache_key`, a hand-listed dict of 19 entries, and
# the `_hashable` recursion that laundered its raw YAML sub-blocks — is deleted,
# not wrapped. Two keys deciding admission is the state this cutover exists to
# end, so there is no fallback to fall back to.
#
# The old key was blind to eleven inputs THE SAME FUNCTION passes to the solver,
# measured one knob at a time: `m_lbfgs`, `newton_polish`, `residual_polish`,
# `pin`, `tol_drho`, `seed_from`, `noise_seed`, `light_shift`,
# `rotating_frame_omega`, `backend`, and the code revision. In a per-config cache
# that is a stale directory. This store is CONTENT-ADDRESSED AND SHARED — the
# whole point is that any config reuses any other's artifact — so a blind axis is
# one config's ground state served to a different config that asked a different
# question. Live exposure at the flip: `config_c1kappa_B0` / `B10` carry a
# `pin:` block selecting a symmetry-broken BRANCH and `config_c1kappa_B60` does
# not, and the only thing keeping them apart today is that their Bz differ.
#
# `artifact_id(::Stage)` hashes the whole declaration, so nothing is selected out
# of it. But turning a step dict INTO a `Stage` is a mapping, and a mapping is
# exactly where an omission can still hide. Two halves, each closed differently:
#
#   * PHYSICS is not mapped here at all. `gs_model(r)` is a pure function of the
#     same `GSResolved` the solver reads (`resolve_gs.jl`), so a physics slot
#     cannot be in the solve and out of the id.
#   * NUMERICS are `_gs_stage_params` below, and
#     `test/model/test_gs_admission_axes.jl` partitions EVERY `GS_SCHEMA` key
#     into {model, stage, refused, not-on-this-path, destination}, asserts the
#     partition is total (a new schema key is red until classified), and then
#     moves each axis one at a time asserting the id moves with it.
#
# FAIL-SAFE. A config `gs_model` cannot resolve (22 tabulated-LHY configs with no
# `n_max`, 16 with no `N_atoms`, 2 with a dropped B tilt) has NO id, and a stage
# with no id NEVER HITS: it recomputes, every time, and says so once. Recomputing
# is only slower; serving an artifact addressed by a key that cannot express the
# question is wrong. Which configs those are is gated by
# `test/model/test_corpus_resolves.jl`, so the set can only shrink deliberately.

# `init_state_params` is a raw YAML mapping and the one place on this path where
# the value type is not known from the key: the 22 named seeds take Float64
# knobs, `from_jld2` takes `{path: <str>, snap: last|<int>}`. A `Dict` has no
# canonical iteration order, and it must NOT reach `_enc` — the generic arm
# reflects a struct into its fields, and `Dict`'s fields are its internal slot
# arrays. Flattened to sorted parallel vectors, the shape `_enc_atom` already
# uses for `scattering_lengths`.
function _init_state_param_pairs(v)
    v isa AbstractDict || return (String[], String[])
    m = Dict{String, String}(string(k) => string(x) for (k, x) in v)
    ks = sort!(collect(keys(m)))
    (ks, String[m[k] for k in ks])
end

# The inverse of `_resolve_backend`, derived from the schema's own enum rather
# than restated — a second list of backend names is a second declaration, and
# `Stage`'s constructor validates the answer by calling `_resolve_backend` on it.
function _backend_symbol(b::AbstractBackend)
    for name in GS_SCHEMA["backend"].enum
        s = Symbol(name)
        _resolve_backend(s) === b && return s
    end
    throw(
        ArgumentError(
            "no `backend:` enum value resolves to $(typeof(b)); " *
            "GS_SCHEMA[\"backend\"].enum is $(GS_SCHEMA["backend"].enum)"),
    )
end

# The numerics half of the stage. `tol` / `n_steps` / `dt` come off `r` because
# `resolve_gs` is where their defaults are applied; the rest are read with the
# SAME expression the solver call below uses, so a default cannot differ between
# what runs and what is hashed.
#
# `noise_seed` is included unconditionally even though it only bites when
# `temperature_ratio` is set. Over-discrimination costs a recomputation; under-
# discrimination costs a wrong answer, and this file only gets to be wrong in one
# direction.
@noinline function _gs_stage_params(r::GSResolved, p::Dict{String, Any})
    isp_names, isp_values = _init_state_param_pairs(get(p, "init_state_params", nothing))
    pin_kind, pin_eps = _parse_pin_block(get(p, "pin", nothing))
    target_mz = _get_optional_float(p, "target_magnetization")
    temp_ratio = _get_optional_float(p, "temperature_ratio")
    (
        tol=r.tol,
        n_steps=r.n_steps,
        dt=r.dt,
        tol_drho=Float64(get(p, "tol_drho", 0.0)),
        m_lbfgs=Int(get(p, "m_lbfgs", 10)),
        newton_polish=get(p, "newton_polish", false) == true,
        residual_polish=get(p, "residual_polish", false) == true,
        initial_state=String(get(p, "initial_state", "polar")),
        init_state_param_names=isp_names,
        init_state_param_values=isp_values,
        # TOML has no null and `_enc` refuses `nothing` (a fieldless value would
        # launder into an empty table). `OPTIONAL_FLOAT_NOTHING` is the codec's
        # one declared spelling for the `nothing` arm of an optional float; it is
        # outside the numeric domain, so it cannot collide with a real value.
        target_magnetization=target_mz === nothing ? OPTIONAL_FLOAT_NOTHING : target_mz,
        temperature_ratio=temp_ratio === nothing ? OPTIONAL_FLOAT_NOTHING : temp_ratio,
        noise_seed=Int(get(p, "noise_seed", 42)),
        pin_kind=pin_kind === nothing ? "none" : String(pin_kind),
        pin_epsilon_ramp=pin_eps,
    )
end

"""
    gs_stage(r::GSResolved, p) -> Stage

The `Stage` a FROM-SCRATCH spinor ground-state solve declares: `:relax` over
`gs_model(r)`, by `r.method`, on `r.backend`, from nothing.

`from = nothing` is a claim, not a default — it says this solve starts from its
own `initial_state` and nothing else. The caller is responsible for only asking
when that is true; `_run_step` refuses to auto-cache a `seed_from` solve for
exactly this reason.

Throws whatever `gs_model` throws. The caller turns that into "no id", which
turns into "never a hit".
"""
gs_stage(r::GSResolved, p::Dict{String, Any}) = Stage(
    :relax, gs_model(r), r.method, nothing, _gs_stage_params(r, p),
    _backend_symbol(r.backend))

# One line per distinct REASON, not one per scan point: a 45-point scan of one
# unresolvable config would otherwise print 45 identical warnings and the signal
# would read as noise. Keyed on the message because the message names the slot
# that is missing, which is the thing a person acts on.
const _NO_ARTIFACT_ID_WARNED = Set{String}()
const _NO_ARTIFACT_ID_LOCK = ReentrantLock()

"For tests, and for a long-lived process that wants the warning again."
_reset_no_artifact_id_warnings!() =
    (lock(() -> empty!(_NO_ARTIFACT_ID_WARNED), _NO_ARTIFACT_ID_LOCK); nothing)

"""
    no_artifact_id_reasons() -> Vector{String}

Every distinct reason a config was denied a GS artifact id in THIS process,
sorted.

The set behind it was already keyed per reason — better than the design's "warns
once" — but it was `@warn` only, so it reached no `Record`, no
`_exit_summary.json`, no `run_summary`. About 40 runnable configs currently
resolve to no id and nothing on disk said so. `_write_exit_summary` now stamps
this list; it is the repo's own "check the run's own report before claiming"
applied to the cache.

A non-empty list means those configs CANNOT be served a cached ground state and
recompute every time — slower, and never wrong, which is why it is a counter and
not an error.
"""
no_artifact_id_reasons() =
    lock(() -> sort!(collect(_NO_ARTIFACT_ID_WARNED)), _NO_ARTIFACT_ID_LOCK)

@noinline function _warn_no_artifact_id_once(why::AbstractString)
    fresh = lock(_NO_ARTIFACT_ID_LOCK) do
        why in _NO_ARTIFACT_ID_WARNED ? false : (push!(_NO_ARTIFACT_ID_WARNED, why); true)
    end
    fresh || return nothing
    @warn "GS stage cache DISABLED for this config: it has no artifact id, so it " *
        "can never be served a cached ground state and will recompute every " *
        "time. Recomputing is slower; serving an artifact under a key that " *
        "cannot express the question is wrong." reason = why
    nothing
end

# `::Union{Nothing, String}` and `@noinline`: everything below this call feeds
# `make_workspace`, and an `Any`-typed local reaching that path is the inference
# explosion CLAUDE.md §"Type stability boundaries" exists to prevent. The
# `NamedTuple` inside `_gs_stage_params` has a per-call type by construction, so
# the narrowing has to happen here.
@noinline function _gs_artifact_id(r::GSResolved, p::Dict{String, Any})::Union{Nothing, String}
    try
        artifact_id(gs_stage(r, p))
    catch err
        _warn_no_artifact_id_once(err isa ArgumentError ? err.msg : sprint(showerror, err))
        nothing
    end
end

function _run_step(
    step::GroundStateStep,
    psi_prev,
    grid_prev,
    atom_prev,
    ws_prev;
    verbose=true,
    checkpoint_dir=nothing,
)
    p = step.params

    # Binary (two-component) GP runs through the dedicated
    # _run_step(::BinaryGroundStateStep, ...) method (gated by the
    # parser on `kind: binary`) so this method's inference world stays
    # narrow — see pipeline_types.jl. Falling back here would
    # re-introduce the JIT cascade.

    # THE shared resolution. Every slot below is read off `r`; nothing in this
    # method parses a physics block. `yaml_to_model` consumes the same call.
    r = resolve_gs(p, grid_prev, atom_prev, ws_prev; verbose)::GSResolved
    method = r.method
    atom = r.atom
    grid, ndim = r.grid, r.ndim
    interactions = r.interactions
    enable_ddi, c_dd_val, secular, q2d, lz, ddi_trunc, ddi_padded_b, ddi_pf = r.enable_ddi, r.c_dd,
    r.secular, r.quasi_2d_ddi, r.l_z_ddi,
    r.ddi_trunc, r.ddi_padded, r.ddi_pad_factor
    potential = r.potential
    backend = r.backend
    tol, n_steps, dt = r.tol, r.n_steps, r.dt
    zeeman = r.zeeman
    gs_light_shift = r.light_shift
    spinor_lhy_mode = r.spinor_lhy
    gs_lhy_opts = r.lhy_opts
    gs_rf_omega = r.rf_omega

    # --- Cache: skip ITP/LBFGS if file exists, but build a workspace so
    #     downstream analyzers (e.g. bogoliubov) can inspect the system ---
    cache_path = get(p, "cache", nothing)
    # Auto content-addressed stage cache: a from-scratch solve keyed on its
    # RESOLVED DECLARATION is reusable by any other config that declares the
    # same thing. `stage_ref` (the artifact id) is threaded into step_result so
    # the scan-loop save can write a light point that references the shared psi
    # (Stage 1).
    #
    # Three guards, and the third is new in cutover step 3:
    #
    #   `cache_path === nothing`  an explicit `cache:` names its own file.
    #   `psi_prev === nothing`    a continuation solve is seeded by the previous
    #                             step, which no id here describes.
    #   no `seed_from`            SAME reason, and the old guard MISSED it: a
    #                             `seed_from` solve has `psi_prev === nothing`
    #                             and is warm-started from bytes at a path, so it
    #                             was auto-cached under a key that could not see
    #                             its seed. `Stage.from` is the slot a warm start
    #                             belongs in and `artifact_id` recurses into it,
    #                             but the predecessor here is a directory of
    #                             point files, not a `Stage` — so this is refused
    #                             rather than mis-declared as from-scratch. 19
    #                             committed configs use `seed_from`; none is
    #                             stage-cached today, and all of them are one
    #                             `export SPINORBEC_STAGE_CACHE=1` away.
    stage_ref = nothing
    if cache_path === nothing && psi_prev === nothing && !haskey(p, "seed_from") &&
        _stage_cache_enabled()
        stage_ref = _gs_artifact_id(r, p)
        if stage_ref !== nothing
            cache_path = joinpath(_gs_stage_dir(), stage_ref * ".jld2")
            verbose && println("  GS artifact id → $(stage_ref)")
        end
    end
    # Cutover step 2, invariant 4: `isfile(cache_path)` was the admission. It is
    # the highest-blast-radius one in the tree — the key is content-addressed
    # over the resolved declaration precisely so that ANY other config reuses the
    # artifact, so one truncated or half-relaxed file is served to N unrelated
    # cells. `admit_payload` requires a marker to have been written last, or
    # (arm b) no marker at all. Measured at cutover: `runs/_stage` did not exist
    # and none of the 12 configs carrying an explicit `cache:` key names a file
    # that is on disk, so arm (b) has no legacy population HERE. Step 3 changes
    # every id in this store, which drops that population to zero a second way —
    # a pre-flip artifact is no longer ADDRESSABLE. Deleting arm (b) outright
    # still needs its own dated cutoff and its own gate; it is not done here.
    gs_admission = cache_path === nothing ? nothing : admit_payload(cache_path)
    if gs_admission !== nothing && gs_admission.hit
        if verbose
            println("  Loading cached GS from $cache_path ($(gs_admission.provenance))")
            flush(stdout);
            ccall(:fflush, Cint, (Ptr{Cvoid},), C_NULL)
        end
        d = JLD2.load(cache_path)
        psi_out = d["psi"]
        energy = get(d, "energy", NaN)
        converged = get(d, "converged", true)
        # The [KNOWN-GAP] step 1b marked here and left for step 3, CLOSED. Until
        # this commit the call passed no `light_shift`, no `spinor_lhy`, no
        # `lhy_opts` and no `rotating_frame_omega`, so a cache HIT handed
        # downstream analyzers (energy_decomposition, bogoliubov, …) a workspace
        # whose Hamiltonian was missing LHY, the light shift and the rotating
        # frame — three terms the FRESH solve had. Step 1b hoisted the four
        # resolutions above this branch; before that the omission was not even
        # expressible.
        #
        # It has to close HERE and not later, because step 3 is what makes it
        # dangerous: `lhy`, `light_shift` and `frame` are now slots of the model
        # the id is derived from, so a hit is by construction a hit for a config
        # that DECLARED them. An id that promises LHY and a workspace that has
        # none is the id lying about its own artifact.
        #
        # The flip is also what makes it safe. A tabulated LHY with no explicit
        # `n_max` resolves to `LHYTableOpts.n_max = NaN` ("3 x max|psi_init|^2"),
        # which would make the table a function of WHICH ψ built it — the cached
        # converged one here, the seed in the fresh solve. `LHYSpec` refuses a
        # non-positive `n_max`, so such a config has no id and can never reach
        # this branch at all. Residual, named rather than hidden: `:full_bdg`
        # still takes its SPINOR from `psi_init`, so its table is built from the
        # converged ψ here and from the seed in the solve that wrote the file.
        # `rotating_frame_omega` is a `SimParams` field, not a `make_workspace`
        # kwarg — it is what builds the Coriolis cache (`make_workspace.jl:396`).
        ws_cached = make_workspace(;
            grid, atom, interactions, zeeman, potential,
            sim_params=SimParams(; dt, n_steps=1, save_every=1,
                rotating_frame_omega=gs_rf_omega),
            psi_init=psi_out,
            enable_ddi, c_dd=c_dd_val,
            secular_ddi=secular, quasi_2d_ddi=q2d, l_z_ddi=lz, ddi_trunc_radius=ddi_trunc,
            ddi_padding=ddi_padded_b, ddi_pad_factor=ddi_pf,
            backend,
            light_shift=gs_light_shift,
            spinor_lhy=spinor_lhy_mode,
            lhy_opts=gs_lhy_opts,
        )
        # Is the verdict TRUE of what was just loaded? Everything above this
        # line trusts the marker; `admit_payload` checked that it exists, was
        # written last, and names bytes that are present. None of that reads ψ.
        #
        # This is the one place the workspace and the stored state are both in
        # hand, so it is the one place the {ψ, E, ∇E} spine can be re-derived
        # without building anything for the purpose. A hit that fails is not
        # served: it falls through to the fresh solve below, loudly. Wrong-and-
        # fast is the outcome the content-addressed store multiplies — the key
        # is shared, so one bad payload reaches every config with the same
        # physics.
        gs_audit = verify_verdict(
            gs_admission.marker === nothing ? nothing : gs_admission.marker.verdict,
            psi_out, ws_cached; energy_recorded=energy, F=atom.F)
        if gs_audit.checked && !gs_audit.agrees
            @error "cached ground state REJECTED: its verdict is not true of it" path =
                cache_path reason = gs_audit.reason energy_recorded = gs_audit.energy_recorded energy_rederived =
                gs_audit.energy_rederived grad_norm_recorded = gs_audit.grad_norm_recorded grad_norm_rederived =
                gs_audit.grad_norm_rederived
        else
            v = gs_admission.marker === nothing ? nothing : gs_admission.marker.verdict
            step_result = Dict{Symbol, Any}(
                :ground_state_energy => energy,
                :ground_state_converged => converged,
                :ground_state_provenance => String(gs_admission.provenance),
                :workspace => ws_cached,
                :gs_stage_ref => stage_ref,
            )
            # The other three quarters of the verdict. The marker carries
            # `stop_reason`, `floor_limited` and `grad_norm`; until this commit a
            # hit published only `converged`, so `gs_verdict` on a cache-hit
            # result reconstructed `("unknown", false, NaN)` from its defaults —
            # a re-marked payload would lose the distinction between a converged
            # solve and a floor-limited one that the verdict exists to keep.
            if v !== nothing
                step_result[:ground_state_stop_reason] = v.stop_reason
                step_result[:ground_state_floor_limited] = v.floor_limited
                step_result[:ground_state_grad_norm] = v.grad_norm
            end
            step_result[:ground_state_verdict_verified] = gs_audit.checked
            return (psi_out, grid, atom, ws_cached, step_result)
        end
    end
    initial_state = Symbol(get(p, "initial_state", "polar"))
    # from_jld2: load ψ from a prior result (mirrors the rotating_basis
    # path). Its init_state_params carry a path/snap, not Float64s, so
    # resolve it before the numeric-params loop below.
    psi_from_jld2 = nothing
    if initial_state === :from_jld2
        isp = get(p, "init_state_params", Dict())
        jpath = get(isp, "path", nothing)
        jpath === nothing && throw(ArgumentError(
            "initial_state: from_jld2 requires init_state_params.path"))
        psi_from_jld2 = _load_psi_from_jld2(String(jpath), get(isp, "snap", "last"))
    end
    init_state_params = Dict{Symbol, Float64}()
    if initial_state !== :from_jld2 && haskey(p, "init_state_params")
        for (k, v) in p["init_state_params"]
            init_state_params[Symbol(k)] = Float64(v)
        end
    end
    target_mz = _get_optional_float(p, "target_magnetization")
    if target_mz === nothing && psi_prev !== nothing && method === :lbfgs
        # Preserve the Mz constraint from the seed state
        target_mz = magnetization(_to_host(psi_prev), grid, SpinSystem(atom.F))
    end
    temp_ratio = _get_optional_float(p, "temperature_ratio")

    # Both warm-start routes, in precedence order: an explicit from_jld2 state
    # wins, then a carried-over psi, then a `seed_from` reference.
    psi_init = psi_from_jld2 !== nothing ? psi_from_jld2 : psi_prev
    if psi_init === nothing && haskey(p, "seed_from")
        psi_init = _resolve_seed_from(p["seed_from"], p, grid, atom)
        verbose && println("  seed_from: loaded + upsampled warm seed (skips fresh init)")
    end
    if psi_init !== nothing
        D = 2 * atom.F + 1
        expected = (grid.config.n_points..., D)
        if size(psi_init) != expected
            throw(
                ArgumentError(
                    "psi_init size $(size(psi_init)) does not match grid+atom: expected $expected. " *
                    "Grid or atom changed between continuation points? Delete stale cached results and re-run.",
                ),
            )
        end
    end
    # Convert psi_init to target backend (e.g. GPU psi → CPU for LBFGS polish)
    if psi_init !== nothing && backend isa CPUBackend
        psi_init = _to_host(psi_init)
    end
    if psi_init === nothing && temp_ratio !== nothing
        psi_base = init_psi(
            grid, SpinSystem(atom.F); state=initial_state, pairs(init_state_params)...
        )
        psi_init = add_thermal_seed(psi_base, atom.F;
            T_over_Tc=temp_ratio, seed=Int(get(p, "noise_seed", 42)))
    end

    ramp_callbacks = Function[]
    ddi_d_raw = get(p, "ddi", Dict())
    if ddi_d_raw isa Dict && get(ddi_d_raw, "c_dd", nothing) isa Dict
        c_dd_spec = ddi_d_raw["c_dd"]
        if get(c_dd_spec, "adaptive", false)
            # Adaptive ramp: advance c_dd only when dE is small
            c_dd_target = Float64(c_dd_spec["to"])
            c_dd_from = Float64(get(c_dd_spec, "from", 0.0))
            c_dd_step = Float64(get(c_dd_spec, "step", (c_dd_target - c_dd_from) / 100))
            dE_threshold = Float64(get(c_dd_spec, "threshold", 0.01))
            save_every_local = max(1, Int(get(p, "n_steps", 100000)) ÷ 100)
            c_dd_current = Ref(c_dd_from)
            E_prev_ramp = Ref(NaN)
            push!(
                ramp_callbacks,
                (ws, step, ns) -> begin
                    ws.ddi === nothing && return nothing
                    if step % save_every_local == 0
                        E_now = total_energy(ws)
                        dE = isnan(E_prev_ramp[]) ? Inf : abs(E_now - E_prev_ramp[])
                        E_prev_ramp[] = E_now
                        if dE < dE_threshold && c_dd_current[] < c_dd_target
                            c_dd_current[] = min(c_dd_current[] + c_dd_step, c_dd_target)
                            ws.ddi.C_dd = c_dd_current[]
                            println(
                                "    c_dd → $(round(c_dd_current[]; digits=1)) (dE=$(round(dE; sigdigits=3)))"
                            )
                            flush(stdout)
                            E_prev_ramp[] = NaN  # reset after jump
                        end
                    end
                end,
            )
            c_dd_val = c_dd_from
        else
            c_dd_interp = _make_interpolator(c_dd_spec)
            push!(
                ramp_callbacks,
                (ws, step, ns) -> begin
                    ws.ddi !== nothing && (ws.ddi.C_dd = c_dd_interp(step / ns))
                end,
            )
            c_dd_val = c_dd_interp(0.0)
        end
    end

    on_step = isempty(ramp_callbacks) ? nothing :
              (ws, step, ns) -> for cb in ramp_callbacks
        ;
        cb(ws, step, ns);
    end

    tol_drho_val = Float64(get(p, "tol_drho", 0.0))
    gs = if method === :itp
        find_ground_state(;
            grid, atom, interactions, zeeman, potential,
            dt, n_steps, tol, tol_drho=tol_drho_val,
            initial_state, init_state_params, psi_init,
            enable_ddi, c_dd=c_dd_val,
            secular_ddi=secular, quasi_2d_ddi=q2d, l_z_ddi=lz, ddi_trunc_radius=ddi_trunc,
            ddi_padding=ddi_padded_b, ddi_pad_factor=ddi_pf,
            target_magnetization=target_mz, backend, on_step,
            checkpoint_dir=checkpoint_dir,
            save_every=max(1, n_steps ÷ 100),
            light_shift=gs_light_shift,
            spinor_lhy=spinor_lhy_mode,
            lhy_opts=gs_lhy_opts,
            rotating_frame_omega=gs_rf_omega,
            verbose=verbose,
        )
    elseif method === :lbfgs
        m_lbfgs = Int(get(p, "m_lbfgs", 10))
        newton_polish = get(p, "newton_polish", false) == true
        residual_polish = get(p, "residual_polish", false) == true
        # `_parse_pin_block` is the ONE parse of the block; `_gs_stage_params`
        # calls the same function, because `pin` selects a branch of the soft
        # manifold and is therefore an input to the artifact id. Only the
        # closure — which no id can digest — is built here.
        pin_kind, pin_eps = _parse_pin_block(get(p, "pin", nothing))
        pin_closure = _pin_closure(pin_kind, zeeman)
        # Reuse existing workspace when available to preserve DDI flags (secular/q2d/l_z).
        # Skip reuse when backend is overridden OR a pin is active (the pin
        # ε-continuation builds its own bare workspace and needs grid/atom).
        if pin_closure === nothing && ws_prev !== nothing && !haskey(p, "backend") &&
            !haskey(p, "interactions") && !haskey(p, "ddi") &&
            !haskey(p, "potential") && !haskey(p, "B")
            find_ground_state_lbfgs(;
                ws_init=ws_prev, psi_init,
                n_steps, tol, m_lbfgs, newton_polish, residual_polish,
                target_magnetization=target_mz,
                verbose,
            )
        else
            find_ground_state_lbfgs(;
                grid, atom, interactions, zeeman, potential,
                n_steps, tol, m_lbfgs, newton_polish, initial_state, init_state_params,
                psi_init,
                enable_ddi, c_dd=c_dd_val,
                secular_ddi=secular, quasi_2d_ddi=q2d, l_z_ddi=lz, ddi_trunc_radius=ddi_trunc,
                ddi_padding=ddi_padded_b, ddi_pad_factor=ddi_pf,
                target_magnetization=target_mz, backend,
                verbose,
                light_shift=gs_light_shift,
                spinor_lhy=spinor_lhy_mode,
                lhy_opts=gs_lhy_opts,
                pin=pin_closure, epsilon_ramp=pin_eps,
                residual_polish,
            )
        end
    else
        throw(ArgumentError("Unknown ground_state method: $method. Supported: itp, lbfgs"))
    end

    # Strip any Nyquist-mode junk the LBFGS/Newton path can accumulate — kills
    # the checkerboard artifact at the source in the saved/analysed ψ. Host
    # copy: the null uses a CPU FFT.
    #
    # The docstring's "the split-step dealias already strips it during ITP, so
    # this is a no-op there" is TRUE only without a rotating frame. Measured
    # 2026-08-03 at 8^3, dt = 0.002, `method: itp`: with `rotating_frame_omega`
    # = 0 the projection moves ψ by 1.1e-16 (machine epsilon, a genuine no-op);
    # at Ω = 0.3 it moves it by 1.1e-5 — five orders larger, and present in
    # every combination containing Ω and in none without. The Coriolis 3-shear
    # runs AFTER the dealias inside the sandwich, and an FFT-based shear rings
    # at the Nyquist frequency, so it repopulates exactly what the dealias had
    # just removed.
    psi_out = _null_nyquist_modes!(_to_host(copy(gs.workspace.state.psi)), grid)

    # …which makes the projection a state change, and a state change here used
    # to split the step's outputs in two: `psi_out` was saved and analysed,
    # while `gs.workspace` — returned to every downstream analyzer — and
    # `gs.energy` still described the UNPROJECTED state. Measured on the same
    # config: the recorded energy was that of a ψ differing from the stored one
    # by 2.6e-5 relative, an energy offset of 3.0e-8 (second order, as it must
    # be at a stationary point). A cache hit rebuilds its workspace FROM the
    # stored ψ, so fresh and cached analysis of the same artifact disagreed by
    # exactly that much, and the recorded energy belonged to neither file.
    #
    # `_finalize_lbfgs_atomic!` (`solvers/lbfgs/atomic.jl`) makes {ψ, E, ∇E}
    # atomic at the SOLVER's return. This is the same discipline one level up,
    # at the STEP's return: sync the workspace to the state that is actually
    # saved, then take the energy from it. One ψ, one E, one workspace.
    # `copyto!` and not a new helper: it already crosses host→device and
    # ComplexF64→ComplexF32 (the `dtype: f32` path), which is the whole job.
    copyto!(gs.workspace.state.psi, psi_out)
    # With a pin ε-continuation the certified energy is the ε→0 extrapolation
    # of a sequence of solves, not a functional of this ψ — recomputing it here
    # would silently replace the certificate with the last rung's value.
    gs_energy = if hasproperty(gs, :E0_extrap)
        gs.E0_extrap
    else
        Float64(total_energy(gs.workspace))
    end
    verbose && _print_gs_summary(psi_out, grid, atom, gs)

    # THE defect this cutover exists to close. `_run_itp_loop!` swallows
    # `InterruptException` (`solvers/ground_state/itp_loop.jl:223-233`) and
    # returns an ordinary NamedTuple, so before this line a run killed at 1 % of
    # its step budget wrote its half-relaxed ψ into a CONTENT-ADDRESSED store
    # that every other config with the same physics then reads. `gs.interrupted`
    # existed the whole time and had exactly two consumers: that file's
    # checkpoint branch and a `println`. This is its third.
    #
    # Withheld, not marked-as-partial: a partial GS in a shared store is not
    # data with a caveat, it is a wrong answer waiting for a different config.
    # `find_ground_state_lbfgs` reports no such field, hence the `get` default.
    gs_interrupted = Bool(get(gs, :interrupted, false))

    # ONE reading of what the solver thought of its own answer, feeding both the
    # completion marker and `step_result` below. Extracted once rather than twice
    # because two independent `get(gs, :floor_limited, …)` sites are two places
    # for the spelling to drift, and the marker's copy is the one admission
    # believes. `find_ground_state_lbfgs` reports all four; the ITP reports
    # `converged` only, hence the defaults.
    gs_v = MarkerVerdict(
        Bool(gs.converged),
        String(get(gs, :stop_reason, :unknown)),
        Bool(get(gs, :floor_limited, false)),
        Float64(get(gs, :grad_norm, NaN)),
    )

    # Save to cache if specified
    if cache_path !== nothing && !gs_interrupted
        mkpath(dirname(cache_path))
        psi_host = _to_host(psi_out)
        tmp = cache_path * ".tmp"
        try
            jldopen(tmp, "w") do f
                f["psi"] = psi_host
                f["energy"] = gs_energy
                f["converged"] = gs.converged
                # The id that DECIDES admission, written into the artifact it
                # names. Step 1 spelled this key `gs_cache_key` because the value
                # WAS `_gs_cache_key`'s; step 3 deleted that function, so the name
                # is renamed with it rather than kept as an alias for a thing
                # that no longer exists (CLAUDE.md §"Naming convention").
                # `code_rev` stays separate: `artifact_id` digests it, but a
                # 16-hex id does not let a reader RECOVER it.
                stage_ref === nothing || (f["artifact_id"] = stage_ref)
                code_rev = _code_rev_or_nothing()
                code_rev === nothing || (f["code_rev"] = code_rev)
            end
            mv(tmp, cache_path; force=true)
            # LAST, and after the `mv`: the marker must certify bytes that are
            # already at their final path. Same directory, so this rename is a
            # real `rename(2)` and a reader never sees a partial marker.
            #
            # The verdict travels WITH the marker, not only inside the payload.
            # `f["converged"]` above has been written since step 1 and admission
            # could never see it — reading it would mean opening the JLD2, which
            # is the multi-GB load the marker exists to decide about. This is the
            # highest-stakes marker in the tree: the key is content-addressed, so
            # one non-converged ψ here is served to every OTHER config that
            # resolves to the same physics.
            write_complete_marker(cache_path, [cache_path];
                kind="ground_state", artifact_id=stage_ref, verdict=gs_v)
            verbose && println("  Cached GS to $cache_path")
        catch err
            isfile(tmp) && rm(tmp; force=true)
            @warn "Failed to save GS cache: $err"
        end
    elseif cache_path !== nothing && gs_interrupted
        # Nothing is written here, so there is no payload to tombstone — the
        # partial ψ never reaches the shared store at all. A tombstone would be
        # worse than useless: the key is content-addressed, so it would poison
        # the cell for every OTHER config that resolves to the same physics.
        @warn "ground state was INTERRUPTED — not caching the partial ψ" cache_path last_step = get(
            gs, :last_step, -1)
    end

    step_result = Dict{Symbol, Any}(
        :ground_state_energy => gs_energy,
        # All four off `gs_v`, so the four keys downstream reads and the four
        # fields the marker certifies cannot disagree. `converged=false` alone
        # cannot tell a run that failed from one that reached the method's floor
        # with an unattainable `tol` asked of it; ITP reports neither of the
        # other two.
        :ground_state_converged => gs_v.converged,
        :interrupted => gs_interrupted,
        :ground_state_stop_reason => gs_v.stop_reason,
        :ground_state_floor_limited => gs_v.floor_limited,
        :ground_state_grad_norm => gs_v.grad_norm,
        :workspace => gs.workspace,
        :gs_stage_ref => stage_ref,
    )
    (psi_out, grid, atom, gs.workspace, step_result)
end
