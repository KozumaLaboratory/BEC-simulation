# --- Pipeline parser & runner ---

function parse_pipeline(data::Dict)
    pipe_data = data["pipeline"]
    (pipe_data isa AbstractVector && !isempty(pipe_data)) ||
        throw(ArgumentError("pipeline: must be a non-empty list of steps"))

    # `defaults:` (top-level, optional): a flat dict whose keys seed every
    # pipeline step's inner block. Step-level entries override defaults.
    # E.g. `defaults: {kind: rotating_basis, save_every: 30, epsilon: 1e-6}`
    # applies to ground_state + every dynamics block. Useful for DRY across
    # multi-phase Klaus / Berry configs.
    defaults = haskey(data, "defaults") ? data["defaults"] : nothing
    if defaults !== nothing
        defaults isa AbstractDict || throw(ArgumentError(
            "defaults: must be a mapping, got $(typeof(defaults))"))
        pipe_data = [_apply_step_defaults(s, defaults) for s in pipe_data]
    end

    steps = PipelineStep[_parse_step(s) for s in pipe_data]

    scan = if haskey(data, "scan")
        scan_d = data["scan"]
        if get(scan_d, "type", nothing) == "constrained_jz"
            _parse_constrained_jz_scan(scan_d)
        else
            _parse_override_scan(scan_d)
        end
    else
        nothing
    end

    PipelineConfig(steps, scan, data)
end

"""
Seed an unkeyed step entry's inner block with `defaults`. Step-level keys
override defaults. Returns a new Dict (immutable input).
"""
function _apply_step_defaults(step::Dict, defaults::AbstractDict)
    keys_list = collect(keys(step))
    length(keys_list) == 1 || return step  # malformed; let _parse_step error
    key = keys_list[1]
    inner = step[key]
    inner isa AbstractDict || return step  # e.g. analyze: <list> doesn't get defaults

    seeded = Dict{Any, Any}()
    for (k, v) in defaults
        seeded[k] = v
    end
    for (k, v) in inner
        seeded[k] = v   # step-level wins
    end
    Dict{Any, Any}(key => seeded)
end

function _parse_step(d::Dict)
    keys_list = collect(keys(d))
    length(keys_list) == 1 || throw(ArgumentError(
        "Each pipeline step must have exactly one key, got: $keys_list"))
    key = Symbol(keys_list[1])
    val = d[keys_list[1]]

    if key == :ground_state
        params = Dict{String, Any}(string(k) => v for (k, v) in val)
        kind = get(params, "kind", nothing)
        if kind == "binary" || kind == :binary
            BinaryGroundStateStep(params)
        elseif kind == "rotating_basis" || kind == :rotating_basis ||
            kind == "option_gamma" || kind == :option_gamma
            RotatingBasisGroundStateStep(params)
        else
            GroundStateStep(params)
        end
    elseif key == :dynamics
        params = Dict{String, Any}(string(k) => v for (k, v) in val)
        kind = get(params, "kind", nothing)
        if kind == "binary" || kind == :binary
            BinaryDynamicsStep(params)
        elseif kind == "rotating_basis" || kind == :rotating_basis ||
            kind == "option_gamma" || kind == :option_gamma
            RotatingBasisDynamicsStep(params)
        else
            DynamicsStep(params)
        end
    elseif key == :analyze
        analyzers = Pair{Symbol, Dict{String, Any}}[]
        for entry in val
            if entry isa Dict
                for (ak, av) in entry
                    params = if av isa Dict
                        Dict{String, Any}(string(k) => v for (k, v) in av)
                    else
                        Dict{String, Any}()
                    end
                    push!(analyzers, Symbol(ak) => params)
                end
            end
        end
        AnalyzeStep(analyzers)
    else
        throw(
            ArgumentError("Unknown pipeline step: $key. Supported: ground_state, dynamics, analyze")
        )
    end
end

"""
    run_pipeline(config::PipelineConfig; verbose=true) -> NamedTuple

Execute a pipeline sequentially. Each step receives the current psi
and produces a new one. Analysis steps don't modify psi but accumulate
results.
"""
function run_pipeline(config::PipelineConfig; verbose::Bool=true, psi_init=nothing,
    checkpoint_dir::Union{Nothing, String}=nothing,
    live_status_path::Union{Nothing, String}=nothing)
    psi = psi_init
    grid = nothing
    atom = nothing
    workspace = nothing
    results = Dict{Symbol, Any}()
    if live_status_path !== nothing
        results[:_live_status_path] = live_status_path
    end

    for (i, step) in enumerate(config.steps)
        if verbose
            println("Step $i/$(length(config.steps)): $(nameof(typeof(step)))")
            flush(stdout);
            ccall(:fflush, Cint, (Ptr{Cvoid},), C_NULL)
        end
        # Push the per-iteration dispatch + tuple destructuring into a
        # @nospecialize-tagged helper. Without that, Julia specialises
        # this loop body across every PipelineStep concrete type AND
        # every _run_step return-tuple shape, which compounds into a
        # multi-minute JIT cascade once the binary GP path is in the
        # union (CLAUDE.md "Type stability boundaries"). The helper
        # treats step as Any, so dispatch happens at runtime and the
        # surrounding inference world stays narrow.
        psi, grid, atom, workspace = _step_dispatch!(
            results, step, psi, grid, atom, workspace,
            verbose, checkpoint_dir, live_status_path,
        )
    end

    # Auto-save rotating_basis pipelines into the dashboard-canonical layout
    # whenever the caller supplied a `checkpoint_dir`. This eliminates the
    # need for downstream launchers to call `save_rotating_basis_result!`
    # by hand and unifies the on-disk format with the dashboard reader.
    # Lab-frame `:dynamics_history` already saves itself via the workflow
    # runner; this hook only fires for the rotating_basis path.
    if checkpoint_dir !== nothing && haskey(results, :rotating_basis_history)
        try
            save_rotating_basis_result!(checkpoint_dir, results)
            verbose && println(
                "  auto-saved canonical rotating_basis result -> ",
                joinpath(checkpoint_dir, "result.jld2"),
            )
        catch err
            @warn "rotating_basis auto-save failed; downstream launcher should " *
                "call save_rotating_basis_result! manually" exception = (err, catch_backtrace())
        end
    end

    (psi=psi, grid=grid, atom=atom, results...)
end

# Inference barrier for the per-step dispatch — see run_pipeline for
# rationale. `@nospecialize` on `step` is the load-bearing annotation:
# without it, Julia generates a fresh specialisation of this function
# (and the rest of the loop body) for each PipelineStep concrete type
# the YAML mentions, and the binary GP path's return-tuple type hits a
# combinatorial explosion that takes 10+ minutes of inference work to
# settle. With it, dispatch on step happens once at runtime per step.
@noinline function _step_dispatch!(
    results::Dict{Symbol, Any},
    @nospecialize(step),
    @nospecialize(psi),
    @nospecialize(grid),
    @nospecialize(atom),
    @nospecialize(workspace),
    verbose::Bool,
    checkpoint_dir,
    live_status_path::Union{Nothing, String},
)
    # Each branch hands back a 5-tuple from _run_step. We narrow to
    # `Tuple` immediately so the loop-local types stay maximally generic.
    out = if step isa AnalyzeStep
        _run_step(step, psi, grid, atom, workspace;
            verbose, checkpoint_dir, pipeline_results=results)
    elseif step isa BinaryDynamicsStep
        _run_step(step, psi, grid, atom, workspace;
            verbose, checkpoint_dir, pipeline_results=results)
    elseif step isa RotatingBasisDynamicsStep
        _run_step(step, psi, grid, atom, workspace;
            verbose, checkpoint_dir, pipeline_results=results)
    elseif step isa DynamicsStep
        _run_step(step, psi, grid, atom, workspace;
            verbose, checkpoint_dir, live_status_path)
    elseif step isa GroundStateStep ||
        step isa BinaryGroundStateStep ||
        step isa RotatingBasisGroundStateStep
        _run_step(step, psi, grid, atom, workspace; verbose, checkpoint_dir)
    else
        # Defensive: a new PipelineStep subtype must be added explicitly above
        # so the kwargs passed to its _run_step match its method signature.
        # Julia would otherwise raise MethodError, but the message would not
        # mention this dispatch site — easier to debug if we point here.
        throw(
            ArgumentError(
                "Unknown PipelineStep subtype $(typeof(step)) in _step_dispatch!. " *
                "Add an explicit branch in _step_dispatch! (pipeline_runner.jl:123) " *
                "and a matching _run_step(::$(typeof(step)), ...) method.",
            ),
        )
    end
    psi_out, grid_out, atom_out, workspace_out, step_result = out
    if step_result !== nothing
        if step isa DynamicsStep || step isa BinaryDynamicsStep
            history = get(results, :dynamics_history, NamedTuple[])
            push!(
                history,
                (
                    dynamics_result=get(step_result, :dynamics_result, nothing),
                    snapshot_tmp_path=get(step_result, :snapshot_tmp_path, nothing),
                    save_psi_snapshots=get(step_result, :save_psi_snapshots, false),
                    snapshot_count=get(step_result, :snapshot_count, 0),
                ),
            )
            results[:dynamics_history] = history
        elseif step isa RotatingBasisDynamicsStep
            # Each phase's dyn dict goes into a list so save_rotating_basis_result!
            # can concatenate the full GS → ramp → chirp → stir timeseries.
            # Without this the last `merge!` would overwrite earlier phases'
            # `:rotating_basis_dynamics` entry and on-disk results would only
            # cover the final phase.
            rb_history = get(results, :rotating_basis_history, Dict[])
            if haskey(step_result, :rotating_basis_dynamics)
                push!(rb_history, step_result[:rotating_basis_dynamics])
            end
            results[:rotating_basis_history] = rb_history
        end
        merge!(results, step_result)
    end
    return (psi_out, grid_out, atom_out, workspace_out)
