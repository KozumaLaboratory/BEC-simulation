const _ITP_EXPONENT_LIMIT = 50.0
const _ITP_DDI_WARN_EXPONENT = 20.0

function _check_itp_overflow(ws, step::Int)
    if any(isnan, ws.state.psi)
        throw(
            ArgumentError(
                "NaN detected in ITP at step $step. " *
                "Likely DDI potential overflow. Reduce dt.",
            ),
        )
    end
    ws.ddi === nothing && return nothing
    bufs = ws.ddi_bufs
    phi_max = max(maximum(abs, bufs.Phi_x), maximum(abs, bufs.Phi_y), maximum(abs, bufs.Phi_z))
    dt = ws.sim_params.dt
    exponent = phi_max * dt / 2
    if exponent > _ITP_EXPONENT_LIMIT
        throw(
            ArgumentError(
                "DDI potential overflow in ITP at step $step: " *
                "max|Φ|=$(round(phi_max, sigdigits=3)), " *
                "exponent=$(round(exponent, digits=1)) > $_ITP_EXPONENT_LIMIT. " *
                "Reduce dt (current=$dt).",
            ),
        )
    end
    nothing
end

function _validate_itp_zeeman(zeeman::ZeemanParams, F, dt)
    sys = SpinSystem(F)
    max_zee = maximum(abs, zeeman_energies(zeeman, sys))
    max_exponent = max_zee * dt / 4
    if max_exponent > _ITP_EXPONENT_LIMIT
        throw(
            ArgumentError(
                "Zeeman p=$(zeeman.p) with F=$F and dt=$dt causes overflow in imaginary time " *
                "(exponent=$(round(max_exponent, digits=1)) > $_ITP_EXPONENT_LIMIT). " *
                "Reduce p or dt. For ferromagnetic ground state, p=10 suffices.",
            ),
        )
    end
end

_validate_itp_zeeman(::TimeDependentZeeman, F, dt) = nothing

function _validate_itp_interactions(
    interactions::InteractionParams,
    F,
    dt;
    psi=nothing,
    c_dd::Float64=0.0,
)
    n_peak = if psi !== nothing
        ndim = ndims(psi) - 1
        Float64(maximum(total_density(psi, ndim)))
    else
        1.0
    end

    max_c = max(abs(interactions.c0), abs(interactions.c1))
    if max_c > 1e-30
        max_exponent = max_c * n_peak * dt / 4
        if max_exponent > _ITP_EXPONENT_LIMIT
            throw(
                ArgumentError(
                    "Spin interaction c0=$(interactions.c0), c1=$(interactions.c1) with " *
                    "n_peak≈$(round(n_peak, sigdigits=3)) and dt=$dt " *
                    "may cause overflow in imaginary time (estimated exponent=$(round(max_exponent, digits=1)) " *
                    "> $_ITP_EXPONENT_LIMIT). Reduce c0/c1 magnitude or dt.",
                ),
            )
        end
    end

    if c_dd > 0
        ddi_exponent = c_dd * F * n_peak * dt / 2
        if ddi_exponent > _ITP_EXPONENT_LIMIT
            throw(
                ArgumentError(
                    "DDI c_dd=$c_dd with F=$F, n_peak≈$(round(n_peak, sigdigits=3)) and dt=$dt " *
                    "may cause overflow in imaginary time (estimated exponent=$(round(ddi_exponent, digits=1)) " *
                    "> $_ITP_EXPONENT_LIMIT). Reduce c_dd or dt.",
                ),
            )
        end
    end
end

