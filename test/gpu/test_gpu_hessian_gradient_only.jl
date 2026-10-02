using Test, Random, FFTW
import CUDA
using SpinorBEC

if !CUDA.functional()
    @info "CUDA not functional — skipping Hessian gradient-only parity"
else
    @testset "GPU gradient-only Hessian matches CPU and preserves homogeneity" begin
        CUDA.allowscalar(false)
        for (F, atom) in ((1, Rb87), (6, Eu151)), padded in (false, true), omega in (0.0, 0.4)
            grid = make_grid(GridConfig((4, 6, 8), (5.0, 6.0, 7.0)))
            rng = MersenneTwister(827 + F)
            psi = randn(rng, ComplexF64, 4, 6, 8, 2F + 1)
            psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
            delta = randn(rng, ComplexF64, size(psi))
            delta ./= sqrt(sum(abs2, delta))
            build(backend) = make_workspace(; grid, atom, backend, psi_init=psi,
                interactions=InteractionParams(Dict(0 => 5.0, 1 => 0.3)),
                zeeman=ZeemanParams(0.7, 0.2), potential=HarmonicTrap((0.7, 1.1, 1.7)),
                sim_params=SimParams(; dt=1e-4, n_steps=1, rotating_frame_omega=omega),
                enable_ddi=true, c_dd=1.0, ddi_padding=padded, fft_flags=FFTW.ESTIMATE)
            cpu, gpu = build(CPUBackend()), build(CUDABackend())
            pd, dd = CUDA.CuArray(psi), CUDA.CuArray(delta)
            reference = hessian_vector_product(cpu, psi, delta; ε=6e-4, order=4)
            actual = hessian_vector_product(gpu, pd, dd; ε=6e-4, order=4)
            @test isapprox(Array(actual), reference; rtol=1e-9, atol=1e-10)
            tiny = hessian_vector_product(gpu, pd, 1e-9 .* dd; ε=6e-4, order=4)
            @test isapprox(Array(tiny) ./ 1e-9, reference; rtol=1e-9, atol=1e-10)
            @test Array(pd) == psi
            prm_cpu = constrained_hessian_params(cpu, psi)
            prm_gpu = constrained_hessian_params(gpu, pd)
            @test isapprox(prm_gpu.μ, prm_cpu.μ; rtol=1e-11)
            @test isapprox(Array(prm_gpu.g), prm_cpu.g; rtol=1e-11, atol=1e-12)
        end
    end
end
