# test/oracles/test_magnetic_gradient_analytic.jl
#
# MagneticGradientTerm is a SPIN-INDEPENDENT linear potential
#   H_MG = g_F · grad · x_axis ⊗ 𝟙_spin      (same scalar for every m)
# (see src/hamiltonian/terms/magnetic_gradient.jl). It is NOT a true
# Stern–Gerlach gradient — no F_z factor. Its two analytic faces are
#   • apply_operator!  :  (H·ψ)_c[I] = (g_F·grad)·x_axis[I]·ψ_c[I]
#   • energy           :  E = g_F·grad·∫ x_axis·n_total(r) d³r
#
# Both are pinned here at machine precision, all spin components, for
# F=1 and F=6. The test is NON-trivial: the coefficient is g_F·grad
# (a sign/factor drift in either flips H·ψ), the multiplied field is
# x_axis along axis=1 (an index drift to the wrong axis changes every
# voxel since x[1] ≠ x[2] on this grid), and the energy folds the same
# coefficient against the density — a wrong sign/factor fails it.
#
# apply_operator! is a REAL implementation (accumulating gradient face),
# not a KNOWN-LIMIT no-op, so we pin it directly.

using Test
using FFTW
using LinearAlgebra
using SpinorBEC
using SpinorBEC: MagneticGradientTerm, apply_operator!, energy_contribution,
    MagneticGradient

@testset "MagneticGradientTerm = g_F·grad·x_axis (spin-independent)" begin
    axis = 1
    g_F = 1.3
    grad = 0.7
    coeff = g_F * grad

    for (atom, F) in ((Rb87, 1), (Eu151, 6))
        grid = make_grid(GridConfig((6, 6, 6), (4.0, 4.0, 4.0)))
        ws = make_workspace(;
            grid, atom,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
            magnetic_gradient=MagneticGradient{3}(grad, axis, g_F),
            sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
            fft_flags=FFTW.ESTIMATE,
        )
        D = 2F + 1
        dV = cell_volume(grid)
        x_axis = collect(grid.x[axis])      # coordinate along axis=1

        psi = randn(ComplexF64, 6, 6, 6, D)

        # Closed form: (H·ψ)_c[I] = coeff · x_axis[I[axis]] · ψ_c[I],
        # identical across all components. Energy folds x against density.
        expected = similar(psi)
        E_expected = 0.0
        @inbounds for I in CartesianIndices((6, 6, 6))
            xv = x_axis[I[axis]]
            n_I = 0.0
            for c in 1:D
                expected[I, c] = coeff * xv * psi[I, c]
                n_I += abs2(psi[I, c])
            end
            E_expected += xv * n_I
        end
        E_expected = coeff * E_expected * dV

        @testset "F=$F" begin
            out = zero(psi)
            apply_operator!(out, MagneticGradientTerm(), ws, psi)
            @test isapprox(out, expected; rtol=1e-12, atol=1e-12)

            E = energy_contribution(MagneticGradientTerm(), psi, ws)
            @test isapprox(E, E_expected; rtol=1e-12, atol=1e-12)

            # Non-triviality guard: with a real, non-uniform x_axis the
            # operator must actually move the state (not be a no-op).
            @test !isapprox(out, zero(psi); atol=1e-8)
        end
    end
end
