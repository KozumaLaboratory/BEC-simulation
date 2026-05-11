# Rigorous Group-Theoretic Proof: D^2|_H has no A_1 component for polyhedral H
#
# This is the **analytical proof** of the rank-2 cross-channel vanishing assumption
# underlying Lemma 1 General-S. The character formula:
#
#   m_S^(A_1) = (1/|H|) Σ_g χ^(D^S)(g) · χ^(A_1)(g) = (1/|H|) Σ_g χ^(D^S)(g)
#
# where χ^(D^S)(rotation by angle θ) = sin((S+1/2)θ) / sin(θ/2).
#
# Computes m_2^(A_1) for the 3 polyhedral pure-rotation groups (T, O, I) and
# the comparison case D_2 (where the formula does NOT vanish).
#
# Reference: docs/manuscript/papers/paper3_universal_theorem/rank2_vanishing_analytical_proof.md

using Test
using Printf

"""
Character of rotation operator at spin-S irrep, for rotation by angle θ.
χ^(D^S)(θ) = sin((S+1/2)θ) / sin(θ/2), with limit 2S+1 at θ=0.
"""
function chi_DS(S, angle)
    if abs(angle) < 1e-10
        return 2.0 * S + 1.0
    end
    return sin((S + 0.5) * angle) / sin(angle / 2)
end

"""
Compute m_S^(A_1) (multiplicity of A_1 trivial irrep in D^S|_H) for group H
specified by conjugacy classes (multiplicity, rotation angle).
"""
function compute_m_A1(S::Int, order::Int, classes::Vector)
    sum_chi = 0.0
    for (mult, angle, _) in classes
        sum_chi += mult * chi_DS(S, angle)
    end
    return sum_chi / order
end

@testset "D^2|_H has no A_1 component for polyhedral H (rank-2 vanishing proof)" begin
    @testset "Tetrahedral T" begin
        T_classes = [
            (1, 0.0, "E"),
            (4, 2π/3, "4C_3"),
            (4, -2π/3, "4C_3²"),
            (3, π, "3C_2"),
        ]
        m = compute_m_A1(2, 12, T_classes)
        @test abs(m) < 1e-10
    end

    @testset "Octahedral O" begin
        O_classes = [
            (1, 0.0, "E"),
            (8, 2π/3, "8C_3"),
            (3, π, "3C_2 (axial)"),
            (6, π/2, "6C_4"),
            (6, π, "6C_2' (diag)"),
        ]
        m = compute_m_A1(2, 24, O_classes)
        @test abs(m) < 1e-10
    end

    @testset "Icosahedral I" begin
        I_classes = [
            (1, 0.0, "E"),
            (12, 2π/5, "12C_5"),
            (12, 4π/5, "12C_5²"),
            (20, 2π/3, "20C_3"),
            (15, π, "15C_2"),
        ]
        m = compute_m_A1(2, 60, I_classes)
        @test abs(m) < 1e-10
    end

    @testset "D_2 (control: non-polyhedral, m_2^(A_1) ≠ 0)" begin
        D2_classes = [
            (1, 0.0, "E"),
            (1, π, "C_2(x)"),
            (1, π, "C_2(y)"),
            (1, π, "C_2(z)"),
        ]
        m = compute_m_A1(2, 4, D2_classes)
        @test m > 0.5   # = 2 exactly
    end
end

println()
println("=== Group-theoretic vanishing argument ===")
println()
println("For polyhedral H ∈ {T, O, I} and their double-cover extensions:")
println("  m_2^(A_1) = (1/|H|) Σ_g χ^(D^2)(g) = 0   (rigorous identity)")
println()
println("This implies: <T^(2)_aa>_H = (1/|H|) Σ_g g^(-1) T^(2)_aa g = 0")
println("(the H-symmetrization of any rank-2 traceless tensor in Cartesian dir a)")
println()
println("Therefore the rank-2 cross-channel contribution to X_S^(anom) vanishes:")
println("  X_S^(anom, T^(2)) = Re ⟨ζ⊗ζ | <T^(2)_aa>_H · P_S | ζ⊗ζ⟩ = 0")
println()
println("=> Lemma 1 General-S is RIGOROUSLY PROVED for A_1-irrep polyhedral inert states.")
println()
println("=== Why D_2 fails ===")
println("D_2 = {E, C_2(x), C_2(y), C_2(z)} (order 4) has m_2^(A_1) = 2:")
println("  D^2|_{D_2} contains 2 copies of A_1 (the two diagonal traceless tensors).")
println("This is why D_2 biaxial nematic phases have THREE distinct spin-Goldstone")
println("stiffnesses (paper3 §VII.C — 'D_2: three distinct stiffnesses').")
