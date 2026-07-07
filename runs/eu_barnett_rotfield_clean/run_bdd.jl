# FEASIBILITY GATE — compute the transverse dipolar field B_dd for real Eu.
#
# The single-stage mechanical-Barnett window opens iff gamma*B_dd/omega_perp
# >~ imaging floor (~0.03). Since H_DDI = -Phi.F (Phi plays the role of gamma*B),
# the dipolar field Phi (in omega_ref units) IS gamma*B_dd directly, so the
# window number is just Phi_z (the component transverse to the in-plane B_ext
# that tips the spin toward z), read off a realistic Eu state.
#
# This is NOT c_dd*n (~mG): that is the field ALONG the magnetisation. The
# spin-tipping transverse piece Phi_z is the small (~uG) part, and it is what
# texture/nonlinearity shift — hence the numerical extraction.
#
# Pass 1 here: magnetostriction GS (no vortex) -> density-weighted RMS/max of
# the transverse dipolar field = the characteristic scale. (Vortex-core value,
# where tipping peaks, needs a P1-stirred state; run_p1_klaus.jl.)
#
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. run_bdd.jl

import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra, Statistics

const SC = "/tmp/claude-1000/-home-suzume-workspace-BEC-simulation/00662cde-2b20-4d46-95e9-97c16408370a/scratchpad"
const OMEGA_REF = 628.3        # rad/s  (f_ref = 100 Hz)
const NAT = 30000
const GAMMA_PER_G = 16276.0    # |p| per Gauss in omega_ref units (Eu g_F=1.163)
const FLOOR = 0.03             # imaging visibility floor for the window test

# magnetostriction GS: strong field along +x, spin polarised along +x, pancake
const GS_YAML = """
defaults: {kind: spinor, backend: gpu, interactions: {N_atoms: 30000, omega_ref: 628.3}}
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [48, 48, 24], box: [12.0, 12.0, 6.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, 2.0]}
      interactions: {N_atoms: 30000, omega_ref: 628.3, c1_ratio: -0.005}
      ddi: {enabled: true, secular: false}
      lhy: {kind: scalar}
      B: {Bx: "9.216e-4 Gauss", By: 0.0, Bz: 0.0}
      gauge_fix: false
      initial_state: spin_coherent
      init_state_params: {init_theta: 1.5707963267948966, init_phi: 0.0}
      init_sigma: 1.5
      dt: 0.004
      n_steps: 2000
      tol: 1.0e-9
"""

gsy = joinpath(SC, "bdd_gs.yaml"); open(gsy, "w") do io; write(io, GS_YAML); end
println("===== B_dd GS (magnetostriction, Eu) =====")
gs_rundir = run_yaml(gsy)
gs_path = joinpath(gs_rundir isa AbstractString ? gs_rundir : "", "point_001.jld2")

rr = open_result(gs_path); grid = rr.grid
N = length(grid.config.n_points); npts = Tuple(grid.config.n_points)
D = size(rr.psi, N + 1); F = (D - 1) ÷ 2
sm = spin_matrices(F); dV = cell_volume(grid)
atom = Eu151

# psi normalised to ∫|ψ|² dV = 1 (dimensionless-c_dd convention)
psi = ComplexF64.(rr.psi)
psi ./= sqrt(sum(abs2, psi) * dV)

# dimensionless c_dd matching the sim (log showed c_dd≈120.7, eps_dd≈0.540)
cdd = SpinorBEC.compute_c_dd_dimless(atom; N_atoms=NAT, omega_ref=OMEGA_REF)
@printf("c_dd(dimless) = %.4f\n", cdd)

ddi = make_ddi_params(grid, atom; c_dd=cdd, secular=false)
bufs = make_ddi_buffers(npts; flags=FFTW.ESTIMATE)
SpinorBEC._compute_spin_density!(bufs.Fx_r, bufs.Fy_r, bufs.Fz_r, psi, sm, Val(D), N, npts)
compute_ddi_potential!(ddi, bufs)
Phix, Phiy, Phiz = bufs.Phi_x, bufs.Phi_y, bufs.Phi_z

# density weight w(r) = |ψ|²(r) (spatial), normalised
w = dropdims(sum(abs2, psi; dims=N + 1); dims=N + 1)
w ./= sum(w)

Phimag = sqrt.(Phix .^ 2 .+ Phiy .^ 2 .+ Phiz .^ 2)
mean_mag = sum(w .* Phimag)                       # total DDI field ~ c_dd*n (along magnetisation)
rms_z = sqrt(sum(w .* Phiz .^ 2))                 # transverse (spin-tipping) RMS
max_z = maximum(abs.(Phiz))                        # peak transverse field
# component along B_ext (x) vs transverse (y,z)
rms_along = sqrt(sum(w .* Phix .^ 2))
rms_perp = sqrt(sum(w .* (Phiy .^ 2 .+ Phiz .^ 2)))

tomuG(phi) = phi / GAMMA_PER_G * 1e6              # omega_ref units -> Gauss -> uG

println("\n================ B_dd feasibility (magnetostriction GS, no vortex) ================")
@printf("|Phi| (density-wtd mean, total DDI field)  = %.4f  = %.2f uG\n", mean_mag, tomuG(mean_mag))
@printf("  Phi_along Bext(x) rms                    = %.4f  = %.2f uG\n", rms_along, tomuG(rms_along))
@printf("  Phi_perp (y,z) rms                       = %.4f  = %.2f uG\n", rms_perp, tomuG(rms_perp))
@printf("Phi_z (spin-tipping) rms                   = %.5f = %.3f uG   <-- gamma*B_dd/omega_perp\n", rms_z, tomuG(rms_z))
@printf("Phi_z (spin-tipping) max                   = %.5f = %.3f uG\n", max_z, tomuG(max_z))
@printf("\nWindow test:  gamma*B_dd/omega_perp = Phi_z(rms) = %.5f  vs floor %.3f  ->  %s\n",
    rms_z, FLOOR, rms_z >= FLOOR ? "OPEN" : "CLOSED (single-stage) -> two-stage quench")
@printf("(peak-based:  Phi_z(max) = %.5f  vs floor %.3f  ->  %s)\n",
    max_z, FLOOR, max_z >= FLOOR ? "OPEN" : "CLOSED")
println("BDD_DONE")
