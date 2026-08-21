# An interrupted step ends the pipeline. It used not to.
#
# WHY THIS EXISTS
#
# `run_step_ground_state.jl` handles its own interrupt carefully: it refuses to
# cache the partial ψ — the key is content-addressed, so a tombstone would poison
# the cell for every other config resolving to the same physics — warns, and
# records `:interrupted => true` on the step result.
#
# Nothing read that flag in `runner.jl`. Observed 2026-08-21 on a deliberately
# short walltime: ITP stopped at step 794/3000 with `conv=false`, and the pipeline
# went straight on to evolve that state. Left alone it produces a full result for
# a ground state nobody finished computing — WORSE than the reaped job the
# walltime self-stop was built to replace, because a reaped job leaves nothing and
# this leaves something that looks complete.
#
# The flag existed, the handling existed, and the two were not connected. That is
# the whole class: a state carefully recorded and never read.

using SpinorBEC
using Test

const _RUNNER = joinpath(@__DIR__, "..", "..", "src", "workflow",
    "experiments", "pipeline", "runner.jl")

@testset "an interrupted step stops the pipeline" begin
    src = read(_RUNNER, String)

    # The loop must read `:interrupted` off the last step result and break.
    @test occursin(":interrupted", src)
    @test occursin("interrupted_at_step", src)

    # `try` opens a scope in Julia, so a binding made inside it is invisible to
    # the `_write_exit_summary` call after the block. This assertion exists
    # because the first version of the fix declared it inside and would have
    # thrown UndefVarError only on the interrupt path — i.e. only when it mattered.
    # Anchor on the STEP LOOP's `try`, not the first one in the file — the first
    # version of this assertion matched an earlier unrelated `try` and failed for
    # a reason that had nothing to do with the property under test.
    loop = findfirst("for (i, step) in enumerate(config.steps)", src)
    @test loop !== nothing
    before_loop = src[1:first(loop)]
    tryi = findlast("\n    try\n", before_loop)
    decl = findfirst("interrupted_at_step = 0", src)
    @test decl !== nothing && tryi !== nothing
    @test first(decl) < first(tryi)

    # The exit summary must not say `completed` for an interrupted pipeline: an
    # autopilot classifying outcomes reads that field, and "completed" would
    # route a truncated run into the same bucket as a finished one.
    @test occursin("completed=(interrupted_at_step == 0)", src)
end

@testset "the ground-state step still refuses to cache a partial psi" begin
    # Pinned separately because the two behaviours are independent and the
    # dangerous combination is "stops the pipeline" WITHOUT "refuses to cache":
    # that would leave a partial ψ under a content-addressed key, where the next
    # config resolving to the same physics silently inherits it.
    gs = read(
        joinpath(@__DIR__, "..", "..", "src", "workflow", "experiments",
            "pipeline", "run_step_ground_state.jl"), String)
    @test occursin("not caching the partial", gs)
    @test occursin(":interrupted => gs_interrupted", gs)
end
