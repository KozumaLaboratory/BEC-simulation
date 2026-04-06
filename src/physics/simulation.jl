"""
    SimulationCallbacks

Event-driven callback system for simulation monitoring.

# Fields
- `on_step::Union{Nothing, Function}`: Called every step with `(ws, step, times, energies)`
- `on_snapshot::Union{Nothing, Function}`: Called when snapshot is saved with `(ws, step, snapshot)`
- `on_complete::Union{Nothing, Function}`: Called when simulation completes with `(ws, result)`

# Example
```julia
callbacks = SimulationCallbacks(
    on_step = (ws, step, times, energies) -> begin
        if step % 100 == 0
            @info "Step \$step" energy=energies[end]
        end
    end,
    on_snapshot = (ws, step, snapshot) -> begin
        # Custom snapshot processing
    end
)

result = run_simulation!(ws, callbacks=callbacks)
```
"""
struct SimulationCallbacks
    on_step::Union{Nothing,Function}
    on_snapshot::Union{Nothing,Function}
    on_complete::Union{Nothing,Function}
end

SimulationCallbacks(;
    on_step = nothing,
    on_snapshot = nothing,
    on_complete = nothing,
) = SimulationCallbacks(on_step, on_snapshot, on_complete)

# Backward compatibility: convert simple function to callbacks
_normalize_callbacks(::Nothing) = SimulationCallbacks()
_normalize_callbacks(f::Function) = SimulationCallbacks(on_snapshot = f)
_normalize_callbacks(c::SimulationCallbacks) = c

function _record_snapshot!(times, energies, norms, mags, snapshots, ws, sys)
    push!(times, ws.state.t)
    push!(energies, total_energy(ws))
    push!(norms, total_norm(ws.state.psi, ws.grid))
    push!(mags, magnetization(ws.state.psi, ws.grid, sys))
    push!(snapshots, Array(ws.state.psi))
end

function _check_energy_drift(energies, norms, E_now, nrm_now, t)
    E_per_N = E_now / max(nrm_now, 1e-300)
    if length(energies) >= 2
        E_per_N_prev = energies[end] / max(norms[end], 1e-300)
        de_rel = abs(E_per_N - E_per_N_prev) / max(abs(E_per_N_prev), 1e-300)
        if de_rel > 0.01
            @warn "E/N drift $(round(de_rel*100, digits=2))% between snapshots at t=$(round(t, digits=4))"
        end
    end
end

"""
    run_simulation!(ws::Workspace; callback=nothing, callbacks=nothing, live_monitor=nothing)

Run time evolution simulation with optional event-driven monitoring.

# Arguments
- `ws::Workspace`: Simulation workspace
- `callback::Union{Nothing,Function}`: Legacy callback (for backward compatibility)
- `callbacks::Union{Nothing,SimulationCallbacks}`: Event-driven callbacks
- `live_monitor::Union{Nothing,LiveMonitor}`: Real-time monitoring

# Returns
- `SimulationResult`: Times, energies, norms, magnetizations, and snapshots

# Example
```julia
# Basic usage
result = run_simulation!(ws)

# With live monitoring
monitor = LiveMonitor(output_file="live_data.json", update_interval=50)
result = run_simulation!(ws, live_monitor=monitor)

# With custom callbacks
callbacks = SimulationCallbacks(
    on_step = (ws, step, times, energies) -> @info "Step \$step",
    on_snapshot = (ws, step, snapshot) -> save_debug("snapshot_\$step.jld2", snapshot)
)
result = run_simulation!(ws, callbacks=callbacks)
```
"""
function run_simulation!(
    ws::Workspace{N};
    callback::Union{Nothing,Function} = nothing,
    callbacks::Union{Nothing,SimulationCallbacks} = nothing,
    live_monitor::Union{Nothing,LiveMonitor} = nothing,
) where {N}
    sp = ws.sim_params
    sys = ws.spin_matrices.system
    it = sp.imaginary_time

    # Normalize callbacks (backward compatibility)
    cbs = if callbacks !== nothing
        callbacks
    else
        _normalize_callbacks(callback)
    end

    times = Float64[]
    energies = Float64[]
    norms = Float64[]
    mags = Float64[]
    snapshots = Array{ComplexF64}[]
    _record_snapshot!(times, energies, norms, mags, snapshots, ws, sys)

    if it
        _run_simulation_standard!(
            ws,
            sp,
            sys,
            times,
            energies,
            norms,
            mags,
            snapshots,
            cbs,
            live_monitor,
        )
    else
        _run_simulation_leapfrog!(
            ws,
            sp,
            sys,
            times,
            energies,
            norms,
            mags,
            snapshots,
            cbs,
            live_monitor,
        )
    end

    result = SimulationResult(times, energies, norms, mags, snapshots)

    # on_complete callback
    if cbs.on_complete !== nothing
        cbs.on_complete(ws, result)
    end

    return result
