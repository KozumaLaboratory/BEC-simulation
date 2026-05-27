#!/usr/bin/env julia
#
# barnett_eu_window_summary.jl — Klaus/Barnett parameter window
# analysis. Per cell extract Fz, Lz, Jz, peak density, N(T)/N(0).
# Use Lz from orbital angular momentum analyzer if available, else
# compute it from psi snapshots (heavy; skip for now and just use
# rotating-frame energy as a proxy).

using JLD2
using JSON
using Printf
using SpinorBEC

const ROOT = joinpath(@__DIR__, "..", "..", "runs", "barnett_eu_window")

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
        norms = Vector{Float64}(f["dynamics/norms"])
        Fz = Vector{Float64}(f["dynamics/Fz"])
        peak_max = maximum(peaks)
        (label=label, status="OK", outdir=outdir,
            peak0=peaks[1], peak_max=peak_max,
            peak_ratio=peak_max / peaks[1],
            N_initial=norms[1], N_final=norms[end],
            N_final_ratio=norms[end] / norms[1],
            Fz_initial=Fz[1], Fz_final=Fz[end],
            Fz_per_N_final=Fz[end] / norms[end],
            DeltaFz_per_N=(Fz[end] - Fz[1]) / norms[end])
    finally
        close(f)
    end
end

function _parse_meta(label::String)
    # Parse Ω sign + DDI from "barnett_eu_omp0p5_DDIon" style.
    omega = if occursin("omp", label)
        +parse(Float64, replace(match(r"omp(\d+p\d+)", label).captures[1], "p" => "."))
    elseif occursin("omm", label)
        -parse(Float64, replace(match(r"omm(\d+p\d+)", label).captures[1], "p" => "."))
    elseif occursin("omz", label)
        0.0
    else
        NaN
    end
    ddi_on = occursin("DDIon", label)
    (omega=omega, ddi_on=ddi_on)
end

function main()
    yamls = sort(filter(endswith(".yaml"), readdir(ROOT; join=true)))
    println("# Barnett Eu parameter window summary")
    println("# Matsui-like trap, N=1e4, c1/c0=1/36, B = 2.6 nT, t = 10 dimless ≈ 14.5 ms")
    println()
    @printf("%-32s %-+6s %-5s %-9s %-13s %-7s %-+13s %-10s %-+12s\n",
        "config", "Ω", "DDI", "status", "peak_max", "p_ratio",
        "Fz/N (T)", "N(T)/N(0)", "ΔFz/N")
    println(repeat("-", 130))

    rows = []
    for y in yamls
        label = splitext(basename(y))[1]
        meta = _parse_meta(label)
        obs = _compute(y, label)
        if obs.status === "OK"
            @printf("%-32s %-+6.1f %-5s %-9s %-13.5e %-7.3f %-+13.4e %-10.5f %-+12.4e\n",
                label, meta.omega, meta.ddi_on ? "on" : "off", "OK",
                obs.peak_max, obs.peak_ratio,
                obs.Fz_per_N_final, obs.N_final_ratio, obs.DeltaFz_per_N)
        else
            @printf("%-32s %-+6.1f %-5s %-9s %-13s %-7s %-13s %-10s %-12s\n",
                label, meta.omega, meta.ddi_on ? "on" : "off", obs.status,
                "-", "-", "-", "-", "-")
        end
        push!(rows, (label=label, omega=meta.omega, ddi_on=meta.ddi_on, obs=obs))
    end

    sjson = joinpath(ROOT, "summary.json")
    open(sjson, "w") do io
        JSON.print(io, Dict("rows" => [
            r.obs.status === "OK" ?
            Dict("label" => r.label, "omega" => r.omega, "ddi_on" => r.ddi_on,
                "status" => "OK",
                "peak0" => r.obs.peak0, "peak_max" => r.obs.peak_max,
                "peak_ratio" => r.obs.peak_ratio,
                "N_initial" => r.obs.N_initial, "N_final" => r.obs.N_final,
                "N_final_ratio" => r.obs.N_final_ratio,
                "Fz_initial" => r.obs.Fz_initial, "Fz_final" => r.obs.Fz_final,
                "Fz_per_N_final" => r.obs.Fz_per_N_final,
                "DeltaFz_per_N" => r.obs.DeltaFz_per_N) :
            Dict("label" => r.label, "omega" => r.omega, "ddi_on" => r.ddi_on,
                "status" => string(r.obs.status))
            for r in rows
        ]), 2)
    end
    println("\nWrote $sjson")
end

main()
