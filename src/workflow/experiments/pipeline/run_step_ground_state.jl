# NOT GENERALIZABLE: `@noinline + ::ConcreteType` boundary is load-bearing.
# Reason: type-inference
# Why: each helper parses Dict{String,Any} and must return a concrete type so
#   the caller's inference doesn't widen to Any. Removing @noinline (or the
#   return-type assertion) re-introduces the Workspace JIT cascade observed
#   2026-03 (30-min compile hang on first ws construction). Keep both.
# See: CLAUDE.md §"Type stability boundaries", MEMORY pitfall_pipeline_inference

# --- GroundStateStep dispatch + parsing helpers ---

# --- Step dispatch ---

"""
Resolve the atom for a GS step: parse from p["atom"] when present (and
populate derived params), else inherit from atom_prev. Throws when neither
is available. @noinline boundary plus the `::AtomSpecies` return assertion
in the caller keeps the `Dict{String,Any}` typed parsing local — preserving
the inference fence pattern that prevents a Workspace JIT cascade
(see CLAUDE.md "Type stability boundaries").
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
    psi = Array{ComplexF64}(JLD2.load(match, "psi"))
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

@noinline function _resolve_pin_block(pin_block, zeeman)
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
    p_lin, q_quad = _zeeman_pq(zeeman)
    (pin_transverse_field(; Bz=p_lin, q=q_quad), eps)
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

# content_id refuses to hash NaN/Inf (the gs_ddi tuple carries NaN for an unset
# ddi_trunc_radius); replace non-finite floats with a stable sentinel, recursively.
_hashable(x::AbstractFloat) = isfinite(x) ? x : "nonfinite:$(x)"
_hashable(x::Union{Integer, Bool, AbstractString, Nothing}) = x
_hashable(x::Symbol) = string(x)
_hashable(x::Tuple) = Any[_hashable(v) for v in x]
_hashable(x::AbstractVector) = Any[_hashable(v) for v in x]
_hashable(x::AbstractDict) = Dict{String, Any}(string(k) => _hashable(v) for (k, v) in x)
_hashable(x) = string(x)   # last resort: stringify anything exotic

# Canonical key over the resolved physics of a FROM-SCRATCH GS solve. Uses
# resolved objects where cheap+robust (atom, grid, c-dict, ddi tuple, scalars)
# and the raw `potential`/`B`/`lhy`/init sub-blocks (which fully determine their
# resolved objects given atom+grid). Excludes analyze/scan/metadata/cache. Only
# valid when psi_prev === nothing — warm-started/continuation solves are
# seed-dependent and are never auto-cached.
function _gs_cache_key(method, atom, grid, interactions, gs_ddi, tol, n_steps, dt, p)
    key = Dict{String, Any}(
        "v" => 1,                                    # key-schema version
        "method" => string(method),
        "atom" => atom.name,
        "F" => atom.F,
        "n_points" => collect(Int, grid.config.n_points),
        "box" => collect(Float64, grid.config.box_size),
        "c" => _hashable(interactions.c),
        "c_lhy" => _hashable(interactions.c_lhy),
        "ddi" => _hashable(gs_ddi),
        "tol" => tol,
        "n_steps" => n_steps,
        "dt" => dt,
        "potential" => _hashable(get(p, "potential", nothing)),
        "B" => _hashable(get(p, "B", nothing)),
        "lhy" => _hashable(get(p, "lhy", nothing)),
        "initial_state" => string(get(p, "initial_state", "polar")),
        "init_state_params" => _hashable(get(p, "init_state_params", nothing)),
        "target_magnetization" => _hashable(get(p, "target_magnetization", nothing)),
        "temperature_ratio" => _hashable(get(p, "temperature_ratio", nothing)),
    )
    content_id(key)
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

    # --- Cache: skip ITP/LBFGS if file exists, but build a workspace so
    #     downstream analyzers (e.g. bogoliubov) can inspect the system ---
    cache_path = get(p, "cache", nothing)
    # Auto content-addressed stage cache: a from-scratch solve keyed on its
    # resolved physics is reusable by any other config. Only when opted-in, not
    # already given an explicit `cache:`, and not warm-started (seed-dependent).
    # `stage_ref` (the content hash) is threaded into step_result so the scan-loop
    # save can write a light point that references the shared psi (Stage 1).
    stage_ref = nothing
    if cache_path === nothing && psi_prev === nothing && _stage_cache_enabled()
        stage_ref = try
            _gs_cache_key(method, atom, grid, interactions, gs_ddi, tol, n_steps, dt, p)
        catch err
            verbose &&
                @warn "GS stage-cache key failed; caching disabled for this cell" exception =
                    err
            nothing
        end
        if stage_ref !== nothing
            cache_path = joinpath(_gs_stage_dir(), stage_ref * ".jld2")
            verbose && println("  GS stage-cache key → $(stage_ref)")
        end
    end
    if cache_path !== nothing && isfile(cache_path)
        if verbose
            println("  Loading cached GS from $cache_path")
            flush(stdout);
            ccall(:fflush, Cint, (Ptr{Cvoid},), C_NULL)
        end
        d = JLD2.load(cache_path)
        psi_out = d["psi"]
        energy = get(d, "energy", NaN)
        converged = get(d, "converged", true)
        ws_cached = make_workspace(;
            grid, atom, interactions, zeeman, potential,
            sim_params=SimParams(; dt, n_steps=1, save_every=1),
            psi_init=psi_out,
            enable_ddi, c_dd=c_dd_val,
            secular_ddi=secular, quasi_2d_ddi=q2d, l_z_ddi=lz, ddi_trunc_radius=ddi_trunc,
            ddi_padding=ddi_padded_b, ddi_pad_factor=ddi_pf,
            backend,
        )
        step_result = Dict{Symbol, Any}(
            :ground_state_energy => energy,
            :ground_state_converged => converged,
            :workspace => ws_cached,
            :gs_stage_ref => stage_ref,
        )
        return (psi_out, grid, atom, ws_cached, step_result)
    end
    initial_state = Symbol(get(p, "initial_state", "polar"))
    init_state_params = Dict{Symbol, Float64}()
    if haskey(p, "init_state_params")
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

    psi_init = psi_prev
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

    V_trap_for_ls = evaluate_potential(potential, grid)
    ls_raw = get(p, "light_shift", nothing)
    gs_light_shift = _parse_light_shift(ls_raw, atom.F, V_trap_for_ls, backend)
    # `_resolve_lhy_block!` writes the resolved LHY mode (from the user-facing
    # `lhy: {kind: ...}` block) into the internal `lhy_kind` slot. Prior to
    # 2026-05-22 this read `p["spinor_lhy"]` — a stale reference to the old
    # YAML key — which was never written by the new resolver, silently
    # disabling non-scalar LHY modes (polar_contact / icosahedral / ...)
    # for every YAML pipeline run.
    spinor_lhy_mode = let v = get(p, "lhy_kind", nothing)
        v === nothing ? nothing : Symbol(String(v))
    end

    gs_rf_omega = Float64(get(p, "rotating_frame_omega", 0.0))
    gs = if method === :itp
        find_ground_state(;
            grid, atom, interactions, zeeman, potential,
            dt, n_steps, tol, initial_state, init_state_params, psi_init,
            enable_ddi, c_dd=c_dd_val,
            secular_ddi=secular, quasi_2d_ddi=q2d, l_z_ddi=lz, ddi_trunc_radius=ddi_trunc,
            ddi_padding=ddi_padded_b, ddi_pad_factor=ddi_pf,
            target_magnetization=target_mz, backend, on_step,
            checkpoint_dir=checkpoint_dir,
            save_every=max(1, n_steps ÷ 100),
            light_shift=gs_light_shift,
            spinor_lhy=spinor_lhy_mode,
            rotating_frame_omega=gs_rf_omega,
            verbose=verbose,
        )
    elseif method === :lbfgs
        m_lbfgs = Int(get(p, "m_lbfgs", 10))
        newton_polish = get(p, "newton_polish", false) == true
        residual_polish = get(p, "residual_polish", false) == true
        pin_closure, pin_eps = _resolve_pin_block(get(p, "pin", nothing), zeeman)
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
                pin=pin_closure, epsilon_ramp=pin_eps,
                residual_polish,
            )
        end
    else
        throw(ArgumentError("Unknown ground_state method: $method. Supported: itp, lbfgs"))
    end

    # Strip any Nyquist-mode junk the LBFGS/Newton path can accumulate (ITP is
    # already dealiased) — kills the checkerboard artifact at the source in the
    # saved/analysed ψ. Host copy: the null uses a CPU FFT.
    psi_out = _null_nyquist_modes!(_to_host(copy(gs.workspace.state.psi)), grid)
    # With a pin ε-continuation the certified energy is the ε→0 extrapolation,
    # not the last pinned-rung value.
    gs_energy = hasproperty(gs, :E0_extrap) ? gs.E0_extrap : gs.energy
    verbose && _print_gs_summary(psi_out, grid, atom, gs)

    # Save to cache if specified
    if cache_path !== nothing
        mkpath(dirname(cache_path))
        psi_host = _to_host(psi_out)
        tmp = cache_path * ".tmp"
        try
            jldopen(tmp, "w") do f
                f["psi"] = psi_host
                f["energy"] = gs_energy
                f["converged"] = gs.converged
            end
            mv(tmp, cache_path; force=true)
            verbose && println("  Cached GS to $cache_path")
        catch err
            isfile(tmp) && rm(tmp; force=true)
            @warn "Failed to save GS cache: $err"
        end
    end

    step_result = Dict{Symbol, Any}(
        :ground_state_energy => gs_energy,
        :ground_state_converged => gs.converged,
        :ground_state_grad_norm => Float64(get(gs, :grad_norm, NaN)),
        :workspace => gs.workspace,
        :gs_stage_ref => stage_ref,
    )
    (psi_out, grid, atom, gs.workspace, step_result)
end
