# --- Active learning regression (R36, 2026-05-02) ---
#
# Phase-classify-distance entropy as BO acquisition target. Test on a
# synthetic 2-D problem with a known boundary so we can measure
# whether the AL scan concentrates samples in the boundary basin.

using SpinorBEC
using Test

@testset "phase_entropy_uncertainty" begin
    @testset "Single dominant candidate → low entropy" begin
        # Distances where one candidate dominates strongly
        scores = [(name=:a, distance=0.01),
            (name=:b, distance=1.0),
            (name=:c, distance=2.0)]
        e = phase_entropy_uncertainty(scores; temperature=0.1)
        @test e < 0.1
    end

    @testset "Tied candidates → maximum entropy" begin
        scores = [(name=:a, distance=0.5),
            (name=:b, distance=0.5),
            (name=:c, distance=0.5)]
        e = phase_entropy_uncertainty(scores; temperature=0.1)
        # log(3) ≈ 1.0986 is the cap for 3 uniform classes
        @test e > 1.0
        @test e ≤ log(3) + 1.0e-10
    end

    @testset "Two-tied vs one-dominant" begin
        # Two candidates close, one far
        scores_tied = [(name=:a, distance=0.4),
            (name=:b, distance=0.5),
            (name=:c, distance=2.0)]
        scores_dom = [(name=:a, distance=0.01),
            (name=:b, distance=1.0),
            (name=:c, distance=2.0)]
        e_tied = phase_entropy_uncertainty(scores_tied; temperature=0.1)
        e_dom = phase_entropy_uncertainty(scores_dom; temperature=0.1)
        @test e_tied > e_dom
    end

    @testset "Empty + missing-:distance handling" begin
        @test phase_entropy_uncertainty(NamedTuple[]) == 0.0
        # Distance-less entries are silently dropped → empty → 0
        scores = [(name=:a,)]
        @test phase_entropy_uncertainty(scores) == 0.0
    end
end

@testset "active_learn_phase_scan — synthetic 2-D problem" begin
    # Synthetic 2-D objective with a "phase boundary" along θ₁ = 0.5.
    # On the left (θ₁ < 0.5): phase :a wins. On the right: phase :b wins.
    # Near the boundary the two distances tie → max entropy.
    function eval_fn(θ::AbstractVector)
        # distance to phase :a is |θ₁ - 0.0|, to phase :b is |θ₁ - 1.0|
        d_a = abs(θ[1] - 0.0)
        d_b = abs(θ[1] - 1.0)
        d_c = sqrt((θ[1] - 0.5)^2 + (θ[2] - 0.5)^2) + 1.0   # never wins
        scores = [(name=:a, distance=d_a),
            (name=:b, distance=d_b),
            (name=:c, distance=d_c)]
        (scores=scores, phase=argmin([d_a, d_b, d_c]))
    end

    bounds = [(0.0, 1.0), (0.0, 1.0)]
    result = active_learn_phase_scan(eval_fn, bounds;
        n_init=5, n_iter=15, temperature=0.05,
        seed=42, verbose=false,
    )

    @testset "Returns BO-shaped result" begin
        @test hasproperty(result, :best_p)
        @test hasproperty(result, :best_y)
        @test hasproperty(result, :X_history)
        @test hasproperty(result, :y_history)
        @test length(result.best_p) == 2
        @test result.best_y > 0
    end

    @testset "Best (most uncertain) point is near θ₁ = 0.5" begin
        @test abs(result.best_p[1] - 0.5) < 0.15
    end

    @testset "Sampling concentrates near boundary" begin
        # Of the n_iter post-init samples, the fraction within 0.2 of
        # the boundary should beat a uniform-random baseline (≈ 0.4).
        post_init = result.X_history[(end - 14):end, :]
        on_boundary = sum(abs.(post_init[:, 1] .- 0.5) .< 0.2) / 15
        @test on_boundary > 0.4
        @info "AL post-init boundary concentration: $(on_boundary)"
    end
end
