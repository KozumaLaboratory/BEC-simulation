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
struct SimulationCallbacks{F1, F2, F3}
    on_step::F1
    on_snapshot::F2
    on_complete::F3
end

SimulationCallbacks(;
on_step=nothing,
on_snapshot=nothing,
on_complete=nothing
) = SimulationCallbacks{typeof(on_step), typeof(on_snapshot), typeof(on_complete)}(
    on_step, on_snapshot, on_complete)

# Backward compatibility: convert simple function to callbacks
_normalize_callbacks(::Nothing) = SimulationCallbacks()
_normalize_callbacks(f::Function) = SimulationCallbacks(on_snapshot=f)
_normalize_callbacks(c::SimulationCallbacks) = c

function _record_snapshot!(
    times,
    energies,
    norms,
    mags,
    snapshots,
    ws,
    sys;
    keep_psi::Bool=true,
)
    push!(times, ws.state.t)
    push!(energies, total_energy(ws))
    push!(norms, total_norm(ws.state.psi, ws.grid))
    push!(mags, magnetization(ws.state.psi, ws.grid, sys))
    # When a caller is streaming snapshots to disk in an on_snapshot
    # callback we skip the in-memory copy. 154 × 52 MB on a 64³×13
    # grid is 8 GB of host RAM that we can trivially avoid — the live
    # `ws.state.psi` is already available to the callback.
    keep_psi && push!(snapshots, Array(ws.state.psi))
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
    callback::Union{Nothing, Function}=nothing,
    callbacks::Union{Nothing, SimulationCallbacks}=nothing,
    live_monitor::Union{Nothing, LiveMonitor}=nothing,
    stream_snapshots::Bool=false,
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
    _record_snapshot!(
        times, energies, norms, mags, snapshots, ws, sys;
        keep_psi=(!stream_snapshots),
    )

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
            live_monitor;
            stream_snapshots,
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
            live_monitor;
            stream_snapshots,
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
    live_monitor::Union{Nothing, LiveMonitor};
    stream_snapshots::Bool=false,
) where {N}
    t_start = time()
    try
        for step in 1:sp.n_steps
            split_step!(ws)

            if callbacks.on_step !== nothing
                callbacks.on_step(ws, step, times, energies)
            end

            if live_monitor !== nothing
                update!(live_monitor, ws, step)
            end

            if step % sp.save_every == 0
                _record_snapshot!(
                    times, energies, norms, mags, snapshots, ws, sys;
                    keep_psi=(!stream_snapshots),
                )

                elapsed = time() - t_start
                frac = step / sp.n_steps
                eta = frac > 0 ? elapsed / frac * (1 - frac) : NaN
                println(
                    "  step $(step)/$(sp.n_steps) | t=$(round(ws.state.t; sigdigits=6)) " *
                    "E=$(round(energies[end]; sigdigits=8)) | $(round(elapsed; digits=1))s elapsed, ETA $(round(eta; digits=0))s",
                )
                flush(stdout)
                ccall(:fflush, Cint, (Ptr{Cvoid},), C_NULL)

                if callbacks.on_snapshot !== nothing
                    psi_snap = stream_snapshots ? Array(ws.state.psi) : snapshots[end]
                    callbacks.on_snapshot(ws, step, psi_snap)
                end
            end
        end
    catch e
        if e isa InterruptException
            _record_snapshot!(
                times, energies, norms, mags, snapshots, ws, sys;
                keep_psi=(!stream_snapshots),
            )
            println(
                "\n  Simulation interrupted at step $(ws.state.step)/$(sp.n_steps), t=$(round(ws.state.t; sigdigits=6))"
            )
            println(
                "  Final snapshot saved. Use run_simulation_checkpointed! with resume=true to continue."
            )
            flush(stdout)
        else
            rethrow(e)
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
    live_monitor::Union{Nothing, LiveMonitor};
    stream_snapshots::Bool=false,
) where {N}
    dt = sp.dt
    n_comp = sys.n_components
    bk = ws.batched_kinetic
    omega = sp.rotating_frame_omega
    cc = ws.coriolis_cache

    _half_potential_step!(
        ws, dt / 2, n_comp, N, false; t_eval=(ws.state.t + dt / 4), t_start=ws.state.t
    )

    try
        for step in 1:sp.n_steps
            _apply_coriolis_step!(ws.state.psi, ws.grid, omega, dt / 2, false, cc)
            apply_kinetic_step_batched!(ws.state.psi, bk)
            _apply_coriolis_step!(ws.state.psi, ws.grid, omega, dt / 2, false, cc)

            is_save = (step % sp.save_every == 0)
            is_last = (step == sp.n_steps)
            need_split = is_save || is_last

            t_now = ws.state.t

            if need_split
                _half_potential_step!(
                    ws, dt / 2, n_comp, N, false; t_eval=t_now + 3dt / 4, t_start=t_now + dt / 2
                )
            else
                _half_potential_step!(
                    ws, dt, n_comp, N, false; t_eval=t_now + dt, t_start=t_now + dt / 2
                )
            end

            if ws.loss !== nothing
                apply_loss_step!(ws.state.psi, ws.loss, sys.F, dt, n_comp, N, ws.density_buf)
            end

            ws.state.t += dt
            ws.state.step += 1

            if callbacks.on_step !== nothing
                callbacks.on_step(ws, step, times, energies)
            end

            if live_monitor !== nothing
                update!(live_monitor, ws, step)
            end

            if is_save
                _record_snapshot!(
                    times, energies, norms, mags, snapshots, ws, sys;
                    keep_psi=(!stream_snapshots),
                )

                if callbacks.on_snapshot !== nothing
                    psi_snap = stream_snapshots ? Array(ws.state.psi) : snapshots[end]
                    callbacks.on_snapshot(ws, step, psi_snap)
                end
            end

            if need_split && !is_last
                _half_potential_step!(
                    ws, dt / 2, n_comp, N, false; t_eval=(ws.state.t + dt / 4), t_start=ws.state.t
                )
            end
        end
    catch e
        if e isa InterruptException
            # Close the open half-step so psi is in a valid Strang-split state
            _half_potential_step!(
                ws, dt / 2, n_comp, N, false; t_eval=(ws.state.t + dt / 4), t_start=ws.state.t
            )
            _record_snapshot!(
                times, energies, norms, mags, snapshots, ws, sys;
                keep_psi=(!stream_snapshots),
            )
            println(
                "\n  Simulation interrupted at step $(ws.state.step)/$(sp.n_steps), t=$(round(ws.state.t; sigdigits=6))"
            )
            println(
                "  Final snapshot saved. Use run_simulation_checkpointed! with resume=true to continue."
            )
            flush(stdout)
        else
            rethrow(e)
        end
    end