function find_ground_state(;
    grid,
    atom,
    interactions,
    zeeman=ZeemanParams(),
    potential=NoPotential(),
    dt=0.001,
    n_steps=10000,
    tol=1e-10,
    initial_state=:polar,
    init_state_params::Dict{Symbol, Float64}=Dict{Symbol, Float64}(),
    psi_init=nothing,
    enable_ddi::Bool=false,
    c_dd::Float64=NaN,
    secular_ddi::Bool=false,
    adaptive_dt::Bool=false,
    dt_max::Float64=10.0 * dt,
    fft_flags=FFTW.MEASURE,
    target_magnetization::Union{Nothing, Float64}=nothing,
    rotating_frame_omega::Float64=0.0,
    target_Jz::Union{Nothing, Float64}=nothing,
    Jz_tol::Float64=0.01,
    Jz_max_iter::Int=20,
    Jz_omega_range::Tuple{Float64, Float64}=(-5.0, 5.0),
    quasi_2d_ddi::Bool=false,
    l_z_ddi::Float64=0.0,
    quasi_2d::Bool=false,
    l_z::Float64=0.0,
    backend::AbstractBackend=CPUBackend(),
    on_step::Union{Nothing, Function}=nothing,  # (ws, step, n_steps) → update ws params
    checkpoint_dir::Union{Nothing, String}=nothing,
    checkpoint_every::Int=0,
    _start_step::Int=0,        # internal: for resume
    _checkpoint_dir::Union{Nothing, String}=nothing,  # internal alias
    _checkpoint_every::Int=0,   # internal alias
    light_shift::Union{Nothing, LightShift}=nothing,
    dtype::Union{Nothing, Type{<:AbstractFloat}}=nothing,
    spinor_lhy::Union{Nothing, Symbol}=nothing,
    method::Symbol=:strang,
    verbose::Bool=true,
)
    method === :strang || throw(
        ArgumentError(
            "find_ground_state currently supports method=:strang only " *
            "(got :$method). The :sc4 path was disabled pending verified " *
            "complex-coefficient symmetric-conjugate weights — see " *
            "src/solvers/embedded_adaptive.jl for the design note."),
    )

    psi0 = if psi_init === nothing
        sys = SpinSystem(atom.F)
        init_kwargs = pairs(init_state_params)
        init_psi(grid, sys; state=initial_state, dtype=dtype, init_kwargs...)
    else
        copy(psi_init)
    end

    # F32 unit roundoff is ~1.2e-7, so requesting tol=1e-10 will never converge.
    # Cap at 1e-6 and warn, so users get a sensible default when they flip dtype
    # without rethinking tolerances.
    T_effective = dtype === nothing ? eltype(grid.x[1]) : dtype
    if T_effective === Float32 && tol < 1.0e-6
        @warn "Relaxing ITP tol $tol → 1e-6 for Float32 (unit roundoff ~1.2e-7)." maxlog=1
        tol = 1.0e-6
    end

    if target_Jz !== nothing
        N_dim = length(grid.config.n_points)
        N_dim >= 2 || throw(
            ArgumentError(
                "target_Jz requires N ≥ 2 (need orbital angular momentum). Got N=$N_dim."
            ),
        )
        return _find_ground_state_Jz(;
            grid,
            atom,
            interactions,
            zeeman,
            potential,
            dt,
            n_steps,
            tol,
            initial_state,
            psi_init=psi0,
            enable_ddi,
            c_dd,
            secular_ddi,
            adaptive_dt,
            dt_max,
            fft_flags,
            target_magnetization,
            target_Jz,
            Jz_tol,
            Jz_max_iter,
            Jz_omega_range,
            quasi_2d_ddi,
            l_z_ddi,
            quasi_2d,
            l_z,
            backend,
        )
    end

    _validate_itp_zeeman(zeeman, atom.F, dt)
    effective_c_dd = (enable_ddi && !isnan(c_dd)) ? c_dd : 0.0
    _validate_itp_interactions(interactions, atom.F, dt; psi=psi0, c_dd=effective_c_dd)

    if adaptive_dt
        return _find_ground_state_adaptive(;
            grid,
            atom,
            interactions,
            zeeman,
            potential,
            dt,
            n_steps,
            tol,
            psi0,
            enable_ddi,
            c_dd,
            secular_ddi,
            dt_max,
            fft_flags,
            rotating_frame_omega,
            quasi_2d_ddi,
            l_z_ddi,
            quasi_2d,
            l_z,
            backend,
            light_shift,
            verbose,
        )
    end

    use_constrained = target_magnetization !== nothing
    norm_every = use_constrained ? 0 : 1
    sp = SimParams(;
        dt,
        n_steps,
        imaginary_time=true,
        normalize_every=norm_every,
        save_every=max(1, n_steps ÷ 100),
        rotating_frame_omega,
    )
    ws = make_workspace(;
        grid,
        atom,
        interactions,
        zeeman,
        potential,
        sim_params=sp,
        psi_init=psi0,
        enable_ddi,
        c_dd,
        secular_ddi,
        fft_flags,
        quasi_2d_ddi,
        l_z_ddi,
        quasi_2d,
        l_z,
        backend,
        light_shift,
        dtype=dtype,
        spinor_lhy,
    )

    n_comp = ws.spin_matrices.system.n_components
    N_dim = length(grid.config.n_points)

    if use_constrained
        _normalize_psi_constrained!(
            ws.state.psi,
            ws.grid,
            n_comp,
            N_dim,
            target_magnetization,
            atom.F,
        )
    end

    ckpt_dir = checkpoint_dir !== nothing ? checkpoint_dir : _checkpoint_dir
    ckpt_every = checkpoint_every > 0 ? checkpoint_every : _checkpoint_every

    _run_itp_loop!(ws, n_steps, tol, on_step, target_magnetization;
        start_step=_start_step,
        checkpoint_dir=ckpt_dir,
        checkpoint_every=ckpt_every,
        verbose=verbose,
    )
