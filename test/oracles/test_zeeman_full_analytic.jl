# test/oracles/test_zeeman_full_analytic.jl
#
# The merged ZeemanTerm is one operator H = −(b·F) + q·(b̂·F)², b = (bx,by,bz),
# b̂ = b/|b| (user spec, b_block_builders.jl). The quadratic is along the FIELD
# axis b̂ (physical: q is the field's own second-order shift; matches the
# rotating-basis convention) and reduces to q·F_z² when b ∥ ẑ. With the
# linear+transverse merge, ALL four coefficients live in one declaration, which
# closes the [GAP-1] class (a face that read only (bz,q) and dropped (bx,by)).
# Pin the full operator against the explicit matrix, all coefficients active at
# once, for F=1 and F=6.

using Test
using FFTW
using LinearAlgebra
using SpinorBEC
using SpinorBEC: ZeemanTerm, apply_operator!, spin_matrices

@testset "ZeemanTerm = −(bx·Fx+by·Fy+bz·Fz) + q·Fz²" begin
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
        Fx = Matrix(sm.Fx);
        Fy = Matrix(sm.Fy);
        Fz = Matrix(sm.Fz)
        bx, by, bz, q = 0.5, -0.3, 0.7, 0.2
        BdotF = bx * Fx + by * Fy + bz * Fz
        bmag2 = bx^2 + by^2 + bz^2
        # H = −(b·F) + q (b̂·F)²  (field-axis quadratic, b̂ = b/|b|)
        M = -BdotF + q * (BdotF * BdotF) / bmag2          # D×D Hermitian
        psi = randn(ComplexF64, 6, 6, 6, D)
        out = zero(psi)
        apply_operator!(out, ZeemanTerm(bx, by, bz, q), ws, psi)
        expected = similar(psi)
        @inbounds for I in CartesianIndices((6, 6, 6))
            expected[I, :] = M * psi[I, :]
        end
        @testset "F=$F" begin
            @test isapprox(out, expected; rtol=1e-12, atol=1e-12)
        end
    end
end
