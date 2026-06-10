# test/oracles/test_spin_density_consistency.jl
#
# `spin_density_vector` is the shared helper behind every spin observable
# and the c₁ / DDI mean fields. It must equal the per-voxel expectation
# f_α(r) = ψ(r)† F_α ψ(r) built directly from the spin matrices. A wrong
# ladder coefficient or a transposed component would silently bias all
# spin physics, so pin it for F=1 and F=6.

using Test
using LinearAlgebra
using SpinorBEC
using SpinorBEC: spin_density_vector, spin_matrices

@testset "spin_density_vector = ψ†·F_α·ψ per voxel" begin
    for (F, D) in ((1, 3), (6, 13))
        sm = spin_matrices(F)
        Fx = Matrix(sm.Fx);
        Fy = Matrix(sm.Fy);
        Fz = Matrix(sm.Fz)
        psi = randn(ComplexF64, 6, 6, 6, D)
        fx, fy, fz = spin_density_vector(psi, sm, 3)
        ex = zeros(6, 6, 6);
        ey = similar(ex);
        ez = similar(ex)
        @inbounds for I in CartesianIndices((6, 6, 6))
            v = psi[I, :]
            ex[I] = real(v' * Fx * v);
            ey[I] = real(v' * Fy * v);
            ez[I] = real(v' * Fz * v)
        end
        @testset "F=$F" begin
            @test isapprox(fx, ex; rtol=1e-12, atol=1e-12)
            @test isapprox(fy, ey; rtol=1e-12, atol=1e-12)
            @test isapprox(fz, ez; rtol=1e-12, atol=1e-12)
        end
    end
end
