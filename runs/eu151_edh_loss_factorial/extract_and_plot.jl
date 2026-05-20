# Extract per-frame trajectory from the 4 factorial cells and render a
# side-by-side comparison plot.
#
# Reads: runs/eu151_edh_loss_factorial/point_001_K3{off,on}_gdr{off,on}.jld2
# Writes: trajectory.csv (long-format: branch,frame,t,norm,peak,Fz,pop_*)
#         trajectory.{pdf,png,svg} (4-panel: norm / peak / Fz / Δpop_m=+F)
#
# Usage:
#   julia --project=. runs/eu151_edh_loss_factorial/extract_and_plot.jl
#
# Renders via matplotlib (python sub-shell). The plot script lives next
# to this one as plot_trajectory.py.

using SpinorBEC   # CodecZstd world-age fix
using JLD2
using CodecZstd
using Printf

const RUN_DIR = @__DIR__
const CELLS = ["K3off_gdroff", "K3off_gdron", "K3on_gdroff", "K3on_gdron"]
const CSV_OUT = joinpath(RUN_DIR, "trajectory.csv")

function find_result_for(cell::AbstractString)
    # comparison_runs writes point_001_<cell>.jld2 OR per-cell subdir
    candidates = [
        joinpath(RUN_DIR, "point_001_$(cell).jld2"),
        joinpath(RUN_DIR, cell, "result.jld2"),
        joinpath(RUN_DIR, "$(cell).jld2"),
    ]
    for p in candidates
        isfile(p) && return p
    end
    nothing
end

function extract_cell(path::AbstractString)
    jldopen(path, "r") do f
        times = f["dynamics/times"]
        norms = f["dynamics/norms"]
        Fz = f["dynamics/Fz"]
        pops = f["dynamics/component_populations"]
        snap_grp = f["dynamics/psi_snapshots_streamed"]
        n_frames = length(times)
        peak_n = Vector{Float64}(undef, n_frames)
        for i in 1:n_frames
            key = @sprintf("frame_%05d", i)
            if !haskey(snap_grp, key)
                peak_n[i] = NaN
                continue
            end
            psi = snap_grp[key]
            n_tot = dropdims(sum(abs2, psi; dims=4); dims=4)
            peak_n[i] = Float64(maximum(n_tot))
        end
        (times=collect(times), norms=collect(norms),
         Fz=collect(Fz), pops=Array(pops), peak=peak_n)
    end
end

function main()
    rows = String[]
    push!(rows, "branch,frame,t,norm,peak,Fz," *
        join(["pop_c$(c)" for c in 1:13], ","))
    for cell in CELLS
        path = find_result_for(cell)
        if path === nothing
            @warn "missing result for cell" cell
            continue
        end
        println("[extract] $cell <- $path")
        d = extract_cell(path)
        n_comp = size(d.pops, 2)
        for i in 1:length(d.times)
            row = [cell, string(i),
                @sprintf("%.6e", d.times[i]),
                @sprintf("%.6e", d.norms[i]),
                @sprintf("%.6e", d.peak[i]),
                @sprintf("%.6e", d.Fz[i])]
            for c in 1:n_comp
                push!(row, @sprintf("%.6e", d.pops[i, c]))
            end
            push!(rows, join(row, ","))
        end
    end
    open(CSV_OUT, "w") do io
        for line in rows; println(io, line); end
    end
    println("[csv] wrote $CSV_OUT  ($(length(rows)-1) rows)")
end

main()
