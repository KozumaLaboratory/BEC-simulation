# NOT GENERALIZABLE: CPU/GPU paths stay duplicated (no KernelAbstractions.jl).
# Reason: performance
# Why: GPU path uses direct CUDA.jl kernels + cuFFT / cuBLAS, NOT KA.jl. (1) TDHFB
#   F32 GPU gets 121× speedup from CUDA-native intrinsics (cuExpm-style voxel-local
#   BdG exp, warp reductions in gpu_tdhfb_hf_step.jl); a KA.jl wrapper either loses
#   them or re-creates the duplication. (2) Single vendor (NVIDIA), no AMD/Metal use
#   case — portability value zero. (3) The "shared API, specialized impl" pattern
#   is already in place (split_step! branches on _is_gpu, extension overloads
#   the GPU-specific apply_*_step! kernels, _zeros factory). Migration to KA.jl
#   is rejected, not deferred — no realistic future event re-opens this before
#   the thesis ships.
# See: MEMORY tdhfb_gpu_port_status, option_gamma_gpu_optimization

module SpinorBECCUDAExt

using SpinorBEC
import CUDA
using CUDA: CuArray, CuGraph, CuGraphExec, @captured
using LinearAlgebra: dot
# Shared with the CPU kernels — see src/foundation/voxel_index.jl. Declared once
# so the padded-corner field access cannot drift between the two devices.
using SpinorBEC: _voxel_index
# The Taylor accuracy contract and the tridiagonal generator are declared in
# src/foundation/spinor_utils/spin_rotation_taylor.jl and shared with the CPU
# Horner, so the two devices cannot drift to different tolerances or a different
# spin algebra.
using SpinorBEC: SPIN_TAYLOR_ENABLED, SPIN_TAYLOR_TOL, SPIN_TAYLOR_RSAFE,
    SPIN_TAYLOR_RK_MAX, SPIN_TAYLOR_DEGREE_CAP

include("backend.jl")
include("gpu_rng.jl")
include("gpu_euler_kernel.jl")
include("gpu_spin_rotation_taylor.jl")
include("gpu_ddi_rotation.jl")
include("gpu_spin_chain.jl")
include("gpu_diagonal.jl")
include("gpu_lhy_field.jl")
include("gpu_spin_density.jl")
include("gpu_spin_mixing.jl")
include("gpu_normalize.jl")
include("gpu_singlet_pair.jl")
include("gpu_tensor.jl")
include("gpu_energy.jl")
include("gpu_raman.jl")
include("gpu_graph.jl")
include("gpu_tdhfb.jl")
include("gpu_tdhfb_expm.jl")
include("gpu_tdhfb_channel.jl")
include("gpu_tdhfb_w_assembly.jl")
include("gpu_tdhfb_r_update.jl")
include("gpu_tdhfb_hf_step.jl")

function __init__()
    # Wire the scan-loop hook so each completed point releases cached GPU
    # memory back to the device. Without this, ~96 64³ ComplexF64
    # workspaces accumulate on a 16 GB GPU (~150 MB pinned per point
    # across psi/fft_buf/k²/ddi_kernel) and a long scan will OOM mid-run.
    SpinorBEC._cuda_reclaim_callback[] = () -> (CUDA.reclaim(); nothing)
    SpinorBEC._cuda_functional_callback[] = () -> CUDA.functional()
    SpinorBEC._cuda_state_lines_callback[] = function ()
        if !CUDA.functional()
            return ["CUDA loaded but no functional device"]
        end
        dev = CUDA.device()
        cap = CUDA.capability(dev)
        round_gb(b) = string(round(b / 2^30; digits=1), " GB")
        [
            "device: $(CUDA.name(dev))",
            "capability: $(cap.major).$(cap.minor)",
            "total memory: $(round_gb(CUDA.totalmem(dev)))",
            "available memory: $(round_gb(CUDA.available_memory()))",
        ]
    end
end

end # module
