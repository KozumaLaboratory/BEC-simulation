#!/usr/bin/env julia
#
# eu_k3_sweep_summary.jl — Task #19A analysis. Per-cell observables
# plus arrest-vs-delay classification.
#
# Per anko's definitions:
#   collapse:  peak_density(t) crosses 2 × initial at some t_coll
#   arrest:    peak_density(t) reaches max, then drops below 0.9 × max
#              (clear plateau / reversal); OR never crosses 2× threshold
#              even at the final time.
#   delay:     peak doubles eventually but well after the K3=0 baseline.
#
# Result table includes the classification column.

using JLD2
using JSON
using Printf
using SpinorBEC

const ROOT = joinpath(@__DIR__, "..", "..", "runs", "eu_k3_sweep")

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
    # 4-category scheme (per anko, Task #19B framing):
    #
    #   collapse:           peak doubled AND peak still growing at end
    #                       (idx_max == final snapshot)
    #   delay:              peak doubled BUT peak crests + drops before end
    #                       (cell technically "arrested" but only because
    #                       transient passed; K3 just shifted onset)
    #   marginal_arrest:    peak never doubled AND peak still growing
    #                       (would have collapsed with more time)
    #   sacrificial_arrest: peak never doubled AND peak crests + drops AND
    #                       N(T)/N(0) < 0.5 (≥ half atoms removed)
    #   stable_arrest:      peak never doubled AND peak crests + drops AND
    #                       N(T)/N(0) ≥ 0.5 (clean arrest without major loss)
    peak0 = peaks[1]
    peak_max = maximum(peaks)
    idx_max = argmax(peaks)
    t_max = times[idx_max]
    idx_2x = findfirst(p -> p > 2 * peak0, peaks)
    coll_t = idx_2x === nothing ? NaN : times[idx_2x]

    peak_growing_at_end = idx_max == length(peaks)
    classification = if !isnan(coll_t)
        peak_growing_at_end ? "collapse" : "delay"
    else
        if peak_growing_at_end
            "marginal_arrest"
        elseif N_final_ratio < 0.5
            "sacrificial_arrest"
        else
            "stable_arrest"
        end
    end
    (peak_max=peak_max, peak_max_t=t_max, coll_t=coll_t,
        classification=classification)
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
        peaks = Float64[Float64(maximum(SpinorBEC.total_density(g[fr], 3))) for fr in frames]
        times = Vector{Float64}(f["dynamics/times"])
        n = min(length(times), length(peaks))
        peaks = peaks[1:n]
        times = times[1:n]
        norms = Vector{Float64}(f["dynamics/norms"])
        Fz = Vector{Float64}(f["dynamics/Fz"])
        N_ratio_for_class = norms[end] / norms[1]
        cls = _classify(peaks, times, N_ratio_for_class)
        (status="OK", outdir=outdir,
            peak0=peaks[1],
            peak_max=cls.peak_max,
            peak_max_t=cls.peak_max_t,
            ratio=cls.peak_max / peaks[1],
            coll_t=cls.coll_t,
            classification=cls.classification,
            N_final_ratio=norms[end] / norms[1],
            Fz_per_atom=Fz[end] / norms[end])
    finally
        close(f)
    end
end

function main()
    yamls = sort(filter(endswith(".yaml"), readdir(ROOT; join=true));
        by=p -> parse(Float64, replace(replace(basename(p), "K3x" => ""), "p" => ".",
            ".yaml" => "")))
    println("# Task #19A — K3 arrest threshold sweep at cigar (N=30k, ω_z=0.25)")
    println("# LHY off, γ_dr off; K3_base = 1e-41 m⁶/s (Dy proxy)")
    println()
    @printf("%-12s %-9s %-8s %-13s %-13s %-7s %-8s %-15s %-9s %-+9s\n",
        "K3_factor", "status", "peak0", "peak_max", "peak_max_t",
        "ratio", "coll_t", "classification", "N(T)/N(0)", "Fz/N")
    println(repeat("-", 120))

    rows = []
    for y in yamls
        base = splitext(basename(y))[1]
        # Extract factor from filename: K3x0p0 → 0.0, K3x100p0 → 100.0
        factor = parse(Float64,
            replace(replace(base, "K3x" => ""), "p" => "."))
        obs = _compute(y)
        if obs.status === "OK"
            @printf("%-12.1f %-9s %-8.4f %-13.5e %-13.4f %-7.2f %-8.3f %-15s %-9.5f %-+9.4e\n",
                factor, "OK", obs.peak0, obs.peak_max, obs.peak_max_t,
                obs.ratio, obs.coll_t, obs.classification,
                obs.N_final_ratio, obs.Fz_per_atom)
        else
            @printf("%-12.1f %-9s %-8s %-13s %-13s %-7s %-8s %-15s %-9s %-9s\n",
                factor, obs.status, "-", "-", "-", "-", "-", "-", "-", "-")
        end
        push!(rows, (factor=factor, obs=obs))
    end

    sjson = joinpath(ROOT, "summary.json")
    open(sjson, "w") do io
        JSON.print(io, Dict("rows" => [
            Dict("K3_factor" => r.factor,
                "status" => string(r.obs.status),
                "peak0" => r.obs.status === "OK" ? r.obs.peak0 : nothing,
                "peak_max" => r.obs.status === "OK" ? r.obs.peak_max : nothing,
                "peak_max_t" => r.obs.status === "OK" ? r.obs.peak_max_t : nothing,
                "ratio" => r.obs.status === "OK" ? r.obs.ratio : nothing,
                "collapse_t" => r.obs.status === "OK" ? r.obs.coll_t : nothing,
                "classification" => r.obs.status === "OK" ? r.obs.classification : nothing,
                "N_final_ratio" => r.obs.status === "OK" ? r.obs.N_final_ratio : nothing,
                "Fz_per_atom" => r.obs.status === "OK" ? r.obs.Fz_per_atom : nothing)
            for r in rows
        ]), 2)
    end
    println("\nWrote $sjson")
end

main()
