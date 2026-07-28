# Spin-vector + orbital trajectory for the Larmor-vs-genuine-excitation
# discriminator. Outputs t, Fx, Fy, Fz, |F|, Lz per frame.
#
# Usage: julia --project=. analyze_spin_vector.jl <result.jld2> <out.csv>

using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf

function main()
    rj = ARGS[1]; outcsv = ARGS[2]
    rr = open_result(rj); grid = rr.grid
    N = length(grid.config.n_points); D = size(rr.psi, N + 1); F = (D - 1) ÷ 2
    sm = spin_matrices(F); plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)
    dV = cell_volume(grid)
    rows = ["t,Fx,Fy,Fz,Fmag,Lz"]
    jldopen(rj, "r") do f
        times = collect(Float64, f["dynamics/times"]); g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        nf = length(frames)
        st = length(times) == nf + 1 ? times[2:end] : times[1:min(nf, length(times))]
        for (i, fr) in enumerate(frames)
            psi = ComplexF64.(g[fr])
            fx, fy, fz = spin_density_vector(psi, sm, N)
            Fx = sum(fx) * dV; Fy = sum(fy) * dV; Fz = sum(fz) * dV
            Lz = orbital_angular_momentum(psi, grid, plans)
            t = i <= length(st) ? st[i] : NaN
            push!(rows, @sprintf("%.5f,%.5f,%.5f,%.5f,%.5f,%.5f",
                                 t, Fx, Fy, Fz, sqrt(Fx^2 + Fy^2 + Fz^2), Lz))
        end
    end
    open(outcsv, "w") do io; for r in rows; println(io, r); end; end
    println("[spin-vec] wrote $outcsv")
end
main()