end

# --- Step dispatch ---

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

    # --- atom: inherit from previous step if absent ---
    atom = if haskey(p, "atom")
        a = resolve_atom(Symbol(p["atom"]))
        _resolve_derived_params!(p, a; verbose)
        a
    elseif atom_prev !== nothing
        atom_prev
    else
        throw(ArgumentError("ground_state step requires 'atom' (no previous step to inherit from)"))
    end

    # --- grid: inherit from previous step if absent ---
    grid, ndim = if haskey(p, "grid")
        _setup_grid_from_params(p)
    elseif grid_prev !== nothing
        (grid_prev, length(grid_prev.config.n_points))
    else
        throw(ArgumentError("ground_state step requires 'grid' (no previous step to inherit from)"))
    end

    # --- Physical params: inherit from ws_prev if absent ---
    interactions = if haskey(p, "interactions")
        _parse_gs_interactions(p["interactions"], atom)
    elseif ws_prev !== nothing
        ws_prev.interactions
    else
        _parse_gs_interactions(Dict{String, Any}(), atom)
    end

    enable_ddi, c_dd_val, secular, q2d, lz = if haskey(p, "ddi") || haskey(p, "interactions")
        _parse_gs_ddi(get(p, "ddi", Dict()), get(p, "interactions", Dict()), atom)
    elseif ws_prev !== nothing && ws_prev.ddi !== nothing
        (true, ws_prev.ddi.C_dd, false, false, 0.0)
    else
        (false, NaN, false, false, 0.0)
    end

    potential = if haskey(p, "potential")
        _parse_and_build_potential(p["potential"], ndim)
    elseif ws_prev !== nothing
        ws_prev.potential
    else
        _parse_and_build_potential(Dict("type" => "harmonic", "omega" => ones(ndim)), ndim)
    end

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
    zeeman = if haskey(p, "zeeman")
        _build_zeeman_dispatched(p["zeeman"], duration, atom, p)
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
            !haskey(p, "potential") && !haskey(p, "zeeman")
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

