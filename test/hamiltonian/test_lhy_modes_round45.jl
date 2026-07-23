# Tests for src/hamiltonian/terms/lhy/modes_round45.jl —
# standalone LHY closed forms for the Round-4/Round-5 polyhedral
# phase verifications.

using Test
using SpinorBEC: lhy_F2_BN, lhy_F3_octa, lhy_F4_cube, lhy_F8_octa, lhy_F10_dodec

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

    @testset "polyhedral c_0/λ ≡ CG σ_S energy reconstruction (magic-number gate)" begin
        # Each closed form's stiffnesses are c_0 = Σ_S σ_S(ζ) g_S and
        # λ_spin = Σ_S [(S(S+1)−2F(F+1))/(2F(F+1))] σ_S(ζ) g_S (Sign-Pattern
        # Lemma 1), with ζ the canonical polyhedral inert state. Reconstruct the
        # energy from σ_S (independent Clebsch-Gordan via _f6_pd_sigma_S) and
        # compare to the source function — gates the hand-entered rationals
        # (1372/12597, 586625/3163581, …) against a from-scratch derivation.
        σ(F, S, ζ) = SpinorBEC._f6_pd_sigma_S(F, S, Complex{Float64}.(ζ))
        fac(F, S) = (S * (S + 1) - 2 * F * (F + 1)) / (2 * F * (F + 1))
        function eps_recon(F, ζ, gd)
            c0 = sum(σ(F, S, ζ) * get(gd, S, 0.0) for S in 0:2:(2F))
            λ = sum(fac(F, S) * σ(F, S, ζ) * get(gd, S, 0.0) for S in 0:2:(2F))
            P_scalar * (c0^2.5 + 3 * abs(λ)^2.5)
        end
        let gd = Dict(0 => 1.3, 2 => 0.7, 4 => 1.1, 6 => 0.9)
            @test isapprox(lhy_F3_octa(gd[0], gd[2], gd[4], gd[6], 1.0, 1.0),
                eps_recon(3, SpinorBEC.ZETA_F3_O_A2, gd); rtol=1e-9)
        end
        let gd = Dict(0 => 1.3, 2 => 0.7, 4 => 1.1, 6 => 0.9, 8 => 1.05)
            @test isapprox(lhy_F4_cube(gd[0], gd[2], gd[4], gd[6], gd[8], 1.0, 1.0),
                eps_recon(4, SpinorBEC.ZETA_F4_OH_A1, gd); rtol=1e-9)
        end
        let gd = Dict(0 => 1.3, 2 => 0.7, 4 => 1.1, 6 => 0.9, 8 => 1.05,
                10 => 0.95, 12 => 1.2, 14 => 0.8, 16 => 1.1)
            @test isapprox(
                lhy_F8_octa(gd[0], gd[2], gd[4], gd[6], gd[8], gd[10], gd[12],
                    gd[14], gd[16], 1.0, 1.0),
                eps_recon(8, SpinorBEC.ZETA_F8_OH_A1, gd); rtol=1e-9)
        end
        let gd = Dict(0 => 1.3, 6 => 0.9, 10 => 0.95, 12 => 1.2, 16 => 1.1,
                18 => 0.85, 20 => 1.05)
            @test isapprox(
                lhy_F10_dodec(gd[0], gd[6], gd[10], gd[12], gd[16], gd[18],
                    gd[20], 1.0, 1.0),
                eps_recon(10, SpinorBEC.ZETA_F10_IH_DODEC, gd); rtol=1e-9)
        end
        # F=2 BN not gated: its D_4-split (λ_z, λ_⊥) inert state is absent from
        # the canonical registry; its {1/5, 2/7, 18/35} c_0 coefficients remain
        # a manuscript follow-up.
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
