# --- Pipeline parser & runner ---

function parse_pipeline(data::Dict)
    pipe_data = data["pipeline"]
    (pipe_data isa AbstractVector && !isempty(pipe_data)) ||
        throw(ArgumentError("pipeline: must be a non-empty list of steps"))
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

function _parse_step(d::Dict)
    keys_list = collect(keys(d))
    length(keys_list) == 1 || throw(ArgumentError(
        "Each pipeline step must have exactly one key, got: $keys_list"))
    key = Symbol(keys_list[1])
    val = d[keys_list[1]]

    if key == :ground_state
        GroundStateStep(Dict{String,Any}(string(k) => v for (k, v) in val))
    elseif key == :dynamics
        DynamicsStep(Dict{String,Any}(string(k) => v for (k, v) in val))
    elseif key == :analyze
        analyzers = Pair{Symbol,Dict{String,Any}}[]
        for entry in val
            if entry isa Dict
                for (ak, av) in entry
                    params = av isa Dict ? Dict{String,Any}(string(k) => v for (k, v) in av) : Dict{String,Any}()
                    push!(analyzers, Symbol(ak) => params)
                end
            end
        end
        AnalyzeStep(analyzers)
    else
        throw(ArgumentError("Unknown pipeline step: $key. Supported: ground_state, dynamics, analyze"))
    end
end

"""
    run_pipeline(config::PipelineConfig; verbose=true) -> NamedTuple

Execute a pipeline sequentially. Each step receives the current psi
and produces a new one. Analysis steps don't modify psi but accumulate
results.
"""
function run_pipeline(config::PipelineConfig; verbose::Bool = true, psi_init = nothing,
                      checkpoint_dir::Union{Nothing,String} = nothing)
    psi = psi_init
    grid = nothing
    atom = nothing
    workspace = nothing
    results = Dict{Symbol,Any}()

    for (i, step) in enumerate(config.steps)
        verbose && println("Step $i/$(length(config.steps)): $(nameof(typeof(step)))")
        psi, grid, atom, workspace, step_result = _run_step(step, psi, grid, atom, workspace; verbose, checkpoint_dir)
        if step_result !== nothing
            merge!(results, step_result)
        end
    end

    (psi = psi, grid = grid, atom = atom, results...)
end

# --- Step dispatch ---

