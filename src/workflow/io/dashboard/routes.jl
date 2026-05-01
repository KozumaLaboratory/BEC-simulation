# --- Dashboard route handlers (large branches) ---
#
# Per-prefix handlers extracted from the 1230-line `_route_dashboard` switch
# in dashboard.jl. Each takes the full router state (data_cache, psi_cache,
# base_dir) and returns a `(status, content_type, body)` tuple. Called via
# 1-liner `elseif` branches from the main router.
#
# Currently extracted (the 4 largest by LOC, ~415 lines moved out):
#   /api/scan_group/         (122 lines)
#   /api/physics_summary/    (107 lines)
#   /api/density_max/        (118 lines)
#   /api/synthetic_dispersion/ ( 68 lines)
#
# Smaller branches stay inline in dashboard.jl until further refactoring.

function _route_scan_group(path::String, base_dir::String, data_cache::Dict{String, String}, psi_cache::Dict{String, Any})
    # /api/scan_group/<scan_dir_name> → aggregated cross-run summary
    # for all points declared in `runs/<scan_dir>/scan.yaml`. Backed
    # by the per-run `/api/physics_summary` data, but loaded once
    # per scan rather than per point.
    pq = _parse_run_only(path, "/api/scan_group/")
    scan_dir = joinpath(base_dir, pq.name)
    isdir(scan_dir) || return (404, "text/plain", "scan_dir not found: $(pq.name)")
    scan_yaml_path = joinpath(scan_dir, "scan.yaml")
    if !isfile(scan_yaml_path)
        return (
            404, "text/plain",
            "scan.yaml not found in $(pq.name) — run scripts/scan_retrofit.jl first",
        )
    end
    json = try
        scan = YAML.load_file(scan_yaml_path)
        param = scan["parameter"]
        values = param["values"]
        display_factor = Float64(get(param, "display_factor", 1.0))

        point_pattern = get(scan, "point_dir_pattern",
            "$(scan["name"])_p\${idx}")

        # Resolve point dir per value (mirror scan_expand naming).
        function _point_name(value, idx)
            s = point_pattern
            s = replace(s, "\${idx}" => string(idx))
            val_str = replace(string(value), "." => "_")
            s = replace(s, "\${value}" => val_str)
            s
        end

        runs_data = []
        for (idx, value) in enumerate(values)
            pt_name = _point_name(value, idx)
            pt_dir = joinpath(scan_dir, pt_name)
            # Look for canonical result.jld2 first, then legacy result_legacy.jld2.
            jld_path = isfile(joinpath(pt_dir, "result.jld2")) ?
                       joinpath(pt_dir, "result.jld2") :
                       joinpath(pt_dir, "result_legacy.jld2")
            run_summary = Dict{String, Any}(
                "value" => value,
                "value_display" => value * display_factor,
                "point_dir" => pt_name,
                "completed" => isfile(jld_path),
            )
            if isfile(jld_path)
                try
                    d = JLD2.load(jld_path)
                    for sym in ("Lz", "Fz")
                        _populate_extremes!(run_summary, d, sym)
                    end
                    pm = _per_m_top_fractions(d)
                    if pm !== nothing
                        run_summary["m_top_init"] = pm.init
                        run_summary["m_top_final"] = pm.final
                    end
                    nd = _norm_max_dev(d)
                    nd === nothing || (run_summary["norm_max_dev"] = nd)
                    if haskey(d, "dynamics/integrator_meta/larmor_phase_per_step")
                        run_summary["larmor_phase_per_step"] =
                            d["dynamics/integrator_meta/larmor_phase_per_step"]
                    end
                catch e
                    run_summary["error"] = string(e)
                end
            end
            push!(runs_data, run_summary)
        end

        out = Dict{String, Any}(
            "name" => scan["name"],
            "description" => get(scan, "description", ""),
            "parameter" => Dict{String, Any}(
                "key" => param["key"],
                "values" => values,
                "unit" => get(param, "unit", ""),
                "display_unit" => get(param, "display_unit", ""),
                "display_factor" => display_factor,
            ),
            "runs" => runs_data,
        )
        _json_string(out)
    catch e
        "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
    end
    (200, "application/json", json)