end

function run_simulation_checkpointed!(
    ws::Workspace{N};
    checkpoint_dir::String="checkpoints",
    checkpoint_every::Int=1000,
    callback::Union{Nothing, Function}=nothing,
    callbacks::Union{Nothing, SimulationCallbacks}=nothing,
    resume::Bool=false,
) where {N}
    mkpath(checkpoint_dir)

    if resume
        existing = filter(
            f -> startswith(basename(f), "step_") && endswith(f, ".jld2"),
            readdir(checkpoint_dir; join=true),
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
    remaining <= 0 && return run_simulation!(ws; callback, callbacks)

    # Create checkpoint callback compatible with new signature
    checkpoint_callbacks = SimulationCallbacks(;
        on_snapshot=function (ws_cb, step, snapshot)
            global_step = start_step + step
            if global_step % checkpoint_every == 0
                fname = joinpath(checkpoint_dir, "step_$(lpad(global_step, 8, '0')).jld2")
                save_state(fname, ws_cb)
            end
            # Call user's old-style callback if provided (backward compatibility)
            if callback !== nothing
                callback(ws_cb, step)
            end
            # Call user's new callbacks if provided
            if callbacks !== nothing && callbacks.on_snapshot !== nothing
                callbacks.on_snapshot(ws_cb, step, snapshot)
            end
        end,
        on_step=callbacks !== nothing ? callbacks.on_step : nothing,
        on_complete=callbacks !== nothing ? callbacks.on_complete : nothing,
    )

    sp_orig = ws.sim_params
    sp_remain = SimParams(
        sp_orig.dt,
        remaining,
        sp_orig.imaginary_time,
        sp_orig.normalize_every,
        sp_orig.save_every,
    )

    ws_remain = _rebuild_workspace(ws; sim_params=sp_remain)

    result = run_simulation!(ws_remain; callbacks=checkpoint_callbacks)

    ws.state.t = ws_remain.state.t
    ws.state.step = start_step + remaining
    copyto!(ws.state.psi, ws_remain.state.psi)

    result
end