end

function _run_simulation_standard!(
    ws::Workspace{N},
    sp,
    sys,
    times,
    energies,
    norms,
    mags,
    snapshots,
    callbacks::SimulationCallbacks,
    live_monitor::Union{Nothing,LiveMonitor},
) where {N}
    t_start = time()
    for step = 1:sp.n_steps
        split_step!(ws)

        # on_step callback (called every step)
        if callbacks.on_step !== nothing
            callbacks.on_step(ws, step, times, energies)
        end

        # Update live monitor (throttled internally)
        if live_monitor !== nothing
            update!(live_monitor, ws, step)
        end

        # Snapshot and logging
        if step % sp.save_every == 0
            _record_snapshot!(times, energies, norms, mags, snapshots, ws, sys)

            elapsed = time() - t_start
            frac = step / sp.n_steps
            eta = frac > 0 ? elapsed / frac * (1 - frac) : NaN
            println(
                "  step $(step)/$(sp.n_steps) | t=$(round(ws.state.t; sigdigits=6)) " *
                "E=$(round(energies[end]; sigdigits=8)) | $(round(elapsed; digits=1))s elapsed, ETA $(round(eta; digits=0))s",
            )
            flush(stdout)

            # on_snapshot callback
            if callbacks.on_snapshot !== nothing
                callbacks.on_snapshot(ws, step, snapshots[end])
            end
        end
    end
end

