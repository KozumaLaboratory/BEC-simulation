#!/usr/bin/env julia
#
# eu_k3_lhy_summary.jl — Task #19C. Compares 4 LHY model variants
# at K3=200× cigar regime:
#   off            — baseline from eu_k3_sweep/K3x200p0.yaml
#   scalar         — eu_k3_lhy/LHY_scalar.yaml
#   polar_contact  — eu_k3_lhy/LHY_polar_contact.yaml
#   icosahedral    — eu_k3_lhy/LHY_icosahedral.yaml

using JLD2
using JSON
using Printf
using SpinorBEC

const ROOT_LHY = joinpath(@__DIR__, "..", "..", "runs", "eu_k3_lhy")
const ROOT_SWEEP = joinpath(@__DIR__, "..", "..", "runs", "eu_k3_sweep")

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

function _compute(yaml_path::String, label::String)
    outdir = _find_output_dir(yaml_path)
    outdir === nothing && return (label=label, status="PENDING")
    res = joinpath(outdir, "result.jld2")
    isfile(res) || return (label=label, status="PENDING")
    f = try
        jldopen(res, "r")
    catch
        return (label=label, status="LOCKED")
    end
    try
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        peaks = Float64[Float64(maximum(SpinorBEC.total_density(g[fr], 3))) for fr in frames]
        times = Vector{Float64}(f["dynamics/times"])
        n = min(length(times), length(peaks))
        peaks = peaks[1:n]; times = times[1:n]
        norms = Vector{Float64}(f["dynamics/norms"])
        Fz = Vector{Float64}(f["dynamics/Fz"])
        cp = f["dynamics/component_populations"]
        Nm_final = cp[end, :]
        cls = _classify(peaks, times, norms[end] / norms[1])
        top3_idx = sortperm(Nm_final; rev=true)[1:3]
        top3 = [(c=c, m=6 - (c - 1), N_m=Nm_final[c]) for c in top3_idx]
        (label=label, status="OK", outdir=outdir,
            peak0=peaks[1], peak_max=maximum(peaks),
            ratio=maximum(peaks) / peaks[1],
            classification=cls,
            absolute_Fz_initial=Fz[1],
            absolute_Fz_final=Fz[end],
            N_initial=norms[1],
            N_final_ratio=norms[end] / norms[1],
            Fz_per_atom=Fz[end] / norms[end],
            top3_Nm=top3)
    finally
        close(f)
    end
end

function main()
    cells = [
        (joinpath(ROOT_SWEEP, "K3x200p0.yaml"), "off"),
        (joinpath(ROOT_LHY, "LHY_scalar.yaml"), "scalar"),
        (joinpath(ROOT_LHY, "LHY_polar_contact.yaml"), "polar_contact"),
        (joinpath(ROOT_LHY, "LHY_icosahedral.yaml"), "icosahedral"),
    ]

    println("# Task #19C — LHY model interference at K3=200× cigar regime")
    println("# (cigar N=30k ω_z=0.25, γ_dr off; same loss = 2e-39 m⁶/s)")
    println()
    @printf("%-15s %-9s %-13s %-7s %-19s %-+10s %-+10s %-10s %-+10s\n",
        "LHY_kind", "status", "peak_max", "ratio", "class",
        "Fz(0)", "Fz(T)", "N(T)/N(0)", "Fz/N(T)")
    println(repeat("-", 130))
    rows = []
    for (yaml, label) in cells
        obs = _compute(yaml, label)
        if obs.status === "OK"
            @printf("%-15s %-9s %-13.5e %-7.3f %-19s %-+10.4e %-+10.4e %-10.5f %-+10.4e\n",
                label, "OK", obs.peak_max, obs.ratio, obs.classification,
                obs.absolute_Fz_initial, obs.absolute_Fz_final,
                obs.N_final_ratio, obs.Fz_per_atom)
            println("  top-3 N_m at T=20: " *
                join(["m=$(t.m): $(round(t.N_m; digits=4))" for t in obs.top3_Nm], ", "))
        else
            @printf("%-15s %-9s %-13s %-7s %-19s %-10s %-10s %-10s %-10s\n",
                label, obs.status, "-", "-", "-", "-", "-", "-", "-")
        end
        push!(rows, obs)
    end

    sjson = joinpath(ROOT_LHY, "summary.json")
    open(sjson, "w") do io
        JSON.print(io, Dict("rows" => [
            Dict("LHY_kind" => r.label,
                "status" => string(r.status),
                "peak_max" => r.status === "OK" ? r.peak_max : nothing,
                "ratio" => r.status === "OK" ? r.ratio : nothing,
                "classification" => r.status === "OK" ? r.classification : nothing,
                "absolute_Fz_initial" => r.status === "OK" ? r.absolute_Fz_initial : nothing,
                "absolute_Fz_final" => r.status === "OK" ? r.absolute_Fz_final : nothing,
                "N_final_ratio" => r.status === "OK" ? r.N_final_ratio : nothing,
                "Fz_per_atom" => r.status === "OK" ? r.Fz_per_atom : nothing,
                "top3_Nm" => r.status === "OK" ?
                    [Dict("c" => t.c, "m" => t.m, "N_m" => t.N_m) for t in r.top3_Nm] : nothing)
            for r in rows
        ]), 2)
    end
    println("\nWrote $sjson")
end

main()
