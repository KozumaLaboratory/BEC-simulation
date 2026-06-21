using Test
import CUDA
using SpinorBEC
@info "CUDA functional" CUDA.functional()
include(joinpath(@__DIR__, "..", "test", "gpu", "test_cuda_equivalence.jl"))
include(joinpath(@__DIR__, "..", "test", "oracles", "test_gpu_cpu_per_term_parity.jl"))
include(joinpath(@__DIR__, "..", "test", "test_level0_gpu_cpu_consistency.jl"))
println("ALL GPU TESTS DONE")
