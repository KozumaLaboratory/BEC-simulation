# Real-time simulation monitoring

using JSON

"""
    LiveMonitor

Real-time simulation monitor that exports data to JSON or WebSocket.

# Fields
- `output_file::Union{Nothing, String}`: JSON file path for output
- `update_interval::Int`: Minimum steps between updates
- `last_update_step::Int`: Last updated step (internal state)
- `extract_observables::Function`: Custom observable extraction function

# Example
```julia
monitor = LiveMonitor(
    output_file="live_data.json",
    update_interval=50
)

ws = make_workspace(...)
result = run_simulation!(ws, live_monitor=monitor)
```
"""
mutable struct LiveMonitor
    output_file::Union{Nothing, String}
    update_interval::Int
    last_update_step::Int
    extract_observables::Function

    function LiveMonitor(;
        output_file::Union{Nothing, String}=nothing,
        update_interval::Int=10,
        extract_observables::Function=default_observable_extractor,
    )
        new(output_file, update_interval, 0, extract_observables)
    end
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
    # Throttle updates
    if step - monitor.last_update_step < monitor.update_interval
        return nothing
    end
    monitor.last_update_step = step

    # Extract observables
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