end

# --- Core ITP loop (interrupt-safe, checkpoint-capable) ---

function _run_itp_loop!(
    ws, n_steps, tol, on_step, target_magnetization;
    start_step::Int=0,
    checkpoint_dir::Union{Nothing, String}=nothing,
    checkpoint_every::Int=0,
    verbose::Bool=true,
)
    sp = ws.sim_params
    n_comp = ws.spin_matrices.system.n_components
    F = ws.atom.F
    N_dim = length(ws.grid.config.n_points)
    use_constrained = target_magnetization !== nothing

    E_prev = total_energy(ws)
    converged = false
    psi_prev = copy(ws.state.psi)
    final_dE = NaN
    final_dpsi = NaN
    last_step = start_step
    t_start = time()

    if checkpoint_dir !== nothing
        mkpath(checkpoint_dir)
    end

    interrupted = false
    gpu = _is_gpu(ws.state.psi)
    dt = ws.sim_params.dt
    n_comp_ws = n_comp
    bk = ws.batched_kinetic
    omega = ws.sim_params.rotating_frame_omega
    cc = ws.coriolis_cache
    it = true  # imaginary time

    # ITP leapfrog: merge outer V substeps (diag+SM+nematic+tensor+raman)
    # between adjacent steps. DDI stays at dt/2 (ITP real exponentials
    # would overflow if doubled).
    #
    # Standard split_step V(dt/2):
    #   outer_fwd(dt/4) → DDI(dt/2) → outer_bwd(dt/4)
    #
    # Leapfrog merges boundary outer_bwd(dt/4) + outer_fwd(dt/4) = outer(dt/2).
    #
    # Open: outer_fwd(dt/4) DDI(dt/2) outer_bwd(dt/4)
    _outer_potential_fwd!(ws, dt / 4, n_comp_ws, N_dim, it)
    _ddi_step!(ws, dt / 2, N_dim, it)
    _outer_potential_bwd!(ws, dt / 4, n_comp_ws, N_dim, it)

    try
        for step in (start_step + 1):n_steps
            on_step !== nothing && on_step(ws, step, n_steps)

            # Kinetic step K(dt)
            _apply_coriolis_step!(ws.state.psi, ws.grid, omega, dt / 2, it, cc)
            apply_kinetic_step_batched!(ws.state.psi, bk)
            _apply_coriolis_step!(ws.state.psi, ws.grid, omega, dt / 2, it, cc)

            is_check = step % sp.save_every == 0
            is_last = step == n_steps
            need_split = is_check || is_last

            if need_split
                # Close: outer_fwd(dt/4) DDI(dt/2) outer_bwd(dt/4)
                _outer_potential_fwd!(ws, dt / 4, n_comp_ws, N_dim, it)
                _ddi_step!(ws, dt / 2, N_dim, it)
                _outer_potential_bwd!(ws, dt / 4, n_comp_ws, N_dim, it)
            else
                # Merged boundary: outer(dt/2) then DDI(dt/2) then outer(dt/2)
                # bwd(dt/4)+fwd(dt/4) = single pass at dt/2
                _outer_potential_fwd!(ws, dt / 2, n_comp_ws, N_dim, it)
                _ddi_step!(ws, dt / 2, N_dim, it)
                _outer_potential_bwd!(ws, dt / 2, n_comp_ws, N_dim, it)
            end

            ws.state.step += 1
            if ws.sim_params.normalize_every > 0 &&
                ws.state.step % ws.sim_params.normalize_every == 0
                _normalize_psi!(ws.state.psi, ws.grid, n_comp_ws, N_dim)
            end

            # NaN check: only first 10 steps (forces GPU sync)
            if step <= (start_step + 10)
                if any(isnan, ws.state.psi)
                    throw(
                        ArgumentError(
                            "NaN detected in ITP at step $step. " *
                            "Likely DDI or interaction overflow. Reduce dt.",
                        ),
                    )
                end
                _check_itp_overflow(ws, step)
            end
            if use_constrained
                _normalize_psi_constrained!(
                    ws.state.psi,
                    ws.grid,
                    n_comp,
                    N_dim,
                    target_magnetization,
                    F,
                )
            end
            last_step = step

            if checkpoint_dir !== nothing && checkpoint_every > 0 && step % checkpoint_every == 0
                _save_itp_checkpoint(
                    checkpoint_dir, ws, step, n_steps, E_prev, final_dE, final_dpsi, converged, tol
                )
            end

            if step % sp.save_every == 0
                E = total_energy(ws)
                dE = abs(E - E_prev)
                psi_max = maximum(abs, ws.state.psi)
                dpsi = if psi_max > 0
                    # Fuse subtraction + abs into map-reduce (avoids temp array alloc)
                    psi_prev .= ws.state.psi .- psi_prev  # reuse psi_prev as diff buffer
                    maximum(abs, psi_prev) / psi_max
                else
                    0.0
                end
                copyto!(psi_prev, ws.state.psi)
                final_dE = dE
                final_dpsi = dpsi

                if verbose
                    elapsed = time() - t_start
                    frac = step / n_steps
                    eta = frac > 0 ? elapsed / frac * (1 - frac) : NaN
                    println(
                        "  ITP $(step)/$(n_steps) | E=$(round(E; sigdigits=8)) dE=$(round(dE; sigdigits=3)) " *
                        "dpsi=$(round(dpsi; sigdigits=3)) | $(round(elapsed; digits=1))s elapsed, ETA $(round(eta; digits=0))s",
                    )
                    flush(stdout)
                end

                if dE < tol
                    converged = true
                    break
                end
                E_prev = E
            end

            # Reopen leapfrog after split point
            if need_split && !converged && step < n_steps
                _outer_potential_fwd!(ws, dt / 4, n_comp_ws, N_dim, it)
                _ddi_step!(ws, dt / 2, N_dim, it)
                _outer_potential_bwd!(ws, dt / 4, n_comp_ws, N_dim, it)
            end
        end
    catch e
        if e isa InterruptException
            interrupted = true
            if verbose
                println("\n  ITP interrupted at step $last_step/$n_steps")
                flush(stdout)
            end
        else
            rethrow(e)
        end
    end

    if interrupted && checkpoint_dir !== nothing
        _save_itp_checkpoint(
            checkpoint_dir,
            ws,
            last_step,
            n_steps,
            total_energy(ws),
            final_dE,
            final_dpsi,
            converged,
            tol,
        )
        if verbose
            println("  Checkpoint saved to $checkpoint_dir/itp_checkpoint.jld2")
            flush(stdout)
        end
    end

    (
        workspace=ws,
        converged=converged,
        energy=total_energy(ws),
        dE=final_dE,
        dpsi=final_dpsi,
        interrupted=interrupted,
        last_step=last_step,
    )
