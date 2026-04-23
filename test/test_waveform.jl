using Test
using SpinorBEC

@testset "Waveform" begin
    @testset "ConstantWaveform" begin
        w = ConstantWaveform(3.14)
        @test evaluate(w, 0.0) == 3.14
        @test evaluate(w, 1.0) == 3.14
        @test evaluate(w, 100.0) == 3.14
    end

    @testset "RampWaveform boundaries" begin
        for scale in (:linear, :log, :sqrt, :cosine, :exponential, :reverse_sqrt)
            w = RampWaveform(10.0, 20.0, 1.0, scale)
            @test evaluate(w, 0.0) ≈ 10.0 atol = 1e-12
            @test evaluate(w, 1.0) ≈ 20.0 atol = 1e-12
        end
    end

    @testset "RampWaveform midpoint sanity" begin
        for scale in (:linear, :log, :sqrt, :cosine, :exponential, :reverse_sqrt)
            w = RampWaveform(0.0, 1.0, 1.0, scale)
            mid = evaluate(w, 0.5)
            @test 0.0 < mid < 1.0
        end
    end

    @testset "RampWaveform linear" begin
        w = RampWaveform(0.0, 10.0, 2.0, :linear)
        @test evaluate(w, 1.0) ≈ 5.0
        @test evaluate(w, 0.5) ≈ 2.5
    end

    @testset "RampWaveform clamping" begin
        w = RampWaveform(0.0, 10.0, 1.0, :linear)
        @test evaluate(w, -0.5) ≈ 0.0
        @test evaluate(w, 2.0) ≈ 10.0
    end

    @testset "RampWaveform zero duration" begin
        w = RampWaveform(5.0, 10.0, 0.0, :linear)
        @test evaluate(w, 0.0) == 5.0
    end

    @testset "PiecewiseLinearWaveform" begin
        w = PiecewiseLinearWaveform([0.0, 1.0, 3.0], [0.0, 10.0, 10.0])
        @test evaluate(w, 0.0) ≈ 0.0
        @test evaluate(w, 0.5) ≈ 5.0
        @test evaluate(w, 1.0) ≈ 10.0
        @test evaluate(w, 2.0) ≈ 10.0
        @test evaluate(w, 3.0) ≈ 10.0
    end

    @testset "PiecewiseLinearWaveform edge clamping" begin
        w = PiecewiseLinearWaveform([1.0, 2.0], [5.0, 15.0])
        @test evaluate(w, 0.0) ≈ 5.0
        @test evaluate(w, 3.0) ≈ 15.0
    end

    @testset "PiecewiseLinearWaveform validation" begin
        @test_throws ArgumentError PiecewiseLinearWaveform([1.0], [1.0])
        @test_throws ArgumentError PiecewiseLinearWaveform([2.0, 1.0], [1.0, 2.0])
        @test_throws ArgumentError PiecewiseLinearWaveform(Float64[], Float64[])
    end

    @testset "FunctionWaveform" begin
        w = FunctionWaveform(t -> t^2)
        @test evaluate(w, 0.0) ≈ 0.0
        @test evaluate(w, 2.0) ≈ 4.0
        @test evaluate(w, 3.0) ≈ 9.0
    end

    @testset "Scale functions monotonic" begin
        for scale in (:linear, :log, :sqrt, :cosine, :exponential, :reverse_sqrt)
            w = RampWaveform(0.0, 1.0, 1.0, scale)
            ts = range(0.0, 1.0; length = 50)
            vals = [evaluate(w, t) for t in ts]
            @test issorted(vals)
        end
    end
end
