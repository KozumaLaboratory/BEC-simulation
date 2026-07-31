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

    @testset "Newton-CG polish tightens the gradient residual" begin
        # ASSERTED WHERE THE POLISH HAS ROOM TO WORK. This testset ran at
        # `n_steps=500, tol=1e-12` and asserted `< 0.5 ×`. At that tolerance the
        # pre-polish residual IS the finite-difference HvP's own noise floor, so
        # the assertion was measuring luck; measured ratio polish/lbfgs on the
        # same commit and problem, one process each:
        #
        #   0.156 | 0.081 ×3 | 1.000 (bit-identical no-op) | 1.998 (worse)
        #
        # The cause was a real defect in `hessian_vector_product`, since fixed:
        # it differenced at `ψ ± ε·δ` with ε ABSOLUTE, so with the CG iterates
        # Newton-CG passes (‖δ‖ ~ 1e-6 after an L-BFGS stage) the perturbation was
        # ~1e-11 and the quotient was noise amplified by 1/2ε. The step is now
        # taken along the normalised direction, which restores homogeneity — gated
        # in test/oracles/test_bdg_fd_hessian.jl.
        #
        # After the fix, at `n_steps=40, tol=1e-6` where L-BFGS stops at 6.299e-6
        # in EVERY process: ratio 2.6e-3 | 1.4e-4 | 2.6e-3. The bound below is
        # 1e-2 — four times looser than the worst of those and 100× below the 1.0
        # a no-op would give, so it separates "works" from "does nothing" without
        # pinning the value.
        #
        # Still open, and deliberately not asserted here: the L-BFGS residual
        # FLOOR itself varies across processes (3.907e-8 vs 1.259e-8 at
        # tol=1e-8), so a tight-tolerance comparison remains unsafe.
        grid = make_grid(GridConfig(128, 16.0))
        base = (;
            grid, atom=Rb87, interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            potential=HarmonicTrap(1.0),
            n_steps=40, tol=1e-6, initial_state=:polar, verbose=false,
        )
        r_lbfgs = find_ground_state_lbfgs(; base...)
        r_poly = find_ground_state_lbfgs(; base..., newton_polish=true)

        # The first-order stage stopped at its own tolerance, well above the FD
        # floor — otherwise the comparison below is back to measuring luck.
        @test r_lbfgs.grad_norm > 1e-7
        @test r_poly.grad_norm < 1e-2 * r_lbfgs.grad_norm
        # Variational: the polish may not raise the energy, and must not move it
        # away from the exact scalar-harmonic value.
        @test r_poly.energy <= r_lbfgs.energy + 1e-14
        @test abs(r_poly.energy - 0.5) < 1e-10
    end
end
