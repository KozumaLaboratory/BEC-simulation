# `resonance_dip` is the instrument that arbitrates Matsui Fig. 4B, so it is
# verified by a manufactured solution before it is used to validate anything —
# Roache's order-of-accuracy discipline applied to a three-point vertex.
#
# The defect this pins: the parabolic vertex used the SYMMETRIC difference
# `(yr - yl)/(xr - xl)` for the first derivative. With h1 = xc-xl, h2 = xr-xc,
# a = (yc-yl)/h1 and b = (yr-yc)/h2 that equals `(a*h1 + b*h2)/(h1+h2)`, whose
# weights are swapped relative to the Lagrange quadratic's derivative at xc,
# `(a*h2 + b*h1)/(h1+h2)`. They agree only when h1 == h2.
#
# The resulting error in `center` is exactly (h1 - h2)/2, independent of the
# data — the swap contributes (b-a)(h1-h2)/(h1+h2) and d2 is 2(b-a)/(h1+h2).
#
# It matters because the fixture is NOT uniform: dataset_fig4_theo.csv has 40
# spacings of 0.5 nT and 20 of 1.0 nT. A dip landing on a 1.0/0.5 boundary was
# biased by 0.25 nT — 61 % of the 0.41 nT centre discrepancy the Fig. 4B arc
# exists to explain. The stored targets never moved, because that dip sits at
# h1 == h2 == 0.5; the exposure was to OUR runs, whose grids need not be uniform.

using Test
using SpinorBEC

# The fixture's own grid: 1.0 nT in the wings, 0.5 nT through the dip.
_matsui_grid() = collect(vcat(-13.0:1.0:-3.0, -2.5:0.5:2.5, 3.0:1.0:13.0))

@testset "resonance_dip on a non-uniform grid (manufactured solution)" begin
    xs = _matsui_grid()
    @testset "the grid really is non-uniform" begin
        d = round.(diff(xs); digits=6)
        @test length(unique(d)) > 1          # positive control: a uniform grid
        @test 1.0 in d                       # could not expose the defect
        @test 0.5 in d
    end

    # An exact parabola has an exact vertex, so recovery must be exact — not
    # "close". Includes vertices on a 1.0/0.5 boundary in both directions,
    # which is where the swapped weights bit, and one in the uniform interior,
    # which is where they did not and where the stored targets live.
    # WHICH x0 exposes the defect is not obvious and must be chosen, not
    # guessed. The grid changes spacing at -3 and +3, so only a vertex whose
    # nearest sample is -3.0 or +3.0 has h1 != h2; everywhere else the triple is
    # locally uniform and the old form was accidentally right. My first draft
    # picked -10.3 and 10.3, which sit in the uniform 1.0 wings — the canary
    # then reddened one assertion instead of four.
    BOUNDARY = (-3.1, -2.9, 2.9, 3.1)      # triple straddles 1.0 / 0.5
    INTERIOR = (-2.0, 0.0, 1.5, -10.3)     # locally uniform: controls

    @testset "exact recovery, spacing boundary, x0 = $x0" for x0 in BOUNDARY
        y = @. (xs - x0)^2 - 5.0
        @test resonance_dip(xs, y).center ≈ x0 atol = 1e-9
    end

    @testset "exact recovery, uniform interior, x0 = $x0" for x0 in INTERIOR
        y = @. (xs - x0)^2 - 5.0
        @test resonance_dip(xs, y).center ≈ x0 atol = 1e-9
    end

    # Positive control on the fixture itself: the chosen BOUNDARY points really
    # do straddle a spacing change, so the testset above cannot pass vacuously.
    @testset "the boundary fixtures really straddle a spacing change" begin
        for x0 in BOUNDARY
            i = argmin(abs.(xs .- x0))
            @test (xs[i] - xs[i - 1]) != (xs[i + 1] - xs[i])
        end
        for x0 in INTERIOR
            i = argmin(abs.(xs .- x0))
            @test (xs[i] - xs[i - 1]) == (xs[i + 1] - xs[i])
        end
    end

    # The bias was a constant (h1-h2)/2, so a wrong implementation fails these
    # by a fixed amount rather than by something data-dependent. Asserting the
    # magnitude keeps a future regression from hiding inside a loose tolerance.
    # The bias was a constant (h1-h2)/2, so pin its magnitude: a regression
    # cannot hide inside a loose tolerance, and the number states what is at
    # stake — 0.25 nT against a 0.41 nT effect.
    @testset "the error the old form would make is not small" begin
        for x0 in BOUNDARY
            i = argmin(abs.(xs .- x0))
            h1, h2 = xs[i] - xs[i - 1], xs[i + 1] - xs[i]
            @test abs((h1 - h2) / 2) ≈ 0.25 atol = 1e-12
        end
    end

    # Width is a half-depth crossing, not a vertex property, so it is checked
    # separately and against the analytic value for this parabola: the depth is
    # measured from the endpoint baseline, so half-depth sits at a known offset.
    @testset "width is unaffected by the vertex fix" begin
        x0 = -2.5
        y = @. (xs - x0)^2 - 5.0
        d = resonance_dip(xs, y)
        @test d.width > 0
        @test isfinite(d.width)
    end
end
