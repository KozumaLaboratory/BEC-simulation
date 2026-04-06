#!/usr/bin/env julia
# Real-time simulation monitor
# Reads latest checkpoint and generates JSON for web dashboard

using JLD2, JSON
using Dates

function find_latest_checkpoint(output_dir)
    checkpoint_dir = joinpath(output_dir, "checkpoints")
    isdir(checkpoint_dir) || return nothing

    files = filter(f -> endswith(f, ".jld2"), readdir(checkpoint_dir, join=true))
    isempty(files) && return nothing

    # Sort by modification time, get latest
    latest = argmax(f -> stat(f).mtime, files)
    return files[latest]
end

function extract_monitor_data(checkpoint_path, output_path)
    jld = jldopen(checkpoint_path, "r")

    # Get metadata
    F = jld["F"]
    D = 2*F + 1
    grid_size = jld["grid_n_points"]
    nx, ny, nz = grid_size
    z_center = div(nz, 2) + 1

    # Get current state
    psi = jld["psi"]
    step = jld["step"]
    time = jld["time"]

    # Compute populations
    n_total = sum(abs2, psi)
    populations = Float64[]
    for c in 1:D
        pop = sum(abs2, psi[:,:,:,c]) / n_total
        push!(populations, pop)
    end

    # Compute 2D density slices (z=center)
    density_slices = []
    for c in 1:D
        slice_2d = psi[:, :, z_center, c]
        density = abs2.(slice_2d)
        push!(density_slices, density)
    end

    # Create output data
    monitor_data = Dict(
        "timestamp" => now(),
        "step" => step,
        "time" => time,
        "F" => F,
        "grid_size" => [nx, ny],
        "populations" => populations,
        "density_slices" => density_slices,
        "checkpoint_file" => basename(checkpoint_path)
    )

    close(jld)

    # Write to JSON
    open(output_path, "w") do f
        JSON.print(f, monitor_data, 2)
    end

    println("✓ Monitor data updated: step=$step, t=$(round(time, digits=3))")
    return true
end

function monitor_loop(output_dir, json_path; interval=5)
    println("Starting real-time monitor...")
    println("Output dir: $output_dir")
    println("JSON output: $json_path")
    println("Update interval: $(interval)s")
    println()

    last_checkpoint = nothing

    while true
        try
            checkpoint = find_latest_checkpoint(output_dir)

            if checkpoint !== nothing && checkpoint != last_checkpoint
                extract_monitor_data(checkpoint, json_path)
                last_checkpoint = checkpoint
            end

            sleep(interval)
        catch e
            println("Error: $e")
            sleep(interval)
        end
    end
end

# Main
if length(ARGS) < 1
    println("Usage: julia live_monitor.jl <output_dir> [json_path] [interval]")
    exit(1)
end

output_dir = ARGS[1]
json_path = length(ARGS) >= 2 ? ARGS[2] : "live_monitor_data.json"
interval = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 5

monitor_loop(output_dir, json_path; interval)
