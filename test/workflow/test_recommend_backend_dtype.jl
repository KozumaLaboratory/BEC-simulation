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

    @testset "1D/2D stay on CPU regardless of size" begin
        for n in (32, 64, 128, 256), nd in (1, 2)
            @test recommend_backend_dtype(n; cuda_functional = true, ndim = nd) ===
                  (:cpu, Float64)
        end
    end

    @testset "large 3D grids go to GPU; mode controls dtype" begin
        for n in (24, 32, 48, 64, 128)
            @test recommend_backend_dtype(n; cuda_functional = true, ndim = 3, mode = :realtime) ===
                  (:cuda, Float32)
            @test recommend_backend_dtype(n; cuda_functional = true, ndim = 3, mode = :itp) ===
                  (:cuda, Float64)
            @test recommend_backend_dtype(n; cuda_functional = true, ndim = 3, mode = :longtime) ===
                  (:cuda, Float64)
        end
    end

    @testset "argument validation" begin
        @test_throws ArgumentError recommend_backend_dtype(0; cuda_functional = true)
        @test_throws ArgumentError recommend_backend_dtype(-4; cuda_functional = true)
        @test_throws ArgumentError recommend_backend_dtype(32;
            cuda_functional = true, mode = :unknown_mode)
        @test_throws ArgumentError recommend_backend_dtype(32;
            cuda_functional = true, ndim = 4)
    end
end