function _run_step(
    step::DynamicsStep, psi_prev, grid, atom, ws_prev;
    verbose=true, checkpoint_dir=nothing,
    live_status_path::Union{Nothing, String}=nothing,
)
    psi_prev !== nothing ||
        throw(ArgumentError("dynamics step requires a preceding ground_state step"))
    grid !== nothing || throw(ArgumentError("dynamics step requires grid from preceding step"))
    p = step.params
    ndim = length(grid.config.n_points)
    F = atom.F

    duration = Float64(p["duration"])
    dt = Float64(p["dt"])
    save_every = _resolve_save_every(p, duration, dt)

    prev_interactions = ws_prev !== nothing ? ws_prev.interactions : InteractionParams(0.0, 0.0)
    prev_potential = ws_prev !== nothing ? ws_prev.potential : HarmonicTrap(ntuple(_ -> 1.0, ndim))
    prev_ddi = ws_prev !== nothing ? ws_prev.ddi : nothing
    prev_c_dd = prev_ddi !== nothing ? prev_ddi.C_dd : NaN
    prev_enable_ddi = prev_ddi !== nothing

    ddi_raw = get(p, "ddi", nothing)
    enable_ddi = if ddi_raw === nothing
        prev_enable_ddi
    elseif ddi_raw isa Bool
        ddi_raw
    elseif ddi_raw isa Dict
        Bool(get(ddi_raw, "enabled", prev_enable_ddi))
    else
        prev_enable_ddi
    end
    c_dd_val = if ddi_raw isa Dict && haskey(ddi_raw, "c_dd")
        Float64(ddi_raw["c_dd"])
    else
        prev_c_dd
    end

    zeeman_wrapper = Dict{String, Any}(
        "ground_state" => Dict{String, Any}("zeeman" => get(p, "zeeman", Dict()))
    )
    zeeman = _build_phase_zeeman(zeeman_wrapper, 0.0, duration; atom, p_step=p)

    pot_d = get(p, "potential", nothing)
    potential = pot_d !== nothing ? _parse_and_build_potential(pot_d, ndim) : prev_potential

    temp_ratio = let v = get(p, "temperature_ratio", nothing)
        v === nothing ? nothing : Float64(v)
    end

    n_steps = round(Int, duration / dt)
    rf_omega = Float64(get(p, "rotating_frame_omega", 0.0))
    spin_rf_omega = Float64(get(p, "spin_rotating_frame_omega", 0.0))
    sp = SimParams(; dt, n_steps, save_every,
        rotating_frame_omega=rf_omega,
        spin_rotating_frame_omega=spin_rf_omega)

    inter = get(p, "interactions", nothing)
    interactions = inter !== nothing ? _parse_gs_interactions(inter, atom) : prev_interactions

    backend = ws_prev !== nothing ? ws_prev.backend : CPUBackend()

    ab_raw = get(p, "absorbing_boundary", nothing)
    absorbing_boundary = if ab_raw isa Dict
        AbsorbingBoundary(;
            strength=Float64(ab_raw["strength"]),
            width=Float64(ab_raw["width"]),
            power=Int(get(ab_raw, "power", 2)),
        )
    else
        nothing
    end

    ls_raw = get(p, "light_shift", nothing)
    light_shift = _parse_light_shift(ls_raw, F, nothing, backend)

    # Loss parser may need (atom, N_atoms, omega_ref) when SI-unit K_3 is used
    inter_raw = get(p, "interactions", Dict{String, Any}())
    n_atoms_for_loss = get(inter_raw, "N_atoms", nothing)
    omega_ref_for_loss = get(inter_raw, "omega_ref", nothing)
    loss = _parse_loss_params(get(p, "loss", nothing);
        atom=atom, N_atoms=n_atoms_for_loss, omega_ref=omega_ref_for_loss)

    raman = _build_raman(p, duration)

    time_dep_interactions = let inter_raw = get(p, "interactions", nothing)
        if inter_raw isa Dict
            c0_spec = get(inter_raw, "c0", nothing)
            c1_spec = get(inter_raw, "c1", nothing)
            if (c0_spec isa Dict) || (c1_spec isa Dict)
                c0_wf = _make_waveform(c0_spec !== nothing ? c0_spec : interactions.c0, duration)
                c1_wf = _make_waveform(c1_spec !== nothing ? c1_spec : interactions.c1, duration)
                TimeDependentInteractions(c0_wf, c1_wf)
            else
                nothing
            end
        else
            nothing
        end
    end

    magnetic_gradient = let mg_raw = get(p, "magnetic_gradient", nothing)
        if mg_raw isa Dict
            grad_spec = mg_raw["gradient"]
            axis = Int(get(mg_raw, "axis", ndim))
            g_F = Float64(get(mg_raw, "g_F", 1.0))
            if grad_spec isa Dict
                wf = _make_waveform(grad_spec, duration)
                TimeDependentMagneticGradient{ndim}(wf, axis, g_F)
            else
                MagneticGradient{ndim}(Float64(grad_spec), axis, g_F)
            end
        else
            nothing
        end
    end

    # Pulse sequence: compile into TimeDep* overrides (type-narrowed to avoid
    # inference blow-up when `run_pipeline` dispatches abstractly on PipelineStep)
    zeeman, raman, time_dep_interactions = _apply_pulse_sequence(
        get(p, "pulse_sequence", nothing), duration, interactions,
        zeeman, raman, time_dep_interactions,
    )

    ws = make_workspace(;
        grid, atom, interactions,
        zeeman, potential,
        sim_params=sp,
        psi_init=psi_prev,
        enable_ddi, c_dd=c_dd_val,
        backend,
        absorbing_boundary,
        light_shift,
        loss,
        raman,
        time_dep_interactions,
        magnetic_gradient,
    )

    if temp_ratio !== nothing
        psi_noisy = add_thermal_noise(
            ws.state.psi, F; T_over_Tc=temp_ratio, seed=Int(get(p, "noise_seed", 42))
        )
        ws.state.psi .= psi_noisy
    end

    seed_amp = let v = get(p, "seed_amplitude", nothing)
        v === nothing ? nothing : Float64(v)
    end
    if seed_amp !== nothing
        seed_k_cut = let v = get(p, "seed_k_cut", nothing)
            v === nothing ? nothing : Float64(v)
        end
        add_symmetry_breaking_seed!(
            ws.state.psi, F;
            amplitude=seed_amp,
            seed=Int(get(p, "noise_seed", 42)),
            k_cut=seed_k_cut,
            grid=seed_k_cut === nothing ? nothing : grid,
        )
    end

    twa_raw = get(p, "twa", nothing)
    if twa_raw !== nothing
        twa_config = _parse_twa_config(twa_raw)
        store_traj = Bool(get(twa_raw, "store_trajectories", false))
        ensemble = run_twa(;
            psi_gs=psi_prev, grid, atom, interactions, zeeman, potential,
            sim_params=sp, twa_config, enable_ddi, c_dd=c_dd_val, backend,
            store_trajectories=store_traj, verbose,
        )

        verbose && @printf("  TWA ensemble: %d trajectories, %d snapshots\n",
            ensemble.n_trajectories, length(ensemble.times))

        # Use mean density to reconstruct a representative psi_out for downstream
        psi_out = copy(psi_prev)
        step_result = Dict{Symbol, Any}(
            :ensemble_result => ensemble,
            :dynamics_workspace => ws,
        )
        return (psi_out, grid, atom, ws, step_result)
    end

    save_psi_snap = Bool(get(p, "save_psi_snapshots", false))
    save_compress = Bool(get(p, "save_snapshot_compression", false))
    snap_precision_str = String(get(p, "save_snapshot_precision", "f32"))
    snap_precision_cf =
        if snap_precision_str == "f64"
            ComplexF64
        elseif snap_precision_str == "f32"
            ComplexF32
        else
            throw(
                ArgumentError(
                    "save_snapshot_precision must be \"f32\" or \"f64\", got " *
                    snap_precision_str,
                ),
            )
        end

    cb_sgpe = _build_sgpe_callback(get(p, "sgpe", nothing), Float64(sp.dt))
    cb_pgp = _build_pgp_callback(get(p, "projected_gp", nothing))
    cb_photon = _build_photon_callback(get(p, "photon_scattering", nothing), Float64(sp.dt))
    cb_live = _build_live_callback(get(p, "live_monitor", nothing), live_status_path)
    extra_cb = _compose_callbacks(cb_sgpe, cb_pgp, cb_photon, cb_live)

    result, snap_tmp_path, snap_count = _run_dynamics_with_optional_streaming!(
        ws, save_psi_snap, save_compress, snap_precision_cf;
        extra_on_step=extra_cb,
    )

    if verbose
        println("  $(n_steps) steps, E_final=$(round(result.energies[end]; sigdigits=6))")
        flush(stdout);
        ccall(:fflush, Cint, (Ptr{Cvoid},), C_NULL)
    end

    psi_out = copy(ws.state.psi)
    step_result = Dict{Symbol, Any}(
        :dynamics_result => result,
        :dynamics_workspace => ws,
        :save_psi_snapshots => save_psi_snap,
        :save_snapshot_compression => save_compress,
        :snapshot_tmp_path => snap_tmp_path,
        :snapshot_count => snap_count,
    )
    (psi_out, grid, atom, ws, step_result)
end

"""
    _run_dynamics_with_optional_streaming!(ws, save_psi, compress)
        -> (result, tmp_path_or_nothing, snapshot_count)

When `save_psi` is false, run the simulation the normal way. When true,
open a scratch JLD2 file for snapshot streaming before the sim, install
an on_snapshot callback that downcasts to ComplexF32 and writes one
frame per key, then close the file. Peak host RAM while dynamics runs
is now one snapshot (~26 MB at 64³×13) instead of the full accumulated
vector (~8 GB at 154 snapshots).
"""
function _run_dynamics_with_optional_streaming!(
    ws, save_psi::Bool, compress::Bool,
    snap_type::Type{<:Complex}=ComplexF32;
    extra_on_step::Union{Nothing, Function}=nothing,
)
    if !save_psi
        cb = extra_on_step === nothing ? nothing :
             SimulationCallbacks(; on_step=extra_on_step)
        return (run_simulation!(ws; callbacks=cb), nothing, 0)
    end

    snap_tmp = _dynamics_scratch_path()
    jld_kwargs = compress ? (; compress=ZlibCompressor()) : (;)
    snap_file = jldopen(snap_tmp, "w"; jld_kwargs...)

    n_pts = ntuple(d -> size(ws.state.psi, d), ndims(ws.state.psi) - 1)
    D = size(ws.state.psi, ndims(ws.state.psi))
    snap_file["spatial_shape"] = collect(n_pts)
    snap_file["n_components"] = D
    snap_file["snap_eltype"] = string(snap_type)

    buf = Array{snap_type}(undef, n_pts..., D)
    frame_count = Ref(0)

    on_snap = function (_ws, _step, psi_snap)
        frame_count[] += 1
        buf .= snap_type.(psi_snap)
        snap_file["frame_" * lpad(string(frame_count[]), 5, '0')] = buf
        return nothing
    end

    result = try
        run_simulation!(
            ws;
            callbacks=SimulationCallbacks(;
                on_snapshot=on_snap,
                on_step=extra_on_step,
            ),
            stream_snapshots=true,
        )
    finally
        snap_file["n_snapshots"] = frame_count[]
        close(snap_file)
    end

    return (result, snap_tmp, frame_count[])
end

"""
    _build_pgp_callback(node) -> Union{Nothing,Function}

Parse a `dynamics.projected_gp:` block into a Projected-GP on-step
callback. Accepts:

    projected_gp: false | null
    projected_gp: {k_cut: 6.0, smooth: false, every: 1}
"""
function _build_pgp_callback(node)
    node === nothing && return nothing
    node isa Bool && (node || return nothing)
    node isa Dict || throw(ArgumentError(
        "dynamics.projected_gp must be a Dict or `false`, got $(typeof(node))"))
    haskey(node, "k_cut") || throw(ArgumentError("dynamics.projected_gp requires `k_cut`"))
    k_cut = Float64(node["k_cut"])
    smooth = Bool(get(node, "smooth", false))
    every = Int(get(node, "every", 1))
    projected_gp_callback(k_cut; smooth=smooth, every=every)
end

"""
    _build_photon_callback(node, dt) -> Union{Nothing,Function}

Parse a `dynamics.photon_scattering:` block into a phase-diffusion
on-step callback. Accepts:

    photon_scattering: false | null
    photon_scattering: {Gamma_sc: 0.01, seed: 42}
"""
function _build_photon_callback(node, dt::Float64)
    node === nothing && return nothing
    node isa Bool && (node || return nothing)
    node isa Dict || throw(
        ArgumentError(
            "dynamics.photon_scattering must be a Dict or `false`, got $(typeof(node))"),
    )
    Γ_sc_key = if haskey(node, "Gamma_sc")
        "Gamma_sc"
    elseif haskey(node, "gamma_sc")
        "gamma_sc"
    else
        throw(ArgumentError("dynamics.photon_scattering requires `Gamma_sc`"))
    end
    Γ_sc = Float64(node[Γ_sc_key])
    seed = let v = get(node, "seed", nothing)
        v === nothing ? nothing : Int(v)
    end
    photon_scattering_callback(Γ_sc, dt; seed=seed)
