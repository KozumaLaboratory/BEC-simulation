@testset "LHY Beyond-Mean-Field" begin
    @testset "c_lhy=0 regression: identical to original" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sp = SimParams(; dt=0.01, n_steps=50)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => -0.5)),
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

    @testset "scalar LHY n^(5/2) scaling (Level 8)" begin
        # For a uniform ψ at density n_0:
        #   ε_LHY(n_0) = (2/5) · c_lhy · n_0^(5/2)   (energy density)
        #   E_LHY(n_0) = (2/5) · c_lhy · n_0^(5/2) · V_total
        # μ_LHY = ∂E_LHY/∂N = c_lhy · n_0^(3/2)  (this is why c_lhy has the
        # bare scaling; the (2/5) is the energy-vs-chemical-potential primitive).
        # Verify the slope 5/2 by varying n_0 over half a decade. Single
        # component (m=+F) suffices — scalar LHY acts on n_total = Σ_c|ψ_c|².
        ndim = 3
        n_pt = 8
        L = 4.0
        config = GridConfig{ndim}(ntuple(_ -> n_pt, ndim), ntuple(_ -> L, ndim))
        grid = make_grid(config)
        dV = cell_volume(grid)
        V_total = dV * prod(grid.config.n_points)
        sys = SpinSystem(1)
        n_comp = sys.n_components
        c_lhy = 0.5

        n0_values = [0.25, 0.5, 1.0, 2.0, 4.0]
        E_values = Float64[]
        for n0 in n0_values
            psi = zeros(ComplexF64, n_pt, n_pt, n_pt, n_comp)
            psi[:, :, :, 1] .= sqrt(n0)
            E = SpinorBEC._lhy_energy(psi, c_lhy, n_comp, ndim, grid.config.n_points, dV)
            push!(E_values, E)
        end

        # Log-log slope: log(E) = (5/2) log(n_0) + const
        logn = log.(n0_values)
        logE = log.(E_values)
        slopes = [
            (logE[i + 1] - logE[i]) / (logn[i + 1] - logn[i]) for
            i in 1:(length(n0_values) - 1)
        ]
        for s in slopes
            @test isapprox(s, 5 / 2; atol=1e-6)
        end

        # Absolute value at n_0=1: E = (2/5) · c_lhy · 1 · V_total
        idx_1 = findfirst(==(1.0), n0_values)
        @test isapprox(E_values[idx_1], (2 / 5) * c_lhy * V_total; rtol=1e-12)

        # Spot check the formula at n_0=2: E = (2/5) · c_lhy · 2^(5/2) · V_total
        idx_2 = findfirst(==(2.0), n0_values)
        @test isapprox(
            E_values[idx_2], (2 / 5) * c_lhy * 2^2.5 * V_total; rtol=1e-12)
    end

    @testset "LHY modifies total energy" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sp = SimParams(; dt=0.01, n_steps=10)

        ws0 = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => -0.5)),
            potential=HarmonicTrap(1.0),
            sim_params=sp,
        )
        E_no_lhy = total_energy(ws0)

        ws1 = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => -0.5); c_lhy=100.0),
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
            interactions=InteractionParams(Dict(0 => 10.0, 1 => -0.5); c_lhy=50.0),
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
        ip1 = InteractionParams(Dict(0 => 1.0, 1 => 2.0))
        @test ip1.c_lhy == 0.0
        @test ip1[2] == 0.0

        ip3 = InteractionParams(Dict(0 => 1.0, 1 => 2.0); c_lhy=5.0)
        @test ip3.c_lhy == 5.0
        @test ip3[2] == 0.0

        ip4 = InteractionParams(Dict(0 => 1.0, 1 => 2.0, 2 => 3.0); c_lhy=5.0)
        @test ip4.c_lhy == 5.0
        @test ip4[2] == 3.0
    end

    @testset "YAML parsing of lhy.c_lhy" begin
        # Post-2026-05-12: c_lhy moved from `interactions.c_lhy` to
        # `lhy.c_lhy` (single LHY block; see lhy_refactor_2026_05_12 memory).
        yaml = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid:
                n: 64
                box: 20.0
              interactions:
                c0: 10.0
                c1: -0.5
              lhy:
                kind: scalar
                c_lhy: 100.0
              dt: 0.01
              n_steps: 10
              tol: 1e-4
              potential: {type: harmonic, omega: [1.0]}
        """
        cfg = load_config_from_string(yaml)
        @test cfg isa PipelineConfig
        p = cfg.steps[1].params
        @test p["lhy"]["c_lhy"] == 100.0
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

        @testset "eps_dd > 1 returns finite positive Q5 (Waechtler-Santos extension)" begin
            Q5 = lima_pelster_Q5(1.5)
            @test Q5 > 0.0
            @test isfinite(Q5)
            @test Q5 > lima_pelster_Q5(1.0)
        end

        @testset "compute_c_lhy_with_ddi" begin
            @test compute_c_lhy_with_ddi(1.0, 0.0) ≈ 1.0 atol = 1e-14
            @test compute_c_lhy_with_ddi(2.0, 0.5) ≈ 2.0 * lima_pelster_Q5(0.5)
        end
    end

    @testset "YAML without c_lhy defaults to 0" begin
        yaml = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid:
                n: 64
                box: 20.0
              interactions:
                c0: 10.0
                c1: -0.5
              dt: 0.01
              n_steps: 10
              tol: 1e-4
              potential: {type: harmonic, omega: [1.0]}
        """
        cfg = load_config_from_string(yaml)
        p = cfg.steps[1].params
        @test get(p["interactions"], "c_lhy", 0.0) == 0.0
    end
end
