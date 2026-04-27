#!/usr/bin/env julia
# Translate rotating_basis pipeline output to dashboard-compatible JLD2 layout.
#
# Source: <run_dir>/result.jld2 with top-level `psi_snapshots`, `times`, etc.
# Target: <run_dir>/result.jld2 (overwritten) with:
#   - psi                              (top-level: GS state = first snapshot)
#   - dynamics/times
#   - dynamics/psi_snapshots           (legacy 5D, stacked on last axis)
#
# The dashboard's snapshot reader auto-detects this format.
#
# Usage: julia --project=. scripts/dashboard_repack_rotating_basis.jl <run_dir>

using JLD2
using Printf

length(ARGS) >= 1 || error("Usage: julia ... <run_dir>")
run_dir = ARGS[1]
src_file = joinpath(run_dir, "result.jld2")
isfile(src_file) || error("missing: $src_file")

# Read all top-level keys
data = JLD2.load(src_file)
times = data["times"]::Vector{Float64}
snaps = data["psi_snapshots"]::Vector
isempty(snaps) && error("No psi_snapshots in source file")

sample = snaps[1]
Nx, Ny, Nz, D = size(sample)
n_frames = length(snaps)
@printf "Source: %s\n" src_file
@printf "  Frames: %d, shape: %d×%d×%d×%d (D=%d, F=%d)\n" n_frames Nx Ny Nz D D ((D-1)÷2)
@printf "  Times: %.3f → %.3f\n" times[1] times[end]

# Save in dashboard-compatible STREAMED layout. The streamed path is what the
# dashboard's density_max + per-frame fetchers already support.
# Each frame stored as `dynamics/psi_snapshots_streamed/frame_NNNNN`.
out_file = joinpath(run_dir, "result_dashboard.jld2")
@printf "Writing streamed layout to %s...\n" out_file
JLD2.jldopen(out_file, "w") do f
    f["psi"] = sample
    f["dynamics/times"] = times
    f["dynamics/psi_snapshots_streamed/n_snapshots"] = n_frames
    f["dynamics/psi_snapshots_streamed/spatial_shape"] = collect(Int, (Nx, Ny, Nz))
    f["dynamics/psi_snapshots_streamed/n_components"] = D
    @inbounds for k in 1:n_frames
        key = "dynamics/psi_snapshots_streamed/frame_" * lpad(string(k), 5, '0')
        f[key] = snaps[k]
    end

    # Pass through other useful keys for the dashboard endpoints
    if haskey(data, "norms")
        f["dynamics/norms"] = data["norms"]
    end
    if haskey(data, "Lz")
        f["dynamics/Lz"] = data["Lz"]
    end
    if haskey(data, "Fz")
        f["dynamics/Fz"] = data["Fz"]
    end
    if haskey(data, "per_m_history")
        f["dynamics/per_m_history"] = data["per_m_history"]
    end
end

@printf "✅ Wrote %s (%.1f MB)\n" out_file (filesize(out_file) / 2^20)

# Activate immediately: rename existing result.jld2 → result_legacy.jld2,
# move dashboard repack into result.jld2, and create point_001.jld2 symlink
# (dashboard expects point_NNN.jld2 to populate the run list).
existing = joinpath(run_dir, "result.jld2")
legacy = joinpath(run_dir, "result_legacy.jld2")
point1 = joinpath(run_dir, "point_001.jld2")
if isfile(existing) && !islink(existing)
    if !isfile(legacy)
        mv(existing, legacy)
        @printf "Renamed result.jld2 → result_legacy.jld2 (preserves analyzer-format raw data)\n"
    else
        rm(existing)
    end
end
mv(out_file, existing)
@printf "Activated dashboard layout at %s\n" existing
if !ispath(point1)
    symlink("result.jld2", point1)
    @printf "Created symlink point_001.jld2 → result.jld2 for dashboard run-list\n"
end
@printf "\n→ Open http://localhost:8765 and select the run from the list.\n"
