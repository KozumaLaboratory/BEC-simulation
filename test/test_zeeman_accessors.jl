using Test
using SpinorBEC
using SpinorBEC: ConstantWaveform, RampWaveform

@testset "Zeeman uniform accessors" begin
    @testset "ZeemanParams (constant)" begin
        z = ZeemanParams(2.5, 0.3)
        @test linear_p(z) ≈ 2.5
        @test linear_p(z, 0.0) ≈ 2.5
        @test linear_p(z, 100.0) ≈ 2.5      # time-invariant
        @test quadratic_q(z) ≈ 0.3
        @test transverse_b(z) == (0.0, 0.0)
        @test transverse_b(z, 5.0) == (0.0, 0.0)
    end

    @testset "TimeDependentZeeman (waveforms)" begin
        p_wf = RampWaveform(10.0, 1.0, 5.0, :linear)   # 10 → 1 over 5 ω⁻¹
        q_wf = ConstantWaveform(0.05)
        z = TimeDependentZeeman(p_wf, q_wf)

        @test linear_p(z, 0.0) ≈ 10.0
        @test linear_p(z, 5.0) ≈ 1.0
        @test linear_p(z, 2.5) ≈ 5.5         # mid-ramp
        @test quadratic_q(z, 0.0) ≈ 0.05
        @test quadratic_q(z, 100.0) ≈ 0.05
        @test transverse_b(z) == (0.0, 0.0)  # bx_wf, by_wf default to nothing
    end

    @testset "TimeDependentZeeman with transverse field" begin
        p_wf = ConstantWaveform(1.0)
        q_wf = ConstantWaveform(0.0)
        bx_wf = RampWaveform(0.0, 0.4, 1.0, :linear)
        by_wf = ConstantWaveform(0.2)
        z = TimeDependentZeeman(p_wf, q_wf, bx_wf, by_wf)

        @test transverse_b(z, 0.0) == (0.0, 0.2)
        @test transverse_b(z, 1.0) == (0.4, 0.2)
        @test transverse_b(z, 0.5) == (0.2, 0.2)
    end
end
