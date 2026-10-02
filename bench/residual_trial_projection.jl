# Re-evaluate the failed full-solve state with the current and trial-state
# tangent projections. Both arms keep every solver parameter unchanged.
import CUDA
using SpinorBEC, JLD2, Printf
source = read("src/solvers/newton_cg.jl", String)
start = findfirst("function residual_newton_refine(", source)
stop = findfirst("# Preconditioned CG for the Newton step", source)
body = source[first(start):(first(stop) - 1)]
# Mutate only the trial projection to reproduce the original defect.
needle = "residual_norm(prm_t, ψt)"
@assert occursin(needle, body)
reference = replace(body,
    "function residual_newton_refine(" => "function residual_old_projection_probe(",
    needle => "residual_norm(prm_t)")
Base.include_string(SpinorBEC, reference, "old_projection_probe.jl")
psi = load("logs/solver_B1.jld2", "psi")
n = size(psi, 1)
grid = make_grid(GridConfig((n, n, n), (12.0, 12.0, 12.0)))
ws = make_workspace(; grid, atom=Eu151,
    interactions=InteractionParams(Dict(0 => 100.0, 1 => 5.0)),
    zeeman=ZeemanParams(10.0, 0.1),
    potential=HarmonicTrap((1.0, 1.0, 1.5)),
    sim_params=SimParams(; dt=1e-4, n_steps=1), psi_init=psi,
    enable_ddi=true, c_dd=10.0, ddi_padding=true, backend=CUDABackend())
for (name, solve) in (("old_projection", SpinorBEC.residual_old_projection_probe),
    ("trial_projection", SpinorBEC.residual_newton_refine))
    copyto!(ws.state.psi, psi)
    result = solve(ws, ws.state.psi; tol=1e-13, max_outer=20, max_cg=120,
        ε=1e-6, hvp_order=4, verbose=true)
    g = similar(ws.state.psi)
    e = SpinorBEC.energy_gradient!(g, result.psi, ws)
    SpinorBEC._project_constraints!(g, result.psi, grid, nothing, 6)
    residual = sqrt(sum(abs2, g) * cell_volume(grid))
    @printf("PROJECTION_PROBE arm=%s energy=%.17g residual=%.10e reported=%.10e iterations=%d\n",
        name, e, residual, result.grad_norm, result.iterations)
    flush(stdout)
end
