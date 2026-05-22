# --- CUDA Graph capture for split_step (EXPERIMENTAL, falls back to split_step!) ---
#
# Goal: capture the split_step! kernel sequence once into a CUDA Graph and
# replay it with a single `cuGraphLaunch`, eliminating the ~5-10 μs
# per-kernel host launch overhead that leaves our 128³ F32 Eu151 DDI run at
# only 55% GPU utilisation.
#
# 2026-04-26 status: tested `CUDA.capture` end-to-end against
# `split_step!`; **capture itself succeeds and produces a `CuGraph`**, but
# the captured graph is not safely replayable as-is. Two failure modes
# observed on a F=2 32³ + Zeeman workload:
#
#   1. Per-step `CUDA.@allocated` is small but non-zero (520 B for F=1
#      16³ contact-only, 776 B for F=2 32³ + DDI; 128 B is from
#      `apply_spin_mixing_step!` alone). These are **actual** allocations
#      from `cis.(m_gpu .* α)` and similar fused broadcasts that
#      materialise per-call temporary CuArrays — Julia's broadcast
#      machinery doesn't fold these into the LHS of `.*=` automatically
#      on the GPU.
#   2. Replaying the captured graph drifts ψ from the plain split_step!
#      reference: max |ψ_captured − ψ_plain| ≈ 0.06 per step on F=2 32³
#      (≈ 5 % relative after 5 steps). Consistent with the temporaries'
#      addresses shifting between calls — the captured kernel arg
#      pointers go stale.
#   3. `CUDA.@captured` (auto re-instantiate) measured at 4× slower than
#      plain `split_step!`. The kernel launch savings get dwarfed by
#      per-iteration `cuGraphInstantiate` cost, exactly the failure mode
#      `@captured` is supposed to avoid.
#
# What still needs to land for graph capture to deliver:
#
#   a. Eliminate per-call allocations from every gpu_*.jl substep. Pre-
#      allocate scratch (N, D) buffers in the per-step caches and
#      rewrite the chains as `broadcast!(f, scratch, ...)` followed by
#      one in-place merge into ψ. Audit: gpu_spin_mixing.jl, gpu_raman.jl,
#      gpu_singlet_pair.jl, gpu_tensor.jl, ddi.jl GPU path. CUDA.@allocated
#      should be exactly 0 once done.
#   b. Confirm cuFFT plan scratch is bound to a pre-allocated work area
#      (`CUFFT.cufftSetWorkArea`) so the FFT plan doesn't re-pool memory
#      across capture/replay.
#   c. Wrap the actual capture / instantiate / launch sequence behind
#      `split_step_captured!` and exercise on an end-to-end ITP run.
#
# Once (a) succeeds, the replay drift should vanish and `@captured`
# should overtake plain split_step! at the targeted ~1.5-2× speedup on
# 128³ F32 (the kernel-launch-bound workload). Until then, this file
# falls back to plain split_step! and `bench_split_step_capture` (below)
# is the documented test for the gating allocation count.

"""
    bench_split_step_capture(ws; n_warmup=3, n_bench=100)
        → NamedTuple

Measure CUDA.@allocated per split_step!, attempt a graph capture, run a
correctness diff against plain split_step!, and time both paths. Returns
diagnostic data for tuning the path-to-replayable-capture work above.

Reports:
  - `bytes_per_step` : `CUDA.@allocated` of one split_step!
  - `capture_ok`     : true iff `CUDA.capture(...)` returned a graph
  - `max_replay_diff`: maximum |ψ_captured − ψ_plain| over a 5-step run
  - `t_plain_ms`     : wall time for `n_bench` plain split_step!s
  - `t_captured_ms`  : wall time for `n_bench` `@captured` split_step!s
  - `speedup`        : `t_plain_ms / t_captured_ms` (>1 means win)

Use after every cache refactor that targets a per-step allocation:
when `bytes_per_step → 0` and `max_replay_diff → 0`, graph capture is
ready to be enabled in `split_step_captured!`.
"""
function bench_split_step_capture(
    ws::SpinorBEC.Workspace{N, A};
    n_warmup::Int=3,
    n_bench::Int=100,
) where {N, A <: CuArray}
    psi0 = Array(copy(ws.state.psi))
    for _ in 1:n_warmup
        SpinorBEC.split_step!(ws)
    end
    CUDA.synchronize()

    bytes = CUDA.@allocated SpinorBEC.split_step!(ws)

    g = CUDA.capture(; throw_error=false) do
        SpinorBEC.split_step!(ws)
    end
    capture_ok = g !== nothing

    # 5-step correctness comparison: plain vs @captured
    Atype = typeof(ws.state.psi)
    copyto!(ws.state.psi, Atype(ComplexF64.(psi0)))
    for _ in 1:5
        SpinorBEC.split_step!(ws)
    end
    CUDA.synchronize()
    psi_plain = Array(copy(ws.state.psi))
    copyto!(ws.state.psi, Atype(ComplexF64.(psi0)))
    if capture_ok
        for _ in 1:5
            CUDA.@captured SpinorBEC.split_step!(ws)
        end
        CUDA.synchronize()
        psi_capt = Array(copy(ws.state.psi))
        max_replay_diff = maximum(abs, psi_capt .- psi_plain)
    else
        max_replay_diff = NaN
    end

    # Timing
    t_plain = @elapsed begin
        copyto!(ws.state.psi, Atype(ComplexF64.(psi0)))
        for _ in 1:n_bench
            SpinorBEC.split_step!(ws)
        end
        CUDA.synchronize()
    end
    t_capt = capture_ok ? begin
        @elapsed begin
            copyto!(ws.state.psi, Atype(ComplexF64.(psi0)))
            for _ in 1:n_bench
                CUDA.@captured SpinorBEC.split_step!(ws)
            end
            CUDA.synchronize()
        end
    end : NaN

    (bytes_per_step=bytes,
        capture_ok=capture_ok,
        max_replay_diff=max_replay_diff,
        t_plain_ms=round(t_plain * 1000; digits=2),
        t_captured_ms=isnan(t_capt) ? NaN : round(t_capt * 1000; digits=2),
        speedup=isnan(t_capt) ? NaN : round(t_plain / t_capt; digits=2))
end

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
