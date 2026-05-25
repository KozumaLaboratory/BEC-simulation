# InteractionParams Dict-keyed API — addresses c_0/c_1 (struct field)
# vs c_extra (positional Vector) asymmetry.
#
# The positional Vector form (kept for backwards compatibility) has
# documented footguns:
#   - `c_extra = [c_2, c_4, c_6]` at F=6 silently misindexes (c_4 → c_3
#     slot, etc.) without the even_c_extra helper
#   - odd-rank slots (c_3) must be explicit zeros; nonzero throws
#   - struct-field c_0/c_1 and Vector-positional c_n for n≥2 use TWO
#     different indexing rules
#
# The Dict form unifies everything:
#   InteractionParams(Dict(0 => c_0, 1 => c_1, 4 => c_4))
#
# Plus `ip[n]` getindex and `c_dict(ip)` round-trip back.

using Test
using SpinorBEC

@testset "InteractionParams Dict-keyed API" begin
    @testset "Dict constructor — sparse keys, any order" begin
        ip = InteractionParams(Dict(0 => 2.0, 1 => 0.1, 4 => 0.5))
        @test ip.c0 == 2.0
        @test ip.c1 == 0.1
        @test get_cn(ip, 2) == 0.0  # not provided
        @test get_cn(ip, 4) == 0.5

        # Out-of-order keys.
        ip2 = InteractionParams(Dict(4 => 0.5, 0 => 2.0, 1 => 0.1))
        @test ip2.c0 == 2.0
        @test ip2.c1 == 0.1
        @test get_cn(ip2, 4) == 0.5

        # Empty dict (no couplings).
        ip3 = InteractionParams(Dict{Int, Float64}())
        @test ip3.c0 == 0.0
        @test ip3.c1 == 0.0
        @test isempty(ip3.c_extra)
    end

    @testset "Dict constructor with c_lhy kwarg" begin
        ip = InteractionParams(Dict(0 => 2.0, 1 => 0.1); c_lhy=15.0)
        @test ip.c_lhy == 15.0
        @test ip.c0 == 2.0
    end

    @testset "Dict constructor rejects negative + odd-rank keys" begin
        # Negative.
        @test_throws ArgumentError InteractionParams(Dict(-1 => 1.0))

        # Odd rank ≥ 3 (KU pair-channel confusion guard).
        @test_throws ArgumentError InteractionParams(Dict(3 => 1.0))
        @test_throws ArgumentError InteractionParams(Dict(5 => 1.0))
        @test_throws ArgumentError InteractionParams(Dict(0 => 1.0, 3 => 0.5))

        # n=1 is the "spin coupling" (NOT a rank-1 tensor), so n=1 is OK
        # by convention.
        ip = InteractionParams(Dict(1 => 0.5))
        @test ip.c1 == 0.5
    end

    @testset "ip[n] getindex: symmetric across all ranks" begin
        ip = InteractionParams(Dict(0 => 2.0, 1 => 0.1, 4 => 0.5, 6 => 0.3))
        # No more "ip.c0 vs ip.c_extra[3]" asymmetry; just ip[n].
        @test ip[0] == 2.0
        @test ip[1] == 0.1
        @test ip[2] == 0.0
        @test ip[4] == 0.5
        @test ip[6] == 0.3
        @test ip[10] == 0.0  # out of range
    end

    @testset "c_dict round-trip: ip → Dict → ip preserves all c_n" begin
        original = Dict(0 => 2.0, 1 => 0.1, 4 => 0.5, 6 => 0.3)
        ip = InteractionParams(original; c_lhy=5.0)
        d = c_dict(ip)
        # Only nonzero entries should appear.
        @test d == original
        # Round-trip.
        ip2 = InteractionParams(d; c_lhy=ip.c_lhy)
        @test ip2.c0 == ip.c0
        @test ip2.c1 == ip.c1
        @test ip2.c_lhy == ip.c_lhy
        @test ip2.c_extra == ip.c_extra
    end

    @testset "Positional Vector form still works (backward compat)" begin
        # The legacy InteractionParams(c0, c1) / (c0, c1, c_extra) /
        # (c0, c1, c_lhy, c_extra) constructors must continue to work
        # so we don't break 28 existing call sites.
        ip = InteractionParams(2.0, 0.1)
        @test ip[0] == 2.0
        @test ip[1] == 0.1
        @test isempty(ip.c_extra)

        ip2 = InteractionParams(2.0, 0.1, even_c_extra(6; c4=0.5))
        @test ip2[0] == 2.0
        @test ip2[4] == 0.5

        ip3 = InteractionParams(2.0, 0.1, 10.0, even_c_extra(6; c2=0.3))
        @test ip3[0] == 2.0
        @test ip3.c_lhy == 10.0
        @test ip3[2] == 0.3
    end

    @testset "Dict + positional give identical InteractionParams" begin
        # InteractionParams(Dict(0=>2.0, 1=>0.1, 4=>0.5)) must produce
        # the same struct as InteractionParams(2.0, 0.1, even_c_extra(F; c4=0.5))
        # for any F supporting c_4. Use F=2 here.
        ip_dict = InteractionParams(Dict(0 => 2.0, 1 => 0.1, 4 => 0.5))
        ip_pos = InteractionParams(2.0, 0.1, even_c_extra(2; c4=0.5))
        @test ip_dict.c0 == ip_pos.c0
        @test ip_dict.c1 == ip_pos.c1
        @test ip_dict.c_extra == ip_pos.c_extra
    end
end
