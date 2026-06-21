# Feshbach a_s(B) model + ramp builder, incl. the ¹⁵¹Eu 1.32 G resonance.

using Test
using SpinorBEC
using SpinorBEC: feshbach_scattering_length, eu_feshbach_resonance, eu_feshbach_ramp,
    feshbach_ramp, feshbach_c0_wf, PiecewiseLinearWaveform

@testset "Feshbach a_s(B) + ramp" begin
    @testset "feshbach_scattering_length a_s(B)" begin
        a_bg, Δ, B0 = 110.0, 0.010, 1.32
        f(B) = feshbach_scattering_length(B; a_bg=a_bg, Delta=Δ, B0=B0)
        @test f(5.0) ≈ a_bg * (1 - Δ / (5.0 - B0))     # far field ≈ a_bg
        @test f(2.0) < a_bg && f(2.0) > 0              # background regime above pole
        @test f(B0 + Δ) ≈ 0.0 atol = 1e-9              # zero crossing at B0 + Δ
        @test f(B0 + 1e-5) < -1e4                      # diverges −∞ just ABOVE pole
        @test f(B0 - 1e-5) > 1e4                       # diverges +∞ just BELOW pole
        @test sign(f(B0 + 1e-4)) != sign(f(B0 - 1e-4)) # sign flip across the pole
    end

    @testset "eu_feshbach_resonance parameters" begin
        r = eu_feshbach_resonance()
        @test r.B0 == 1.32
        @test r.Delta == 0.010
        @test r.a_bg == 110.0
    end

    @testset "eu_feshbach_ramp into the collapse window" begin
        # ramp 1.4 → 1.325 G crosses the zero (B0+Δ = 1.33) into the a_s<0 window
        # (1.32 < B < 1.33) — attractive contact → collapse — without hitting the pole.
        c0_wf, as_wf, B_wf = eu_feshbach_ramp(; B_start=1.4, B_end=1.325, duration=0.05)
        @test B_wf.values[1] ≈ 1.4 && B_wf.values[end] ≈ 1.325
        @test as_wf.values[1] > 0                      # 1.4 G > B0+Δ ⇒ a_s > 0
        @test as_wf.values[end] < 0                    # 1.325 G in (B0, B0+Δ) ⇒ a_s < 0
        @test any(<(0), as_wf.values) && any(>(0), as_wf.values)
        @test c0_wf isa PiecewiseLinearWaveform
    end

    @testset "feshbach_ramp generic: c0 = c_scale·a_s, ramp shapes" begin
        c0, as_, B = feshbach_ramp(; a_bg=100.0, Delta=0.02, B0=2.0,
            B_start=2.5, B_end=2.2, duration=0.1, c_scale=3.0)
        @test c0.values ≈ 3.0 .* as_.values            # c_scale mapping
        @test B.values[1] ≈ 2.5 && B.values[end] ≈ 2.2
        @test issorted(B.times)
        @test feshbach_c0_wf(; a_bg=100.0, Delta=0.02, B0=2.0,
            B_start=2.5, B_end=2.2, duration=0.1, c_scale=3.0).values ≈ c0.values
        @test_throws ArgumentError feshbach_ramp(; a_bg=1.0, Delta=1.0, B0=1.0,
            B_start=2.0, B_end=1.5, duration=-1.0)
    end
end
