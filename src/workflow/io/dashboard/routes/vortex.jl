# Vortex / vorticity route handlers
#
# Extracted from src/workflow/io/dashboard/routes.jl in the 2026-05-09
# refactor. Loaded by SpinorBEC.jl after route_helpers.jl + cache.jl.

function _route_vortex_lines(path::String, base_dir::String, psi_cache::Dict{String, Any})
    # /api/vortex_lines/:run/:file?snap=K&mask=FRAC  → per-m polylines
    p = _parse_run_file(path, "/api/vortex_lines/")
    p === nothing && return (
        400, "text/plain", "Expected /api/vortex_lines/:run/:file?snap=K&mask=FRAC"
    )
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    snap_idx = _q_int_opt(p.query, "snap")
    mask_frac = _q_float(p.query, "mask", 0.0)
    # Cache key: (file, snap, mask). Identical scrub-replay returns
    # instantly from cache instead of re-running the per-plaquette
    # phase-winding scan + greedy z-stitch (sub-second per call but
    # the scrubber fires many in rapid succession).
    cache_key = "vortex_lines:$(fpath)#snap=$(snap_idx)#mask=$(mask_frac)"
    json = if haskey(psi_cache, cache_key)
        psi_cache[cache_key]
    else
        # Reuse the same FIFO cap as ψ snapshots to keep RAM bounded.
        while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
            _evict_one!(psi_cache)
        end
        json_str = try
            psi, n_comp, ndim, n_pts, F = _load_psi_cached(fpath, psi_cache, snap_idx)
            ndim == 3 || throw(ArgumentError("vortex_lines requires 3D data"))
            box_size = _load_box_size(fpath)
            g = make_grid(GridConfig(n_pts, box_size))
            lines = extract_vortex_lines_per_m(psi, g; min_density_frac=mask_frac)
            # Flatten into a frontend-friendly list [{m, charge, points}, ...]
            out_lines = Dict{String, Any}[]
            for (m_label, polylines) in lines
                for ln in polylines
                    push!(
                        out_lines,
                        Dict{String, Any}(
                            "m" => m_label,
                            "charge" => ln.charge,
                            "points" => [[p[1], p[2], p[3]] for p in ln.points],
                        ),
                    )
                end
            end
            _json_string(
                Dict{String, Any}(
                    "lines" => out_lines,
                    "box" => collect(Float64.(box_size)),
                    "n_lines" => length(out_lines),
                ),
            )
        catch e
            "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
        end
        psi_cache[cache_key] = json_str
        json_str
    end
    (200, "application/json", json)
end

function _route_vorticity3d_bin(path::String, base_dir::String, psi_cache::Dict{String, Any})
    # /api/vorticity3d_bin/:run/:file?snap=K
    p = _parse_run_file(path, "/api/vorticity3d_bin/")
    p === nothing && return (
        400, "text/plain", "Expected /api/vorticity3d_bin/:run/:file?snap=K"
    )
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    snap_idx = _q_int_opt(p.query, "snap")
    bin = try
        psi, n_comp, ndim, n_pts, F = _load_psi_cached(fpath, psi_cache, snap_idx)
        ndim == 3 || throw(ArgumentError("vorticity3d requires 3D data"))
        box_size = _load_box_size(fpath)
        _compute_3d_vorticity_binary(psi, n_comp, ndim, n_pts, F, box_size)
    catch e
        return (500, "text/plain", "Error: $(e)")
    end
    (200, "application/octet-stream", bin)
end
