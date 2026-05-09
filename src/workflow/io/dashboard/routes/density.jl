# Density route handlers (2D/3D + binary + atlas + max + rotated)
#
# Extracted from src/workflow/io/dashboard/routes.jl in the 2026-05-09
# refactor. Loaded by SpinorBEC.jl after route_helpers.jl + cache.jl.

function _route_density_max(path::String, base_dir::String, psi_cache::Dict{String, Any})
    # /api/density_max/:run/:file → {"density_max_total": float}
    # Lazy version of the field that used to live in /api/snapshots.
    # The 16-frame walk takes ~0.8 s on Klaus and stalled the
    # initial run-open hop; computing it on demand keeps that hop
    # instant. Cached server-side so repeat calls are sub-ms.
    p = _parse_run_file(path, "/api/density_max/")
    p === nothing && return (400, "text/plain", "Expected /api/density_max/:run/:file")
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    cache_key = "density_max:$(fpath)"
    d_max = if haskey(psi_cache, cache_key)
        psi_cache[cache_key]
    else
        v = try
            jldopen(fpath, "r") do f
                if haskey(f, "dynamics/psi_snapshots_streamed/n_snapshots")
                    n = Int(f["dynamics/psi_snapshots_streamed/n_snapshots"])
                    n == 0 ? 1.0 : _global_density_max_total_sampled(f, n; n_samples=16)
                elseif haskey(f, "dynamics/psi_snapshots")
                    # Legacy 5D layout — sample frames directly
                    snaps = f["dynamics/psi_snapshots"]
                    nframes = size(snaps, ndims(snaps))
                    nframes == 0 && return 1.0
                    # Sample up to 16 frames; for legacy 5D the array IS in
                    # memory, so just compute peak per frame quickly.
                    sample_idxs = if nframes ≤ 16
                        (1:nframes)
                    else
                        Int.(round.(range(1, nframes; length=16)))
                    end
                    gmax = 0.0
                    spatial_dims = ndims(snaps) - 2  # (Nx,Ny,Nz, D, n)
                    for k in sample_idxs
                        idx = ntuple(d -> d == ndims(snaps) ? k : Colon(),
                            ndims(snaps))
                        ψk = view(snaps, idx...)
                        # |ψ|² summed across components (last axis of slice)
                        local_max = 0.0
                        for I in CartesianIndices(ntuple(d -> size(ψk, d),
                            spatial_dims))
                            rho = 0.0
                            for c in 1:size(ψk, ndims(ψk))
                                rho += abs2(ψk[I, c])
                            end
                            rho > local_max && (local_max = rho)
                        end
                        local_max > gmax && (gmax = local_max)
                    end
                    gmax > 0 ? gmax : 1.0
                elseif haskey(f, "psi_snapshots")
                    # Top-level Vector{Array{Complex,4}} layout (saved by
                    # legacy launch_*.jl direct jldsave). Each element is
                    # an N+1-D array (spatial..., D); sample up to 16.
                    snaps = f["psi_snapshots"]
                    nframes = length(snaps)
                    nframes == 0 && return 1.0
                    sample_idxs = if nframes ≤ 16
                        (1:nframes)
                    else
                        Int.(round.(range(1, nframes; length=16)))
                    end
                    gmax = 0.0
                    for k in sample_idxs
                        ψk = snaps[k]
                        local_max = 0.0
                        spatial_dims = ndims(ψk) - 1
                        for I in CartesianIndices(ntuple(d -> size(ψk, d),
                            spatial_dims))
                            rho = 0.0
                            for c in 1:size(ψk, ndims(ψk))
                                rho += abs2(ψk[I, c])
                            end
                            rho > local_max && (local_max = rho)
                        end
                        local_max > gmax && (gmax = local_max)
                    end
                    gmax > 0 ? gmax : 1.0
                elseif haskey(f, "psi")
                    # Static-psi file (e.g. ground-state-only run, or a
                    # `_run_yaml_single` point_NNN.jld2 that only stores
                    # the final ψ). Compute the spin-summed peak density
                    # directly so the volume renderer can normalise.
                    psi = f["psi"]
                    spatial_dims = ndims(psi) - 1
                    D = size(psi, ndims(psi))
                    gmax = 0.0
                    for I in CartesianIndices(ntuple(d -> size(psi, d), spatial_dims))
                        rho = 0.0
                        for c in 1:D
                            rho += abs2(psi[I, c])
                        end
                        rho > gmax && (gmax = rho)
                    end
                    gmax > 0 ? gmax : 1.0
                else
                    1.0
                end
            end
        catch
            1.0
        end
        while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
            _evict_one!(psi_cache)
        end
        psi_cache[cache_key] = v
        v
    end
    (200, "application/json", "{\"density_max_total\":$(d_max)}")
