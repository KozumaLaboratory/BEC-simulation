using Test
using SpinorBEC

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

    @testset "absorbing applied on every production driver (App. A epilogue audit)" begin
        # THE regression for the live bug: run_simulation! (leapfrog,
        # the production RTP default), run_simulation_yoshida!, and
        # run_simulation_adaptive! each hand-write the per-step epilogue
        # and PRE-FIX applied loss but OMITTED the absorbing mask — only
        # split_step! had it, and no test routed an absorber through the
        # drivers. So a production `dynamics: {absorbing_boundary: {...}}`
        # built the mask and silently discarded it. With c0=c1=0 the RTP
        # core is exactly unitary, so the ONLY thing that can drop the
        # norm is the absorbing mask. Pre-fix: norm ratio ≈ 1.0 (RED);
        # post-fix: a packet sitting in the absorbing zone is damped.
        function _edge_ws(; dt=0.005, n_steps=120)
            grid = make_grid(GridConfig(128, 20.0))
            psi = zeros(ComplexF64, 128, 3)
            for i in 1:128
                psi[i, 1] = exp(-(grid.x[1][i] - 7.0)^2 / (2 * 0.5^2))
            end
            psi ./= sqrt(sum(abs2, psi) * grid.config.box_size[1] / 128)
            ab = AbsorbingBoundary(strength=50.0, width=4.0, power=2)
            sp = SimParams(; dt=dt, n_steps=n_steps)
            make_workspace(;
                grid, atom=Rb87,
                interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
                sim_params=sp, absorbing_boundary=ab, psi_init=psi,
            )
        end

        @testset "run_simulation! (leapfrog — production RTP default)" begin
            ws = _edge_ws()
            N0 = total_norm(ws.state.psi, ws.grid)
            run_simulation!(ws)
            @test total_norm(ws.state.psi, ws.grid) < 0.97 * N0
        end

        @testset "run_simulation_yoshida!" begin
            ws = _edge_ws()
            N0 = total_norm(ws.state.psi, ws.grid)
            run_simulation_yoshida!(ws; t_end=0.4, save_interval=0.1)
            @test total_norm(ws.state.psi, ws.grid) < 0.97 * N0
        end

        @testset "run_simulation_adaptive!" begin
            ws = _edge_ws()
            N0 = total_norm(ws.state.psi, ws.grid)
            run_simulation_adaptive!(ws; t_end=0.4, save_interval=0.1)
            @test total_norm(ws.state.psi, ws.grid) < 0.97 * N0
        end
    end

    @testset "apply_rt_dissipation! co-applies loss AND absorbing" begin
        # Unit gate on the consolidated helper: loss and the absorbing
        # mask are inseparable. A workspace with BOTH active must damp
        # more than either alone — pins that the helper never drops a
        # channel (the term-omission that hid in the driver loops).
        grid = make_grid(GridConfig(64, 20.0))
        ab = AbsorbingBoundary(strength=20.0, width=3.0, power=2)
        loss = LossParams(; K3_cubic=0.5)
        function _ws(; with_loss, with_abs)
            sp = SimParams(; dt=0.01, n_steps=1)
            make_workspace(;
                grid, atom=Rb87,
                interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
                sim_params=sp,
                loss=with_loss ? loss : nothing,
                absorbing_boundary=with_abs ? ab : nothing,
            )
        end
        seed = zeros(ComplexF64, 64, 3)
        for i in 1:64
            seed[i, 1] = exp(-(grid.x[1][i] - 8.0)^2 / 2) + 0.3
        end
        n_of(ws) = begin
            copyto!(ws.state.psi, seed)
            SpinorBEC.apply_rt_dissipation!(ws, 0.05, 3, 1)
            total_norm(ws.state.psi, ws.grid)
        end
        n_both = n_of(_ws(with_loss=true, with_abs=true))
        n_loss = n_of(_ws(with_loss=true, with_abs=false))
        n_abs = n_of(_ws(with_loss=false, with_abs=true))
        n_none = n_of(_ws(with_loss=false, with_abs=false))
        @test n_none ≈ total_norm(seed, grid) rtol = 1e-12   # neither ⇒ untouched
        @test n_both < n_loss                                # absorbing still acts with loss on
        @test n_both < n_abs                                 # loss still acts with absorbing on
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
