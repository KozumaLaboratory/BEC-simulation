# Public simulation entry points:
#   run_simulation!               — dispatch between standard / leapfrog
#   run_simulation_checkpointed!  — resumable JLD2-checkpointed wrapper

export run_simulation!, run_simulation_checkpointed!

"""
    run_simulation!(ws::Workspace; callbacks=nothing)

Run time evolution simulation with optional event-driven monitoring.

# Arguments
- `ws::Workspace`: Simulation workspace
- `callbacks::Union{Nothing,SimulationCallbacks}`: Event-driven callbacks

# Returns
- `SimulationResult`: Times, energies, norms, magnetizations, and snapshots

# Example
```julia
# Basic usage
result = run_simulation!(ws)

# Dashboard JSON push — plain on_step callback
callbacks = SimulationCallbacks(
    on_step = (ws, step, times, energies) -> begin
        step % 50 == 0 || return nothing
        open("live_data.json", "w") do f
            JSON.print(f, Dict("step"=>step, "t"=>ws.state.t,
                "E"=>(isempty(energies) ? NaN : energies[end])))
        end
    end,
    on_snapshot = (ws, step, snapshot) -> save_debug("snapshot_\$step.jld2", snapshot),
)
result = run_simulation!(ws, callbacks=callbacks)
```
"""
function run_simulation!(
    ws::Workspace{N};
    callbacks::Union{Nothing, SimulationCallbacks}=nothing,
    stream_snapshots::Bool=false,
) where {N}
    sp = ws.sim_params
    sys = ws.spin_matrices.system
    it = sp.imaginary_time

    cbs = callbacks === nothing ? SimulationCallbacks() : callbacks

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
            cbs;
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
            cbs;
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

function run_simulation_checkpointed!(
    ws::Workspace{N};
    checkpoint_dir::String="checkpoints",
    callbacks::Union{Nothing, SimulationCallbacks}=nothing,
    resume::Bool=false,
) where {N}
    # Unified observation cadence (2026-06-04): disk checkpoint fires at
    # `sim_params.save_every`, same as every other observation sink
    # (callbacks, live monitor). The separate `checkpoint_every` knob was
    # dropped because it duplicated `save_every` and the cost asymmetry
    # (disk I/O vs. callback cost) is small at typical cadences.
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
    remaining <= 0 && return run_simulation!(ws; callbacks)

    # Compose user callbacks (if any) with the checkpoint snapshot writer.
    checkpoint_callbacks = SimulationCallbacks(;
        on_snapshot=function (ws_cb, step, snapshot)
            global_step = start_step + step
            fname = joinpath(checkpoint_dir, "step_$(lpad(global_step, 8, '0')).jld2")
            save_state(fname, ws_cb)
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
        sp_orig.rotating_frame_omega,
        sp_orig.spin_rotating_frame_omega,
    )

    ws_remain = _rebuild_workspace(ws; sim_params=sp_remain)

    result = run_simulation!(ws_remain; callbacks=checkpoint_callbacks)

    ws.state.t = ws_remain.state.t
    ws.state.step = start_step + remaining
    copyto!(ws.state.psi, ws_remain.state.psi)

    result
end
