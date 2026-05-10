# Misc dashboard handlers (data / coherence / vector3d_bin)
#
# Extracted from src/workflow/io/dashboard/routes.jl in the 2026-05-09
# refactor. Loaded by SpinorBEC.jl after route_helpers.jl + cache.jl.

function _route_coherence(path::String, base_dir::String, psi_cache::Dict{String, Any})
    p = _parse_run_file(path, "/api/coherence/")
    p === nothing &&
        return (400, "text/plain", "Expected /api/coherence/:run/:file?axis=N")
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    axis = _q_int(p.query, "axis", 3)
    bin = try
        _compute_coherence_matrix_binary(_load_psi_cached(fpath, psi_cache)..., axis)
    catch e
        return (500, "text/plain", "Error: $(e)")
    end
    (200, "application/octet-stream", bin)
end

function _route_vector3d_bin(path::String, base_dir::String, psi_cache::Dict{String, Any})
    p = _parse_run_file(path, "/api/vector3d_bin/")
    p === nothing && return (
        400,
        "text/plain",
        "Expected /api/vector3d_bin/:run/:file?field=current&stride=2&snap=K",
    )
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    vec_field = _q_sym(p.query, "field", :current)
    vec_stride = _q_int(p.query, "stride", 2)
    snap_idx = _q_int_opt(p.query, "snap")
    bin = try
        psi, n_comp, ndim, n_pts, F = _load_psi_cached(fpath, psi_cache, snap_idx)
        ndim == 3 || throw(ArgumentError("vector3d requires 3D data"))
        box_size = _load_box_size(fpath)
        _compute_vector3d_binary(psi, n_comp, ndim, n_pts, F, box_size;
            field=vec_field, stride=vec_stride)
    catch e
        return (500, "text/plain", "Error: $(e)")
    end
    (200, "application/octet-stream", bin)
end

function _route_data(path::String, base_dir::String, data_cache::Dict{String, String})
    p = _parse_run_only(path, "/api/data/")
    run_dir = joinpath(base_dir, p.name)
    isdir(run_dir) || return (404, "text/plain", "Run not found: $(p.name)")
    name = p.name  # used in cache key + downstream
    # Cache only completed runs. In-progress runs (no point_*.jld2 yet,
    # or whose point file count differs from a prior cache hit) bypass
    # the cache so the dashboard reflects new files as the batch lands
    # them. Without this guard the first request during a run cached
    # the empty in-progress response and the dashboard never updated
    # even after `point_001.jld2` appeared on disk.
    live_count = count(f -> startswith(f, "point_") && endswith(f, ".jld2"),
        readdir(run_dir))
    cache_key = "$name#$live_count"
    json = get!(data_cache, cache_key) do
        try
            _json_string(generate_dashboard_data(run_dir))
        catch e
            "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
        end
    end
    (200, "application/json", json)
end
