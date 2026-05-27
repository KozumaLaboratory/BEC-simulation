# Scan group / physics summary / synthetic dispersion / scan status handlers
#
# Extracted from src/workflow/io/dashboard/routes.jl in the 2026-05-09
# refactor. Loaded by SpinorBEC.jl after route_helpers.jl + cache.jl.

function _route_scan_group(
    path::String, base_dir::String, data_cache::Dict{String, String}, psi_cache::Dict{String, Any}
)
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
            "scan.yaml not found in $(pq.name) — author one, or inspect " *
            "the cells from REPL: `using SpinorBEC; exps = [Experiment(p) for p in <yamls>]`",
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
            # Look for canonical result.jld2 first, then result_legacy.jld2 fallback.
            jld_path = if isfile(joinpath(pt_dir, "result.jld2"))
                joinpath(pt_dir, "result.jld2")
            else
                joinpath(pt_dir, "result_legacy.jld2")
            end
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
                        run_summary["larmor_phase_per_step"] = d["dynamics/integrator_meta/larmor_phase_per_step"]
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
        # top-level fallback paths without ceremony.
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
