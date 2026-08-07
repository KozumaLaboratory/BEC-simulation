# Snapshot / dynamics series / TWA ensemble route handlers
#
# Extracted from src/workflow/io/dashboard/routes.jl in the 2026-05-09
# refactor. Loaded by SpinorBEC.jl after route_helpers.jl + cache.jl.

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
            pops = d["dynamics/component_populations"]
            n_snaps = size(pops, 1)
            n_comp = size(pops, 2)
            # Compact dominant-m series kept for the DataTable sparklines.
            out["pop_top"] = [Float64(pops[t, 1]) for t in 1:n_snaps]  # m=+F
            out["pop_mid"] = [Float64(pops[t, (n_comp + 1) ÷ 2]) for t in 1:n_snaps]  # m=0
            # Full per-m series for the time-series Overview. Row t is one
            # snapshot; column c is m = F-(c-1). Sent as a flat row-major
            # Float64 array (snap-major) the client reshapes to [snap][m].
            F = (n_comp - 1) ÷ 2
            out["m_values"] = Int[F - (c - 1) for c in 1:n_comp]
            out["n_comp"] = n_comp
            out["populations"] = [Float64(pops[t, c]) for t in 1:n_snaps for c in 1:n_comp]
            # component_populations is recorded once per snapshot frame, so
            # it usually has one fewer row than `times` (which includes the
            # t=0 initial state). Align by dropping t=0 when the lengths
            # differ by exactly one; otherwise fall back to the raw times.
            if haskey(d, "dynamics/times")
                ts = Float64.(d["dynamics/times"])
                # When the lengths align, these are TIMES. When they do not, we
                # do not know the times — and the fallback emitted
                # `collect(1.0:n_snaps)`, i.e. frame INDICES, under the key
                # `pop_times`, which the front end plots as a time axis. A reader
                # then sees an axis running 1, 2, 3… in whatever unit they assume.
                #
                # Absence written out as a plausible value, the same shape as the
                # `Fx` literal fixed the same day. The key is omitted instead, and
                # the mismatch is reported so the caller can say "no time axis"
                # rather than draw a wrong one.
                if length(ts) == n_snaps + 1
                    out["pop_times"] = ts[2:end]
                elseif length(ts) == n_snaps
                    out["pop_times"] = ts
                else
                    out["pop_times_unavailable"] = Dict(
                        "n_times" => length(ts), "n_snapshots" => n_snaps,
                        "reason" =>
                            "times and snapshots cannot be aligned; " *
                            "frame indices are NOT times",
                    )
                end
            end
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

# /api/ensemble/:run/:file → TWA EnsembleResult summary (Round-2 Task 5).
#
# Reads `dynamics/ensemble/phase_NN/...` from a result.jld2 written by
# `save_rotating_basis_result!` and returns a JSON summary of every TWA
# ensemble phase (n_trajectories, frame times, peak / on-axis / σ-over-μ
# scalar time series, σ/μ histogram on the last frame).
#
# The 3D mean / variance volumes themselves are NOT returned here; they
# stay on disk and would be served by a future `/api/ensemble_bin/`
# endpoint mirroring `density3d_bin`. This route is the lightweight JSON
# the EnsemblePanel UI needs to render time series and the σ/μ histogram.
# ---------------------------------------------------------------------------

function _route_ensemble(path::String, base_dir::String)
    p = _parse_run_file(path, "/api/ensemble/")
    p === nothing && return (400, "text/plain", "Expected /api/ensemble/:run/:file")
    fpath = joinpath(base_dir, p.name, p.file)
    isfile(fpath) || return (404, "text/plain", "File not found: $(p.name)/$(p.file)")
    json = try
        _json_string(_compute_ensemble_summary(fpath))
    catch e
        "{\"error\":\"$(replace(string(e), "\"" => "'"))\"}"
    end
    (200, "application/json", json)
end

function _compute_ensemble_summary(fpath::String)
    out = Dict{String, Any}("phases" => [])
    JLD2.jldopen(fpath, "r") do f
        # Discover phase_NN subgroups under dynamics/ensemble.
        haskey(f, "dynamics/ensemble") || return out
        ens_root = f["dynamics/ensemble"]
        for pname in sort!(collect(keys(ens_root)))
            startswith(pname, "phase_") || continue
            phase_idx = tryparse(Int, replace(pname, "phase_" => ""))
            phase_idx === nothing && continue
            phase_data = _summarize_phase(ens_root, pname)
            phase_data["phase_idx"] = phase_idx
            push!(out["phases"], phase_data)
        end
    end
    out
