using Test
using SpinorBEC
using FFTW

@testset "Simulation" begin
    @testset "Ground state: 87Rb ferromagnetic (c1 < 0)" begin
        config = GridConfig(128, 20.0)
        grid = make_grid(config)
        interactions = InteractionParams(Dict(0 => 10.0, 1 => -0.5))
        trap = HarmonicTrap(1.0)

        result = find_ground_state(;
            grid, atom=Rb87, interactions, potential=trap,
            dt=0.005, n_steps=5000, initial_state=:m_plus_F,
        )

        psi = result.workspace.state.psi
        n1 = sum(abs2, psi[:, 1]) * cell_volume(grid)
        n2 = sum(abs2, psi[:, 2]) * cell_volume(grid)
        n3 = sum(abs2, psi[:, 3]) * cell_volume(grid)

        @test n1 > 0.9
        @test n2 < 0.05
        @test n3 < 0.05
        @test haskey(result, :dE)
        @test haskey(result, :dpsi)
    end

    @testset "Ground state: 23Na polar (c1 > 0)" begin
        config = GridConfig(128, 20.0)
        grid = make_grid(config)
        interactions = InteractionParams(Dict(0 => 10.0, 1 => 0.5))
        trap = HarmonicTrap(1.0)

        result = find_ground_state(;
            grid, atom=Na23, interactions, potential=trap,
            dt=0.005, n_steps=5000, initial_state=:polar,
        )

        psi = result.workspace.state.psi
        n1 = sum(abs2, psi[:, 1]) * cell_volume(grid)
        n2 = sum(abs2, psi[:, 2]) * cell_volume(grid)
        n3 = sum(abs2, psi[:, 3]) * cell_volume(grid)

        @test n2 > 0.9
        @test n1 < 0.05
        @test n3 < 0.05
    end

    @testset "seed_noise returns noisy copy preserving norm" begin
        config = GridConfig(64, 10.0)
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi_gs = init_psi(grid, sys; state=:m_plus_F)
        dV = cell_volume(grid)

        psi_noisy = SpinorBEC.seed_noise(psi_gs, sys.n_components, 1, grid)

        @test psi_noisy !== psi_gs
        @test psi_noisy != psi_gs
        norm_noisy = sum(abs2, psi_noisy) * dV
        @test abs(norm_noisy - 1.0) < 1e-10

        psi_noisy2 = SpinorBEC.seed_noise(psi_gs, sys.n_components, 1, grid)
        @test psi_noisy ≈ psi_noisy2
    end

    @testset "init_psi new states" begin
        grid = make_grid(GridConfig(64, 10.0))
        sys1 = SpinSystem(1)
        sys2 = SpinSystem(2)
        dV = cell_volume(grid)

        @testset "antiferromagnetic: unit norm" begin
            psi = init_psi(grid, sys1; state=:antiferromagnetic)
            @test total_norm(psi, grid) ≈ 1.0 atol = 1e-12
        end

        @testset "antiferromagnetic: zero magnetization for F=1" begin
            psi = init_psi(grid, sys1; state=:antiferromagnetic)
            Mz = magnetization(psi, grid, sys1)
            @test abs(Mz) < 1e-12
        end

        @testset "random: unit norm and seed reproducibility" begin
            psi1 = init_psi(grid, sys1; state=:random, seed=123)
            psi2 = init_psi(grid, sys1; state=:random, seed=123)
            psi3 = init_psi(grid, sys1; state=:random, seed=456)
            @test total_norm(psi1, grid) ≈ 1.0 atol = 1e-12
            @test psi1 ≈ psi2
            @test !(psi1 ≈ psi3)
        end

        @testset "spin_helix: unit norm" begin
            psi = init_psi(grid, sys1; state=:spin_helix, helix_k=(1.0,))
            @test total_norm(psi, grid) ≈ 1.0 atol = 1e-12
        end

        @testset "F=2 antiferromagnetic: unit norm" begin
            grid2 = make_grid(GridConfig(32, 10.0))
            psi = init_psi(grid2, sys2; state=:antiferromagnetic)
            @test total_norm(psi, grid2) ≈ 1.0 atol = 1e-12
        end
    end

    @testset "find_ground_state_multistart" begin
        config = GridConfig(64, 10.0)
        grid = make_grid(config)
        trap = HarmonicTrap(1.0)

        @testset "ferromagnetic (c1 < 0) picks ferro" begin
            interactions = InteractionParams(Dict(0 => 10.0, 1 => -0.5))
            result = find_ground_state_multistart(;
                grid, atom=Rb87, interactions, potential=trap,
                dt=0.005, n_steps=2000,
                initial_states=[:polar, :m_plus_F],
                fft_flags=FFTW.ESTIMATE,
            )
            @test result.initial_state == :m_plus_F
            @test result.converged || result.energy < 10.0
            @test length(result.all_results) == 2
        end
    end

    @testset "magnetization-constrained ITP" begin
        config = GridConfig(64, 10.0)
        grid = make_grid(config)
        trap = HarmonicTrap(1.0)
        interactions = InteractionParams(Dict(0 => 10.0, 1 => -0.5))

        @testset "target Mz=0 for ferromagnetic c1<0 → polar-like" begin
            result = find_ground_state(;
                grid, atom=Rb87, interactions, potential=trap,
                dt=0.005, n_steps=3000, initial_state=:uniform,
                target_magnetization=0.0,
                fft_flags=FFTW.ESTIMATE,
            )
            sys = SpinSystem(1)
            Mz = magnetization(result.workspace.state.psi, grid, sys)
            @test abs(Mz) < 0.05
        end

        @testset "target Mz=1 for ferromagnetic c1<0 → ferromagnetic" begin
            result = find_ground_state(;
                grid, atom=Rb87, interactions, potential=trap,
                dt=0.005, n_steps=3000, initial_state=:m_plus_F,
                target_magnetization=1.0,
                fft_flags=FFTW.ESTIMATE,
            )
            psi = result.workspace.state.psi
            n1 = sum(abs2, psi[:, 1]) * cell_volume(grid)
            @test n1 > 0.9
        end
    end

    @testset "run_simulation! returns result" begin
        config = GridConfig(64, 10.0)
        grid = make_grid(config)
        interactions = InteractionParams(Dict(0 => 1.0, 1 => 0.1))
        sp = SimParams(; dt=0.01, n_steps=50, imaginary_time=false, save_every=10)

        ws = make_workspace(;
            grid, atom=Rb87, interactions, sim_params=sp
        )

        result = run_simulation!(ws)
        @test length(result.times) == 6   # initial + 5 saves
        @test length(result.energies) == 6
        @test all(n -> abs(n - 1.0) < 1e-8, result.norms)
    end

    @testset "Coriolis step norm preservation (2D)" begin
        config = GridConfig((32, 32), (10.0, 10.0))
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:polar)
        dV = cell_volume(grid)
        norm_before = sum(abs2, psi) * dV

        SpinorBEC._apply_coriolis_step!(psi, grid, 0.5, 0.01, false)
        norm_after = sum(abs2, psi) * dV
        @test norm_after ≈ norm_before rtol = 1e-10
    end

    @testset "Coriolis step no-op for omega=0" begin
        config = GridConfig((16, 16), (10.0, 10.0))
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:m_plus_F)
        psi_copy = copy(psi)

        SpinorBEC._apply_coriolis_step!(psi, grid, 0.0, 0.01, false)
        @test psi ≈ psi_copy
    end

    @testset "Coriolis step no-op for 1D" begin
        config = GridConfig(32, 10.0)
        grid = make_grid(config)
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:polar)
        psi_copy = copy(psi)

        SpinorBEC._apply_coriolis_step!(psi, grid, 1.0, 0.01, false)
        @test psi ≈ psi_copy
    end

    @testset "Coriolis step rotates ψ clockwise (REAL TIME direction)" begin
        # Convention: H_rot = H_lab − Ω·L_z. The RT Coriolis substep
        # implements exp(−i·(−Ω·L_z)·dt) = exp(+iΩ·L_z·dt). Recalling
        # R̂(α) = exp(−iα·L_z) (active CCW rotation by α), this equals
        # R̂(−Ω·dt) — active CLOCKWISE rotation of ψ by Ω·dt. A Gaussian
        # centred at (3, 0) rotated by −π/2 must land at (0, −3).
        #
        # Norm preservation (the test above) is necessary but NOT
        # sufficient — it holds for any unitary rotation, including the
        # wrong direction. The 2026-06-03 audit
        # (`mistake_coriolis_substep_sign_2026_06_03.md`) reverted an
        # earlier over-correction that had inverted the substep to CCW;
        # this test pins the correct CW direction.
        config = GridConfig((64, 64), (16.0, 16.0))
        grid = make_grid(config)
        psi = zeros(ComplexF64, 64, 64, 3)
        σ = 0.6
        x_offset = 3.0
        for I in CartesianIndices((64, 64))
            x = grid.x[1][I[1]]
            y = grid.x[2][I[2]]
            psi[I, 2] = exp(-((x - x_offset)^2 + y^2) / (2 * σ^2))
        end
        dV = cell_volume(grid)
        psi ./= sqrt(sum(abs2, psi) * dV)

        # Centre of mass before: should be at (x_offset, 0).
        n_before = SpinorBEC.total_density(psi, 2)
        x_vec = grid.x[1]
        y_vec = grid.x[2]
        cx0 = sum(I -> x_vec[I[1]] * n_before[I], CartesianIndices((64, 64))) * dV
        cy0 = sum(I -> y_vec[I[2]] * n_before[I], CartesianIndices((64, 64))) * dV
        @test cx0 ≈ x_offset atol=0.01
        @test cy0 ≈ 0.0 atol=0.01

        # Apply Coriolis with Ω·dt = π/2 → 90° clockwise rotation.
        SpinorBEC._apply_coriolis_step!(psi, grid, 1.0, π/2, false)

        n_after = SpinorBEC.total_density(psi, 2)
        cx1 = sum(I -> x_vec[I[1]] * n_after[I], CartesianIndices((64, 64))) * dV
        cy1 = sum(I -> y_vec[I[2]] * n_after[I], CartesianIndices((64, 64))) * dV
        # Expected (CW): peak (3, 0) → (0, −3).
        @test cx1 ≈ 0.0 atol=0.15
        @test cy1 ≈ -x_offset atol=0.15
    end

    @testset "Static +Bx aligns ⟨F_x⟩ > 0 (transverse Zeeman sign oracle)" begin
        # User-spec convention (`b_block_builders.jl:27`):
        #   `H_Zeeman = -(g_F μ_B B · F) + q F_z²`
        # → For +Bx, H gets `-bx·F_x` → low energy at ⟨F_x⟩ > 0
        # → spin aligns WITH +Bx, not against it.
        #
        # Pre-2026-06-04 the propagator applied `+bx·F_x` (opposite
        # sign), which gave ⟨F_x⟩ → −F at +Bx. The bug was caught by
        # the M2 lab-frame stir asymmetry showing EdH-inverted direction
        # (CCW rotation pumped ⟨F_z⟩ negative instead of positive).
        # This test pins the corrected convention as a permanent guard.
        #
        # Setup: F=1, c1=0, both +Bz and +Bx active. FM_z initial
        # state breaks the F_x parity (polar/FM_z superposition has
        # ⟨F_x⟩=0 by symmetry — needs a Bz-aligned seed for the +Bx
        # tilt to drive ⟨F_x⟩ off zero). GS lives in (x, z) plane with
        # ⟨F_x⟩ > 0 ALWAYS (the diagnostic), and ⟨F_z⟩ > 0 too.
        config = GridConfig((8, 8, 8), (4.0, 4.0, 4.0))
        grid = make_grid(config)
        atom = Rb87
        interactions = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
        # TimeDependentZeeman(p_wf, q_wf, bx_wf, by_wf) — p first = Bz.
        zeeman = TimeDependentZeeman(
            ConstantWaveform(1.0),   # Bz = 1 (parity breaker)
            ConstantWaveform(0.0),   # q = 0
            ConstantWaveform(2.0),   # Bx = 2 (dominant)
            ConstantWaveform(0.0),   # By = 0
        )
        r = find_ground_state(;
            grid, atom, interactions, zeeman,
            potential=HarmonicTrap((1.0, 1.0, 1.0)),
            dt=0.005, n_steps=500, tol=0.0,
            initial_state=:m_plus_F, verbose=false,
            enable_ddi=false,
        )
        psi = Array(r.workspace.state.psi)
        sm = r.workspace.spin_matrices
        fx, fy, fz = spin_density_vector(psi, sm, 3)
        dV = cell_volume(grid)
        Fx = sum(fx) * dV
        Fz = sum(fz) * dV
        @test Fx > 0.1   # spin tilts toward +Bx (post-fix); pre-fix gave −0.x
        @test Fz > 0.1   # Bz dominates the polar pull → mostly along +z
    end

    @testset "Coriolis step amplifies +L_z component (IMAGINARY TIME direction)" begin
        # In ITP the substep implements exp(+Ω·L_z·dτ), descending on the
        # rotating-frame functional H_rot = H − Ω·L_z. On an L_z = +1
        # eigenstate (single-vortex `(x + iy)·gauss`), amplitudes are
        # multiplied by exp(+Ω·dτ); on L_z = −1 by exp(−Ω·dτ). A
        # wrong-sign substep would flip both ratios.
        config = GridConfig((48, 48), (12.0, 12.0))
        grid = make_grid(config)
        dV = cell_volume(grid)
        σ = 1.0

        ψplus = zeros(ComplexF64, 48, 48, 3)
        ψminus = zeros(ComplexF64, 48, 48, 3)
        for I in CartesianIndices((48, 48))
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]]
            envelope = exp(-(x^2 + y^2) / (2 * σ^2))
            ψplus[I, 2] = (x + im*y) * envelope
            ψminus[I, 2] = (x - im*y) * envelope
        end

        ω = 0.7
        dτ = 0.1
        nrm_plus_before = sum(abs2, ψplus) * dV
        nrm_minus_before = sum(abs2, ψminus) * dV

        SpinorBEC._apply_coriolis_step!(ψplus, grid, ω, dτ, true)
        SpinorBEC._apply_coriolis_step!(ψminus, grid, ω, dτ, true)

        nrm_plus_after = sum(abs2, ψplus) * dV
        nrm_minus_after = sum(abs2, ψminus) * dV

        # Ratio for L_z = ℓ should be exp(2·Ω·dτ·ℓ). Allow modest
        # tolerance: the 3-shear is exact only for matrix exp of an
        # idealised L_z; on a 48² grid with σ=1 there's a few-% error
        # from finite resolution.
        expected_plus = exp(+2 * ω * dτ)   # ℓ = +1
        expected_minus = exp(-2 * ω * dτ)   # ℓ = −1
        @test nrm_plus_after / nrm_plus_before ≈ expected_plus rtol=0.05
        @test nrm_minus_after / nrm_minus_before ≈ expected_minus rtol=0.05
    end

    @testset "SimParams rotating_frame_omega" begin
        sp = SimParams(; dt=0.01, n_steps=100, rotating_frame_omega=0.5)
        @test sp.rotating_frame_omega == 0.5

        sp2 = SimParams(0.01, 100, false, 1, 10)
        @test sp2.rotating_frame_omega == 0.0
    end

    @testset "Rotating frame: centrifugal + Zeeman shift in workspace" begin
        config = GridConfig((16, 16), (10.0, 10.0))
        grid = make_grid(config)
        interactions = InteractionParams(Dict(0 => 1.0, 1 => 0.0))
        omega = 0.3

        sp = SimParams(; dt=0.01, n_steps=10, imaginary_time=true,
            rotating_frame_omega=omega)
        ws = make_workspace(; grid, atom=Rb87, interactions, sim_params=sp,
            fft_flags=FFTW.ESTIMATE)

        center_idx = CartesianIndex(8, 8)
        corner_idx = CartesianIndex(1, 1)
        # 2026-04-27 sign fix: centrifugal term is `-(1/2)ω²r_⊥²` subtracted
        # from V (deconfining), not added. With NoPotential as the base,
        # corners now have LOWER potential than centre (was the opposite
        # under the over-confining bug).
        @test ws.potential_values[corner_idx] < ws.potential_values[center_idx]

        # Sign convention (2026-06-02 fix, see
        # mistake_frame_transformation_half_term_silent_cancellation):
        # rotating frame H_rot = H_lab − Ω(L_z + F_z); with Zeeman convention
        # H_Zee = −p·F_z, effective_p = z.p + Ω so that the −Ω·F_z Barnett
        # term is installed when user passes z.p = p_lab. Pre-fix this test
        # asserted `≈ -omega` — which pinned the broken sign that silently
        # cancelled Barnett and let half the rotating-frame term go missing.
        zee = SpinorBEC.zeeman_at(ws.zeeman, 0.0)
        @test zee.p ≈ +omega
    end

    @testset "find_ground_state with rotating_frame_omega" begin
        config = GridConfig((16, 16), (10.0, 10.0))
        grid = make_grid(config)
        interactions = InteractionParams(Dict(0 => 5.0, 1 => 0.0))
        trap = HarmonicTrap(1.0, 1.0)

        r = find_ground_state(; grid, atom=Rb87, interactions, potential=trap,
            dt=0.005, n_steps=200,
            rotating_frame_omega=0.3, fft_flags=FFTW.ESTIMATE)
        @test isfinite(r.energy)
        @test !any(isnan, r.workspace.state.psi)
    end

    @testset "leapfrog RT driver ≡ split_step! loop (cross-path)" begin
        # run_simulation! (leapfrog) must reproduce a plain split_step! loop
        # bit-for-bit: the "always close+reopen, never merge the boundary V"
        # contract (Bug-4 RTP analogue). All inner-V terms active so a dropped
        # or merged substep would show up — c0, c1, transverse Zeeman, Coriolis.
        function build()
            grid = make_grid(GridConfig((16, 16), (8.0, 8.0)))
            zee = TimeDependentZeeman(ConstantWaveform(0.2), ConstantWaveform(0.1),
                ConstantWaveform(0.3), ConstantWaveform(0.0))   # p, q, bx, by
            sp = SimParams(; dt=0.005, n_steps=20, imaginary_time=false,
                rotating_frame_omega=0.3, save_every=20)
            ws = make_workspace(; grid, atom=Rb87,
                interactions=InteractionParams(Dict(0 => 10.0, 1 => -0.5)),
                zeeman=zee, potential=HarmonicTrap((1.0, 1.0)), sim_params=sp,
                fft_flags=FFTW.ESTIMATE)
            copyto!(ws.state.psi,
                init_psi_spin_coherent(grid, SpinSystem(1); theta=π / 3, phi=0.0))
            ws
        end
        ws_a = build()
        run_simulation!(ws_a)
        ws_b = build()
        for _ in 1:20
            split_step!(ws_b)
        end
        @test ws_a.state.psi == ws_b.state.psi                 # bit-identical
        # the dynamics genuinely evolved (not a trivial no-op match)
        @test sqrt(sum(abs2, ws_b.state.psi .- build().state.psi)) > 0.1
    end
end
