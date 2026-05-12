module SpinorBECCUDAExt

using SpinorBEC
import CUDA
using CUDA: CuArray, CuGraph, CuGraphExec, @captured

include("backend.jl")
include("gpu_euler_kernel.jl")
include("gpu_spin_mixing.jl")
include("gpu_normalize.jl")
include("gpu_nematic.jl")
include("gpu_tensor.jl")
include("gpu_energy.jl")
include("gpu_raman.jl")
include("gpu_graph.jl")
include("gpu_tdhfb.jl")
include("gpu_tdhfb_expm.jl")

function __init__()
    # Wire the scan-loop hook so each completed point releases cached GPU
    # memory back to the device. Without this, ~96 64³ ComplexF64
    # workspaces accumulate on a 16 GB GPU (~150 MB pinned per point
    # across psi/fft_buf/k²/ddi_kernel) and a long scan will OOM mid-run.
    SpinorBEC._cuda_reclaim_callback[] = () -> (CUDA.reclaim(); nothing)
    SpinorBEC._cuda_functional_callback[] = () -> CUDA.functional()
end

end # module
