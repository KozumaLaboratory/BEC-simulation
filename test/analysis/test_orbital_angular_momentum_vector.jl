#!/usr/bin/env julia
#
# `orbital_angular_momentum_vector` — the three-component ⟨L⟩.
#
# The repo had only ⟨L_z⟩, which is enough while **B** ‖ z. Mechanical Larmor
# precession turns the cloud about **B**, so with B ⊥ z the in-plane components
# carry the rotation and ⟨L_z⟩ alone reads as a decay. This gates:
#   * z-component identity with the existing scalar `orbital_angular_momentum`
#     (same spectral derivatives, same no-Nyquist-null convention)
#   * correct axis assignment, by imprinting the SAME vortex about x, y and z and
#     asserting the unit vector lands on the right component. An
#     index-permutation bug is invisible in any single-axis test.
#   * charge and sign: ℓ = ±1, ±2.

using SpinorBEC
using FFTW
using Test

"Gaussian with a charge-ℓ vortex about `axis`, in the plane perpendicular to it."
function _vortex_psi(grid::Grid{3}, F::Int, l::Int, axis::Symbol)
    n_pts = grid.config.n_points
    D = 2F + 1
    psi = zeros(ComplexF64, n_pts..., D)
    # (a, b) = the plane the phase winds in, right-handed about `axis`
    ia, ib = if axis === :z
        (1, 2)
    elseif axis === :x
        (2, 3)
    else
        (3, 1)
    end
    @inbounds for I in CartesianIndices(n_pts)
        r = (grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]])
        env = exp(-(r[1]^2 + r[2]^2 + r[3]^2) / (2 * 1.5^2))
        rho = sqrt(r[ia]^2 + r[ib]^2)
        psi[I, 1] = env * rho^abs(l) * cis(l * atan(r[ib], r[ia]))
    end
    psi ./ sqrt(sum(abs2, psi) * cell_volume(grid))
end

@testset "orbital_angular_momentum_vector" begin
    grid = make_grid(GridConfig{3}((40, 40, 40), (12.0, 12.0, 12.0)))
    plans = make_fft_plans(grid.config.n_points; flags=FFTW.ESTIMATE)

    @testset "axis assignment, l=$l" for l in (1, -1, 2)
        for (axis, idx) in ((:x, 1), (:y, 2), (:z, 3))
            L = orbital_angular_momentum_vector(_vortex_psi(grid, 1, l, axis), grid, plans)
            @test L[idx] ≈ l rtol = 2e-2
            for other in setdiff(1:3, idx)
                @test abs(L[other]) < 1e-8
            end
        end
    end

    @testset "z component matches the scalar orbital_angular_momentum" begin
        for l in (1, -1, 2), axis in (:x, :y, :z)
            psi = _vortex_psi(grid, 1, l, axis)
            @test orbital_angular_momentum_vector(psi, grid, plans)[3] ≈
                orbital_angular_momentum(psi, grid, plans) rtol = 1e-12
        end
    end

    @testset "sums over spinor components" begin
        # two components carrying different charges: ⟨L_z⟩ is population-weighted
        psi = zeros(ComplexF64, 40, 40, 40, 3)
        p1 = _vortex_psi(grid, 1, 1, :z)
        p2 = _vortex_psi(grid, 1, 2, :z)
        psi[:, :, :, 1] .= p1[:, :, :, 1] ./ sqrt(2)
        psi[:, :, :, 3] .= p2[:, :, :, 1] ./ sqrt(2)
        L = orbital_angular_momentum_vector(psi, grid, plans)
        @test L[3] ≈ 1.5 rtol = 2e-2
    end

    @testset "2D falls back to (0, 0, Lz)" begin
        g2 = make_grid(GridConfig{2}((40, 40), (12.0, 12.0)))
        p2 = make_fft_plans(g2.config.n_points; flags=FFTW.ESTIMATE)
        psi = zeros(ComplexF64, 40, 40, 3)
        @inbounds for I in CartesianIndices((40, 40))
            x, y = g2.x[1][I[1]], g2.x[2][I[2]]
            psi[I, 1] = exp(-(x^2 + y^2) / (2 * 1.5^2)) * sqrt(x^2 + y^2) * cis(atan(y, x))
        end
        psi ./= sqrt(sum(abs2, psi) * cell_volume(g2))
        L = orbital_angular_momentum_vector(psi, g2, p2)
        @test L[1] == 0.0 && L[2] == 0.0
        @test L[3] ≈ orbital_angular_momentum(psi, g2, p2)
    end
end
