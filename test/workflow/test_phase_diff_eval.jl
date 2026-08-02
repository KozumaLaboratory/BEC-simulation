# --- make_phase_diff_eval regression (R35-bridge, 2026-05-02) ---
#
# Closure factory that turns SpinorBEC's L-BFGS solver into the
# scalar `F(θ)` that `trace_phase_boundary` expects. Tests pin:
#
#   1. The closure compiles and runs end-to-end on a 1-D F=1 problem
#      cheap enough to fit a unit test (~5 s wall time).
#   2. Sign of `F = E_FM − E_polar` matches the canonical F=1 spinor
#      transition: F > 0 for c₁ > 0 (polar wins), F < 0 for c₁ < 0
#      (FM wins). Catches mis-wired branch labels.
#   3. Warm-start is observationally neutral (it may not move F) and does
#      strictly less work, measured as `last_step` — the solver's own iteration
#      count. Until 2026-07-29 this was `@elapsed t_warm <= 1.5 * t_cold`, which
#      measures the machine, not the code: it went red at 0.348 s vs 0.070 s on
#      a loaded runner while the solver was converging in fewer iterations than
#      ever. A wall-clock assertion belongs in bench/, not in a correctness
#      suite. The claim worth defending is the one wall time cannot see — a warm
#      start that slides branch A into branch B's basin makes F collapse toward
#      zero while getting FASTER.

using SpinorBEC
using Test

@testset "make_phase_diff_eval — F=1 polar↔FM transition" begin
    grid = make_grid(GridConfig((8, 8), (4.0, 4.0)))
    atom = AtomSpecies("test", 2.5e-25, 1, 50e-10, 60e-10, 6.977e-23)

    F = make_phase_diff_eval(grid, atom;
        parameter_setter=θ -> (
            interactions=InteractionParams(Dict(0 => θ[1], 1 => θ[2])),
            potential=HarmonicTrap((1.0, 1.0)),
        ),
        phase_A_init=:m_plus_F,
        phase_B_init=:polar,
        n_steps=200, tol=1.0e-6,
        verbose=false,
    )

    @testset "Closure constructs and is callable" begin
        @test F isa Function
    end

    @testset "Sign matches physics" begin
        # c1 > 0 (antiferromagnetic) → polar wins → F = E_FM - E_polar > 0
        f_pos = F([10.0, 0.5])
        # c1 < 0 (ferromagnetic) → FM wins → F < 0
        f_neg = F([10.0, -0.5])
        @test f_pos > 0
        @test f_neg < 0
        # Magnitudes are the same order
        @test 0.1 < abs(f_pos) / abs(f_neg) < 10
    end

    _TOL = 1.0e-7
    _fresh_eval() = make_phase_diff_eval(grid, atom;
        parameter_setter=θ -> (
            interactions=InteractionParams(Dict(0 => θ[1], 1 => θ[2])),
            potential=HarmonicTrap((1.0, 1.0)),
        ),
        phase_A_init=:m_plus_F, phase_B_init=:polar,
        n_steps=300, tol=_TOL, verbose=false,
    )

    @testset "Warm start does not move F" begin
        # The failure mode warm-starting actually has: branch A, restarted from
        # its own previous ψ, slides into branch B's basin as θ moves, and F
        # collapses toward zero — while running FASTER, so any timing check
        # reads it as a success.
        θ = [10.0, 0.31]
        f_cold = _fresh_eval()(θ)

        Fw = _fresh_eval()
        Fw([10.0, 0.30])            # leaves both branches warm
        f_warm = Fw(θ)

        # Tolerance derived from the solver's own convergence tolerance, not
        # fitted: each branch energy is converged to ~`tol`, and F is their
        # difference, so 10·tol on the energy scale is the honest bound.
        @test isapprox(f_warm, f_cold; atol=10 * _TOL * max(1.0, abs(f_cold)))
        # …and the two branches must still be distinct minima.
        @test abs(f_warm) > 100 * _TOL
    end

    @testset "Warm start converges in fewer iterations" begin
        # `last_step` is the solver's own iteration count: deterministic, and
        # independent of machine load. See the header for why this is not
        # `@elapsed`.
        base = (; grid, atom,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => 0.31)),
            potential=HarmonicTrap((1.0, 1.0)),
            n_steps=300, tol=_TOL, verbose=false)
        cold = find_ground_state_lbfgs(; base..., initial_state=:polar)
        warm = find_ground_state_lbfgs(;
            base..., psi_init=copy(cold.workspace.state.psi))
        @test cold.last_step > 0            # the cold solve did real work
        @test warm.last_step < cold.last_step
    end
end
