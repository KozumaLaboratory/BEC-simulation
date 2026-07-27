using Test
using SpinorBEC

# Analytic oracle: for n̄(x) = n₀(1 + A cos kx) on a full period,
#   ∫dx/n̄ = L/(n₀√(1−A²))  ⇒  f_s = L²/[(∫n̄)(∫dx/n̄)] = √(1−A²).
_fs_cosine(A) = sqrt(1 - A^2)

@testset "Superfluid fraction (phase twist)" begin
    @testset "uniform density is fully superfluid" begin
        grid = make_grid(GridConfig((16, 16, 16), (10.0, 10.0, 10.0)))
        n = fill(0.3, 16, 16, 16)

        @test superfluid_fraction(n, grid; direction=1) ≈ 1.0 atol = 1e-14
        @test superfluid_fraction(n, grid; direction=2) ≈ 1.0 atol = 1e-14
        @test superfluid_fraction(n, grid; direction=3, method=:relaxed) ≈ 1.0 atol = 1e-12
    end

    @testset "cosine modulation matches √(1−A²)" begin
        L = 10.0
        npt = 128
        grid = make_grid(GridConfig(npt, L))
        k = 2π / L

        for A in (0.0, 0.3, 0.6, 0.9)
            n = [1.0 + A * cos(k * x) for x in grid.x[1]]
            # The Leggett branch is a trapezoid sum of 1/n̄ over a period, which
            # converges geometrically in the point count.
            @test superfluid_fraction(n, grid) ≈ _fs_cosine(A) rtol = 1e-8
            @test superfluid_fraction(n, grid; method=:relaxed) ≈ _fs_cosine(A) rtol = 5e-3
        end
    end

    @testset "relaxed converges to Leggett from above, second order" begin
        # Axis-only modulation ⇒ no transverse rerouting ⇒ the two branches
        # describe the same continuum number, and any gap is the relaxed
        # branch's truncation error. Pinning both the sign (always above) and
        # the order (dx²) is what lets a user tell discretisation from physics
        # when the two disagree on a real state.
        L = 7.0
        A = 0.9
        k = 2π / L
        gaps = map((32, 64, 128)) do npt
            grid = make_grid(GridConfig(npt, L))
            n = [1.0 + A * cos(k * x) for x in grid.x[1]]
            superfluid_fraction(n, grid; method=:relaxed) -
            superfluid_fraction(n, grid; method=:leggett)
        end
        @test all(gaps .> 0)                        # one-sided truncation error
        @test gaps[1] / gaps[2] > 3.5               # second order
        @test gaps[2] / gaps[3] > 3.5
        @test gaps[3] < 1e-3                        # and small once resolved

        # Same in 3D when only the flow axis is modulated.
        grid3 = make_grid(GridConfig((64, 8, 8), (L, 4.0, 4.0)))
        n3 = [1.0 + 0.8 * cos(k * x) for x in grid3.x[1], _ in grid3.x[2], _ in grid3.x[3]]
        @test superfluid_fraction(n3, grid3; method=:relaxed) ≈
            superfluid_fraction(n3, grid3; method=:leggett) rtol = 5e-3
    end

    @testset "f_s decreases monotonically with contrast" begin
        grid = make_grid(GridConfig(64, 8.0))
        k = 2π / 8.0
        fs = [
            superfluid_fraction([1.0 + A * cos(k * x) for x in grid.x[1]], grid) for
            A in 0.0:0.1:0.9
        ]
        @test all(diff(fs) .< 0.0)
        @test fs[1] ≈ 1.0
        @test fs[end] < 0.5
    end

    @testset "transverse modulation does not impede flow" begin
        grid = make_grid(GridConfig((16, 16), (6.0, 6.0)))
        ky = 2π / 6.0
        n = [1.0 + 0.8 * cos(ky * y) for _ in grid.x[1], y in grid.x[2]]

        @test superfluid_fraction(n, grid; direction=1) ≈ 1.0 atol = 1e-12
        @test superfluid_fraction(n, grid; direction=1, method=:relaxed) ≈ 1.0 atol = 1e-12
        # Along the modulated axis the same density is a barrier.
        @test superfluid_fraction(n, grid; direction=2) ≈ _fs_cosine(0.8) rtol = 1e-3
    end

    @testset "a transverse channel pulls f_s below the Leggett bound" begin
        # Modulate only half of the y range. Flow concentrates in the open
        # channel instead of pushing uniformly through the barrier, which costs
        # less energy than the plane-averaged (Leggett) ansatz allows — so the
        # relaxed value must sit strictly below the bound.
        grid = make_grid(GridConfig((32, 32), (6.0, 6.0)))
        kx = 2π / 6.0
        n = ones(32, 32)
        for (i, x) in enumerate(grid.x[1]), j in 1:16
            n[i, j] = 1.0 + 0.9 * cos(kx * x)
        end

        f_leggett = superfluid_fraction(n, grid; direction=1)
        f_relaxed = superfluid_fraction(n, grid; direction=1, method=:relaxed)

        @test f_leggett ≈ _fs_cosine(0.45) rtol = 1e-6
        @test f_relaxed < f_leggett - 0.01
        # Decoupled-channel limit: the open half alone already carries f_s ≥ 1/2.
        @test f_relaxed > 0.5
    end

    @testset "bounds hold for arbitrary densities" begin
        grid = make_grid(GridConfig((12, 12, 12), (5.0, 5.0, 5.0)))
        for seed in 1:3
            n = [
                1.0 + 0.9 * sin(seed * x + 0.7y) * cos(0.5z + seed) for
                x in grid.x[1], y in grid.x[2], z in grid.x[3]
            ]
            n .-= minimum(n)
            n .+= 0.05
            for d in 1:3
                f_l = superfluid_fraction(n, grid; direction=d)
                f_r = superfluid_fraction(n, grid; direction=d, method=:relaxed)
                # Genuinely 3D structure, so rerouting dominates the relaxed
                # branch's positive truncation error and the ordering shows.
                @test 0.0 <= f_r <= f_l <= 1.0 + 1e-10
            end
        end
    end

    @testset "spinor input uses the total density" begin
        grid = make_grid(GridConfig(64, 10.0))
        k = 2π / 10.0
        A = 0.5
        psi = zeros(ComplexF64, 64, 3)
        for (i, x) in enumerate(grid.x[1])
            amp = sqrt(1.0 + A * cos(k * x))
            psi[i, 1] = 0.6 * amp
            psi[i, 3] = 0.8 * amp * cis(0.3x)     # phase must not matter
        end

        @test superfluid_fraction(psi, grid) ≈ _fs_cosine(A) rtol = 1e-8
    end

    @testset "disconnected cloud has no phase rigidity" begin
        grid = make_grid(GridConfig(64, 10.0))
        n = zeros(64)
        n[20:40] .= 1.0

        @test superfluid_fraction(n, grid; warn_vacuum=false) == 0.0
        @test superfluid_fraction(n, grid; method=:relaxed, warn_vacuum=false) < 1e-8
        @test_logs (:warn, r"does not connect") superfluid_fraction(n, grid)
    end

    @testset "plane_averaged_density" begin
        n = reshape(collect(1.0:12.0), 3, 4)
        @test plane_averaged_density(n, 1) ≈ [(1 + 4 + 7 + 10) / 4, (2 + 5 + 8 + 11) / 4,
            (3 + 6 + 9 + 12) / 4]
        @test plane_averaged_density(n, 2) ≈ [2.0, 5.0, 8.0, 11.0]
        @test_throws ArgumentError plane_averaged_density(n, 3)
    end

    @testset "YAML analyzer face" begin
        grid = make_grid(GridConfig((16, 16), (6.0, 6.0)))
        kx = 2π / 6.0
        psi = zeros(ComplexF64, 16, 16, 3)
        for (i, x) in enumerate(grid.x[1]), j in 1:16
            psi[i, j, 2] = sqrt(1.0 + 0.7 * cos(kx * x))
        end

        r = SpinorBEC._run_analyzer(
            :superfluid_fraction, psi, grid, Rb87, Dict{String, Any}()
        )
        @test r.directions == [1, 2]
        # Modulated along x only: axis 1 is impeded, axis 2 is free.
        @test r.f_s_leggett[1] ≈ _fs_cosine(0.7) rtol = 1e-3
        @test r.f_s_leggett[2] ≈ 1.0 atol = 1e-12
        @test r.f_s_relaxed[2] ≈ 1.0 atol = 1e-12
        @test all(0.0 .< r.f_s_relaxed .<= 1.0 + 1e-10)

        # `method` selects a branch; the other comes back NaN, not silently 0.
        r_l = SpinorBEC._run_analyzer(
            :superfluid_fraction, psi, grid, Rb87,
            Dict{String, Any}("method" => "leggett", "directions" => [1]),
        )
        @test r_l.directions == [1]
        @test isfinite(r_l.f_s_leggett[1])
        @test isnan(r_l.f_s_relaxed[1])

        @test_throws ArgumentError SpinorBEC._run_analyzer(
            :superfluid_fraction, psi, grid, Rb87,
            Dict{String, Any}("method" => "bogus"),
        )
        @test_throws ArgumentError SpinorBEC._run_analyzer(
            :superfluid_fraction, psi, grid, Rb87,
            Dict{String, Any}("directions" => [3]),
        )
    end

    @testset "argument validation" begin
        grid = make_grid(GridConfig(16, 4.0))
        n = ones(16)
        @test_throws ArgumentError superfluid_fraction(n, grid; direction=2)
        @test_throws ArgumentError superfluid_fraction(n, grid; method=:bogus)
        @test_throws ArgumentError superfluid_fraction(-ones(16), grid)
        @test_throws ArgumentError superfluid_fraction(zeros(16), grid; warn_vacuum=false)
    end
end
