using Test
using Scattering

@testset "Atomic units conversions" begin
    # hz_to_au: 1 Hz corresponds to h/E_h ≈ 1.51983e-16 E_h
    @test Scattering.hz_to_au(1.0) ≈ 6.62607015e-34 / 4.3597447222071e-18 atol = 1e-25
    @test Scattering.mhz_to_au(1.0) ≈ 1e6 * Scattering.hz_to_au(1.0) atol = 1e-18
    @test Scattering.ghz_to_au(1.0) ≈ 1e9 * Scattering.hz_to_au(1.0) atol = 1e-15

    # round trip Hz → au → Hz
    @test Scattering.au_to_hz(Scattering.hz_to_au(2.5e9)) ≈ 2.5e9 rtol = 1e-12
    @test Scattering.au_to_mhz(Scattering.mhz_to_au(123.45)) ≈ 123.45 rtol = 1e-12

    # Bohr radius round trip
    @test Scattering.bohr_to_m(Scattering.m_to_bohr(1e-9)) ≈ 1e-9 rtol = 1e-12

    # amu to electron mass: 1 u ≈ 1822.888 m_e
    @test Scattering.amu_to_au(1.0) ≈ 1.66053906660e-27 / 9.1093837015e-31 rtol = 1e-9

    # Bohr magneton constant check: μ_B = 1/2 in Gaussian atomic units
    @test Scattering.MU_B_AU == 0.5
    # μ_N / μ_B ≈ m_e / m_p ≈ 1/1836.15
    @test Scattering.MU_N_AU / Scattering.MU_B_AU ≈ 1 / 1836.152 rtol = 1e-3

    # Temperature: kT at 1 K ≈ 3.167e-6 E_h
    @test Scattering.kelvin_to_au(1.0) ≈ 1.380649e-23 / 4.3597447222071e-18 rtol = 1e-9
end