end

function _save_itp_checkpoint(dir, ws, step, n_steps, energy, dE, dpsi, converged, tol)
    psi_host = _to_host(ws.state.psi)
    fname = joinpath(dir, "itp_checkpoint.jld2")
    tmp = fname * ".tmp"
    try
        jldopen(tmp, "w") do f
            f["psi"] = psi_host
            f["step"] = step
            f["n_steps"] = n_steps
            f["energy"] = energy
            f["dE"] = isnan(dE) ? Inf : dE
            f["dpsi"] = isnan(dpsi) ? Inf : dpsi
            f["converged"] = converged
            f["dt"] = ws.sim_params.dt
            f["tol"] = tol
            f["atom_name"] = ws.atom.name
            f["grid_n_points"] = ws.grid.config.n_points
            f["grid_box_size"] = ws.grid.config.box_size
            f["c0"] = ws.interactions.c0
            f["c1"] = ws.interactions.c1
        end
        mv(tmp, fname; force=true)
    catch err
        isfile(tmp) && rm(tmp; force=true)
        @warn "Failed to save ITP checkpoint: $err"
    end
end

"""
    load_itp_checkpoint(path) -> ITPCheckpoint

Load an ITP checkpoint from a JLD2 file (or directory containing itp_checkpoint.jld2).
"""
function load_itp_checkpoint(path::String)
    fname = isdir(path) ? joinpath(path, "itp_checkpoint.jld2") : path
    isfile(fname) || throw(ArgumentError("Checkpoint not found: $fname"))
    d = JLD2.load(fname)
    ITPCheckpoint(
        d["psi"],
        d["step"],
        d["n_steps"],
        d["energy"],
        get(d, "dE", NaN),
        get(d, "dpsi", NaN),
        get(d, "converged", false),
        d["dt"],
        get(d, "tol", 1e-10),
    )