"""
Leapfrog-fused simulation loop for real-time dynamics.

Merges adjacent half potential steps V(dt/2)+V(dt/2)=V(dt) between time steps.
Splits at snapshot save points to ensure saved states are proper Strang-split results.
Mathematically identical to standard loop — no accuracy change.

Also uses batched FFT for kinetic step (all components in one FFTW call).
"""
function _run_simulation_leapfrog!(
    ws::Workspace{N},
    sp,
    sys,
    times,
    energies,
    norms,
    mags,
    snapshots,
    callbacks::SimulationCallbacks,
    live_monitor::Union{Nothing,LiveMonitor},
) where {N}
    dt = sp.dt
    n_comp = sys.n_components
    bk = ws.batched_kinetic
    omega = sp.rotating_frame_omega
    cc = ws.coriolis_cache

    # Leapfrog: initial half potential step
    # First half-step covers [t, t+dt/2], midpoint at t+dt/4
    _half_potential_step!(ws, dt / 2, n_comp, N, false; t_eval = ws.state.t + dt / 4, t_start = ws.state.t)

    for step = 1:sp.n_steps
        _apply_coriolis_step!(ws.state.psi, ws.grid, omega, dt / 2, false, cc)
        apply_kinetic_step_batched!(ws.state.psi, bk)
        _apply_coriolis_step!(ws.state.psi, ws.grid, omega, dt / 2, false, cc)

        is_save = (step % sp.save_every == 0)
        is_last = (step == sp.n_steps)
        need_split = is_save || is_last

        t_now = ws.state.t

        if need_split
            # Close current step: covers [t_now+dt/2, t_now+dt], midpoint at t_now+3dt/4
            _half_potential_step!(ws, dt / 2, n_comp, N, false; t_eval = t_now + 3dt / 4, t_start = t_now + dt / 2)
        else
            # Merged: close [t_now+dt/2, t_now+dt] + open [t_now+dt, t_now+3dt/2]
            # = full step [t_now+dt/2, t_now+3dt/2], midpoint at t_now+dt
            _half_potential_step!(ws, dt, n_comp, N, false; t_eval = t_now + dt, t_start = t_now + dt / 2)
        end

        if ws.loss !== nothing
            apply_loss_step!(ws.state.psi, ws.loss, sys.F, dt, n_comp, N, ws.density_buf)
        end

        ws.state.t += dt
        ws.state.step += 1

        # on_step callback (called every step)
        if callbacks.on_step !== nothing
            callbacks.on_step(ws, step, times, energies)
        end

        # Update live monitor (throttled internally)
        if live_monitor !== nothing
            update!(live_monitor, ws, step)
        end

        if is_save
            _record_snapshot!(times, energies, norms, mags, snapshots, ws, sys)

            # on_snapshot callback
            if callbacks.on_snapshot !== nothing
                callbacks.on_snapshot(ws, step, snapshots[end])
            end
        end

        # Open next step if we split: covers [t_now+dt, t_now+3dt/2], midpoint at t_now+dt+dt/4
        if need_split && !is_last
            _half_potential_step!(ws, dt / 2, n_comp, N, false; t_eval = ws.state.t + dt / 4, t_start = ws.state.t)
        end
    end
end

function run_simulation_checkpointed!(
    ws::Workspace{N};
    checkpoint_dir::String = "checkpoints",
    checkpoint_every::Int = 1000,
    callback::Union{Nothing,Function} = nothing,
    resume::Bool = false,
) where {N}
    mkpath(checkpoint_dir)

    if resume
        existing = filter(
            f -> startswith(basename(f), "step_") && endswith(f, ".jld2"),
            readdir(checkpoint_dir, join = true),
        )
        if !isempty(existing)
            sort!(existing)
            latest = existing[end]
            data = load_state(latest)
            copyto!(ws.state.psi, data.psi)
            ws.state.t = data.t
            ws.state.step = data.step
        end
    end

    start_step = ws.state.step
    remaining = ws.sim_params.n_steps - start_step
    remaining <= 0 && return run_simulation!(ws; callback)

    checkpoint_cb = function (ws_cb, step)
        global_step = start_step + step
        if global_step % checkpoint_every == 0
            fname = joinpath(checkpoint_dir, "step_$(lpad(global_step, 8, '0')).jld2")
            save_state(fname, ws_cb)
        end
        callback !== nothing && callback(ws_cb, step)
    end

    sp_orig = ws.sim_params
    sp_remain = SimParams(
        sp_orig.dt,
        remaining,
        sp_orig.imaginary_time,
        sp_orig.normalize_every,
        sp_orig.save_every,
    )

    ws_remain = Workspace(
        ws.state,
        ws.fft_plans,
        ws.kinetic_phase,
        ws.potential_values,
        ws.density_buf,
        ws.spin_matrices,
        ws.grid,
        ws.atom,
        ws.interactions,
        ws.zeeman,
        ws.potential,
        sp_remain,
        ws.ddi,
        ws.ddi_bufs,
        ws.raman,
        ws.loss,
        ws.ddi_padded,
        ws.batched_kinetic,
        ws.tensor_cache,
        ws.coriolis_cache,
        ws.backend,
        ws.lhy,
    )

    result = run_simulation!(ws_remain; callback = checkpoint_cb)

    ws.state.t = ws_remain.state.t
    ws.state.step = start_step + remaining
    copyto!(ws.state.psi, ws_remain.state.psi)

    result
end
