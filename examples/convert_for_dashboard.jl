using JLD2

# This script converts a ground state JLD2 file into a format
# compatible with the visualize_dashboard.jl script, by presenting
# the single ground state as a single-frame time evolution.

# 1. Load the original ground state data
source_path = "output/eu151_ground_state_large.jld2"
source_data = jldopen(source_path, "r")

# 2. Create a new dictionary for the target data structure
target_data = Dict{String, Any}()

# 3. Copy metadata, but override grid_box_size to "zoom in"
for key in keys(source_data)
    if key != "psi" && key != "grid_box_size" # Exclude keys to be handled separately
        target_data[key] = source_data[key]
    end
end
# Manually set the grid_box_size to half its original value for zooming
original_box_size = source_data["grid_box_size"]
target_data["grid_box_size"] = original_box_size ./ 2.0


# 4. Create a dummy "phase" structure with a single time step
target_data["phase_names"] = ["Ground State"]
target_data["phase_1_times"] = [0.0]
target_data["phase_1_psi_snapshots"] = [source_data["psi"]]
target_data["phase_1_zeeman"] = [
    get(source_data, "gs_zeeman_p", 0.0),
    get(source_data, "gs_zeeman_p", 0.0),
    get(source_data, "gs_zeeman_q", 0.0),
    get(source_data, "gs_zeeman_q", 0.0)
]
target_data["phase_1_duration"] = 0.0

# 5. Write to a new JLD2 file with a new name
target_path = "output/eu151_ground_state_zoomed_for_dashboard.jld2"
jldopen(target_path, "w") do f
    for (k, v) in target_data
        f[k] = v
    end
end

println("Successfully converted data for dashboard: $(target_path)")

close(source_data)