end

"""
    resume_ground_state(checkpoint; grid, atom, interactions, kwargs...) -> NamedTuple

Resume ITP from a checkpoint. The checkpoint can be:
- An `ITPCheckpoint` (from `load_itp_checkpoint`)
- A file path or directory containing `itp_checkpoint.jld2`

Requires the same `grid`, `atom`, `interactions` (and other workspace params)
as the original run. `n_steps`, `tol`, `dt` default to the checkpoint values.
"""
function resume_ground_state(checkpoint::ITPCheckpoint;
    n_steps::Int=checkpoint.n_steps,
    tol::Float64=checkpoint.tol,
    dt::Float64=checkpoint.dt,
    checkpoint_dir::Union{Nothing, String}=nothing,
    checkpoint_every::Int=0,
    kwargs...,
)
    checkpoint.converged &&
        @warn "Checkpoint already converged (dE=$(checkpoint.dE)). Use refine_ground_state to continue with tighter tol."

    remaining = n_steps - checkpoint.step
    remaining <= 0 && return (
        workspace=nothing,
        converged=checkpoint.converged,
        energy=checkpoint.energy,
        dE=checkpoint.dE,
        dpsi=checkpoint.dpsi,
        interrupted=false,
        last_step=checkpoint.step,
    )

    find_ground_state(;
        psi_init=copy(checkpoint.psi),
        dt, n_steps, tol,
        _start_step=checkpoint.step,
        _checkpoint_dir=checkpoint_dir,
        _checkpoint_every=checkpoint_every,
        kwargs...,
    )
end

function resume_ground_state(path::String; kwargs...)
    resume_ground_state(load_itp_checkpoint(path); kwargs...)
end

