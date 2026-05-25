# InteractionParams Dict-keyed API — pure-Dict storage (2026-05-25 refactor).
#
# Old positional Vector form `InteractionParams(c0, c1, c_extra::Vector)`
# REMOVED. All c_n now live in `ip.c::Dict{Int, Float64}`. Access via
# `ip[n]` or `get_cn(ip, n)`. No more `ip.c0` / `ip.c1` field-access
# asymmetry — the user's "c0 c1 だけ分かれてるのきもちあ" critique.

using Test
using SpinorBEC
using SpinorBEC: get_cn, c_dict, has_higher_rank_couplings, max_rank

@testset "InteractionParams Dict-keyed API" begin
    @testset "Dict constructor — sparse keys, any order" begin
        ip = InteractionParams(Dict(0 => 2.0, 1 => 0.1, 4 => 0.5))
        @test ip[0] == 2.0
        @test ip[1] == 0.1
        @test ip[2] == 0.0
        @test ip[4] == 0.5

        # Out-of-order keys.
        ip2 = InteractionParams(Dict(4 => 0.5, 0 => 2.0, 1 => 0.1))
        @test ip2[0] == 2.0
        @test ip2[1] == 0.1
        @test ip2[4] == 0.5

        # Empty dict.
        ip3 = InteractionParams(Dict{Int, Float64}())
        @test ip3[0] == 0.0
        @test ip3[1] == 0.0
        @test isempty(ip3.c)
    end

    @testset "Dict constructor with c_lhy kwarg" begin
        ip = InteractionParams(Dict(0 => 2.0, 1 => 0.1); c_lhy=15.0)
        @test ip.c_lhy == 15.0
        @test ip[0] == 2.0
    end

    @testset "Dict constructor rejects negative + odd-rank keys" begin
        @test_throws ArgumentError InteractionParams(Dict(-1 => 1.0))
        @test_throws ArgumentError InteractionParams(Dict(3 => 1.0))
        @test_throws ArgumentError InteractionParams(Dict(5 => 1.0))
        @test_throws ArgumentError InteractionParams(Dict(0 => 1.0, 3 => 0.5))

        # n=1 is the "spin coupling" (F̂·F̂ rank-1 dot product), allowed.
        ip = InteractionParams(Dict(1 => 0.5))
        @test ip[1] == 0.5
    end

    @testset "Positional form removed: loud error" begin
        # InteractionParams(c0::Real, c1::Real, ...) positional form
        # was removed 2026-05-25 — calling it throws ArgumentError with
        # a migration message. Build a Symbol-keyword call to invoke
        # the deleted method signature.
        @test_throws ArgumentError InteractionParams(2.0, 0.1)
        @test_throws ArgumentError InteractionParams(2.0, 0.1, 10.0)
    end

    @testset "ip[n] getindex: symmetric across all ranks" begin
        ip = InteractionParams(Dict(0 => 2.0, 1 => 0.1, 4 => 0.5, 6 => 0.3))
        @test ip[0] == 2.0
        @test ip[1] == 0.1
        @test ip[2] == 0.0
        @test ip[4] == 0.5
        @test ip[6] == 0.3
        @test ip[10] == 0.0
    end

    @testset "c_dict round-trip + has_higher_rank_couplings" begin
        d_in = Dict(0 => 2.0, 1 => 0.1, 4 => 0.5, 6 => 0.3)
        ip = InteractionParams(d_in; c_lhy=5.0)

        # c_dict gives back the underlying Dict.
        @test c_dict(ip) == d_in

        # has_higher_rank_couplings: true iff any c_k k≥4 nonzero.
        @test has_higher_rank_couplings(ip)
        @test !has_higher_rank_couplings(InteractionParams(Dict(0 => 2.0, 2 => 0.1)))
    end

    @testset "max_rank" begin
        @test max_rank(InteractionParams(Dict(0 => 1.0, 6 => 2.0))) == 6
        @test max_rank(InteractionParams(Dict{Int, Float64}())) == -1
    end

    @testset "get_cn / ip[n] equivalence" begin
        ip = InteractionParams(Dict(0 => 1.5, 1 => 2.5, 2 => 10.0, 4 => 20.0,
            6 => 30.0))
        @test get_cn(ip, 0) == ip[0] == 1.5
        @test get_cn(ip, 1) == ip[1] == 2.5
        @test get_cn(ip, 2) == ip[2] == 10.0
        @test get_cn(ip, 4) == ip[4] == 20.0
        @test get_cn(ip, 6) == ip[6] == 30.0
        @test get_cn(ip, 8) == ip[8] == 0.0
    end

    @testset "c_to_g unified: KU c_0/c_1 + 6j c_k via single call" begin
        ip = InteractionParams(Dict(0 => 2.0, 1 => 0.1))
        g = SpinorBEC.c_to_g(1, ip)
        # F=1: g_0 = c_0 - 2c_1 = 1.8, g_2 = c_0 + c_1 = 2.1
        @test isapprox(g[0], 1.8; rtol=1e-12)
        @test isapprox(g[2], 2.1; rtol=1e-12)

        # Adding c_4 via 6j only affects the g_S via Wigner.
        ip2 = InteractionParams(Dict(0 => 2.0, 1 => 0.1, 4 => 0.5))
        g2 = SpinorBEC.c_to_g(2, ip2)
        # The c_4 contribution adds via 6j; just verify g_S has all
        # expected keys at F=2.
        @test sort(collect(keys(g2))) == [0, 2, 4]
    end
end
