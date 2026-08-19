using Test
using SpinorBEC
using SpinorBEC.Dashboard: _get_plans_and_grid, _vector3d_plans_cache

# Two runs at the same resolution and different box sizes must not share a grid.
#
# `_get_plans_and_grid` cached on `n_pts` alone. The FFT plans really do depend
# only on the point count — but the cached tuple also carries a `Grid{3}` built
# from `box_size`, and `probability_current(psi, grid, plans)` takes its
# k-vectors from that grid. So the second run to ask for, say, 32³ got the first
# run's box, and the current came out scaled by the box ratio.
#
# Silent in the worst way for a dashboard: the chart renders, the arrows point
# the right way, and only the magnitudes are wrong. Nothing errors, nothing warns.

@testset "the vector-field plan cache is keyed on the box too" begin
    empty!(_vector3d_plans_cache)

    n = (8, 8, 8)
    small = (10.0, 10.0, 10.0)
    large = (20.0, 20.0, 20.0)

    _, g_small = _get_plans_and_grid(n, small)
    _, g_large = _get_plans_and_grid(n, large)

    # CALIBRATION. If `make_grid` ignored `box_size`, or the two boxes here were
    # equal, the assertion below would hold for the wrong reason. Establish that
    # the two boxes give genuinely different k-vectors first.
    @testset "the two boxes are distinguishable at all" begin
        @test small != large
        @test g_small.config.box_size == small
        @test g_large.config.box_size == large
        # k_max scales as 1/L: halving the box doubles the largest k
        @test maximum(g_small.k[1]) > 1.5 * maximum(g_large.k[1])
    end

    @testset "the second box is not served the first one's grid" begin
        @test g_large.config.box_size == large
        @test g_small.config.box_size == small
        @test !(g_small === g_large)
    end

    # The cache must still BE a cache — keying on more must not defeat reuse, or
    # the fix trades a wrong answer for a rebuilt FFT plan on every request.
    @testset "the same (n_pts, box) is still reused" begin
        p1, gg1 = _get_plans_and_grid(n, small)
        p2, gg2 = _get_plans_and_grid(n, small)
        @test gg1 === gg2
        @test p1 === p2
        @test length(_vector3d_plans_cache) == 2   # small and large, not four
    end

    # And the key must actually carry the box. A cache that stored a tuple key
    # but looked up by `n_pts` would pass everything above by accident.
    @testset "the key carries the box size" begin
        @test all(k -> k isa Tuple && length(k) == 2, keys(_vector3d_plans_cache))
        @test (n, small) in keys(_vector3d_plans_cache)
        @test (n, large) in keys(_vector3d_plans_cache)
    end

    empty!(_vector3d_plans_cache)
end
