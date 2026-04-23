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

    @testset "ChirpedSinusoidalWaveform: constant-freq limit" begin
        w_flat = ChirpedSinusoidalWaveform(; freq_start=2.0, freq_end=2.0, duration=1.0)
        w_ref = SinusoidalWaveform(; frequency=2.0)
        for t in (0.0, 0.1, 0.37, 0.5, 0.83)
            @test evaluate(w_flat, t) ≈ evaluate(w_ref, t) atol=1e-12
        end
    end

    @testset "ChirpedSinusoidalWaveform: chirp behaviour" begin
        # Use a steeper chirp so multiple oscillations exist in each half:
        # f goes 0 → 10 over duration=1. Phase at t=1 is 2π·5 = 10π → sin = 0.
        w = ChirpedSinusoidalWaveform(; freq_start=0.0, freq_end=10.0, duration=1.0)
        @test evaluate(w, 0.0) ≈ 0.0 atol=1e-12
        @test evaluate(w, 1.0) ≈ 0.0 atol=1e-10

        # Zero-crossing density should increase across the interval (chirp up).
        ts = collect(range(0.0, 1.0; length = 5001))
        vals = [evaluate(w, t) for t in ts]
        half = length(ts) ÷ 2
        count_zero_crossings(vs) = sum((vs[i-1] * vs[i]) < 0 for i in 2:length(vs))
        xings_first = count_zero_crossings(vals[1:half])
        xings_second = count_zero_crossings(vals[half+1:end])
        @test xings_second > xings_first
    end

    @testset "ChirpedSinusoidalWaveform: YAML builder" begin
        spec = Dict{String,Any}("chirped_sinusoidal" => Dict{String,Any}(
            "amplitude" => 2.0, "freq_start" => 0.0, "freq_end" => 10.0,
            "duration" => 0.5,
        ))
        w = SpinorBEC._make_waveform(spec, 1.0)
        @test w isa ChirpedSinusoidalWaveform
        @test w.amplitude == 2.0
        @test w.freq_end == 10.0
        @test w.duration == 0.5
    end
end
