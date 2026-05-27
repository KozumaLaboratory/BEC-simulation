#!/usr/bin/env julia
#
# eu_k3_sweep_96_summary.jl — 96³ anchor analysis for Task #19B
# confirmation. Adds absolute Fz, N_m(t) component decomposition, and
# loss_onset_time (per anko's "Fz/N だけを見ないこと" guidance).

using JLD2
using JSON
using Printf
using SpinorBEC

const ROOT = joinpath(@__DIR__, "..", "..", "runs", "eu_k3_sweep_96")

function _find_output_dir(yaml_path::String)
    base = splitext(basename(yaml_path))[1]
    ymtime = mtime(yaml_path)
    runs_root = joinpath(@__DIR__, "..", "..", "runs")
    cand = String[]
    for d in readdir(runs_root; join=true)
        isdir(d) || continue
        startswith(basename(d), base * "_") || continue
        isfile(joinpath(d, "result.jld2")) || continue
        mtime(d) > ymtime || continue
        push!(cand, d)
    end
    isempty(cand) && return nothing
    sort!(cand; by=d -> mtime(d))
    last(cand)
end

function _classify(peaks::Vector{Float64}, times::Vector{Float64},
    N_final_ratio::Float64)
    peak0 = peaks[1]
    idx_max = argmax(peaks)
    idx_2x = findfirst(p -> p > 2 * peak0, peaks)
    coll_t = idx_2x === nothing ? NaN : times[idx_2x]
    peak_growing_at_end = idx_max == length(peaks)
    if !isnan(coll_t)
        peak_growing_at_end ? "collapse" : "delay"
    else
        peak_growing_at_end ? "marginal_arrest" :
            (N_final_ratio < 0.5 ? "sacrificial_arrest" : "stable_arrest")
    end
end

function _loss_onset(times::Vector{Float64}, norms::Vector{Float64})
    n0 = norms[1]
    idx = findfirst(i -> norms[i] / n0 < 0.999, 2:length(norms))
    idx === nothing ? NaN : times[idx + 1]
end

function _compute(yaml_path::String)
    outdir = _find_output_dir(yaml_path)
    outdir === nothing && return (status="PENDING",)
    res = joinpath(outdir, "result.jld2")
    isfile(res) || return (status="PENDING",)
    f = try
        jldopen(res, "r")
    catch
        return (status="LOCKED",)
    end
    try
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        peaks = Float64[Float64(maximum(SpinorBEC.total_density(g[fr], 3))) for fr in frames]
        times = Vector{Float64}(f["dynamics/times"])
        n = min(length(times), length(peaks))
        peaks = peaks[1:n]
        times = times[1:n]
        norms = Vector{Float64}(f["dynamics/norms"])
        Fz = Vector{Float64}(f["dynamics/Fz"])
        cp = f["dynamics/component_populations"]  # (n_snapshots, n_comp=13)
        peak_max = maximum(peaks)
        idx_max = argmax(peaks)
        cls = _classify(peaks, times, norms[end] / norms[1])
        loss_t = _loss_onset(times, norms)
        # N_m at final snapshot: dominant 3 components for compactness.
        # In Eu (F=6) convention c=1 ↔ m=+F, c=13 ↔ m=-F.
        Nm_final = cp[end, :]
        Nm_initial = cp[1, :]
        top3_idx = sortperm(Nm_final; rev=true)[1:3]
        top3 = [(c=c, m=6 - (c - 1), N_m=Nm_final[c]) for c in top3_idx]
        (status="OK",
            outdir=outdir,
            peak0=peaks[1], peak_max=peak_max,
            peak_max_t=times[idx_max],
            ratio=peak_max / peaks[1],
            coll_t=isnan(_classify(peaks, times, norms[end] / norms[1]) == "delay" ? 0.0 : NaN) ? NaN : 0.0,
            classification=cls,
            absolute_Fz_initial=Fz[1],
            absolute_Fz_final=Fz[end],
            N_initial=norms[1],
            N_final=norms[end],
            N_final_ratio=norms[end] / norms[1],
            Fz_per_atom=Fz[end] / norms[end],
            loss_onset_t=loss_t,
            top3_Nm=top3)
    finally
        close(f)
    end
end

function main()
    yamls = sort(filter(endswith(".yaml"), readdir(ROOT; join=true)))
    println("# 96³ K3 anchor — Task #19B operational-transition confirmation")
    println("# cigar N=30k ω_z=0.25; LHY off, γ_dr off; K3_base = 1e-41 m⁶/s")
    println()
    @printf("%-22s %-9s %-13s %-7s %-15s %-+12s %-+12s %-9s %-9s\n",
        "config", "status", "peak_max", "ratio", "classification",
        "Fz(0)", "Fz(T)", "N(T)/N(0)", "loss_t")
    println(repeat("-", 130))

    rows = []
    for y in yamls
        base = splitext(basename(y))[1]
        obs = _compute(y)
        if obs.status === "OK"
            @printf("%-22s %-9s %-13.5e %-7.3f %-15s %-+12.4e %-+12.4e %-9.5f %-9.2f\n",
                base, "OK", obs.peak_max, obs.ratio, obs.classification,
                obs.absolute_Fz_initial, obs.absolute_Fz_final,
                obs.N_final_ratio, obs.loss_onset_t)
            println("  top-3 N_m at T=20: " *
                join(["m=$(t.m): N_m=$(round(t.N_m; digits=4))" for t in obs.top3_Nm], ", "))
        else
            @printf("%-22s %-9s %-13s %-7s %-15s %-12s %-12s %-9s %-9s\n",
                base, obs.status, "-", "-", "-", "-", "-", "-", "-")
        end
        push!(rows, (config=base, obs=obs))
    end

    sjson = joinpath(ROOT, "summary.json")
    open(sjson, "w") do io
        JSON.print(io, Dict("rows" => [
            Dict("config" => r.config,
                "status" => string(r.obs.status),
                "peak0" => r.obs.status === "OK" ? r.obs.peak0 : nothing,
                "peak_max" => r.obs.status === "OK" ? r.obs.peak_max : nothing,
                "peak_max_t" => r.obs.status === "OK" ? r.obs.peak_max_t : nothing,
                "ratio" => r.obs.status === "OK" ? r.obs.ratio : nothing,
                "classification" => r.obs.status === "OK" ? r.obs.classification : nothing,
                "absolute_Fz_initial" => r.obs.status === "OK" ? r.obs.absolute_Fz_initial : nothing,
                "absolute_Fz_final" => r.obs.status === "OK" ? r.obs.absolute_Fz_final : nothing,
                "N_initial" => r.obs.status === "OK" ? r.obs.N_initial : nothing,
                "N_final" => r.obs.status === "OK" ? r.obs.N_final : nothing,
                "N_final_ratio" => r.obs.status === "OK" ? r.obs.N_final_ratio : nothing,
                "Fz_per_atom" => r.obs.status === "OK" ? r.obs.Fz_per_atom : nothing,
                "loss_onset_t" => r.obs.status === "OK" ? r.obs.loss_onset_t : nothing,
                "top3_Nm" => r.obs.status === "OK" ?
                    [Dict("c" => t.c, "m" => t.m, "N_m" => t.N_m) for t in r.obs.top3_Nm] : nothing)
            for r in rows
        ]), 2)
    end
    println("\nWrote $sjson")
end

main()
