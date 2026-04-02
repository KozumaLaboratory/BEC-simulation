# --- Unified Config v3: runner ---

function run_config(config::UnifiedConfig; verbose::Bool = true)
    if config.output.seed !== nothing
        Random.seed!(config.output.seed)
    end
    _run_config(config, config.spec; verbose)
end

# --- Ground state only ---

function _run_config(config::UnifiedConfig, ::GroundStateExperiment; verbose::Bool = true)
    grid, atom, ndim = _setup_grid(config)
    potential = _build_potential(config.ground_state.potential, ndim)

    verbose && println(
        "Ground state ($(config.ground_state.n_steps) steps, tol=$(config.ground_state.tol))...",
    )

    result = _run_ground_state(config, grid, atom, potential, ndim)

    verbose && println("  converged=$(result.converged), E=$(result.energy)")

    (
        ground_state_energy = result.energy,
        ground_state_converged = result.converged,
        psi = copy(result.workspace.state.psi),
        workspace = result.workspace,
    )
end

# --- Dynamics ---

function _run_config(config::UnifiedConfig, spec::DynamicsExperiment; verbose::Bool = true)
    grid, atom, ndim = _setup_grid(config)
    potential = _build_potential(config.ground_state.potential, ndim)

    verbose && println("Ground state ($(config.ground_state.n_steps) steps)...")

    gs_result = _run_ground_state(config, grid, atom, potential, ndim)

    verbose && println("  converged=$(gs_result.converged), E=$(gs_result.energy)")

    psi_current = copy(gs_result.workspace.state.psi)

    if spec.perturbation !== nothing
        if spec.perturbation.seed !== nothing
            Random.seed!(spec.perturbation.seed)
        end
        n_components = 2 * atom.F + 1
        _add_noise!(psi_current, spec.perturbation.amplitude, n_components, ndim, grid)
    end

    phase_results, phase_names =
        _run_dynamics_sequence(config, spec, grid, atom, ndim, psi_current; verbose)

    (
        ground_state_energy = gs_result.energy,
        ground_state_converged = gs_result.converged,
        phase_results = phase_results,
        phase_names = phase_names,
    )
end

# --- Phase scan ---

function _run_config(config::UnifiedConfig, spec::ScanExperiment; verbose::Bool = true)
    sys = config.system
    atom = resolve_atom(sys.atom_name)
    ndim = length(sys.grid_n_points)
    grid_cfg = GridConfig(
        NTuple{ndim,Int}(sys.grid_n_points),
        NTuple{ndim,Float64}(sys.grid_box_size),
    )
    grid = make_grid(grid_cfg)
    sm = spin_matrices(atom.F)
    potential = _build_potential(config.ground_state.potential, ndim)

    verbose && println("Phase scan: $(config.name)")

    if config.output.csv
        mkpath(config.output.dir)
    end

    _run_scan(config, grid, atom, sm, potential, ndim; verbose)
end

# --- Shared helpers ---

function _setup_grid(config::UnifiedConfig)
    sys = config.system
    atom = resolve_atom(sys.atom_name)
    ndim = length(sys.grid_n_points)
    grid_cfg = GridConfig(
        NTuple{ndim,Int}(sys.grid_n_points),
        NTuple{ndim,Float64}(sys.grid_box_size),
    )
    grid = make_grid(grid_cfg)
    (grid, atom, ndim)
end

function _run_ground_state(config::UnifiedConfig, grid, atom, potential, ndim)
    gs = config.ground_state
    sys = config.system
    c_dd_val = sys.ddi.c_dd === nothing ? NaN : sys.ddi.c_dd
    gs_enable_ddi = something(gs.enable_ddi, sys.ddi.enabled)

    find_ground_state(;
        grid,
        atom,
        interactions = sys.interactions,
        zeeman = gs.zeeman,
        potential,
        dt = gs.dt,
        n_steps = gs.n_steps,
        tol = gs.tol,
        initial_state = gs.initial_state,
        enable_ddi = gs_enable_ddi,
        c_dd = c_dd_val,
        secular_ddi = sys.ddi.secular,
        quasi_2d_ddi = sys.ddi.quasi_2d,
        l_z_ddi = sys.ddi.l_z,
        target_magnetization = gs.target_magnetization,
        rotating_frame_omega = gs.rotating_frame_omega,
    )
end

function _run_dynamics_sequence(
    config::UnifiedConfig,
    spec::DynamicsExperiment,
    grid,
    atom,
    ndim,
    psi_current;
    verbose::Bool = true,
)
    sys = config.system
    enable_ddi = sys.ddi.enabled
    c_dd_val = sys.ddi.c_dd === nothing ? NaN : sys.ddi.c_dd
    secular_ddi = sys.ddi.secular
    quasi_2d_ddi = sys.ddi.quasi_2d
    l_z_ddi = sys.ddi.l_z

    phase_results = SimulationResult[]
    phase_names = String[]
    t_offset = 0.0
    prev_potential_config = config.ground_state.potential

    for (i, phase) in enumerate(spec.sequence)
        verbose &&
            println("Phase $i: $(phase.name) (duration=$(phase.duration), dt=$(phase.dt))")

        pot_cfg = phase.potential !== nothing ? phase.potential : prev_potential_config
        potential = _build_potential(pot_cfg, ndim)
        prev_potential_config = pot_cfg

        zeeman = _build_zeeman(phase, t_offset)

        n_steps = round(Int, phase.duration / phase.dt)
        sp = SimParams(; dt = phase.dt, n_steps, save_every = phase.save_every)

        ws = make_workspace(;
            grid,
            atom,
            interactions = sys.interactions,
            zeeman,
            potential,
            sim_params = sp,
            psi_init = psi_current,
            enable_ddi,
            c_dd = c_dd_val,
            secular_ddi,
            loss = sys.loss,
            quasi_2d_ddi,
            l_z_ddi,
        )
        ws.state.t = t_offset

        if phase.noise_amplitude !== nothing && phase.noise_amplitude > 0
            _add_noise!(ws.state.psi, phase.noise_amplitude, 2 * atom.F + 1, ndim, grid)
        end

        sim_result = if phase.integrator.method == :adaptive
            save_interval = phase.dt * phase.save_every
            out = run_simulation_adaptive!(
                ws;
                adaptive = phase.integrator.params,
                t_end = t_offset + phase.duration,
                save_interval,
            )
            verbose && println(
                "  adaptive: $(out.n_accepted) accepted, $(out.n_rejected) rejected",
            )
            out.result
        elseif phase.integrator.method == :yoshida
            params = something(phase.integrator.params, AdaptiveDtParams(; dt_init = phase.dt))
            save_interval = phase.dt * phase.save_every
            out = run_simulation_yoshida!(
                ws;
                adaptive = params,
                t_end = t_offset + phase.duration,
                save_interval,
            )
            verbose && println(
                "  yoshida: $(out.n_accepted) accepted, $(out.n_rejected) rejected",
            )
            out.result
        else
            run_simulation!(ws)
        end

        psi_current = copy(ws.state.psi)
        t_offset += phase.duration

        push!(phase_results, sim_result)
        push!(phase_names, phase.name)

        verbose && println("  final t=$(ws.state.t), E=$(sim_result.energies[end])")
    end

    (phase_results, phase_names)
end