end

"""
    _build_live_callback(node, status_path) -> Union{Nothing,Function}

Build an on_step callback that periodically writes a JSON status snapshot
to `status_path` for the dashboard's `/api/live/*` endpoints. Accepts:

    live_monitor: false | null   → off
    live_monitor: true           → defaults (every=50)
    live_monitor: {every: 100}   → custom cadence

If `status_path === nothing` we silently skip even when YAML asks for it
(useful for ad-hoc `run_config` calls that have no run dir).
"""
function _build_live_callback(node, status_path::Union{Nothing, String})
    node === nothing && return nothing
    if node isa Bool
        node || return nothing
        every = 50
    else
        node isa Dict || throw(ArgumentError(
            "dynamics.live_monitor must be Bool or Dict, got $(typeof(node))"))
        every = Int(get(node, "every", 50))
    end
    status_path === nothing && return nothing
    every >= 1 || throw(ArgumentError("live_monitor.every must be >= 1"))
    status_dir = dirname(status_path)
    isempty(status_dir) || mkpath(status_dir)
    function (ws, step, times, energies)
        step % every == 0 || return nothing
        psi = ws.state.psi
        D = size(psi, ndims(psi))
        ndim = ndims(psi) - 1
        n_total = sum(abs2, psi)
        pops = Float64[]
        for c in 1:D
            push!(pops, Float64(sum(abs2, selectdim(psi, ndim + 1, c))) / n_total)
        end
        e_now = isempty(energies) ? NaN : Float64(energies[end])
        t_now = isempty(times) ? Float64(ws.state.t) : Float64(times[end])
        data = Dict{String, Any}(
            "step" => step,
            "t" => t_now,
            "energy" => e_now,
            "norm" => Float64(n_total) * Float64(cell_volume(ws.grid)),
            "populations" => pops,
            "updated_ms" => round(Int, time() * 1000),
        )
        # Atomic write: tmp file + rename so HTTP readers never see partial JSON
        tmp_path = status_path * ".tmp"
        open(tmp_path, "w") do f
            JSON.print(f, data)
        end
        mv(tmp_path, status_path; force=true)
        nothing
    end
end

"""Compose multiple optional on_step callbacks into a single one. Each
nothing entry is silently skipped."""
function _compose_callbacks(cbs...)
    real_cbs = filter(cb -> cb !== nothing, collect(cbs))
    isempty(real_cbs) && return nothing
    length(real_cbs) == 1 && return real_cbs[1]
    function (ws, step, args...)
        for cb in real_cbs
            cb(ws, step, args...)
        end
        nothing
    end
end

"""
Binary (two-component) ground-state YAML entry point. Returns a result
shape compatible with the standard spinor `_run_step` path so analyzers
that only need ψ can still consume it.

Currently F=0 + F=0 via `find_binary_ground_state`. Spinor binary,
DDI, and YAML-side analyzer integration are next-session work — see
`docs/two_component_gp_design.md`.
"""
function _run_binary_ground_state_step(p::AbstractDict; verbose::Bool=true)
    grid_node = p["grid"]
    n = Int.(grid_node["n"])
    box = Float64.(grid_node["box"])
    grid = make_grid(GridConfig(Tuple(n), Tuple(box)))

    inter = p["interactions"]
    couplings = BinaryCouplings(;
        g_AA=Float64(inter["g_AA"]),
        g_BB=Float64(inter["g_BB"]),
        g_AB=Float64(inter["g_AB"]),
        omega_coupling=Float64(get(inter, "omega_coupling", 0.0)),
        delta_coupling=Float64(get(inter, "delta_coupling", 0.0)),
    )

    pot_node = get(p, "potential", Dict())
    potential = if pot_node isa AbstractDict && get(pot_node, "type", "") == "harmonic"
        ω_vec = Float64.(pot_node["omega"])
        length(ω_vec) == length(n) ||
            throw(ArgumentError("potential.omega length must match grid ndim"))
        HarmonicTrap(Tuple(ω_vec))
    else
        NoPotential()
    end

    state = find_binary_ground_state(
        grid;
        couplings=couplings,
        potential_A=potential,
        potential_B=potential,
        dt=Float64(get(p, "dt", 0.005)),
        n_steps=Int(get(p, "n_steps", 1000)),
        tol=Float64(get(p, "tol", 1e-6)),
        verbose=verbose,
    )

    # Stash ψ_A as the "psi" downstream so phase_classify etc. don't break;
    # ψ_B is in the binary-specific result. Atom / interactions are
    # placeholders — binary path doesn't carry a single AtomSpecies.
    placeholder_atom = AtomSpecies("Binary", 1.66e-25, 0, 0.0, 0.0, 0.0)
    psi_4d = reshape(state.psi_A, (size(state.psi_A)..., 1))
    step_result = Dict{Symbol, Any}(
        :binary_state => state,
        :binary_couplings => couplings,
    )
    return (psi_4d, grid, placeholder_atom, nothing, step_result)
end

# Concrete-type dispatch for binary GP. Both methods are tagged
# @noinline so the abstract reads from the YAML Dict{String,Any} stay
# inside this file's compilation unit and don't widen the inference
# world of the regular spinor steps.

@noinline function _run_step(
    step::BinaryGroundStateStep,
    psi_prev,
    grid_prev,
    atom_prev,
    ws_prev;
    verbose=true,
    checkpoint_dir=nothing,
)
    return _run_binary_ground_state_step(step.params; verbose=verbose)
end

@noinline function _run_step(
    step::BinaryDynamicsStep,
    psi_prev,
    grid,
    atom,
    ws_prev;
    verbose=true,
    checkpoint_dir=nothing,
    pipeline_results::Union{Nothing, Dict}=nothing,
)
    grid !== nothing || throw(ArgumentError(
        "binary dynamics step requires grid from preceding ground_state step"))
    pipeline_results !== nothing || throw(ArgumentError(
        "binary dynamics step requires preceding ground_state results"))
    return _run_binary_dynamics_inner(step.params, grid, pipeline_results;
        verbose=verbose)
end

# --- Option γ rotating-basis pipeline ---
#
# YAML schema:
#
#   ground_state:
#     kind: rotating_basis
#     atom: Eu151                      # name; pulled to populate F via atom DB
#     grid: {n: [16, 16, 16], box: [12, 12, 12]}
#     potential: {type: harmonic, omega: [1, 1, 1]}
#     interactions: {c0: 100, c1: 0, c_dd: 5, gamma_lhy: 0}
#     zeeman: {p: 5000, q: 0}
#     B_hat: {theta: 0, phi: 0}        # constant B̂ during ITP
#     gauge_fix: false                 # default true; set false to recover ψ_lab=Û_B ψ̃
#     n_steps: 200
#     dt: 0.005
#     init_m_idx: 1                    # start in m=+F (default 1)
#
#   dynamics:
#     kind: rotating_basis
#     duration: 1.0
#     dt: 0.005
#     B_hat:                           # time-dep field. Constant theta + linear phi
#       theta_const: 0.611             # rad
#       phi_omega:  4.524              # rad/dimless. φ(t) = phi_omega * t
#     save_every: 10                   # for trajectory observables (norm, per_m, L_z)
#
# Future-extensible: full waveform spec for theta(t), theta_dot(t),
# phi(t), phi_dot(t) (deferred this session — constant tilt + linear
# rotation covers Klaus magnetostir).

# Concrete callable types instead of closures, to avoid the closure-type
# pollution warned about in memory `pitfall_pipeline_inference.md`. Each
# closure site has a unique type → multiplies specialization combinatorics.
# These are reused across all rotating-basis pipeline runs.
struct _ConstAngle <: Function
    val::Float64
end
(c::_ConstAngle)(::Float64) = c.val

struct _LinearPhi <: Function
    omega::Float64
