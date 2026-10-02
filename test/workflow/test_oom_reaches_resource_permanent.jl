using Test
using SpinorBEC
using SpinorBEC: _is_oom_error

# Detect host and GPU OOM exceptions without referencing CUDA types from core.
# The pipeline persists this distinction in its exit summary.

@testset "GPU OOM detection without a CUDA dependency" begin
    @testset "`_is_oom_error` sees the GPU type without depending on CUDA" begin
        @test _is_oom_error(OutOfMemoryError())
        @test _is_oom_error(ErrorException("CUDA error: out of memory"))
        @test !_is_oom_error(BoundsError())
        @test !_is_oom_error(InterruptException())
        # a stand-in with the same type NAME, which is how the real one is matched
        @eval struct OutOfGPUMemoryError <: Exception end
        @test _is_oom_error(OutOfGPUMemoryError())
    end
end
