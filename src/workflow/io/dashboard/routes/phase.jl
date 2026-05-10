# Phase route handlers (2D + binary + 3D binary)
#
# Extracted from src/workflow/io/dashboard/routes.jl in the 2026-05-09
# refactor. Loaded by SpinorBEC.jl after route_helpers.jl + cache.jl.

function _route_phase3d_bin(path::String, base_dir::String, psi_cache::Dict{String, Any})
    # /api/phase3d_bin/:run/:file?comp=N&snap=K (N >= 1)
    p = _parse_run_file(path, "/api/phase3d_bin/")
    p === nothing && return (
        400, "text/plain", "Expected /api/phase3d_bin/:run/:file?comp=N&snap=K"
    )
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    comp_idx = _q_int(p.query, "comp", 1)
    snap_idx = _q_int_opt(p.query, "snap")
    bin = try
        _compute_3d_phase_binary(
            _load_psi_cached(fpath, psi_cache, snap_idx)...; component=comp_idx
        )
    catch e
        return (500, "text/plain", "Error: $(e)")
    end
    (200, "application/octet-stream", bin)
end

function _route_phase2d(path::String, base_dir::String, psi_cache::Dict{String, Any})
    # /api/phase/:run/:file?axis=N&slice=K&snap=S
    p = _parse_run_file(path, "/api/phase/")
    p === nothing &&
        return (400, "text/plain", "Expected /api/phase/:run/:file?axis=N&slice=K")
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    axis = _q_int(p.query, "axis", 3)
    slice_idx = _q_int_opt(p.query, "slice")
    snap_idx = _q_int_opt(p.query, "snap")
    json = try
        cached = _load_psi_cached(fpath, psi_cache, snap_idx)
        _json_string(_compute_phase_slice_from_cache(cached..., axis, slice_idx, fpath))
    catch e
        "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
    end
    (200, "application/json", json)
end

function _route_phase_bin(path::String, base_dir::String, psi_cache::Dict{String, Any})
    # /api/phase_bin/:run/:file?axis=N&slice=K&snap=S — packed Float32
    # phase + |ψ_m|² for low-density masking. Same speed motivation as
    # density_bin.
    p = _parse_run_file(path, "/api/phase_bin/")
    p === nothing && return (400, "text/plain", "Expected /api/phase_bin/:run/:file")
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    axis = _q_int(p.query, "axis", 3)
    slice_idx = _q_int_opt(p.query, "slice")
    snap_idx = _q_int_opt(p.query, "snap")
    cache_key = "phase_bin:$(fpath)#snap=$(snap_idx)#axis=$(axis)#slice=$(slice_idx)"
    bin = if haskey(psi_cache, cache_key)
        psi_cache[cache_key]
    else
        while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
            _evict_one!(psi_cache)
        end
        v = try
            _compute_phase_slice_binary(
                _load_psi_cached(fpath, psi_cache, snap_idx)...,
                axis, slice_idx, fpath,
            )
        catch e
            return (500, "text/plain", "Error: $(e)")
        end
        psi_cache[cache_key] = v
        v
    end
    (200, "application/octet-stream", bin)
end