"""
    refine_ground_state(result; tol, dt, n_steps, kwargs...) -> NamedTuple

Take an existing ground state result and continue ITP with tighter parameters.
The `result` should be a NamedTuple from `find_ground_state` (must have `.workspace`).

Typical usage: converged at tol=1e-8, refine to tol=1e-10.
"""
function refine_ground_state(result::NamedTuple;
    tol::Float64=result.workspace.sim_params.imaginary_time ? 1e-12 : 1e-10,
    dt::Float64=result.workspace.sim_params.dt,
    n_steps::Int=result.workspace.sim_params.n_steps,
    checkpoint_dir::Union{Nothing, String}=nothing,
    checkpoint_every::Int=0,
    on_step::Union{Nothing, Function}=nothing,
    target_magnetization::Union{Nothing, Float64}=nothing,
)
    ws = result.workspace
    println(
        "  Refining: E=$(round(result.energy; sigdigits=8)), dE=$(result.dE), tol_new=$tol, dt=$dt"
    )
    flush(stdout)

    ws_new = if dt != ws.sim_params.dt
        _rebuild_workspace_with_dt(ws, dt)
    else
        ws
    end

    _run_itp_loop!(ws_new, n_steps, tol, on_step, target_magnetization;
        start_step=0,
        checkpoint_dir,
        checkpoint_every,
    )
end

"""
Adaptive dt ground state search.

Strategy: run check_every steps, then evaluate energy.
- Energy decreased → grow dt by 10% (capped at dt_max)
- Energy increased → revert psi, halve dt, retry
"""
function _find_ground_state_adaptive(;
    grid,
    atom,
    interactions,
    zeeman,
    potential,
    dt,
    n_steps,
    tol,
    psi0,
    enable_ddi,
    c_dd,
    secular_ddi=false,
    dt_max,
    fft_flags=FFTW.MEASURE,
    rotating_frame_omega::Float64=0.0,
    quasi_2d_ddi::Bool=false,
    l_z_ddi::Float64=0.0,
    quasi_2d::Bool=false,
    l_z::Float64=0.0,
    backend::AbstractBackend=CPUBackend(),
    light_shift=nothing,
    verbose::Bool=true,
)
    current_dt = dt
    check_every = max(1, n_steps ÷ 100)
    psi_current = copy(psi0)

    sp = SimParams(;
        dt=current_dt,
        n_steps=check_every,
        imaginary_time=true,
        normalize_every=1,
        save_every=check_every,
        rotating_frame_omega,
    )
    ws = make_workspace(;
        grid,
        atom,
        interactions,
        zeeman,
        potential,
        sim_params=sp,
        psi_init=psi_current,
        enable_ddi,
        c_dd,
        secular_ddi,
        fft_flags,
        quasi_2d_ddi,
        l_z_ddi,
        quasi_2d,
        l_z,
        backend,
        light_shift,
    )
    psi_backup = similar(ws.state.psi)
    E_prev = total_energy(ws)
    converged = false
    total_steps = 0

    final_dE = NaN
    final_dpsi = NaN
    t_start = time()

    while total_steps < n_steps
        copyto!(psi_backup, ws.state.psi)

        for i in 1:check_every
            split_step!(ws)
            if i == 1 && total_steps == 0
                _check_itp_overflow(ws, 1)
            end
            if any(isnan, ws.state.psi)
                copyto!(ws.state.psi, psi_backup)
                break
            end
        end
        total_steps += check_every

        E = total_energy(ws)

        if isnan(E) || E > E_prev
            copyto!(ws.state.psi, psi_backup)
            current_dt = max(current_dt * 0.5, 1e-8)
            ws = _rebuild_workspace_with_dt(ws, current_dt)
            if verbose
                println(
                    "  ITP adaptive: rejected at step $(total_steps)/$(n_steps), dt → $(current_dt)"
                )
                flush(stdout)
            end
        else
            dE = abs(E - E_prev)
            psi_max = maximum(abs, ws.state.psi)
            dpsi = psi_max > 0 ? maximum(abs, ws.state.psi .- psi_backup) / psi_max : 0.0
            final_dE = dE
            final_dpsi = dpsi

            if verbose
                elapsed = time() - t_start
                frac = total_steps / n_steps
                eta = frac > 0 ? elapsed / frac * (1 - frac) : NaN
                println(
                    "  ITP $(total_steps)/$(n_steps) | E=$(round(E; sigdigits=8)) dE=$(round(dE; sigdigits=3)) " *
                    "dpsi=$(round(dpsi; sigdigits=3)) dt=$(round(current_dt; sigdigits=3)) | " *
                    "$(round(elapsed; digits=1))s elapsed, ETA $(round(eta; digits=0))s",
                )
                flush(stdout)
            end

            # Convergence by dE only — dpsi can stay large with persistent
            # mass currents (DDI-driven vortex flow, FL texture, etc.)
            if dE < tol
                converged = true
                break
            end
            E_prev = E
            new_dt = min(current_dt * 1.1, dt_max)
            if new_dt != current_dt
                current_dt = new_dt
                ws = _rebuild_workspace_with_dt(ws, current_dt)
            end
        end
    end

    (
        workspace=ws,
        converged=converged,
        energy=total_energy(ws),
        dE=final_dE,
        dpsi=final_dpsi,
    )
