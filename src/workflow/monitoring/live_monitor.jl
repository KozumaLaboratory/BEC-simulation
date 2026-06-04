# Real-time simulation monitoring

export LiveMonitor

using JSON

"""
    LiveMonitor

Real-time simulation monitor that exports data to JSON or WebSocket.
Fires at the workspace's `sim_params.save_every` cadence (unified
observation cadence, 2026-06-04) — no separate `update_interval`.

# Fields
- `output_file::Union{Nothing, String}`: JSON file path for output
- `extract_observables::Function`: Custom observable extraction function

# Example
```julia
monitor = LiveMonitor(output_file="live_data.json")
ws = make_workspace(...)   # sim_params controls cadence
result = run_simulation!(ws, live_monitor=monitor)
```
"""
mutable struct LiveMonitor{F}
    output_file::Union{Nothing, String}
    extract_observables::F
end

# Parameterising on F<:Function (instead of an abstract `::Function` field)
# means `monitor.extract_observables(ws)` is statically dispatched.
function LiveMonitor(;
    output_file::Union{Nothing, String}=nothing,
    extract_observables::F=default_observable_extractor,
    update_interval=nothing,  # deprecated alias; warns
) where {F <: Function}
    if update_interval !== nothing
        @warn "LiveMonitor `update_interval` is removed (2026-06-04 unification). " *
            "Cadence now follows `sim_params.save_every`. Ignoring update_interval=$update_interval." maxlog=1
    end
    LiveMonitor{F}(output_file, extract_observables)
end

"""
Default observable extractor for LiveMonitor.
Returns basic observables: populations, energy, norm.
"""
function default_observable_extractor(ws::Workspace)
    Dict{String, Any}(
        "energy" => total_energy(ws),
        "norm" => total_norm(ws.state.psi, ws.grid),
        "populations" => compute_populations(ws),
    )
end

"""
    update!(monitor::LiveMonitor, ws::Workspace, step::Int)

Update live monitor with current simulation state.
Writes data to JSON file if configured.
"""
function update!(monitor::LiveMonitor, ws::Workspace{N}, step::Int) where {N}
    # No throttle here — caller (run_simulation!) only invokes update!
    # at sim_params.save_every cadence. Single observation knob.
    observables = monitor.extract_observables(ws)

    # Build data structure
    data = Dict{String, Any}(
        "step" => step,
        "time" => ws.state.t,
        "observables" => observables,
        "timestamp" => time(),
    )

    # Write to JSON
    if monitor.output_file !== nothing
        open(monitor.output_file, "w") do f
            JSON.print(f, data, 2)
        end
    end

    return data
end

"""
Helper to compute population fractions for all components.
"""
function compute_populations(ws::Workspace{N}) where {N}
    psi = ws.state.psi
    D = size(psi, N + 1)  # Last dimension is component
    n_total = sum(abs2, psi)

    pops = Float64[]
    for c in 1:D
        # Simple slicing: all spatial dims, specific component
        pop = sum(abs2, selectdim(psi, N + 1, c)) / n_total
        push!(pops, pop)
    end

    return pops
end
