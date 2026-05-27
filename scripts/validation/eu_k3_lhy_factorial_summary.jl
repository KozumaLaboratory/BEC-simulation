#!/usr/bin/env julia
#
# eu_k3_lhy_factorial_summary.jl — full 2×4 factorial K3 × LHY at
# cigar regime. Combines:
#   K3=0  baseline (from runs/eu_k3_sweep/K3x0p0.yaml)
#   K3=200 baseline (from runs/eu_k3_sweep/K3x200p0.yaml)
#   K3=0  + LHY {scalar, polar_contact, icosa} (runs/eu_k3_lhy_control/)
#   K3=200+ LHY {scalar, polar_contact, icosa} (runs/eu_k3_lhy/)

using JLD2
using JSON
using Printf
using SpinorBEC

const RUNS = joinpath(@__DIR__, "..", "..", "runs")

function _find_output_dir(yaml_path::String)
    base = splitext(basename(yaml_path))[1]
    ymtime = mtime(yaml_path)
    # Strict match: dir basename must be EXACTLY `<base>_<8 hex chars>`,
    # otherwise sibling prefixes (e.g. `LHY_polar_contact` matching
    # `LHY_polar_contact_K0`) bleed into the search.
    pat = Regex("^" * base * "_[0-9a-f]{8}\$")
    cand = String[]
    for d in readdir(RUNS; join=true)
        isdir(d) || continue
        occursin(pat, basename(d)) || continue
        isfile(joinpath(d, "result.jld2")) || continue
        mtime(d) > ymtime || continue
        push!(cand, d)
    end
    isempty(cand) && return nothing
    sort!(cand; by=d -> mtime(d))
    last(cand)
end

function _compute(yaml_path::String, label::String, K3, LHY_kind)
    outdir = _find_output_dir(yaml_path)
    outdir === nothing && return (label=label, K3=K3, LHY=LHY_kind, status="PENDING")
    res = joinpath(outdir, "result.jld2")
    isfile(res) || return (label=label, K3=K3, LHY=LHY_kind, status="PENDING")
    f = try
        jldopen(res, "r")
    catch
        return (label=label, K3=K3, LHY=LHY_kind, status="LOCKED")
    end
    try
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        peaks = Float64[Float64(maximum(SpinorBEC.total_density(g[fr], 3))) for fr in frames]
        times = Vector{Float64}(f["dynamics/times"])
        norms = Vector{Float64}(f["dynamics/norms"])
        Fz = Vector{Float64}(f["dynamics/Fz"])
        cp = f["dynamics/component_populations"]
        peak_max = maximum(peaks)
        ratio = peak_max / peaks[1]
        idx_2x = findfirst(p -> p > 2 * peaks[1], peaks)
        coll_t = idx_2x === nothing ? NaN : times[idx_2x]
        idx_max = argmax(peaks)
        peak_growing = idx_max == length(peaks)
        Nratio = norms[end] / norms[1]
        cls = if !isnan(coll_t)
            peak_growing ? "collapse" : "delay"
        else
            peak_growing ? "marginal_arrest" :
                (Nratio < 0.5 ? "sacrificial_arrest" : "stable_arrest")
        end
        Nm_final = cp[end, :]
        top3_idx = sortperm(Nm_final; rev=true)[1:3]
        top3 = [(m=6 - (c - 1), N_m=Nm_final[c]) for c in top3_idx]
        (label=label, K3=K3, LHY=LHY_kind, status="OK",
            peak_max=peak_max, ratio=ratio, classification=cls,
            N_final_ratio=Nratio,
            Fz_per_N=Fz[end] / norms[end],
            top3=top3)
    finally
        close(f)
    end
end

function main()
    cells = [
        (joinpath(RUNS, "eu_k3_sweep", "K3x0p0.yaml"), "K3=0, LHY=off", 0, "off"),
        (joinpath(RUNS, "eu_k3_lhy_control", "LHY_scalar_K0.yaml"), "K3=0, LHY=scalar", 0, "scalar"),
        (joinpath(RUNS, "eu_k3_lhy_control", "LHY_polar_contact_K0.yaml"), "K3=0, LHY=polar_contact", 0, "polar_contact"),
        (joinpath(RUNS, "eu_k3_lhy_control", "LHY_icosahedral_K0.yaml"), "K3=0, LHY=icosa", 0, "icosahedral"),
        (joinpath(RUNS, "eu_k3_sweep", "K3x200p0.yaml"), "K3=200, LHY=off", 200, "off"),
        (joinpath(RUNS, "eu_k3_lhy", "LHY_scalar.yaml"), "K3=200, LHY=scalar", 200, "scalar"),
        (joinpath(RUNS, "eu_k3_lhy", "LHY_polar_contact.yaml"), "K3=200, LHY=polar_contact", 200, "polar_contact"),
        (joinpath(RUNS, "eu_k3_lhy", "LHY_icosahedral.yaml"), "K3=200, LHY=icosa", 200, "icosahedral"),
    ]
    println("# Full 2×4 K3 × LHY factorial at cigar regime")
    println("# (cigar N=30k ω_z=0.25; same loss = 2e-39 m⁶/s where K3=200; t=20 dimless)")
    println()
    @printf("%-25s %-5s %-15s %-9s %-13s %-7s %-15s %-10s %-+10s\n",
        "config", "K3", "LHY", "status", "peak_max", "ratio",
        "classification", "N(T)/N(0)", "Fz/N")
    println(repeat("-", 135))
    rows = []
    for (yaml, label, K3, LHY) in cells
        obs = _compute(yaml, label, K3, LHY)
        if obs.status === "OK"
            @printf("%-25s %-5d %-15s %-9s %-13.5e %-7.3f %-15s %-10.5f %-+10.4e\n",
                label, K3, LHY, "OK", obs.peak_max, obs.ratio, obs.classification,
                obs.N_final_ratio, obs.Fz_per_N)
            println("  top-3: " * join(["m=$(t.m):$(round(t.N_m; digits=3))" for t in obs.top3], ", "))
        else
            @printf("%-25s %-5d %-15s %-9s %-13s %-7s %-15s %-10s %-10s\n",
                label, K3, LHY, obs.status, "-", "-", "-", "-", "-")
        end
        push!(rows, obs)
    end

    sjson = joinpath(RUNS, "eu_k3_lhy_control", "factorial_2x4.json")
    open(sjson, "w") do io
        JSON.print(io, Dict("rows" => [
            r.status === "OK" ?
            Dict("label" => r.label, "K3" => r.K3, "LHY" => r.LHY,
                "status" => "OK",
                "peak_max" => r.peak_max, "ratio" => r.ratio,
                "classification" => r.classification,
                "N_final_ratio" => r.N_final_ratio,
                "Fz_per_N" => r.Fz_per_N,
                "top3" => [Dict("m" => t.m, "N_m" => t.N_m) for t in r.top3]) :
            Dict("label" => r.label, "K3" => r.K3, "LHY" => r.LHY,
                "status" => string(r.status))
            for r in rows
        ]), 2)
    end
    println("\nWrote $sjson")
end

main()
