using Test
using SpinorBEC

@testset "Sinatra TWA validity helpers" begin
    @testset "healing_length" begin
        # Dimensionless ℏ = M = 1: ξ = 1/√(2 g n)
        @test isapprox(healing_length(1.0, 0.5), 1.0; rtol=1e-13)
        @test isapprox(healing_length(2.0, 1.0), 0.5; rtol=1e-13)
        # Scaling
        @test isapprox(healing_length(4.0, 1.0), healing_length(1.0, 1.0) / 2.0;
            rtol=1e-13)
        # ℏ scaling
        @test isapprox(healing_length(1.0, 0.5; hbar=2.0), 2.0; rtol=1e-13)
        # Edge cases: zero or negative gn → Inf
        @test healing_length(0.0, 1.0) == Inf
        @test healing_length(1.0, 0.0) == Inf
        @test healing_length(-1.0, 1.0) == Inf
    end

    @testset "cutoff_energy_from_xi" begin
        # k_cut = factor / ξ → E_cut = (factor/ξ)² / 2 (dimensionless)
        @test isapprox(cutoff_energy_from_xi(1.0; factor=2.0), 2.0; rtol=1e-13)
        @test isapprox(cutoff_energy_from_xi(0.5; factor=2.0), 8.0; rtol=1e-13)
        @test isapprox(cutoff_energy_from_xi(1.0; factor=1.0), 0.5; rtol=1e-13)
        # Argument validation
        @test_throws ArgumentError cutoff_energy_from_xi(0.0)
        @test_throws ArgumentError cutoff_energy_from_xi(-1.0)
    end

    @testset "cutoff_energy_from_gn (composition)" begin
        # E_cut = (factor² / 2) · 2 g n = factor² · g · n
        for (g, n, fac) in
            ((1.0, 1.0, 2.0), (5.0, 0.3, 2.0), (10.0, 0.1, 1.0), (2.0, 0.5, 3.0))
            expected = fac^2 * g * n
            actual = cutoff_energy_from_gn(g, n; factor=fac)
            @test isapprox(actual, expected; rtol=1e-13)
        end
    end

    @testset "effective_n_modes counts plane waves" begin
        grid = make_grid(GridConfig(16, 10.0))    # 1D, 16 pts, box L=10
        n_total = prod(grid.config.n_points)
        # No cutoff → all modes
        @test effective_n_modes(grid; cutoff_energy=nothing, D=1) == n_total
        @test effective_n_modes(grid; cutoff_energy=Inf, D=1) == n_total
        @test effective_n_modes(grid; cutoff_energy=Inf, D=13) == 13 * n_total
        # Tiny cutoff → only k=0 mode survives (1D fftfreq has k=0 at index 1)
        @test effective_n_modes(grid; cutoff_energy=0.0, D=1) == 1
        # Large cutoff → all modes
        kmax_sq = maximum(grid.k_squared)
        @test effective_n_modes(grid; cutoff_energy=kmax_sq, D=1) == n_total
        # Monotone in cutoff
        for c1 in (0.5, 1.0, 5.0)
            for c2 in (c1 + 0.5, c1 * 2.0)
                @test effective_n_modes(grid; cutoff_energy=c1, D=1) <=
                    effective_n_modes(grid; cutoff_energy=c2, D=1)
            end
        end
    end

    @testset "sinatra_ratio computes correctly" begin
        grid = make_grid(GridConfig(16, 10.0))
        N_atoms = 1000.0
        # Without cutoff, ratio = 16 × 13 / 1000 = 0.208
        r = sinatra_ratio(grid, 13, N_atoms; cutoff_energy=nothing)
        @test isapprox(r, 16 * 13 / 1000.0; rtol=1e-12)
        # Cutoff reduces the ratio
        r_cut = sinatra_ratio(grid, 13, N_atoms; cutoff_energy=1.0)
        @test r_cut < r
        @test r_cut > 0
    end

    @testset "Eu EdH scenario sanity" begin
        # Eu F=6 EdH config: c_total = 4689 dimensionless, N_atoms = 10⁴.
        # Single-particle coupling g ≈ c_total / N_atoms (loosely);
        # GS peak density n_peak ≈ 0.118 (from the 5-LHY-mode ablation).
        # ξ = 1/√(2·g·n_peak), expect very short ξ ≪ box / grid spacing,
        # confirming that for Eu in the post-quench collapse regime the
        # k-cutoff at 2/ξ would not actually filter any modes (the entire
        # BZ lies below 2/ξ). Grid coarsening dominates the Sinatra remedy.
        g_per_atom = 4689.0 / 10_000.0
        n_peak = 0.118
        ξ = healing_length(g_per_atom, n_peak)
        @test ξ > 0
        @test ξ < 5.0    # ξ ≈ 0.92 a_ho — short but not microscopic
        # k_cut at 2/ξ (spec recommendation)
        E_cut_2 = cutoff_energy_from_gn(g_per_atom, n_peak; factor=2.0)
        E_cut_1 = cutoff_energy_from_gn(g_per_atom, n_peak; factor=1.0)
        @test E_cut_2 == 4 * E_cut_1
        @test isapprox(E_cut_2, 4 * g_per_atom * n_peak; rtol=1e-12)
    end
end