end

"""
    find_ground_state_multistart(; initial_states, n_random, seed, kwargs...) → NamedTuple

Try multiple initial states and return the lowest-energy ground state.
All keyword arguments except `initial_states`, `n_random`, and `seed` are
forwarded to `find_ground_state`.

Returns `(workspace, converged, energy, initial_state, all_results)`.
"""
function find_ground_state_multistart(;
    initial_states::Vector{Symbol}=[:polar, :ferromagnetic, :uniform, :antiferromagnetic],
    n_random::Int=3,
    seed::Int=42,
    grid,
    atom,
    interactions,
    kwargs...,
)
    results = NamedTuple[]

    for state in initial_states
        if state == :random
            for i in 1:n_random
                sys = SpinSystem(atom.F)
                psi0 = init_psi(grid, sys; state=:random, seed=seed + i)
                r = find_ground_state(;
                    grid,
                    atom,
                    interactions,
                    psi_init=psi0,
                    kwargs...,
                )
                push!(
                    results,
                    (
                        initial_state=:random,
                        idx=i,
                        workspace=r.workspace,
                        converged=r.converged,
                        energy=r.energy,
                        dE=r.dE,
                        dpsi=r.dpsi,
                    ),
                )
            end
        else
            r = find_ground_state(;
                grid,
                atom,
                interactions,
                initial_state=state,
                kwargs...,
            )
            push!(
                results,
                (
                    initial_state=state,
                    idx=0,
                    workspace=r.workspace,
                    converged=r.converged,
                    energy=r.energy,
                    dE=r.dE,
                    dpsi=r.dpsi,
                ),
            )
        end
    end

    best = argmin(r -> r.energy, results)
    (
        workspace=best.workspace,
        converged=best.converged,
        energy=best.energy,
        initial_state=best.initial_state,
        all_results=results,
    )
end

"""
Normalize psi while constraining magnetization ⟨Fz⟩ to target_Mz.

Applies exp(λ·m) weights to each component, then normalizes.
Uses Newton iteration to find λ such that Mz(λ) = target_Mz.
"""
function _normalize_psi_constrained!(psi, grid, n_components, ndim, target_Mz, F)
    dV = cell_volume(grid)
    n_pts = ntuple(d -> size(psi, d), ndim)

    _normalize_psi!(psi, grid, n_components, ndim)

    lambda = 0.0
    for _iter in 1:20
        norms = Vector{Float64}(undef, n_components)
        for c in 1:n_components
            m = F - (c - 1)
            idx = _component_slice(ndim, n_pts, c)
            w = exp(lambda * m)
            norms[c] = sum(abs2, view(psi, idx...)) * dV * w^2
        end
        total = sum(norms)
        total < 1e-30 && break

        Mz = sum((F - (c - 1)) * norms[c] for c in 1:n_components) / total
        abs(Mz - target_Mz) < 1e-12 && break

        dMz = 0.0
        for c in 1:n_components
            m = F - (c - 1)
            dMz += 2 * m * (m - Mz) * norms[c] / total
        end
        abs(dMz) < 1e-30 && break

        lambda -= (Mz - target_Mz) / dMz
        lambda = clamp(lambda, -10.0, 10.0)
    end

    for c in 1:n_components
        m = F - (c - 1)
        w = exp(lambda * m)
        idx = _component_slice(ndim, n_pts, c)
        view(psi, idx...) .*= w
    end

    _normalize_psi!(psi, grid, n_components, ndim)
    nothing
