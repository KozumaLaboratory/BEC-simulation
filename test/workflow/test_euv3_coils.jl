# euv3 lab coil/field calibration: non-orthogonal projection + per-coil G↔V.

using Test
using SpinorBEC
using SpinorBEC: bxpyp,
    coil2_xp_volts, coil2_yp_volts, coil2_z_volts, coil2_q_volts,
    coil2_xp_field, coil2_yp_field, coil2_z_field, coil2_q_grad,
    coil1_z_volts, horizontal_bias_volts

@testset "euv3 coil/field calibration" begin
    @testset "bxpyp non-orthogonal projection" begin
        θxp = -10.0 / 180 * π
        θyp = +98.0 / 180 * π
        # a unit field along an axis projects to (1, 0) / (0, 1) on that axis
        sx, tx = bxpyp(θxp)
        @test sx ≈ 1.0 atol = 1e-12
        @test tx ≈ 0.0 atol = 1e-12
        sy, ty = bxpyp(θyp)
        @test sy ≈ 0.0 atol = 1e-12
        @test ty ≈ 1.0 atol = 1e-12
    end

    @testset "Coil2 G ↔ V invertibility + transcribed constants" begin
        for B in (-3.0, 0.5, 7.0)
            @test coil2_xp_field(coil2_xp_volts(B)) ≈ B rtol = 1e-12
            @test coil2_yp_field(coil2_yp_volts(B)) ≈ B rtol = 1e-12
            @test coil2_z_field(coil2_z_volts(B)) ≈ B rtol = 1e-12
        end
        @test coil2_z_volts(7.0) ≈ 11.0            # 7 G / (7 G/A) × 11 V/A
        @test coil2_q_grad(coil2_q_volts(5.0)) ≈ 5.0 rtol = 1e-12
    end

    @testset "Coil1 Z offset" begin
        # vCoil1Z(bz) = (bz/2.32 - 0.11)/0.291
        @test coil1_z_volts(2.32) ≈ (1.0 - 0.11) / 0.291
    end

    @testset "horizontal_bias_volts reconstructs the field components" begin
        B, θ = 1.5, 35.0 / 180 * π          # 1.5 G at 35° (euv3 test direction)
        Vxp, Vyp = horizontal_bias_volts(B, θ)
        s, t = bxpyp(θ)
        @test coil2_xp_field(Vxp) ≈ B * s rtol = 1e-12
        @test coil2_yp_field(Vyp) ≈ B * t rtol = 1e-12
    end
end
