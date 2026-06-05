using Test
using SpinorBEC

@testset "Preset struct + eu151_preset" begin
    @testset "eu151_preset defaults" begin
        p = eu151_preset()

        @test p.atom === SpinorBEC.Eu151
        @test p.F == 6
        @test p.D == 13
        @test p.n_atoms == 50_000
        @test size(p.grid.x[1], 1) == 24
        @test p.potential isa HarmonicTrap{3}
        @test p.potential.omega == (1.0, 1.0, 1.1818)

        # Couplings positive and consistent with c_1 = c_0 / 36 assumption.
        @test p.c0 > 0.0
        @test p.c1 > 0.0
        @test isapprox(p.c1, p.c0 / 36; rtol=1e-12)

        # c_dd matches independent compute_c_dd_dimless call.
        c_dd_check = SpinorBEC.compute_c_dd_dimless(
            p.atom; N_atoms=p.n_atoms, omega_ref=p.omega_ref
        )
        @test p.c_dd == c_dd_check

        # Eu γ_F / (2π) ≈ 16.28 Hz/nT at ω_ref = 2π·110 Hz ⇒ p_per_nT ≈ 0.148.
        @test isapprox(p.p_per_nT, 0.148; atol=2e-3)

        # a_ho is the right scale: √(ℏ/(m·ω)) ≈ 0.6 µm for Eu151 @ 110 Hz.
        @test 1e-7 < p.a_ho < 1e-6
    end

    @testset "eu151_preset kwargs override geometry / atom count" begin
        p = eu151_preset(; n_atoms=10_000, n_pts=(16, 16, 16), box=(20.0, 20.0, 20.0))
        @test p.n_atoms == 10_000
        @test size(p.grid.x[1], 1) == 16
        @test p.grid.config.box_size == (20.0, 20.0, 20.0)
    end

    @testset "omega_ref override re-derives p_per_nT" begin
        ref = eu151_preset()
        scaled = eu151_preset(; omega_ref=2 * ref.omega_ref)
        # p_per_nT ∝ 1/ω_ref ⇒ doubling ω_ref halves p_per_nT.
        @test isapprox(scaled.p_per_nT, ref.p_per_nT / 2; rtol=1e-12)
    end
end
