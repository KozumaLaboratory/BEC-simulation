# Dump all-frame 2D fields for the vortex animation.
# For each run: per frame -> total column density, vortex-host column
# density, mid-z current (jx,jy); plus a scalars CSV (t, Fz, Lz).
#
# Usage: julia --project=. make_video_data.jl <result.jld2> <Omega> <outdir>

using SpinorBEC
using JLD2, CodecZstd, FFTW, DelimitedFiles, Printf

function main()
    rj = ARGS[1]; Om = parse(Float64, ARGS[2]); outdir = ARGS[3]
    mkpath(outdir)
    rr = open_result(rj); grid = rr.grid
    N = length(grid.config.n_points); D = size(rr.psi, N + 1); F = (D - 1) ÷ 2
    sys = SpinSystem(F); plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)
    dV = cell_volume(grid); zc = grid.config.n_points[3] ÷ 2 + 1

    scal = String["frame,t,Fz,Lz"]
    jldopen(rj, "r") do f
        times = collect(Float64, f["dynamics/times"])
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        nf = length(frames)
        stimes = length(times) == nf + 1 ? times[2:end] :
                 length(times) == nf ? times : times[1:min(nf, length(times))]
        for (i, fr) in enumerate(frames)
            psi = ComplexF64.(g[fr])
            npts = ntuple(d -> size(psi, d), N)
            ntot = dropdims(sum(abs2, psi; dims=N+1); dims=N+1)
            # vortex-host = transferred component with deepest central hole
            pops = [sum(abs2, psi[SpinorBEC._component_slice(N, npts, c)...]) * dV for c in 1:D]
            chost = argmax(pops); besthole = Inf
            for c in 1:D
                pops[c] < 0.03 && continue
                dc = abs2.(psi[SpinorBEC._component_slice(N, npts, c)...][:, :, zc])
                mx = maximum(dc); mx <= 0 && continue
                center = dc[npts[1]÷2+1, npts[2]÷2+1] / mx
                if center < besthole; besthole = center; chost = c; end
            end
            hostdens = dropdims(sum(abs2, psi[SpinorBEC._component_slice(N, npts, chost)...]; dims=3); dims=3)
            jvec = probability_current(psi, grid, plans)
            writedlm(joinpath(outdir, @sprintf("f%03d_ncol.csv", i)), dropdims(sum(ntot; dims=3); dims=3), ',')
            writedlm(joinpath(outdir, @sprintf("f%03d_host.csv", i)), hostdens, ',')
            writedlm(joinpath(outdir, @sprintf("f%03d_jx.csv", i)), jvec[1][:, :, zc], ',')
            writedlm(joinpath(outdir, @sprintf("f%03d_jy.csv", i)), jvec[2][:, :, zc], ',')
            Fz = magnetization(psi, grid, sys); Lz = orbital_angular_momentum(psi, grid, plans)
            t = i <= length(stimes) ? stimes[i] : NaN
            push!(scal, @sprintf("%d,%.4f,%.5f,%.5f", i, t, Fz, Lz))
        end
        writedlm(joinpath(outdir, "grid_x.csv"), collect(grid.x[1]), ',')
        writedlm(joinpath(outdir, "grid_y.csv"), collect(grid.x[2]), ',')
        open(joinpath(outdir, "scalars.csv"), "w") do io; for s in scal; println(io, s); end; end
        println("[video-data] $nf frames -> $outdir")
    end
end
main()
