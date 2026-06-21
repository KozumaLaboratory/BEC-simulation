@testset "Atom Species Library" begin
    all_atoms = [
        Li7, Na23, K39, K41, Rb85, Rb87, Cs133,
        Cr52, Dy164, Dy162, Er168, Er166, Eu151, Eu151_f1_effective,
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
        dipolar = [Cr52, Dy164, Dy162, Er168, Er166, Eu151, He4star]
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