end

function _route_physics_summary(path::String, base_dir::String, psi_cache::Dict{String, Any})
    # /api/physics_summary/:run/:file → integrator metadata + Larmor regime
    # classification + Lz/Fz/m=+F summary. Designed so a frontend physics
    # panel can render gauge widgets (Larmor ratio, ε vs threshold,
    # Lz min/max) without re-loading the multi-GB result.jld2 each time.
    p = _parse_run_file(path, "/api/physics_summary/")
    p === nothing && return (400, "text/plain", "Expected /api/physics_summary/:run/:file")
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    json = try
        d = JLD2.load(fpath)
        out = Dict{String, Any}()

        # Integrator metadata block (written by `save_rotating_basis_result!`).
        for (k, label) in (
            ("dynamics/integrator_meta/dt_used", "dt_used"),
            ("dynamics/integrator_meta/integrator", "integrator"),
            ("dynamics/integrator_meta/epsilon_target", "epsilon_target"),
            ("dynamics/integrator_meta/p_zeeman", "p_zeeman"),
            ("dynamics/integrator_meta/F_atom", "F_atom"),
            ("dynamics/integrator_meta/larmor_phase_per_step", "larmor_phase_per_step"),
            ("dynamics/integrator_meta/theta_const", "theta_const"),
            ("dynamics/integrator_meta/phi_omega", "phi_omega"),
        )
            haskey(d, k) && (out[label] = d[k])
        end

        # Larmor regime classification — same threshold as the Larmor
        # guard warning in pipeline_runner. Audit 2026-04-28 showed
        # ε=1e-3 fails for `p·F·dt > 300`; ε=1e-6 brings it down to
        # ~90 for the Klaus-equivalent runs. Frontend can colour-code
        # the gauge from this field.
        larmor = get(out, "larmor_phase_per_step", NaN)
        out["larmor_regime"] = if !isfinite(larmor) || larmor == 0
            "unknown"
        elseif larmor < 1
            "safe"
        elseif larmor < 100
            "marginal"
        elseif larmor < 300
            "stiff"
        else
            "danger"
        end

        # Lz / Fz / Fx / Fy extremes — `_populate_extremes!` reads from
        # the canonical `dynamics/<X>` path (post-2026-04-29) or the
        # top-level legacy `<X>` (pre-2026-04-29) without ceremony.
        for sym in ("Lz", "Fz", "Fx", "Fy")
            _populate_extremes!(out, d, sym)
        end

        # m=+F population at start vs end (canonical thesis observable).
        pm = _per_m_top_fractions(d)
        if pm !== nothing
            out["m_top_init"] = pm.init
            out["m_top_final"] = pm.final
        end

        # Norm conservation diagnostic.
        nd = _norm_max_dev(d)
        nd === nothing || (out["norm_max_dev"] = nd)

        _json_string(out)
    catch e
        "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
    end
    (200, "application/json", json)
end

