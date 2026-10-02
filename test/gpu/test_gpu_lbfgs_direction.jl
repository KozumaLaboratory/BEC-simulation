using Test, Random, LinearAlgebra
import CUDA
using SpinorBEC

if !CUDA.functional()
    @info "CUDA not functional — skipping L-BFGS direction parity"
else
    @testset "GPU L-BFGS direction preserves the manifold recurrence" begin
        for T in (ComplexF32, ComplexF64), m in (0, 1, 5, 20), dV in (1.0, 0.037)
            rng = MersenneTwister(491 + m)
            grad = randn(rng, T, 7, 9, 3)
            s = [randn(rng, T, size(grad)) for _ in 1:m]
            hessian = real(T)(0.5) .+ rand(rng, real(T), size(grad))
            y = [hessian .* v for v in s]
            rho = Float64[inv(real(dot(a, b)) * dV) for (a, b) in zip(s, y)]
            reference = copy(SpinorBEC._lbfgs_direction(grad, s, y, rho, dV))
            gd = CUDA.CuArray(grad)
            sd, yd = CUDA.CuArray.(s), CUDA.CuArray.(y)
            # Empty typed history vectors must also select the device path.
            sd = typeof(gd)[v for v in sd]
            yd = typeof(gd)[v for v in yd]
            direction = Array(SpinorBEC._lbfgs_direction(gd, sd, yd, rho, dV))
            @test isapprox(direction, reference; rtol=T === ComplexF32 ? 2e-6 : 1e-12)
            @test real(dot(grad, direction)) < 0
            @test Array(gd) == grad
            @test all(Array(sd[i]) == s[i] && Array(yd[i]) == y[i] for i in 1:m)
        end
    end
end
