#!/usr/bin/env julia
#
# eu_k3_arrest_summary.jl — collapse-arrest analysis at the cigar
# regime (Task #18). Filters output dirs by mtime > YAML mtime so
# stale eu_robust_factorial caches (same basename, different physics)
# don't bleed into the result.

using JLD2
using JSON
using Printf
using SpinorBEC

const ROOT = joinpath(@__DIR__, "..", "..", "runs", "eu_k3_arrest")

function _find_output_dir(yaml_path::String)
    base = splitext(basename(yaml_path))[1]
    ymtime = mtime(yaml_path)
    runs_root = joinpath(@__DIR__, "..", "..", "runs")
    candidates = String[]
    for d in readdir(runs_root; join=true)
        isdir(d) || continue
        startswith(basename(d), base * "_") || continue
        isfile(joinpath(d, "result.jld2")) || continue
        # Only consider dirs created after the YAML was written;
        # otherwise stale runs from sibling factorials (same basename)
        # masquerade as our result.
        mtime(d) > ymtime || continue
        push!(candidates, d)
    end
    isempty(candidates) && return nothing
    sort!(candidates; by=d -> mtime(d))
    last(candidates)
end

function _compute(yaml_path::String)
    outdir = _find_output_dir(yaml_path)
    outdir === nothing && return (status="PENDING",)
    res = joinpath(outdir, "result.jld2")
    isfile(res) || return (status="PENDING",)

    f = jldopen(res, "r")
    try
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        peaks = [maximum(SpinorBEC.total_density(g[fr], 3)) for fr in frames]
        norms = Vector{Float64}(f["dynamics/norms"])
        Fz = Vector{Float64}(f["dynamics/Fz"])
        times = Vector{Float64}(f["dynamics/times"])

        peak0 = peaks[1]
        peak_max = maximum(peaks)
        ratio = peak_max / peak0
        idx_2x = findfirst(p -> p > 2 * peak0, peaks)
        idx_5x = findfirst(p -> p > 5 * peak0, peaks)
        coll_2x = idx_2x === nothing ? NaN : times[idx_2x]
        coll_5x = idx_5x === nothing ? NaN : times[idx_5x]

        (status="OK", outdir=outdir,
            peak0=peak0, peak_max=peak_max, ratio=ratio,
            coll_2x=coll_2x, coll_5x=coll_5x,
            N_final_ratio=norms[end] / norms[1],
            Fz_per_atom=Fz[end] / norms[end])
    finally
        close(f)
    end
end

function main()
    yamls = sort(filter(endswith(".yaml"), readdir(ROOT; join=true)))
    println("# K3 arrest factorial at cigar regime (N=30k, ω_z=0.25)")
    println()
    @printf("%-22s %-9s %-3s %-3s %-3s %-13s %-13s %-7s %-7s %-9s %-+10s\n",
        "config", "status", "K3", "gdr", "LHY",
        "peak0", "peak_max", "ratio", "coll_t", "N(T)/N(0)", "Fz/N")
    println(repeat("-", 110))
    rows = []
    for y in yamls
        base = splitext(basename(y))[1]
        K3 = occursin("K1_", base) ? "on" : "off"
        gdr = occursin("_gdr1_", base) ? "on" : "off"
        lhy = occursin("_LHY1", base) ? "on" : "off"
        obs = _compute(y)
        if obs.status === "OK"
            @printf("%-22s %-9s %-3s %-3s %-3s %-13.5e %-13.5e %-7.2f %-7.2f %-9.5f %+10.4e\n",
                base, "OK", K3, gdr, lhy,
                obs.peak0, obs.peak_max, obs.ratio,
                obs.coll_2x, obs.N_final_ratio, obs.Fz_per_atom)
        else
            @printf("%-22s %-9s %-3s %-3s %-3s %-13s %-13s %-7s %-7s %-9s %-10s\n",
                base, obs.status, K3, gdr, lhy, "-", "-", "-", "-", "-", "-")
        end
        push!(rows, (config=base, K3=K3, gdr=gdr, lhy=lhy, obs=obs))
    end
    sjson = joinpath(ROOT, "summary.json")
    open(sjson, "w") do io
        JSON.print(io, Dict("rows" => [
            Dict("config" => r.config, "K3" => r.K3, "gdr" => r.gdr,
                "lhy" => r.lhy, "status" => string(r.obs.status),
                "peak0" => r.obs.status === "OK" ? r.obs.peak0 : nothing,
                "peak_max" => r.obs.status === "OK" ? r.obs.peak_max : nothing,
                "ratio" => r.obs.status === "OK" ? r.obs.ratio : nothing,
                "collapse_onset_2x" => r.obs.status === "OK" ? r.obs.coll_2x : nothing,
                "N_final_ratio" => r.obs.status === "OK" ? r.obs.N_final_ratio : nothing,
                "Fz_per_atom" => r.obs.status === "OK" ? r.obs.Fz_per_atom : nothing)
            for r in rows
        ]), 2)
    end
    println("\nWrote $sjson")
end

main()
