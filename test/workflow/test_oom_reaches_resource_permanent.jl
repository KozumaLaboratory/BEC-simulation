using Test
using SpinorBEC
using SpinorBEC: classify_failure, PERMANENT, TRANSIENT, RESOURCE_PERMANENT,
    _is_oom_error, _escalation_can_help, UGE_PROFILE_ESCALATION

# A GPU OOM must classify as RESOURCE_PERMANENT, and the escalation it triggers
# must not be assumed to help.
#
# Two independent defects stacked here until 2026-08-07, and together they made a
# job priced to fail and then paid for again on every attempt:
#
# 1. `_is_oom_error` tested `err isa OutOfMemoryError` plus a text match on
#    `ErrorException`. CUDA's `OutOfGPUMemoryError` is neither, and it cannot be
#    referenced from core because CUDA is a weak dependency — so `oom_killed` was
#    `false` for every GPU OOM there has ever been.
# 2. `classify_failure`'s `oom_killed` arm sat BELOW the `exception_type` block
#    while its own comment said "`oom_killed` FIRST". A GPU OOM sets both fields,
#    so it matched the generic "unrecognised exception -> PERMANENT" arm and
#    never reached the resource arm.
#
# Result: `PERMANENT`. The resource class was never escalated, the job was
# re-queued at the same size, and it OOM'd again. Chained with the VRAM estimate
# that under-sized 16 of 23 atoms (fixed the same day), the first attempt was
# already doomed.
#
# The third fact is the one that costs the most and is NOT a bug to fix here:
# **escalating cannot cure an OOM.** `node_h` is two H100s, `node_f` is four, and
# this codebase is single-device, so the wider profile offers the same 80 GB at
# 2x then 4x the billing rate. That is a policy question, so it is asserted as a
# fact rather than silently changed.

@testset "a GPU OOM is resource-permanent" begin
    # CALIBRATION. `classify_failure` returning one constant for everything would
    # satisfy any single arm below. Pin that it discriminates first.
    @testset "the classifier discriminates" begin
        @test classify_failure(Dict("exception_type" => "InterruptException")) == TRANSIENT
        @test classify_failure(Dict("exception_type" => "BoundsError")) == PERMANENT
        @test classify_failure(Dict("nan_encountered" => true)) == PERMANENT
        @test length(
            unique([
                classify_failure(Dict("exception_type" => "InterruptException")),
                classify_failure(Dict("exception_type" => "BoundsError")),
                classify_failure(Dict("oom_killed" => true)),
            ]),
        ) == 3
    end

    @testset "every shape a GPU OOM arrives in" begin
        # the real shape: CUDA's type name, with the Bool now set
        @test classify_failure(
            Dict("exception_type" => "OutOfGPUMemoryError",
                "oom_killed" => true),
        ) == RESOURCE_PERMANENT
        # …and with the Bool NOT set, because `_is_oom_error` may not have heard
        # of a future type. Two independent readers of the same fact.
        @test classify_failure(
            Dict("exception_type" => "OutOfGPUMemoryError",
                "oom_killed" => false),
        ) == RESOURCE_PERMANENT
        # host OOM
        @test classify_failure(Dict("exception_type" => "OutOfMemoryError")) ==
            RESOURCE_PERMANENT
        # the Bool alone, no exception recorded
        @test classify_failure(Dict("oom_killed" => true)) == RESOURCE_PERMANENT
    end

    # The ordering bug, pinned directly: an OOM must win over the generic
    # exception arm, not the other way round.
    @testset "the resource arm outranks the generic exception arm" begin
        both = Dict("exception_type" => "OutOfGPUMemoryError", "oom_killed" => true)
        @test classify_failure(both) == RESOURCE_PERMANENT
        @test classify_failure(both) != PERMANENT
    end

    @testset "`_is_oom_error` sees the GPU type without depending on CUDA" begin
        @test _is_oom_error(OutOfMemoryError())
        @test _is_oom_error(ErrorException("CUDA error: out of memory"))
        @test !_is_oom_error(BoundsError())
        @test !_is_oom_error(InterruptException())
        # a stand-in with the same type NAME, which is how the real one is matched
        @eval struct OutOfGPUMemoryError <: Exception end
        @test _is_oom_error(OutOfGPUMemoryError())
    end
end

@testset "escalation is not assumed to cure an OOM" begin
    @test !_escalation_can_help(:oom)
    @test _escalation_can_help(:timeout)

    # The ladder still exists and still climbs — this file is not asserting it
    # away, only that its limit is recorded.
    @test UGE_PROFILE_ESCALATION["default"] == "node_h"
    @test UGE_PROFILE_ESCALATION["node_h"] == "node_f"
    @test UGE_PROFILE_ESCALATION["node_f"] === nothing

    # The premise: single-device. If a multi-GPU path ever lands, the note above
    # `UGE_PROFILE_ESCALATION` becomes wrong and must be revisited — so the
    # premise is asserted, not assumed.
    root = normpath(joinpath(@__DIR__, "..", ".."))
    multi = String[]
    for sub in ("src", "ext")
        for (dir, _, files) in walkdir(joinpath(root, sub)), f in files
            endswith(f, ".jl") || continue
            # CODE lines only. A first version scanned the whole file and
            # matched the COMMENT above `UGE_PROFILE_ESCALATION` that says there
            # is no multi-GPU path — a search for a term hitting the prose that
            # retracts it, for the third time today. Comment lines are dropped,
            # and the pattern is narrowed to calls rather than the loose word.
            code = [l for l in readlines(joinpath(dir, f))
                          if !startswith(strip(l), "#")]
            any(l -> occursin(r"CUDA\.device!\(|CUDA\.ndevices\(\)", l), code) &&
                push!(multi, relpath(joinpath(dir, f), root))
        end
    end
    if !isempty(multi)
        println("\nA multi-GPU path appeared. The escalation note above")
        println("`UGE_PROFILE_ESCALATION` says a wider profile cannot add VRAM")
        println("because nothing uses more than one device. Revisit it:")
        foreach(f -> println("  ", f), multi)
    end
    @test isempty(multi)
end
