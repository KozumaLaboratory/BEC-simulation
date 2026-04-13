module SpinorBECCUDAExt

using SpinorBEC
import CUDA
using CUDA: CuArray

include("backend.jl")
include("gpu_spin_mixing.jl")

end # module
