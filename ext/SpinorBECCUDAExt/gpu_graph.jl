# --- CUDA Graph capture for split_step (EXPERIMENTAL, falls back to split_step!) ---
#
# Goal: capture the split_step! kernel sequence once into a CUDA Graph and
# replay it with a single `cuGraphLaunch`, eliminating the ~5-10 μs
# per-kernel host launch overhead that leaves our 128³ F32 Eu151 DDI run at
# only 55% GPU utilisation.
#
# Allocation audit (2026-04-26, CUDA.jl 5.x, CUDA Runtime 12.9):
#
#     Workload                | CUDA.@allocated per split_step!
#     ------------------------|--------------------------------
#     F=1 16³ contact only    |   520 bytes
#     F=2 32³ contact only    |   520 bytes
#     F=2 32³ + DDI           |   776 bytes
#     F=6 32³ + DDI           |   776 bytes
#
# These are tiny fixed-size allocations (KernelAbstractions launch
# metadata / per-launch handles), not the per-point intermediate
# CuArrays the original gpu_graph.jl comment was worried about. So the
# blocker for graph capture is not the implicit-allocation cost itself
# — recent CUDA.jl tracks and pools fused broadcasts well enough that
# steady-state allocations are negligible. What still needs a focused
# session:
#
#   a. Confirm cuFFT plan scratch is configured against the workspace's
#      pre-allocated work area (CUFFT.cufftSetWorkArea), so re-allocations
#      don't sneak in across the captured graph boundary.
#   b. Verify each step's CuArrays live for the full lifetime of the
#      Workspace, not just the call (this is true for the latest gpu_*.jl
#      caches but warrants a `gc_total_bytes()` cross-check).
#   c. Wrap the actual capture / instantiate / launch sequence and exercise
#      it over an end-to-end ITP run, comparing against split_step! on a
#      few representative grids.
#
# Until that lands, `split_step_captured!` falls back to `split_step!` on
# GPU. The fallback is correct, just doesn't deliver the launch-overhead
# savings.

"""
    split_step_captured!(ws::Workspace{N,<:CuArray}) → Nothing

Fallback to `split_step!` on GPU — graph capture is **experimental** and
disabled pending allocation-free refactor (see gpu_graph.jl source for
details). CPU path already falls back at the main-module stub.
"""
function SpinorBEC.split_step_captured!(
    ws::SpinorBEC.Workspace{N, A}
) where {N, A <: CuArray}
    SpinorBEC.split_step!(ws)
end

function SpinorBEC.invalidate_split_step_graph!(
    ::SpinorBEC.Workspace{N, A}
) where {N, A <: CuArray}
    nothing
end
