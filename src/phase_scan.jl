# --- Phase Scan Runner ---

function _sweep_values(sv::ScanValues)
    range(sv.from, sv.to; length=sv.n_points)
end

_sweep_values(v::Vector{Float64}) = v

function _base_sweep_state(config::UnifiedConfig{<:ScanExperiment})
    (interactions=config.system.interactions,
     zeeman=config.ground_state.zeeman,
     c_dd_override=nothing,
     rotating_frame_omega=config.ground_state.rotating_frame_omega)
end

# --- Val-dispatched parameter application (extensible via new methods) ---

function _apply_sweep_param(state::NamedTuple, param::Symbol, value::Float64;
                            c_total::Float64, F::Int)
    _apply_param(state, Val(param), value; c_total, F)
end

function _apply_param(state::NamedTuple, ::Val{:c1_ratio}, value::Float64;
                      c_total::Float64, F::Int)
    ip = interaction_params_from_constraint(;
        c_total, c1_ratio=value, F, c_extra=copy(state.interactions.c_extra))
    merge(state, (interactions=ip,))
end

function _apply_param(state::NamedTuple, ::Val{:zeeman_p}, value::Float64; kw...)
    merge(state, (zeeman=ZeemanParams(value, state.zeeman.q),))
end

function _apply_param(state::NamedTuple, ::Val{:zeeman_q}, value::Float64; kw...)
    merge(state, (zeeman=ZeemanParams(state.zeeman.p, value),))
end

function _apply_param(state::NamedTuple, ::Val{:c_dd}, value::Float64; kw...)
    merge(state, (c_dd_override=value,))
end

function _apply_param(state::NamedTuple, ::Val{:rotating_frame_omega}, value::Float64; kw...)
    merge(state, (rotating_frame_omega=value,))
end

function _apply_param(::NamedTuple, ::Val{P}, ::Float64; kw...) where {P}
    throw(ArgumentError(
        "Unknown sweep parameter: $P. " *
        "Supported: c1_ratio, zeeman_p, zeeman_q, c_dd, rotating_frame_omega"))
end

# --- Per-point override resolution ---

function _resolve_overrides(gs::GroundStateConfig,
                            overrides::Vector{ScanPointOverride},
                            param_values::Dict{Symbol,Float64})
    dt = gs.dt
    n_steps = gs.n_steps
    tol = gs.tol
    initial_state = gs.initial_state
    for ov in overrides
        val = get(param_values, ov.parameter, nothing)
        val === nothing && continue
        ov.range[1] <= val <= ov.range[2] || continue
        haskey(ov.overrides, :dt) && (dt = ov.overrides[:dt]::Float64)
        haskey(ov.overrides, :n_steps) && (n_steps = ov.overrides[:n_steps]::Int)
        haskey(ov.overrides, :tol) && (tol = ov.overrides[:tol]::Float64)
        haskey(ov.overrides, :initial_state) && (initial_state = ov.overrides[:initial_state]::Symbol)
    end
    (dt=dt, n_steps=n_steps, tol=tol, initial_state=initial_state)
end

# --- Single ground-state point (ParameterScan only) ---

function _run_single_point(config::UnifiedConfig{ScanExperiment{ParameterScan}}, state::NamedTuple,
                           grid, atom, sm, potential, ndim;
                           prev_psi=nothing, force_multistart::Bool=false,
                           param_values::Dict{Symbol,Float64}=Dict{Symbol,Float64}())
    gs = config.ground_state
    sys = config.system
    scan = config.spec.scan
    c_dd_val = state.c_dd_override !== nothing ? state.c_dd_override :
               (sys.ddi.c_dd === nothing ? NaN : sys.ddi.c_dd)

    resolved = _resolve_overrides(gs, scan.per_point_overrides, param_values)

    use_continuation = scan.continuation.enabled && prev_psi !== nothing && !force_multistart
    n_steps = use_continuation ? scan.continuation.n_steps : resolved.n_steps

    gs_kwargs = (;
        enable_ddi=something(gs.enable_ddi, sys.ddi.enabled), c_dd=c_dd_val,
        secular_ddi=sys.ddi.secular,
        quasi_2d_ddi=sys.ddi.quasi_2d, l_z_ddi=sys.ddi.l_z,
        fft_flags=FFTW.ESTIMATE,
        target_magnetization=gs.target_magnetization,
        rotating_frame_omega=state.rotating_frame_omega,
    )

    result = if (scan.multistart.enabled && !use_continuation) || force_multistart
        find_ground_state_multistart(;
            grid, atom, interactions=state.interactions,
            zeeman=state.zeeman, potential,
            dt=resolved.dt, n_steps=resolved.n_steps, tol=resolved.tol,
            initial_states=scan.multistart.initial_states,
            n_random=scan.multistart.n_random,
            gs_kwargs...)
    else
        psi_init = use_continuation ? copy(prev_psi) : nothing
        find_ground_state(;
            grid, atom, interactions=state.interactions,
            zeeman=state.zeeman, potential,
            dt=resolved.dt, n_steps, tol=resolved.tol,
            initial_state=resolved.initial_state, psi_init,
            gs_kwargs...)
    end

    ws = result.workspace
    psi = ws.state.psi
    phase_info = classify_phase_detailed(psi, atom.F, grid, sm;
        sampling=config.observables.spatial_sampling)

    stab_result = if config.spec.stability.enabled
        analyze_stability(ws;
            perturbation=config.spec.stability.perturbation,
            n_steps=config.spec.stability.n_steps,
            sample_every=config.spec.stability.sample_every,
        )
    else
        nothing
    end

    (energy=result.energy, converged=result.converged,
     phase_info=phase_info, psi=copy(psi), stability=stab_result)
