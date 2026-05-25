@testset "Losses" begin
    @testset "LossParams constructors" begin
        lp = LossParams(1e-3, 1e-5)
        @test lp.gamma_dr == 1e-3
        @test lp.L3 == 1e-5
        @test isempty(lp.L3_per_m)

        lp2 = LossParams(1e-3)
        @test lp2.L3 == 0.0
        @test isempty(lp2.L3_per_m)

        # Kwarg with spin-dependent K₃
        lp3 = LossParams(; gamma_dr=0.0, L3_per_m=[1.0, 2.0, 4.0])
        @test lp3.L3_per_m == [1.0, 2.0, 4.0]
        @test lp3.L3 == 0.0
    end

    @testset "L3_per_m: spin-dependent legacy 2-body-shape loss (spin-1)" begin
        # NOTE: name is historical — `L3_per_m` applies as `exp(-γ·n·dt/2)`,
        # i.e. linear in n. True 3-body (quadratic in n) lives in
        # `K3_per_m_cubic`. See LossParams docstring in
        # src/foundation/types/ddi_loss.jl.
        config = GridConfig(32, 20.0)
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:uniform)
        # c=1 loses slowest, c=3 loses fastest
        loss = LossParams(; gamma_dr=0.0, L3_per_m=[0.01, 0.1, 0.5])
        dt = 0.005
        for _ in 1:20
            apply_loss_step!(psi, loss, 1, dt, sys.n_components, 1)
        end
        pop = [sum(abs2, psi[:, c]) for c in 1:3]
        @test pop[1] > pop[2] > pop[3]   # monotonic
    end

    @testset "L3_per_m length-mismatch raises" begin
        config = GridConfig(8, 4.0)
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:uniform)
        # Wrong length (4 != 3 components)
        loss = LossParams(; gamma_dr=0.0, L3_per_m=[0.1, 0.1, 0.1, 0.1])
        @test_throws ArgumentError apply_loss_step!(psi, loss, 1, 0.01,
            sys.n_components, 1)
    end

    @testset "L3_per_m overrides scalar L3" begin
        config = GridConfig(16, 8.0)
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi_a = init_psi(grid, sys; state=:uniform)
        psi_b = copy(psi_a)
        # loss_a: only per-m, scalar L3 should be ignored
        loss_a = LossParams(; gamma_dr=0.0, L3=999.0, L3_per_m=[0.1, 0.1, 0.1])
        # loss_b: scalar L3 matching per-m values
        loss_b = LossParams(; gamma_dr=0.0, L3=0.1)
        dt = 0.01
        for _ in 1:10
            apply_loss_step!(psi_a, loss_a, 1, dt, sys.n_components, 1)
            apply_loss_step!(psi_b, loss_b, 1, dt, sys.n_components, 1)
        end
        @test psi_a ≈ psi_b rtol=1e-12
    end

    @testset "No loss: LossParams(0,0) preserves norm" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:uniform)
        loss = LossParams(0.0, 0.0)

        N0 = total_norm(psi, grid)
        apply_loss_step!(psi, loss, 1, 0.01, sys.n_components, 1)
        @test total_norm(psi, grid) ≈ N0 rtol = 1e-14
    end

    @testset "m-dependent decay (spin-1)" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:uniform)
        loss = LossParams(0.1, 0.0)
        dt = 0.01

        pop_before = [sum(abs2, psi[:, c]) for c in 1:3]

        for _ in 1:100
            apply_loss_step!(psi, loss, 1, dt, sys.n_components, 1)
        end

        pop_after = [sum(abs2, psi[:, c]) for c in 1:3]

        # c=1->m=+1, c=2->m=0, c=3->m=-1
        # m=-1: no downward transitions -> stable
        @test pop_after[3] ≈ pop_before[3] rtol = 1e-14

        # Both m=+1 and m=0 decay, but m=+1 decays faster (2 channels vs 1)
        @test pop_after[1] < pop_before[1]
        @test pop_after[2] < pop_before[2]
        @test pop_after[1] < pop_after[2]
    end

    @testset "m-dependent decay (spin-2)" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sys = SpinSystem(2)
        psi = init_psi(grid, sys; state=:uniform)
        loss = LossParams(0.1, 0.0)
        dt = 0.01

        pop_before = [sum(abs2, psi[:, c]) for c in 1:5]

        for _ in 1:50
            apply_loss_step!(psi, loss, 2, dt, sys.n_components, 1)
        end

        pop_after = [sum(abs2, psi[:, c]) for c in 1:5]

        # m=-2 (c=5) unchanged
        @test pop_after[5] ≈ pop_before[5] rtol = 1e-14

        # All non-stable components decay
        for c in 1:4
            @test pop_after[c] < pop_before[c]
        end

        # m=+2 (c=1) has the highest rate
        @test pop_after[1] < pop_after[2]
        @test pop_after[1] < pop_after[3]
    end

    @testset "_dipolar_relaxation_rates properties" begin
        for F in [1, 2, 3, 6]
            rates = SpinorBEC._dipolar_relaxation_rates(F, 1.0)
            D = 2F + 1
            @test length(rates) == D

            # m=-F is stable
            @test rates[D] ≈ 0.0 atol = 1e-15

            # Average rate = gamma_dr
            @test sum(rates) / D ≈ 1.0 rtol = 1e-12

            # All rates non-negative
            @test all(r -> r >= -1e-15, rates)
        end

        # F=6: all non-terminal components have nonzero rates
        rates6 = SpinorBEC._dipolar_relaxation_rates(6, 0.5)
        @test all(r -> r > 0.01, rates6[1:12])
        @test rates6[13] ≈ 0.0 atol = 1e-15
    end

    @testset "Density dependence" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi = zeros(ComplexF64, 64, 3)

        # Component 2 (m=0): put higher density on left half
        psi[1:32, 2] .= 2.0
        psi[33:64, 2] .= 0.5

        pop_left_before = sum(abs2, psi[1:32, 2])
        pop_right_before = sum(abs2, psi[33:64, 2])

        loss = LossParams(0.05, 0.0)
        apply_loss_step!(psi, loss, 1, 0.01, 3, 1)

        pop_left_after = sum(abs2, psi[1:32, 2])
        pop_right_after = sum(abs2, psi[33:64, 2])

        # Higher density region loses more (fractionally)
        frac_left = (pop_left_before - pop_left_after) / pop_left_before
        frac_right = (pop_right_before - pop_right_after) / pop_right_before
        @test frac_left > frac_right
    end

    @testset "L3 loss: uniform across all m" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:uniform)
        loss = LossParams(0.0, 0.1)
        dt = 0.01

        for _ in 1:50
            apply_loss_step!(psi, loss, 1, dt, sys.n_components, 1)
        end

        pop = [sum(abs2, psi[:, c]) for c in 1:3]
        # All components decay at same rate with L3 only
        @test pop[1] ≈ pop[2] rtol = 1e-10
        @test pop[2] ≈ pop[3] rtol = 1e-10
    end

    @testset "loss=nothing in workspace: no error" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sp = SimParams(; dt=0.01, n_steps=10)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.0)),
            sim_params=sp,
            loss=nothing,
        )
        N0 = total_norm(ws.state.psi, ws.grid)
        for _ in 1:10
            split_step!(ws)
        end
        @test total_norm(ws.state.psi, ws.grid) ≈ N0 rtol = 1e-6
    end

    @testset "loss in workspace: norm decreases" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sp = SimParams(; dt=0.01, n_steps=100)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.0)),
            sim_params=sp,
            loss=LossParams(0.5, 0.0),
        )
        N0 = total_norm(ws.state.psi, ws.grid)
        for _ in 1:100
            split_step!(ws)
        end
        N1 = total_norm(ws.state.psi, ws.grid)
        @test N1 < N0
    end

    @testset "leapfrog with loss: norm decreases" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sp = SimParams(; dt=0.01, n_steps=100, save_every=100)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.0)),
            sim_params=sp,
            loss=LossParams(0.5, 0.0),
        )
        N0 = total_norm(ws.state.psi, ws.grid)
        result = run_simulation!(ws)
        N1 = total_norm(ws.state.psi, ws.grid)
        @test N1 < N0
    end

    @testset "Loss skipped during imaginary time" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sp = SimParams(; dt=0.01, n_steps=10, imaginary_time=true)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.0)),
            potential=HarmonicTrap(1.0),
            sim_params=sp,
            loss=LossParams(100.0, 100.0),
        )
        for _ in 1:10
            split_step!(ws)
        end
        N1 = total_norm(ws.state.psi, ws.grid)
        @test N1 ≈ 1.0 rtol = 1e-6
    end

    @testset "YAML parsing of losses" begin
        yaml = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid:
                n: 64
                box: 20.0
              interactions:
                c0: 1.0
                c1: 0.0
              losses:
                gamma_dr: 1.0e-3
                L3: 2.0e-5
              dt: 0.01
              n_steps: 10
              tol: 1e-4
              potential: {type: harmonic, omega: [1.0]}
        """
        cfg = load_config_from_string(yaml)
        @test cfg isa PipelineConfig
        p = cfg.steps[1].params
        @test p["losses"]["gamma_dr"] == 1e-3
        @test p["losses"]["L3"] == 2e-5
    end

    @testset "YAML without losses" begin
        yaml = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid:
                n: 64
                box: 20.0
              interactions:
                c0: 1.0
                c1: 0.0
              dt: 0.01
              n_steps: 10
              tol: 1e-4
              potential: {type: harmonic, omega: [1.0]}
        """
        cfg = load_config_from_string(yaml)
        p = cfg.steps[1].params
        @test !haskey(p, "losses")
    end

    @testset "YAML parsing of phase temperature_ratio" begin
        yaml = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid:
                n: 64
                box: 20.0
              interactions:
                c0: 1.0
                c1: 0.0
              dt: 0.01
              n_steps: 10
              tol: 1e-4
              potential: {type: harmonic, omega: [1.0]}
          - dynamics:
              duration: 1.0
              dt: 0.01
              temperature_ratio: 0.1
          - dynamics:
              duration: 1.0
              dt: 0.01
        """
        cfg = load_config_from_string(yaml)
        @test cfg.steps[2].params["temperature_ratio"] == 0.1
        @test get(cfg.steps[3].params, "temperature_ratio", nothing) === nothing
    end

    @testset "_add_noise! changes psi but preserves norm" begin
        config = GridConfig((32, 32), (10.0, 10.0))
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:polar)
        dV = cell_volume(grid)

        psi_before = copy(psi)
        SpinorBEC._add_noise!(psi, 0.01, sys.n_components, 2, grid)

        @test psi != psi_before
        N1 = sum(abs2, psi) * dV
        @test N1 ≈ 1.0 rtol = 1e-12
    end

    @testset "_add_noise! skips dominant component" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:m_plus_F)
        dominant_before = copy(psi[:, 1])

        SpinorBEC._add_noise!(psi, 0.01, sys.n_components, 1, grid)

        scale = psi[32, 1] / dominant_before[32]
        @test psi[:, 1] ≈ dominant_before .* scale rtol = 1e-10
        @test sum(abs2, psi[:, 2]) > 0
        @test sum(abs2, psi[:, 3]) > 0
    end

    @testset "2D loss step" begin
        config = GridConfig((32, 32), (10.0, 10.0))
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi = zeros(ComplexF64, 32, 32, 3)
        for c in 1:3
            psi[:, :, c] .= 1.0 / sqrt(3 * 32 * 32)
        end
        loss = LossParams(0.1, 0.0)

        pop_before = [sum(abs2, psi[:, :, c]) for c in 1:3]
        apply_loss_step!(psi, loss, 1, 0.01, 3, 2)
        pop_after = [sum(abs2, psi[:, :, c]) for c in 1:3]

        # c=1->m=+1, c=2->m=0, c=3->m=-1
        # m=-1 (c=3) unchanged
        @test pop_after[3] ≈ pop_before[3] rtol = 1e-14
        # m=+1,0 decay
        @test pop_after[1] < pop_before[1]
        @test pop_after[2] < pop_before[2]
    end
end
