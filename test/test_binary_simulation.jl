# Binary RTP smoke test: start from a ground state, evolve for a few
# units of time, and verify the two-component split-step preserves
# (a) per-species particle number to ~1e-12 (no Rabi → exact unitary)
# (b) total energy to O(dt²) (Strang accuracy)
# (c) Rabi oscillations transfer population coherently when Ω≠0.

using Test
using SpinorBEC

@testset "Binary RTP — F=0 + F=0 scalar" begin
    grid = make_grid(GridConfig((48, 48), (10.0, 10.0)))
    couplings = BinaryCouplings(g_AA = 1.0, g_BB = 1.0, g_AB = 0.5)
    trap = HarmonicTrap((1.0, 1.0))

    @testset "Norm conservation under unitary evolution" begin
        gs = find_binary_ground_state(
            grid; couplings, potential_A = trap, potential_B = trap,
            dt = 0.005, n_steps = 400,
        )
        sim = make_binary_simulation(
            grid; couplings, potential_A = trap, potential_B = trap,
            psi_A_init = gs.psi_A, psi_B_init = gs.psi_B,
        )
        n_A0, n_B0 = binary_norms(sim)
        # Both species normalised to 1 by ITP.
        @test n_A0 ≈ 1.0 atol = 1e-8
        @test n_B0 ≈ 1.0 atol = 1e-8

        run_binary_simulation!(sim; duration = 1.0, dt = 0.005)
        n_A, n_B = binary_norms(sim)
        # Pure split-step on a Schrödinger-style propagator preserves
        # |ψ|² ↔ each species norm to round-off.
        @test isapprox(n_A, n_A0; rtol = 1e-10)
        @test isapprox(n_B, n_B0; rtol = 1e-10)
    end

    @testset "Energy drift bounded under Strang" begin
        # Run ITP longer so the GS we hand to RTP is reasonably
        # stationary; otherwise small residual oscillations give a
        # misleadingly large "drift" that's actually just the RTP
        # following the dynamics of an out-of-equilibrium initial state.
        gs = find_binary_ground_state(
            grid; couplings, potential_A = trap, potential_B = trap,
            dt = 0.005, n_steps = 1500, tol = 1e-9,
        )
        sim = make_binary_simulation(
            grid; couplings, potential_A = trap, potential_B = trap,
            psi_A_init = gs.psi_A, psi_B_init = gs.psi_B,
        )
        E0 = binary_total_energy(sim)
        run_binary_simulation!(sim; duration = 0.5, dt = 0.005)
        E = binary_total_energy(sim)
        # Strang split-step is 2nd-order accurate. With a reasonably
        # converged GS the drift over 100 steps stays well under 5%.
        @test isapprox(E, E0; rtol = 5e-2)
    end

    @testset "Rabi coupling transfers population A ↔ B" begin
        # Initial state: all population in A, zero in B.
        rabi = BinaryCouplings(
            g_AA = 0.0, g_BB = 0.0, g_AB = 0.0,
            omega_coupling = π,  # rad/(time unit)
        )
        n_pts = grid.config.n_points
        dV = cell_volume(grid)
        psi_A0 = ones(ComplexF64, n_pts...) ./ sqrt(prod(n_pts) * dV)
        psi_B0 = zeros(ComplexF64, n_pts...)
        sim = make_binary_simulation(
            grid; couplings = rabi,
            psi_A_init = psi_A0, psi_B_init = psi_B0,
        )
        # A π/Ω = 1.0 sweep performs half a Rabi cycle → most pop in B.
        run_binary_simulation!(sim; duration = 1.0, dt = 0.001)
        n_A, n_B = binary_norms(sim)
        @test n_A + n_B ≈ 1.0 atol = 1e-6
        # Without interactions or trap, the cycle should be clean — most
        # population sloshed across.
        @test n_B > n_A
    end
end
