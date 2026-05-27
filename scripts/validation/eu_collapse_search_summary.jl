#!/usr/bin/env julia
#
# eu_collapse_search_summary.jl — peak-density-runaway analysis for
# the collapse-regime search (Task #17). Adds explicit
# `collapse_factor = peak_max / peak_initial` ratio so a numerical
# answer to "did this cell collapse?" is in the output.

using JLD2
using JSON
using Printf
using SpinorBEC

const ROOT = joinpath(@__DIR__, "..", "..", "runs", "eu_collapse_search")

function _find_output_dir(yaml_path::String)
    base = splitext(basename(yaml_path))[1]
    runs_root = joinpath(@__DIR__, "..", "..", "runs")
    candidates = String[]
    for d in readdir(runs_root; join=true)
        isdir(d) || continue
        startswith(basename(d), base * "_") || continue
        isfile(joinpath(d, "result.jld2")) || isfile(joinpath(d, "point_001.jld2")) ||
            continue
        push!(candidates, d)
    end
    isempty(candidates) && return nothing
    sort!(candidates; by=d -> mtime(d))   # newest by mtime
    last(candidates)
end

function _trajectory_peaks(f)
    g = try
        f["dynamics/psi_snapshots_streamed"]
    catch
        return Float64[], Float64[]
    end
    frame_names = try
        sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
    catch
        String[]
    end
    isempty(frame_names) && return Float64[], Float64[]
    peaks = Float64[]
    for name in frame_names
        psi = g[name]
        ndim = ndims(psi) - 1
        push!(peaks, maximum(SpinorBEC.total_density(psi, ndim)))
    end
    times = try
        Vector{Float64}(f["dynamics/times"])
    catch
        collect(Float64.(1:length(peaks)))
    end
    n = min(length(times), length(peaks))
    (times[1:n], peaks[1:n])
end

function _compute(yaml_path::String)
    outdir = _find_output_dir(yaml_path)
    outdir === nothing && return (status="MISSING",)
    res_path = joinpath(outdir, "result.jld2")
    isfile(res_path) || (res_path = joinpath(outdir, "point_001.jld2"))
    isfile(res_path) || return (status="MISSING",)

    f = jldopen(res_path, "r")
    try
        times, peaks = _trajectory_peaks(f)
        norms = try
            Vector{Float64}(f["dynamics/norms"])
        catch
            Float64[]
        end
        Fz_traj = try
            Vector{Float64}(f["dynamics/Fz"])
        catch
            Float64[]
        end
        isempty(peaks) && return (status="NO_FRAMES",)

        peak_initial = peaks[1]
        peak_max = maximum(peaks)
        collapse_factor = peak_max / max(peak_initial, 1e-30)
        # collapse onset: any threshold (2× or 5×). We report both.
        idx_2x = findfirst(p -> p > 2 * peak_initial, peaks)
        idx_5x = findfirst(p -> p > 5 * peak_initial, peaks)
        coll_2x = idx_2x === nothing ? NaN : times[idx_2x]
        coll_5x = idx_5x === nothing ? NaN : times[idx_5x]

        N0 = isempty(norms) ? NaN : norms[1]
        N_final = isempty(norms) ? NaN : norms[end]
        Fz_per_atom = (!isempty(Fz_traj) && !isempty(norms) &&
                       norms[end] > 1e-30) ? Fz_traj[end] / norms[end] : NaN

        (status="OK",
            peak_initial=peak_initial,
            peak_max=peak_max,
            collapse_factor=collapse_factor,
            coll_2x=coll_2x,
            coll_5x=coll_5x,
            N_final_ratio=N_final / N0,
            Fz_per_atom=Fz_per_atom)
    finally
        close(f)
    end
end

function main()
    yamls = sort(filter(endswith(".yaml"), readdir(ROOT; join=true)))
    println("# Eu collapse-regime search summary")
    println("# Source: $ROOT")
    println()
    @printf("%-26s %-9s %-13s %-13s %-8s %-9s %-9s %-9s\n",
        "config", "status", "peak_init", "peak_max",
        "ratio", "coll_2x", "coll_5x", "Fz/N")
    println(repeat("-", 110))
    rows = []
    for y in yamls
        base = splitext(basename(y))[1]
        obs = _compute(y)
        if obs.status === "OK"
            @printf("%-26s %-9s %-13.5e %-13.5e %-8.2f %-9.3f %-9.3f %-+9.4e\n",
                base, "OK", obs.peak_initial, obs.peak_max,
                obs.collapse_factor, obs.coll_2x, obs.coll_5x, obs.Fz_per_atom)
        else
            @printf("%-26s %-9s %-13s %-13s %-8s %-9s %-9s %-9s\n",
                base, obs.status, "-", "-", "-", "-", "-", "-")
        end
        push!(rows, (config=base, obs=obs))
    end
    summary_path = joinpath(ROOT, "summary.json")
    open(summary_path, "w") do io
        JSON.print(io, Dict("rows" => [
            Dict("config" => r.config,
                "status" => string(r.obs.status),
                "peak_initial" => r.obs.status === "OK" ? r.obs.peak_initial : nothing,
                "peak_max" => r.obs.status === "OK" ? r.obs.peak_max : nothing,
                "collapse_factor" => r.obs.status === "OK" ? r.obs.collapse_factor : nothing,
                "collapse_onset_2x" => r.obs.status === "OK" ? r.obs.coll_2x : nothing,
                "collapse_onset_5x" => r.obs.status === "OK" ? r.obs.coll_5x : nothing,
                "Fz_per_atom" => r.obs.status === "OK" ? r.obs.Fz_per_atom : nothing,
                "N_final_ratio" => r.obs.status === "OK" ? r.obs.N_final_ratio : nothing)
            for r in rows
        ]), 2)
    end
    println("\nWrote $summary_path")
end

main()
