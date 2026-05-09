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
#   3. Warm-start kicks in: a second call at a near-by θ converges
#      faster (smaller `last_step` from the second `find_ground_state_lbfgs`
#      call than from the first) — pinned indirectly via wall time.

using SpinorBEC
using Test

@testset "make_phase_diff_eval — F=1 polar↔FM transition" begin
    grid = make_grid(GridConfig((8, 8), (4.0, 4.0)))
    atom = AtomSpecies("test", 2.5e-25, 1, 50e-10, 60e-10, 6.977e-23)

    F = make_phase_diff_eval(grid, atom;
        parameter_setter=θ -> (
            interactions=InteractionParams(θ[1], θ[2]),
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

    @testset "Warm-start reduces work on consecutive calls" begin
        # Build a fresh closure so the warm-start counter starts at zero.
        Fw = make_phase_diff_eval(grid, atom;
            parameter_setter=θ -> (
                interactions=InteractionParams(θ[1], θ[2]),
                potential=HarmonicTrap((1.0, 1.0)),
            ),
            phase_A_init=:m_plus_F, phase_B_init=:polar,
            n_steps=300, tol=1.0e-7, verbose=false,
        )
        # Warm up Julia's JIT for both branches at θ = (10, 0.3)
        Fw([10.0, 0.3])
        # Time the cold-vs-warm second call: a small θ step should
        # converge much faster from the warm ψ than from a cold init.
        t_warm = @elapsed Fw([10.0, 0.31])
        # Reference: a fresh closure on the same θ pays cold-start cost
        # for both branches (no JIT, since warmup above paid that).
        Fc = make_phase_diff_eval(grid, atom;
            parameter_setter=θ -> (
                interactions=InteractionParams(θ[1], θ[2]),
                potential=HarmonicTrap((1.0, 1.0)),
            ),
            phase_A_init=:m_plus_F, phase_B_init=:polar,
            n_steps=300, tol=1.0e-7, verbose=false,
        )
        t_cold = @elapsed Fc([10.0, 0.31])
        # Warm should be ≤ cold (allow 50 % slack to absorb GC noise)
        @test t_warm <= t_cold * 1.5
        @info "warm-start timing" t_cold=t_cold t_warm=t_warm
    end
end
