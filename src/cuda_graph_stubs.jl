# CUDA-graph-accelerated split_step (extended by SpinorBECCUDAExt).
# Default implementation = plain split_step! so CPU workspaces work unchanged.

# NOT GENERALIZABLE: CPU fallback intentionally aliases to plain split_step!.
# Reason: performance
# Why: a real CUDA Graph capture lives in ext/SpinorBECCUDAExt/gpu_graph.jl but
#   is currently DISABLED — replay drifts by ~5% / 5 steps due to per-call
#   broadcast temporary allocations, and capture is 4× slower than plain
#   split_step!. Until per-step `CUDA.@allocated == 0`, both CPU and GPU paths
#   route here. Bench helper `bench_split_step_capture` is the gating measurement.
# See: ext/SpinorBECCUDAExt/gpu_graph.jl, CLAUDE.md §"Known limitations"

"""
    split_step_captured!(ws) → Nothing

GPU-accelerated variant of `split_step!` that captures the kernel sequence
into a CUDA Graph on first call, then replays it via a single driver call on
subsequent steps. Eliminates the ~5-10 μs per-kernel launch overhead that
dominates large-D F32 runs.

For CPU workspaces this falls back to plain `split_step!`. Requires
`using CUDA` to load the optimised implementation.
"""
function split_step_captured! end
split_step_captured!(ws::Workspace) = split_step!(ws)

"""
    invalidate_split_step_graph!(ws) → Nothing

Drop the cached CUDA Graph for this workspace. No-op on CPU.
"""
function invalidate_split_step_graph! end
invalidate_split_step_graph!(::Workspace) = nothing