end


function _route_density3d_atlas(path::String, base_dir::String, psi_cache::Dict{String, Any})
    # /api/density3d_atlas/:run/:file?comp=N → all-snaps 3D density
    # atlas for one component. Same panel-major idea as the 2D atlas
    # but for the 3D viewer: 1 fetch instead of one per scrub frame.
    # Layout (panel-major over snap, single component):
    #   "D3AT" magic (4)
    #   Int32 header (6): n_snaps, nx, ny, nz, n_comp_total, component
    #   Float32 atlas  (n_snaps * nx * ny * nz)
    p = _parse_run_file(path, "/api/density3d_atlas/")
    p === nothing && return (400, "text/plain", "Expected /api/density3d_atlas/:run/:file")
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    comp_idx = _q_int(p.query, "comp", 0)
    bsz = _q_flag(p.query, "bsz")
    cache_key = "density3d_atlas:$(fpath)#comp=$(comp_idx)#bsz=$(bsz)"
    bin = if haskey(psi_cache, cache_key)
        psi_cache[cache_key]
    else
        disk_blob = _try_load_atlas_from_disk(base_dir, fpath, 1000 + comp_idx, bsz)
        if disk_blob !== nothing
            while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                _evict_one!(psi_cache)
            end
            psi_cache[cache_key] = disk_blob
            disk_blob
        else
            while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                _evict_one!(psi_cache)
            end
            v = try
                meta = _snapshots_metadata(fpath)
                n_snaps = meta === nothing ? 0 : Int(get(meta, "n_snapshots", 0))
                n_snaps == 0 && return (404, "text/plain", "No snapshots")
                raw = _compute_density3d_atlas_binary(fpath, comp_idx, n_snaps, psi_cache)
                _maybe_bitshuffle_zstd(raw, bsz)
            catch e
                return (500, "text/plain", "Error: $(e)")
            end
            psi_cache[cache_key] = v
            _save_atlas_to_disk(base_dir, fpath, 1000 + comp_idx, bsz, v)
            v
        end
    end
    (200, "application/octet-stream", bin)
end

function _route_density_atlas(path::String, base_dir::String, psi_cache::Dict{String, Any})
    # /api/density_atlas/:run/:file?axis=N → all-snaps atlas in one
    # binary blob (panel-major: total then n_comp components, each
    # n_snaps × nx × ny). Replaces ~157 separate /api/density_bin
    # round-trips with a single fetch.
    p = _parse_run_file(path, "/api/density_atlas/")
    p === nothing && return (400, "text/plain", "Expected /api/density_atlas/:run/:file")
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    axis = _q_int(p.query, "axis", 3)
    bsz = _q_flag(p.query, "bsz")
    cache_key = "density_atlas:$(fpath)#axis=$(axis)#bsz=$(bsz)"
    bin = if haskey(psi_cache, cache_key)
        psi_cache[cache_key]
    else
        # Disk-cache fallback: a previous dashboard run may have
        # already written this atlas to runs/_dashboard_cache/.
        disk_blob = _try_load_atlas_from_disk(base_dir, fpath, axis, bsz)
        if disk_blob !== nothing
            while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                _evict_one!(psi_cache)
            end
            psi_cache[cache_key] = disk_blob
            disk_blob
        else
            while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                _evict_one!(psi_cache)
            end
            v = try
                meta = _snapshots_metadata(fpath)
                n_snaps = meta === nothing ? 0 : Int(get(meta, "n_snapshots", 0))
                if n_snaps == 0
                    return (404, "text/plain", "No snapshots in $(p.name)/$(p.file)")
                end
                raw = _compute_column_density_atlas_binary(fpath, axis, n_snaps, psi_cache)
                _maybe_bitshuffle_zstd(raw, bsz)
            catch e
                return (500, "text/plain", "Error: $(e)")
            end
            psi_cache[cache_key] = v
            # Also write through to disk so the next session is instant.
            _save_atlas_to_disk(base_dir, fpath, axis, bsz, v)
            v
        end
    end
    (200, "application/octet-stream", bin)
