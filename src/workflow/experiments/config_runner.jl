# --- Unified Config: runner ---

function run_config(config::UnifiedConfig; verbose::Bool = true)
    if config.output.seed !== nothing
        Random.seed!(config.output.seed)
    end
    _run_config(config, config.spec; verbose)
end

"""
    _resolve_backend(name::Symbol) → AbstractBackend

Resolve a YAML backend symbol to a concrete backend object. CUDABackend is
constructed via `Base.invokelatest(Module.eval, ...)` so the runner does not
depend on CUDA at load time. The user must `import CUDA` before calling.
"""
function _resolve_backend(name::Symbol)
    if name == :cpu
        return CPUBackend()
    elseif name == :cuda || name == :gpu
        # CUDABackend struct is always defined in backend.jl, but actual GPU
        # methods come from the SpinorBECCUDAExt extension which only loads
        # when the user has `import CUDA` in their session. The user is
        # responsible for that import; downstream errors will be clear.
        return CUDABackend()
    else
        throw(ArgumentError("Unknown backend: $name (expected :cpu or :cuda)"))
    end
end

"""
    _load_psi_init(path::Union{Nothing,String}) → Union{Nothing,Array}

Load a psi array from a JLD2 file. Tries the keys "psi" then "psi_uniform"
then "psi_fl" before giving up.
"""
function _load_psi_init(path::Union{Nothing,String})
    path === nothing && return nothing
    isfile(path) || throw(ArgumentError("psi_init_path file not found: $path"))
    data = JLD2.load(path)
    for key in ("psi", "psi_uniform", "psi_fl")
        haskey(data, key) && return data[key]
    end
    throw(
        ArgumentError(
            "psi_init_path: $path contains no recognized psi key. " *
            "Expected one of: psi, psi_uniform, psi_fl",
        ),
    )
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
        psi_current = add_thermal_noise(
            psi_current, atom.F;
            T_over_Tc = spec.perturbation.temperature_ratio,
            seed = something(spec.perturbation.seed, 42),
        )
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
    backend = _resolve_backend(gs.backend)
    psi_init = _load_psi_init(gs.psi_init_path)

    # Thermal fluctuation perturbation: build psi from initial_state then
    # overlay Bose-Einstein-distributed noise scaled by T/T_c. Used to seed
    # spontaneous symmetry breaking in ITP (vortex ground states, etc).
    if psi_init === nothing && gs.temperature_ratio !== nothing
        sys_obj = SpinSystem(atom.F)
        psi_base = init_psi(grid, sys_obj; state = gs.initial_state,
                            (k => v for (k, v) in gs.init_state_params)...)
        psi_init = add_thermal_noise(
            psi_base, atom.F;
            T_over_Tc = gs.temperature_ratio,
            seed = something(gs.noise_seed, 42),
        )
    end

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
        init_state_params = gs.init_state_params,
        psi_init = psi_init,
        enable_ddi = gs_enable_ddi,
        c_dd = c_dd_val,
        secular_ddi = sys.ddi.secular,
        quasi_2d_ddi = sys.ddi.quasi_2d,
        l_z_ddi = sys.ddi.l_z,
        target_magnetization = gs.target_magnetization,
        rotating_frame_omega = gs.rotating_frame_omega,
        backend = backend,
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
    phase_results = SimulationResult[]
    phase_names = String[]
    phase_times = Float64[]
    phase_rates = Float64[]
    t_offset = 0.0
    simulation_start = time()

    for (i, phase) in enumerate(spec.sequence)
        if verbose
            print_phase_header(phase.name, phase.duration, phase.dt, round(Int, phase.duration / phase.dt))
        end

        # Apply phase override (if any) to the raw YAML and re-parse, so
        # system/interactions/potential/DDI can switch between phases via
        # the same mechanism as scan points.
        phase_raw = isempty(phase.override) ? config.raw_data :
                    apply_overrides(config.raw_data, phase.override)
        phase_config = isempty(phase.override) ? config : _parse_config(phase_raw)
        sys = phase_config.system
        enable_ddi = sys.ddi.enabled
        c_dd_val = sys.ddi.c_dd === nothing ? NaN : sys.ddi.c_dd
        secular_ddi = sys.ddi.secular
        quasi_2d_ddi = sys.ddi.quasi_2d
        l_z_ddi = sys.ddi.l_z

        # Potential: either the phase override brought in a new one, or the
        # re-parsed phase_config inherits the base. Always rebuild from the
        # re-parsed config so phase-level `potential:` (auto-migrated to
        # override) is honored.
        potential = _build_potential(phase_config.ground_state.potential, ndim)

        # Zeeman: inspect the raw (override-applied) dict directly so that
        # ramp-form values `{from, to}` build a TimeDependentZeeman linear
        # ramp over the phase duration.
        zeeman = _build_phase_zeeman(phase_raw, t_offset, phase.duration)

        n_steps = round(Int, phase.duration / phase.dt)
        sp = SimParams(; dt = phase.dt, n_steps, save_every = phase.save_every)

        # Create progress reporter
        progress = verbose ? ProgressReporter(phase.name, n_steps; print_every=max(1, div(n_steps, 50))) : nothing

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

        if phase.temperature_ratio !== nothing
            psi_noisy = add_thermal_noise(
                ws.state.psi, atom.F;
                T_over_Tc = phase.temperature_ratio,
                seed = something(phase.noise_seed, 42),
            )
            ws.state.psi .= psi_noisy
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
            phase_start_time = time()
            E_initial = total_energy(ws)

            # Callback for progress reporting
            callback = progress !== nothing ? (ws_cb, step) -> print_progress(progress, ws_cb, step) : nothing
            result = run_simulation!(ws; callback)

            if verbose
                phase_elapsed = time() - phase_start_time
                step_rate = n_steps / phase_elapsed
                print_phase_summary(phase.name, phase_elapsed, E_initial, result.energies[end], step_rate)
                push!(phase_times, phase_elapsed)
                push!(phase_rates, step_rate)
            end

            result
        end

        psi_current = copy(ws.state.psi)
        t_offset += phase.duration

        push!(phase_results, sim_result)
        push!(phase_names, phase.name)
    end

    if verbose && !isempty(phase_times)
        total_time = time() - simulation_start
        print_simulation_summary(total_time, phase_names, phase_times, phase_rates)
    end

    (phase_results, phase_names)
end
