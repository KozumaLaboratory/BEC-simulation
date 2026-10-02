using Test, Random
import CUDA
using SpinorBEC
using FFTW

if !CUDA.functional()
    @info "CUDA not functional — skipping energy reduction shape parity"
else
    @testset "GPU energy reductions preserve broadcast and padded axes" begin
        for T in (Float32, Float64), padded in (false, true)
            shape = (8, 6, 10)
            grid = make_grid(GridConfig(shape, (7.0, 8.0, 9.0)); dtype=T)
            psi = randn(MersenneTwister(416), Complex{T}, shape..., 13)
            psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
            build(backend) = make_workspace(; grid, atom=Eu151, backend,
                psi_init=psi, interactions=InteractionParams(Dict(0 => 5.0, 1 => 0.3)),
                zeeman=ZeemanParams(0.7, 0.2),
                potential=HarmonicTrap((0.7, 1.1, 1.7)),
                sim_params=SimParams(; dt=1e-4, n_steps=1),
                enable_ddi=true, c_dd=1.0, ddi_padding=padded,
                fft_flags=FFTW.ESTIMATE)
            cpu, gpu = build(CPUBackend()), build(CUDABackend())
            reference = energy_decomposition(cpu)
            actual = energy_decomposition(gpu)
            rtol, atol = T === Float32 ? (2e-5, 2e-6) : (1e-10, 1e-12)
            for field in (:kinetic, :trap, :zeeman, :density, :spin, :ddi, :total)
                expected = getproperty(reference, field)
                @test abs(expected) > 1e-9
                @test isapprox(getproperty(actual, field), expected; rtol, atol)
            end
            gh, gd = similar(cpu.state.psi), similar(gpu.state.psi)
            # Independent CPU energy and operator traversals also exercise the
            # F32 reference without its Float64-only fused energy entry point.
            SpinorBEC.gradient_only!(gh, psi, cpu)
            ed = SpinorBEC.energy_gradient!(gd, psi, gpu)
            @test isapprox(ed, reference.total; rtol, atol)
            @test isapprox(Array(gd), gh; rtol, atol)
            SpinorBEC.gradient_only!(gd, psi, gpu)
            @test isapprox(Array(gd), gh; rtol, atol)
        end
    end
end
