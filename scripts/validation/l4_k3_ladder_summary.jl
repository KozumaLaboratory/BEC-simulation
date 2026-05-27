#!/usr/bin/env julia
#
# l4_k3_ladder_summary.jl — collapse-arrest analysis for Task #14.
# Trajectory-aware (uses dynamics/times, /norms, /Fz, and per-snapshot
# peak density from /psi_snapshots_streamed). Per-cell observables:
#
#   collapse_onset_time   first t where peak_density(t) > 2 × initial
#   loss_onset_time       first t where N(t)/N(0) < 0.999
#   peak_density_max      max(peak_density) over trajectory
#   final_N_fraction      N(T)/N(0)
#   final_Fz_per_N        ⟨F_z⟩/N at T_evolution
#   ΔFz                   final_Fz_per_N − initial_Fz_per_N (= -F)
#   max_Jz_drift          NaN if Lz not saved; placeholder column
#
# Writes runs/l4_k3_ladder/summary.json + prints a wide table.

using JLD2
using JSON
using Printf
using SpinorBEC

const ROOT = joinpath(@__DIR__, "..", "..", "runs", "l4_k3_ladder")

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

function _peak_density_trajectory(f)
    g = try
        f["dynamics/psi_snapshots_streamed"]
    catch
        return Float64[], Float64[]
    end
    frame_names = try
        # The streamed-snapshot group also stores metadata keys
        # (n_snapshots, spatial_shape, n_components); filter them out.
        sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
    catch
        String[]
    end
    isempty(frame_names) && return Float64[], Float64[]
    peaks = Float64[]
    for name in frame_names
        psi = g[name]
        ndim = ndims(psi) - 1
        n = SpinorBEC.total_density(psi, ndim)
        push!(peaks, maximum(n))
    end
    times = try
        Vector{Float64}(f["dynamics/times"])
    catch
        collect(Float64.(1:length(peaks)))
    end
    # times array length may not match snapshot count; trim/pad to match.
    n = min(length(times), length(peaks))
    (times[1:n], peaks[1:n])
end

function _compute_observables(yaml_path::String)
    outdir = _find_output_dir(yaml_path)
    outdir === nothing && return (status="MISSING",)
    res_path = joinpath(outdir, "result.jld2")
    isfile(res_path) || (res_path = joinpath(outdir, "point_001.jld2"))
    isfile(res_path) || return (status="MISSING",)

    f = try
        jldopen(res_path, "r")
    catch
        return (status="LOCKED",)
    end
    try
        times, peaks = _peak_density_trajectory(f)
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
        N0 = isempty(norms) ? NaN : norms[1]
        N_final = isempty(norms) ? NaN : norms[end]
        Fz_final = isempty(Fz_traj) ? NaN : Fz_traj[end]
        Fz_per_atom = (!isnan(Fz_final) && !isnan(N_final) && N_final > 1e-30) ?
            Fz_final / N_final : NaN
        peak_max = isempty(peaks) ? NaN : maximum(peaks)
        # collapse onset: first t where peak > 2 × initial peak (if any).
        collapse_onset = if !isempty(peaks)
            p0 = peaks[1]
            idx = findfirst(p -> p > 2 * p0, peaks)
            idx === nothing ? NaN : times[idx]
        else
            NaN
        end
        loss_onset = if length(norms) > 1
            n0 = norms[1]
            ts = try
                Vector{Float64}(f["dynamics/times"])
            catch
                collect(Float64.(1:length(norms)))
            end
            tn = min(length(ts), length(norms))
            idx = findfirst(i -> norms[i] / n0 < 0.999, 1:tn)
            idx === nothing ? NaN : ts[idx]
        else
            NaN
        end
        (status="OK", outdir=outdir,
            collapse_onset=collapse_onset,
            loss_onset=loss_onset,
            peak_max=peak_max,
            final_N_fraction=N_final / N0,
            final_Fz_per_N=Fz_per_atom,
            n_snapshots=length(peaks))
    finally
        close(f)
    end
end

function main()
    yamls = sort(filter(endswith(".yaml"),
        readdir(ROOT; join=true)))
    println("# L4 K3 collapse-arrest ladder summary")
    println("# Source: $ROOT")
    println()
    @printf("%-26s %-9s %-9s %-9s %-12s %-12s %-12s\n",
        "config", "status", "coll_t", "loss_t",
        "peak_max", "N(T)/N(0)", "Fz/N(T)")
    println(repeat("-", 99))

    rows = []
    for y in yamls
        base = splitext(basename(y))[1]
        obs = _compute_observables(y)
        if obs.status === "OK"
            @printf("%-26s %-9s %-9.3f %-9.3f %-12.4e %-12.6e %-+12.5e\n",
                base, "OK", obs.collapse_onset, obs.loss_onset,
                obs.peak_max, obs.final_N_fraction, obs.final_Fz_per_N)
        else
            @printf("%-26s %-9s %-9s %-9s %-12s %-12s %-12s\n",
                base, obs.status, "-", "-", "-", "-", "-")
        end
        push!(rows, (config=base, obs=obs))
    end

    summary_path = joinpath(ROOT, "summary.json")
    open(summary_path, "w") do io
        JSON.print(io, Dict("rows" => [
            Dict("config" => r.config,
                "status" => string(r.obs.status),
                "collapse_onset" => r.obs.status === "OK" ? r.obs.collapse_onset : nothing,
                "loss_onset" => r.obs.status === "OK" ? r.obs.loss_onset : nothing,
                "peak_max" => r.obs.status === "OK" ? r.obs.peak_max : nothing,
                "final_N_fraction" => r.obs.status === "OK" ? r.obs.final_N_fraction : nothing,
                "final_Fz_per_N" => r.obs.status === "OK" ? r.obs.final_Fz_per_N : nothing,
                "n_snapshots" => r.obs.status === "OK" ? r.obs.n_snapshots : 0)
            for r in rows
        ]), 2)
    end
    println("\nWrote $summary_path")
end

main()