function _route_synthetic_dispersion(path::String, base_dir::String, psi_cache::Dict{String, Any})
    # /api/synthetic_dispersion/:run/:file?axis=N&snap=K → packed
    # Float32 (k_real × k_synth) dispersion image. Drives the new
    # SlicePanel "dispersion" mode — same protocol shape as
    # density_bin so the same DataTexture upload path can render it.
    p = _parse_run_file(path, "/api/synthetic_dispersion/")
    p === nothing &&
        return (400, "text/plain", "Expected /api/synthetic_dispersion/:run/:file")
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    axis = _q_int(p.query, "axis", 1)
    snap_idx = _q_int_opt(p.query, "snap")
    cache_key = "synth_disp:$(fpath)#snap=$(snap_idx)#axis=$(axis)"
    bin = if haskey(psi_cache, cache_key)
        psi_cache[cache_key]
    else
        while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
            _evict_one!(psi_cache)
        end
        v = try
            tup = _load_psi_cached(fpath, psi_cache, snap_idx)
            psi = tup[1]
            # Re-derive a Grid from the JLD2 box_size so the
            # synthetic_dim_dispersion call (which queries
            # grid.config.box_size) has what it needs.
            box = _load_box_size(fpath)
            ndim = ndims(psi) - 1
            n_pts = ntuple(i -> size(psi, i), ndim)
            box_n = ntuple(i -> Float64(box[i]), ndim)
            grid = make_grid(GridConfig(n_pts, box_n))
            d = synthetic_dim_dispersion(psi, grid; axis=axis)
            spectrum_f32 = Float32.(d.spectrum)
            n_axis = size(spectrum_f32, 1)
            D = size(spectrum_f32, 2)
            buf = IOBuffer(; sizehint=40 + n_axis * D * 4)
            # density_bin header reused: ndim=2, axis=axis,
            # nx=n_axis, ny=D, n_comp=0 (no per-component split,
            # the whole image lives in the total slot), F=0.
            write(buf, Int32(2), Int32(axis), Int32(n_axis), Int32(D), Int32(0), Int32(0))
            # axis_ranges in radians-of-k (label-only on the client)
            write(buf, Float32[-π, π, -π, π])
            # m_values empty (n_comp=0) so the frontend parser skips
            # straight to total_density.
            # total_density slot carries the spectrum.
            write(buf, vec(spectrum_f32))
            take!(buf)
        catch e
            return (500, "text/plain", "Error: $(e)")
        end
        psi_cache[cache_key] = v
        v
    end
    (200, "application/octet-stream", bin)
end

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


# --- Round 5 (R11-cont) extracted handlers ---
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

# --- R21: medium-sized branches lifted out of _route_dashboard ---

function _route_lab_list(path::String, base_dir::String)
    # /api/lab/list/<run_name>?limit=N → JSON array of recent lab
    # images uploaded via POST /api/lab/image/<run>. Most recent
    # first, capped to `limit` (default 32 — matches the React
    # LabImageOverlay's ring buffer expectation).
    p = _parse_run_only(path, "/api/lab/list/")
    limit = _q_int(p.query, "limit", 32)
    img_dir = joinpath(base_dir, p.name, "lab_images")
    isdir(img_dir) || return (200, "application/json", "[]")
    files = sort(filter(f -> startswith(f, "shot_") && endswith(f, ".png"),
            readdir(img_dir)); rev=true)
    files = files[1:min(limit, length(files))]
    items = map(files) do f
        full = joinpath(img_dir, f)
        mt = round(Int, mtime(full) * 1000)
        sz = filesize(full)
        "{\"name\":\"$f\",\"url\":\"/runs/$(p.name)/lab_images/$(f)\",\"mtime_ms\":$mt,\"size\":$sz}"
    end
    (200, "application/json", "[" * join(items, ",") * "]")
end

function _route_live_list(base_dir::String)
    # Scan base_dir/* for runs whose _live_status.json was touched in
    # the last 5 minutes — those are presumed actively running. Return
    # a JSON array of {run, mtime_ms, age_s}.
    cutoff_s = 300.0
    active = String[]
    if isdir(base_dir)
        now_s = time()
        for entry in readdir(base_dir)
            full = joinpath(base_dir, entry, "_live_status.json")
            isfile(full) || continue
            age = now_s - mtime(full)
            age <= cutoff_s || continue
            mt = round(Int, mtime(full) * 1000)
            push!(active,
                "{\"run\":\"$entry\",\"mtime_ms\":$mt,\"age_s\":$(round(age; digits=1))}")
        end
    end
    (200, "application/json", "[" * join(active, ",") * "]")
end

function _route_live(path::String, base_dir::String)
    # /api/live/<run_name> → contents of base_dir/<run>/_live_status.json
    p = _parse_run_only(path, "/api/live/")
    status_path = joinpath(base_dir, p.name, "_live_status.json")
    isfile(status_path) ||
        return (404, "application/json", "{\"error\":\"no live status for $(p.name)\"}")
    (200, "application/json", read(status_path, String))
