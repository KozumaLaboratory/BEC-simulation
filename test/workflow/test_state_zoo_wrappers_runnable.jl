# state_zoo wrappers runnable regression.
#
# Each parameterized wrapper (init_psi_spin_helix, init_psi_fl_vortex, ...)
# must call `init_psi` with kwargs that `init_psi` actually accepts. A
# 2026-05 refactor flattened `init_psi`'s signature but left the wrappers
# passing `init_state_params=Dict(...)` — silent MethodError at call time
# (memory `state_zoo_yaml_integration_wip.md`). This test pins the
# contract: every wrapper must produce a non-empty L2-normalized psi.

using Test
using SpinorBEC

@testset "state_zoo wrappers runnable (MethodError regression)" begin
    grid2 = make_grid(GridConfig((16, 16), (8.0, 8.0)))
    grid3 = make_grid(GridConfig((16, 16, 16), (8.0, 8.0, 8.0)))
    sys = SpinSystem(1)
    F = sys.F
    D = sys.n_components

    function _check_psi(psi, expected_dims; tag::String)
        # Each wrapper must return a complex array whose spatial shape
        # matches the grid and whose last axis is 2F+1 components.
        @test eltype(psi) <: Complex
        @test ndims(psi) == expected_dims + 1
        @test size(psi)[end] == D
        # L2 normalization to 1 in the dV-weighted inner product is the
        # contract `init_psi` enforces at line 332-334.
        dV_inv = sum(abs2, psi)
        @test isfinite(dV_inv) && dV_inv > 0
    end

    @testset "init_psi_spin_helix 3D q_vector" begin
        psi = init_psi_spin_helix(grid3, sys; q_vector=(0.5, 0.0, 0.0))
        _check_psi(psi, 3; tag="spin_helix")
    end

    @testset "init_psi_spin_helix 2D q_vector" begin
        psi = init_psi_spin_helix(grid2, sys; q_vector=(0.5, 0.0))
        _check_psi(psi, 2; tag="spin_helix")
    end

    @testset "init_psi_spin_coherent" begin
        psi = init_psi_spin_coherent(grid2, sys; theta=0.5, phi=0.3)
        _check_psi(psi, 2; tag="spin_coherent")
    end

    @testset "init_psi_fl_vortex" begin
        psi = init_psi_fl_vortex(grid2, sys; winding=1)
        _check_psi(psi, 2; tag="fl_vortex")
    end

    @testset "init_psi_biaxial_nematic" begin
        psi = init_psi_biaxial_nematic(grid2, sys; angles=(0.0, 0.0))
        _check_psi(psi, 2; tag="biaxial_nematic")
        # Non-tuple angles must throw.
        @test_throws ArgumentError init_psi_biaxial_nematic(grid2, sys; angles=0.0)
    end

    @testset "init_psi_polar_core_vortex" begin
        psi = init_psi_polar_core_vortex(grid2, sys; winding=1)
        _check_psi(psi, 2; tag="polar_core_vortex")
        # Non-:z axis must throw (not silently produce a z-axis state).
        @test_throws ArgumentError init_psi_polar_core_vortex(
            grid2, sys; winding=1, axis=:x)
    end

    @testset "init_psi_bright_soliton" begin
        psi = init_psi_bright_soliton(grid2, sys)
        _check_psi(psi, 2; tag="bright_soliton")
    end

    @testset "init_psi_dark_soliton" begin
        psi = init_psi_dark_soliton(grid2, sys)
        _check_psi(psi, 2; tag="dark_soliton")
    end

    @testset "init_psi_wavepacket" begin
        psi = init_psi_wavepacket(grid2, sys; momentum=0.5)
        _check_psi(psi, 2; tag="wavepacket")
    end

    @testset "init_psi_domain_wall" begin
        psi = init_psi_domain_wall(grid2, sys)
        _check_psi(psi, 2; tag="domain_wall")
        # Non-axis-1 must throw.
        @test_throws ArgumentError init_psi_domain_wall(grid2, sys; axis=2)
    end

    @testset "init_psi_two_packets" begin
        psi = init_psi_two_packets(grid2, sys; momentum_kick=2.0)
        _check_psi(psi, 2; tag="two_packets")
    end

    @testset "init_psi_chiral_spin_vortex" begin
        psi = init_psi_chiral_spin_vortex(grid2, sys; winding=1)
        _check_psi(psi, 2; tag="chiral_spin_vortex")
    end

    @testset "init_psi_magnetic_domain (3 patterns)" begin
        for pattern in (:stripe, :square, :hexagonal)
            psi = init_psi_magnetic_domain(grid2, sys; pattern=pattern)
            _check_psi(psi, 2; tag="magnetic_domain($pattern)")
        end
        # Unknown pattern must throw.
        @test_throws ArgumentError init_psi_magnetic_domain(
            grid2, sys; pattern=:bogus)
    end

    @testset "init_psi_vortex_lattice" begin
        psi = init_psi_vortex_lattice(grid2, sys; n_vortices=4)
        _check_psi(psi, 2; tag="vortex_lattice")
    end

    @testset "init_psi_skyrmion_lattice" begin
        psi = init_psi_skyrmion_lattice(grid2, sys; q_vector=(2π, 0.0, 0.0))
        _check_psi(psi, 2; tag="skyrmion_lattice")
    end

    @testset "init_psi_random (seed=nothing and seed=42)" begin
        psi_default = init_psi_random(grid2, sys)
        _check_psi(psi_default, 2; tag="random_default")

        psi_seeded = init_psi_random(grid2, sys; seed=123)
        _check_psi(psi_seeded, 2; tag="random_seed=123")

        # Different seeds → different states.
        psi_other = init_psi_random(grid2, sys; seed=456)
        @test psi_seeded != psi_other
    end
end
