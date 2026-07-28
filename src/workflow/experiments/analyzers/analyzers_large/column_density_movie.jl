function _analyze_column_density_movie(psi, grid, atom, params, ws_prev,
    pipeline_results=Dict{Symbol, Any}())
    # Streams per-snapshot column densities into a single JLD2 archive
    # (`columns.jld2` with one Float32 2D array per frame, key
    # `frame_NNNNN`) and writes a JSON manifest with frame times + axis
    # metadata. The dashboard / external notebooks render frames; we no
    # longer ship PNGs (PlotlyJS dependency removed).
    #
    # Two snapshot sources supported, same as before:
    #   1. Streamed scratch JLD2 (preferred for long runs).
    #   2. Legacy in-memory `dynres.psi_snapshots`.
    # `multi_step: true` walks every preceding dynamics phase.
    ndim = length(grid.config.n_points)
    ndim == 3 || throw(ArgumentError(
        "column_density_movie currently supports 3D only (got $(ndim)D)"))
    axis = Int(get(params, "axis", 3))
    output_dir = String(get(params, "output_dir", "frames"))
    mkpath(output_dir)
    multi_step = Bool(get(params, "multi_step", false))

    archive_path = joinpath(output_dir, "columns.jld2")
    manifest_path = joinpath(output_dir, "manifest.json")
    frame_keys = String[]
    frame_times = Float64[]
    frame_phases = Int[]
    global_idx = 0
    jldopen(archive_path, "w") do out
        _each_dynamics_snapshot(pipeline_results, multi_step,
            "column_density_movie") do frame, t, phase_idx
            global_idx += 1
            n_total = total_density(frame, ndim)
            col = dropdims(sum(n_total; dims=axis); dims=axis)
            okey = "frame_" * lpad(string(global_idx), 5, '0')
            out[okey] = Float32.(col)
            push!(frame_keys, okey)
            push!(frame_times, t)
            push!(frame_phases, phase_idx)
        end
        out["n_frames"] = global_idx
        out["axis"] = axis
    end
    n_phases = _n_dynamics_phases(pipeline_results, multi_step)
    manifest = Dict{String, Any}(
        "n_frames" => global_idx,
        "axis" => axis,
        "n_phases" => n_phases,
        "frame_keys" => frame_keys,
        "times" => frame_times,
        "phase_indices" => frame_phases,
        "archive" => basename(archive_path),
    )
    open(manifest_path, "w") do io
        JSON.print(io, manifest)
    end
    (output_dir=output_dir, n_frames=global_idx,
        archive_path=archive_path, manifest_path=manifest_path,
        axis=axis, n_phases=multi_step ? length(sources) : 1)
end
