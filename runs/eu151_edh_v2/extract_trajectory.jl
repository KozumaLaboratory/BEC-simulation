#!/usr/bin/env julia
#
# extract_trajectory.jl — pulls per-frame observables from this dir's
# result.jld2 files (one per comparison_runs cell) into a single
# trajectory.json for plotting.
#
# Pattern adapted from runs/eu151_edh_K3_long/extract_trajectory.jl.

using JLD2
using JSON
using CodecZstd
using SpinorBEC

const HERE = @__DIR__
const ROOT = joinpath(HERE, "..")

# Find the comparison_runs subdirs created by this YAML.
const BASE = "eu151_edh_v2"
function _find_cell_dirs()
    dirs = String[]
    for d in readdir(ROOT; join=true)
        isdir(d) || continue
        b = basename(d)
        startswith(b, BASE * "_") || continue
        isfile(joinpath(d, "result.jld2")) || continue
        push!(dirs, d)
    end
    return sort(dirs)
end

function _extract(d::String)
    res = joinpath(d, "result.jld2")
    out = Dict{String, Any}()
    jldopen(res, "r") do f
        # Component populations + global Fz + norms + times.
        times = haskey(f, "dynamics/times") ? Vector{Float64}(f["dynamics/times"]) : Float64[]
        norms = haskey(f, "dynamics/norms") ? Vector{Float64}(f["dynamics/norms"]) : Float64[]
        Fz    = haskey(f, "dynamics/Fz")    ? Vector{Float64}(f["dynamics/Fz"])    : Float64[]
        cp    = haskey(f, "dynamics/component_populations") ?
                Matrix{Float64}(f["dynamics/component_populations"]) : zeros(0, 0)

        n = min(length(times), length(norms), length(Fz))
        n_cp = size(cp, 1)
        n_use = min(n, n_cp)

        t_ms = times[1:n_use] .* 1000 / 691.15
        N_over_N0 = norms[1:n_use] ./ norms[1]
        Fz_per_N = Fz[1:n_use] ./ norms[1:n_use]

        # Per-m populations (m=+6 .. m=-6).
        N_m_t = Dict{String, Vector{Float64}}()
        for c in 1:13
            m = 7 - c
            N_m_t["m_$(m)"] = cp[1:n_use, c] ./ sum(cp[1:n_use, :]; dims=2)[:]
        end

        # Peak density at each snapshot (z-summed total density).
        g = haskey(f, "dynamics/psi_snapshots_streamed") ?
            f["dynamics/psi_snapshots_streamed"] : nothing
        peak_t = Float64[]
        if g !== nothing
            frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
            for fr in frames
                psi = g[fr]
                push!(peak_t, Float64(maximum(SpinorBEC.total_density(psi, 3))))
            end
        end

        out["t_ms"]      = collect(t_ms)
        out["N_over_N0"] = collect(N_over_N0)
        out["Fz_per_N"]  = collect(Fz_per_N)
        out["N_m_t"]     = N_m_t
        out["peak_t"]    = peak_t
    end
    return out
end

function main()
    dirs = _find_cell_dirs()
    if isempty(dirs)
        println("No eu151_edh_v2_* dirs found.  Run the YAML first.")
        return
    end
    println("Found $(length(dirs)) cell(s):")
    for d in dirs
        println("  $d")
    end

    out = Dict{String, Any}()
    for d in dirs
        b = basename(d)
        # Strip "eu151_edh_v2_" prefix and 9-char hash suffix "_<hash>".
        m = match(r"^eu151_edh_v2_(.+?)_[0-9a-f]{8}$", b)
        cell = m === nothing ? b : m.captures[1]
        println("\nExtracting cell '$cell' from $b ...")
        out[cell] = _extract(d)
        println("  $(length(out[cell]["t_ms"])) frames, ",
                "N(end)/N(0) = $(round(out[cell]["N_over_N0"][end]; digits=4)), ",
                "Fz/N(end) = $(round(out[cell]["Fz_per_N"][end]; digits=4))")
    end

    outpath = joinpath(HERE, "trajectory.json")
    open(outpath, "w") do io
        JSON.print(io, out, 2)
    end
    println("\nWrote $outpath")
end

main()
