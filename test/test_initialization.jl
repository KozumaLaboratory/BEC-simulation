using Test
using SpinorBEC
using FFTW: fft

@testset "Initialization" begin
    @testset "init_psi states are normalized" begin
        grid = make_grid(GridConfig(64, 20.0))
        sys = SpinSystem(1)
        dV = cell_volume(grid)

        for state in [:polar, :ferromagnetic, :uniform, :antiferromagnetic, :random]
            psi = init_psi(grid, sys; state)
            norm = sum(abs2, psi) * dV
            @test norm ≈ 1.0 atol = 1e-12
        end
    end

    @testset "init_psi spin_helix normalized" begin
        grid = make_grid(GridConfig(64, 20.0))
        sys = SpinSystem(1)
        dV = cell_volume(grid)

        psi = init_psi(grid, sys; state=:spin_helix, helix_k=(1.0,))
        norm = sum(abs2, psi) * dV
        @test norm ≈ 1.0 atol = 1e-12
    end

    @testset "polar state populates m=0 only" begin
        grid = make_grid(GridConfig(64, 20.0))
        sys = SpinSystem(1)
        dV = cell_volume(grid)

        psi = init_psi(grid, sys; state=:polar)
        pop1 = sum(abs2, psi[:, 1]) * dV
        pop2 = sum(abs2, psi[:, 2]) * dV
        pop3 = sum(abs2, psi[:, 3]) * dV

        @test pop1 < 1e-14
        @test pop2 ≈ 1.0 atol = 1e-12
        @test pop3 < 1e-14
    end

    @testset "ferromagnetic state populates m=F only" begin
        grid = make_grid(GridConfig(64, 20.0))
        sys = SpinSystem(1)
        dV = cell_volume(grid)

        psi = init_psi(grid, sys; state=:ferromagnetic)
        pop1 = sum(abs2, psi[:, 1]) * dV
        pop2 = sum(abs2, psi[:, 2]) * dV
        pop3 = sum(abs2, psi[:, 3]) * dV

        @test pop1 ≈ 1.0 atol = 1e-12
        @test pop2 < 1e-14
        @test pop3 < 1e-14
    end

    @testset "uniform state has equal populations" begin
        grid = make_grid(GridConfig(64, 20.0))
        sys = SpinSystem(1)
        dV = cell_volume(grid)

        psi = init_psi(grid, sys; state=:uniform)
        pop1 = sum(abs2, psi[:, 1]) * dV
        pop2 = sum(abs2, psi[:, 2]) * dV
        pop3 = sum(abs2, psi[:, 3]) * dV

        @test pop1 ≈ pop2 rtol = 1e-10
        @test pop2 ≈ pop3 rtol = 1e-10
    end

    @testset "random state is reproducible with seed" begin
        grid = make_grid(GridConfig(64, 20.0))
        sys = SpinSystem(1)

        psi1 = init_psi(grid, sys; state=:random, seed=123)
        psi2 = init_psi(grid, sys; state=:random, seed=123)
        @test psi1 ≈ psi2

        psi3 = init_psi(grid, sys; state=:random, seed=456)
        @test !isapprox(psi1, psi3, atol=1e-6)
    end

    @testset "unknown state throws" begin
        grid = make_grid(GridConfig(64, 20.0))
        sys = SpinSystem(1)
        @test_throws ArgumentError init_psi(grid, sys; state=:nonexistent)
    end

    @testset "F=2 states" begin
        grid = make_grid(GridConfig(64, 20.0))
        sys = SpinSystem(2)
        dV = cell_volume(grid)

        for state in [:polar, :ferromagnetic, :uniform, :antiferromagnetic]
            psi = init_psi(grid, sys; state)
            norm = sum(abs2, psi) * dV
            @test norm ≈ 1.0 atol = 1e-12
        end
    end

    @testset "2D init_psi" begin
        grid = make_grid(GridConfig((32, 32), (10.0, 10.0)))
        sys = SpinSystem(1)
        dV = cell_volume(grid)

        psi = init_psi(grid, sys; state=:polar)
        @test size(psi) == (32, 32, 3)
        norm = sum(abs2, psi) * dV
        @test norm ≈ 1.0 atol = 1e-12
    end

    @testset "add_symmetry_breaking_seed! lowpass" begin
        grid = make_grid(GridConfig((32, 32), (8.0, 8.0)))
        sys = SpinSystem(1)
        dV = cell_volume(grid)
        # Ferromagnetic: dominant is m=+1 (index 1), so seed target = index 2.
        psi0 = init_psi(grid, sys; state=:ferromagnetic)
        norm0 = sum(abs2, psi0) * dV
        psi = copy(psi0)
        SpinorBEC.add_symmetry_breaking_seed!(psi, 1;
            amplitude=1e-3, seed=7, k_cut=1.0, grid=grid)
        # Renormalised back to original total density
        @test sum(abs2, psi) * dV ≈ norm0 atol=1e-10
        delta = psi[:, :, 2] .- psi0[:, :, 2]
        nhat = fft(delta)
        kvecs = grid.k
        kc2 = 1.0
        p_above = 0.0
        p_below = 0.0
        for I in CartesianIndices(nhat)
            k2 = kvecs[1][I.I[1]]^2 + kvecs[2][I.I[2]]^2
            (k2 > kc2 ? (p_above += abs2(nhat[I])) : (p_below += abs2(nhat[I])))
        end
        # Cutoff power above k_cut should be machine-epsilon dust vs.
        # the retained low-k band
        @test p_below > 0
        @test p_above < 1e-20 * p_below
    end
end
