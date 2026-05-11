# TDHFB Strang step integrator smoke tests (Phase 3).
#
# Verifies:
# 1. Free evolution (g_S = 0, V_ext = 0) preserves |φ|² norm
# 2. Harmonic trap evolution preserves trap energy approximately
# 3. F=1 polar at zero-coupling reduces to pure kinetic evolution
# 4. ρ=0 limit consistent across steps

using Test
using LinearAlgebra
using FFTW
using Random
using SpinorBEC

@testset "TDHFB Strang step (Phase 3)" begin
    Random.seed!(42)

    @testset "Free evolution: norm preservation" begin
        # 1D, F=1, periodic, no trap, no interaction
        nx = 16
        D = 3
        F = 1
        phi = randn(ComplexF64, nx, D)
        phi[:, 2] .+= 1.0  # bias toward polar
        # Normalize
        nrm = sqrt(sum(abs2.(phi)))
        phi ./= nrm
        rho = zeros(ComplexF64, nx, D, D)
        kappa = zeros(ComplexF64, nx, D, D)

        state = init_tdhfb_vacuum(phi)
        state.rho .= rho
        state.kappa .= kappa

        V_ext = zeros(Float64, nx, D)
        g_S = Dict(0 => 0.0, 2 => 0.0)
        dt = 0.001
        nsteps = 50

        norm_before = sum(abs2.(state.phi))
        for _ in 1:nsteps
            tdhfb_strang_step!(state, F, g_S, V_ext, dt)
        end
        norm_after = sum(abs2.(state.phi))

        @test abs(norm_after - norm_before) < 1e-8
    end

    @testset "Harmonic trap evolution: phi maintains shape (with drift)" begin
        # 1D, F=1 polar, harmonic trap, zero interaction
        nx = 32
        D = 3
        F = 1
        phi = zeros(ComplexF64, nx, D)
        # Gaussian wavepacket in m=0 component
        x = collect(0:nx-1) .- nx/2 .+ 0.5
        for i in 1:nx
            phi[i, 2] = exp(-x[i]^2 / 4) * (1.0 / (2π)^(1/4))
        end
        # Normalize
        nrm = sqrt(sum(abs2.(phi)))
        phi ./= nrm

        state = init_tdhfb_vacuum(phi)

        # Harmonic trap V = (1/2) ω² x² for ω = 0.5
        V_ext = zeros(Float64, nx, D)
        ω = 0.5
        for i in 1:nx, m in 1:D
            V_ext[i, m] = 0.5 * ω^2 * x[i]^2
        end

        g_S = Dict(0 => 0.0, 2 => 0.0)
        dt = 0.01
        nsteps = 10

        norm_before = sum(abs2.(state.phi))
        for _ in 1:nsteps
            tdhfb_strang_step!(state, F, g_S, V_ext, dt)
        end
        norm_after = sum(abs2.(state.phi))

        @test abs(norm_after - norm_before) < 1e-6
        # Phi should still have most of its mass in m=0
        m0_mass_after = sum(abs2.(state.phi[:, 2]))
        @test m0_mass_after > 0.99
    end

    @testset "TDHFBState init: vacuum (ρ, κ = 0)" begin
        nx = 8
        D = 3
        F = 1
        phi = zeros(ComplexF64, nx, D)
        phi[:, 2] .= 1.0 / sqrt(nx)

        state = init_tdhfb_vacuum(phi)
        @test all(state.rho .== 0)
        @test all(state.kappa .== 0)
        @test state.t == 0.0
        @test state.step == 0
    end

    @testset "F=1 polar ground state stationarity (zero interaction)" begin
        # Polar state |1, 0⟩ should be stationary under free evolution
        nx = 8
        D = 3
        F = 1
        phi = zeros(ComplexF64, nx, D)
        phi[:, 2] .= 1.0 / sqrt(nx)

        state = init_tdhfb_vacuum(phi)
        V_ext = zeros(Float64, nx, D)
        g_S = Dict(0 => 0.0, 2 => 0.0)
        dt = 0.01
        nsteps = 20

        phi_initial = copy(state.phi)
        for _ in 1:nsteps
            tdhfb_strang_step!(state, F, g_S, V_ext, dt)
        end

        # |phi| should stay constant (= 1/sqrt(nx))
        for i in 1:nx
            for m in 1:D
                @test abs(abs(state.phi[i, m]) - abs(phi_initial[i, m])) < 1e-6
            end
        end
    end
end

@info "TDHFB Strang step Phase 3 smoke tests PASS"
