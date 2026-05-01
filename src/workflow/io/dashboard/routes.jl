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
    rest = _uri_decode(path[17:end])
    qidx = findfirst('?', rest)
    qidx !== nothing && (rest = rest[1:(qidx - 1)])
    scan_dir = joinpath(base_dir, rest)
    if !isdir(scan_dir)
        return (404, "text/plain", "scan_dir not found: $rest")
    end
    scan_yaml_path = joinpath(scan_dir, "scan.yaml")
    if !isfile(scan_yaml_path)
        return (
            404, "text/plain",
            "scan.yaml not found in $rest — run scripts/scan_retrofit.jl first",
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
                    # Same fields as /api/physics_summary, abbreviated.
                    for sym in ("Lz", "Fz")
                        v = if haskey(d, "dynamics/$sym")
                            Float64.(d["dynamics/$sym"])
                        elseif haskey(d, sym)
                            Float64.(d[sym])
                        else
                            Float64[]
                        end
                        if !isempty(v)
                            run_summary[sym * "_min"] = minimum(v)
                            run_summary[sym * "_max"] = maximum(v)
                            run_summary[sym * "_init"] = v[1]
                            run_summary[sym * "_final"] = v[end]
                        end
                    end
                    pm = if haskey(d, "dynamics/per_m_history")
                        d["dynamics/per_m_history"]
                    elseif haskey(d, "per_m_history")
                        d["per_m_history"]
                    else
                        nothing
                    end
                    if pm !== nothing
                        T = size(pm, 2)
                        col1 = sum(view(pm, :, 1))
                        colT = sum(view(pm, :, T))
                        run_summary["m_top_init"] = pm[1, 1] / max(col1, 1e-30)
                        run_summary["m_top_final"] = pm[1, T] / max(colT, 1e-30)
                    end
                    nv = if haskey(d, "dynamics/norms")
                        Float64.(d["dynamics/norms"])
                    elseif haskey(d, "norms")
                        Float64.(d["norms"])
                    else
                        Float64[]
                    end
                    if !isempty(nv)
                        run_summary["norm_max_dev"] = maximum(abs.(nv .- 1.0))
                    end
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
    rest = _uri_decode(path[22:end])
    slash_idx = findfirst('/', rest)
    if slash_idx === nothing
        return (400, "text/plain", "Expected /api/physics_summary/:run/:file")
    end
    name = rest[1:(slash_idx - 1)]
    file = rest[(slash_idx + 1):end]
    qidx = findfirst('?', file)
    qidx !== nothing && (file = file[1:(qidx - 1)])
    fpath = joinpath(base_dir, name, file)
    if !isfile(fpath)
        return (404, "text/plain", "File not found: $name/$file")
    end
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

        # Lz / Fz extremes summary. Try the canonical
        # `dynamics/<X>` keys first; fall back to top-level `<X>`
        # for the legacy launch_*.jl Vector output (pre-2026-04-29).
        for sym in ("Lz", "Fz", "Fx", "Fy")
            v = if haskey(d, "dynamics/$sym")
                Float64.(d["dynamics/$sym"])
            elseif haskey(d, sym)
                Float64.(d[sym])
            else
                nothing
            end
            v === nothing || isempty(v) && continue
            if v !== nothing && !isempty(v)
                out[sym * "_min"] = minimum(v)
                out[sym * "_max"] = maximum(v)
                out[sym * "_init"] = v[1]
                out[sym * "_final"] = v[end]
            end
        end

        # m=+F population at start vs end (canonical thesis observable).
        pm = if haskey(d, "dynamics/per_m_history")
            d["dynamics/per_m_history"]
        elseif haskey(d, "per_m_history")
            d["per_m_history"]
        else
            nothing
        end
        if pm !== nothing
            T = size(pm, 2)
            col1 = sum(view(pm, :, 1))
            colT = sum(view(pm, :, T))
            out["m_top_init"] = pm[1, 1] / max(col1, 1e-30)
            out["m_top_final"] = pm[1, T] / max(colT, 1e-30)
        end

        # Norm conservation diagnostic.
        nv = if haskey(d, "dynamics/norms")
            Float64.(d["dynamics/norms"])
        elseif haskey(d, "norms")
            Float64.(d["norms"])
        else
            nothing
        end
        if nv !== nothing && !isempty(nv)
            out["norm_max_dev"] = maximum(abs.(nv .- 1.0))
        end

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
    rest = _uri_decode(path[27:end])
    slash_idx = findfirst('/', rest)
    if slash_idx === nothing
        return (400, "text/plain", "Expected /api/synthetic_dispersion/:run/:file")
    end
    name = rest[1:(slash_idx - 1)]
    file = rest[(slash_idx + 1):end]
    axis = 1
    snap_idx = nothing
    qidx = findfirst('?', file)
    if qidx !== nothing
        query = file[(qidx + 1):end]
        file = file[1:(qidx - 1)]
        m = match(r"axis=(\d+)", query)
        m !== nothing && (axis = parse(Int, m.captures[1]))
        ms = match(r"snap=(\d+)", query)
        ms !== nothing && (snap_idx = parse(Int, ms.captures[1]))
    end
    fpath = joinpath(base_dir, name, file)
    if !isfile(fpath)
        return (404, "text/plain", "File not found: $name/$file")
    end
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
    rest = _uri_decode(path[18:end])
    slash_idx = findfirst('/', rest)
    if slash_idx === nothing
        return (400, "text/plain", "Expected /api/density_max/:run/:file")
    end
    name = rest[1:(slash_idx - 1)]
    file = rest[(slash_idx + 1):end]
    qidx = findfirst('?', file)
    qidx !== nothing && (file = file[1:(qidx - 1)])
    fpath = joinpath(base_dir, name, file)
    if !isfile(fpath)
        return (404, "text/plain", "File not found: $name/$file")
    end
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

