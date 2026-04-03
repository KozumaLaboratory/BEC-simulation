@testset "Quasi-2D direct API" begin
    @testset "make_workspace scales interactions" begin
        grid = make_grid(GridConfig((16, 16), (10.0, 10.0)))
        atom = Rb87
        c0, c1 = 10.0, -0.5
        interactions = InteractionParams(c0, c1)
        l_z_val = 1.5
        factor = 1.0 / (sqrt(2π) * l_z_val)

        sp = SimParams(; dt=0.01, n_steps=5, imaginary_time=true, normalize_every=1)
        ws = make_workspace(;
            grid, atom, interactions,
            sim_params=sp,
            potential=HarmonicTrap((1.0, 1.0)),
            quasi_2d=true, l_z=l_z_val,
        )

        @test ws.interactions.c0 ≈ c0 * factor
        @test ws.interactions.c1 ≈ c1 * factor
    end

    @testset "find_ground_state with quasi_2d runs" begin
        grid = make_grid(GridConfig((16, 16), (10.0, 10.0)))
        atom = Rb87
        interactions = InteractionParams(10.0, -0.5)

        result = find_ground_state(;
            grid, atom, interactions,
            potential=HarmonicTrap((1.0, 1.0)),
            dt=0.005, n_steps=50, tol=1e-4,
            quasi_2d=true, l_z=1.5,
        )
        @test result.energy isa Float64
    end

    @testset "3D grid + quasi_2d → ArgumentError" begin
        grid = make_grid(GridConfig((16, 16, 16), (10.0, 10.0, 10.0)))
        atom = Rb87
        interactions = InteractionParams(10.0, 0.0)
        sp = SimParams(; dt=0.01, n_steps=5)

        @test_throws ArgumentError make_workspace(;
            grid, atom, interactions,
            sim_params=sp,
            quasi_2d=true, l_z=1.5,
        )
    end

    @testset "l_z=0 + quasi_2d → ArgumentError" begin
        grid = make_grid(GridConfig((16, 16), (10.0, 10.0)))
        atom = Rb87
        interactions = InteractionParams(10.0, 0.0)
        sp = SimParams(; dt=0.01, n_steps=5)

        @test_throws ArgumentError make_workspace(;
            grid, atom, interactions,
            sim_params=sp,
            quasi_2d=true, l_z=0.0,
        )
    end

    @testset "quasi_2d=false leaves interactions unchanged" begin
        grid = make_grid(GridConfig((16, 16), (10.0, 10.0)))
        atom = Rb87
        c0, c1 = 10.0, -0.5
        interactions = InteractionParams(c0, c1)
        sp = SimParams(; dt=0.01, n_steps=5, imaginary_time=true, normalize_every=1)

        ws = make_workspace(;
            grid, atom, interactions,
            sim_params=sp,
            potential=HarmonicTrap((1.0, 1.0)),
        )
        @test ws.interactions.c0 == c0
        @test ws.interactions.c1 == c1
    end

    @testset "DDI auto-routes when quasi_2d=true" begin
        grid = make_grid(GridConfig((16, 16), (10.0, 10.0)))
        atom = Rb87
        interactions = InteractionParams(10.0, 0.0)
        sp = SimParams(; dt=0.01, n_steps=5, imaginary_time=true, normalize_every=1)

        ws = make_workspace(;
            grid, atom, interactions,
            sim_params=sp,
            potential=HarmonicTrap((1.0, 1.0)),
            enable_ddi=true, c_dd=1.0,
            quasi_2d=true, l_z=1.5,
        )
        @test ws.ddi !== nothing
    end

    @testset "scale_interactions_quasi_2d is exported" begin
        ip = InteractionParams(10.0, -0.5)
        l_z_val = 2.0
        factor = 1.0 / (sqrt(2π) * l_z_val)
        ip2 = scale_interactions_quasi_2d(ip, l_z_val)
        @test ip2.c0 ≈ ip.c0 * factor
        @test ip2.c1 ≈ ip.c1 * factor
    end
end
