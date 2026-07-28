# General f_z(r) z-cross-section on ANY saved end state (Task-1 method, reusable).
# The arbiter between the three PASS-0 branches: integral F_z cannot tell
#   (Option 2) |F| held + z-EVEN flux-closure (net F_z=0 by z-cancellation)
# from
#   (Option 3) true local DEPOLARISATION (|f|/n collapses),
# because both give integral F_z ~ 0. And when integral F_z is finite, it cannot
# tell coherent-texture from noise. The LOCAL |F|=|f|/n map + z-resolved
# int f_z dxdy profile + f_z(x,z) slice settle it.
#
# Usage: julia --project=. analyze_fz_crosssection.jl <point_001.jld2> <tag> [snap]
#   snap = "last" (default) or an integer frame index.
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra

const OUT = "runs/eu_barnett_rotfield_clean/figures"
mkpath(OUT)

pj = ARGS[1]; tag = ARGS[2]; which = length(ARGS) >= 3 ? ARGS[3] : "last"

function load_frame(pj, which)
    jldopen(pj, "r") do f
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        idx = which == "last" ? length(frames) : parse(Int, which)
        ComplexF64.(g[frames[idx]])
    end
end

density(psi, N) = dropdims(sum(abs2, psi; dims = N + 1); dims = N + 1)

rr = open_result(pj); grid = rr.grid
N = length(grid.config.n_points); nx, ny, nz = grid.config.n_points
D = size(rr.psi, N + 1); F = (D - 1) ÷ 2
sm = spin_matrices(F)
dx, dy, dz = grid.dx; dV = cell_volume(grid); dA = dx * dy
plans = make_fft_plans(Tuple(grid.config.n_points); flags = FFTW.ESTIMATE)

psi = load_frame(pj, which)
fx, fy, fz = spin_density_vector(psi, sm, N)
n = density(psi, N)
fmag = sqrt.(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2)

Ntot = sum(n) * dV
Fxt = sum(fx) * dV; Fyt = sum(fy) * dV; Fzt = sum(fz) * dV
Fcloud = sqrt(Fxt^2 + Fyt^2 + Fzt^2)
Lz = orbital_angular_momentum(psi, grid, plans)

npk = maximum(n); mask = n .> 0.05 * npk
localF = fmag ./ max.(n, eps())
localF_bulk = sum(localF[mask] .* n[mask]) / sum(n[mask])   # density-wtd local |F|

# z-resolved column integral of f_z + z-cancellation fraction
zc = grid.x[3]; xc = grid.x[1]
fzcol = [sum(@view fz[:, :, k]) * dA for k in 1:nz]
net = sum(fzcol) * dz
absint = sum(abs.(fzcol)) * dz
cancel = absint > 1e-12 ? 1.0 - abs(net) / absint : 0.0

zrows = ["z,Fz_col,N_col,Fmag_col,localF_slice"]
for k in 1:nz
    nc = sum(@view n[:, :, k]) * dA; fmc = sum(@view fmag[:, :, k]) * dA
    push!(zrows, @sprintf("%.5f,%.6e,%.6e,%.6e,%.5f", zc[k], fzcol[k], nc, fmc,
        nc > 1e-12 ? fmc / nc : 0.0))
end
open(joinpath(OUT, "xsec_zprofile_$(tag).csv"), "w") do io
    for r in zrows; println(io, r); end
end

jy = ny ÷ 2 + 1
xzrows = ["x,z,n,fz,localF"]
for k in 1:nz, i in 1:nx
    nv = n[i, jy, k]
    push!(xzrows, @sprintf("%.5f,%.5f,%.6e,%.6e,%.5f", xc[i], zc[k], nv,
        fz[i, jy, k], nv > 1e-12 ? fmag[i, jy, k] / nv : 0.0))
end
open(joinpath(OUT, "xsec_fzxz_$(tag).csv"), "w") do io
    for r in xzrows; println(io, r); end
end

@printf("\n===== f_z cross-section [%s] =====\n", tag)
@printf("Ntot=%.2f  Fz=%.4f  |F|_cloud=%.4f  Lz=%.4f  Jz=Fz+Lz=%.4f\n",
    Ntot, Fzt, Fcloud, Lz, Fzt + Lz)
@printf("LOCAL |F|=|f|/n (density-wtd, bulk) = %.3f   [vs |F|_cloud=%.3f]\n", localF_bulk, Fcloud)
@printf("z-cancellation fraction            = %.3f\n", cancel)
@printf("--- interpretation ---\n")
if localF_bulk > 4.5 && Fcloud < 3.0
    println("LOCAL |F| HELD (~$(round(localF_bulk,digits=1))) but |F|_cloud low -> SPATIAL REORIENTATION = TEXTURE (not depol)")
elseif localF_bulk < 3.0
    println("LOCAL |F| COLLAPSED (~$(round(localF_bulk,digits=1))) -> TRUE DEPOLARISATION (Option 3)")
else
    println("LOCAL |F| intermediate -> partial depol + texture")
end
if cancel > 0.5
    println("z-cancellation HIGH -> z-EVEN texture (integral F_z cancels; Option 2 = need z-symmetry break)")
else
    println("z-cancellation LOW -> f_z same-sign in z (net F_z is real, not cancelled)")
end
println("XSEC_DONE")
