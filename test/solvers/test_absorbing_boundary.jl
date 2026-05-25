@testset "Absorbing Boundary" begin
    @testset "AbsorbingBoundary constructors" begin
        ab = AbsorbingBoundary(10.0, 3.0, 2)
        @test ab.strength == 10.0
        @test ab.width == 3.0
        @test ab.power == 2

        ab2 = AbsorbingBoundary(strength=5.0, width=2.0)
        @test ab2.power == 2
    end

    @testset "mask shape: 1.0 in bulk, <1 near edges" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        ab = AbsorbingBoundary(strength=10.0, width=3.0, power=2)
        mask = compute_absorbing_mask(grid, ab, 0.01, CPUBackend())

        @test size(mask) == (64,)
        @test mask[32] ≈ 1.0
        @test mask[33] ≈ 1.0
        @test mask[1] < 1.0
        @test mask[64] < 1.0
        @test all(0 .< mask .<= 1)
    end

    @testset "mask symmetry" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        ab = AbsorbingBoundary(strength=10.0, width=3.0, power=2)
        mask = compute_absorbing_mask(grid, ab, 0.01, CPUBackend())

        for i in 1:32
            @test mask[i] ≈ mask[65 - i] rtol = 1e-12
        end
    end

    @testset "2D mask: bulk=1, corners strongest absorption" begin
        config = GridConfig((32, 32), (10.0, 10.0))
        grid = make_grid(config)
        ab = AbsorbingBoundary(strength=10.0, width=2.0, power=2)
        mask = compute_absorbing_mask(grid, ab, 0.01, CPUBackend())

        @test size(mask) == (32, 32)
        @test mask[16, 16] ≈ 1.0
        @test mask[1, 1] < mask[1, 16]
        @test mask[1, 1] < mask[16, 1]
    end

    @testset "apply_absorbing_boundary! damps components equally" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        ab = AbsorbingBoundary(strength=10.0, width=3.0, power=2)
        mask = compute_absorbing_mask(grid, ab, 0.01, CPUBackend())

        psi = ones(ComplexF64, 64, 3)
        apply_absorbing_boundary!(psi, mask, 3, 1)

        for c in 1:3
            @test psi[:, c] ≈ mask rtol = 1e-14
        end
    end

    @testset "absorbing_boundary=nothing in workspace: no error" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sp = SimParams(; dt=0.01, n_steps=10)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.0)),
            sim_params=sp,
        )
        @test ws.absorbing_mask === nothing
        N0 = total_norm(ws.state.psi, ws.grid)
        for _ in 1:10
            split_step!(ws)
        end
        @test total_norm(ws.state.psi, ws.grid) ≈ N0 rtol = 1e-6
    end

    @testset "absorbing boundary in workspace: norm decreases" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sp = SimParams(; dt=0.01, n_steps=100)
        ab = AbsorbingBoundary(strength=10.0, width=3.0, power=2)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.0)),
            sim_params=sp,
            absorbing_boundary=ab,
        )
        N0 = total_norm(ws.state.psi, ws.grid)
        for _ in 1:100
            split_step!(ws)
        end
        N1 = total_norm(ws.state.psi, ws.grid)
        @test N1 < N0
    end

    @testset "skipped during imaginary time" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sp = SimParams(; dt=0.01, n_steps=10, imaginary_time=true)
        ab = AbsorbingBoundary(strength=100.0, width=5.0, power=2)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.0)),
            potential=HarmonicTrap(1.0),
            sim_params=sp,
            absorbing_boundary=ab,
        )
        for _ in 1:10
            split_step!(ws)
        end
        N1 = total_norm(ws.state.psi, ws.grid)
        @test N1 ≈ 1.0 rtol = 1e-6
    end

    @testset "wavepacket at edge absorbed, no wrap-around" begin
        config = GridConfig(128, 20.0)
        grid = make_grid(config)
        sys = SpinSystem(1)
        D = sys.n_components
        psi = zeros(ComplexF64, 128, D)
        dx = grid.config.box_size[1] / 128

        # Gaussian at +7 a_ho (near right edge, within absorbing region)
        x0 = 7.0
        sigma = 0.5
        for i in 1:128
            psi[i, 1] = exp(-(grid.x[1][i] - x0)^2 / (2 * sigma^2))
        end
        norm0 = sqrt(sum(abs2, psi) * dx)
        psi ./= norm0

        ab = AbsorbingBoundary(strength=50.0, width=4.0, power=2)
        sp = SimParams(; dt=0.001, n_steps=200)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            sim_params=sp,
            absorbing_boundary=ab,
            psi_init=psi,
        )

        for _ in 1:200
            split_step!(ws)
        end

        N_final = total_norm(ws.state.psi, ws.grid)
        @test N_final < 0.95

        # Check no significant density wrapped to left edge
        left_density = sum(abs2, ws.state.psi[1:16, :])
        total_density = sum(abs2, ws.state.psi)
        @test left_density / max(total_density, 1e-30) < 0.01
    end

    @testset "power=1 vs power=2: different ramp profiles" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)

        ab1 = AbsorbingBoundary(strength=10.0, width=3.0, power=1)
        ab2 = AbsorbingBoundary(strength=10.0, width=3.0, power=2)
        mask1 = compute_absorbing_mask(grid, ab1, 0.01, CPUBackend())
        mask2 = compute_absorbing_mask(grid, ab2, 0.01, CPUBackend())

        @test mask1[1] != mask2[1]
        # power=1 (linear) absorbs more at intermediate distance
        @test mask1[5] < mask2[5]
    end

    @testset "YAML parsing of absorbing_boundary" begin
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
              absorbing_boundary: {strength: 10.0, width: 3.0, power: 2}
        """
        cfg = load_config_from_string(yaml)
        p = cfg.steps[2].params
        @test p["absorbing_boundary"]["strength"] == 10.0
        @test p["absorbing_boundary"]["width"] == 3.0
        @test p["absorbing_boundary"]["power"] == 2
    end
end
