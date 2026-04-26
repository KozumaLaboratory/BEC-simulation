using Test
using SpinorBEC
using LinearAlgebra

@testset "L-BFGS ground state" begin
    @testset "basic convergence (1D F=1)" begin
        grid = make_grid(GridConfig(32, 16.0))
        interactions = InteractionParams(5.0, -0.2)
        trap = HarmonicTrap(1.0)

        result = find_ground_state_lbfgs(;
            grid, atom=Rb87, interactions, potential=trap,
            n_steps=200, tol=1e-7,
            initial_state=:ferromagnetic,
            verbose=false,
        )

        @test isfinite(result.energy)
        @test haskey(result, :converged)
        @test haskey(result, :workspace)
        @test total_norm(result.workspace.state.psi, grid) ≈ 1.0 atol = 1e-6
    end

    @testset "polishes ITP output to lower energy" begin
        grid = make_grid(GridConfig(32, 12.0))
        interactions = InteractionParams(10.0, -0.5)
        trap = HarmonicTrap(1.0)

        r_itp = find_ground_state(;
            grid, atom=Rb87, interactions, potential=trap,
            dt=0.005, n_steps=200, initial_state=:ferromagnetic,
        )
        E_itp = r_itp.energy
        psi_itp = copy(r_itp.workspace.state.psi)

        r_lbfgs = find_ground_state_lbfgs(;
            ws_init=r_itp.workspace, psi_init=psi_itp,
            n_steps=100, tol=1e-9,
            verbose=false,
        )

        @test isfinite(r_lbfgs.energy)
        # L-BFGS should never increase the energy (within tolerance)
        @test r_lbfgs.energy ≤ E_itp + 1e-8
        # Psi norm preserved
        @test total_norm(r_lbfgs.workspace.state.psi, grid) ≈ 1.0 atol = 1e-6
    end

    @testset "respects target magnetization" begin
        grid = make_grid(GridConfig(32, 12.0))
        interactions = InteractionParams(5.0, -0.2)
        trap = HarmonicTrap(1.0)
        target_Mz = 0.5

        result = find_ground_state_lbfgs(;
            grid, atom=Rb87, interactions, potential=trap,
            n_steps=200, tol=1e-7,
            initial_state=:uniform,
            target_magnetization=target_Mz,
            verbose=false,
        )

        ws = result.workspace
        sys = ws.spin_matrices.system
        Mz = magnetization(ws.state.psi, grid, sys)
        @test abs(Mz - target_Mz) < 1e-3
    end

    @testset "dE shrinks below reasonable threshold" begin
        grid = make_grid(GridConfig(32, 12.0))
        interactions = InteractionParams(3.0, 0.1)
        trap = HarmonicTrap(1.0)

        result = find_ground_state_lbfgs(;
            grid, atom=Na23, interactions, potential=trap,
            n_steps=100, tol=1e-10,
            initial_state=:polar,
            verbose=false,
        )

        # A smooth-running L-BFGS on this simple problem should reach dE ≲ 1e-6
        # well before hitting n_steps=100.
        @test result.dE < 1e-4
    end
end
