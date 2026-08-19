# Event-driven callbacks + per-step bookkeeping helpers used by both
# the standard and leapfrog-fused simulation loops.

export SimulationCallbacks

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
    on_complete=nothing,
) = SimulationCallbacks{typeof(on_step), typeof(on_snapshot), typeof(on_complete)}(
    on_step, on_snapshot, on_complete)

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
    E_per_N = E_now / max(nrm_now, UNDERFLOW_FLOOR)
    if length(energies) >= 2
        E_per_N_prev = energies[end] / max(norms[end], UNDERFLOW_FLOOR)
        de_rel = abs(E_per_N - E_per_N_prev) / max(abs(E_per_N_prev), UNDERFLOW_FLOOR)
        if de_rel > 0.01
            @warn "E/N drift $(round(de_rel*100, digits=2))% between snapshots at t=$(round(t, digits=4))"
        end
    end
end
