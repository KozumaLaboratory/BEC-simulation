using Test, SpinorBEC

@testset "recommend_backend_dtype" begin
    @testset "no CUDA → always (cpu, F64)" begin
        for n in (8, 16, 24, 32, 48, 64, 128)
            @test recommend_backend_dtype(n; cuda_functional = false) ===
                  (:cpu, Float64)
            @test recommend_backend_dtype(n; cuda_functional = false, mode = :itp) ===
                  (:cpu, Float64)
            @test recommend_backend_dtype(n; cuda_functional = false, mode = :longtime) ===
                  (:cpu, Float64)
        end
    end

    @testset "small grids stay on CPU even with CUDA" begin
        for n in (1, 8, 16)
            @test recommend_backend_dtype(n; cuda_functional = true) ===
                  (:cpu, Float64)
        end
    end

    @testset "large grids go to GPU; mode controls dtype" begin
        for n in (24, 32, 48, 64, 128)
            @test recommend_backend_dtype(n; cuda_functional = true, mode = :realtime) ===
                  (:cuda, Float32)
            @test recommend_backend_dtype(n; cuda_functional = true, mode = :itp) ===
                  (:cuda, Float64)
            @test recommend_backend_dtype(n; cuda_functional = true, mode = :longtime) ===
                  (:cuda, Float64)
        end
    end

    @testset "argument validation" begin
        @test_throws ArgumentError recommend_backend_dtype(0; cuda_functional = true)
        @test_throws ArgumentError recommend_backend_dtype(-4; cuda_functional = true)
        @test_throws ArgumentError recommend_backend_dtype(32;
            cuda_functional = true, mode = :unknown_mode)
    end
end
