# test/oracles/test_spin_operator_algebra.jl
#
# The spin matrices must satisfy the su(2) algebra for every F used in the
# code (F=1…6, incl. ¹⁵¹Eu F=6). Any construction error in `spin_matrices`
# propagates into every spin term (Zeeman, c₁ spin-mixing, DDI, tensor), so
# pin the defining identities directly:
#   • Hermiticity:      F_a = F_a†
#   • commutator:       [F_x,F_y]=iF_z (and cyclic)
#   • Casimir:          F_x²+F_y²+F_z² = F(F+1)·I
#   • ladder spectrum:  F_z eigenvalues = F, F−1, …, −F

using Test
using LinearAlgebra
using SpinorBEC: spin_matrices

@testset "Spin operator algebra (su(2))" begin
    for F in 1:6
        sm = spin_matrices(F)
        Fx = Matrix(sm.Fx); Fy = Matrix(sm.Fy); Fz = Matrix(sm.Fz)
        D = 2F + 1
        Id = Matrix{ComplexF64}(I, D, D)
        @testset "F=$F" begin
            # Hermiticity
            @test isapprox(Fx, Fx'; atol=1e-12)
            @test isapprox(Fy, Fy'; atol=1e-12)
            @test isapprox(Fz, Fz'; atol=1e-12)
            # commutators [F_a,F_b] = i ε_abc F_c
            @test isapprox(Fx * Fy - Fy * Fx, im * Fz; atol=1e-12)
            @test isapprox(Fy * Fz - Fz * Fy, im * Fx; atol=1e-12)
            @test isapprox(Fz * Fx - Fx * Fz, im * Fy; atol=1e-12)
            # Casimir F² = F(F+1) I
            @test isapprox(Fx^2 + Fy^2 + Fz^2, F * (F + 1) * Id; atol=1e-10)
            # F_z spectrum = {F, …, −F}, ordered c=1→+F
            @test isapprox(real(diag(Fz)), Float64[F - (c - 1) for c in 1:D]; atol=1e-12)
        end
    end
end
