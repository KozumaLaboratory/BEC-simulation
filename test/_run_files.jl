# Single source of truth for *how a test file's pass/fail is determined* and
# how failures surface. Used by BOTH execution modes in runtests.jl:
#   • serial (SPINORBEC_TEST_WORKERS=1): called once, in-process;
#   • parallel (N>1): called by run_chunk.jl inside each chunk process.
# Keeping one implementation means the two modes cannot drift on what counts
# as a failure — a real concern for a test harness whose whole job is to go red.

using Test

# No stdlib preamble. This file used to `using LinearAlgebra / Random /
# Statistics / Printf` so that files which reach for `norm`, `I`,
# `MersenneTwister`, `mean` or `@printf` without importing them would still run.
# That made the environment, not the file, responsible for a file's
# dependencies — which contradicts the contract CLAUDE.md states ("each test
# file stays a dependency-free unit") and made "does this file run on its own"
# depend on which sibling the claim queue handed out first.
#
# Every `test_*.jl` now declares what it uses; measured by running all 348 in
# their own process with no preamble at all. With that in place the whole `ci`
# tier (273 files, 4 workers) passes with this preamble gone, so it is gone —
# the contract is now structural rather than a static gate plus a safety net
# that quietly absorbed violations.

"""
    run_test_files(files; dir=@__DIR__) -> (failed::Bool, timings)

Run each file under its own top-level `@testset`, so it prints one summary and
a `@test` failure OR a load-time exception is caught — the remaining files
still run, and `failed` records that the suite is red. `timings` is a
`Vector{(file, seconds)}`.
"""
function run_test_files(files::AbstractVector; dir::AbstractString=@__DIR__)
    timings = Tuple{String, Float64}[]
    failed = false
    for f in files
        t = @elapsed try
            @testset "$f" begin
                include(joinpath(dir, f))
            end
        catch e
            # A failing top-level @testset throws TestSetException *after*
            # printing its summary (incl. each failure's Expression/Evaluated);
            # any other exception is a load/setup error we surface here.
            failed = true
            e isa Test.TestSetException || showerror(stdout, e, catch_backtrace())
        end
        push!(timings, (f, t))
    end
    return failed, timings
end

"""
    print_timing(timings, tier; top=30)

Print the slowest `top` files (suppressed by SPINORBEC_TEST_TIMING=quiet).
"""
function print_timing(timings, tier; top::Int=30)
    lowercase(get(ENV, "SPINORBEC_TEST_TIMING", "on")) == "quiet" && return nothing
    total = sum(last, timings; init=0.0)
    println("\n── Per-file timing (tier=$tier, total $(round(total; digits = 1))s) ──")
    for (f, t) in first(sort(timings; by=last, rev=true), min(top, length(timings)))
        println(rpad(string(round(t; digits=2), "s"), 9), f)
    end
    return nothing
end
