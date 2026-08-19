using Test
using SpinorBEC
using SpinorBEC: cuda_preflight_check, cuda_state_lines

# The GPU preflight must be able to say NO.
#
# `cuda_preflight_check` returned `true` on every path and printed
# "✅ preflight passed" — including on a machine with no GPU at all, because
# `report_cuda_state` prints "CUDA not loaded" and returns `nothing`. Then
# `scripts/cli.jl`'s `_cmd_preflight` discarded the value and `return 0`.
#
# So `cli.jl preflight` was a green light with no red available, run immediately
# before a paid GPU submission. The one job of a preflight is to have a verdict,
# and this one's was a constant.
#
# Three separate places dropped the signal — the reporter returns nothing, the
# checker ignored it, the CLI ignored the checker. That is the same shape as the
# divergence kill (writer and reader sharing no keys) and the budget gate
# (summing zeros): **absence folding into health, at a boundary.**
#
# This suite runs where CUDA is NOT loaded, which is the CI condition, so the
# assertion it can make is the important one: the negative verdict exists and is
# reachable. The positive direction was verified by hand on 2026-08-07 against an
# RTX 5070 Ti (`✅ preflight passed`, returns `true`) — recorded here because a
# gate that only ever sees the failing side proves half of what it should.

@testset "the GPU preflight has a verdict" begin
    # CALIBRATION. The whole point is that this environment's answer is NO. If
    # CUDA were loaded here the assertions below would be testing the other
    # branch, so establish which branch is under test before asserting on it.
    lines = cuda_state_lines()
    cuda_absent = any(l -> occursin("not loaded", l), lines)

    @testset "the reporter says something either way" begin
        @test !isempty(lines)
        @test all(l -> l isa AbstractString, lines)
    end

    if cuda_absent
        @testset "without CUDA the verdict is false" begin
            out = IOBuffer()
            @test cuda_preflight_check(; io=out) === false
            txt = String(take!(out))
            # and it says why, rather than only failing
            @test occursin("FAILED", txt)
            @test occursin("not active", txt) || occursin("not loaded", txt)
            # the remedy is in the message: this exact ordering is the WSL2
            # footgun recorded in CLAUDE.md
            @test occursin("using CUDA", txt)
        end
    else
        @testset "with CUDA the verdict is true" begin
            out = IOBuffer()
            @test cuda_preflight_check(; io=out) === true
            @test occursin("passed", String(take!(out)))
        end
    end

    # The CLI must PROPAGATE it. A checker with a verdict and a caller that
    # discards it is the same defect one layer up, and that is exactly what
    # happened: `_cmd_preflight` returned 0 regardless. (The CLI body moved
    # from scripts/cli.jl to src/workflow/cli.jl on 2026-08-18; the shim has
    # no logic to drop the verdict in, so the gate reads the body.)
    @testset "the CLI turns the verdict into an exit code" begin
        src = read(joinpath(@__DIR__, "..", "..", "src", "workflow", "cli.jl"),
            String)
        i = findfirst("function _cmd_preflight", src)
        @test i !== nothing
        body = src[first(i):min(lastindex(src), first(i) + 600)]
        # the return must depend on the call, not be a bare 0
        @test occursin("cuda_preflight_check", body)
        @test occursin(r"return cuda_preflight_check\([^)]*\)\s*\?", body) ||
            occursin(r"ok\s*\?\s*0\s*:\s*1", body)
        # a bare `return 0` immediately after the call is the defect
        @test !occursin(r"cuda_preflight_check\([^)]*\)\n\s*return 0", body)
    end
end