end

function _summarize_phase(ens_root, pname::String)
    phase = ens_root[pname]
    out = Dict{String, Any}("observables" => String[])
    out["n_trajectories"] = haskey(phase, "n_trajectories") ? Int(phase["n_trajectories"]) : 0
    out["times"] = haskey(phase, "times") ? Float64.(phase["times"]) : Float64[]
    for obs_name in sort!(collect(keys(phase)))
        obs_name in ("n_trajectories", "times") && continue
        obs_group = phase[obs_name]
        keys_in = collect(keys(obs_group))
        obs_summary = Dict{String, Any}(
            "has_mean" => "mean" in keys_in,
            "has_variance" => "variance" in keys_in,
        )
        if obs_summary["has_mean"]
            mean_arr = obs_group["mean"]
            obs_summary["shape"] = collect(Int, size(mean_arr))
            if obs_name == "density" && ndims(mean_arr) == 4
                _density_scalars!(obs_summary, mean_arr,
                    obs_summary["has_variance"] ? obs_group["variance"] : nothing)
            end
        end
        out[obs_name] = obs_summary
        push!(out["observables"], obs_name)
    end
    out
end

function _density_scalars!(obs_summary::Dict{String, Any}, mean_arr::AbstractArray{<:Real, 4},
    var_arr::Union{Nothing, AbstractArray{<:Real, 4}})
    nx, ny, nz, nt = size(mean_arr)
    cx, cy, cz = nx ÷ 2 + 1, ny ÷ 2 + 1, nz ÷ 2 + 1

    peak_mean = Vector{Float64}(undef, nt)
    on_axis_ratio = Vector{Float64}(undef, nt)
    sigma_over_mu_at_peak = Vector{Float64}(undef, nt)
    peak_variance = Vector{Float64}(undef, nt)

    for t in 1:nt
        slab = @view mean_arr[:, :, :, t]
        peak = maximum(slab)
        peak_mean[t] = peak
        on_axis_ratio[t] = peak > 0 ? slab[cx, cy, cz] / peak : 0.0
        if var_arr !== nothing
            var_slab = @view var_arr[:, :, :, t]
            peak_idx = argmax(slab)
            v = max(var_slab[peak_idx], 0.0)
            peak_variance[t] = v
            sigma_over_mu_at_peak[t] = peak > 0 ? sqrt(v) / peak : 0.0
        else
            peak_variance[t] = NaN
            sigma_over_mu_at_peak[t] = NaN
        end
    end

    obs_summary["peak_mean"] = peak_mean
    obs_summary["on_axis_ratio_mean"] = on_axis_ratio
    obs_summary["peak_variance"] = peak_variance
    obs_summary["sigma_over_mu_at_peak"] = sigma_over_mu_at_peak

    # σ/μ histogram across all voxels at the last frame (where instability
    # has fully developed). Only count voxels with ⟨n⟩ above 1% of peak so
    # vacuum voxels with arbitrary σ/μ ratios don't dominate the bin.
    if var_arr !== nothing && nt > 0
        last_mean = @view mean_arr[:, :, :, nt]
        last_var = @view var_arr[:, :, :, nt]
        peak = peak_mean[nt]
        threshold = 0.01 * peak
        bin_edges = collect(0.0:0.05:2.0)
        n_bins = length(bin_edges) - 1
        counts = zeros(Int, n_bins)
        n_kept = 0
        for I in eachindex(last_mean)
            μ = last_mean[I]
            μ > threshold || continue
            σ = sqrt(max(last_var[I], 0.0))
            r = σ / μ
            r > bin_edges[end] && (r = bin_edges[end] - 1e-9)
            bin = clamp(floor(Int, r / 0.05) + 1, 1, n_bins)
            counts[bin] += 1
            n_kept += 1
        end
        obs_summary["sigma_over_mu_histogram"] = Dict{String, Any}(
            "bin_edges" => bin_edges,
            "counts" => counts,
            "n_voxels" => n_kept,
            "threshold_frac_of_peak" => 0.01,
        )
    end
    obs_summary
end
