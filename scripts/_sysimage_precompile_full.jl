# Exercises the heavy M1-ITP code path so PackageCompiler captures the
# right method specialisations for F=6 24³ DDI + rotating-frame + LBFGS
# + Sobolev.
import CUDA
using SpinorBEC
using LinearAlgebra
using Random

const F = 6
const TW = eu151_preset()

ip = TW.interactions
sys = SpinSystem(F)
psi_init = init_psi(TW.grid, sys; state=:polar)
rng = MersenneTwister(1)
for i in eachindex(psi_init)
    psi_init[i] += 0.01 * (randn(rng) + im * randn(rng))
end
n = sqrt(sum(abs2, psi_init) * SpinorBEC.cell_volume(TW.grid))
psi_init ./= n
zeeman = ZeemanParams(0.385, 0.0)

# Tiny ITP + rotating-frame to specialise the path
ws, conv, E, _, _ = find_ground_state(;
    grid=TW.grid, atom=TW.atom, interactions=ip, zeeman=zeeman, potential=TW.potential,
    dt=0.005, n_steps=20, tol=1e-8,
    initial_state=:polar, verbose=false, psi_init=psi_init,
    enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
    rotating_frame_omega=0.4, backend=CUDABackend())

# Tiny LBFGS + Sobolev to specialise that path too
psi_after = Array(ws.state.psi)
res = find_ground_state_lbfgs(;
    grid=TW.grid, atom=TW.atom, interactions=ip, zeeman=zeeman, potential=TW.potential,
    n_steps=10, tol=1e-9,
    initial_state=:polar, psi_init=psi_after,
    enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
    backend=CUDABackend(), verbose=false, sobolev_alpha=0.02)

# Energy decomposition + observables
b = energy_decomposition(ws)
sm = ws.spin_matrices
fx, fy, fz = spin_density_vector(Array(ws.state.psi), sm, 3)

# Real-time path (M0): tiny run_simulation! to specialise that branch
sp = SimParams(; dt=0.005, n_steps=10, imaginary_time=false,
    normalize_every=0, save_every=10, rotating_frame_omega=0.0)
ws2 = make_workspace(; grid=TW.grid, atom=TW.atom, interactions=ip,
    zeeman=zeeman, potential=TW.potential, sim_params=sp,
    psi_init=Array(ws.state.psi),
    enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
    backend=CUDABackend())
run_simulation!(ws2)

println("[precompile workload] specialisations exercised")