end
(c::_LinearPhi)(t::Float64) = c.omega * t

struct _ConstZero <: Function end
(::_ConstZero)(::Float64) = 0.0

const _ZERO_FUNC = _ConstZero()

# Linear ramp θ(t) = θ_start + (θ_end - θ_start)·clamp(t/T, 0, 1).
# `θ_dot(t) = (θ_end - θ_start)/T` for t ∈ [0,T], else 0.
struct _LinearRamp <: Function
    start_val::Float64
    end_val::Float64
    duration::Float64
end
(r::_LinearRamp)(t::Float64) =
    r.start_val + (r.end_val - r.start_val) * clamp(t / r.duration, 0.0, 1.0)

struct _LinearRampDot <: Function
    rate::Float64           # = (end - start) / duration
    duration::Float64
end
(r::_LinearRampDot)(t::Float64) = (0.0 ≤ t ≤ r.duration) ? r.rate : 0.0

# Linear chirp φ̇(t) = ω_start + (ω_end - ω_start)·clamp(t/T, 0, 1)
# φ(t) = ω_start·t + (ω_end - ω_start)·t²/(2T) for t ≤ T, then steady ω_end·t after.
struct _LinearChirpPhi <: Function
    omega_start::Float64
    omega_end::Float64
    duration::Float64
end
function (c::_LinearChirpPhi)(t::Float64)
    if t ≤ c.duration
        c.omega_start * t + (c.omega_end - c.omega_start) * t^2 / (2 * c.duration)
    else
        # After ramp ends, phase continues at constant ω_end
        c.omega_start * c.duration + (c.omega_end - c.omega_start) * c.duration / 2 +
        c.omega_end * (t - c.duration)
    end
end

struct _LinearChirpPhiDot <: Function
    omega_start::Float64
    omega_end::Float64
    duration::Float64
end
function (c::_LinearChirpPhiDot)(t::Float64)
    if t ≤ c.duration
        c.omega_start + (c.omega_end - c.omega_start) * t / c.duration
    else
        c.omega_end
    end
end

@noinline function _run_rotating_basis_ground_state_step(
    p::Dict{String, Any}; verbose::Bool=true
)
    grid_node = p["grid"]::Dict
    n = Int.(grid_node["n"])
    box = Float64.(grid_node["box"])

    # Float precision: see V_trap allocation below for context. Grid must
    # match V_trap precision so make_rotating_basis_ws's `T` parameter is
    # consistent across all inputs.
    dtype_str = String(get(p, "dtype", "f64"))::String
    T_float = dtype_str == "f32" ? Float32 : Float64

    grid = make_grid(GridConfig(Tuple(n), Tuple(box)); dtype=T_float)

    pot_node = p["potential"]::Dict
    get(pot_node, "type", "harmonic") == "harmonic" || throw(
        ArgumentError(
            "rotating_basis ground_state currently supports only `potential.type: harmonic`"),
    )
    ω_vec = Float64.(pot_node["omega"])::Vector{Float64}
    length(ω_vec) == length(n) ||
        throw(ArgumentError("potential.omega length must match grid ndim"))

    # T_float was resolved earlier (must match grid precision). Allocate
    # V_trap at the same precision.
    V_trap = zeros(T_float, Tuple(n)...)
    @inbounds for I in CartesianIndices(V_trap)
        V_local = T_float(0)
        for d in 1:length(n)
            x_d = T_float(grid.x[d][I[d]])
            V_local += T_float(ω_vec[d])^2 * x_d^2
        end
        V_trap[I] = T_float(0.5) * V_local
    end

    # --- Physical-parameter path (recommended) ------------------------------
    # Spec: `atom: Eu151` + `N_atoms: 60000` + `omega_ref: 314.159 rad/s`
    # auto-derives c0, c_dd, gamma_lhy via project's canonical helpers.
    # Manual c0/c_dd literals in `interactions:` override the auto-computed
    # values but emit a warning since the convention is easy to get wrong
    # (project uses spinor convention c_dd = μ₀(μ/F)², where the F² returns
    # via spin operators in the Hamiltonian).
    atom_obj = if haskey(p, "atom")
        atom_name = string(p["atom"])::String
        if atom_name == "Eu151"
            ;
            SpinorBEC.Eu151
        elseif atom_name == "Dy164"
            ;
            SpinorBEC.Dy164
        elseif atom_name == "Dy162"
            ;
            SpinorBEC.Dy162
        elseif atom_name == "Cr52"
            ;
            SpinorBEC.Cr52
        elseif atom_name == "Rb87"
            ;
            SpinorBEC.Rb87
        else
            ;
            nothing
        end
    else
        nothing
    end
    F_atom = if haskey(p, "F")
        Int(p["F"])::Int
    elseif atom_obj !== nothing
        atom_obj.F
    else
        1
    end

    inter = p["interactions"]::Dict
    auto_path = atom_obj !== nothing && haskey(p, "N_atoms") && haskey(p, "omega_ref")
    c0_auto = 0.0;
    c_dd_auto = 0.0;
    γ_auto = 0.0;
    ε_dd_phys = NaN
    if auto_path
        N_atoms = Int(p["N_atoms"])::Int
        ω_ref = Float64(p["omega_ref"])
        c0_auto = compute_c_total(atom_obj; N_atoms=N_atoms, omega_ref=ω_ref)
        c_dd_auto = compute_c_dd_dimless(atom_obj; N_atoms=N_atoms, omega_ref=ω_ref)
        a_ho = sqrt(SpinorBEC.Units.HBAR / (atom_obj.mass * ω_ref))
        ε_dd_phys = compute_a_dd(atom_obj) / atom_obj.a_s
        # Lima-Pelster γ_LHY (only nonzero if ε_dd worth stabilising)
        γ_auto = ε_dd_phys > 0.5 ?
                 compute_gamma_lhy(atom_obj.a_s / a_ho, ε_dd_phys, N_atoms) : 0.0
    end

    c0 = haskey(inter, "c0") ? Float64(inter["c0"]) : c0_auto
    c_dd = haskey(inter, "c_dd") ? Float64(inter["c_dd"]) : c_dd_auto
    γ = haskey(inter, "gamma_lhy") ? Float64(inter["gamma_lhy"]) : γ_auto
    c1 = Float64(get(inter, "c1", 0.0))

    if verbose && auto_path
        # Show physical ε_dd alongside the dimensionless effective ε_dd_eff
        # (= c_dd·F²/(3·c0)) so user can verify convention immediately.
        ε_dd_eff = c0 > 0 ? c_dd * F_atom^2 / (3 * c0) : NaN
        printstyled(
            "  rotating_basis physics: atom=$(atom_obj.name), N=$(p["N_atoms"]), ω_ref=$(p["omega_ref"]) rad/s\n";
            color=:cyan,
        )
        @printf "    c0=%.3e c_dd=%.3e γ_LHY=%.3e\n" c0 c_dd γ
        @printf "    ε_dd_phys = a_dd/a_s = %.4f, ε_dd_eff (solver) = %.4f  ← MUST match\n" ε_dd_phys ε_dd_eff
    end
    if !auto_path && verbose
        printstyled(
            "  ⚠️  rotating_basis: manual c0/c_dd path (no `atom`+`N_atoms`+`omega_ref`).\n";
            color=:yellow,
        )
        printstyled(
            "       Convention reminder: c_dd uses spinor `μ₀(μ/F)²` (F² returns via spin ops).\n";
            color=:yellow,
        )
    end

    zee = p["zeeman"]::Dict
    p_z = Float64(get(zee, "p", 0.0))
    q_z = Float64(get(zee, "q", 0.0))

    B_hat = get(p, "B_hat", Dict{String, Any}())::Dict
    θ_init = Float64(get(B_hat, "theta", 0.0))
    φ_init = Float64(get(B_hat, "phi", 0.0))
    gauge_fix_flag = Bool(get(p, "gauge_fix", true))

    # Device backend: "cpu" (default) or "cuda"
    backend_name = String(get(p, "backend", "cpu"))::String
    backend_obj = if backend_name == "cuda" || backend_name == "gpu"
        CUDABackend()
    else
        CPUBackend()
    end

    ws = make_rotating_basis_ws(grid, F_atom, V_trap;
        p=p_z, q=q_z, c0=c0, c1=c1, c_dd=c_dd, gamma_lhy=γ,
        theta_func=_ConstAngle(θ_init), phi_func=_ConstAngle(φ_init),
        theta_dot_func=_ZERO_FUNC, phi_dot_func=_ZERO_FUNC,
        gauge_fix=gauge_fix_flag,
        backend=backend_obj,
    )

    D = 2F_atom + 1
    init_m_idx = Int(get(p, "init_m_idx", p_z > 0 ? 1 : D))::Int
    σ_init = Float64(get(p, "init_sigma", 1.0))
    # Build Gaussian on host (CPU) then copyto! to device — avoids GPU scalar
    # indexing on every cell. For 32×32×16 grid this is ~50 KB host alloc.
    psi_init_host = zeros(ComplexF64, grid.config.n_points..., D)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        r2 = 0.0
        for d in 1:length(n)
            r2 += grid.x[d][I[d]]^2
        end
        psi_init_host[I, init_m_idx] = exp(-r2 / (2σ_init^2))
    end
    copyto!(ws.psi_tilde, psi_init_host)
    normalize_rotating!(ws)

    n_steps = Int(get(p, "n_steps", 200))
    dt_itp = Float64(get(p, "dt", 0.005))

    if verbose
        println("  rotating_basis GS: F=", F_atom, " D=", D,
            " p=", p_z, " ε_dd_eff=", round(c_dd * F_atom^2 / (3 * c0); digits=3))
    end

    μ_final = find_ground_state_rotating!(ws, n_steps, T_float(dt_itp))

    placeholder_atom = AtomSpecies("RotatingBasis", 1.66e-25, F_atom, 0.0, 0.0, 0.0)
    # IMPORTANT: keep RotatingBasisWS OUT of the return tuple. The 23-type-param
    # Workspace (or our 6-param RotatingBasisWS) propagates through abstract
    # PipelineStep dispatch into make_workspace inference combinatorics, which
    # the memory `pitfall_pipeline_inference.md` documents as a 30+ min hang.
    # Stash ws inside the Dict{Symbol,Any} step_result (Any-typed, inference-safe).
    # Also type-assert psi_tilde to a CONCRETE 4D array — RotatingBasisWS.psi_tilde
    # is declared as `Array{Complex{T}}` (any dim), and an abstract array element
    # in the return tuple pollutes downstream step's psi argument inference.
    step_result = Dict{Symbol, Any}(
        :rotating_basis_ws => ws,
        :rotating_basis_F => F_atom,
        :rotating_basis_mu => μ_final,
        :rotating_basis_per_m => rotating_per_m_norms(ws),
        # Stash omega_ref so downstream rotating_basis dynamics steps
        # can convert physical-unit fields ("226 Hz") to dimensionless
        # ratios via _parse_dimless_freq. NaN if manual c0/c_dd path.
        :rotating_basis_omega_ref => auto_path ? Float64(p["omega_ref"]) : NaN,
    )
    # Type assertion: pin to a concrete 4D Complex array (either F32 or F64
    # eltype). Earlier this hard-asserted ComplexF64 to keep downstream
    # inference narrow, but that broke the F32 path. The Complex Union
    # still constrains inference enough to avoid abstract dispatch.
    psi_concrete = ws.psi_tilde::AbstractArray{<:Complex, 4}
    return (psi_concrete, grid, placeholder_atom, nothing, step_result)
