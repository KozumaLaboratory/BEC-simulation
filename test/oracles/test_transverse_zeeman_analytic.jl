# test/oracles/test_transverse_zeeman_analytic.jl
#
# Analytic pin of the TRANSVERSE Zeeman operator: H = −bx·F_x − by·F_y
# (source of truth H_Zeeman = −(g_F μ_B B·F)). `apply_operator!` must equal
# that exact matrix acting voxel-wise. This is the locus of the 2026-06-04
# sign-inversion bug (propagator applied +bx,+by); a directional oracle
# already guards it, but this pins the full matrix (sign AND ladder
# coefficients) at machine precision for every F.

using Test
using FFTW
using LinearAlgebra
using SpinorBEC
using SpinorBEC: ZeemanTerm, apply_operator!, spin_matrices

@testset "TransverseZeeman = −bx·F_x − by·F_y" begin
    for (atom, F) in ((Rb87, 1), (Eu151, 6))
        grid = make_grid(GridConfig((6, 6, 6), (4.0, 4.0, 4.0)))
        ws = make_workspace(;
            grid, atom,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
            sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
            fft_flags=FFTW.ESTIMATE,
        )
        D = 2F + 1
        sm = spin_matrices(F)
        bx, by = 0.6, -0.4
        M = -bx * Matrix(sm.Fx) - by * Matrix(sm.Fy)   # D×D Hermitian
        psi = randn(ComplexF64, 6, 6, 6, D)
        out = zero(psi)
        apply_operator!(out, ZeemanTerm(bx, by, 0.0, 0.0), ws, psi)
        expected = similar(psi)
        @inbounds for I in CartesianIndices((6, 6, 6))
            expected[I, :] = M * psi[I, :]
        end
        @testset "F=$F" begin
            @test isapprox(out, expected; rtol=1e-12, atol=1e-12)
        end
    end
end
