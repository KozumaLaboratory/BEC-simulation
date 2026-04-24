# --- CUDA Graph capture for split_step (EXPERIMENTAL, currently disabled) ---
#
# Goal: capture the split_step! kernel sequence once into a CUDA Graph and
# replay it with a single `cuGraphLaunch`, eliminating the ~5-10 μs
# per-kernel host launch overhead that leaves our 128³ F32 Eu151 DDI run at
# only 55% GPU utilisation.
#
# Status: requires an allocation-free hot path to work correctly. Our
# current split_step! has implicit allocations from:
#
#   1. Julia fused broadcasts that materialise intermediate CuArrays
#   2. cuBLAS gemm workspace scratch
#   3. cuFFT plan workspace scratch
#
# When `cuStreamBeginCapture` is active, these allocations get recorded
# into the graph's memory plan. On replay, the recorded `cuMemFreeAsync`
# calls try to free memory whose pool positions have shifted — the
# captured pointer in the kernel args then points at unrelated memory,
# and the replayed step zero's the wavefunction (observed).
#
# Path to enabling this:
#   a. Pre-allocate every scratch buffer inside Workspace (add fields).
#   b. Rewrite the broadcasts to `@.` pure in-place (no intermediate).
#   c. Configure cuFFT / cuBLAS to use the pre-allocated workspace.
#
# Until then, `split_step_captured!` falls back to `split_step!` on GPU.
# This keeps the API stable so the future allocation-free rewrite doesn't
# break callers, and clearly signals the intent.

"""
    split_step_captured!(ws::Workspace{N,<:CuArray}) → Nothing

Fallback to `split_step!` on GPU — graph capture is **experimental** and
disabled pending allocation-free refactor (see gpu_graph.jl source for
details). CPU path already falls back at the main-module stub.
"""
function SpinorBEC.split_step_captured!(
    ws::SpinorBEC.Workspace{N,A},
) where {N,A<:CuArray}
    SpinorBEC.split_step!(ws)
end

function SpinorBEC.invalidate_split_step_graph!(
    ::SpinorBEC.Workspace{N,A},
) where {N,A<:CuArray}
    nothing
end