end

# Default integrator for RTP: Yoshida6 (order 6).
function _default_rotating_integrator(duration::Float64)::String
    "yoshida6"
end

"""
    _resolve_save_every(p::Dict, duration, dt; n_steps=nothing) -> Int

Resolve `save_every` (frame stride in integrator steps). Priority:

  1. `save_every: 30`     — explicit step count (legacy, exact)
  2. `n_snapshots: 100`   — N frames over the step, dt-invariant (preferred)
  3. default              — ~20-100 frames depending on context

`n_snapshots` is dt-invariant: changing `dt`/`epsilon` keeps the number
of saved frames unchanged, only their granularity changes.
"""
function _resolve_save_every(p::Dict, duration::Float64, dt::Real;
    n_steps::Union{Nothing, Int}=nothing)
    if haskey(p, "save_every")
        return Int(p["save_every"])
    end
    if haskey(p, "n_snapshots")
        ns = Int(p["n_snapshots"])
        ns >= 1 || throw(ArgumentError("n_snapshots must be >= 1, got $ns"))
        total = n_steps !== nothing ? n_steps :
                max(1, round(Int, duration / float(dt)))
        return max(1, total ÷ ns)
    end
    total = n_steps !== nothing ? n_steps :
            max(1, round(Int, duration / float(dt)))
    # 100 frames default for rotating_basis (n_steps known), 20 otherwise.
    return max(1, total ÷ (n_steps === nothing ? 20 : 100))
end

"""
Derive dt from accumulated-error target ε via global error scaling
ε ≈ C · T · dt^p where p is integrator order, C ~ O(1).

Safety factor 0.1 → conservative dt that consistently meets target across
typical Klaus / B-1 problems (verified empirically, prevents under-resolved
DDI / fast-rotation regimes).

Returns: dt = 0.1 · (ε / duration)^(1/p)
"""
function _dt_from_epsilon(epsilon::Float64, duration::Float64, integrator::String)
    p = if integrator == "strang"
        ;
        2
    elseif integrator == "yoshida4" || integrator == "cfet4"
        ;
        4
    elseif integrator == "yoshida6"
        ;
        6
    else
        ;
        2  # fallback
    end
    safety = 0.1
    safety * (epsilon / duration)^(1.0 / p)
end

