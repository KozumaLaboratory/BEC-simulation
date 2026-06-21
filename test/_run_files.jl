# Single source of truth for *how a test file's pass/fail is determined* and
# how failures surface. Used by BOTH execution modes in runtests.jl:
#   • serial (SPINORBEC_TEST_WORKERS=1): called once, in-process;
#   • parallel (N>1): called by run_chunk.jl inside each chunk process.
# Keeping one implementation means the two modes cannot drift on what counts
# as a failure — a real concern for a test harness whose whole job is to go red.

using Test

# Standard test-environment preamble. The serial runner historically left these
# stdlibs in `Main` for later files (whoever `using`d them first leaked them);
# many test files use `norm`, `I`, `MersenneTwister`, `mean`, `@printf`, … with
# no local import and only passed by that accident. Each parallel chunk is a
# fresh process, so a file landing in a chunk with no such sibling would hit
# `UndefVarError`. Provide them explicitly — alongside the Test + SpinorBEC that
# both runners already supply — so a file behaves identically run with siblings
# or alone. This is the test environment contract; files may still import their
# own extras (FFTW, StaticArrays, …).
using LinearAlgebra
using Random
using Statistics
using Printf

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
