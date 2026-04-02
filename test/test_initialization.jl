using Test
using SpinorBEC

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
end
