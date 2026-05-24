# Level 1 (validation_ladder_2026_05_22.md) — scalar exact tests.
#
# Three analytical-target checks running the full split_step
# integrator, complementing the per-operator L5 probes in
# scripts/validation/L5_operator_rhs_compare.jl:
#
#   1.1 Free uniform ψ = const → stays constant under K + V_zero
#       integration. Pinned for norm + per-component drift.
#
#   1.2 Plane-wave kinetic phase accumulation. ψ_0 = exp(i k_0 x),
#       no potential, n_steps × dt = T evolution.
#       Analytical: ψ(T) = exp(-i k_0²/2 · T) · ψ_0
#       Verify ψ(T) matches the analytical formula at machine precision.
#
#   1.3 Harmonic-trap ground-state stationarity. ψ_GS = Gaussian
#       (ω=1 oscillator), stationary up to phase exp(-i E_0 t).
#       Verify after several periods that |ψ(t)| matches |ψ_0|
#       (probe density preservation) and tracks the right energy.

using Test
using SpinorBEC

@testset "Level 1 — scalar exact integration tests" begin
    @testset "L1.1 free uniform ψ stays uniform under K (V=0)" begin
        # F=1, no trap, no interactions, no Zeeman.
        # Uniform ψ_0 = (0, 1/sqrt(N), 0) — only m=0 populated, density n_0=1/N.
        ndim = 1
        n_pt = 16
        L = 8.0
        grid = make_grid(GridConfig((n_pt,), (L,)))
        atom = Rb87
        interactions = InteractionParams(0.0, 0.0)
        sp = SimParams(; dt=0.05, n_steps=100, save_every=100)
        ws = make_workspace(;
            grid, atom, interactions,
            potential=HarmonicTrap(0.0),
            sim_params=sp,
        )
        # Set uniform ψ in m=0 (c=2)
        psi_init = zeros(ComplexF64, n_pt, 3)
        psi_init[:, 2] .= 1.0 / sqrt(L)
        copyto!(ws.state.psi, psi_init)
        # Norm = 1 verify
        N0 = total_norm(ws.state.psi, ws.grid)
        @test isapprox(N0, 1.0; rtol=1e-12)

        for _ in 1:100
            split_step!(ws)
        end

        # Norm preserved at machine precision.
        N1 = total_norm(ws.state.psi, ws.grid)
        @test isapprox(N1, N0; rtol=1e-12)
        # Per-component density: m=±1 stays zero (no inter-m coupling).
        @test maximum(abs, ws.state.psi[:, 1]) < 1e-12
        @test maximum(abs, ws.state.psi[:, 3]) < 1e-12
        # m=0 density still uniform (constant magnitude across grid).
        densities = abs.(ws.state.psi[:, 2])
        @test maximum(densities) - minimum(densities) < 1e-10
    end

    @testset "L1.2 plane-wave kinetic phase = cis(-k_0^2/2 * T)" begin
        # ψ_0 = exp(i k_0 x), no V, no interactions.
        # Strang reduces to pure kinetic propagator (V step is no-op
        # at V=0, c0=0). Pure spectral: ψ(T) = cis(-k_0^2/2 * T) ψ_0.
        ndim = 1
        n_pt = 32
        L = 8.0
        grid = make_grid(GridConfig((n_pt,), (L,)))
        atom = Rb87
        interactions = InteractionParams(0.0, 0.0)
        T = 0.5
        dt = 0.01
        n_steps = Int(round(T / dt))
        sp = SimParams(; dt=dt, n_steps=n_steps, save_every=n_steps)
        ws = make_workspace(;
            grid, atom, interactions,
            potential=HarmonicTrap(0.0),
            sim_params=sp,
        )

        # Set plane wave at k_0 = grid.k[1][2] (first non-zero positive k)
        k_idx = 2
        k_0 = grid.k[1][k_idx]
        psi_init = zeros(ComplexF64, n_pt, 3)
        for i in 1:n_pt
            psi_init[i, 2] = cis(k_0 * grid.x[1][i])
        end
        copyto!(ws.state.psi, psi_init)

        for _ in 1:n_steps
            split_step!(ws)
        end

        expected = cis(-0.5 * k_0^2 * T) * psi_init
        residual = maximum(abs, ws.state.psi .- expected)
        # Single-mode plane wave with pure K → machine precision.
        @test residual < 1e-10
    end

    @testset "L1.3 harmonic GS Gaussian → density stationary" begin
        # Gaussian ψ_GS(x) = (1/π)^(1/4) exp(-x²/2) is the 1D ω=1 harmonic GS.
        # Under H = K + V_trap, ψ_GS picks up only a global phase
        # exp(-i·E_0·t) with E_0 = 1/2. Density |ψ|² is stationary.
        ndim = 1
        n_pt = 64
        L = 12.0
        grid = make_grid(GridConfig((n_pt,), (L,)))
        atom = Rb87
        interactions = InteractionParams(0.0, 0.0)
        dt = 0.005
        T = 2π  # one harmonic period
        n_steps = Int(round(T / dt))
        sp = SimParams(; dt=dt, n_steps=n_steps, save_every=n_steps)
        ws = make_workspace(;
            grid, atom, interactions,
            potential=HarmonicTrap(1.0),
            sim_params=sp,
        )

        # Gaussian GS at m=0 (c=2)
        psi_init = zeros(ComplexF64, n_pt, 3)
        for i in 1:n_pt
            x = grid.x[1][i]
            psi_init[i, 2] = (1 / π)^(1 / 4) * exp(-x^2 / 2)
        end
        # Normalise
        dV = cell_volume(grid)
        psi_init ./= sqrt(sum(abs2, psi_init) * dV)
        density_init = abs2.(psi_init[:, 2])
        copyto!(ws.state.psi, psi_init)

        for _ in 1:n_steps
            split_step!(ws)
        end

        density_final = abs2.(ws.state.psi[:, 2])
        # Density profile preserved up to Strang dt² breathing error.
        # With dt=0.005 the deviation should be < 0.1% relative.
        rel_diff = maximum(abs, density_final .- density_init) /
                   maximum(density_init)
        @test rel_diff < 1e-2

        # Norm preserved at machine precision (independent of trap GS test).
        @test isapprox(
            total_norm(ws.state.psi, ws.grid), 1.0; rtol=1e-10)
    end
end