end


function _route_density3d_rotated(path::String, base_dir::String, psi_cache::Dict{String, Any})
    p = _parse_run_file(path, "/api/density3d_rotated/")
    p === nothing && return (
        400, "text/plain", "Expected /api/density3d_rotated/:run/:file?angle=DEG&comp=N"
    )
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    angle_deg = _q_float(p.query, "angle", 0.0)
    comp_idx = _q_int(p.query, "comp", 0)
    bin = try
        _compute_rotated_3d_density_binary(
            _load_psi_cached(fpath, psi_cache)...; angle_deg, component=comp_idx)
    catch e
        return (500, "text/plain", "Error: $(e)")
    end
    (200, "application/octet-stream", bin)
end


function _route_density2d(path::String, base_dir::String, psi_cache::Dict{String, Any})
    # /api/density/run_name/point_001.jld2?axis=3&snap=K
    p = _parse_run_file(path, "/api/density/")
    p === nothing && return (400, "text/plain", "Expected /api/density/:run/:file")
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    axis = _q_int(p.query, "axis", 3)
    snap_idx = _q_int_opt(p.query, "snap")
    json = try
        cached = _load_psi_cached(fpath, psi_cache, snap_idx)
        _json_string(_compute_column_densities_from_cache(cached..., axis, fpath))
    catch e
        "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
    end
    (200, "application/json", json)
end


function _route_density_bin(path::String, base_dir::String, psi_cache::Dict{String, Any})
    # /api/density_bin/:run/:file?axis=N&snap=K — packed Float32 column density.
    # ~7× smaller than the JSON endpoint and skips JSON.parse on the
    # client; the time-scrubber needs this to stay <20 ms per frame.
    p = _parse_run_file(path, "/api/density_bin/")
    p === nothing && return (400, "text/plain", "Expected /api/density_bin/:run/:file")
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    axis = _q_int(p.query, "axis", 3)
    snap_idx = _q_int_opt(p.query, "snap")
    cache_key = "density_bin:$(fpath)#snap=$(snap_idx)#axis=$(axis)"
    bin = if haskey(psi_cache, cache_key)
        psi_cache[cache_key]
    else
        while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
            _evict_one!(psi_cache)
        end
        v = try
            _compute_column_density_binary(
                _load_psi_cached(fpath, psi_cache, snap_idx)..., axis, fpath
            )
        catch e
            return (500, "text/plain", "Error: $(e)")
        end
        psi_cache[cache_key] = v
        v
    end
    (200, "application/octet-stream", bin)
end


function _route_density3d(path::String, base_dir::String)
    p = _parse_run_file(path, "/api/density3d/")
    p === nothing && return (400, "text/plain", "Expected /api/density3d/:run/:file")
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    json = try
        _json_string(_compute_3d_densities(fpath))
    catch e
        "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
    end
    (200, "application/json", json)
end

function _route_density3d_bin(path::String, base_dir::String, psi_cache::Dict{String, Any})
    p = _parse_run_file(path, "/api/density3d_bin/")
    p === nothing && return (400, "text/plain", "Expected /api/density3d_bin/:run/:file")
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    comp_idx = _q_int(p.query, "comp", 0)
    snap_idx = _q_int_opt(p.query, "snap")
    bsz = _q_flag(p.query, "bsz")
    # Cache density3d_bin output by (file, snap, component). The
    # packed Float32 volume is much smaller than the underlying ψ
    # (524 KB for 64x64x32 vs 13.6 MB), so this is a RAM win + the
    # time-scrubber playback hits cache after the first full pass.
    # bsz variant cached separately to avoid re-encoding on each hit.
    cache_key = "density3d_bin:$(fpath)#snap=$(snap_idx)#comp=$(comp_idx)#bsz=$(bsz)"
    bin = if haskey(psi_cache, cache_key)
        psi_cache[cache_key]
    else
        while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
            _evict_one!(psi_cache)
        end
        v = try
            raw = _compute_3d_density_binary(
                _load_psi_cached(fpath, psi_cache, snap_idx)...; component=comp_idx
            )
            _maybe_bitshuffle_zstd(raw, bsz)
        catch e
            return (500, "text/plain", "Error: $(e)")
        end
        psi_cache[cache_key] = v
        v
    end
    (200, "application/octet-stream", bin)
end


