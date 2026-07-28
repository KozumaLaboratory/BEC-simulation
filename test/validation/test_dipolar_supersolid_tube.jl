# Type-C regression: dipolar supersolid in a periodic tube.
#
# Reference: S. M. Roccuzzo & F. Ancilotto, "Supersolid behaviour of a dipolar
# Bose-Einstein condensate confined in a tube", Phys. Rev. A 99, 041601(R)
# (2019), arXiv:1810.12229. Their simulations are ¹⁶⁶Er (§II: "In what follows m
# is the mass of a ¹⁶⁶Er atom" — the ¹⁶⁴Dy in the introduction is the Chomaz
# pancake experiment they cite for motivation, not their own geometry):
#
#   N = 6×10⁴, ω_y = ω_z = 2π·600 Hz, x periodic (tube), z the polarization axis
#   n₀ = N/L = 3.78×10³ µm⁻¹  ⇒  L = 15.873 µm
#   at ε_dd = 1.45: 11 droplets in the cell, d = L/11 = 1.443 µm
#   f_s < 1 once modulated, decreasing with ε_dd, → 0 in the droplet regime,
#   with a small jump at the uniform → modulated transition (first order)
#   LHY: γ(ε_dd) = (32/3√π)·g·a^{3/2}·F(ε_dd), F = Q₅ — same as this repo's
#
# The full reproduction is a ~100 min scan (see docs/validation/
# dipolar_supersolid_tube.md for the numbers). This file keeps the *cheap*
# invariants that would break first if the physics regressed: the coefficient
# chain that sets the regime, and the direction of the energy competition on a
# coarse grid. It deliberately does not re-derive the f_s curve.

using Test
using SpinorBEC
using StaticArrays: SVector

const _U = SpinorBEC.Units

_a_dd(atom) = _U.MU_0 * atom.mu_mag^2 * atom.mass / (12π * _U.HBAR^2)

@testset "Dipolar supersolid tube (Roccuzzo & Ancilotto 2019)" begin
    @testset "a_dd of the reference species" begin
        # Getting the species wrong is how this reproduction failed the first
        # time: ¹⁶⁴Dy has twice Er's a_dd, so at fixed ε_dd it puts a_s (and
        # hence γ ∝ a_s^{5/2}) in a different regime entirely and no supersolid
        # forms below ε_dd = 1.75.
        @test _a_dd(Er166) / _U.BOHR_RADIUS ≈ 65.0 atol = 1.0     # lit. 65.5 a₀
        @test _a_dd(Dy164) / _U.BOHR_RADIUS ≈ 130.5 atol = 1.5    # lit. 130.8 a₀
        @test _a_dd(Dy164) / _a_dd(Er166) > 1.9
    end

    @testset "Q₅ against closed forms" begin
        # γ carries Q₅(ε_dd), which is ~4.4 at ε_dd = 1.45 — a factor this size
        # decides whether the modulation survives, so it needs anchors outside
        # the quadrature itself.
        @test lima_pelster_Q5(0.0) == 1.0
        @test lima_pelster_Q5(1.0) ≈ 3^(5 / 2) / 6 rtol = 1e-4    # analytic
        for e in (0.05, 0.1)
            @test lima_pelster_Q5(e) ≈ 1 + 1.5e^2 rtol = 2e-3     # small-ε
        end
        @test lima_pelster_Q5(1.45) ≈ 4.385 rtol = 1e-3
    end

    @testset "tube geometry reproduces the paper's cell" begin
        N = 60_000
        n0_per_um = 3.78e3
        L_um = N / n0_per_um
        @test L_um ≈ 15.873 rtol = 1e-4
        @test L_um / 11 ≈ 1.443 rtol = 1e-3                       # droplet spacing

        a_ho = sqrt(_U.HBAR / (Er166.mass * 2π * 600.0))
        @test a_ho ≈ 3.186e-7 rtol = 1e-3
        @test L_um * 1e-6 / a_ho ≈ 49.8 rtol = 1e-2               # L in a_ho
    end

    @testset "modulation lowers the energy at ε_dd = 1.45, not at 1.30" begin
        # Coarse grid + short ITP: this cannot resolve f_s, but it does resolve
        # the SIGN of E_mod − E_unif, which is the statement that there is a
        # supersolid ground state at all. Runs in about a minute.
        N = 60_000
        w = 2π * 600.0
        a_ho = sqrt(_U.HBAR / (Er166.mass * w))
        a_dd = _a_dd(Er166)
        L = 15.873e-6 / a_ho
        nx, nt, Lt = 64, 24, 14.0
        grid = make_grid(GridConfig((nx, nt, nt), (L, Lt, Lt)))
        V = [
            0.5 * (grid.x[2][I[2]]^2 + grid.x[3][I[3]]^2)
            for I in CartesianIndices((nx, nt, nt))
        ]
        Bhat = SVector{3, Float64}(0.0, 0.0, 1.0)

        function relaxed_energy(eps_dd, modulated)
            a_s = a_dd / eps_dd
            ws = SpinorBEC.make_scalar_ws(
                grid, V;
                g_contact=4π * (a_s / a_ho) * N,
                c_dd=12π * (a_dd / a_ho) * N,
                F=1.0,
                gamma_lhy=scalar_lhy_coefficient(a_s / a_ho, N; eps_dd),
            )
            k11 = 11 * 2π / L
            for I in CartesianIndices(ws.psi)
                x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
                amp = modulated ? sqrt(1 + 0.9 * cos(k11 * x)) : 1.0
                ws.psi[I] = exp(-(y^2 + z^2) / 2) * amp + 0im
            end
            SpinorBEC.normalize_scalar!(ws)
            SpinorBEC.find_ground_state_scalar!(ws, 8_000, 5e-4; B_hat=Bhat)
            e = SpinorBEC.scalar_energies(ws, Bhat)
            rho = abs2.(ws.psi)
            nbar = [sum(view(rho,i,:,:)) / (nt * nt) for i in 1:nx]
            (E=e.total,
                contrast=(maximum(nbar) - minimum(nbar)) / (maximum(nbar) + minimum(nbar)))
        end

        u30, m30 = relaxed_energy(1.30, false), relaxed_energy(1.30, true)
        @test m30.E > u30.E - 1e-6            # below transition: no lower branch
        # The seed starts at contrast 0.9 and is decaying; 8k steps on this grid
        # take it to a few percent (the 30k-step production run reaches exactly
        # 0). Assert the decay, not full convergence — the sign of dE above is
        # what carries the physics here.
        @test m30.contrast < 0.05

        u45, m45 = relaxed_energy(1.45, false), relaxed_energy(1.45, true)
        @test m45.E < u45.E                   # supersolid IS the ground state
        @test m45.contrast > 0.3              # and genuinely modulated
        @test u45.contrast < 1e-3
    end
end
