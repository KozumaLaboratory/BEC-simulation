# Compare the generic host-scalar recurrence with the production GPU dispatch.
# The abstract first argument in invoke deliberately bypasses the GPU method.
import CUDA
using SpinorBEC, LinearAlgebra, Printf, Test
CUDA.allowscalar(false)

function run_case(n, m, T)
    CUDA.seed!(123)
    shape = (n, n, n, 13)
    grad = CUDA.randn(T, shape...)
    s = [CUDA.randn(T, shape...) for _ in 1:m]
    h = real(T)(0.5) .+ CUDA.rand(real(T), shape...)
    y = [h .* v for v in s]
    dV = 0.037
    rho = Float64[inv(real(dot(vec(a), vec(b))) * dV) for (a, b) in zip(s, y)]
    before() = invoke(SpinorBEC._lbfgs_direction,
        Tuple{AbstractArray{T}, typeof(s), typeof(y), typeof(rho), Float64},
        grad, s, y, rho, dV)
    after() = SpinorBEC._lbfgs_direction(grad, s, y, rho, dV)
    reference = copy(before())
    candidate = after()
    error = norm(vec(reference .- candidate)) / norm(vec(reference))
    @test error < (T == ComplexF64 ? 1e-12 : 1e-5)
    for _ in 1:3
        before();
        after()
    end
    times = (Float64[], Float64[])
    for repetition in 1:12
        for arm in (isodd(repetition) ? (1, 2) : (2, 1))
            CUDA.synchronize()
            t0 = time_ns()
            arm == 1 ? before() : after()
            CUDA.synchronize()
            push!(times[arm], (time_ns() - t0) / 1e6)
        end
    end
    medians = map(times) do x
        z = sort(x)
        (z[6] + z[7]) / 2
    end
    @printf(
        "DEVICE_SCALARS n=%d m=%d type=%s error=%.3e before_ms=%.6f after_ms=%.6f speedup=%.3f\n",
        n, m, T, error, medians[1], medians[2], medians[1] / medians[2])
    flush(stdout)
end

@assert CUDA.functional()
println("device=", CUDA.name(CUDA.device()), " Julia=", VERSION)
@testset "device-resident L-BFGS scalars" begin
    for T in (ComplexF64, ComplexF32), n in (8, 32, 64), m in (0, 1, 20)
        run_case(n, m, T)
        GC.gc(true)
        CUDA.reclaim()
    end
end
