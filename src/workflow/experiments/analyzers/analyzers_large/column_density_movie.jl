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

    history = get(pipeline_results, :dynamics_history, nothing)
    if multi_step
        history === nothing && throw(
            ArgumentError(
                "column_density_movie multi_step=true requires preceding dynamics steps"),
        )
        sources = collect(history)
    else
        dynres = get(pipeline_results, :dynamics_result, nothing)
        dynres === nothing && throw(
            ArgumentError(
                "column_density_movie requires a preceding dynamics step with save_every > 0"
            ),
        )
        sources = [(
            dynamics_result=dynres,
            snapshot_tmp_path=get(pipeline_results, :snapshot_tmp_path, nothing),
            save_psi_snapshots=get(pipeline_results, :save_psi_snapshots, false),
            snapshot_count=get(pipeline_results, :snapshot_count, 0),
        )]
    end

    archive_path = joinpath(output_dir, "columns.jld2")
    manifest_path = joinpath(output_dir, "manifest.json")
    frame_keys = String[]
    frame_times = Float64[]
    frame_phases = Int[]
    global_idx = 0
    t_offset = 0.0
    jldopen(archive_path, "w") do out
        for (phase_idx, src) in enumerate(sources)
            dr = src.dynamics_result
            dr === nothing && continue
            tmp = src.snapshot_tmp_path
            saved = src.save_psi_snapshots
            times = dr.times
            if saved && tmp !== nothing && isfile(tmp)
                jldopen(tmp, "r") do jh
                    n_snaps = Int(jh["n_snapshots"])
                    t_max = min(length(times), n_snaps)
                    for i in 1:t_max
                        global_idx += 1
                        skey = "frame_" * lpad(string(i), 5, '0')
                        frame = jh[skey]
                        n_total = total_density(frame, ndim)
                        col = dropdims(sum(n_total; dims=axis); dims=axis)
                        okey = "frame_" * lpad(string(global_idx), 5, '0')
                        out[okey] = Float32.(col)
                        push!(frame_keys, okey)
                        push!(frame_times, times[i] + t_offset)
                        push!(frame_phases, phase_idx)
                    end
                end
            elseif hasproperty(dr, :psi_snapshots)
                for (i, psi_s) in enumerate(dr.psi_snapshots)
                    global_idx += 1
                    n_total = total_density(psi_s, ndim)
                    col = dropdims(sum(n_total; dims=axis); dims=axis)
                    okey = "frame_" * lpad(string(global_idx), 5, '0')
                    out[okey] = Float32.(col)
                    push!(frame_keys, okey)
                    push!(frame_times, times[i] + t_offset)
                    push!(frame_phases, phase_idx)
                end
            end
            t_offset += isempty(times) ? 0.0 : times[end] - times[1]
        end
        out["n_frames"] = global_idx
        out["axis"] = axis
    end
    manifest = Dict{String, Any}(
        "n_frames" => global_idx,
        "axis" => axis,
        "n_phases" => multi_step ? length(sources) : 1,
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
