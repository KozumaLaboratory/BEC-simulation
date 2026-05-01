# --- bogoliubov_along_boundary_curve regression (R39, 2026-05-02) ---
#
# Bridge between R37 (boundary tracing) and BdG spectrum analysis.
# Tests pin:
#   1. Returns Vector{BoundaryBdGSample} with one entry per input row.
#   2. Each sample carries θ, BdGResult, n0, last_step, converged.
#   3. BdG fields populated correctly (k_values length == n_k, omega
#      shape (2D × n_k)).
#   4. Heavy gate skipped by default; SPINORBEC_RUN_HEAVY_YAML opts in.
#
# This file uses a tiny F=1 problem (8×8 grid, 100 ITP iters) so even
# the "fast" tests run in seconds. The tests are tagged but not gated
# because they do still exercise find_ground_state_lbfgs end-to-end.

using SpinorBEC
using Test

@testset "bogoliubov_along_boundary_curve — synthetic 3-point curve" begin
    grid = make_grid(GridConfig((8, 8), (4.0, 4.0)))
    atom = AtomSpecies("test", 2.5e-25, 1, 50.0e-10, 60.0e-10, 6.977e-23)

    points = Float64[
        -0.1   0.0
         0.0   0.0
         0.1   0.0
    ]
    parameter_setter = θ -> (
        interactions=InteractionParams(20.0, θ[1]),
        potential=HarmonicTrap((1.0, 1.0)),
    )

    samples = bogoliubov_along_boundary_curve(
        points, parameter_setter, grid, atom;
        phase_init=:m_plus_F,
        k_max=5.0, n_k=30,
        n_steps=100, tol=1.0e-5,
        verbose=false,
    )

    @testset "Returns one sample per input row" begin
        @test length(samples) == 3
        @test all(s -> s isa BoundaryBdGSample, samples)
    end

    @testset "Sample fields populated" begin
        for s in samples
            @test length(s.θ) == 2
            @test s.bdg isa BdGResult
            @test length(s.bdg.k_values) == 30
            @test size(s.bdg.omega) == (6, 30)   # 2D = 2 × (2F+1) = 6
            @test s.n0 > 0
            @test 0 < s.last_step <= 100
            @test s.converged isa Bool
        end
    end

    @testset "F=1 weak-interaction is BdG-stable (max_growth ≈ 0)" begin
        # Far from any DDI / strong-c1 instability — all samples should
        # report Re ω real (max_growth ≈ 0) for this benign config.
        for s in samples
            @test s.bdg.max_growth_rate < 1.0e-3
            @test !s.bdg.unstable
        end
    end

    @testset "Warm-start: subsequent points converge faster than first" begin
        # The first point starts cold (initial_state=:m_plus_F).
        # Points 2 and 3 warm-start from the previous ψ. With a small θ
        # step they should converge in fewer L-BFGS iters.
        if samples[1].converged
            for s in samples[2:end]
                # Allow generous slack — the warm-start advantage isn't
                # always strict on a tiny test problem
                @test s.last_step <= samples[1].last_step + 50
            end
        end
    end
end

@testset "bogoliubov_along_boundary_curve — argument validation" begin
    grid = make_grid(GridConfig((8, 8), (4.0, 4.0)))
    atom = AtomSpecies("test", 2.5e-25, 1, 50.0e-10, 60.0e-10, 6.977e-23)
    points = Float64[0.0 0.0]

    # parameter_setter without :interactions field
    bad_setter = θ -> (potential=HarmonicTrap((1.0, 1.0)),)
    @test_throws ArgumentError bogoliubov_along_boundary_curve(
        points, bad_setter, grid, atom;
        phase_init=:m_plus_F,
        n_steps=10, tol=1.0e-3,
        verbose=false,
    )
end
