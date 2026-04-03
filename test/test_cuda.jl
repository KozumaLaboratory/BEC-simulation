using SpinorBEC
using Test

@testset "CUDA Backend (gated)" begin
    cuda_available = try
        import CUDA
        CUDA.functional()
    catch
        false
    end

    if !cuda_available
        @info "CUDA not available, skipping GPU tests"
        @test true  # placeholder
        return
    end

    @testset "CUDABackend type" begin
        backend = CUDABackend()
        @test backend isa SpinorBEC.AbstractBackend
    end

    @testset "Workspace creation on GPU" begin
        grid = make_grid(GridConfig((16,), (10.0,)))
        atom = Rb87
        interactions = compute_interaction_params(atom)
        sp = SimParams(; dt=0.001, n_steps=10, imaginary_time=true)

        ws = make_workspace(;
            grid, atom, interactions, sim_params=sp,
            backend=CUDABackend(),
        )

        @test ws.state.psi isa CuArray
        @test ws.backend isa CUDABackend
    end

    @testset "Kinetic step on GPU" begin
        grid = make_grid(GridConfig((16,), (10.0,)))
        atom = Rb87
        interactions = compute_interaction_params(atom)
        sp = SimParams(; dt=0.001, n_steps=1, imaginary_time=false)

        ws = make_workspace(;
            grid, atom, interactions, sim_params=sp,
            backend=CUDABackend(),
        )

        psi_before = Array(ws.state.psi)
        norm_before = sum(abs2, psi_before) * cell_volume(grid)

        split_step!(ws)

        psi_after = Array(ws.state.psi)
        norm_after = sum(abs2, psi_after) * cell_volume(grid)

        @test norm_after ≈ norm_before rtol=1e-10
    end

    @testset "Ground state on GPU matches CPU" begin
        grid = make_grid(GridConfig((16,), (10.0,)))
        atom = Rb87
        interactions = compute_interaction_params(atom)

        r_cpu = find_ground_state(;
            grid, atom, interactions,
            potential=HarmonicTrap(1.0),
            n_steps=200, dt=0.01,
        )

        r_gpu = find_ground_state(;
            grid, atom, interactions,
            potential=HarmonicTrap(1.0),
            n_steps=200, dt=0.01,
            backend=CUDABackend(),
        )

        @test r_gpu.energy ≈ r_cpu.energy rtol=1e-6
    end
end