end

# --- CSV helpers ---

function _open_csv(dir, filename)
    open(joinpath(dir, filename), "w")
end

function _write_csv(io, values)
    row = join(values, ",")
    if io !== nothing
        println(io, row)
        flush(io)
    end
    row
end

# --- ParameterScan dispatch (1D/2D unified) ---

function _run_scan(config::UnifiedConfig{ScanExperiment{ParameterScan}},
                   grid, atom, sm, potential, ndim; verbose::Bool=true)
    n_axes = length(config.spec.scan.axes)
    if n_axes == 1
        _run_parameter_1d(config, grid, atom, sm, potential, ndim; verbose)
    else
        _run_parameter_2d(config, grid, atom, sm, potential, ndim; verbose)
    end
end

function _run_parameter_1d(config::UnifiedConfig{ScanExperiment{ParameterScan}},
                           grid, atom, sm, potential, ndim; verbose::Bool=true)
    scan = config.spec.scan
    axis = scan.axes[1]
    values = collect(_sweep_values(axis.values))
    F = atom.F
    ip = config.system.interactions
    c_total = ip.c0 + F^2 * ip.c1
    base_state = _base_sweep_state(config)

    verbose && println("  1D sweep: $(axis.parameter), $(length(values)) points")

    io = config.output.csv ? _open_csv(config.output.dir, "scan_1d.csv") : nothing

    cols = Any[axis.parameter, :phase, :point_group, :energy,
               :spin_order, :nematic_order, :biaxiality, :converged]
    config.spec.stability.enabled && append!(cols, [:growth_rate, :unstable, :k_peak])
    header = _write_csv(io, cols)
    verbose && println(header)

    results = NamedTuple[]
    prev_psi = nothing
    prev_energy = NaN

    for (i, val) in enumerate(values)
        state = _apply_sweep_param(base_state, axis.parameter, val; c_total, F)
        pv = Dict{Symbol,Float64}(axis.parameter => val)

        r = _run_single_point(config, state, grid, atom, sm, potential, ndim;
                              prev_psi, param_values=pv)

        if scan.continuation.enabled && !isnan(prev_energy) &&
           abs(r.energy - prev_energy) / max(abs(prev_energy), 1e-30) > scan.continuation.energy_jump_threshold
            r = _run_single_point(config, state, grid, atom, sm, potential, ndim;
                                  prev_psi=nothing,
                                  force_multistart=scan.multistart.enabled,
                                  param_values=pv)
        end

        info = r.phase_info
        row_vals = Any[
            round(val; sigdigits=6), info.phase, info.point_group,
            round(r.energy; sigdigits=8), round(info.spin_order; sigdigits=4),
            round(info.nematic_order; sigdigits=4), round(info.biaxiality; sigdigits=4),
            r.converged]
        if config.spec.stability.enabled && r.stability !== nothing
            append!(row_vals, [round(r.stability.growth_rate; sigdigits=4),
                               r.stability.unstable, round(r.stability.k_peak; sigdigits=4)])
        end

        row = _write_csv(io, row_vals)
        verbose && println(row)

        push!(results, (param=val, energy=r.energy, converged=r.converged,
                        phase_info=info, stability=r.stability))

        if config.output.save_psi
            JLD2.jldsave(joinpath(config.output.dir, "psi_$(i).jld2"); psi=r.psi)
        end

        prev_psi = r.psi
        prev_energy = r.energy
    end

    io !== nothing && close(io)
    results
end

