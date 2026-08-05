using Test
using SpinorBEC

@testset "Atom Species Library" begin
    all_atoms = [
        Li7, Na23, K39, K41, Rb85, Rb87, Cs133,
        Cr52, Dy164, Dy162, Er168, Er166, Eu151, Eu153, Eu151_f1_effective,
        Ca40, Sr84, Sr86, Sr88, Yb170, Yb174, Yb176,
        He4star,
    ]

    @testset "Basic fields ($a)" for a in all_atoms
        @test a.name isa String
        @test !isempty(a.name)
        @test a.mass > 0
        @test a.F >= 0
    end

    @testset "ATOM_REGISTRY" begin
        @test length(ATOM_REGISTRY) == length(all_atoms)
        for (sym, atom) in ATOM_REGISTRY
            @test atom isa AtomSpecies
            @test atom === resolve_atom(sym)
        end
        @test_throws ArgumentError resolve_atom(:Nonexistent)
    end

    @testset "g_F ≡ Landé g-factor (magic-number gate)" begin
        # Every registry g_F is the Landé projection g_J·[F(F+1)+J(J+1)-I(I+1)]/(2F(F+1)),
        # not a hand-typed fraction. Recompute each from (F, I, J, g_J) and compare —
        # gates the -1/2, -1/3, -1/4, 7/12·g_J literals against the formula (the
        # 35/144-class guard). (I, J, g_J from standard atomic data.)
        cases = [
            (Li7, 1, 3 // 2, 1 // 2, 2.0), (Na23, 1, 3 // 2, 1 // 2, 2.0),
            (K39, 1, 3 // 2, 1 // 2, 2.0), (K41, 1, 3 // 2, 1 // 2, 2.0),
            (Rb87, 1, 3 // 2, 1 // 2, 2.0), (Rb85, 2, 5 // 2, 1 // 2, 2.0),
            (Cs133, 3, 7 // 2, 1 // 2, 2.0), (He4star, 1, 0, 1, 2.0),
            (Cr52, 3, 0, 3, 2.0), (Dy164, 8, 0, 8, 1.24), (Dy162, 8, 0, 8, 1.24),
            (Er168, 6, 0, 6, 1.16), (Er166, 6, 0, 6, 1.16),
            (Eu151, 6, 5 // 2, 7 // 2, 1.9934), (Eu153, 6, 5 // 2, 7 // 2, 1.9934),
        ]
        for (a, F, I, J, gJ) in cases
            @test isapprox(a.g_F, lande_g_factor(F, I, J; g_J=gJ); atol=1e-4)
        end
    end

    @testset "F=1 alkali: a_s consistency" begin
        f1_atoms = [Li7, Na23, K39, K41, Rb87, He4star]
        for a in f1_atoms
            @test a.F == 1
            @test a.a_s ≈ (a.a0 + 2 * a.a2) / 3 rtol = 1e-12
            @test haskey(a.scattering_lengths, 0)
            @test haskey(a.scattering_lengths, 2)
            @test a.scattering_lengths[0] == a.a0
            @test a.scattering_lengths[2] == a.a2
        end
    end

    @testset "Na23 literature values (Knoop et al. PRA 2011)" begin
        @test Na23.a0 ≈ 47.36 * SpinorBEC.Units.BOHR_RADIUS rtol = 1e-6
        @test Na23.a2 ≈ 52.98 * SpinorBEC.Units.BOHR_RADIUS rtol = 1e-6
    end

    @testset "F>1 alkali: mean a_s only" begin
        for a in [Rb85, Cs133]
            @test a.F > 1
            @test a.a_s == a.a0
            @test a.a2 == 0.0
        end
    end

    @testset "Dipolar atoms: mu_mag > 0" begin
        dipolar = [Cr52, Dy164, Dy162, Er168, Er166, Eu151, Eu153, He4star]
        for a in dipolar
            @test a.mu_mag > 0
            @test a.g_F != 0.0
        end
    end

    @testset "Spinless atoms: F=0, non-magnetic" begin
        spinless = [Ca40, Sr84, Sr86, Sr88, Yb170, Yb174, Yb176]
        for a in spinless
            @test a.F == 0
            @test a.mu_mag == 0.0
            @test a.g_F == 0.0
        end
    end

    @testset "Cr52 channel-resolved scattering" begin
        @test Cr52.F == 3
        @test haskey(Cr52.scattering_lengths, 2)
        @test haskey(Cr52.scattering_lengths, 4)
        @test haskey(Cr52.scattering_lengths, 6)
        @test Cr52.scattering_lengths[6] < 0  # a₆ = -7 a₀
    end

    @testset "Eu151 unchanged" begin
        @test Eu151.F == 6
        @test Eu151.a_s ≈ 110.0 * SpinorBEC.Units.BOHR_RADIUS rtol = 1e-6
        @test Eu151.mu_mag > 6.0 * SpinorBEC.Units.BOHR_MAGNETON
    end

    @testset "Eu153 shares Eu151's electronic structure" begin
        # Same ⁸S₇/₂ configuration and same nucleus spin (I=5/2), so everything
        # that depends only on (F, I, J, g_J) must be bit-identical.
        @test Eu153.F == 6
        @test Eu153.g_J == Eu151.g_J
        @test Eu153.g_F == Eu151.g_F
        @test Eu153.mu_mag == Eu151.mu_mag
        @test Eu153.q_geometry == Eu151.q_geometry
        @test Eu153.nuclear_I == 5 / 2
        @test Eu153.electronic_J == 7 / 2

        # NIST/AME2020 relative atomic masses 152.9212380 / 150.9198578.
        @test Eu153.mass / Eu151.mass ≈ 152.9212380 / 150.919857 rtol = 1e-9
        @test Eu153.mass > Eu151.mass
    end

    @testset "Eu153 hyperfine and quadratic Zeeman" begin
        # a_hf = -8.853 MHz vs -20.052 MHz (Sandars & Woodgate 1960, as tabulated
        # in Zaremba-Kopczyk/Żuchowski/Tomza PRA 98, 032704 (2018) Table I).
        # F=6 ↔ F=5 splitting = 6|a_hf| = 53.1 MHz.
        @test Eu153.Delta_E_hf ≈ 53.1e6 * 2π * SpinorBEC.Units.HBAR rtol = 1e-9
        @test Eu153.Delta_E_hf < Eu151.Delta_E_hf

        # q ∝ 1/Δ_hf at fixed B and identical g_J/q_geometry ⇒ ¹⁵³Eu feels a
        # ~2.3× larger quadratic Zeeman. That is the isotope's headline
        # difference, so pin it directionally rather than by a bare number.
        ratio = quadratic_zeeman_si(Eu153, 1e-4) / quadratic_zeeman_si(Eu151, 1e-4)
        @test ratio ≈ Eu151.Delta_E_hf / Eu153.Delta_E_hf rtol = 1e-12
        @test 2.2 < ratio < 2.4
        q_hz = quadratic_zeeman_si(Eu153, 1e-4) / (2π * SpinorBEC.Units.HBAR)
        @test 3.1e3 < q_hz < 3.4e3     # ≈ 3.3 kHz/G², vs 1.43 kHz/G² for ¹⁵¹Eu
    end

    @testset "Eu153 scattering length is an unmeasured placeholder" begin
        # No ¹⁵³Eu measurement exists; the entry carries the ¹⁵¹Eu value of
        # 110(4) a₀ (Miyazawa et al. PRL 129, 223401 (2022)). This test exists
        # to make any future substitution a deliberate, documented change.
        @test Eu153.a_s == Eu151.a_s
        @test isempty(Eu153.scattering_lengths)
    end

    @testset "Hyperfine splitting for alkali" begin
        for a in [Li7, Na23, K39, K41, Rb85, Rb87, Cs133]
            @test a.Delta_E_hf > 0
        end
        @test Cs133.Delta_E_hf > Rb87.Delta_E_hf > Na23.Delta_E_hf > Li7.Delta_E_hf
    end

    @testset "He4star metastable" begin
        @test He4star.F == 1
        @test He4star.mu_mag > 0
        @test He4star.g_F ≈ 2.0
        @test haskey(He4star.scattering_lengths, 0)
        @test haskey(He4star.scattering_lengths, 2)
    end

    @testset "Dy/Er large magnetic moment" begin
        @test Dy164.mu_mag > 9.0 * SpinorBEC.Units.BOHR_MAGNETON
        @test Er168.mu_mag > 6.0 * SpinorBEC.Units.BOHR_MAGNETON
        @test Dy164.F == 8
        @test Er168.F == 6
    end
end
