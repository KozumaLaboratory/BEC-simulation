# Level 3 (validation_ladder_2026_05_24.md) — Zeeman-only dynamics.
#
# Pure-Zeeman test: kinetic uniform, no interactions, no DDI, no LHY.
# Linear + quadratic Zeeman act diagonally on each m component:
#
#   H_Z ψ_m = (-p · m + q · m²) ψ_m
#
# Theory:
#   N_m(t) = const                  (populations frozen, diagonal H)
#   ψ_m(t) = exp(-i(-p·m + q·m²)·t) · ψ_m(0)
#                                   (phase analytical to machine ε)
#
# A failure here means: linear vs quadratic Zeeman sign mixed up,
# m ordering inverted (c=1 should be m=+F), or off-by-one in the
# split-step Zeeman substep.

using Test
using SpinorBEC

@testset "Level 3 — Zeeman-only dynamics" begin
    @testset "L3.1 Populations frozen under Zeeman-only" begin
        # F=1, 3 components. Set ψ_m = 1/sqrt(3) for each m, uniform
        # in space. With p, q ≠ 0 the populations N_m = |ψ_m|² should
        # stay 1/3 each across the evolution (diagonal H_Z).
        n_pt = 8
        L = 4.0
        grid = make_grid(GridConfig((n_pt,), (L,)))
        atom = Rb87
        interactions = InteractionParams(0.0, 0.0)
        zeeman = ZeemanParams(0.7, 0.3)  # arbitrary p, q
        sp = SimParams(; dt=0.01, n_steps=100, save_every=100)
        ws = make_workspace(; grid, atom, interactions, zeeman,
            potential=HarmonicTrap(0.0), sim_params=sp)

        psi_init = zeros(ComplexF64, n_pt, 3)
        for c in 1:3
            psi_init[:, c] .= 1.0 / sqrt(3 * L)
        end
        copyto!(ws.state.psi, psi_init)

        # Initial per-component norms.
        dV = cell_volume(grid)
        N_m_init = [sum(abs2, ws.state.psi[:, c]) * dV for c in 1:3]
        @test all(isapprox.(N_m_init, 1 / 3; rtol=1e-12))

        for _ in 1:100
            split_step!(ws)
        end

        N_m_final = [sum(abs2, ws.state.psi[:, c]) * dV for c in 1:3]
        for (Ni, Nf) in zip(N_m_init, N_m_final)
            @test isapprox(Ni, Nf; rtol=1e-10)
        end
    end

    @testset "L3.2 Phase per component matches exp(-i(-p·m+q·m²)·t)" begin
        # Same setup as L3.1 but verify the analytical phase formula
        # at the final time. m=+1 (c=1), m=0 (c=2), m=-1 (c=3) under
        # H_Z ψ_m = (-p·m + q·m²) ψ_m.
        #
        # Note: m=0 has H_Z=0, so it's a "control" — the m=0 component
        # should pick up zero phase across the Zeeman-only evolution.
        n_pt = 8
        L = 4.0
        grid = make_grid(GridConfig((n_pt,), (L,)))
        atom = Rb87
        interactions = InteractionParams(0.0, 0.0)
        p = 0.5
        q = 0.2
        zeeman = ZeemanParams(p, q)
        T = 1.0
        dt = 0.005
        n_steps = Int(round(T / dt))
        sp = SimParams(; dt=dt, n_steps=n_steps, save_every=n_steps)
        ws = make_workspace(; grid, atom, interactions, zeeman,
            potential=HarmonicTrap(0.0), sim_params=sp)

        psi_init = zeros(ComplexF64, n_pt, 3)
        for c in 1:3
            psi_init[:, c] .= 1.0 / sqrt(3 * L)
        end
        copyto!(ws.state.psi, psi_init)

        for _ in 1:n_steps
            split_step!(ws)
        end

        # m values in our descending convention: c=1 → m=+1, c=2 → m=0, c=3 → m=-1
        for (c, m) in ((1, +1), (2, 0), (3, -1))
            energy_m = -p * m + q * m^2
            expected_phase = cis(-energy_m * T)
            actual_phase = ws.state.psi[1, c] / psi_init[1, c]
            @test isapprox(actual_phase, expected_phase; rtol=1e-6)
        end
    end

    @testset "L3.3 m ordering: c=1 picks up phase for m=+F" begin
        # Sign sanity. With p > 0 and q = 0: ψ_{m=+F} acquires phase
        # exp(-i·(-p·F)·T) = exp(+i·p·F·T) — positive imaginary phase.
        # c=1 must be m=+F per our convention.
        n_pt = 8
        L = 4.0
        grid = make_grid(GridConfig((n_pt,), (L,)))
        F = 1
        atom = Rb87
        interactions = InteractionParams(0.0, 0.0)
        p = 0.4
        zeeman = ZeemanParams(p, 0.0)
        T = 1.5
        dt = 0.01
        n_steps = Int(round(T / dt))
        sp = SimParams(; dt=dt, n_steps=n_steps, save_every=n_steps)
        ws = make_workspace(; grid, atom, interactions, zeeman,
            potential=HarmonicTrap(0.0), sim_params=sp)
        psi_init = zeros(ComplexF64, n_pt, 3)
        for c in 1:3
            psi_init[:, c] .= 1.0 / sqrt(3 * L)
        end
        copyto!(ws.state.psi, psi_init)
        for _ in 1:n_steps
            split_step!(ws)
        end
        # c=1 should have picked up phase angle = +p·F·T > 0 (mod 2π)
        m_top = F  # +F under descending m ordering
        phase_top = angle(ws.state.psi[1, 1] / psi_init[1, 1])
        expected = mod2pi(+p * m_top * T)
        actual = mod2pi(phase_top)
        # Loose tolerance because mod2pi wraps; check both directions
        # in case the convention sign is reversed.
        diff_correct = abs(actual - expected)
        diff_wrong = abs(actual - mod2pi(-p * m_top * T))
        @test diff_correct < diff_wrong
        @test diff_correct < 1e-4
    end

    @testset "L3.4 Quadratic Zeeman q ≠ 0: m=±F same shift, m=0 zero" begin
        # H_Z^quad acts as +q·m² → m=+1 and m=-1 acquire the SAME
        # phase shift q·1²·T, while m=0 acquires zero phase shift.
        n_pt = 8
        L = 4.0
        grid = make_grid(GridConfig((n_pt,), (L,)))
        atom = Rb87
        interactions = InteractionParams(0.0, 0.0)
        q = 0.3
        zeeman = ZeemanParams(0.0, q)
        T = 0.8
        dt = 0.01
        n_steps = Int(round(T / dt))
        sp = SimParams(; dt=dt, n_steps=n_steps, save_every=n_steps)
        ws = make_workspace(; grid, atom, interactions, zeeman,
            potential=HarmonicTrap(0.0), sim_params=sp)
        psi_init = zeros(ComplexF64, n_pt, 3)
        for c in 1:3
            psi_init[:, c] .= 1.0 / sqrt(3 * L)
        end
        copyto!(ws.state.psi, psi_init)
        for _ in 1:n_steps
            split_step!(ws)
        end
        phase_top = angle(ws.state.psi[1, 1] / psi_init[1, 1])
        phase_bot = angle(ws.state.psi[1, 3] / psi_init[1, 3])
        phase_mid = angle(ws.state.psi[1, 2] / psi_init[1, 2])

        # m=±F phases must be equal (q·F² for both).
        @test isapprox(phase_top, phase_bot; atol=1e-10)
        # m=0 phase must be near zero.
        @test abs(phase_mid) < 1e-6
        # Magnitude check: expected phase = -q·F²·T (since H_Z phi=q m² ψ
        # → exp(-i q m² T) ψ → angle = -q m² T mod 2π).
        expected = mod2pi(-q * 1 * T)
        @test isapprox(mod2pi(phase_top), expected; atol=1e-4)
    end
end
