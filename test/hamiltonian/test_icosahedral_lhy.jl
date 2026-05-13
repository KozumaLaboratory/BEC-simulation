using Test
using SpinorBEC
using SpinorBEC.IcosahedralMod

# F=6 icosahedral (I_h) closed-form contact LHY tests (Round-3 Task 1).
# Formula derived in parallel session 2026-05-07; numerical values
# pre-verified by hand calculation before implementation.

@testset "F=6 I_h LHY closed form" begin
    @testset "ZETA_F6_IH normalization" begin
        @test length(ZETA_F6_IH) == 13
        @test isapprox(sum(abs2, ZETA_F6_IH), 1.0; atol=1e-12)
        # Non-zero only at m=+5 (idx 2), m=0 (idx 7), m=-5 (idx 12).
        for (i, ζ) in enumerate(ZETA_F6_IH)
            if i in (2, 7, 12)
                @test abs(ζ) > 0.4
            else
                @test abs(ζ) < 1e-15
            end
        end
        # Mz = ⟨ζ| F_z |ζ⟩ = (+5)(7/25) + 0(11/25) + (-5)(7/25) = 0
        F_z = Diagonal(Float64[6, 5, 4, 3, 2, 1, 0, -1, -2, -3, -4, -5, -6])
        Mz = real(ZETA_F6_IH' * (F_z * ZETA_F6_IH))
        @test isapprox(Mz, 0.0; atol=1e-12)
    end

    @testset "Scalar limit (g_S ≡ 1)" begin
        c0, lambda_spin = compute_c0_lambda_F6_Ih(ones(7))
        @test isapprox(c0, 1.0; atol=1e-13)
        @test isapprox(lambda_spin, 0.0; atol=1e-13)
        # Generic scalar limit: c_0 = g, λ_spin = 0
        for g in (0.5, 2.0, 100.0)
            c0g, lg = compute_c0_lambda_F6_Ih(fill(g, 7))
            @test isapprox(c0g, g; atol=1e-13 * max(g, 1.0))
            @test isapprox(lg, 0.0; atol=1e-13 * max(g, 1.0))
        end
    end

    @testset "g_2 / g_4 / g_8 cancellation" begin
        # I_h harmonic decomposition kills S=2,4,8 channels exactly.
        baseline = ones(7)
        c0_base, lam_base = compute_c0_lambda_F6_Ih(baseline)
        for (idx, label) in ((2, "g_2"), (3, "g_4"), (5, "g_8"))
            for factor in (-3.0, 0.0, 5.0, 100.0)
                gs = copy(baseline)
                gs[idx] = factor
                c0, lam = compute_c0_lambda_F6_Ih(gs)
                @test isapprox(c0, c0_base; atol=1e-13)
                @test isapprox(lam, lam_base; atol=1e-13)
            end
        end
    end

    @testset "Eu-like config (parallel-session reference)" begin
        # g_S = [g_0, g_2, g_4, g_6, g_8, g_10, g_12]
        gs = [1.0, 1.05, 0.98, 1.02, 0.97, 1.01, 0.99]
        c0, lam = compute_c0_lambda_F6_Ih(gs)
        # Parallel session reported c_0 ≈ 1.0095, λ_spin ≈ -0.00406.
        # Exact values from the closed form match those approximations:
        #   c_0     = 1/13 + 121*1.02/323 + 147*1.01/391 + 980*0.99/5681
        #           = 1.0095268024477877
        #   λ_spin  = -1/13 - 121*1.02/646 + 91*1.01/782 + 840*0.99/5681
        #           = -0.004061060086770152
        @test isapprox(c0, 1.0095268024477877; atol=1e-13)
        @test isapprox(lam, -0.004061060086770152; atol=1e-13)
        # Within the parallel-session 4-sig-fig print precision:
        @test isapprox(c0, 1.0095; atol=5e-4)
        @test isapprox(lam, -0.00406; atol=5e-5)
    end

    @testset "g_dict overload" begin
        gd = Dict(0 => 1.0, 6 => 1.02, 10 => 1.01, 12 => 0.99)   # missing g_2,4,8
        c0d, lamd = compute_c0_lambda_F6_Ih(gd)
        c0v, lamv = compute_c0_lambda_F6_Ih([1.0, 0.0, 0.0, 1.02, 0.0, 1.01, 0.99])
        @test isapprox(c0d, c0v; atol=1e-13)
        @test isapprox(lamd, lamv; atol=1e-13)
    end

    @testset "LHY positivity" begin
        # Any positive g_S → c_0 > 0 → ε_LHY ≥ 0 at all densities.
        rng_gs = (
            ones(7),
            [1.0, 0.5, 1.5, 0.9, 1.1, 1.0, 1.0],
            [2.0, 0.0, 0.0, 1.0, 0.0, 0.5, 0.5],
            [1.0, 1.05, 0.98, 1.02, 0.97, 1.01, 0.99],
        )
        for gs in rng_gs
            for n in (0.1, 1.0, 10.0, 100.0)
                ε = epsilon_LHY_F6_Ih(n, gs)
                @test isfinite(ε)
                @test ε >= 0
            end
            @test epsilon_LHY_F6_Ih(0.0, gs) == 0.0
            @test epsilon_LHY_F6_Ih(-1.0, gs) == 0.0
        end
    end

    @testset "Scalar reduction matches Lima-Pelster" begin
        # For uniform g_S the I_h closed form should give the same energy
        # density as the standard scalar LHY at coupling g, since c_0 = g
        # and λ_spin = 0 → the ε_LHY collapses to (8/15π²)(g·n)^(5/2).
        for g in (1.0, 2.5, 10.0)
            for n in (0.1, 1.0, 5.0)
                gs = fill(g, 7)
                ε_Ih = epsilon_LHY_F6_Ih(n, gs)
                ε_scalar = (8.0 / (15.0 * π^2)) * (g * n)^2.5
                @test isapprox(ε_Ih, ε_scalar; rtol=1e-12)
            end
        end
    end

    @testset "Argument validation" begin
        @test_throws ArgumentError compute_c0_lambda_F6_Ih(ones(6))
        @test_throws ArgumentError compute_c0_lambda_F6_Ih(ones(8))
    end

    @testset "compute_spinor_lhy_icosahedral wrapper" begin
        gd = Dict(0 => 1.0, 2 => 1.05, 4 => 0.98, 6 => 1.02,
            8 => 0.97, 10 => 1.01, 12 => 0.99)
        tbl = compute_spinor_lhy_icosahedral(F=6, g_dict=gd, n_max=2.0, n_points=200)
        @test tbl isa IcosahedralLHY
        @test length(tbl.densities) == 200
        @test length(tbl.potential_values) == 200
        @test tbl.densities[1] == 0.0
        @test tbl.densities[end] == 2.0
        # Potential is dε/dn = (5/2)(8/15π²)(c_0^(5/2) + 3|λ|^(5/2)) n^(3/2);
        # check positivity (c_0 > 0) and that it grows with n.
        @test all(>=(0), tbl.potential_values[2:end])
        @test tbl.potential_values[end] > tbl.potential_values[10]
        # F=6 only
        @test_throws ArgumentError compute_spinor_lhy_icosahedral(
            F=1, g_dict=Dict(0 => 1.0), n_max=1.0, n_points=10)
    end

    @testset "Cross-state: IcosahedralLHY vs PolarContact (paper #1 cross-check)" begin
        # (1) Scalar limit g_S ≡ g: both reduce to scalar Lima-Pelster
        # exactly. Polar and I_h are LHY for DIFFERENT ground states, but
        # the scalar Hamiltonian makes both states degenerate and the LHY
        # collapses to the same value.
        for g in (1.0, 5.0, 50.0)
            gd = Dict(2k => g for k in 0:6)
            sca = (8.0 / (15.0 * π^2)) * (g * 1.0)^2.5
            pol = SpinorBEC.PolarContactMod.lhy_energy_polar(1.0, 6, gd)
            ico = SpinorBEC.IcosahedralMod.epsilon_LHY_F6_Ih(1.0, gd)
            @test isapprox(pol, sca; rtol=1e-10)
            @test isapprox(ico, sca; rtol=1e-10)
        end

        # (2) State-dependence: at the same Eu-realistic g_dict (c0/c1
        # parameterization), Polar and I_h LHY differ ~46% — different
        # ground states give materially different LHY corrections. Pin
        # the ratio so a future "fix" that collapses one to the other
        # would be caught.
        g_eu = SpinorBEC._c0c1_to_gS(6, 100.0, 5.0)
        pol = SpinorBEC.PolarContactMod.lhy_energy_polar(1.0, 6, g_eu)
        ico = SpinorBEC.IcosahedralMod.epsilon_LHY_F6_Ih(1.0, g_eu)
        # I_h c_0 must be positive (else I_h not the GS, NaN returned).
        c0_ico, _ = SpinorBEC.IcosahedralMod.compute_c0_lambda_F6_Ih(g_eu)
        @test c0_ico > 0
        @test isfinite(ico) && ico > 0
        @test 1.3 < pol / ico < 1.6     # measured 1.4617 (2026-05-12)

        # (3) g_12-dominated regime: I_h-favouring g_dict gives a larger
        # state-dependence (Polar/I_h ratio ~ 2.4).
        g_ih = Dict(0 => 5.0, 2 => 2.0, 4 => 2.0, 6 => 5.0,
            8 => 2.0, 10 => 10.0, 12 => 50.0)
        c0_ico2, _ = SpinorBEC.IcosahedralMod.compute_c0_lambda_F6_Ih(g_ih)
        @test c0_ico2 > 0
        pol2 = SpinorBEC.PolarContactMod.lhy_energy_polar(1.0, 6, g_ih)
        ico2 = SpinorBEC.IcosahedralMod.epsilon_LHY_F6_Ih(1.0, g_ih)
        @test 2.0 < pol2 / ico2 < 3.0   # measured 2.4440 (2026-05-12)
    end
end
