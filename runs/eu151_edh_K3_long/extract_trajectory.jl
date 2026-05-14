# Extract per-frame trajectory data from result.jld2 and write CSV.
#
# Output columns: frame, t, norm, peak_density, Fz, pop_m6..pop_m_minus6
#
# Lz (orbital angular momentum) is intentionally NOT extracted here —
# it requires gradients of psi, which are easier to compute on the GPU
# during the run via observable callbacks. Future work.

using SpinorBEC   # loads CodecZstd's compressor in the right world age
using JLD2
using CodecZstd
using Printf

const RUN_DIR = @__DIR__
const RESULT = joinpath(RUN_DIR, "result.jld2")
const CSV_OUT = joinpath(RUN_DIR, "trajectory.csv")

function extract()
    println("[extract] reading $RESULT")
    jldopen(RESULT, "r") do f
        times = f["dynamics/times"]
        norms = f["dynamics/norms"]
        Fz = f["dynamics/Fz"]
        pops = f["dynamics/component_populations"]
        n_frames = length(times)
        n_components = size(pops, 2)
        println("[extract] $n_frames frames, $n_components components")

        # Peak density per frame from streamed snapshots.
        snap_grp = f["dynamics/psi_snapshots_streamed"]
        peak_n = Vector{Float64}(undef, n_frames)
        for i in 1:n_frames
            key = @sprintf("frame_%05d", i)
            if !haskey(snap_grp, key)
                peak_n[i] = NaN
                continue
            end
            psi = snap_grp[key]            # (nx, ny, nz, nc) ComplexF32
            n_tot = dropdims(sum(abs2, psi; dims=4); dims=4)
            peak_n[i] = Float64(maximum(n_tot))
            if i % 50 == 0
                println("[extract]  frame $i / $n_frames peak_n=$(peak_n[i])")
            end
        end

        open(CSV_OUT, "w") do io
            # header
            cols = String["frame", "t", "norm", "peak_density", "Fz"]
            for m in 1:n_components
                push!(cols, "pop_c$(m)")   # c1 = m=+F, cD = m=−F
            end
            println(io, join(cols, ","))
            for i in 1:n_frames
                row = String[
                    string(i),
                    @sprintf("%.6e", times[i]),
                    @sprintf("%.6e", norms[i]),
                    @sprintf("%.6e", peak_n[i]),
                    @sprintf("%.6e", Fz[i]),
                ]
                for m in 1:n_components
                    push!(row, @sprintf("%.6e", pops[i, m]))
                end
                println(io, join(row, ","))
            end
        end
        println("[extract] wrote $CSV_OUT")
    end
end

extract()