end

function _rebuild_workspace_with_dt(ws::Workspace{N}, new_dt::Float64) where {N}
    sp = SimParams(
        new_dt,
        ws.sim_params.n_steps,
        true,
        ws.sim_params.normalize_every,
        ws.sim_params.save_every,
        ws.sim_params.rotating_frame_omega,
    )
    kinetic_phase = _to_device(
        ws.backend,
        prepare_kinetic_phase(ws.grid, new_dt; imaginary_time=true),
    )
    batched_kinetic = _make_batched_kinetic_cache(ws.state.psi, kinetic_phase, N, ws.backend)

    _rebuild_workspace(ws;
        sim_params=sp,
        kinetic_phase=kinetic_phase,
        batched_kinetic=batched_kinetic,
    )
end

# --- Constrained Jz ground state (bisection on rotating_frame_omega) ---

"""
Bisection on rotating_frame_omega to find ground state with target J_z.

Higher Ω shifts the energy minimum to lower J_z, so:
  J_z(Ω) is a decreasing function of Ω.
"""
function _find_ground_state_Jz(;
    grid,
    atom,
    interactions,
    zeeman,
    potential,
    dt,
    n_steps,
    tol,
    initial_state,
    psi_init,
    enable_ddi,
    c_dd,
    secular_ddi,
    adaptive_dt,
    dt_max,
    fft_flags,
    target_magnetization,
    target_Jz,
    Jz_tol,
    Jz_max_iter,
    Jz_omega_range,
    quasi_2d_ddi::Bool=false,
    l_z_ddi::Float64=0.0,
    quasi_2d::Bool=false,
    l_z::Float64=0.0,
    backend::AbstractBackend=CPUBackend(),
)
    omega_lo, omega_hi = Jz_omega_range
    prev_psi = psi_init

    best_result = nothing
    best_Jz = NaN
    best_omega = 0.0

    for iter in 1:Jz_max_iter
        omega_trial = (omega_lo + omega_hi) / 2.0
        r = find_ground_state(;
            grid,
            atom,
            interactions,
            zeeman,
            potential,
            dt,
            n_steps,
            tol,
            initial_state,
            psi_init=copy(prev_psi),
            enable_ddi,
            c_dd,
            secular_ddi,
            adaptive_dt,
            dt_max,
            fft_flags,
            target_magnetization,
            rotating_frame_omega=omega_trial,
            quasi_2d_ddi,
            l_z_ddi,
            quasi_2d,
            l_z,
            backend,
        )

        ws = r.workspace
        plans = ws.fft_plans
        sys = ws.spin_matrices.system
        Jz = total_angular_momentum(ws.state.psi, grid, plans, sys)

        if best_result === nothing || abs(Jz - target_Jz) < abs(best_Jz - target_Jz)
            best_result = r
            best_Jz = Jz
            best_omega = omega_trial
        end

        if abs(Jz - target_Jz) < Jz_tol
            return (
                workspace=r.workspace,
                converged=r.converged,
                energy=r.energy,
                dE=r.dE,
                dpsi=r.dpsi,
                Jz=Jz,
                omega=omega_trial,
            )
        end

        if Jz > target_Jz
            omega_lo = omega_trial
        else
            omega_hi = omega_trial
        end

        prev_psi = copy(ws.state.psi)
    end

    (
        workspace=best_result.workspace,
        converged=false,
        energy=best_result.energy,
        dE=best_result.dE,
        dpsi=best_result.dpsi,
        Jz=best_Jz,
        omega=best_omega,
    )
end
