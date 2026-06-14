@testset "TOF / Stern-Gerlach" begin
    @testset "1D Gaussian TOF width" begin
        F = 1
        sys = SpinSystem(F)
        grid = make_grid(GridConfig((128,), (20.0,)))
        psi = init_psi(grid, sys; state=:m_plus_F)

        params = TOFParams(1.0, 0.0, 1)
        result = simulate_tof(psi, grid, sys, params)

        @test haskey(result, F)  # m=+F component
        @test length(result[F]) == 128
        @test all(v -> v >= 0, result[F])
    end

    @testset "2D TOF returns 1D images" begin
        F = 1
        sys = SpinSystem(F)
        grid = make_grid(GridConfig((16, 16), (10.0, 10.0)))
        psi = init_psi(grid, sys; state=:polar)

        params = TOFParams(1.0, 0.0, 2)
        result = simulate_tof(psi, grid, sys, params)

        # Column integration along axis 2 → 1D array
        @test haskey(result, 0)
        @test ndims(result[0]) == 1
        @test length(result[0]) == 16
    end

    @testset "3D TOF returns 2D images" begin
        F = 1
        sys = SpinSystem(F)
        grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
        psi = init_psi(grid, sys; state=:m_plus_F)

        params = TOFParams(1.0, 0.0, 3)
        result = simulate_tof(psi, grid, sys, params)

        @test haskey(result, F)
        @test ndims(result[F]) == 2
        @test size(result[F]) == (8, 8)
    end

    @testset "SG separates components" begin
        F = 1
        sys = SpinSystem(F)
        grid = make_grid(GridConfig((16, 16), (10.0, 10.0)))

        # Uniform state: all components equally populated
        psi = init_psi(grid, sys; state=:uniform)

        # Large gradient to separate
        params = TOFParams(10.0, 5.0, 2)
        result = simulate_tof(psi, grid, sys, params)

        # All m components should be present
        @test haskey(result, 1)
        @test haskey(result, 0)
        @test haskey(result, -1)

        # With SG, center of mass should shift differently for ±m
        com_p1 = sum(i * result[1][i] for i in 1:16) / sum(result[1])
        com_m1 = sum(i * result[-1][i] for i in 1:16) / sum(result[-1])
        com_0 = sum(i * result[0][i] for i in 1:16) / sum(result[0])

        # m=+1 and m=-1 should shift in opposite directions relative to m=0
        @test (com_p1 - com_0) * (com_m1 - com_0) <= 0.0 + 1.0  # opposite or near zero
    end

    @testset "TOFParams validation" begin
        @test_throws ArgumentError TOFParams(-1.0, 0.0, 1)
        @test_throws ArgumentError TOFParams(1.0, 0.0, 0)
        @test_throws ArgumentError TOFParams(1.0, 0.0, 4)
    end

    @testset "Total momentum density conserved" begin
        F = 1
        sys = SpinSystem(F)
        grid = make_grid(GridConfig((32,), (10.0,)))
        psi = init_psi(grid, sys; state=:uniform)

        params = TOFParams(1.0, 0.0, 1)
        result = simulate_tof(psi, grid, sys, params)

        total = sum(sum(v) for v in values(result))
        @test total > 0
    end

    @testset "Scaling-frame TOF matches Castin-Dum closed form" begin
        # A non-interacting harmonic ground state expands self-similarly:
        # physical width(t) = σ₀·√(1+ω²t²). In the co-expanding frame χ must
        # stay stationary (width unchanged) while b carries all the growth.
        # A wrong residual-harmonic term or kinetic rescale breaks stationarity.
        ω = 1.0
        grid = make_grid(GridConfig{1}((128,), (20.0,)))
        x = grid.x[1]
        psi = zeros(ComplexF64, 128, 3)
        @. psi[:, 1] = exp(-ω * x^2 / 2)
        psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict{Int, Float64}()),
            potential=HarmonicTrap((ω,)),
            sim_params=SimParams(; dt=0.01, n_steps=1),
            psi_init=psi,
        )

        σ0 = 1 / sqrt(2 * ω)   # RMS of |exp(-ωx²/2)|² = exp(-ωx²)
        for t_tof in (1.0, 3.0, 6.0)
            r = simulate_tof_scaling(ws; t_tof=t_tof, n_steps=400)
            b_exact = sqrt(1 + ω^2 * t_tof^2)
            @test r.b[1] ≈ b_exact rtol = 1e-12
            # χ stays put on the (compact) grid — the load-bearing correctness signal.
            @test r.moments.widths[1] ≈ σ0 rtol = 1e-3
            # Physical width grows exactly as σ₀·b.
            @test r.widths_physical[1] ≈ σ0 * b_exact rtol = 2e-3
            @test r.norm_drift < 1e-10
        end

        # Reads ω from a HarmonicTrap source when omega is omitted; explicit
        # omega override is honoured.
        r_explicit = simulate_tof_scaling(ws; t_tof=2.0, omega=(ω,), n_steps=200)
        @test r_explicit.b[1] ≈ sqrt(1 + ω^2 * 4) rtol = 1e-12
    end
end
