# GPU leg of the tabulated-LHY propagator gate (CPU leg:
# test/hamiltonian/test_tabulated_lhy_propagator_parity.jl).
#
# The fused GPU diagonal kernel accepts only Nothing / NoLHY / Float64 /
# ScalarLHY, so every TabulatedLHY falls back to the generic broadcast path.
# That path used to drop the table entirely, which meant every GPU run using
# polar_contact / fm_contact / icosahedral / polar_dipolar / fm_dipolar /
# polar_two_channel / full_bdg was running with NO LHY, silently. The existing
# per-term GPU/CPU parity oracle missed it because it never tried a tabulated
# LHY on a device.

using Test
using LinearAlgebra
using StaticArrays
import CUDA
using SpinorBEC
using SpinorBEC: _diagonal_step_svec!, _c0c1_to_gS

if !CUDA.functional()
    @info "CUDA not functional — skipping GPU tabulated-LHY parity"
else
    @testset "GPU == CPU for tabulated LHY" begin
        F, D, n = 6, 13, 8
        psi0 = randn(ComplexF64, n, n, n, D)
        zd = SVector{D, Float64}(zeros(D))
        g = _c0c1_to_gS(F, 10.0, 0.1)
        zoo = (
            "ScalarLHY" => ScalarLHY(0.5),
            "PolarContactLHY" => compute_spinor_lhy_polar_contact(;
                F, g_dict=g, n_max=200.0, n_points=200),
            "FMContactLHY" => compute_spinor_lhy_fm_contact(;
                F, g_dict=_c0c1_to_gS(F, 10.0, -0.02), n_max=200.0, n_points=200),
            "IcosahedralLHY" => compute_spinor_lhy_icosahedral(;
                F, g_dict=g, n_max=200.0, n_points=200),
            "PolarTwoChannelLHY" => compute_spinor_lhy_polar_two_channel(;
                F, c0=10.0, c1=0.1, n_max=200.0, n_points=200),
        )
        # Buffers must share an eltype across host and device or the comparison
        # measures Float32 rounding rather than the physics — `CUDA.zeros`
        # defaults to Float32 and cost me a false MISMATCH at 2e-6 first time.
        for (label, lhy) in zoo, it in (false, true)
            pc, mc = copy(psi0), copy(psi0)
            _diagonal_step_svec!(Val(3), pc, zeros(Float64, n, n, n), zd, 10.0,
                lhy, 0.001, zeros(Float64, n, n, n), it; psi_mf=mc)

            pg, mg = CUDA.CuArray(psi0), CUDA.CuArray(psi0)
            _diagonal_step_svec!(Val(3), pg, CUDA.zeros(Float64, n, n, n), zd,
                10.0, lhy, 0.001, CUDA.zeros(Float64, n, n, n), it; psi_mf=mg)
            CUDA.synchronize()

            @test maximum(abs.(Array(pg) .- pc)) < 1e-13
        end

        @testset "the LHY is actually present on the device" begin
            # Guards the failure mode that hid the bug: agreeing on zero.
            tbl = compute_spinor_lhy_polar_contact(;
                F, g_dict=g, n_max=200.0, n_points=200)
            outs = map((NoLHY(), tbl)) do lhy
                pg, mg = CUDA.CuArray(psi0), CUDA.CuArray(psi0)
                _diagonal_step_svec!(Val(3), pg, CUDA.zeros(Float64, n, n, n), zd,
                    10.0, lhy, 0.001, CUDA.zeros(Float64, n, n, n), false; psi_mf=mg)
                CUDA.synchronize()
                Array(pg)
            end
            @test maximum(abs.(outs[1] .- outs[2])) > 1e-3
        end

        @testset "a non-uniform density grid is refused, not mis-indexed" begin
            # The device lookup is O(1) index arithmetic, which is only valid on
            # the uniform grid the tabulators build.
            bad = SpinorBEC.PolarContactLHY([0.0, 1.0, 10.0], [0.0, 1.0, 2.0])
            @test_throws ArgumentError SpinorBEC._lhy_potential_field(
                bad, CUDA.zeros(Float64, 4), Float64)
        end
    end
end
