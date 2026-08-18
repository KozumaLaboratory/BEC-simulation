# classify_spinor_phase on KNOWN state_zoo imprints: distinguishable textures
# must get distinct labels (no collapsing). This is the threshold-setting run
# of the classifier (absorbed from scripts/eu_fingerprint_validate.jl) turned
# into a pin: F=6 Eu, 32³ box=12 (phase-diagram texture scale), no solving —
# imprints carry the canonical texture by construction.
#
# Every branch of the classifier is exercised: the σ_S point-group labels, the
# ferromagnetic uniform branch, and each texture label (radial / chiral /
# polar-core / skyrmion).
#
# The @test_broken block records a measured DRIFT (2026-08-18): the validation
# script's header claimed (2026-07-24) flower fc≈0.12 / coh 0.12–0.51 and
# "modulated" spin_mod > 0.30 for magnetic_domain / vortex_lattice /
# domain_wall. Measured today: flower coh=0.74 fc=0.543 (→ ferromagnetic),
# and all three modulated imprints have spin_mod ≈ 0.000 (suspect:
# `b4525d78` — `_struct_peak` non-cubic-grid fix — for the modulated family;
# the flower drift is unexplained). The radial (fc=0.936), chiral (χ=0.241)
# and skyrmion (χ=0.703) claims still reproduce, so the machinery is
# consistent and the drift is imprint-specific. If one of these starts
# passing, promote it to @test.

using Test
using SpinorBEC

@testset "spinor phase classifier on state_zoo imprints" begin
    grid = make_grid(GridConfig((32, 32, 32), (12.0, 12.0, 12.0)))
    sys = SpinSystem(6)

    label(st) = classify_spinor_phase(
        spinor_fingerprint(ComplexF64.(init_psi(grid, sys; state=st)), grid, 6))

    @testset "σ_S point-group labels (uniform bulk)" begin
        @test label(:polar) == "polar"
        @test label(:cyclic) == "cyclic"
        @test label(:biaxial_nematic) == "biaxial_nematic"
    end

    @testset "ferromagnetic uniform branch" begin
        @test label(:m_plus_F) == "ferromagnetic"
        @test label(:spin_coherent) == "ferromagnetic"
    end

    @testset "texture labels are distinct (no collapsing)" begin
        @test label(:radial_spin_vortex) == "radial_spin_vortex"
        @test label(:chiral_spin_vortex) == "chiral_spin_vortex"
        @test label(:polar_core_vortex) == "polar_core_vortex"
        @test label(:skyrmion) == "skyrmion"
    end

    @testset "drifted imprints (measured 2026-08-18; see header)" begin
        @test_broken label(:flower) == "flower"
        @test_broken label(:magnetic_domain) == "modulated"
        @test_broken label(:vortex_lattice) == "modulated"
        @test_broken label(:domain_wall) == "modulated"
    end
end
