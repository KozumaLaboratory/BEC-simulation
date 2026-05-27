#!/usr/bin/env julia
#
# matsui_baseline_summary.jl — Matsui reproduction analysis.
# Per cell, output:
#   - N_m(t) at characteristic times (0, 5ms, 10ms, 20ms, 40ms)
#   - peak density trajectory
#   - absolute Fz / N(t)
#   - radial profile slice at t_final (for ring detection)
#
# Writes per-cell JSON + a top-level summary.json. Used by
# `make_week_figures.py` to draw Matsui-specific panels.

using JLD2
using JSON
using Printf
using SpinorBEC

const ROOT = joinpath(@__DIR__, "..", "..", "runs", "matsui_baseline")
const OMEGA_REF = 2π * 110.0
const T_SAMPLES_MS = (0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 10.0, 20.0, 30.0, 40.0)

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
    outdir === nothing && return (label=label, status="MISSING")
    res = joinpath(outdir, "result.jld2")
    isfile(res) || return (label=label, status="MISSING")
    f = jldopen(res, "r")
    try
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        peaks = Float64[Float64(maximum(SpinorBEC.total_density(g[fr], 3))) for fr in frames]
        times_full = Vector{Float64}(f["dynamics/times"])
        norms = Vector{Float64}(f["dynamics/norms"])
        Fz = Vector{Float64}(f["dynamics/Fz"])
        cp = f["dynamics/component_populations"]  # (n_saves, 13) — saves only,
                                                  # does NOT include initial t=0
        # `times_full` includes the initial t=0 plus each save time; align with
        # cp by dropping the first entry.
        times_save = length(times_full) == size(cp, 1) ? times_full :
            times_full[2:end][1:size(cp, 1)]
        times_ms = times_save .* (1000.0 / OMEGA_REF)
        # Find indices closest to T_SAMPLES_MS. Tolerate slight overshoot
        # of the final time (FP roundoff at the duration boundary).
        sample_idx = Int[]
        sample_t_ms = Float64[]
        t_end_tol = times_ms[end] * 1.05
        for t_target in T_SAMPLES_MS
            t_target > t_end_tol && break
            i = argmin(abs.(times_ms .- t_target))
            i ∈ sample_idx && continue   # don't duplicate
            push!(sample_idx, i)
            push!(sample_t_ms, times_ms[i])
        end
        Nm_samples = [cp[i, :] for i in sample_idx]
        peak0 = peaks[1]
        peak_max = maximum(peaks)
        (label=label, status="OK", outdir=outdir,
            n_frames=length(frames),
            peak0=peak0, peak_max=peak_max,
            peak_ratio=peak_max / peak0,
            N_initial=norms[1], N_final=norms[end],
            Fz_initial=Fz[1], Fz_final=Fz[end],
            Fz_per_N_final=Fz[end] / norms[end],
            sample_t_ms=sample_t_ms,
            Nm_samples=Nm_samples,
            times_ms=times_ms,
            peaks=peaks)
    finally
        close(f)
    end
end

function main()
    yamls = sort(filter(endswith(".yaml"), readdir(ROOT; join=true)))
    println("# Matsui 2026 baseline reproduction")
    println("# Loss-free, m=-F initial, c1/c0=1/36, near-spherical trap")
    println()

    rows = []
    for y in yamls
        label = splitext(basename(y))[1]
        obs = _compute(y, label)
        push!(rows, obs)
        if obs.status === "OK"
            println("=== $label ===")
            @printf("  peak ratio = %.3f  (peak0 = %.3e → peak_max = %.3e)\n",
                obs.peak_ratio, obs.peak0, obs.peak_max)
            @printf("  N_final/N_initial = %.5f  (Matsui sim is loss-free → expect 1.0000)\n",
                obs.N_final / obs.N_initial)
            @printf("  Fz: %.4f → %.4f  (Fz/N: %.4f → %.4f)\n",
                obs.Fz_initial, obs.Fz_final,
                obs.Fz_initial / obs.N_initial, obs.Fz_per_N_final)
            println("  N_m at characteristic times (top-5 components only):")
            for (t_ms, Nm) in zip(obs.sample_t_ms, obs.Nm_samples)
                m_vals = collect(6:-1:-6)
                # Show top-5 by population
                idx = sortperm(Nm; rev=true)[1:5]
                pieces = ["m=$(m_vals[i]):$(round(Nm[i]; digits=4))" for i in idx]
                @printf("    t=%6.2f ms : %s\n", t_ms, join(pieces, ", "))
            end
            println()
        else
            println("$label: $(obs.status)")
        end
    end

    sjson = joinpath(ROOT, "summary.json")
    open(sjson, "w") do io
        JSON.print(io, Dict("rows" => [
            r.status === "OK" ?
            Dict("label" => r.label,
                "status" => "OK",
                "peak0" => r.peak0, "peak_max" => r.peak_max,
                "peak_ratio" => r.peak_ratio,
                "N_initial" => r.N_initial, "N_final" => r.N_final,
                "Fz_initial" => r.Fz_initial, "Fz_final" => r.Fz_final,
                "sample_t_ms" => r.sample_t_ms,
                "Nm_samples" => [Vector{Float64}(s) for s in r.Nm_samples],
                "times_ms" => r.times_ms, "peaks" => r.peaks) :
            Dict("label" => r.label, "status" => string(r.status))
            for r in rows
        ]), 2)
    end
    println("Wrote $sjson")
end

main()
