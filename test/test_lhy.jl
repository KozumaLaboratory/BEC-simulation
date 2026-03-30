@testset "LHY Beyond-Mean-Field" begin
    @testset "c_lhy=0 regression: identical to original" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sp = SimParams(; dt=0.01, n_steps=50)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(10.0, -0.5),
            potential=HarmonicTrap(1.0),
            sim_params=sp,
        )
        @test ws.interactions.c_lhy == 0.0

        N0 = total_norm(ws.state.psi, ws.grid)
        E0 = total_energy(ws)
        for _ in 1:50
            split_step!(ws)
        end
        @test total_norm(ws.state.psi, ws.grid) ≈ N0 rtol = 1e-6
    end

    @testset "LHY energy is positive for c_lhy > 0" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:polar)
        n_pts = grid.config.n_points
        dV = cell_volume(grid)
        n_comp = sys.n_components

        E_lhy = SpinorBEC._lhy_energy(psi, 1.0, n_comp, 1, n_pts, dV)
        @test E_lhy > 0.0
    end

    @testset "LHY energy zero when c_lhy=0" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:polar)
        n_pts = grid.config.n_points
        dV = cell_volume(grid)
        n_comp = sys.n_components

        E_lhy = SpinorBEC._lhy_energy(psi, 0.0, n_comp, 1, n_pts, dV)
        @test E_lhy == 0.0
    end

    @testset "LHY modifies total energy" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sp = SimParams(; dt=0.01, n_steps=10)

        ws0 = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(10.0, -0.5),
            potential=HarmonicTrap(1.0),
            sim_params=sp,
        )
        E_no_lhy = total_energy(ws0)

        ws1 = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(10.0, -0.5, 100.0),
            potential=HarmonicTrap(1.0),
            sim_params=sp,
        )
        E_with_lhy = total_energy(ws1)

        @test E_with_lhy > E_no_lhy
    end

    @testset "Norm conservation with LHY" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sp = SimParams(; dt=0.005, n_steps=100)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(10.0, -0.5, 50.0),
            potential=HarmonicTrap(1.0),
            sim_params=sp,
        )
        N0 = total_norm(ws.state.psi, ws.grid)
        for _ in 1:100
            split_step!(ws)
        end
        @test total_norm(ws.state.psi, ws.grid) ≈ N0 rtol = 1e-6
    end

    @testset "InteractionParams c_lhy constructors" begin
        ip1 = InteractionParams(1.0, 2.0)
        @test ip1.c_lhy == 0.0
        @test ip1.c_extra == Float64[]

        ip2 = InteractionParams(1.0, 2.0, [3.0, 4.0])
        @test ip2.c_lhy == 0.0
        @test ip2.c_extra == [3.0, 4.0]

        ip3 = InteractionParams(1.0, 2.0, 5.0)
        @test ip3.c_lhy == 5.0
        @test ip3.c_extra == Float64[]

        ip4 = InteractionParams(1.0, 2.0, 5.0, [3.0])
        @test ip4.c_lhy == 5.0
        @test ip4.c_extra == [3.0]
    end

    @testset "YAML parsing of c_lhy" begin
        yaml = """
        experiment:
          type: dynamics
          name: lhy_test
          system:
            atom: Rb87
            grid:
              n_points: 64
              box_size: 20.0
            interactions:
              c0: 10.0
              c1: -0.5
              c_lhy: 100.0
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
        @test cfg.system.interactions.c_lhy == 100.0
    end

    @testset "Lima-Pelster Q5" begin
        @testset "Q5(0) = 1" begin
            @test lima_pelster_Q5(0.0) ≈ 1.0 atol = 1e-14
        end

        @testset "Q5 monotonically increasing" begin
            prev = lima_pelster_Q5(0.0)
            for eps in [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
                q = lima_pelster_Q5(eps)
                @test q > prev
                prev = q
            end
        end

        @testset "Q5(0.5) agrees with numerical integration" begin
            @test lima_pelster_Q5(0.5) ≈ 1.3899 rtol = 0.01
        end

        @testset "negative arg throws DomainError" begin
            @test_throws DomainError lima_pelster_Q5(1.5)
        end

        @testset "compute_c_lhy_with_ddi" begin
            @test compute_c_lhy_with_ddi(1.0, 0.0) ≈ 1.0 atol = 1e-14
            @test compute_c_lhy_with_ddi(2.0, 0.5) ≈ 2.0 * lima_pelster_Q5(0.5)
        end
    end

    @testset "YAML without c_lhy defaults to 0" begin
        yaml = """
        experiment:
          type: dynamics
          name: no_lhy_test
          system:
            atom: Rb87
            grid:
              n_points: 64
              box_size: 20.0
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
        @test cfg.system.interactions.c_lhy == 0.0
    end
end
