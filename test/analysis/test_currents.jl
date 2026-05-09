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

    @testset "circulation: quantized 2π around a Gaussian-envelope vortex" begin
        # Artificial vortex: ψ(x,y) = exp(-r²/2σ²) · exp(iφ) placed in a single
        # spinor component. Envelope → 0 at the boundary → compatible with
        # FFT periodic BC. Expected circulation = 2π·w for a loop with winding w.
        nx = ny = 128
        L = 12.0
        grid = make_grid(GridConfig((nx, ny), (L, L)))
        plans = make_fft_plans(grid.config.n_points)

        σ = 1.5
        psi = zeros(ComplexF64, nx, ny, 3)
        @inbounds for j in 1:ny, i in 1:nx
            x = grid.x[1][i]
            y = grid.x[2][j]
            r = sqrt(x^2 + y^2)
            if r > 1e-6
                psi[i, j, 2] = exp(-r^2 / (2σ^2)) * exp(im * atan(y, x))
            end
        end

        v = superfluid_velocity(psi, grid, plans)

        # Circular loop of radius R around origin (well inside envelope).
        R = 1.0
        n_seg = 64
        loop = [(R * cos(2π * k / n_seg), R * sin(2π * k / n_seg)) for k in 0:(n_seg - 1)]
        Γ = circulation(v, grid, loop)
        @test Γ ≈ 2π rtol = 1e-2

        # Reversed orientation flips sign.
        Γ_rev = circulation(v, grid, reverse(loop))
        @test Γ_rev ≈ -2π rtol = 1e-2

        # Loop that does NOT enclose the vortex: small loop off-center in
        # the envelope tail. Winding w=0 → Γ ≈ 0.
        cx, cy = 3.5, 0.0
        loop_off = [
            (cx + 0.3 * cos(2π * k / n_seg), cy + 0.3 * sin(2π * k / n_seg)) for
            k in 0:(n_seg - 1)
        ]
        Γ_off = circulation(v, grid, loop_off)
        @test abs(Γ_off) < 0.1
    end

    @testset "circulation: 3D dispatch on straight-line vortex" begin
        # Vortex along z-axis: ψ = exp(-(x²+y²)/2σ²) · exp(iφ_xy), independent of z.
        # A loop in any constant-z plane encircling the vortex gives Γ ≈ 2π.
        nx = ny = nz = 32
        L = 10.0
        grid = make_grid(GridConfig((nx, ny, nz), (L, L, L)))
        plans = make_fft_plans(grid.config.n_points)

        σ = 1.5
        psi = zeros(ComplexF64, nx, ny, nz, 3)
        @inbounds for k in 1:nz, j in 1:ny, i in 1:nx
            x = grid.x[1][i]
            y = grid.x[2][j]
            r_xy = sqrt(x^2 + y^2)
            if r_xy > 1e-6
                psi[i, j, k, 2] = exp(-r_xy^2 / (2σ^2)) * exp(im * atan(y, x))
            end
        end

        v = superfluid_velocity(psi, grid, plans)

        R = 1.0
        n_seg = 48
        # Loop in z=0 plane (nearest grid z-slice).
        z0 = grid.x[3][nz ÷ 2 + 1]
        loop = [
            (R * cos(2π * k / n_seg), R * sin(2π * k / n_seg), z0) for k in 0:(n_seg - 1)
        ]
        Γ = circulation(v, grid, loop)
        @test Γ ≈ 2π rtol = 5e-2
    end
end
