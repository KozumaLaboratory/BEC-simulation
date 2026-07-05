# Summarize a set of runs into peak/mean vortex + Barnett metrics for the
# optimization scaling graphs.
#
# Usage: julia --project=. summarize_runs.jl <out.csv> path1 param1 path2 param2 ...
# Each pair = (result.jld2, parameter value). Outputs:
#   param,peak_Lz,peak_Fz,meanabs_Lz,peak_vtx

using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf

function run_metrics(rj)
    rr = open_result(rj); grid = rr.grid
    N = length(grid.config.n_points); D = size(rr.psi, N + 1); F = (D - 1) ÷ 2
    sys = SpinSystem(F); plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)
    Fz_max = 0.0; Lz_max = 0.0; Lz_abs_sum = 0.0; n = 0; vtx_max = 0
    jldopen(rj, "r") do f
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        for fr in frames
            psi = ComplexF64.(g[fr])
            npts = ntuple(d -> size(psi, d), N)
            Fz = magnetization(psi, grid, sys); Lz = orbital_angular_momentum(psi, grid, plans)
            Fz_max = max(Fz_max, abs(Fz)); Lz_max = max(Lz_max, abs(Lz))
            Lz_abs_sum += abs(Lz); n += 1
            # peak vortex count on most-vortical component (mid-z, masked)
            zc = npts[3] ÷ 2 + 1
            best = 0
            pops = [sum(abs2, psi[SpinorBEC._component_slice(N, npts, c)...]) for c in 1:D]
            for c in 1:D
                pops[c] / sum(pops) < 0.02 && continue
                amp = sqrt(maximum(abs2, psi[SpinorBEC._component_slice(N, npts, c)...][:, :, zc]))
                wf = winding_number_field(psi, grid; component=c, threshold=0.15 * amp)
                ws = view(wf, :, :, zc)
                best = max(best, abs(sum(ws)))
            end
            vtx_max = max(vtx_max, best)
        end
    end
    (peak_Lz=Lz_max, peak_Fz=Fz_max, meanabs_Lz=Lz_abs_sum / max(n, 1), peak_vtx=vtx_max)
end

function main()
    outcsv = ARGS[1]
    rows = ["param,peak_Lz,peak_Fz,meanabs_Lz,peak_vtx"]
    i = 2
    while i + 1 <= length(ARGS)
        path = ARGS[i]; param = parse(Float64, ARGS[i+1]); i += 2
        m = run_metrics(path)
        push!(rows, @sprintf("%.6g,%.5f,%.5f,%.5f,%d", param, m.peak_Lz, m.peak_Fz, m.meanabs_Lz, m.peak_vtx))
        @printf("param=%.4g  peakLz=%.3f peakFz=%.3f meanLz=%.3f vtx=%d\n",
                param, m.peak_Lz, m.peak_Fz, m.meanabs_Lz, m.peak_vtx)
    end
    open(outcsv, "w") do io; for r in rows; println(io, r); end; end
    println("[summary] wrote $outcsv")
end
main()
