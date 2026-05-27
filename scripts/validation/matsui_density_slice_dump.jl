#!/usr/bin/env julia
#
# matsui_density_slice_dump.jl — extract z=0 plane density slices for
# top-m components from the Matsui 5ms 64³ run. Output JSON readable
# by `make_week_figures.py` for the morphology figure.

using JLD2
using JSON
using SpinorBEC

const ROOT = joinpath(@__DIR__, "..", "..", "runs", "matsui_baseline")

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

function main()
    yaml = joinpath(ROOT, "matsui_5ms_morphology_n64.yaml")
    outdir = _find_output_dir(yaml)
    outdir === nothing && error("no Matsui 5ms 64³ output found")
    res = joinpath(outdir, "result.jld2")
    println("loading $res")

    out = Dict{String, Any}()
    out["src"] = outdir

    f = jldopen(res, "r")
    try
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        # Pick last frame (closest to 5 ms) + first frame for comparison.
        idx_pairs = [("initial", frames[1]), ("final", frames[end])]
        D = nothing
        for (label, fr) in idx_pairs
            psi = g[fr]
            n_pts = size(psi)[1:3]
            D = size(psi, 4)
            # Slice at z = n_pts[3] / 2 + 1 (mid-plane)
            zmid = div(n_pts[3], 2) + 1
            slices = Dict{String, Vector{Vector{Float64}}}()
            for c in 1:D
                m = (D - 1) ÷ 2 - (c - 1)   # for F=6: c=1→m=+6, c=13→m=-6
                # |ψ_c(x, y, z=zmid)|² as (n_x, n_y) matrix → row-major JSON
                slice = abs2.(psi[:, :, zmid, c])
                slices["m_$(m)"] = [Vector{Float64}(slice[i, :]) for i in 1:size(slice, 1)]
            end
            out[label] = Dict("z_slice" => slices, "frame" => fr,
                "shape_xy" => collect(size(psi)[1:2]))
        end
        # Also store grid axes for plotting.
        # Box was 12, n_pts 64 → dx = 12/64
        out["box"] = 12.0
        out["n_xy"] = 64
        out["F"] = (D !== nothing ? (D - 1) ÷ 2 : 6)
    finally
        close(f)
    end

    outpath = joinpath(ROOT, "matsui_5ms_n64_density_slice.json")
    open(outpath, "w") do io
        JSON.print(io, out)
    end
    println("wrote $outpath  ($(div(filesize(outpath), 1024)) KB)")
end

main()
