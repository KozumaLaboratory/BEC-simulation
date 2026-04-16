module SpinorBECCUDAExt

using SpinorBEC
import CUDA
using CUDA: CuArray

include("backend.jl")
include("gpu_spin_mixing.jl")
include("gpu_normalize.jl")
include("gpu_nematic.jl")
include("gpu_tensor.jl")
include("gpu_energy.jl")

end # module
