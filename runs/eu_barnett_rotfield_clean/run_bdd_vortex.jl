# FEASIBILITY GATE pass-2 — vortex-core transverse dipolar field B_dd.
#
# Pass 1 (run_bdd.jl) used a z-symmetric magnetostriction GS: Phi_z has zero
# MEAN (net M_z needs z-symmetry breaking) but RMS 0.12 = the characteristic
# scale. A P1-stirred state (vortices present, z-symmetry broken by the
# dynamics) gives the NET density-weighted Phi_z that actually drives M_z, and
# the peak Phi_z at the vortex cores. This is the confirmed feasibility number.
#
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. run_bdd_vortex.jl <p1_result.jld2> [frame]
#   frame = "last" (default) or an integer index into the dynamics snapshots.

import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra, Statistics

const OMEGA_REF = 628.3
const NAT = 30000
const GAMMA_PER_G = 16276.0
const FLOOR = 0.03

pj = length(ARGS) >= 1 ? ARGS[1] : error("need a P1 result jld2 path")
which = length(ARGS) >= 2 ? ARGS[2] : "last"

rr = open_result(pj); grid = rr.grid
N = length(grid.config.n_points); npts = Tuple(grid.config.n_points)
D = size(rr.psi, N + 1); F = (D - 1) ÷ 2
sm = spin_matrices(F); dV = cell_volume(grid)
atom = Eu151
cdd = SpinorBEC.compute_c_dd_dimless(atom; N_atoms=NAT, omega_ref=OMEGA_REF)
ddi = make_ddi_params(grid, atom; c_dd=cdd, secular=false)
bufs = make_ddi_buffers(npts; flags=FFTW.ESTIMATE)
tomuG(phi) = phi / GAMMA_PER_G * 1e6

# pick a snapshot (a stirred, vortex-containing frame)
psi = nothing
jldopen(pj, "r") do f
    if haskey(f, "dynamics/psi_snapshots_streamed")
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        idx = which == "last" ? length(frames) : clamp(parse(Int, which), 1, length(frames))
        global psi = ComplexF64.(g[frames[idx]])
        @printf("using frame %d / %d\n", idx, length(frames))
    else
        global psi = ComplexF64.(rr.psi)
        println("no dynamics snapshots — using stored psi")
    end
end
psi ./= sqrt(sum(abs2, psi) * dV)

SpinorBEC._compute_spin_density!(bufs.Fx_r, bufs.Fy_r, bufs.Fz_r, psi, sm, Val(D), N, npts)
compute_ddi_potential!(ddi, bufs)
Phix, Phiy, Phiz = bufs.Phi_x, bufs.Phi_y, bufs.Phi_z

w = dropdims(sum(abs2, psi; dims=N + 1); dims=N + 1); w ./= sum(w)
mean_z = sum(w .* Phiz)                         # NET transverse field (drives net M_z)
rms_z = sqrt(sum(w .* Phiz .^ 2))
max_z = maximum(abs.(Phiz))
# value at the vortex cores: low column-density voxels inside the cloud
ncol = dropdims(sum(abs2, psi; dims=(3, N + 1)); dims=(3, N + 1))
pk = maximum(ncol)
core_z = Float64[]
@inbounds for ix in 2:npts[1]-1, iy in 2:npts[2]-1
    ncol[ix, iy] < 0.25 * pk || continue
    (ncol[ix-1, iy] + ncol[ix+1, iy] + ncol[ix, iy-1] + ncol[ix, iy+1]) / 4 > 0.3 * pk || continue
    # column-integrated |Phi_z| along z at this (x,y)
    push!(core_z, mean(abs.(Phiz[ix, iy, :])))
end
core_val = isempty(core_z) ? NaN : maximum(core_z)

println("\n============ B_dd pass-2 (vortex-containing stir state) ============")
@printf("Phi_z NET (density-wtd mean)   = %.5f = %.3f uG   <-- drives NET M_z\n", mean_z, tomuG(mean_z))
@printf("Phi_z rms                      = %.5f = %.3f uG\n", rms_z, tomuG(rms_z))
@printf("Phi_z max                      = %.5f = %.3f uG\n", max_z, tomuG(max_z))
@printf("Phi_z at vortex cores (max)    = %.5f = %.3f uG   (n_cores=%d)\n", core_val, tomuG(core_val), length(core_z))
@printf("\nWindow (net):    Phi_z NET = %.5f vs floor %.3f -> %s\n",
    abs(mean_z), FLOOR, abs(mean_z) >= FLOOR ? "OPEN" : "below floor (use RMS/core scale)")
@printf("Window (rms):    Phi_z rms = %.5f vs floor %.3f -> %s\n",
    rms_z, FLOOR, rms_z >= FLOOR ? "OPEN" : "CLOSED")
println("BDD_VORTEX_DONE")
