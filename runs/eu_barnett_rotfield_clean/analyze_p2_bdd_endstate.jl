# Two-stage PASS-0, direct quantifier: decompose the DDI field B_dd on the SAVED
# P2 on end state to measure the residual in-plane pinning that SURVIVES B_ext->0.
#
# The spin is pinned in-plane by the total in-plane field = B_ext (gamma*B=4, along
# x) + B_dd_inplane. After the quench B_ext=0, only B_dd_inplane remains. So:
#   surviving fraction = |B_dd_inplane| / (gamma*B_ext + |B_dd_inplane|)
#   #1 external-field lock  <=  B_dd_inplane << gamma*B_ext (lock mostly released)
#   #2 B_dd self-lock       <=  B_dd_inplane ~> gamma*B_ext (lock persists)
#
# Reuses the run_bdd.jl Phi-extraction pattern (make_ddi_params/buffers +
# compute_ddi_potential!) but on the P2 on end state instead of a fresh GS.
#
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#          runs/eu_barnett_rotfield_clean/analyze_p2_bdd_endstate.jl
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra

const SRC = "runs/p2_on_a5258bf8/point_001.jld2"   # P2 on end state
const NAT = 30000
const OMEGA_REF = 628.3
const GAMMA_B_EXT = 4.0                             # gamma*B_ext in omega_ref units
# g_F=1.163 Eu: gamma per Gauss in omega_ref units (from run_bdd.jl)
const GAMMA_PER_G = 16276.0
tomuG(phi) = phi / GAMMA_PER_G * 1e6

# load the LAST dynamics frame
psi, grid = jldopen(SRC, "r") do f
    g = f["dynamics/psi_snapshots_streamed"]
    frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
    ComplexF64.(g[frames[end]]), nothing
end
rr = open_result(SRC); grid = rr.grid
N = length(grid.config.n_points); npts = Tuple(grid.config.n_points)
D = size(psi, N + 1); F = (D - 1) ÷ 2
sm = spin_matrices(F); dV = cell_volume(grid)

# normalise to ∫|ψ|²dV = 1 (dimensionless-c_dd convention, matches run_bdd.jl)
psi ./= sqrt(sum(abs2, psi) * dV)

cdd = SpinorBEC.compute_c_dd_dimless(Eu151; N_atoms=NAT, omega_ref=OMEGA_REF)
ddi = make_ddi_params(grid, Eu151; c_dd=cdd, secular=false)
bufs = make_ddi_buffers(npts; flags=FFTW.ESTIMATE)
SpinorBEC._compute_spin_density!(bufs.Fx_r, bufs.Fy_r, bufs.Fz_r, psi, sm, Val(D), N, npts)
compute_ddi_potential!(ddi, bufs)
Phix, Phiy, Phiz = bufs.Phi_x, bufs.Phi_y, bufs.Phi_z

# density weight
w = dropdims(sum(abs2, psi; dims=N + 1); dims=N + 1); w ./= sum(w)

# net magnetisation direction (in-plane) to project B_dd onto "along-magnetisation"
fx, fy, fz = spin_density_vector(psi, sm, N)
Mx = sum(fx) * dV; My = sum(fy) * dV; Mz = sum(fz) * dV
Mperp = sqrt(Mx^2 + My^2); mhatx = Mx / Mperp; mhaty = My / Mperp

# B_dd decomposition (density-weighted rms)
rms_inplane = sqrt(sum(w .* (Phix .^ 2 .+ Phiy .^ 2)))
rms_along_M = sqrt(sum(w .* (mhatx .* Phix .+ mhaty .* Phiy) .^ 2))   # along net magnetisation
rms_z = sqrt(sum(w .* Phiz .^ 2))
mean_mag = sum(w .* sqrt.(Phix .^ 2 .+ Phiy .^ 2 .+ Phiz .^ 2))

survive = rms_inplane / (GAMMA_B_EXT + rms_inplane)

@printf("\n============ B_dd decomposition on P2 on END STATE ============\n")
@printf("net magnetisation: Mperp=%.3f (dir %.2f,%.2f)  Mz=%.3f\n", Mperp, mhatx, mhaty, Mz)
@printf("|B_dd| density-wtd mean          = %.4f  = %.2f uG\n", mean_mag, tomuG(mean_mag))
@printf("B_dd in-plane rms                = %.4f  = %.2f uG\n", rms_inplane, tomuG(rms_inplane))
@printf("  along net magnetisation rms    = %.4f  = %.2f uG\n", rms_along_M, tomuG(rms_along_M))
@printf("B_dd axial (z) rms               = %.4f  = %.2f uG\n", rms_z, tomuG(rms_z))
@printf("\ngamma*B_ext (removed by quench)   = %.4f  = %.2f uG\n", GAMMA_B_EXT, tomuG(GAMMA_B_EXT))
@printf("RESIDUAL in-plane pinning fraction after B_ext->0 = %.3f\n", survive)
@printf("  -> %s\n", survive < 0.25 ?
    "B_dd in-plane << B_ext: lock MOSTLY RELEASED (#1 external-field lock) -> flux-closure bet justified" :
    "B_dd in-plane comparable to B_ext: lock PERSISTS (#2 B_dd self-lock) -> flux-closure blocked, redesign")
println("P2_BDD_ENDSTATE_DONE")
