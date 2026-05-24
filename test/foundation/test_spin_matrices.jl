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

    @testset "Spin matrix structural sanity (per-F)" begin
        # Cause-isolation probes for the spin algebra primitives.
        # Catches bugs in:
        #   - m_values ordering (CLAUDE.md: c=1↔m=+F, c=D↔m=−F)
        #   - F̂_x, F̂_y tridiagonality (|c − c'| = 1 only)
        #   - F̂_z diagonality
        #   - F̂_z eigenvalues = m_values
        #   - F̂_+ |F,m⟩ = √(F(F+1)−m(m+1)) |F,m+1⟩
        #   - F² eigenvalue = F(F+1)
        # These are L0 sanity tests (cheap, catch convention regressions).
        for F in (1, 2, 3, 6)
            D = 2F + 1
            sm = spin_matrices(F)
            Fx = Matrix(sm.Fx)
            Fy = Matrix(sm.Fy)
            Fz = Matrix(sm.Fz)
            m_vals = sm.system.m_values

            # m-ordering: c=1 ↔ m=+F, c=D ↔ m=−F
            @test m_vals[1] == F
            @test m_vals[end] == -F

            # F̂_z is diagonal with values m_vals
            @test isdiag(Fz)
            @test real(diag(Fz)) ≈ Float64.(m_vals)
            @test maximum(abs, imag(diag(Fz))) < 1e-14

            # F̂_x, F̂_y are TRIDIAGONAL (|c − c'| = 1)
            for c in 1:D, cp in 1:D
                if abs(c - cp) > 1
                    @test abs(Fx[c, cp]) < 1e-14
                    @test abs(Fy[c, cp]) < 1e-14
                end
            end

            # F̂_+ |F,m⟩ = √(F(F+1) − m(m+1)) |F,m+1⟩
            # F̂_+ has nonzero on c-1, c block (raises m → m+1, c → c−1)
            Fplus = Fx + im * Fy
            for c in 2:D
                m = m_vals[c]
                expected = sqrt(F * (F + 1) - m * (m + 1))
                @test isapprox(Fplus[c - 1, c], expected; atol=1e-12)
            end

            # F² = F̂_x² + F̂_y² + F̂_z² = F(F+1)·I
            F_sq = Fx * Fx + Fy * Fy + Fz * Fz
            @test maximum(abs, F_sq - F * (F + 1) * I) < 1e-12

            # [F̂_x, F̂_y] = i F̂_z
            comm_xy = Fx * Fy - Fy * Fx
            @test maximum(abs, comm_xy - im * Fz) < 1e-12

            # Hermiticity
            @test maximum(abs, Fx - Fx') < 1e-14
            @test maximum(abs, Fy - Fy') < 1e-14
            @test maximum(abs, Fz - Fz') < 1e-14
        end
    end
end
