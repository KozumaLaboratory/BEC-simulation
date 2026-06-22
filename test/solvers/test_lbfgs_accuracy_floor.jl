using Test
using SpinorBEC

# Regression gate for the L-BFGS ground-state accuracy floor.
#
# Before 2026-06-22 the L-BFGS solver could not reach its gradient floor:
# the shrink-only line search capped every step at α=0.01 (1% of the
# curvature-scaled, ≈Newton, two-loop direction), AND the two-loop
# recursion omitted the `·dV` factor that `rho_hist` carries — mis-scaling
# the direction by 1/dV. Together they stalled L-BFGS far above its floor:
# on the trivially-conditioned scalar harmonic GS it plateaued at
# E-error ≈ 1.9e-6 / |∇E| ≈ 4e-3 (vs the exact 0.5), while ITP reached
# 1e-12. These tests pin the post-fix behaviour — machine-precision energy
# and a true gradient floor — so the line-search / inner-product scaling
# cannot silently regress.

@testset "L-BFGS accuracy floor" begin
    @testset "scalar harmonic GS reaches machine-precision energy" begin
        # 1D ω=1 harmonic, no interactions: exact GS is the Gaussian with
        # E_0 = 0.5. The minimiser is smooth and well-conditioned, so any
        # competent optimiser should drive E to ~machine precision.
        grid = make_grid(GridConfig(128, 16.0))
        interactions = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
        trap = HarmonicTrap(1.0)

        r = find_ground_state_lbfgs(;
            grid, atom=Rb87, interactions, potential=trap,
            n_steps=500, tol=1e-10,
            initial_state=:polar, verbose=false,
        )

        # Pre-fix: errE ≈ 1.9e-6. Post-fix: < 1e-15. 1e-9 cleanly separates.
        @test abs(r.energy - 0.5) < 1e-9
        # Pre-fix: |∇E| ≈ 4e-3. Post-fix: < 1e-7 (F64 grid floor).
        @test r.grad_norm < 1e-6
    end

    @testset "L-BFGS reaches its floor within a small step budget" begin
        # A spinor F=1 problem with interactions + trap. L-BFGS should hit
        # its gradient floor quickly (≈100 steps) rather than crawling for
        # thousands. Pin: |∇E| floor reached by 200 steps, and the energy
        # is no worse than a deeply-converged ITP run (L-BFGS optimises the
        # exact functional, so it matches or beats split-step ITP).
        grid = make_grid(GridConfig(64, 16.0))
        interactions = InteractionParams(Dict(0 => 10.0, 1 => -0.5))
        trap = HarmonicTrap(1.0)

        r_itp = find_ground_state(;
            grid, atom=Rb87, interactions, potential=trap,
            dt=0.002, n_steps=20000, tol=1e-12,
            initial_state=:m_plus_F, verbose=false,
        )

        r = find_ground_state_lbfgs(;
            grid, atom=Rb87, interactions, potential=trap,
            n_steps=200, tol=1e-10,
            initial_state=:m_plus_F, verbose=false,
        )

        @test r.grad_norm < 1e-6
        # L-BFGS energy is at or below ITP's (allow tiny slack for ITP's
        # own residual). Pre-fix L-BFGS sat ABOVE ITP by ~1e-5.
        @test r.energy ≤ r_itp.energy + 1e-7
    end

    @testset "residual-Newton breaks the energy-comparison floor" begin
        # The L-BFGS line search and the energy-gated Newton-CG trust region
        # both floor the projected gradient at √eps·‖g‖ (~6e-8 here): a step
        # whose energy reduction (~‖∇E‖²/κ) drops below the energy roundoff
        # (~eps·|E|) can't be resolved. `residual_newton_refine` accepts steps
        # by the RESIDUAL norm instead (evaluable to ~eps·κ_max), so it breaks
        # that floor — down to the finite-difference HvP floor: eps^(2/3)≈2e-11
        # at order=2, eps^(4/5)≈1.6e-13 at order=4. (Gapped/in-basin only;
        # the scalar harmonic is the clean well-conditioned anchor.)
        grid = make_grid(GridConfig(128, 16.0))
        interactions = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
        trap = HarmonicTrap(1.0)

        r0 = find_ground_state_lbfgs(;
            grid, atom=Rb87, interactions, potential=trap,
            n_steps=500, tol=1e-12, initial_state=:polar, verbose=false,
        )
        ws = r0.workspace
        psi0 = copy(ws.state.psi)

        r2 = residual_newton_refine(ws, psi0; tol=1e-14, max_outer=40, max_cg=120,
            sobolev_alpha=0.04, ε=1e-5, hvp_order=2)
        r4 = residual_newton_refine(ws, psi0; tol=1e-15, max_outer=40, max_cg=120,
            sobolev_alpha=0.04, ε=6e-4, hvp_order=4)

        # order=2 → finite-difference HvP floor eps^(2/3)≈2e-11 (≫ below LBFGS).
        @test r2.grad_norm < 1e-10
        @test r2.grad_norm < 0.05 * r0.grad_norm
        # order=4 → eps^(4/5)≈1.6e-13.
        @test r4.grad_norm < 1e-11
        # Energy never regresses (already machine-exact).
        @test abs(r4.energy - 0.5) < 1e-12
    end

    @testset "Newton-CG polish tightens the gradient floor" begin
        # L-BFGS is first-order, so its projected gradient floors near
        # √(machine-eps)·scale even at a machine-exact energy. The opt-in
        # `newton_polish` second-order pass drives the stationarity residual
        # below that floor (≈10× on the scalar harmonic) without moving the
        # (already converged) energy.
        grid = make_grid(GridConfig(128, 16.0))
        interactions = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
        trap = HarmonicTrap(1.0)

        base = (;
            grid, atom=Rb87, interactions, potential=trap,
            n_steps=500, tol=1e-12, initial_state=:polar, verbose=false,
        )
        r_lbfgs = find_ground_state_lbfgs(; base...)
        r_poly = find_ground_state_lbfgs(; base..., newton_polish=true)

        # Polish lowers the gradient residual by a clear margin.
        @test r_poly.grad_norm < 0.5 * r_lbfgs.grad_norm
        # Energy stays at machine precision (polish must not regress it).
        @test abs(r_poly.energy - 0.5) < 1e-12
    end
end
