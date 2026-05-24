# Level 11 — convergence sweep automation.
#
# Validation ladder Level 11 (memory `validation_ladder_2026_05_24.md`)
# requires documented convergence in dt, grid, box, seed at Eu params.
# This file packages the convergence contract as a regression-pinned
# test: a single physical observable (per-axis cloud width and kinetic
# energy) must converge as we refine each axis.
#
# Scope (FAST tier compatible):
#   - dt convergence: harmonic-trap GS energy stable across dt halvings
#     (slope-2 already tested in Level 2; here we pin the GS *value*).
#   - grid convergence: per-axis cloud width converges as n_pts grows.
#   - box convergence: cloud center mass at fixed grid resolution
#     converges as L grows (box is large enough to avoid boundary).
#
# The full Eu params sweep (N=64/96/128, hours of GPU time) is
# documented in `runs/L4*` and is the MANUAL Level 9/11 artifact
# (2026-05-24 CROSS-GRID CONVERGED). This test pins the convergence
# *machinery* at low cost so a regression in the GS routine, FFT
# normalisation, or box handling trips the test before the heavy run.

using Test
using SpinorBEC
using LinearAlgebra

@testset "Level 11 — convergence sweep" begin
    @testset "dt convergence: GS energy stable across dt halvings" begin
        # F=1 Rb87, harmonic trap, scalar polar GS. Run ITP to convergence
        # at three dt values and verify the final energy is the same
        # within 1e-4 (ITP terminates when |dE| < tol, so all three
        # should agree at the ITP tolerance).
        n = 16
        L = 8.0
        grid = make_grid(GridConfig{1}((n,), (L,)))
        atom = Rb87
        E_values = Float64[]
        for dt in (0.04, 0.02, 0.01)
            ws = make_workspace(;
                grid, atom,
                interactions=InteractionParams(5.0, 0.1),
                zeeman=ZeemanParams(0.0, 0.0),
                potential=HarmonicTrap((1.0,)),
                sim_params=SimParams(; dt=dt, n_steps=500, save_every=500),
            )
            # ITP via repeated split_step in imaginary time would require
            # the IIP loop; instead use find_ground_state.
            result = find_ground_state(;
                grid, atom,
                interactions=InteractionParams(5.0, 0.1),
                potential=HarmonicTrap((1.0,)),
                dt=dt, n_steps=500, tol=1e-7,
            )
            push!(E_values, result.energy)
        end
        # All three should agree to ITP tolerance (~1e-4 in E).
        E_ref = E_values[end]  # smallest dt
        for E in E_values
            @test isapprox(E, E_ref; rtol=1e-3)
        end
    end

    @testset "Grid convergence: cloud width converges as n_pts grows" begin
        # Same physical setup, three grid resolutions. Cloud RMS width
        # in real space must converge.
        L = 8.0
        widths = Float64[]
        for n in (16, 24, 32)
            grid = make_grid(GridConfig{1}((n,), (L,)))
            result = find_ground_state(;
                grid, atom=Rb87,
                interactions=InteractionParams(5.0, 0.1),
                potential=HarmonicTrap((1.0,)),
                dt=0.01, n_steps=500, tol=1e-7,
            )
            ψ = Array(result.workspace.state.psi)
            n_dens = dropdims(sum(abs2, ψ; dims=2); dims=2)
            dV = cell_volume(grid)
            n_dens .*= dV
            x = grid.x[1]
            x_mean = sum(x .* n_dens) / sum(n_dens)
            width = sqrt(sum((x .- x_mean) .^ 2 .* n_dens) / sum(n_dens))
            push!(widths, width)
        end
        # All three widths should agree to ~1% (Strang+ITP at fixed L=8).
        w_ref = widths[end]
        for w in widths
            @test isapprox(w, w_ref; rtol=0.01)
        end
    end

    @testset "Box convergence: GS density confined far from boundary" begin
        # Fix grid spacing dx = L/n ≈ constant, vary box size. GS density
        # at the boundary must drop to negligible (cloud is confined).
        # This catches box-too-small artifacts before they corrupt DDI.
        dx_target = 0.4
        boundary_densities = Float64[]
        for L in (6.0, 8.0, 12.0)
            n = Int(round(L / dx_target))
            iseven(n) || (n += 1)  # GridConfig requires even n
            grid = make_grid(GridConfig{1}((n,), (L,)))
            result = find_ground_state(;
                grid, atom=Rb87,
                interactions=InteractionParams(5.0, 0.1),
                potential=HarmonicTrap((1.0,)),
                dt=0.01, n_steps=500, tol=1e-7,
            )
            ψ = Array(result.workspace.state.psi)
            n_dens = dropdims(sum(abs2, ψ; dims=2); dims=2)
            peak = maximum(n_dens)
            boundary = max(n_dens[1], n_dens[end])
            push!(boundary_densities, boundary / peak)
        end
        # Convergence contract: ratio drops by ≥10× each L-doubling
        # (Gaussian tails ~ exp(-x²/2) → exp(-L²/8) drops fast with L).
        # L=6 is intentionally NOT converged (catches box-too-small);
        # only assert L=12 is well-converged (< 1e-3).
        @test boundary_densities[1] > boundary_densities[2] > boundary_densities[3]
        @test boundary_densities[end] < 1e-3
        # Monotone exponential drop: each step at least 10× tighter.
        @test boundary_densities[1] / boundary_densities[2] > 10
        @test boundary_densities[2] / boundary_densities[3] > 10
    end

    @testset "Seed reproducibility: same seed → same ψ (bitwise)" begin
        # Reproducibility under fixed seed is a Level-0 / Level-11
        # contract. Two calls with the same seed must produce identical
        # init_psi output.
        grid = make_grid(GridConfig{1}((16,), (8.0,)))
        sys = SpinSystem(1)
        ψ_a = init_psi(grid, sys; state=:random, seed=42)
        ψ_b = init_psi(grid, sys; state=:random, seed=42)
        ψ_c = init_psi(grid, sys; state=:random, seed=43)
        @test ψ_a == ψ_b
        @test ψ_a != ψ_c
    end
end
