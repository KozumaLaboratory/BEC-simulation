# TDHFB anomalous pair potential Δ kernel tests.
#
# Verifies:
#   1. Δ is symmetric in (c, c') for F ∈ {1, 3, 6}, random φ, random symmetric κ
#   2. Δ is linear in κ
#   3. Δ is quadratic in φ ⊗ φ at κ = 0  (Δ(2φ, 0) = 4 Δ(φ, 0))
#   4. F=1 polar |1,0⟩ vacuum (κ=0) — hand-derived expression
#   5. Singlet-only (g_S = {0 ⇒ 1}) — closed form pins sign convention
#
# Reference: src/hamiltonian/tdhfb/pair_potential.jl

using Test
using LinearAlgebra
using Random
using SpinorBEC

@testset "TDHFB pair potential Δ kernel" begin
    Random.seed!(2026)

    function random_symmetric_kappa(nx::Int, D::Int)
        kappa = zeros(ComplexF64, nx, D, D)
        for i in 1:nx
            A = randn(ComplexF64, D, D)
            S = (A + transpose(A)) / 2
            kappa[i, :, :] .= S
        end
        return kappa
    end

    @testset "Symmetry in (c, c') for F ∈ {1, 3, 6}" begin
        cases = [
            (1, Dict(0 => 1.0, 2 => 0.5)),
            (3, Dict(0 => 1.0, 2 => 0.3, 4 => -0.1, 6 => 0.05)),
            (
                6,
                Dict(
                    0 => 1.0,
                    2 => 0.05,
                    4 => -0.02,
                    6 => 0.01,
                    8 => -0.03,
                    10 => 0.02,
                    12 => 0.04,
                ),
            ),
        ]
        for (F, gS) in cases
            D = 2 * F + 1
            nx = 3
            phi = randn(ComplexF64, nx, D)
            kappa = random_symmetric_kappa(nx, D)

            Delta = pair_potential_generic(phi, kappa, F, gS)
            for i in 1:nx
                for c in 1:D, c_p in 1:D
                    @test abs(Delta[i, c, c_p] - Delta[i, c_p, c]) < 1e-10
                end
            end
        end
    end

    @testset "Linearity in κ" begin
        F = 3
        D = 7
        nx = 3
        gS = Dict(0 => 1.0, 2 => 0.5, 4 => 0.3, 6 => 0.2)
        phi = randn(ComplexF64, nx, D)
        kappa = random_symmetric_kappa(nx, D)

        Delta_0 = pair_potential_generic(phi, zero(kappa), F, gS)
        Delta_1 = pair_potential_generic(phi, kappa, F, gS)
        Delta_2 = pair_potential_generic(phi, 2 .* kappa, F, gS)

        lhs = Delta_2 .- Delta_0
        rhs = 2 .* (Delta_1 .- Delta_0)
        @test maximum(abs.(lhs .- rhs)) < 1e-10
    end

    @testset "Quadratic in φ at κ = 0" begin
        # Δ(2φ, 0) should equal 4 Δ(φ, 0)
        F = 3
        D = 7
        nx = 3
        gS = Dict(0 => 1.0, 2 => 0.5, 4 => 0.3, 6 => 0.2)
        phi = randn(ComplexF64, nx, D)
        kappa = zeros(ComplexF64, nx, D, D)

        Delta_1 = pair_potential_generic(phi, kappa, F, gS)
        Delta_2 = pair_potential_generic(2 .* phi, kappa, F, gS)
        @test maximum(abs.(Delta_2 .- 4 .* Delta_1)) < 1e-10
    end

    @testset "F=1 polar (|1, 0⟩, κ=0)" begin
        # phi = (0, 1, 0): only φ_{m=0} = 1, others zero.
        # Δ_{m,m'} = Σ V(m, m'; m2, m2') φ_{m2} φ_{m2'}.
        # The only non-zero pair has m2 = m2' = 0 (i.e. c2 = c2' = 2 for F=1).
        # By conservation m + m2 = m' + m2', this requires m = m' (since m2=m2'=0).
        # So Δ is diagonal, and Δ_{m,m} = V(m, m; 0, 0) · 1 · 1.
        F = 1
        D = 3
        nx = 2
        phi = zeros(ComplexF64, nx, D)
        phi[:, 2] .= 1.0  # m=0 component
        kappa = zeros(ComplexF64, nx, D, D)
        gS = Dict(0 => 1.0, 2 => 0.5)

        Delta = pair_potential_generic(phi, kappa, F, gS)
        V = channel_kernel(F, gS)

        # c2 = c2_p = 2 corresponds to m2 = m2_p = 0
        # c_to_m(c): c=1→m=+1, c=2→m=0, c=3→m=-1
        for i in 1:nx
            for c in 1:D, c_p in 1:D
                expected = V[c, c_p, 2, 2]  # only (c2, c2_p) = (2, 2) contributes
                @test abs(Delta[i, c, c_p] - expected) < 1e-12
            end
        end

        # Off-diagonal must vanish (since c ≠ c_p means m ≠ m' in this polar setup)
        for i in 1:nx, c in 1:D, c_p in 1:D
            c != c_p && @test abs(Delta[i, c, c_p]) < 1e-12
        end
    end

    @testset "Singlet-only (g_S = {0 ⇒ 1}) closed form" begin
        # Singlet projector P_0 = |0,0⟩⟨0,0|. CG ⟨F m, F m2 | 0 0⟩ = δ_{m2,-m} (-1)^(F-m) / √(2F+1).
        # The un-symmetrized channel kernel reduces to
        #   V(m, m'; m2, m2') = (1/(2F+1)) · δ_{m2,-m} δ_{m2',-m'} · (-1)^(2F-m-m')
        # Plugging into Δ_{m,m'} = Σ V (φ_{m2} φ_{m2'} + κ_{m2,m2'}),
        # and using (-1)^(2F-m-m') = (-1)^(m+m') (for integer F):
        #   Δ_{m,m'} = (1/(2F+1)) · (-1)^(m+m') · (φ_{-m} φ_{-m'} + κ_{-m,-m'})
        F = 3
        D = 7
        nx = 2
        phi = zeros(ComplexF64, nx, D)
        for i in 1:nx
            v = randn(ComplexF64, D)
            v ./= norm(v)
            phi[i, :] .= v
        end
        kappa = random_symmetric_kappa(nx, D)
        gS = Dict(0 => 1.0)

        Delta = pair_potential_generic(phi, kappa, F, gS)

        for i in 1:nx, c in 1:D, c_p in 1:D
            m = F + 1 - c
            m_p = F + 1 - c_p
            # -m has index c_to_m^{-1}(-m) = F + 1 - (-m) = F + 1 + m, but only valid
            # when |-m| ≤ F. For our c ∈ 1..D=2F+1, m ∈ -F..F so -m ∈ -F..F. Index is
            # c(-m) = F + 1 - (-m) = F + 1 + m.
            c_neg_m = F + 1 + m
            c_neg_mp = F + 1 + m_p
            phi_neg_m = phi[i, c_neg_m]
            phi_neg_mp = phi[i, c_neg_mp]
            kappa_negm_negmp = kappa[i, c_neg_m, c_neg_mp]
            sign_factor = (-1)^(m + m_p)
            expected = (1.0 / (2 * F + 1)) * sign_factor *
                       (phi_neg_m * phi_neg_mp + kappa_negm_negmp)
            @test abs(Delta[i, c, c_p] - expected) < 1e-10
        end
    end
end

@info "TDHFB pair potential kernel tests PASS"
