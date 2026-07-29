using SpinorBEC
using Test
using Random
using LinearAlgebra

# GPU=CPU parity for the SPGPE energy-damping (scattering) kernel — validation
# ladder Level 0 for the new term.
#
# Why this specific test: the kernel builds THREE host-resident k-space arrays
# (`ws.grid.k_squared` for the Laplacian, `1/|k|` for the non-local kernel, and
# its square root for the noise colouring) and broadcasts them against device
# buffers. That is exactly the shape of the bug `test_projected_gp_parity.jl`
# was written for — a host `Array` broadcast against a `CuArray` either fails to
# compile or, worse, silently takes a different path.
#
# Only the QUIET (`noise=false`) step can be compared: the stochastic term draws
# from CURAND on GPU and from the host RNG on CPU by design, so the noisy step is
# not bit-comparable and its correctness is gated statistically elsewhere.

function _flow_state(grid, D; k0=0.5, curv=0.08, w=1.5)
    psi = zeros(ComplexF64, grid.config.n_points..., D)
    for I in CartesianIndices(grid.config.n_points)
        x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
        r2 = x^2 + y^2 + z^2
        psi[I, D] = exp(-r2 / (2w^2)) * cis(k0 * x + curv * r2)
    end
    psi
end

@testset "SPGPE energy damping — GPU/CPU parity (gated)" begin
    cuda_available = try
        import CUDA
        CUDA.functional()
    catch
        false
    end

    if !cuda_available
        @info "CUDA not available, skipping SPGPE GPU/CPU parity"
        @test true
        return nothing
    end

    grid = make_grid(GridConfig((24, 24, 24), (18.0, 18.0, 18.0)))
    atom = Rb87
    interactions = InteractionParams(Dict{Int, Float64}(0 => 20.0))
    sp = SimParams(; dt=0.002, n_steps=1, imaginary_time=false, normalize_every=0)
    D = SpinorBEC.SpinSystem(atom.F).n_components
    psi0 = _flow_state(grid, D)

    ws_cpu = make_workspace(; grid, atom, interactions, sim_params=sp,
        potential=HarmonicTrap{3}((1.0, 1.0, 1.0)), backend=CPUBackend())
    ws_gpu = make_workspace(; grid, atom, interactions, sim_params=sp,
        potential=HarmonicTrap{3}((1.0, 1.0, 1.0)), backend=CUDABackend())
    copyto!(ws_cpu.state.psi, psi0)
    copyto!(ws_gpu.state.psi, psi0)

    for _ in 1:5
        apply_energy_damping_step!(ws_cpu, 2e-2, 0.0, 0.01; noise=false)
        apply_energy_damping_step!(ws_gpu, 2e-2, 0.0, 0.01; noise=false)
    end

    a, b = Array(ws_cpu.state.psi), Array(ws_gpu.state.psi)
    scale = maximum(abs, psi0)
    @test maximum(abs, a .- b) < 1e-11 * scale
    # …and the step was not a no-op on either backend.
    @test maximum(abs, a .- psi0) > 1e-8 * scale

    @testset "quiet full SPGPE step agrees too" begin
        res = SPGPEReservoir(; T=0.0, mu=5.0, a_s=0.01, k_cut=4.0, gamma=0.05, M=2e-2)
        copyto!(ws_cpu.state.psi, psi0)
        copyto!(ws_gpu.state.psi, psi0)
        for _ in 1:5
            apply_spgpe_step!(ws_cpu, res, 0.002; t=0.0, noise=false)
            apply_spgpe_step!(ws_gpu, res, 0.002; t=0.0, noise=false)
        end
        @test maximum(abs, Array(ws_cpu.state.psi) .- Array(ws_gpu.state.psi)) <
            1e-10 * scale
    end

    @testset "device noise has the right variance" begin
        # The GPU path draws from CURAND rather than the host RNG, so its
        # amplitude cannot be checked by comparison — check it against the FDR
        # target directly: one number-damping noise injection into an empty
        # field must deposit ⟨∫|ψ|²⟩ = 2γT·dt·(number of modes)/dV · dV.
        γ, T, dt = 0.05, 2.0, 0.01
        n_pts = grid.config.n_points
        expected = 2 * γ * T * dt * prod(n_pts) * D
        for ws in (ws_cpu, ws_gpu)
            fill!(ws.state.psi, 0)
            SpinorBEC._sgpe_add_noise!(ws, γ, T, dt; seed=17)
            got = real(sum(abs2, ws.state.psi)) * cell_volume(grid)
            @test isapprox(got, expected; rtol=0.05)
        end
    end
end