function _run_step(step::GroundStateStep, psi_prev, grid_prev, atom_prev, ws_prev; verbose=true, checkpoint_dir=nothing)
    p = step.params
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
        _parse_gs_interactions(Dict{String,Any}(), atom)
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
        _parse_zeeman(p["zeeman"], duration)
    elseif ws_prev !== nothing
        ws_prev.zeeman
    else
        _parse_zeeman(Dict(), duration)
    end

    # --- Cache: skip ITP/LBFGS if file exists, but build a workspace so
    #     downstream analyzers (e.g. bogoliubov) can inspect the system ---
    cache_path = get(p, "cache", nothing)
    if cache_path !== nothing && isfile(cache_path)
        verbose && println("  Loading cached GS from $cache_path")
        d = JLD2.load(cache_path)
        psi_out = d["psi"]
        energy = get(d, "energy", NaN)
        converged = get(d, "converged", true)
        ws_cached = make_workspace(;
            grid, atom, interactions, zeeman, potential,
            sim_params = SimParams(; dt, n_steps = 1, save_every = 1),
            psi_init = psi_out,
            enable_ddi, c_dd = c_dd_val,
            secular_ddi = secular, quasi_2d_ddi = q2d, l_z_ddi = lz,
            backend,
        )
        step_result = Dict{Symbol,Any}(
            :ground_state_energy => energy,
            :ground_state_converged => converged,
            :workspace => ws_cached,
        )
        return (psi_out, grid, atom, ws_cached, step_result)
    end
    initial_state = Symbol(get(p, "initial_state", "polar"))
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
            throw(ArgumentError(
                "psi_init size $(size(psi_init)) does not match grid+atom: expected $expected. " *
                "Grid or atom changed between continuation points? Delete stale cached results and re-run."))
        end
    end
    if psi_init === nothing && temp_ratio !== nothing
        psi_base = init_psi(grid, SpinSystem(atom.F); state = initial_state)
        psi_init = add_thermal_noise(psi_base, atom.F;
            T_over_Tc = temp_ratio, seed = Int(get(p, "noise_seed", 42)))
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
            push!(ramp_callbacks, (ws, step, ns) -> begin
                ws.ddi === nothing && return
                if step % save_every_local == 0
                    E_now = total_energy(ws)
                    dE = isnan(E_prev_ramp[]) ? Inf : abs(E_now - E_prev_ramp[])
                    E_prev_ramp[] = E_now
                    if dE < dE_threshold && c_dd_current[] < c_dd_target
                        c_dd_current[] = min(c_dd_current[] + c_dd_step, c_dd_target)
                        ws.ddi.C_dd = c_dd_current[]
                        println("    c_dd → $(round(c_dd_current[]; digits=1)) (dE=$(round(dE; sigdigits=3)))")
                        flush(stdout)
                        E_prev_ramp[] = NaN  # reset after jump
                    end
                end
            end)
            c_dd_val = c_dd_from
        else
            c_dd_interp = _make_interpolator(c_dd_spec)
            push!(ramp_callbacks, (ws, step, ns) -> begin
                ws.ddi !== nothing && (ws.ddi.C_dd = c_dd_interp(step / ns))
            end)
            c_dd_val = c_dd_interp(0.0)
        end
    end

    on_step = isempty(ramp_callbacks) ? nothing :
        (ws, step, ns) -> for cb in ramp_callbacks; cb(ws, step, ns); end

    gs = if method === :itp
        find_ground_state(;
            grid, atom, interactions, zeeman, potential,
            dt, n_steps, tol, initial_state, psi_init,
            enable_ddi, c_dd = c_dd_val,
            secular_ddi = secular, quasi_2d_ddi = q2d, l_z_ddi = lz,
            target_magnetization = target_mz, backend, on_step,
            checkpoint_dir = checkpoint_dir,
            checkpoint_every = checkpoint_dir !== nothing ? max(1, n_steps ÷ 10) : 0,
        )
    elseif method === :lbfgs
        m_lbfgs = Int(get(p, "m_lbfgs", 10))
        # Reuse existing workspace when available to preserve DDI flags (secular/q2d/l_z)
        if ws_prev !== nothing && !haskey(p, "interactions") && !haskey(p, "ddi") &&
           !haskey(p, "potential") && !haskey(p, "zeeman")
            find_ground_state_lbfgs(;
                ws_init = ws_prev, psi_init,
                n_steps, tol, m_lbfgs,
                target_magnetization = target_mz,
                verbose,
            )
        else
            find_ground_state_lbfgs(;
                grid, atom, interactions, zeeman, potential,
                n_steps, tol, m_lbfgs, initial_state, psi_init,
                enable_ddi, c_dd = c_dd_val,
                secular_ddi = secular, quasi_2d_ddi = q2d, l_z_ddi = lz,
                target_magnetization = target_mz, backend,
                verbose,
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
            mv(tmp, cache_path; force = true)
            verbose && println("  Cached GS to $cache_path")
        catch err
            isfile(tmp) && rm(tmp; force = true)
            @warn "Failed to save GS cache: $err"
        end
    end

    step_result = Dict{Symbol,Any}(
        :ground_state_energy => gs.energy,
        :ground_state_converged => gs.converged,
        :workspace => gs.workspace,
    )
    (psi_out, grid, atom, gs.workspace, step_result)
end

function _run_step(step::DynamicsStep, psi_prev, grid, atom, ws_prev; verbose=true, checkpoint_dir=nothing)
    psi_prev !== nothing || throw(ArgumentError("dynamics step requires a preceding ground_state step"))
    grid !== nothing || throw(ArgumentError("dynamics step requires grid from preceding step"))
    p = step.params
    ndim = length(grid.config.n_points)
    F = atom.F

    duration = Float64(p["duration"])
    dt = Float64(p["dt"])
    save_every = Int(get(p, "save_every", max(1, round(Int, duration / dt / 20))))

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

    zeeman_wrapper = Dict{String,Any}("ground_state" => Dict{String,Any}("zeeman" => get(p, "zeeman", Dict())))
    zeeman = _build_phase_zeeman(zeeman_wrapper, 0.0, duration)

    pot_d = get(p, "potential", nothing)
    potential = pot_d !== nothing ? _parse_and_build_potential(pot_d, ndim) : prev_potential

    temp_ratio = let v = get(p, "temperature_ratio", nothing)
        v === nothing ? nothing : Float64(v)
    end

    n_steps = round(Int, duration / dt)
    sp = SimParams(; dt, n_steps, save_every)

    inter = get(p, "interactions", nothing)
    interactions = inter !== nothing ? _parse_gs_interactions(inter, atom) : prev_interactions

    ws = make_workspace(;
        grid, atom, interactions,
        zeeman, potential,
        sim_params = sp,
        psi_init = psi_prev,
        enable_ddi, c_dd = c_dd_val,
    )

    if temp_ratio !== nothing
        psi_noisy = add_thermal_noise(ws.state.psi, F; T_over_Tc = temp_ratio, seed = Int(get(p, "noise_seed", 42)))
        ws.state.psi .= psi_noisy
    end

    result = run_simulation!(ws)

    verbose && println("  $(n_steps) steps, E_final=$(round(result.energies[end]; sigdigits=6))")

    psi_out = copy(ws.state.psi)
    step_result = Dict{Symbol,Any}(
        :dynamics_result => result,
        :dynamics_workspace => ws,
    )
    (psi_out, grid, atom, ws, step_result)
end

function _run_step(step::AnalyzeStep, psi, grid, atom, ws_prev; verbose=true, checkpoint_dir=nothing)
    psi !== nothing || throw(ArgumentError("analyze step requires psi from preceding steps"))
    results = Dict{Symbol,Any}()

    for (name, params) in step.analyzers
        verbose && print("  $name... ")
        result = _run_analyzer(name, psi, grid, atom, params; ws_prev = ws_prev)
        results[name] = result
        verbose && println("done")
    end

    (psi, grid, atom, ws_prev, results)
end
