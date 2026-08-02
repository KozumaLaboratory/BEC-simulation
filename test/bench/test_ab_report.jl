using Test

include(joinpath(@__DIR__, "..", "..", "bench", "ab_report.jl"))
using .ABReport: Arm, compare, summarize, read_rows

# `bench/ab_report.jl` exists to stop one specific mistake: reading a
# performance difference off arms whose own samples scatter by more than the
# difference. Every wrong number in the 2026-08-02 L-BFGS work had that shape —
# 15 % taken from two single runs that turned out to be node drift, "+17 % more
# iterations" taken from n = 2 against a baseline that had moved between arms.
#
# So the rule has to be checked, not trusted. What is gated here is that the
# report REFUSES in the cases where a human eye says "clearly different":
# overlapping ranges, too few samples, and a gap narrower than the arms' own
# spread. A decision rule that only ever says yes is not a decision rule.

@testset "ab_report decision rule" begin
    @testset "refuses overlapping arms however different the medians look" begin
        a = Arm("A", [100.0, 130.0, 160.0])
        b = Arm("B", [110.0, 120.0, 125.0])
        r = compare("wall", a, b)
        @test !r.resolved
        @test occursin("OVERLAP", r.reason)
        # The delta is still reported — the point is that it is labelled, not
        # hidden. A suppressed number gets re-derived by the next reader.
        @test r.delta ≈ 120.0 - 130.0
    end

    @testset "refuses a gap narrower than the arms' own spread" begin
        # Disjoint, but only just: A spans 20, B spans 20, gap is 2.
        a = Arm("A", [100.0, 110.0, 120.0])
        b = Arm("B", [122.0, 132.0, 142.0])
        r = compare("wall", a, b)
        @test !r.resolved
        @test occursin("under the wider arm", r.reason)
    end

    @testset "refuses too few samples even when cleanly separated" begin
        a = Arm("A", [100.0, 101.0])
        b = Arm("B", [200.0, 201.0])
        r = compare("wall", a, b)
        @test !r.resolved
        @test occursin("need 3", r.reason)
    end

    @testset "resolves a real separation" begin
        # The measured L-BFGS case: iteration counts 614/678/688 against
        # 487/527/573. Disjoint by 41, wider spread 43... which is NOT enough,
        # and that is the honest verdict on those three rounds.
        a = Arm("iters", [614.0, 678.0, 688.0])
        b = Arm("iters", [487.0, 527.0, 573.0])
        r = compare("iters", a, b)
        @test r.delta < 0
        @test !r.resolved            # 41 < 43 — one more round would settle it
        @test occursin("under the wider arm", r.reason)

        # ms/it from the same rounds separates comfortably.
        a2 = Arm("ms_it", [31.77, 32.18, 31.77])
        b2 = Arm("ms_it", [25.55, 25.85, 25.26])
        r2 = compare("ms_it", a2, b2)
        @test r2.resolved
        @test r2.delta < 0
        @test r2.rel < -0.15
    end

    @testset "summarize is empty-safe" begin
        s = summarize(Arm("A", Float64[]))
        @test s.n == 0
        @test isnan(s.med)
        r = compare("x", Arm("A", Float64[]), Arm("B", [1.0, 2.0, 3.0]))
        @test !r.resolved
    end

    @testset "reads the driver's row shape, and only that" begin
        path = tempname()
        write(
            path,
            """
##### round=1 sha=deadbeef
{"metric":"wall","value":12.5,"sha":"aaa","round":1}
some other output the body printed
{"metric":"wall","value":13.5,"sha":"bbb","round":1}
{"metric":"iters","value":600,"sha":"aaa","round":1}
{"metric":"grad_norm","value":9.97568048e-07,"sha":"aaa","round":1}
{"metric":"neg","value":-1.5e+03,"sha":"bbb","round":1}
{"not_a_row":1}
""",
        )
        rows = read_rows(path)
        @test length(rows) == 5
        @test rows[1].metric == "wall" && rows[1].value == 12.5 && rows[1].sha == "aaa"
        @test rows[3].metric == "iters"
        # A NEGATIVE exponent, which the shipped regex truncated at the `e`
        # because `-` was only allowed as a leading sign. Real `grad_norm` rows
        # are all of this shape, so the very first data set hit it.
        @test rows[4].value ≈ 9.97568048e-7
        @test rows[5].value ≈ -1.5e3
        rm(path)
    end
end
