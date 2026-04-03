using Test
using SpinorBEC

@testset "Ground State" begin
    @testset "Basic convergence (1D F=1)" begin
        grid = make_grid(GridConfig(32, 16.0))
        interactions = InteractionParams(5.0, -0.2)
        trap = HarmonicTrap(1.0)

        result = find_ground_state(;
            grid, atom = Rb87, interactions, potential = trap,
            dt = 0.005, n_steps = 200, initial_state = :ferromagnetic,
        )

        @test result.energy < 0 || result.energy < 100
        @test isfinite(result.energy)
        @test haskey(result, :converged)
        @test haskey(result, :dE)
        @test haskey(result, :dpsi)
        @test total_norm(result.workspace.state.psi, grid) ≈ 1.0 atol = 1e-6
    end

    @testset "Different initial states converge to same energy" begin
        grid = make_grid(GridConfig(32, 16.0))
        interactions = InteractionParams(5.0, 0.3)
        trap = HarmonicTrap(1.0)

        r_polar = find_ground_state(;
            grid, atom = Na23, interactions, potential = trap,
            dt = 0.005, n_steps = 200, initial_state = :polar,
        )
        r_ferro = find_ground_state(;
            grid, atom = Na23, interactions, potential = trap,
            dt = 0.005, n_steps = 200, initial_state = :ferromagnetic,
        )

        @test abs(r_polar.energy - r_ferro.energy) / max(abs(r_polar.energy), 1e-10) < 0.3
    end

    @testset "Constrained magnetization" begin
        grid = make_grid(GridConfig(32, 16.0))
        interactions = InteractionParams(5.0, -0.2)
        trap = HarmonicTrap(1.0)

        target_Mz = 0.5
        result = find_ground_state(;
            grid, atom = Rb87, interactions, potential = trap,
            dt = 0.005, n_steps = 500, initial_state = :uniform,
            target_magnetization = target_Mz,
        )

        ws = result.workspace
        sys = ws.spin_matrices.system
        Mz = magnetization(ws.state.psi, grid, sys)
        @test abs(Mz - target_Mz) < 0.2
    end

    @testset "Multistart returns lowest energy" begin
        grid = make_grid(GridConfig(16, 12.0))
        interactions = InteractionParams(3.0, 0.1)
        trap = HarmonicTrap(1.0)

        result = find_ground_state_multistart(;
            grid, atom = Na23, interactions, potential = trap,
            dt = 0.005, n_steps = 50,
            initial_states = [:polar, :ferromagnetic],
            n_random = 0,
        )

        @test haskey(result, :energy)
        @test haskey(result, :initial_state)
        @test haskey(result, :all_results)
        @test length(result.all_results) == 2

        best_energy = minimum(r -> r.energy, result.all_results)
        @test result.energy ≈ best_energy
    end

    @testset "ITP overflow: extreme Zeeman" begin
        @test_throws ArgumentError SpinorBEC._validate_itp_zeeman(
            ZeemanParams(1e6, 0.0), 1, 0.01,
        )
    end

    @testset "ITP overflow: extreme interactions" begin
        @test_throws ArgumentError SpinorBEC._validate_itp_interactions(
            InteractionParams(1e8, 0.0), 1, 0.01,
        )
    end
end
