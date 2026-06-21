using SpinorBEC
using Test

@testset "Sign Pattern Lemma 1 + 2 (Paper #3 §VI)" begin
    @testset "Lemma 1 closed form β_S^(λ_spin) = [S(S+1) − 2F(F+1)] / [2F(F+1)] · β_S^(c_0)" begin
        # F=1: 2F(F+1) = 4.
        # S=0: factor = (0 - 4)/4 = -1
        # S=2: factor = (6 - 4)/4 = +0.5  (S=2 is at the sign boundary S_bd = √4 = 2)
        @test sign_pattern_beta_lambda_spin(0, 1, 1.0) ≈ -1.0
        @test sign_pattern_beta_lambda_spin(2, 1, 1.0) ≈ +0.5

        # F=6: 2F(F+1) = 84
        for (S, expected) in [
            (0, -84/84),     # S(S+1) - 84 = -84
            (2, -78/84),     # 6 - 84
            (4, -64/84),     # 20 - 84
            (6, -42/84),     # 42 - 84
            (8, -12/84),     # 72 - 84
            (10, 26/84),     # 110 - 84
            (12, 72/84),     # 156 - 84
        ]
            @test sign_pattern_beta_lambda_spin(S, 6, 1.0) ≈ expected
        end
    end

    @testset "Lemma 1 — input validation" begin
        @test_throws ArgumentError sign_pattern_beta_lambda_spin(0, 0, 1.0)
        @test_throws ArgumentError sign_pattern_beta_lambda_spin(-2, 6, 1.0)
        @test_throws ArgumentError sign_pattern_beta_lambda_spin(13, 6, 1.0)
        @test_throws ArgumentError sign_pattern_beta_lambda_spin(3, 6, 1.0)  # odd S
    end

    @testset "Lemma 2 sign-change boundary S_bd(F) = √(2F(F+1))" begin
        @test sign_change_boundary_S_bd(1) ≈ sqrt(4)    # = 2
        @test sign_change_boundary_S_bd(6) ≈ sqrt(84)   # ≈ 9.165
        @test sign_change_boundary_S_bd(10) ≈ sqrt(220) # ≈ 14.83
        # Approximation √2·F at large F
        for F in (10, 20, 50, 100)
            @test isapprox(sign_change_boundary_S_bd(F) / (sqrt(2) * F), 1.0; atol=0.1)
        end
    end

    @testset "Sign prediction: negative below S_bd, positive above" begin
        # F=6: S_bd = √84 ≈ 9.16 → integer threshold between S=8 and S=10
        for S in (0, 2, 4, 6, 8)
            @test predict_lambda_spin_sign(6, S) === :negative
        end
        for S in (10, 12)
            @test predict_lambda_spin_sign(6, S) === :positive
        end
        # F=10: S_bd = √220 ≈ 14.83 → threshold between S=14 and S=16
        @test predict_lambda_spin_sign(10, 14) === :negative
        @test predict_lambda_spin_sign(10, 16) === :positive
    end

    @testset "Table generator over all even S ∈ 0..2F" begin
        F = 4
        beta_c0 = Dict(0 => 0.1, 2 => 0.2, 4 => 0.3, 6 => 0.15, 8 => 0.25)
        tbl = sign_pattern_beta_lambda_spin_table(F, beta_c0)
        @test sort(collect(keys(tbl))) == [0, 2, 4, 6, 8]
        for S in keys(tbl)
            @test isapprox(tbl[S], sign_pattern_beta_lambda_spin(S, F, beta_c0[S]); rtol=1e-12)
        end
        # Missing channels default to 0
        beta_partial = Dict(0 => 1.0)
        tbl2 = sign_pattern_beta_lambda_spin_table(F, beta_partial)
        @test tbl2[2] == 0.0  # β_2^(c_0) absent → β_2^(λ_spin) = 0
    end

    @testset "polyhedral_op_character — F=3 O:A_2 sign-rep diagnostic" begin
        # F=3 O:A_2 state (Paper #3 §V.B): ζ = (|3,+2⟩ - |3,-2⟩)/√2.
        # Under C_4z: |m⟩ → e^{-imπ/2}|m⟩, m=±2 picks up e^{∓iπ} = -1.
        # So ζ → -1·(|+2⟩ - |-2⟩)/√2 = -ζ. Character ⟨ζ|U|ζ⟩ = -1.
        zeta_A2 = ComplexF64[0, 1, 0, 0, 0, -1, 0] ./ sqrt(2)
        chi_C4z = polyhedral_op_character(zeta_A2, 3; axis=(0.0, 0.0, 1.0), angle=π/2)
        @test isapprox(real(chi_C4z), -1.0; atol=1e-10)
        @test isapprox(imag(chi_C4z), 0.0; atol=1e-10)
    end

    @testset "polyhedral_op_character — F=6 I_h state under C_5z" begin
        # F=6 I_h state: ζ = √7/5|+5⟩ + √11/5|0⟩ - √7/5|-5⟩
        # Under C_5z (axis=z, angle=2π/5): |m⟩ → e^{-i 2πm/5} |m⟩
        # m=±5 picks up e^{∓i 2π} = +1; m=0 picks up +1.
        # So ζ is invariant under C_5z → character +1.
        zeta_Ih = Vector{ComplexF64}(SpinorBEC.ZETA_F6_IH)
        chi = polyhedral_op_character(zeta_Ih, 6; axis=(0.0, 0.0, 1.0), angle=2π/5)
        @test isapprox(real(chi), 1.0; atol=1e-10)
        @test isapprox(imag(chi), 0.0; atol=1e-10)
    end

    @testset "polyhedral_op_character — input validation" begin
        zeta = ComplexF64[1.0, 0.0, 0.0]
        @test_throws DimensionMismatch polyhedral_op_character(zeta, 6; angle=0.0)
        @test_throws ArgumentError polyhedral_op_character(zeta, 1;
            axis=(0.0, 0.0, 0.0), angle=π)
    end

    @testset "Cross-verify against IcosahedralMod F=6 I_h closed form (Paper #3 §V.D)" begin
        # Paper #3 §V.D / sign_pattern_lemma1_general_S.md verifies the Lemma 1
        # closed form against IcosahedralMod's c_0 and λ_spin coefficients
        # at S = 0, 6, 10, 12. Verify the IcosahedralMod tables match the
        # Sign Pattern Lemma 1 formula applied to the I_h state's β_S^(c_0).
        #
        # The I_h state has β_S^(c_0) populated only at S ∈ {0, 6, 10, 12}
        # (other even S vanish under I_h harmonic decomposition).
        # IcosahedralMod's coefficients give c_0 and λ_spin directly; we can
        # extract β_S^(c_0) and β_S^(λ_spin) ratios.
        #
        # Per IcosahedralMod (paper #3 derivation):
        #   c_0       = g_0/13 + 121 g_6/323 + 147 g_10/391 + 980 g_12/5681
        #   λ_spin    = -g_0/13 - 121 g_6/646 + 91 g_10/782 + 840 g_12/5681
        #
        # Extract β_S^(c_0) = (coefficient of g_S in c_0):
        beta_c0_F6 = Dict(0 => 1/13, 6 => 121/323, 10 => 147/391, 12 => 980/5681)
        # Expected β_S^(λ_spin) from Sign Pattern Lemma 1:
        # F=6, 2F(F+1) = 84.
        expected_lambda = Dict(
            S => sign_pattern_beta_lambda_spin(S, 6, beta_c0_F6[S])
            for S in keys(beta_c0_F6)
        )
        # IcosahedralMod's β_S^(λ_spin) (extracted from λ_spin formula):
        actual_lambda = Dict(0 => -1/13, 6 => -121/646, 10 => 91/782, 12 => 840/5681)
        for S in keys(expected_lambda)
            @test isapprox(expected_lambda[S], actual_lambda[S]; rtol=1e-12)
        end
    end
end
