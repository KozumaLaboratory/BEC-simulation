# End-to-end LBFGS ground-state wall-time (fixed step budget). The old-vs-new
# ratio is the real end-to-end speedup (config-independent: per-step cost is
# constant, bit-equivalent trajectory => identical step/line-search sequence).
using SpinorBEC; import CUDA
using Printf
include(joinpath(@__DIR__, "..", "..", "bench", "eu151_params.jl"))
NG = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 128
NSTEPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 30
L = 16.0
grid = make_grid(GridConfig(ntuple(_ -> NG, 3), ntuple(_ -> L, 3)))
common = (; grid, atom=Eu151,
    interactions=InteractionParams(Dict(0 => EU_c0, 1 => 0.3 * EU_c0)),
    zeeman=ZeemanParams(EU_p_weak, 0.0), potential=HarmonicTrap((1.0, 1.0, EU_λ_z)),
    enable_ddi=true, c_dd=100.0, secular_ddi=true, backend=CUDABackend(),
    m_lbfgs=20, tol=1e-16, verbose=false)
# warm/JIT (2 steps)
find_ground_state_lbfgs(; common..., n_steps=2)
CUDA.synchronize()
t0 = time_ns()
res = find_ground_state_lbfgs(; common..., n_steps=NSTEPS)
CUDA.synchronize()
wall = (time_ns() - t0) / 1e9
@printf("E2E_LBFGS N=%d^3 steps=%d wall=%.3f s  per_step=%.1f ms  grad_norm=%.3e\n",
    NG, NSTEPS, wall, 1e3 * wall / NSTEPS, res.grad_norm)
