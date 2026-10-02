import CUDA
using SpinorBEC
@assert CUDA.functional()
CUDA.allowscalar(false)
for file in (
    "gpu/test_gpu_hessian_gradient_only.jl",
    "gpu/test_gpu_energy_reduction_shapes.jl",
    "gpu/test_gpu_energy_gradient_host_psi.jl",
    "gpu/test_gpu_lbfgs_direction.jl",
    "gpu/test_lbfgs_stall_fixed_point.jl",
    "oracles/test_gpu_cpu_per_term_parity.jl",
    "oracles/test_bdg_fd_hessian.jl",
    "solvers/test_lbfgs_accuracy_floor.jl",
)
    println("VALIDATE ", file)
    flush(stdout)
    include(joinpath(@__DIR__, "..", "test", file))
end
