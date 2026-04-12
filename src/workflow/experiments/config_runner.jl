# --- Config runner (backward-compat wrapper) ---
#
# run_config(config::UnifiedConfig) delegates to the old typed dispatch
# for backward compatibility with tests. New code should use
# parse_pipeline + run_pipeline directly.

function run_config(config::UnifiedConfig; verbose::Bool = true)
    if config.output.seed !== nothing
        Random.seed!(config.output.seed)
    end
    _run_config(config, config.spec; verbose)
end

run_config(config::PipelineConfig; verbose::Bool = true) =
    run_pipeline(config; verbose)

# --- Ground state only ---

function _run_config(config::UnifiedConfig, ::GroundStateExperiment; verbose::Bool = true)
    grid, atom, ndim = _setup_grid(config)
    potential = _build_potential(config.ground_state.potential, ndim)

    verbose && println("Ground state ($(config.ground_state.n_steps) steps)...")

    result = _run_ground_state(config, grid, atom, potential, ndim)

    verbose && println("  converged=$(result.converged), E=$(result.energy)")

    psi = copy(result.workspace.state.psi)
    tomo = config.tomography !== nothing ?
        _maybe_run_tomography(config, psi, grid, atom; verbose) : nothing
    faraday_r = config.faraday !== nothing ?
        _maybe_run_faraday(config, psi, grid, atom; verbose) : nothing

    (
        ground_state_energy = result.energy,
        ground_state_converged = result.converged,
        psi = psi,
        workspace = result.workspace,
        tomography = tomo,
        faraday = faraday_r,
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

# --- Scan ---

function _run_config(config::UnifiedConfig, spec::ScanExperiment; verbose::Bool = true)
    sys = config.system
    atom = resolve_atom(sys.atom_name)
    ndim = length(sys.grid_n_points)
    grid = make_grid(GridConfig(NTuple{ndim,Int}(sys.grid_n_points), NTuple{ndim,Float64}(sys.grid_box_size)))
    sm = spin_matrices(atom.F)
    potential = _build_potential(config.ground_state.potential, ndim)

    verbose && println("Scan: $(config.name)")
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
    grid = make_grid(GridConfig(NTuple{ndim,Int}(sys.grid_n_points), NTuple{ndim,Float64}(sys.grid_box_size)))
    (grid, atom, ndim)
end

function _resolve_backend(name::Symbol)
    name == :cpu && return CPUBackend()
    name in (:cuda, :gpu) && return CUDABackend()
    throw(ArgumentError("Unknown backend: $name"))
end

function _load_psi_init(path::Union{Nothing,String})
    path === nothing && return nothing
    isfile(path) || throw(ArgumentError("psi_init_path not found: $path"))
    data = JLD2.load(path)
    for key in ("psi", "psi_uniform", "psi_fl")
        haskey(data, key) && return data[key]
    end
    throw(ArgumentError("No psi key found in $path"))
end

function _run_ground_state(config::UnifiedConfig, grid, atom, potential, ndim)
    gs = config.ground_state
    sys = config.system
    c_dd_val = sys.ddi.c_dd === nothing ? NaN : sys.ddi.c_dd
    backend = _resolve_backend(gs.backend)
    psi_init = _load_psi_init(gs.psi_init_path)

    if psi_init === nothing && gs.temperature_ratio !== nothing
        sys_obj = SpinSystem(atom.F)
        psi_base = init_psi(grid, sys_obj; state = gs.initial_state,
                            (k => v for (k, v) in gs.init_state_params)...)
        psi_init = add_thermal_noise(psi_base, atom.F;
            T_over_Tc = gs.temperature_ratio,
            seed = something(gs.noise_seed, 42))
    end

    find_ground_state(;
        grid, atom,
        interactions = sys.interactions,
        zeeman = gs.zeeman,
        potential,
        dt = gs.dt, n_steps = gs.n_steps, tol = gs.tol,
        initial_state = gs.initial_state,
        init_state_params = gs.init_state_params,
        psi_init,
        enable_ddi = something(gs.enable_ddi, sys.ddi.enabled),
        c_dd = c_dd_val,
        secular_ddi = sys.ddi.secular,
        quasi_2d_ddi = sys.ddi.quasi_2d,
        l_z_ddi = sys.ddi.l_z,
        target_magnetization = gs.target_magnetization,
        rotating_frame_omega = gs.rotating_frame_omega,
        backend,
    )
end

function _run_dynamics_sequence(config, spec, grid, atom, ndim, psi_current; verbose=true)
    phase_results = SimulationResult[]
    phase_names = String[]
    t_offset = 0.0

    for phase in spec.sequence
        verbose && println("  Phase: $(phase.name) ($(phase.duration) ω⁻¹)")

        phase_raw = isempty(phase.override) ? config.raw_data :
                    apply_overrides(config.raw_data, phase.override)
        phase_config = isempty(phase.override) ? config : _parse_config(phase_raw)
        sys = phase_config.system

        potential = _build_potential(phase_config.ground_state.potential, ndim)
        zeeman = _build_phase_zeeman(phase_raw, t_offset, phase.duration)

        n_steps = round(Int, phase.duration / phase.dt)
        sp = SimParams(; dt = phase.dt, n_steps, save_every = phase.save_every)

        ws = make_workspace(;
            grid, atom,
            interactions = sys.interactions,
            zeeman, potential,
            sim_params = sp,
            psi_init = psi_current,
            enable_ddi = sys.ddi.enabled,
            c_dd = something(sys.ddi.c_dd, NaN),
            secular_ddi = sys.ddi.secular,
            loss = sys.loss,
            quasi_2d_ddi = sys.ddi.quasi_2d,
            l_z_ddi = sys.ddi.l_z,
        )
        ws.state.t = t_offset

        if phase.temperature_ratio !== nothing
            psi_noisy = add_thermal_noise(ws.state.psi, atom.F;
                T_over_Tc = phase.temperature_ratio,
                seed = something(phase.noise_seed, 42))
            ws.state.psi .= psi_noisy
        end

        result = if phase.integrator.method == :adaptive
            out = run_simulation_adaptive!(ws;
                adaptive = phase.integrator.params,
                t_end = t_offset + phase.duration,
                save_interval = phase.dt * phase.save_every)
            out.result
        elseif phase.integrator.method == :yoshida
            params = something(phase.integrator.params, AdaptiveDtParams(; dt_init = phase.dt))
            out = run_simulation_yoshida!(ws;
                adaptive = params,
                t_end = t_offset + phase.duration,
                save_interval = phase.dt * phase.save_every)
            out.result
        else
            run_simulation!(ws)
        end

        psi_current = copy(ws.state.psi)
        t_offset += phase.duration
        push!(phase_results, result)
        push!(phase_names, phase.name)
    end

    (phase_results, phase_names)
end

function _maybe_run_tomography(config, psi, grid, atom; verbose=true)
    td = config.tomography
    td === nothing && return nothing
    F = atom.F
    verbose && println("Running tomography...")
    spin_tomography(psi, grid, F;
        rotation_axis = Symbol(get(td, "rotation_axis", "y")),
        n_angles = Int(get(td, "n_angles", 19)),
        tof_params = let d = get(td, "tof", Dict())
            TOFParams(Float64(get(d, "t_tof", 11.0)),
                     Float64(get(d, "gradient", 0.0)),
                     Int(get(d, "imaging_axis", 3)))
        end,
        reference_m = let v = get(td, "reference_m", nothing); v === nothing ? nothing : Int(v) end)
end

function _maybe_run_faraday(config, psi, grid, atom; verbose=true)
    fd = config.faraday
    fd === nothing && return nothing
    verbose && println("Running Faraday imaging...")
    faraday_image(psi, grid, atom.F;
        params = FaradayParams(;
            probe_axis = Int(get(fd, "probe_axis", 3)),
            detuning = Float64(get(fd, "detuning", -64.0)),
            polarization = Symbol(get(fd, "polarization", "linear_x"))))
end
