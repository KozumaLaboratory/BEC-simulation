# Full L-BFGS solve, one arm per process; alternate processes on the same node.
# julia --project=. bench/energy_solver_ab.jl baseline|energy|direction|candidate label [grid_n] [strong|weak]
import CUDA
using SpinorBEC
using JSON, JLD2, Printf, SHA

mode, label = ARGS[1:2]
mode in ("baseline", "energy", "direction", "candidate") || error("Unknown arm: $mode")
n = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 32
profile = length(ARGS) >= 4 ? ARGS[4] : "strong"
profile in ("strong", "weak") || error("Unknown profile: $profile")
source_paths = (
    "src/solvers/lbfgs/driver.jl", "src/solvers/lbfgs/energy_gradient.jl",
    "src/solvers/hessian.jl", "src/solvers/newton_cg.jl",
    "ext/SpinorBECCUDAExt/gpu_energy.jl", "ext/SpinorBECCUDAExt/gpu_lbfgs.jl",
    "logs/baseline_gpu_energy.jl", "logs/baseline_energy_gradient.jl",
    "logs/baseline_lbfgs_driver.jl", @__FILE__,
)
source_sha256 = Dict(relpath(path) => bytes2hex(sha256(read(path))) for path in source_paths)
CUDA.allowscalar(false)
if mode in ("baseline", "energy")
    # Disable only the CUDA specialization; keep the same residual-polish fix
    # in both arms so their time-to-solution has the same accuracy contract.
    ext = Base.get_extension(SpinorBEC, :SpinorBECCUDAExt)
    for method in methods(SpinorBEC._lbfgs_direction)
        method.module === ext && Base.delete_method(method)
    end
end
if mode in ("baseline", "direction")
    source = read("logs/baseline_gpu_energy.jl", String)
    first_line = findfirst("function _gpu_energy_and_optional_grad(", source)
    last_line = findfirst("# Energy-only entry", source)
    first_line === nothing && error("Missing reference function")
    last_line === nothing && error("Missing reference boundary")
    Base.include_string(Base.get_extension(SpinorBEC, :SpinorBECCUDAExt),
        source[first(first_line):(first(last_line) - 1)], "baseline_gpu_energy.jl")
end

# A true gradient-only traversal is the third candidate change. Restore the
# previous fused GPU path in controls, including Hessian callers that now use
# gradient_only! rather than discarding the energy_gradient! return value.
if mode != "candidate"
    source = read("logs/baseline_energy_gradient.jl", String)
    first_line = findfirst("function gradient_only!(", source)
    last_line = findfirst("# GPU fused energy+gradient", source)
    first_line === nothing && error("Missing reference gradient-only function")
    last_line === nothing && error("Missing reference gradient-only boundary")
    Base.include_string(SpinorBEC, source[first(first_line):(first(last_line) - 1)],
        "baseline_gradient_only.jl")
end

if mode != "candidate"
    Base.include_string(SpinorBEC, read("logs/baseline_lbfgs_driver.jl", String),
        "baseline_lbfgs_driver.jl")
end

function solve(n)
    grid = make_grid(GridConfig((n, n, n), (12.0, 12.0, 12.0)))
    psi = if profile == "weak"
        init_psi(grid, SpinSystem(6); state=:spin_coherent, init_theta=0.7, init_phi=0.4)
    else
        nothing
    end
    find_ground_state_lbfgs(; grid, atom=Eu151, psi_init=psi,
        interactions=InteractionParams(Dict(0 => 100.0, 1 => 5.0)),
        zeeman=ZeemanParams(profile == "weak" ? 0.3 : 10.0, 0.1),
        potential=HarmonicTrap((1.0, 1.0, 1.5)),
        n_steps=1000, tol=1e-8, initial_state=:m_plus_F, residual_polish=true,
        enable_ddi=true, c_dd=10.0, ddi_padding=true,
        backend=CUDABackend(), verbose=false)
end

println("DEVICE name=", CUDA.name(CUDA.device()), " uuid=", CUDA.uuid(CUDA.device()))
println("SOLVER_START mode=$mode label=$label grid=$n profile=$profile Julia=$VERSION")
flush(stdout)
# Warm the measured shape too: GPU reduction specializations and FFT plans
# can differ from a small-grid warmup.
warmup_seconds = @elapsed solve(n)
println("SOLVER_WARMUP_DONE mode=$mode label=$label seconds=$warmup_seconds")
flush(stdout)
GC.gc(true)
CUDA.reclaim()
CUDA.synchronize()
result = nothing
elapsed = @elapsed begin
    result = solve(n)
    CUDA.synchronize()
end
ws = result.workspace
fresh_gradient = similar(ws.state.psi)
fresh_energy = SpinorBEC.energy_gradient!(fresh_gradient, ws.state.psi, ws)
SpinorBEC._project_constraints!(fresh_gradient, ws.state.psi, ws.grid, nothing, 6)
fresh_residual = sqrt(sum(abs2, fresh_gradient) * cell_volume(ws.grid))
record = (; mode, label, n, profile, julia=string(VERSION), source_sha256, seconds=elapsed,
    n_line_search_evals=result.n_line_search_evals,
    n_line_search_failures=result.n_line_search_failures,
    handoff=if hasproperty(result, :residual_polish_handoff)
        string(result.residual_polish_handoff)
    else
        "legacy"
    end,
    warmup_seconds, converged=result.converged, steps=result.last_step,
    energy=result.energy, grad_norm=result.grad_norm, fresh_energy, fresh_residual)
println("SOLVER_AB ", JSON.json(record))
flush(stdout)
open("logs/solver_$label.json", "w") do io
    JSON.print(io, record, 2)
end
jldsave("logs/solver_$label.jld2"; psi=Array(result.workspace.state.psi), record)
# The legacy flag describes the pre-polish loop; the returned state and its
# independently re-evaluated residual are the acceptance evidence.
@assert result.grad_norm <= 1e-8 && fresh_residual <= 1e-8 "Requested residual not reached"
@assert isapprox(fresh_energy, result.energy; rtol=1e-12, atol=1e-12)
