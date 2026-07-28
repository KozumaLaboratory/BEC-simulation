# P2 completion, Task 1: f_z(r) z-cross-section on the SAVED P2 end states.
#
# Distinguishes the two net-M_z failure modes on the last dynamics frame:
#   (a) z-odd spatial cancellation: local |F|=|f|/n ~ 6 everywhere, but the
#       column integral int f_z dxdy is ODD in z -> integrates to ~0 over z.
#   (b) component depolarisation: local |F| < 6, the spin cannot tilt to z.
# Both reduce the cloud-averaged |F| (the trajectory number), so only the
# LOCAL |F(r)| map + the z-resolved f_z profile separate them.
#
# Outputs (into figures/):
#   p2_zprofile_{on,off}.csv  : z, Fz_col(int f_z dxdy), N_col, Fmag_col, localF_slice
#   p2_fzxz_{on,off}.csv      : x, z, n, fz, localF   (y=0 slice, |F|=|f|/n)
#
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#          runs/eu_barnett_rotfield_clean/analyze_p2_fz_crosssection.jl
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra

const OUT = "runs/eu_barnett_rotfield_clean/figures"
const RUNS = Dict(
    "on"  => "runs/p2_on_a5258bf8/point_001.jld2",
    "off" => "runs/p2_off_7c99abc5/point_001.jld2",
)
mkpath(OUT)

# last streamed frame -> ComplexF64 psi[x,y,z,c]
function last_frame(pj)
    jldopen(pj, "r") do f
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        times = collect(Float64, f["dynamics/times"])
        t = isempty(times) ? NaN : times[end]
        (ComplexF64.(g[frames[end]]), t, length(frames))
    end
end

density(psi, N) = dropdims(sum(abs2, psi; dims = N + 1); dims = N + 1)

function analyze(tag, pj)
    rr = open_result(pj); grid = rr.grid
    N = length(grid.config.n_points); nx, ny, nz = grid.config.n_points
    D = size(rr.psi, N + 1); F = (D - 1) ÷ 2
    sm = spin_matrices(F)
    dx, dy, dz = grid.dx
    dV = cell_volume(grid); dA = dx * dy
    plans = make_fft_plans(Tuple(grid.config.n_points); flags = FFTW.ESTIMATE)

    psi, t, nfr = last_frame(pj)
    fx, fy, fz = spin_density_vector(psi, sm, N)
    n = density(psi, N)
    fmag = sqrt.(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2)

    Ntot = sum(n) * dV
    Fzt = sum(fz) * dV
    Fxt = sum(fx) * dV; Fyt = sum(fy) * dV
    Fcloud = sqrt(Fxt^2 + Fyt^2 + Fzt^2)
    Lz = orbital_angular_momentum(psi, grid, plans)

    # local |F| = |f|/n, restricted to the bulk (n above 5% of peak)
    npk = maximum(n); mask = n .> 0.05 * npk
    localF = fmag ./ max.(n, eps())
    localF_bulk = sum(localF[mask] .* n[mask]) / sum(n[mask])  # density-weighted

    @printf("[%s] t=%.2f frames=%d  Ntot=%.1f  Fz=%.4f  |F|_cloud=%.4f  Lz=%.4f  <localF>_n=%.4f\n",
        tag, t, nfr, Ntot, Fzt, Fcloud, Lz, localF_bulk)

    # z-resolved profile: column integrals over (x,y) at each z-slice
    zc = grid.x[3]
    zrows = ["z,Fz_col,N_col,Fmag_col,localF_slice"]
    for k in 1:nz
        fzc = sum(@view fz[:, :, k]) * dA
        nc  = sum(@view n[:, :, k]) * dA
        fmc = sum(@view fmag[:, :, k]) * dA
        lf  = nc > 1e-12 ? fmc / nc : 0.0
        push!(zrows, @sprintf("%.5f,%.6e,%.6e,%.6e,%.5f", zc[k], fzc, nc, fmc, lf))
    end
    open(joinpath(OUT, "p2_zprofile_$(tag).csv"), "w") do io
        for r in zrows; println(io, r); end
    end

    # y=0 slice: f_z(x,z), n(x,z), localF(x,z)
    jy = ny ÷ 2 + 1  # y closest to 0 (box symmetric, even n -> offset gridpoint)
    xc = grid.x[1]
    xzrows = ["x,z,n,fz,localF"]
    for k in 1:nz, i in 1:nx
        nv = n[i, jy, k]
        lf = nv > 1e-12 ? fmag[i, jy, k] / nv : 0.0
        push!(xzrows, @sprintf("%.5f,%.5f,%.6e,%.6e,%.5f", xc[i], zc[k], nv, fz[i, jy, k], lf))
    end
    open(joinpath(OUT, "p2_fzxz_$(tag).csv"), "w") do io
        for r in xzrows; println(io, r); end
    end

    # net f_z from the z-profile (sanity: should equal Fzt) + z-odd metric
    fzcol = [sum(@view fz[:, :, k]) * dA for k in 1:nz]
    net_from_prof = sum(fzcol) * dz
    # z-odd fraction: how much of the column f_z cancels across z-reflection
    absint = sum(abs.(fzcol)) * dz
    cancel_frac = absint > 1e-12 ? 1.0 - abs(net_from_prof) / absint : 0.0
    @printf("     net_from_zprofile=%.4f (=Fz check)  z-cancellation_frac=%.3f\n",
        net_from_prof, cancel_frac)
    return (; tag, t, Ntot, Fzt, Fcloud, Lz, localF_bulk, cancel_frac)
end

results = Dict{String,Any}()
for (tag, pj) in RUNS
    results[tag] = analyze(tag, pj)
end
println("\n===== P2 cross-section summary =====")
@printf("%-4s %8s %8s %10s %8s %10s %8s\n", "run", "Fz", "|F|cl", "localF_n", "Lz", "z-cancel", "N")
for tag in ["off", "on"]
    r = results[tag]
    @printf("%-4s %8.4f %8.4f %10.4f %8.4f %10.3f %8.0f\n",
        tag, r.Fzt, r.Fcloud, r.localF_bulk, r.Lz, r.cancel_frac, r.Ntot)
end
println("P2_XSEC_DONE")