function _run_parameter_2d(config::UnifiedConfig{ScanExperiment{ParameterScan}},
                           grid, atom, sm, potential, ndim; verbose::Bool=true)
    scan = config.spec.scan
    ax1 = scan.axes[1]
    ax2 = scan.axes[2]
    vals1 = collect(_sweep_values(ax1.values))
    vals2 = collect(_sweep_values(ax2.values))
    n1, n2 = length(vals1), length(vals2)
    F = atom.F
    ip = config.system.interactions
    c_total = ip.c0 + F^2 * ip.c1
    base_state = _base_sweep_state(config)

    verbose && println("  2D sweep: $(ax1.parameter) ($n1) × $(ax2.parameter) ($n2)")

    io = config.output.csv ? _open_csv(config.output.dir, "scan_2d.csv") : nothing
    cols = Any[ax1.parameter, ax2.parameter, :phase, :point_group, :energy,
               :spin_order, :nematic_order, :biaxiality, :converged]
    header = _write_csv(io, cols)
    verbose && println(header)

    results = Matrix{NamedTuple}(undef, n1, n2)
    prev_row_psi = nothing

    for (j, v2) in enumerate(vals2)
        prev_psi = prev_row_psi
        prev_energy = NaN

        for (i, v1) in enumerate(vals1)
            state = _apply_sweep_param(base_state, ax1.parameter, v1; c_total, F)
            state = _apply_sweep_param(state, ax2.parameter, v2; c_total, F)
            pv = Dict{Symbol,Float64}(ax1.parameter => v1, ax2.parameter => v2)

            r = _run_single_point(config, state, grid, atom, sm, potential, ndim;
                                  prev_psi, param_values=pv)

            if scan.continuation.enabled && !isnan(prev_energy) &&
               abs(r.energy - prev_energy) / max(abs(prev_energy), 1e-30) > scan.continuation.energy_jump_threshold
                r = _run_single_point(config, state, grid, atom, sm, potential, ndim;
                                      prev_psi=nothing,
                                      force_multistart=scan.multistart.enabled,
                                      param_values=pv)
            end

            info = r.phase_info
            row_vals = Any[
                round(v1; sigdigits=6), round(v2; sigdigits=6),
                info.phase, info.point_group, round(r.energy; sigdigits=8),
                round(info.spin_order; sigdigits=4), round(info.nematic_order; sigdigits=4),
                round(info.biaxiality; sigdigits=4), r.converged]
            row = _write_csv(io, row_vals)
            verbose && println(row)

            results[i, j] = (param1=v1, param2=v2, energy=r.energy, converged=r.converged,
                             phase_info=info)

            prev_psi = r.psi
            prev_energy = r.energy
            i == 1 && (prev_row_psi = r.psi)
        end
    end

    io !== nothing && close(io)
    results
end

# --- ConstrainedJzScan dispatch ---

function _run_scan(config::UnifiedConfig{ScanExperiment{ConstrainedJzScan}},
                   grid, atom, sm, potential, ndim; verbose::Bool=true)
    scan = config.spec.scan
    verbose && println("  Jz scan: $(length(scan.target_values)) targets")

    io = config.output.csv ? _open_csv(config.output.dir, "scan_jz.csv") : nothing
    cols = [:target_Jz, :actual_Jz, :omega, :energy, :phase, :point_group,
            :spin_order, :converged]
    header = _write_csv(io, cols)
    verbose && println(header)

    gs = config.ground_state
    sys = config.system
    c_dd_val = sys.ddi.c_dd === nothing ? NaN : sys.ddi.c_dd

    results = NamedTuple[]

    for jz_target in scan.target_values
        r = find_ground_state(;
            grid, atom, interactions=sys.interactions,
            zeeman=gs.zeeman, potential,
            dt=gs.dt, n_steps=gs.n_steps, tol=gs.tol,
            initial_state=gs.initial_state,
            enable_ddi=something(gs.enable_ddi, sys.ddi.enabled), c_dd=c_dd_val,
            secular_ddi=sys.ddi.secular,
            quasi_2d_ddi=sys.ddi.quasi_2d, l_z_ddi=sys.ddi.l_z,
            fft_flags=FFTW.ESTIMATE,
            target_magnetization=gs.target_magnetization,
            rotating_frame_omega=gs.rotating_frame_omega,
            target_Jz=jz_target,
            Jz_tol=scan.tolerance,
            Jz_max_iter=scan.max_iter,
            Jz_omega_range=scan.omega_range,
            Jz_method=gs.Jz_method,
        )

        psi = r.workspace.state.psi
        info = classify_phase_detailed(psi, atom.F, grid, sm;
            sampling=config.observables.spatial_sampling)

        row_vals = Any[
            round(jz_target; digits=2), round(r.Jz; digits=4),
            round(r.omega; sigdigits=4), round(r.energy; sigdigits=8),
            info.phase, info.point_group, round(info.spin_order; sigdigits=4),
            r.converged]
        row = _write_csv(io, row_vals)
        verbose && println(row)

        push!(results, (target_Jz=jz_target, actual_Jz=r.Jz, omega=r.omega,
                        energy=r.energy, converged=r.converged, phase_info=info))

        if config.output.save_psi
            JLD2.jldsave(joinpath(config.output.dir, "psi_jz_$(round(jz_target; digits=2)).jld2");
                         psi=copy(psi))
        end
    end

    io !== nothing && close(io)
    results
end
