using Test
using SpinorBEC
using FFTW

# #407: the FFTW planner corner that cost 36.9 GB and a SIGKILL.
#
# The mechanism, measured 2026-08-21 on TSUBAME cpu_16, one process per point:
# `MEASURE` planning of a NON-POWER-OF-TWO transform with REAL Julia threads.
#
#   n     48     50     54     64     80     96     98     128
#   RSS   1.66   2.40   3.01   0.35   4.26   6.73   11.97  0.38   GB
#
# The only cheap sizes are 64 and 128, and that is the whole of #407's paradox:
# "19× larger, 32× less memory" is arithmetic once the axis is the radix rather
# than n. Removing any ONE of the three conditions removes the effect —
# `ESTIMATE` gives 0.33-0.36 GB everywhere, and `julia -t 1` gives 0.26-0.30 GB
# everywhere even with FFTW still reporting 16 threads.
#
# WHAT IS GATED HERE is the PREDICATE, not the memory. A test that allocated
# 11.97 GB to prove the point would be a test nobody can run, and one that
# measured `ru_maxrss` would be measuring the CI runner. The predicate is what
# the advisory fires on, so the predicate is what must not drift.
#
# The truth table is asserted in BOTH directions on every axis, because a
# predicate that says `true` everywhere would silence nothing and one that says
# `false` everywhere would warn about nothing, and those are different defects
# with the same green.

@testset "#407 FFT planning memory risk — the predicate, both directions" begin
    risky = (s; kw...) -> fft_planning_memory_risk(s; kw...)
    base = (; flags=FFTW.MEASURE, fftw_threads=16, julia_threads=16)

    @testset "the measured corner is flagged" begin
        # Every mixed-radix size from the table.
        for n in (48, 50, 54, 80, 96, 98)
            @test risky((n, n, n); base...)
        end
        # Non-cubic too: the smoke grid that actually died is 48×48×24.
        @test risky((48, 48, 24); base...)
        # One bad axis is enough — the plan is one object.
        @test risky((64, 64, 48); base...)
    end

    @testset "the cheap sizes are NOT flagged" begin
        # 64 and 128 measured at 0.35 and 0.38 GB in the same sweep.
        for n in (16, 32, 64, 128, 256)
            @test !risky((n, n, n); base...)
        end
        @test !risky((128, 128, 64); base...)
    end

    @testset "each of the three conditions is necessary" begin
        bad = (48, 48, 24)
        @test risky(bad; base...)
        # planner effort
        @test !risky(bad; flags=FFTW.ESTIMATE, fftw_threads=16, julia_threads=16)
        # PATIENT is at least as thorough as MEASURE, so it is in.
        @test risky(bad; flags=FFTW.PATIENT, fftw_threads=16, julia_threads=16)
        # FFTW threads
        @test !risky(bad; flags=FFTW.MEASURE, fftw_threads=1, julia_threads=16)
        # Julia threads — the axis #407 did not have, and the one whose absence
        # made a probe report a clean flat null about a configuration nobody ran.
        @test !risky(bad; flags=FFTW.MEASURE, fftw_threads=16, julia_threads=1)
    end

    @testset "the deliberate override downgrades the planner" begin
        # `SPINORBEC_FFT_PLAN=estimate` is the opt-in, and it is opt-in rather
        # than automatic because this repo does not silently change the
        # throughput of every production run to fix a recognisable corner.
        withenv("SPINORBEC_FFT_PLAN" => "estimate") do
            @test SpinorBEC._fft_flags_override(FFTW.MEASURE) == FFTW.ESTIMATE
        end
        withenv("SPINORBEC_FFT_PLAN" => "ESTIMATE") do
            @test SpinorBEC._fft_flags_override(FFTW.MEASURE) == FFTW.ESTIMATE
        end
        for v in (nothing, "", "measure", "yes")
            withenv("SPINORBEC_FFT_PLAN" => v) do
                @test SpinorBEC._fft_flags_override(FFTW.MEASURE) == FFTW.MEASURE
            end
        end
    end

    @testset "the power-of-two helper is right at the edges" begin
        @test SpinorBEC._is_pow2(1)
        @test SpinorBEC._is_pow2(2)
        @test SpinorBEC._is_pow2(1024)
        @test !SpinorBEC._is_pow2(0)
        @test !SpinorBEC._is_pow2(3)
        @test !SpinorBEC._is_pow2(48)
        @test !SpinorBEC._is_pow2(-4)
    end

    @testset "planning a risky shape still works and stays cheap under the override" begin
        # An END-TO-END check that the advisory path does not break planning,
        # on a shape small enough that even the risky corner is affordable.
        # `julia_threads` here is whatever the runner has, so this asserts the
        # plumbing rather than the memory.
        plans = make_fft_plans((12, 12, 6))
        @test plans isa SpinorBEC.FFTPlans
        withenv("SPINORBEC_FFT_PLAN" => "estimate") do
            @test make_fft_plans((12, 12, 6)) isa SpinorBEC.FFTPlans
        end
    end
end
