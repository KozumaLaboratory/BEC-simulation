# TDHFB HF matrix kernel smoke test (Phase 2 minimal).

using Test
using LinearAlgebra

# Direct include since TDHFB not yet exported from SpinorBEC umbrella
include(joinpath(@__DIR__, "..", "src", "foundation", "types", "tdhfb_state.jl"))
include(joinpath(@__DIR__, "..", "src", "hamiltonian", "tdhfb", "hartree_fock_matrix.jl"))

@testset "TDHFB HF matrix F=1 Phase 2" begin
    @testset "Vacuum polar state h^HF = c_0 I" begin
        # Polar state |1, 0⟩ at every spatial point
        nx = 4
        phi = zeros(ComplexF64, nx, 3)
        phi[:, 2] .= 1.0 + 0im
        rho = zeros(ComplexF64, nx, 3, 3)
        kappa = zeros(ComplexF64, nx, 3, 3)

        c0 = 1.0
        c1 = 0.1

        h_hf = hf_matrix_F1(phi, rho, kappa, c0, c1)

        for i in 1:nx, m in 1:3, m_prime in 1:3
            expected = (m == m_prime) ? c0 : 0.0
            @test abs(h_hf[i, m, m_prime] - expected) < 1e-12
        end
    end

    @testset "Ferromagnetic state ⟨F_z⟩ = 1" begin
        # FM state |1, +1⟩
        nx = 4
        phi = zeros(ComplexF64, nx, 3)
        phi[:, 1] .= 1.0 + 0im  # m=+1
        rho = zeros(ComplexF64, nx, 3, 3)
        kappa = zeros(ComplexF64, nx, 3, 3)

        c0 = 1.0
        c1 = 0.1

        h_hf = hf_matrix_F1(phi, rho, kappa, c0, c1)

        # FM: |φ|² = 1, ⟨F_x⟩ = ⟨F_y⟩ = 0, ⟨F_z⟩ = 1
        # h^HF = c_0 · 1 · I + c_1 · 1 · F_z = diag(c_0+c_1, c_0, c_0-c_1)
        for i in 1:nx
            @test abs(h_hf[i, 1, 1] - (c0 + c1)) < 1e-12  # m=+1: c_0 + c_1·(+1) = c_0+c_1
            @test abs(h_hf[i, 2, 2] - c0) < 1e-12          # m=0: c_0 + c_1·0 = c_0
            @test abs(h_hf[i, 3, 3] - (c0 - c1)) < 1e-12  # m=-1: c_0 + c_1·(-1) = c_0-c_1
            @test abs(h_hf[i, 1, 2]) < 1e-12               # off-diagonals: 0
            @test abs(h_hf[i, 2, 1]) < 1e-12
        end
    end

    @testset "Hermiticity of h^HF" begin
        # Random complex spinor at every point, random ρ, κ
        nx = 4
        phi = randn(ComplexF64, nx, 3)
        # rho must be Hermitian for physical input
        rho_seed = randn(ComplexF64, nx, 3, 3)
        rho = similar(rho_seed)
        for i in 1:nx
            r_mat = rho_seed[i, :, :]
            rho[i, :, :] = (r_mat + r_mat') / 2
        end
        kappa = zeros(ComplexF64, nx, 3, 3)

        c0 = 1.0
        c1 = 0.1

        h_hf = hf_matrix_F1(phi, rho, kappa, c0, c1)

        for i in 1:nx
            h_mat = h_hf[i, :, :]
            herm_dev = norm(h_mat - h_mat')
            @test herm_dev < 1e-10
        end
    end

    @testset "Linear-in-rho test" begin
        # h^HF[φ, c·ρ] - h^HF[φ, 0] should scale linearly in c
        nx = 4
        phi = randn(ComplexF64, nx, 3)
        rho_base = randn(ComplexF64, nx, 3, 3)
        # Symmetrize
        for i in 1:nx
            r_mat = rho_base[i, :, :]
            rho_base[i, :, :] = (r_mat + r_mat') / 2
        end
        kappa = zeros(ComplexF64, nx, 3, 3)

        c0 = 1.0
        c1 = 0.1

        h_0 = hf_matrix_F1(phi, zero(rho_base), kappa, c0, c1)
        h_1 = hf_matrix_F1(phi, rho_base, kappa, c0, c1)
        h_2 = hf_matrix_F1(phi, 2 * rho_base, kappa, c0, c1)

        # Linear: h_2 - h_0 = 2 (h_1 - h_0)
        lhs = h_2 - h_0
        rhs = 2 * (h_1 - h_0)
        @test maximum(abs.(lhs - rhs)) < 1e-10
    end
end

@info "TDHFB HF matrix Phase 2 smoke tests PASS"
