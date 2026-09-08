# Where does theory put the resonance? The surface-mode spectrum of the actual state.
#
# A perturbation rotating at Omega with l-fold azimuthal symmetry drives the surface
# mode of the same l when Omega = omega_l / l. In the TF limit of a non-dipolar
# axially symmetric trap omega_l = sqrt(l) * omega_perp, so l = 2 (which is what a
# tilted dipole's in-plane anisotropy has, an axis being 2-fold) predicts
#
#     Omega_res = sqrt(2)/2 = 0.707 omega_perp = 70.7 Hz
#
# and that textbook number sits right on Klaus et al. 2022's measured Omega_c ~ 0.74.
# The 12-point scan here rises monotonically THROUGH 0.707 and peaks near 0.885, so
# either the TF formula does not apply (eps_dd = 0.54 is not small, and omega_z/omega_perp
# = 2 is not the 2D limit) or the peak is not a surface resonance at all.
#
# This script replaces the formula with the spectrum of the real state: same atom,
# interactions, trap and field as the production cell, ground state relaxed, then
# `trapped_bdg_frequencies`.
#
# TWO TRAPS SET IN CLAUDE.md, BOTH RESPECTED HERE:
#   * `trapped_bdg_low_modes` returns HESSIAN eigenvalues, not frequencies — lambda ~ k^2
#     against omega ~ k, so reading one as the other reports a quadratic phonon branch
#     and no tolerance reconciles it. `trapped_bdg_frequencies` is the spectrum.
#   * that function reports `spectrum_reached`, and when it is false the numbers are
#     honest but are NOT an excitation spectrum. Printed, not ignored.
#
# Run: julia --project=. runs/eu_barnett_redo/bdg_surface_modes.jl   (add BDG_N=... )
import CUDA
using SpinorBEC
using Printf, FFTW

const NPTS = let s = get(ENV, "BDG_N", "")
    isempty(s) ? (64, 64, 32) : NTuple{3, Int}(parse.(Int, split(s, ",")))
end
const BOX = (28.0, 28.0, 18.0)
const OMEGA_TRAP = (1.0, 1.0, 2.0)
const N_ATOMS = 30000
const OMEGA_REF = 628.3
const B_GAUSS = 9.216e-4
const NEV = parse(Int, get(ENV, "BDG_NEV", "10"))

const BACKEND = CUDA.functional() ? CUDABackend() : CPUBackend()
const ATOM = SpinorBEC.resolve_atom(:Eu151)
const D = 2 * ATOM.F + 1
const SM = spin_matrices(ATOM.F)
const GRID = make_grid(GridConfig(NPTS, BOX))
const DV = cell_volume(GRID)
const C0 = compute_c_total(ATOM; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
const C1 = -0.005 * C0
const C_DD = compute_c_dd_dimless(ATOM; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const EPS_DD = SpinorBEC.compute_a_dd(ATOM) / ATOM.a_s
const C_LHY = scalar_lhy_coefficient(ATOM.a_s / A_HO, N_ATOMS; eps_dd=EPS_DD)
const P_ZEE = SpinorBEC.Units.bfield_to_p(B_GAUSS, ATOM.g_F, OMEGA_REF)

const V_TRAP = let V = zeros(Float64, NPTS...)
    for I in CartesianIndices(V)
        V[I] = 0.5 * sum(OMEGA_TRAP[d]^2 * GRID.x[d][I[d]]^2 for d in 1:3)
    end
    V
end

function seed()
    chi = exp(-im * π * Matrix(SM.Fz)) * exp(-im * (π / 2) * Matrix(SM.Fy)) *
          ComplexF64[c == 1 ? 1.0 : 0.0 for c in 1:D]
    psi = zeros(ComplexF64, NPTS..., D)
    σ = 2.5
    for k in axes(psi, 3), j in axes(psi, 2), i in axes(psi, 1)
        env = exp(-(GRID.x[1][i]^2 + GRID.x[2][j]^2 +
                    OMEGA_TRAP[3] * GRID.x[3][k]^2) / (2σ^2))
        for c in 1:D
            psi[i, j, k, c] = env * chi[c]
        end
    end
    psi ./ sqrt(sum(abs2, psi) * DV)
end

zee = TimeDependentZeeman(ConstantWaveform(0.0), ConstantWaveform(0.0),
                          ConstantWaveform(P_ZEE), ConstantWaveform(0.0))
ws = make_workspace(; grid=GRID, atom=ATOM,
    interactions=InteractionParams(Dict(0 => C0, 1 => C1); c_lhy=C_LHY),
    zeeman=zee, potential=NoPotential(),
    sim_params=SimParams(; dt=0.004, n_steps=4000, imaginary_time=true, normalize_every=0),
    psi_init=seed(), enable_ddi=true, c_dd=C_DD, backend=BACKEND)
copyto!(ws.potential_values, V_TRAP)

@printf("grid %s box %s dx=(%.4f, %.4f, %.4f)  backend %s\n", NPTS, BOX,
        (BOX[d] / NPTS[d] for d in 1:3)..., BACKEND)
@printf("c0=%.1f c1=%.3f c_dd=%.3f c_lhy=%.4g eps_dd=%.4f p=%.4f\n",
        C0, C1, C_DD, C_LHY, EPS_DD, P_ZEE)

μ = 0.0
for step in 1:4000
    split_step!(ws)
    nrm = sqrt(sum(abs2, ws.state.psi) * DV)
    if nrm > 0
        μ = -log(nrm) / (2 * 0.004)
        ws.state.psi ./= nrm
    end
    step % 1000 == 0 && (@printf("  ITP %d/4000 mu=%.6f\n", step, μ); flush(stdout))
end
psi = Array(ws.state.psi)
fx, fy, fz = spin_density_vector(psi, SM, 3)
@printf("GS: mu=%.6f  <F>=(%+.3f, %+.3f, %+.3f)\n",
        μ, sum(fx) * DV, sum(fy) * DV, sum(fz) * DV)

res = trapped_bdg_frequencies(ws, ws.state.psi; nev=NEV)
println("\nreturned: ", keys(res))
sr = get(res, :spectrum_reached, nothing)
@printf("\nspectrum_reached = %s%s\n", sr,
        sr === false ? "   <-- NOT a spectrum; the null manifold swallowed nev" : "")

ω = get(res, :omega, get(res, :frequencies, nothing))
if ω !== nothing
    println("\nomega [omega_ref]   ->  resonance Omega = omega/l for l = 1, 2, 3")
    for (i, w) in enumerate(sort(collect(real.(vec(ω)))))
        w <= 1e-6 && continue
        @printf("  %2d  omega = %8.4f   (%.1f Hz)   l=1: %6.3f   l=2: %6.3f   l=3: %6.3f\n",
                i, w, w * OMEGA_REF / 2π, w, w / 2, w / 3)
    end
    println("\nTF reference (non-dipolar, 2D limit): omega_l = sqrt(l), so l=2 -> Omega = 0.7071")
    println("measured injection peak: near Omega = 0.885 (unresolved, band [0.880, 0.885])")
end