@noinline function _run_rotating_basis_dynamics_inner(
    p::Dict{String, Any}, grid, pipeline_results::Dict;
    verbose::Bool=true,
)
    haskey(pipeline_results, :rotating_basis_ws) || throw(
        ArgumentError(
            "rotating_basis dynamics requires preceding ground_state with kind: rotating_basis"
        ),
    )
    ws_prev = pipeline_results[:rotating_basis_ws]::RotatingBasisWS

    duration = Float64(p["duration"])
    integrator_name = String(get(p, "integrator", _default_rotating_integrator(duration)))::String

    # dt resolution priority:
    #   1. explicit `dt:` in YAML (override)
    #   2. derive from `epsilon:` (target accumulated error) given integrator order
    #   3. sensible default (0.005)
    dt_rtp = if haskey(p, "dt")
        Float64(p["dt"])
    elseif haskey(p, "epsilon")
        ε = Float64(p["epsilon"])
        _dt_from_epsilon(ε, duration, integrator_name)
    else
        0.005   # legacy default
    end
    n_steps = Int(round(duration / dt_rtp))

    # Larmor / Â regime guard: the Y6 ε-formula coefficient (0.1) assumes
    # commutator scales of O(1). For Klaus regime where p × F or
    # |Â| × |H_DDI| scale 10³–10⁵, ε=1e-3 is empirically too coarse and
    # produces non-physical depolarisation (audit 2026-04-28: p_3000
    # ε=1e-3 → 0.997→0.106 thermal scrambling; ε=1e-6 → 0.997→0.999
    # frozen). Warn when the per-step Larmor phase advance exceeds π —
    # the regime where the spin step's exp(-i p F_z dt) wraps inside one
    # solver step and Y6 commutator-error coefficients break the ε scaling.
    # This is a *predictive* check, not enforcing; user can pass an
    # explicit `dt:` to override.
    p_zeeman_abs = abs(ws_prev.p)
    F_atom_int = ws_prev.spin_matrices.system.F
    larmor_phase = p_zeeman_abs * F_atom_int * dt_rtp
    if verbose && larmor_phase > π && !haskey(p, "dt")
        @warn "rotating_basis: Larmor phase advance per step (p·F·dt = " *
            "$(round(larmor_phase; sigdigits=4))) > π. Y6 ε-formula " *
            "may underestimate dt for Klaus-regime p·F·dt ≫ 1; see " *
            "audit 2026-04-28 (p_3000 ε=1e-3 false convergence). " *
            "Consider tightening to ε ≤ 1e-6, or supplying an explicit " *
            "dt < $(round(π / (p_zeeman_abs * F_atom_int); sigdigits=3))."
    end
    save_every = _resolve_save_every(p, duration, dt_rtp; n_steps=n_steps)

    B_hat_node = get(p, "B_hat", Dict{String, Any}())::Dict

    # Build θ(t) waveform: either constant or linear ramp. Save scalar
    # representatives (θ_repr, φ_omega_repr) for downstream Berry-connection
    # diagnostic + dyn_dict storage; for ramp/chirp we use the END value
    # (most-relevant for the steady-state portion of the step).
    theta_func, theta_dot_func, θ_repr = if haskey(B_hat_node, "theta_ramp")
        rn = B_hat_node["theta_ramp"]::Dict
        θ0 = Float64(rn["from"]);
        θ1 = Float64(rn["to"])
        T_ramp = Float64(rn["duration"])
        rate = (θ1 - θ0) / T_ramp
        (_LinearRamp(θ0, θ1, T_ramp), _LinearRampDot(rate, T_ramp), θ1)
    else
        θc = Float64(get(B_hat_node, "theta_const",
            Float64(get(B_hat_node, "theta", 0.0))))
        (_ConstAngle(θc), _ZERO_FUNC, θc)
    end

    # Hz-aware parsing of phi_omega / phi_chirp endpoints: a string like
    # "226 Hz" gets converted to dimensionless ω/ω_ref via the omega_ref
    # stashed by _run_rotating_basis_ground_state_step. Real values
    # pass through unchanged (existing dimensionless convention).
    ω_ref_dimless = get(pipeline_results, :rotating_basis_omega_ref, NaN)::Float64
    _ω(node) = isnan(ω_ref_dimless) ? Float64(node) :
               _parse_dimless_freq(node, ω_ref_dimless)

    phi_func, phi_dot_func, φ_omega_repr = if haskey(B_hat_node, "phi_chirp")
        cn = B_hat_node["phi_chirp"]::Dict
        ω0 = _ω(cn["from"]);
        ω1 = _ω(cn["to"])
        T_chirp = Float64(cn["duration"])
        (_LinearChirpPhi(ω0, ω1, T_chirp), _LinearChirpPhiDot(ω0, ω1, T_chirp), ω1)
    else
        ω = _ω(get(B_hat_node, "phi_omega", 0.0))
        (_LinearPhi(ω), _ConstAngle(ω), ω)
    end

    # Build a NEW workspace re-using the same physics couplings + state, but
    # with the time-dep B̂(t) hooked up.
    F_atom = ws_prev.spin_matrices.system.F
    V_trap = ws_prev.V_trap
    ws = make_rotating_basis_ws(grid, F_atom, V_trap;
        p=ws_prev.p, q=ws_prev.q,
        c0=ws_prev.c0, c1=ws_prev.c1,
        c_dd=ws_prev.ddi_params.C_dd, gamma_lhy=ws_prev.gamma_lhy,
        theta_func=theta_func, phi_func=phi_func,
        theta_dot_func=theta_dot_func, phi_dot_func=phi_dot_func,
        gauge_fix=ws_prev.gauge_fix,
        backend=ws_prev.backend,                  # inherit device from GS
    )
    copyto!(ws.psi_tilde, ws_prev.psi_tilde)

    times_arr = Float64[]
    norms_arr = Float64[]
    Lz_arr = Float64[]
    per_m_arr = Vector{Vector{Float64}}()
    Fz_arr = Float64[]                   # ⟨F_z⟩(t) for EdH conservation
    Fx_arr = Float64[];
    Fy_arr = Float64[]
    # ψ̃ snapshots: optional, controlled by save_psi_snapshots flag.
    # Enables per-m density (Fig 4), spin texture (Fig 3) — heavy memory but
    # only every save_every step, so 200ms × dt=0.005 / save_every=50 = 80 frames.
    save_psi = Bool(get(p, "save_psi_snapshots", true))::Bool
    psi_snapshots = Vector{Array{ComplexF64, 4}}()

    if verbose
        dt_source =
            haskey(p, "dt") ? "explicit" :
            (haskey(p, "epsilon") ? "ε=$(p["epsilon"])" : "default")
        println("  rotating_basis dynamics: ", n_steps, " steps × dt=", round(dt_rtp; sigdigits=3),
            " ($dt_source, integrator=", integrator_name,
            ", θ_repr=", round(θ_repr; digits=3),
            ", φ_omega_repr=", round(φ_omega_repr; digits=3),
            ", save_psi=", save_psi, ")")
    end

    # Integrator dispatch
    evolve_fn = if integrator_name == "strang"
        evolve_rotating!
    elseif integrator_name == "yoshida4"
        evolve_rotating_yoshida4!
    elseif integrator_name == "yoshida6"
        evolve_rotating_yoshida6!
    elseif integrator_name == "cfet4"
        evolve_rotating_cfet4_real!   # experimental, not order-4 in current form
    else
        throw(
            ArgumentError(
                "Unknown integrator '$integrator_name'. Use: strang, yoshida4, yoshida6, cfet4"
            ),
        )
    end

    evolve_fn(ws, n_steps, dt_rtp; t0=0.0,
        on_step=(step, t, w) -> begin
            if step == 1 || step % save_every == 0
                push!(times_arr, t)
                push!(norms_arr, rotating_norm(w))
                if length(grid.config.n_points) == 3
                    push!(Lz_arr, rotating_Lz(w))
                end
                pm = rotating_per_m_norms(w)
                push!(per_m_arr, pm)
                # ⟨F_z⟩ = Σ_m m·N_m (m runs F, F-1, ..., -F as idx 1..D)
                F_val = w.spin_matrices.system.F
                fz_sum = 0.0
                for m_idx in 1:length(pm)
                    fz_sum += (F_val - (m_idx - 1)) * pm[m_idx]
                end
                push!(Fz_arr, fz_sum)
                # ⟨F_x⟩, ⟨F_y⟩ from spinor-resolved current density (defer for now;
                # placeholder zeros — implemented in next analyzer iteration if
                # needed for spin texture animation. Total magnetization
                # in lab frame can be derived via Û_B(t) rotation in post.)
                push!(Fx_arr, 0.0);
                push!(Fy_arr, 0.0)
                if save_psi
                    snap = Array{ComplexF64, 4}(undef, size(w.psi_tilde)...)
                    copyto!(snap, w.psi_tilde)
                    push!(psi_snapshots, snap)
                end
            end
        end,
    )

    placeholder_atom = AtomSpecies("RotatingBasis", 1.66e-25, F_atom, 0.0, 0.0, 0.0)
    dyn_dict = Dict{Symbol, Any}(
        :times => times_arr,
        :norms => norms_arr,
        :Lz => Lz_arr,
        :Fz => Fz_arr,
        :Fx => Fx_arr,
        :Fy => Fy_arr,
        :per_m_history => per_m_arr,
        :theta_const => θ_repr,
        :phi_omega => φ_omega_repr,
        # Integrator metadata for postmortem analysis: lets a future audit
        # check whether a run was in the Larmor-stiff regime
        # (`p · F · dt > π`) without re-loading the YAML config.
        :dt_used => dt_rtp,
        :integrator => integrator_name,
        :epsilon_target => Float64(get(p, "epsilon", NaN)),
        :p_zeeman => ws_prev.p,
        :F_atom => F_atom_int,
        :larmor_phase_per_step => abs(ws_prev.p) * F_atom_int * dt_rtp,
    )
    if !isempty(psi_snapshots)
        dyn_dict[:psi_snapshots] = psi_snapshots
    end
    step_result = Dict{Symbol, Any}(
        :rotating_basis_ws => ws,
        :rotating_basis_F => F_atom,
        :rotating_basis_per_m_final => rotating_per_m_norms(ws),
        :rotating_basis_dynamics => dyn_dict,
    )
    # See note in _run_rotating_basis_ground_state_step: ws stashed in Dict only,
    # psi_tilde concrete-typed (Complex eltype, supports both F32 and F64).
    psi_concrete = ws.psi_tilde::AbstractArray{<:Complex, 4}
    return (psi_concrete, grid, placeholder_atom, nothing, step_result)
end

@noinline function _run_step(
    step::RotatingBasisGroundStateStep,
    psi_prev, grid_prev, atom_prev, ws_prev;
    verbose=true, checkpoint_dir=nothing,
)
    return _run_rotating_basis_ground_state_step(step.params; verbose=verbose)
end

