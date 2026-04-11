#!/usr/bin/env julia
# Event-driven simulation demonstration

using SpinorBEC

# Simple test: F=1 BEC with callbacks
println("Event-driven simulation demo")
println("=" ^60)

# Create workspace
grid_config = GridConfig((16, 16, 16), (8.0, 8.0, 8.0))
grid = make_grid(grid_config)
ws = make_workspace(
    F = 1,
    grid = grid,
    n_steps = 100,
    dt = 0.01,
    save_every = 20,
    c0 = 100.0,
    c1 = -0.5,
    imaginary_time = false,
)

# Initialize
init_psi(ws, :gaussian)

println("\n1. Basic callback demo")
println("-" ^60)

step_count = Ref(0)
callbacks = SimulationCallbacks(
    on_step = (ws, step, times, energies) -> begin
        step_count[] += 1
        if step % 20 == 0
            E = length(energies) > 0 ? energies[end] : total_energy(ws)
            println("  Step $step: E = $(round(E, sigdigits=6))")
        end
    end,
    on_snapshot = (ws, step, snapshot) -> begin
        n = sum(abs2, snapshot)
        println("  → Snapshot at step $step: norm = $(round(n, digits=4))")
    end,
    on_complete = (ws, result) -> begin
        println("  ✓ Simulation complete!")
        println("    Total steps executed: $(step_count[])")
        println("    Snapshots saved: $(length(result.times))")
    end
)

result = run_simulation!(ws, callbacks=callbacks)

println("\n2. Live monitor demo")
println("-" ^60)

# Create live monitor
monitor = LiveMonitor(
    output_file = "demo_live_data.json",
    update_interval = 25
)

println("  Running with LiveMonitor (update every 25 steps)...")
result2 = run_simulation!(ws, live_monitor=monitor)

# Check output
if isfile("demo_live_data.json")
    using JSON
    data = JSON.parsefile("demo_live_data.json")
    println("  ✓ Live data saved to demo_live_data.json")
    println("    Last step: $(data["step"])")
    println("    Last time: $(round(data["time"], digits=4))")
    println("    Energy: $(round(data["observables"]["energy"], sigdigits=6))")
    rm("demo_live_data.json")
else
    println("  ⚠ No live data file created")
end

println("\n3. Custom observable extractor")
println("-" ^60)

custom_monitor = LiveMonitor(
    output_file = "demo_custom.json",
    update_interval = 30,
    extract_observables = ws -> begin
        Dict(
            "energy" => total_energy(ws),
            "norm" => total_norm(ws.state.psi, ws.grid),
            "magnetization" => magnetization(ws.state.psi, ws.grid, ws.spin_matrices.system),
            "custom_metric" => sum(abs2, ws.state.psi) * ws.state.t
        )
    end
)

result3 = run_simulation!(ws, live_monitor=custom_monitor)

if isfile("demo_custom.json")
    using JSON
    data = JSON.parsefile("demo_custom.json")
    println("  ✓ Custom observables extracted:")
    for (key, val) in data["observables"]
        println("    - $key: $(round(val, sigdigits=6))")
    end
    rm("demo_custom.json")
end

println("\n" * "=" ^60)
println("Demo complete!")
