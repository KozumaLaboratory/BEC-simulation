using Test

# CUDA.jl loaded, no working driver — the configuration every CI runner is in.
#
# The extension loads whenever CUDA.jl is imported, driver or no driver. Two
# things assumed a driver anyway:
#
#   * `_cuda_reclaim_callback` called `CUDA.reclaim()` unguarded, so a CPU-only
#     YAML scan died between points with `ERROR: CUDA driver not functional`.
#     Its two sibling callbacks in the same `__init__` were guarded from the
#     start; this one drifted.
#   * `test/hamiltonian/test_tdhfb_gpu_phase5*.jl` guarded with a top-level
#     `try … return nothing … end`. `return` does not stop an `include` —
#     Julia evaluates each top-level expression on its own — so all three
#     logged "skipping" and then ran `CUDA.reclaim()` anyway.
#
# Both were red in the nightly `full` tier for months and neither was visible,
# because that job had not gone green since at least 2026-05-08.
#
# This has to be a subprocess: the point is a session in which
# `CUDA.functional()` is false, and the parent may well be running on a GPU.
# `CUDA_VISIBLE_DEVICES=-1` produces exactly that (verified below — a session
# that reports `functional() == true` would make the whole gate vacuous, so it
# is asserted, not assumed).

const _PROBE = """
import CUDA
using Test
using SpinorBEC

CUDA.functional() && error("CUDA_VISIBLE_DEVICES=-1 did not disable the driver")

# 1. the scan-loop reclaim hook must be a no-op, not an error
SpinorBEC._maybe_cuda_reclaim()

# 2. each GPU-only test file must LOAD and skip, not throw
for f in ("test_tdhfb_gpu_phase5ab.jl", "test_tdhfb_gpu_phase5c_expm.jl",
          "test_tdhfb_gpu_phase5c_hf.jl")
    include(joinpath(@__DIR__, "..", "hamiltonian", f))
end

println("CPU_ONLY_RUNNER_OK")
"""

@testset "CPU-only runner: CUDA.jl loaded, no driver" begin
    # `@__DIR__` inside the probe must resolve to test/gpu/, so hand it the
    # real path rather than relying on where the temp file happens to live.
    probe = joinpath(mktempdir(), "cpu_only_probe.jl")
    write(probe, replace(_PROBE, "@__DIR__" => repr(@__DIR__)))

    out = IOBuffer()
    cmd = Cmd(
        `$(Base.julia_cmd()) --project=$(Base.active_project()) --startup-file=no $probe`;
        env=copy(ENV),
    )
    cmd = addenv(cmd, "CUDA_VISIBLE_DEVICES" => "-1", "JULIA_NUM_THREADS" => "1")
    ok = success(pipeline(ignorestatus(cmd); stdout=out, stderr=out))
    log = String(take!(out))
    ok || @info "CPU-only probe output" log
    @test ok
    @test occursin("CPU_ONLY_RUNNER_OK", log)
end
