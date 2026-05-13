# Smoke test for TDHFBState Phase 1 implementation.
#
# Phase 1 scope: struct definition + basic constructors + sanity functions.
# Phase 2+ (kernels, integrators) tested separately when implemented.

using Test
using LinearAlgebra
using SpinorBEC

@testset "TDHFBState Phase 1 scaffold" begin
    # Setup: 1D grid, D=3 (F=1)
    N = 1
    D = 3
    spatial = (8,)  # 8-point 1D grid
    psi = ComplexF64.(randn(8, 3) + im * randn(8, 3))

    state = init_tdhfb_vacuum(psi)

    @testset "Construction + types" begin
        @test state isa TDHFBState
        # 2026-05-12: init_tdhfb_vacuum now copies psi by default
        # (alias=true opts back into reference-sharing). state.phi has
        # identical content but is a distinct array from psi.
        @test state.phi == psi
        @test state.phi !== psi
        @test size(state.rho) == (8, 3, 3)
        @test size(state.kappa) == (8, 3, 3)
        @test state.t == 0.0
        @test state.step == 0

        # alias=true preserves the old reference-sharing semantics
        state_aliased = init_tdhfb_vacuum(psi; alias=true)
        @test state_aliased.phi === psi
    end

    @testset "Vacuum initial state" begin
        @test all(iszero, state.rho)
        @test all(iszero, state.kappa)
    end

    @testset "Particle number computation" begin
        # Φ-only particle number (vacuum ρ adds nothing)
        N_total = tdhfb_total_particle_number(state; integration_weight=1.0)
        N_phi_expected = sum(abs2, psi)
        @test N_total ≈ N_phi_expected
    end

    @testset "Hermiticity check on vacuum (trivially zero)" begin
        rho_dev, kappa_dev = tdhfb_hermiticity_check(state)
        @test rho_dev < 1e-12
        @test kappa_dev < 1e-12
    end

    @testset "Hermiticity check on non-vacuum ρ" begin
        # Manually set ρ to a Hermitian matrix at each spatial point
        rho = state.rho
        for i in 1:size(rho, 1)
            # Hermitian random matrix
            A = randn(ComplexF64, 3, 3)
            H = (A + A') / 2
            rho[i, :, :] .= H
        end
        rho_dev, _ = tdhfb_hermiticity_check(state)
        @test rho_dev < 1e-12
    end

    @testset "Symmetric κ initialization" begin
        kappa = state.kappa
        for i in 1:size(kappa, 1)
            # Random symmetric matrix
            A = randn(ComplexF64, 3, 3)
            S = (A + transpose(A)) / 2
            kappa[i, :, :] .= S
        end
        _, kappa_dev = tdhfb_hermiticity_check(state)
        @test kappa_dev < 1e-12
    end
end

@info "TDHFBState Phase 1 smoke tests PASS"
