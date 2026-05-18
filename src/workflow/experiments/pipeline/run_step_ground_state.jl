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
        return (true, ws_prev.ddi.C_dd, false, false, 0.0)
    elseif haskey(p, "interactions")
        return _parse_gs_ddi(Dict{String, Any}(), p["interactions"], atom)
    else
        return (false, NaN, false, false, 0.0)
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
    enable_ddi, c_dd_val, secular, q2d, lz = _resolve_gs_ddi_inheritance(p, ws_prev, atom)
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
        _build_zeeman_dispatched(p["B"], duration, atom, p)
    elseif ws_prev !== nothing
        ws_prev.zeeman
    else
        _parse_zeeman(Dict(), duration)
    end

    # --- Cache: skip ITP/LBFGS if file exists, but build a workspace so
    #     downstream analyzers (e.g. bogoliubov) can inspect the system ---
    cache_path = get(p, "cache", nothing)
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
            secular_ddi=secular, quasi_2d_ddi=q2d, l_z_ddi=lz,
            backend,
        )
        step_result = Dict{Symbol, Any}(
            :ground_state_energy => energy,
            :ground_state_converged => converged,
            :workspace => ws_cached,
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
        psi_init = add_thermal_noise(psi_base, atom.F;
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
    spinor_lhy_mode = let v = get(p, "spinor_lhy", nothing)
        v === nothing ? nothing : Symbol(String(v))
    end

    gs_rf_omega = Float64(get(p, "rotating_frame_omega", 0.0))
    gs = if method === :itp
        find_ground_state(;
            grid, atom, interactions, zeeman, potential,
            dt, n_steps, tol, initial_state, init_state_params, psi_init,
            enable_ddi, c_dd=c_dd_val,
            secular_ddi=secular, quasi_2d_ddi=q2d, l_z_ddi=lz,
            target_magnetization=target_mz, backend, on_step,
            checkpoint_dir=checkpoint_dir,
            checkpoint_every=checkpoint_dir !== nothing ? max(1, n_steps ÷ 10) : 0,
            light_shift=gs_light_shift,
            spinor_lhy=spinor_lhy_mode,
            rotating_frame_omega=gs_rf_omega,
            verbose=verbose,
        )
    elseif method === :lbfgs
        m_lbfgs = Int(get(p, "m_lbfgs", 10))
        # Reuse existing workspace when available to preserve DDI flags (secular/q2d/l_z).
        # Skip reuse when backend is explicitly overridden (e.g. GPU ITP → CPU LBFGS).
        if ws_prev !== nothing && !haskey(p, "backend") &&
            !haskey(p, "interactions") && !haskey(p, "ddi") &&
            !haskey(p, "potential") && !haskey(p, "B")
            find_ground_state_lbfgs(;
                ws_init=ws_prev, psi_init,
                n_steps, tol, m_lbfgs,
                target_magnetization=target_mz,
                verbose,
            )
        else
            find_ground_state_lbfgs(;
                grid, atom, interactions, zeeman, potential,
                n_steps, tol, m_lbfgs, initial_state, init_state_params, psi_init,
                enable_ddi, c_dd=c_dd_val,
                secular_ddi=secular, quasi_2d_ddi=q2d, l_z_ddi=lz,
                target_magnetization=target_mz, backend,
                verbose,
                light_shift=gs_light_shift,
            )
        end
    else
        throw(ArgumentError("Unknown ground_state method: $method. Supported: itp, lbfgs"))
    end

    psi_out = copy(gs.workspace.state.psi)
    verbose && _print_gs_summary(psi_out, grid, atom, gs)

    # Save to cache if specified
    if cache_path !== nothing
        mkpath(dirname(cache_path))
        psi_host = _to_host(psi_out)
        tmp = cache_path * ".tmp"
        try
            jldopen(tmp, "w") do f
                f["psi"] = psi_host
                f["energy"] = gs.energy
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
        :ground_state_energy => gs.energy,
        :ground_state_converged => gs.converged,
        :workspace => gs.workspace,
    )
    (psi_out, grid, atom, gs.workspace, step_result)
end
