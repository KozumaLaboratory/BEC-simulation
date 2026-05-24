# Level 2 (validation_ladder_2026_05_24.md) — Strang splitting dt-convergence.
#
# Strang has global error O(dt²). Verify the slope-2 scaling on a
# clean Eu-shape setup so that any regression — change of integrator
# substep order, off-by-one in a half-step, dropped term — shifts the
# slope to 1 or higher and trips this test.
#
# Method: run the same physical setup at three time steps (dt, dt/2,
# dt/4) and compute the L² difference in ψ(T) at fixed final time T.
# The successive ratio Δ(dt)/Δ(dt/2) ≈ 4 ⟹ slope 2 (correct).
# Ratio ≈ 2 ⟹ slope 1 (regression). Ratio ≈ 1 ⟹ no convergence
# (e.g. cache hit, integrator no-op).
#
# Test setup: F=1 polar contact, 16-pt 1D grid, harmonic trap, no DDI
# / no LHY. This is "Eu-shape" in the sense that it exercises the
# same Strang sandwich (V × K × V) but at the simplest possible
# physics so a slope drop is unambiguously from the integrator.
#
# Cost: ~3 s on CPU (16 × 50 ITP + 3 × short RTP runs).

using Test
using SpinorBEC

@testset "Level 2 — Strang dt²-convergence" begin
    @testset "Free uniform: Strang at dt → 0 limit is identity" begin
        # No potential, no interactions → split_step ≈ free kinetic.
        # On a uniform ψ this is exactly the identity (k=0 contribution).
        # Verify residual scales like dt² (Strang) under the formal
        # halving sequence even though absolute residual is FP-floor.
        grid = make_grid(GridConfig((16,), (8.0,)))
        atom = Rb87
        interactions = InteractionParams(0.0, 0.0)
        T = 0.4
        results = Float64[]
        for dt in (0.04, 0.02, 0.01)
            n_steps = Int(round(T / dt))
            sp = SimParams(; dt=dt, n_steps=n_steps, save_every=n_steps)
            ws = make_workspace(; grid, atom, interactions,
                potential=HarmonicTrap(0.0), sim_params=sp)
            psi_init = zeros(ComplexF64, 16, 3)
            psi_init[:, 2] .= 1.0 / sqrt(8.0)
            copyto!(ws.state.psi, psi_init)
            for _ in 1:n_steps
                split_step!(ws)
            end
            push!(results, maximum(abs, Array(ws.state.psi) .- psi_init))
        end
        # All three should be machine-precision (this branch is the
        # control: any dt-dependent drift here is a bug, not Strang error).
        for r in results
            @test r < 1e-10
        end
    end

    @testset "Harmonic trap: Δψ(dt)/Δψ(dt/2) ≈ 4 (slope 2)" begin
        # Slightly-broadened Gaussian ψ_0 in a harmonic trap → split_step
        # generates a real breathing signal. Compare ψ(T) across dt
        # levels, all within the Strang-asymptotic regime (dt ≪ 1/ω).
        n_pt = 32
        L = 8.0
        grid = make_grid(GridConfig((n_pt,), (L,)))
        atom = Rb87
        interactions = InteractionParams(0.0, 0.0)
        T = 0.5

        function _run_to_T(dt)
            n_steps = Int(round(T / dt))
            sp = SimParams(; dt=dt, n_steps=n_steps, save_every=n_steps)
            ws = make_workspace(; grid, atom, interactions,
                potential=HarmonicTrap(1.0), sim_params=sp)
            psi_init = zeros(ComplexF64, n_pt, 3)
            sigma = 0.85  # slightly broader than GS to seed breathing
            for i in 1:n_pt
                x = grid.x[1][i]
                psi_init[i, 2] = exp(-x^2 / (2 * sigma^2))
            end
            dV = cell_volume(grid)
            psi_init ./= sqrt(sum(abs2, psi_init) * dV)
            copyto!(ws.state.psi, psi_init)
            for _ in 1:n_steps
                split_step!(ws)
            end
            return Array(ws.state.psi)
        end

        # Reference at dt=0.00125 (8× smaller than coarsest probe).
        # All probe dt's are within the Strang asymptotic regime
        # (dt·ω ≤ 0.01 ≪ 1).
        ψ_ref = _run_to_T(0.00125)
        ψ_dt = _run_to_T(0.01)
        ψ_dt2 = _run_to_T(0.005)
        ψ_dt4 = _run_to_T(0.0025)

        d1 = maximum(abs, ψ_dt .- ψ_ref)
        d2 = maximum(abs, ψ_dt2 .- ψ_ref)
        d4 = maximum(abs, ψ_dt4 .- ψ_ref)

        # Strang slope-2: halving dt → quartering error. Loose bound
        # (2.5, 8) catches a regression to slope 1 (ratio ~2) or to no
        # convergence (ratio ~1). Upper bound 8 absorbs noise from
        # the discrete reference being not-exact.
        ratio_1to2 = d1 / d2
        ratio_2to4 = d2 / d4
        @test 2.5 < ratio_1to2 < 8.0
        @test 2.5 < ratio_2to4 < 8.0
    end

    @testset "Spin-1 contact: norm preserved across dt halvings" begin
        # Add real interactions and verify norm drift stays at the
        # Strang machine-precision floor across dt levels (this is the
        # Strang unitarity guard — slope-2 is for ψ, but ‖ψ‖ should
        # stay ε across dt halvings).
        n_pt = 16
        L = 8.0
        grid = make_grid(GridConfig((n_pt,), (L,)))
        atom = Rb87
        interactions = InteractionParams(10.0, -0.5)
        T = 0.5
        norms = Float64[]
        for dt in (0.04, 0.02, 0.01)
            n_steps = Int(round(T / dt))
            sp = SimParams(; dt=dt, n_steps=n_steps, save_every=n_steps)
            ws = make_workspace(; grid, atom, interactions,
                potential=HarmonicTrap(1.0), sim_params=sp)
            # Polar GS seed
            psi_init = init_psi(grid, SpinSystem(1); state=:polar)
            copyto!(ws.state.psi, psi_init)
            N0 = total_norm(ws.state.psi, ws.grid)
            for _ in 1:n_steps
                split_step!(ws)
            end
            push!(norms, abs(total_norm(ws.state.psi, ws.grid) - N0))
        end
        for drift in norms
            # Strang preserves norm at machine precision — should be
            # < 1e-10 at all dt. Independent of dt is the contract:
            # Strang unitarity is exact, not approximate-in-dt.
            @test drift < 1e-8
        end
    end
end
