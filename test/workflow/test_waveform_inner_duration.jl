# Regression test for the YAML waveform parser's `duration` handling.
#
# Pre-2026-05-25 the parser silently ignored an inner `duration` field
# inside `{from, to, duration}` ramp specs and always used the outer
# dynamics step's duration as the ramp time. The L4 EdH configs all
# wrote `Bz: {from: 0.01, to: 2.6e-5, duration: 0.0}` expecting an
# instantaneous quench; instead they got a full-window linear ramp.
# See memory/gotcha_bz_ramp_duration_ignored.md for the discovery.
#
# Pinned semantics post-fix:
#   {from, to}                       — RampWaveform over outer duration
#   {from, to, duration: T}, T > 0   — RampWaveform over T (clamps after)
#   {from, to, duration: 0|missing≤0}— ConstantWaveform(to)  (instant jump)

using Test
using SpinorBEC
using SpinorBEC: _make_waveform, ConstantWaveform, RampWaveform, evaluate

@testset "YAML ramp inner-duration handling" begin
    @testset "Bare {from, to} uses outer duration" begin
        spec = Dict{Any, Any}("from" => 0.0, "to" => 1.0)
        w = _make_waveform(spec, 0.5)
        @test w isa RampWaveform
        @test evaluate(w, 0.0) == 0.0
        @test evaluate(w, 0.25) == 0.5
        @test evaluate(w, 0.5) == 1.0
    end

    @testset "{from, to, duration: 0.0} = instant jump to `to`" begin
        spec = Dict{Any, Any}("from" => 0.0, "to" => 1.0, "duration" => 0.0)
        w = _make_waveform(spec, 0.5)
        @test w isa ConstantWaveform
        @test evaluate(w, 0.0) == 1.0
        @test evaluate(w, 0.5) == 1.0
        @test evaluate(w, 10.0) == 1.0
    end

    @testset "{from, to, duration: T}, T > 0 honors inner duration" begin
        spec = Dict{Any, Any}("from" => 0.0, "to" => 1.0, "duration" => 0.1)
        w = _make_waveform(spec, 0.5)              # outer step = 0.5
        @test w isa RampWaveform
        @test evaluate(w, 0.05) == 0.5             # halfway through inner ramp
        @test evaluate(w, 0.1) == 1.0              # ramp completes
        @test evaluate(w, 0.3) == 1.0              # clamped after duration
    end

    @testset "Negative inner duration also means instant jump" begin
        spec = Dict{Any, Any}("from" => 0.0, "to" => 1.0, "duration" => -1.0)
        w = _make_waveform(spec, 0.5)
        @test w isa ConstantWaveform
        @test evaluate(w, 0.0) == 1.0
    end
end
