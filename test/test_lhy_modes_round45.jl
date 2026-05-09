# Tests for src/hamiltonian/interactions/lhy_modes_round45.jl —
# standalone LHY closed forms for the Round-4/Round-5 polyhedral
# phase verifications.

using Test
using SpinorBEC.LHYModesRound45

@testset "LHY modes (Round 4-5 closed forms)" begin
    # Universal scalar prefactor at M = ℏ = 1
    P_scalar = 8.0 / (15.0 * π^2)

    @testset "F=2 BN scalar limit (g_S ≡ g)" begin
        for g in (0.5, 1.0, 2.0, 10.0)
            n = 1.0
            ε = lhy_F2_BN(g, g, g, n, 1.0)
            # c_0 = g, λ_z = 0, λ_⊥ = 0  ⇒  ε = (8/15π²) (g·n)^(5/2)
            @test isapprox(ε, P_scalar * (g * n)^2.5; rtol=1e-12)
        end
    end

    @testset "F=2 BN coefficient sum identities" begin
        # c_0 sum:  1/5 + 2/7 + 18/35 = 35/35 = 1
        # λ_z sum: -1/5 - 2/7 + 17/35 =  0/35 = 0
        # λ_⊥ sum: -1/5 + 1/7 + 2/35 =  0/35 = 0
        @test isapprox(1 / 5 + 2 / 7 + 18 / 35, 1.0; atol=1e-15)
        @test isapprox(-1 / 5 - 2 / 7 + 17 / 35, 0.0; atol=1e-15)
        @test isapprox(-1 / 5 + 1 / 7 + 2 / 35, 0.0; atol=1e-15)
    end

    @testset "F=3 octahedral scalar limit (g_S ≡ g)" begin
        # In the function signature, g_2 is present but excluded by O harmonics
        # so it must not affect the result.
        for g in (0.5, 1.0, 2.0)
            for g2_dummy in (-5.0, 0.0, 1.0, 100.0)
                n = 1.0
                ε = lhy_F3_octa(g, g2_dummy, g, g, n, 1.0)
                # c_0 = g, λ_spin = 0  ⇒  ε = (8/15π²) (g·n)^(5/2)
                @test isapprox(ε, P_scalar * (g * n)^2.5; rtol=1e-12)
            end
        end
    end

    @testset "F=3 selection rule: g_2 has zero effect" begin
        ε_a = lhy_F3_octa(1.0, 0.0, 1.05, 0.98, 1.0, 1.0)
        ε_b = lhy_F3_octa(1.0, 1000.0, 1.05, 0.98, 1.0, 1.0)
        @test ε_a == ε_b
    end

    @testset "F=4 cube scalar limit (g_S ≡ g)" begin
        for g in (0.5, 1.0, 2.0)
            for g2_dummy in (-3.0, 0.0, 5.0)
                n = 1.0
                ε = lhy_F4_cube(g, g2_dummy, g, g, g, n, 1.0)
                @test isapprox(ε, P_scalar * (g * n)^2.5; rtol=1e-12)
            end
        end
    end

    @testset "F=4 cube selection rule: g_2 has zero effect" begin
        ε_a = lhy_F4_cube(1.0, 0.0, 1.05, 0.98, 1.02, 1.0, 1.0)
        ε_b = lhy_F4_cube(1.0, 1e6, 1.05, 0.98, 1.02, 1.0, 1.0)
        @test ε_a == ε_b
    end

    @testset "F=4 cube coefficient sum identities" begin
        # c_0:    1/9 + 98/429 + 40/99 + 10/39 = 1
        # λ_spin: -1/9 - 49/429 + 2/99 + 8/39 = 0
        @test isapprox(1 / 9 + 98 / 429 + 40 / 99 + 10 / 39, 1.0; atol=1e-13)
        @test isapprox(-1 / 9 - 49 / 429 + 2 / 99 + 8 / 39, 0.0; atol=1e-13)
    end

    @testset "F=8 octahedral scalar limit (g_S ≡ g)" begin
        for g in (0.5, 1.0, 2.0)
            for g2_dummy in (-3.0, 0.0, 5.0)
                n = 1.0
                ε = lhy_F8_octa(g, g2_dummy, g, g, g, g, g, g, g, n, 1.0)
                @test isapprox(ε, P_scalar * (g * n)^2.5; rtol=1e-10)
            end
        end
    end

    @testset "F=8 octahedral selection rule: g_2 has zero effect" begin
        ε_a = lhy_F8_octa(1.0, 0.0, 1.05, 0.98, 1.02, 0.97, 1.01, 0.99, 1.03, 1.0, 1.0)
        ε_b = lhy_F8_octa(
            1.0, 999.0, 1.05, 0.98, 1.02, 0.97, 1.01, 0.99, 1.03, 1.0, 1.0
        )
        @test ε_a == ε_b
    end

    @testset "F=8 octahedral coefficient sum identities" begin
        c0_sum =
            1 / 17 + 1372 / 12597 + 64 / 22287 + 330 / 5681 +
            40768 / 200583 + 1651420 / 5816907 +
            37856 / 365769 + 1714570 / 9490743
        λ_sum =
            -1 / 17 - 10633 / 113373 - 8 / 3933 - 165 / 5681 -
            5096 / 106191 + 412855 / 17450721 +
            52052 / 1097307 + 13716560 / 85416687
        @test isapprox(c0_sum, 1.0; atol=1e-12)
        @test isapprox(λ_sum, 0.0; atol=1e-12)
    end

    @testset "F=10 dodecahedral scalar limit (g_S ≡ g)" begin
        # Signature only has 7 contributing channels (g_2, g_4, g_8, g_14
        # already excluded by I_h harmonics).
        for g in (0.5, 1.0, 2.0)
            n = 1.0
            ε = lhy_F10_dodec(g, g, g, g, g, g, g, n, 1.0)
            @test isapprox(ε, P_scalar * (g * n)^2.5; rtol=1e-10)
        end
    end

    @testset "F=10 dodecahedral coefficient sum identities" begin
        c0_sum =
            1 / 21 + 2299 / 24633 + 586625 / 3163581 + 3135 / 20677 +
            349448 / 1554777 + 131648 / 736281 + 15895 / 134199
        λ_sum =
            -1 / 21 - 18601 / 246330 - 586625 / 6327162 - 912 / 20677 +
            412984 / 7773885 + 365024 / 3681405 + 14450 / 134199
        @test isapprox(c0_sum, 1.0; atol=1e-12)
        @test isapprox(λ_sum, 0.0; atol=1e-12)
    end

    @testset "Numerical positivity (typical-parameter sanity)" begin
        # Eu-like couplings, range of densities; ε_LHY ≥ 0 always.
        gS = 1.0
        for n in (0.1, 1.0, 10.0)
            @test lhy_F2_BN(gS, 1.05gS, 0.98gS, n, 1.0) >= 0
            @test lhy_F3_octa(gS, 1.0, 1.02gS, 0.97gS, n, 1.0) >= 0
            @test lhy_F4_cube(gS, 1.0, 1.05gS, 0.98gS, 1.02gS, n, 1.0) >= 0
            @test lhy_F8_octa(gS, 1.0, 1.05gS, 0.98gS, 1.02gS,
                0.97gS, 1.01gS, 0.99gS, 1.03gS, n, 1.0) >= 0
            @test lhy_F10_dodec(gS, 1.0gS, 1.05gS, 0.98gS,
                1.02gS, 0.97gS, 1.01gS, n, 1.0) >= 0
        end
        # Edge: n = 0 → ε = 0
        @test lhy_F2_BN(1.0, 1.0, 1.0, 0.0, 1.0) == 0.0
        @test lhy_F3_octa(1.0, 1.0, 1.0, 1.0, 0.0, 1.0) == 0.0
        @test lhy_F4_cube(1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0) == 0.0
        @test lhy_F8_octa(1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0) == 0.0
        @test lhy_F10_dodec(1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0) == 0.0
    end

    @testset "Mass / hbar scaling (dimensional)" begin
        # ε ∝ √M³ / ℏ³ (with all g, n fixed)
        ε1 = lhy_F3_octa(1.0, 0.0, 1.0, 1.0, 1.0, 1.0; hbar=1.0)
        ε2 = lhy_F3_octa(1.0, 0.0, 1.0, 1.0, 1.0, 4.0; hbar=1.0)  # M ×4
        @test isapprox(ε2 / ε1, sqrt(64.0); rtol=1e-12)            # √M³ ratio = 8
        ε3 = lhy_F3_octa(1.0, 0.0, 1.0, 1.0, 1.0, 1.0; hbar=2.0)  # ℏ ×2
        @test isapprox(ε3 / ε1, 1 / 8; rtol=1e-12)                # 1/ℏ³ ratio = 1/8
    end
end
