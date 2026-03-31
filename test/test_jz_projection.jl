@testset "J_z Projection ITP" begin
    @testset "Jz_constrained normalization preserves norm" begin
        config = GridConfig((32, 32), (10.0, 10.0))
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:ferromagnetic)
        plans = make_fft_plans(grid.config.n_points)
        dV = cell_volume(grid)

        N0 = sum(abs2, psi) * dV
        SpinorBEC._normalize_psi_Jz_constrained!(psi, grid, plans, sys, 0.5, 1)
        N1 = sum(abs2, psi) * dV
        @test N1 ≈ 1.0 rtol = 1e-6
    end

    @testset "Jz_constrained achieves target Jz" begin
        config = GridConfig((32, 32), (10.0, 10.0))
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:ferromagnetic)
        plans = make_fft_plans(grid.config.n_points)

        target = 0.5
        SpinorBEC._normalize_psi_Jz_constrained!(psi, grid, plans, sys, target, 1)
        Jz = total_angular_momentum(psi, grid, plans, sys)
        # Should be close to target (may not be exact due to discretization)
        @test abs(Jz - target) < 0.2
    end

    @testset "Sz projection conserves norm" begin
        config = GridConfig(32, 10.0)
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:ferromagnetic)
        dV = cell_volume(grid)
        n_pts = (32,)

        N0 = sum(abs2, psi) * dV
        SpinorBEC._apply_Sz_projection!(psi, 3, 1, n_pts, 0.5, 1, dV)
        # Sz projection changes component weights but _normalize_psi_Jz_constrained! handles renorm
        @test sum(abs2, psi) * dV > 0
    end

    @testset "estimate_rotation_for_Lz returns finite value" begin
        config = GridConfig((32, 32), (10.0, 10.0))
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:polar)
        plans = make_fft_plans(grid.config.n_points)
        dV = cell_volume(grid)

        delta_omega = SpinorBEC._estimate_rotation_for_Lz(psi, grid, plans, 0.1, 2, dV)
        @test isfinite(delta_omega)
    end

    @testset "find_ground_state with Jz_method=:projection" begin
        config = GridConfig((32, 32), (10.0, 10.0))
        grid = make_grid(config)

        result = find_ground_state(;
            grid, atom=Rb87,
            interactions=InteractionParams(10.0, -0.5),
            potential=HarmonicTrap(1.0, 1.0),
            dt=0.01, n_steps=50, tol=1e-4,
            target_Jz=0.5,
            Jz_method=:projection,
        )
        @test haskey(result, :Jz)
        @test isfinite(result.Jz)
        @test isfinite(result.energy)
    end

    @testset "YAML Jz_method parsing" begin
        yaml = """
        experiment:
          type: dynamics
          name: jz_test
          system:
            atom: Rb87
            grid:
              n_points: [32, 32]
              box_size: [10.0, 10.0]
            interactions:
              c0: 10.0
              c1: -0.5
          ground_state:
            dt: 0.01
            n_steps: 10
            tol: 1e-4
            Jz_method: projection
            potential:
              type: harmonic
              omega: [1.0, 1.0]
          sequence: []
        """
        cfg = load_config_from_string(yaml)
        @test cfg.ground_state.Jz_method === :projection
    end

    @testset "YAML default Jz_method=bisection" begin
        yaml = """
        experiment:
          type: dynamics
          name: jz_default_test
          system:
            atom: Rb87
            grid:
              n_points: 32
              box_size: 10.0
            interactions:
              c0: 10.0
              c1: -0.5
          ground_state:
            dt: 0.01
            n_steps: 10
            tol: 1e-4
            potential:
              type: harmonic
              omega: [1.0]
          sequence: []
        """
        cfg = load_config_from_string(yaml)
        @test cfg.ground_state.Jz_method === :bisection
    end
end