end

function _route_scan_status(path::String, base_dir::String)
    # /api/scan_status/<run_name> → JSON with {completed, expected,
    # latest_mtime_s, eta_s} so the dashboard can show "12/144 done · ETA 9h"
    # for an in-progress overnight scan. expected may be null when the
    # config has no scan block.
    p = _parse_run_only(path, "/api/scan_status/")
    status = run_status(joinpath(base_dir, p.name))
    if !status.exists
        return (404, "application/json", "{\"error\":\"unknown run $(p.name)\"}")
    end
    expected_str = status.expected === nothing ? "null" : string(status.expected)
    latest_str =
        isnan(status.latest_mtime_s) ? "null" :
        string(round(status.latest_mtime_s; digits=3))
    eta_str = isnan(status.eta_s) ? "null" :
              string(round(status.eta_s; digits=1))
    body =
        "{\"completed\":$(status.completed),\"expected\":$expected_str," *
        "\"latest_mtime_s\":$latest_str,\"eta_s\":$eta_str}"
    (200, "application/json", body)
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

function _route_dynamics_series(path::String, base_dir::String)
    # /api/dynamics_series/:run/:file → scalar time series for sparkline rendering
    p = _parse_run_file(path, "/api/dynamics_series/")
    p === nothing &&
        return (400, "text/plain", "Expected /api/dynamics_series/:run/:file")
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    json = try
        d = JLD2.load(fpath)
        out = Dict{String, Any}("has_dynamics" => haskey(d, "dynamics/times"))
        for k in (
            "dynamics/times",
            "dynamics/energies",
            "dynamics/magnetizations",
            "dynamics/norms",
        )
            haskey(d, k) || continue
            out[split(k, "/")[2]] = Float64.(d[k])
        end
        if haskey(d, "dynamics/component_populations")
            # Just return the dominant m's series so sparklines stay compact.
            pops = d["dynamics/component_populations"]
            n_snaps = size(pops, 1)
            n_comp = size(pops, 2)
            out["pop_top"] = [Float64(pops[t, 1]) for t in 1:n_snaps]  # m=+F
            out["pop_mid"] = [Float64(pops[t, (n_comp + 1) ÷ 2]) for t in 1:n_snaps]  # m=0
        end
        _json_string(out)
    catch e
        "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
    end
    (200, "application/json", json)
end

function _route_snapshots(path::String, base_dir::String, psi_cache::Dict{String, Any})
    # /api/snapshots/:run/:file → metadata for the time-scrubber UI.
    p = _parse_run_file(path, "/api/snapshots/")
    p === nothing && return (400, "text/plain", "Expected /api/snapshots/:run/:file")
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    meta = _snapshots_metadata(fpath)
    if meta === nothing
        return (200, "application/json", "{\"n_snapshots\":0,\"times\":[]}")
    end
    # Kick off background warming of every per-snap density_bin (axis=3,
    # the default the SlicePanel opens to). The frontend's prefetch
    # only covers the next 1-2 frames; this turns the rest of the run
    # into a cache hit by the time the user scrubs to it. axis=1/2 are
    # warmed lazily via the existing per-request path.
    n_snaps = get(meta, "n_snapshots", 0)
    if n_snaps isa Integer && n_snaps > 0
        # Prefer the user's most-likely first axis (z-integration)
        # but warm 1 and 2 right behind it so the axis selector is
        # also instant. The warmer yields between frames so the
        # subsequent axes don't starve the active scrub.
        for ax in (3, 1, 2)
            inflight_key = "warm_density_bin:$(fpath)#axis=$(ax)"
            inflight_key in _PREPACK_INFLIGHT && continue
            push!(_PREPACK_INFLIGHT, inflight_key)
            @async _warm_density_bin_all(fpath, Int(n_snaps), ax, psi_cache, base_dir)
        end
    end
    (200, "application/json", _json_string(meta))
end

