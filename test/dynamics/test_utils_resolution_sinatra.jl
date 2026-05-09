# Tests for src/dynamics/utils_resolution_sinatra.jl
#
# Module wired into SpinorBEC; pull exports via the qualified path.

using Test
using SpinorBEC.UtilsResolutionSinatra

@testset "Resolution + Sinatra utilities" begin
    @testset "Species data lookup" begin
        @test haskey(SPECIES_DATA, :Eu151)
        @test SPECIES_DATA[:Eu151].F == 6
        @test SPECIES_DATA[:Eu151].a_s_aB ≈ 110.0
        @test SPECIES_DATA[:Cr52].F == 3
        @test SPECIES_DATA[:Er168].F == 6
        @test SPECIES_DATA[:Dy164].F == 8
    end

    @testset "suggest_grid: Eu defaults return positive sane values" begin
        rec = suggest_grid(:Eu151, 10000)
        @test rec.nx > 0 && rec.ny > 0 && rec.nz > 0
        @test rec.Lx > 0 && rec.Ly > 0 && rec.Lz > 0
        @test rec.dx > 0
        @test rec.xi > 0
        @test rec.ratio > 0
        # nx must be a power of 2 (next-pow-2 rounding)
        @test rec.nx == 1 << Int(round(log2(rec.nx)))
        # dx should be ≤ ξ for the recommendation to be self-consistent
        @test rec.dx <= rec.xi * 1.01   # tiny slack for floating-point
    end

    @testset "suggest_grid: Eu alias same as Eu151" begin
        a = suggest_grid(:Eu, 10000)
        b = suggest_grid(:Eu151, 10000)
        @test a.nx == b.nx
        @test a.dx == b.dx
        @test a.ratio == b.ratio
    end

    @testset "suggest_grid: unknown species raises" begin
        @test_throws ArgumentError suggest_grid(:Xenon, 10000)
        @test_throws ArgumentError suggest_grid(:Eu151, -1)
        @test_throws ArgumentError suggest_grid(:Eu151, 10000; target_resolution=0)
    end

    @testset "suggest_grid: increasing target_resolution ⇒ finer dx" begin
        r1 = suggest_grid(:Eu151, 10000; target_resolution=2)
        r4 = suggest_grid(:Eu151, 10000; target_resolution=4)
        r8 = suggest_grid(:Eu151, 10000; target_resolution=8)
        @test r1.dx >= r4.dx
        @test r4.dx >= r8.dx
    end

    @testset "sinatra_check: Round-5 16³×box=10 N=10⁵ reproduces ratio ≈ 0.5" begin
        # Pinned 1/N test config (May 8 GPU run): 16³ grid, box=10 a_ho.
        grid_16g_box10 = (nx=16, ny=16, nz=16, Lx=10.0, Ly=10.0, Lz=10.0)
        # F=6 ⇒ D=13. With no cutoff (full mode count) and N=10⁵:
        # ratio = 16³ × 13 / 10⁵ = 4096·13/100000 = 0.53248
        chk = sinatra_check(grid_16g_box10, 100_000; F=6, k_cutoff_method=:full)
        @test isapprox(chk.ratio, 0.53248; atol=1e-4)
        @test chk.verdict === :clean
    end

    @testset "sinatra_check: 32³×box=20 N=10⁴ reproduces ratio ≈ 42.6 (contaminated)" begin
        # Original baseline, before May-7 ambiguity.
        grid_32g_box20 = (nx=32, ny=32, nz=32, Lx=20.0, Ly=20.0, Lz=20.0)
        # ratio = 32³ × 13 / 10⁴ = 32768·13/10000 ≈ 42.6
        chk = sinatra_check(grid_32g_box20, 10_000; F=6, k_cutoff_method=:full)
        @test isapprox(chk.ratio, 42.5984; atol=1e-3)
        @test chk.verdict === :contaminated
    end

    @testset "sinatra_check: May-7 bug case (16³×box=20) — ratio + warning" begin
        # 16³ × box=20 has dx = 1.25 a_ho > ξ_filament (~0.6) → cloud
        # GS profile is grid-resolution-bound (May-7 bug).
        grid_may7 = (nx=16, ny=16, nz=16, Lx=20.0, Ly=20.0, Lz=20.0)
        # ratio = 16³ × 13 / 10⁴ = 5.32
        chk = sinatra_check(grid_may7, 10_000; F=6, k_cutoff_method=:full)
        @test isapprox(chk.ratio, 5.3248; atol=1e-3)
        @test chk.verdict === :marginal
        # Sinatra alone says marginal; the GS-resolution failure is what
        # makes this case bad. That's why the suggest_grid heuristic must
        # also flag dx > ξ (separate from the Sinatra ratio).
    end

    @testset "sinatra_check: verdict bands" begin
        big = (nx=8, ny=8, nz=8, Lx=10.0, Ly=10.0, Lz=10.0)
        chk_clean = sinatra_check(big, 100_000; F=6, k_cutoff_method=:full)
        @test chk_clean.verdict === :clean
        chk_marg = sinatra_check(big, 1_000; F=6, k_cutoff_method=:full)
        @test chk_marg.verdict === :marginal
        chk_cont = sinatra_check(big, 100; F=6, k_cutoff_method=:full)
        @test chk_cont.verdict === :contaminated
    end

    @testset "sinatra_check: :healing_length cutoff requires kwargs" begin
        grid = (nx=32, ny=32, nz=32, Lx=20.0, Ly=20.0, Lz=20.0)
        @test_throws ArgumentError sinatra_check(grid, 10_000;
            k_cutoff_method=:healing_length)
        @test_throws ArgumentError sinatra_check(grid, 10_000;
            k_cutoff_method=:healing_length, c_total=937.0)
        # With both kwargs supplied, the count is < full-grid count
        chk_full = sinatra_check(grid, 10_000; F=6, k_cutoff_method=:full)
        chk_hl = sinatra_check(grid, 10_000; F=6,
            k_cutoff_method=:healing_length, c_total=937.0, n_peak=0.1)
        @test chk_hl.n_modes <= chk_full.n_modes
    end

    @testset "sinatra_check: :fixed cutoff" begin
        grid = (nx=16, ny=16, nz=16, Lx=10.0, Ly=10.0, Lz=10.0)
        # Very small k_cut → only k=0 mode (count = 1)
        chk_zero = sinatra_check(grid, 10_000; F=6,
            k_cutoff_method=:fixed, k_cutoff_value=1e-9)
        @test chk_zero.n_modes == 1
        # Huge k_cut → all modes
        chk_all = sinatra_check(grid, 10_000; F=6,
            k_cutoff_method=:fixed, k_cutoff_value=1e6)
        @test chk_all.n_modes == 16^3
    end

    @testset "sinatra_check: invalid method" begin
        grid = (nx=8, ny=8, nz=8, Lx=10.0, Ly=10.0, Lz=10.0)
        @test_throws ArgumentError sinatra_check(grid, 10_000;
            k_cutoff_method=:bogus)
    end

    @testset "sinatra_check: F propagates to D" begin
        grid = (nx=8, ny=8, nz=8, Lx=10.0, Ly=10.0, Lz=10.0)
        # F=1 → D=3, F=6 → D=13
        c1 = sinatra_check(grid, 1000; F=1, k_cutoff_method=:full)
        c6 = sinatra_check(grid, 1000; F=6, k_cutoff_method=:full)
        @test c6.n_modes_eff / c1.n_modes_eff ≈ 13 / 3
    end
end
