using Test
using SpinorBEC
using LinearAlgebra

@testset "Spin Matrices" begin
    @testset "Spin-1 basics" begin
        sm = spin_matrices(1)
        @test sm.system.F == 1
        @test sm.system.n_components == 3
        @test sm.system.m_values == [1, 0, -1]
    end

    # Hermiticity / commutators / Casimir for F=1..8 covered by the
    # property-based suite in test/test_property_based.jl.

    @testset "Fz eigenvalues" begin
        sm = spin_matrices(1)
        @test real(diag(Matrix(sm.Fz))) ≈ [1.0, 0.0, -1.0]
    end

    @testset "Spin-6 (Eu)" begin
        sm = spin_matrices(6)
        @test sm.system.n_components == 13
        @test sm.system.m_values == collect(6:-1:-6)
    end
end
