using Test
using SpinorBEC
using FFTW

@testset "Currents" begin
    @testset "probability_current zero for real Gaussian" begin
        grid = make_grid(GridConfig(64, 20.0))
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:polar)
        plans = make_fft_plans(grid.config.n_points)

        j = probability_current(psi, grid, plans)
        @test length(j) == 1
        @test maximum(abs, j[1]) < 1e-10
    end

    @testset "probability_current nonzero for plane wave" begin
        grid = make_grid(GridConfig(64, 20.0))
        sys = SpinSystem(1)
        dV = cell_volume(grid)
        plans = make_fft_plans(grid.config.n_points)

        psi = zeros(ComplexF64, 64, 3)
        k0 = 2π / grid.config.box_size[1]
        for i in 1:64
            psi[i, 2] = exp(1im * k0 * grid.x[1][i])
        end
        psi ./= sqrt(sum(abs2, psi) * dV)

        j = probability_current(psi, grid, plans)
        @test maximum(j[1]) > 0.0
    end

    @testset "orbital_angular_momentum returns 0 for 1D" begin
        grid = make_grid(GridConfig(64, 20.0))
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:polar)
        plans = make_fft_plans(grid.config.n_points)

        Lz = orbital_angular_momentum(psi, grid, plans)
        @test Lz == 0.0
    end

    @testset "orbital_angular_momentum for 2D" begin
        grid = make_grid(GridConfig((32, 32), (10.0, 10.0)))
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:polar)
        plans = make_fft_plans(grid.config.n_points)

        Lz = orbital_angular_momentum(psi, grid, plans)
        @test isfinite(Lz)
        @test abs(Lz) < 1e-8
    end

    @testset "superfluid_velocity zero for stationary state" begin
        grid = make_grid(GridConfig(64, 20.0))
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:polar)
        plans = make_fft_plans(grid.config.n_points)

        v = superfluid_velocity(psi, grid, plans)
        @test length(v) == 1
        @test maximum(abs, v[1]) < 1e-8
    end

    @testset "total_angular_momentum = Lz + Sz" begin
        grid = make_grid(GridConfig((32, 32), (10.0, 10.0)))
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:ferromagnetic)
        plans = make_fft_plans(grid.config.n_points)

        Jz = total_angular_momentum(psi, grid, plans, sys)
        Lz = orbital_angular_momentum(psi, grid, plans)
        Sz = magnetization(psi, grid, sys)

        @test Jz ≈ Lz + Sz atol = 1e-12
    end
end