@noinline function _run_step(
    step::RotatingBasisDynamicsStep,
    psi_prev, grid, atom, ws_prev;
    verbose=true, checkpoint_dir=nothing,
    pipeline_results::Union{Nothing, Dict}=nothing,
)
    grid !== nothing || throw(
        ArgumentError(
            "rotating_basis dynamics step requires grid from preceding ground_state step"),
    )
    pipeline_results !== nothing || throw(ArgumentError(
        "rotating_basis dynamics step requires preceding ground_state results"))
    return _run_rotating_basis_dynamics_inner(step.params, grid, pipeline_results;
        verbose=verbose)
end

@noinline function _run_binary_dynamics_inner(
    p::Dict{String, Any},
    grid,
    pipeline_results::Dict;
    verbose::Bool=true,
)
    haskey(pipeline_results, :binary_state) || throw(
        ArgumentError(
            "binary dynamics requires a preceding `ground_state` step with `kind: binary`"),
    )
    state = pipeline_results[:binary_state]::BinaryState
    base_couplings = pipeline_results[:binary_couplings]::BinaryCouplings

    duration = Float64(p["duration"])
    dt = Float64(p["dt"])
    save_every = Int(get(p, "save_every", max(1, round(Int, duration / dt / 20))))

    couplings = if haskey(p, "couplings")
        c_node = p["couplings"]::Dict
        BinaryCouplings(;
            g_AA=Float64(get(c_node, "g_AA", base_couplings.g_AA)),
            g_BB=Float64(get(c_node, "g_BB", base_couplings.g_BB)),
            g_AB=Float64(get(c_node, "g_AB", base_couplings.g_AB)),
            omega_coupling=Float64(get(c_node, "omega_coupling",
                    base_couplings.omega_coupling)),
            delta_coupling=Float64(get(c_node, "delta_coupling",
                    base_couplings.delta_coupling)),
        )
    else
        base_couplings
    end

    pot_node = get(p, "potential", nothing)
    potential::AbstractPotential =
        if pot_node isa AbstractDict &&
            get(pot_node, "type", "") == "harmonic"
            ω_vec = Float64.(pot_node["omega"])
            HarmonicTrap(Tuple(ω_vec))
        else
            NoPotential()
        end

    sim = make_binary_simulation(grid;
        couplings=couplings,
        potential_A=potential,
        potential_B=potential,
        psi_A_init=state.psi_A,
        psi_B_init=state.psi_B)

    save_psi = Bool(get(p, "save_psi_snapshots", false))
    times = Float64[]
    psi_A_snaps = Vector{Array{ComplexF64, ndims(sim.psi_A)}}()
    psi_B_snaps = Vector{Array{ComplexF64, ndims(sim.psi_B)}}()
    on_save = save_psi ? function _on(s)
        push!(times, s.t)
        push!(psi_A_snaps, copy(s.psi_A))
        push!(psi_B_snaps, copy(s.psi_B))
        return nothing
    end : nothing
    verbose && println("  binary RTP: duration=$duration dt=$dt save_every=$save_every")
    run_binary_simulation!(sim; duration, dt, save_every, on_save)

    state.psi_A = sim.psi_A
    state.psi_B = sim.psi_B
    state.t = sim.t
    state.step = sim.step

    placeholder_atom = AtomSpecies("Binary", 1.66e-25, 0, 0.0, 0.0, 0.0)
    psi_4d = reshape(state.psi_A, (size(state.psi_A)..., 1))
    bdyn = Dict{Symbol, Any}(
        :duration => duration, :dt => dt,
        :final_t => sim.t, :final_step => sim.step,
        :norms => binary_norms(sim),
        :total_energy => binary_total_energy(sim),
    )
    if save_psi
        bdyn[:times] = times
        bdyn[:psi_A_snapshots] = psi_A_snaps
        bdyn[:psi_B_snapshots] = psi_B_snaps
    end
    step_result = Dict{Symbol, Any}(
        :binary_state => state,
        :binary_couplings => couplings,
        :binary_dynamics => bdyn,
    )
    return (psi_4d, grid, placeholder_atom, nothing, step_result)
end

"""
    _build_sgpe_callback(node, dt) -> Union{Nothing,Function}

Parse a `dynamics.sgpe:` block into an SGPE on-step callback. Accepts:

    sgpe: false | null            # disabled (returns nothing)
    sgpe: {gamma: 0.05, T: 0.1, mu: 0.0, k_cut: 6.0, every: 1, seed: 42}

`gamma` and `T` are required when sgpe is a Dict. `mu` defaults to 0,
`k_cut` to Inf (no projection), `every` to 1, `seed` to nothing (random).
"""
function _build_sgpe_callback(node, dt::Float64)
    node === nothing && return nothing
    node isa Bool && (node || return nothing)
    node isa Dict || throw(ArgumentError(
        "dynamics.sgpe must be a mapping or `false`, got $(typeof(node))"))
    haskey(node, "gamma") || throw(ArgumentError("dynamics.sgpe requires `gamma`"))
    haskey(node, "T") || throw(ArgumentError("dynamics.sgpe requires `T`"))
    γ = Float64(node["gamma"])
    T = Float64(node["T"])
    μ = Float64(get(node, "mu", 0.0))
    k_cut = Float64(get(node, "k_cut", Inf))
    every = Int(get(node, "every", 1))
    seed = let v = get(node, "seed", nothing)
        v === nothing ? nothing : Int(v)
    end
    sgpe_callback(γ, T, dt; μ=μ, k_cut=k_cut, seed=seed, every=every)
end

function _dynamics_scratch_path()
    scratch = get(ENV, "SPINORBEC_SCRATCH_DIR", "")
    base = string(hash((time_ns(), getpid())); base=16)
    dir = isempty(scratch) ? tempdir() : scratch
    isdir(dir) || mkpath(dir)
    joinpath(dir, "spinorbec_snaps_" * base * ".jld2")
end

function _parse_twa_config(d::Dict)
    n_traj = Int(d["n_trajectories"])
    seed_base = Int(get(d, "seed_base", 42))
    cutoff_raw = get(d, "cutoff_energy", nothing)
    cutoff = cutoff_raw === nothing ? nothing : Float64(cutoff_raw)
    obs_raw = get(d, "observables", ["density", "magnetization"])
    observables = Symbol[Symbol(s) for s in obs_raw]
    TWAConfig(n_traj, seed_base, cutoff, observables)
end

function _parse_light_shift(raw, F::Int, V_trap, backend::AbstractBackend)
    raw === nothing && return nothing
    raw isa Dict || return nothing
    if haskey(raw, "eta_tensor")
        eta_t = Float64(raw["eta_tensor"])
        eta_v = Float64(get(raw, "eta_vector", 0.0))
        pol_raw = get(raw, "polarization", [0, 0, 1])
        pol = NTuple{3, Float64}(Tuple(Float64.(pol_raw)))
        V_trap === nothing &&
            throw(ArgumentError("light_shift.eta_tensor requires a trap potential (V_trap)"))
        return make_light_shift_from_trap(
            V_trap, F, eta_t; eta_vector=eta_v, polarization=pol, backend
        )
    end
    alpha_t = Float64(get(raw, "alpha_tensor", 0.0))
    alpha_v = Float64(get(raw, "alpha_vector", 0.0))
    pol_raw = get(raw, "polarization", [0, 0, 1])
    pol = NTuple{3, Float64}(Tuple(Float64.(pol_raw)))
    if haskey(raw, "profile")
        throw(
            ArgumentError(
                "light_shift.profile from YAML not yet supported; use eta_tensor with trap or pass LightShift from Julia"
            ),
        )
    end
    nothing
end

function _run_step(step::AnalyzeStep, psi, grid, atom, ws_prev; verbose=true,
    checkpoint_dir=nothing,
    pipeline_results::Dict{Symbol, Any}=Dict{Symbol, Any}())
    psi !== nothing || throw(ArgumentError("analyze step requires psi from preceding steps"))
    results = Dict{Symbol, Any}()

    for (name, params) in step.analyzers
        verbose && print("  $name... ")
        result = _run_analyzer(name, psi, grid, atom, params;
            ws_prev=ws_prev, pipeline_results=pipeline_results)
        results[name] = result
        verbose && println("done")
    end

    (psi, grid, atom, ws_prev, results)
end
