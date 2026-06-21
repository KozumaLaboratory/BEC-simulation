# --- Triple-point hunting regression (R37, 2026-05-02) ---
#
# Synthetic 2-D problem with three phases meeting at origin:
#   phase :A — distance = θ₂ + 1            (favoured for θ₂ < boundary)
#   phase :B — distance = √(θ₁² + θ₂²)/√2   (radial, favoured at origin)
#                                            tweaked so :B < :A and :B < :C
#                                            in different sectors
#   phase :C — distance = -θ₂ + 1            (favoured for θ₂ > boundary)
# Actually: build a cleaner 3-fold-symmetric problem so the triple
# point is at the origin and the 3 boundary curves are 120° apart.

using SpinorBEC
using Test
using LinearAlgebra: norm

# 3-fold symmetric (equilateral): phase i has centre at the i-th
# vertex of an equilateral triangle inscribed in the unit circle.
# Each phase's "distance" is the Euclidean distance to its centre.
# At the centroid (origin) all three distances tie at 1.0 → triple point.

const _TRIPLE_CENTRES = (
    (1.0, 0.0),
    (-0.5, sqrt(3) / 2),
    (-0.5, -sqrt(3) / 2),
)
const _TRIPLE_NAMES = (:A, :B, :C)

function _three_phase_eval(θ::AbstractVector)
    distances = map(_TRIPLE_CENTRES) do c
        sqrt((θ[1] - c[1])^2 + (θ[2] - c[2])^2)
    end
    scores = NamedTuple[]
    for (n, d) in zip(_TRIPLE_NAMES, distances)
        push!(scores, (name=n, distance=d))
    end
    (scores=scores,)
end

@testset "pair_F_factory" begin
    # At centre :A (1, 0): d_A = 0, d_B = sqrt(3) → F_AB < 0
    F_AB = pair_F_factory(_three_phase_eval, :A, :B)
    @test F_AB([1.0, 0.0]) < 0
    # At centre :B (-0.5, +√3/2): d_B = 0, d_C = sqrt(3) → F_BC < 0
    F_BC = pair_F_factory(_three_phase_eval, :B, :C)
    @test F_BC([-0.5, sqrt(3) / 2]) < 0
end

@testset "detect_triple_points" begin
    @testset "Synthetic 3-fold-symmetric problem" begin
        bounds = [(-1.0, 1.0), (-1.0, 1.0)]
        candidates = detect_triple_points(_three_phase_eval, bounds;
            n_init=15, n_iter=40,
            temperature=0.1, tie_ratio_max=0.2,
            min_phases=3,
            seed=42, verbose=false,
        )
        # Expect at least one candidate
        @test !isempty(candidates)
        # Best candidate should be near the origin
        best = candidates[1]
        @test norm(best.θ) < 0.4
        @test length(best.phases) == 3
        @test sort(best.phases) == [:A, :B, :C]
    end

    @testset "tie_ratio_max gates" begin
        bounds = [(-1.0, 1.0), (-1.0, 1.0)]
        # Very strict — should produce fewer (or no) candidates than loose
        loose = detect_triple_points(_three_phase_eval, bounds;
            n_init=15, n_iter=30, tie_ratio_max=0.5,
            seed=42, verbose=false,
        )
        strict = detect_triple_points(_three_phase_eval, bounds;
            n_init=15, n_iter=30, tie_ratio_max=0.05,
            seed=42, verbose=false,
        )
        @test length(strict) <= length(loose)
    end
end

@testset "trace_triple_point_curves" begin
    bounds = [(-1.0, 1.0), (-1.0, 1.0)]
    candidates = detect_triple_points(_three_phase_eval, bounds;
        n_init=15, n_iter=40, tie_ratio_max=0.3,
        seed=42, verbose=false,
    )
    @assert !isempty(candidates)

    traces = trace_triple_point_curves(candidates[1], _three_phase_eval;
        arc_step=0.05, max_steps=20, verbose=false,
    )

    @testset "Returns Dict with one entry per phase pair" begin
        @test traces isa Dict
        # 3 phases → C(3,2) = 3 pairs
        @test length(traces) == 3
        # Each value is a BoundaryTrace
        for (k, v) in traces
            @test v isa BoundaryTrace
            @test size(v.points, 2) == 2
            @test size(v.points, 1) >= 1   # at least the seed point
        end
    end

    @testset "Each curve advances away from triple point" begin
        seed = candidates[1].θ
        for (k, v) in traces
            # The last accepted point should be further from seed than the seed itself.
            if size(v.points, 1) > 1
                d_end = norm(v.points[end, :] .- seed)
                @test d_end > 0
            end
        end
    end
end
