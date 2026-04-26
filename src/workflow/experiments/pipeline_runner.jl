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
        params = Dict{String, Any}(string(k) => v for (k, v) in val)
        kind = get(params, "kind", nothing)
        if kind == "binary" || kind == :binary
            BinaryGroundStateStep(params)
        else
            GroundStateStep(params)
        end
    elseif key == :dynamics
        params = Dict{String, Any}(string(k) => v for (k, v) in val)
        kind = get(params, "kind", nothing)
        if kind == "binary" || kind == :binary
            BinaryDynamicsStep(params)
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
    elseif step isa DynamicsStep
        _run_step(step, psi, grid, atom, workspace;
            verbose, checkpoint_dir, live_status_path)
    else
        _run_step(step, psi, grid, atom, workspace; verbose, checkpoint_dir)
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
    sp = SimParams(; dt, n_steps, save_every)

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
