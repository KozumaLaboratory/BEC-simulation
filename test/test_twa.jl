using Test
using SpinorBEC
using FFTW

@testset "TWA" begin
    F = 1
    D = 2F + 1
    grid = make_grid(GridConfig(16, 10.0))
    atom = Rb87
    V = prod(grid.config.box_size)
    sm = spin_matrices(F)

    # Uniform condensate for testing
    psi_uniform = zeros(ComplexF64, 16, D)
    psi_uniform[:, 1] .= 1.0 / sqrt(grid.config.box_size[1])

    @testset "Noise statistics" begin
        n_samples = 200
        n_pts = grid.config.n_points[1]
        variance_accum = zeros(Float64, n_pts, D)
        plans = make_fft_plans(grid.config.n_points)

        for s in 1:n_samples
            psi_noisy = add_vacuum_noise(psi_uniform, grid, F; seed = s)
            delta = psi_noisy .- psi_uniform
            for c in 1:D
                delta_k = plans.forward * delta[:, c]
                variance_accum[:, c] .+= abs2.(delta_k)
            end
        end
        variance_accum ./= n_samples

        expected_var = 1.0 / (2.0 * V)
        mean_measured_var = sum(variance_accum) / length(variance_accum)
        @test isapprox(mean_measured_var, expected_var; rtol = 0.2)
    end

    @testset "Energy cutoff" begin
        cutoff = 5.0
        psi_noisy = add_vacuum_noise(psi_uniform, grid, F; seed = 1, cutoff_energy = cutoff)
        delta = psi_noisy .- psi_uniform
        plans = make_fft_plans(grid.config.n_points)
        delta_k = plans.forward * delta[:, 1]

        for i in eachindex(delta_k)
            ek = grid.k_squared[i] / 2.0
            if ek > cutoff
                @test abs(delta_k[i]) < 1e-14
            end
        end
    end

    @testset "No renormalization" begin
        psi_noisy = add_vacuum_noise(psi_uniform, grid, F; seed = 42)
        norm_orig = total_norm(psi_uniform, grid)
        norm_noisy = total_norm(psi_noisy, grid)
        @test norm_orig != norm_noisy  # noise changes norm
    end

    @testset "Deterministic seeding" begin
        psi_a = add_vacuum_noise(psi_uniform, grid, F; seed = 123)
        psi_b = add_vacuum_noise(psi_uniform, grid, F; seed = 123)
        @test psi_a ≈ psi_b

        psi_c = add_vacuum_noise(psi_uniform, grid, F; seed = 456)
        @test !(psi_a ≈ psi_c)
    end

    @testset "TWAConfig validation" begin
        @test_throws ArgumentError TWAConfig(0)
        @test_throws ArgumentError TWAConfig(-1)
        cfg = TWAConfig(4, 42, nothing, [:density])
        @test cfg.n_trajectories == 4
        @test cfg.seed_base == 42
    end

    @testset "Serial ensemble" begin
        interactions = InteractionParams(100.0, -0.5)
        sp = SimParams(; dt = 0.01, n_steps = 20, save_every = 10)
        twa_cfg = TWAConfig(3, 42, nothing, [:density, :magnetization])

        gs = find_ground_state(;
            grid, atom, interactions,
            dt = 0.005, n_steps = 200, tol = 1e-6,
        )
        psi_gs = gs.workspace.state.psi

        result = run_twa(;
            psi_gs, grid, atom, interactions,
            zeeman = ZeemanParams(0.0, -0.01),
            potential = HarmonicTrap(1.0),
            sim_params = sp,
            twa_config = twa_cfg,
            verbose = false,
        )

        @test result isa EnsembleResult
        @test result.n_trajectories == 3
        @test length(result.times) > 0
        @test haskey(result.mean, :density)
        @test haskey(result.mean, :magnetization)
        @test haskey(result.var, :density)
        @test length(result.mean[:density]) == length(result.times)
        @test size(result.mean[:density][1]) == (16,)
        @test result.trajectory_results === nothing
    end

    @testset "Store trajectories" begin
        interactions = InteractionParams(100.0, -0.5)
        sp = SimParams(; dt = 0.01, n_steps = 10, save_every = 10)
        twa_cfg = TWAConfig(2, 42, nothing, [:density])

        gs = find_ground_state(;
            grid, atom, interactions,
            dt = 0.005, n_steps = 200, tol = 1e-6,
        )

        result = run_twa(;
            psi_gs = gs.workspace.state.psi, grid, atom, interactions,
            sim_params = sp, twa_config = twa_cfg,
            store_trajectories = true, verbose = false,
        )

        @test result.trajectory_results !== nothing
        @test length(result.trajectory_results) == 2
        @test result.trajectory_results[1] isa SpinorBEC.SimulationResult
    end

    @testset "Ensemble analysis utilities" begin
        a = [ones(4), 2 .* ones(4), 3 .* ones(4)]
        b = [2 .* ones(4), 4 .* ones(4), 6 .* ones(4)]
        corr = ensemble_correlation(a, b)
        mean_a = sum([1.0, 2.0, 3.0]) / 3
        mean_b = sum([2.0, 4.0, 6.0]) / 3
        mean_ab = sum([2.0, 8.0, 18.0]) / 3
        expected = mean_ab - mean_a * mean_b
        @test all(isapprox.(corr, expected; atol = 1e-12))

        var_arr = 4.0 .* ones(4)
        se = ensemble_stderr(var_arr, 100)
        @test all(isapprox.(se, 0.2; atol = 1e-12))
    end

    @testset "Wigner density correction" begin
        density_k = ones(16)
        corrected = wigner_correct_density(density_k, grid; n_components = 3)
        expected = 1.0 - 3.0 / (2.0 * V)
        @test all(isapprox.(corrected, expected; atol = 1e-12))
    end
end
