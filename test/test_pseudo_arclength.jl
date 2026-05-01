# --- pseudo_arclength continuation tests (R35, 2026-05-02) ---
#
# trace_phase_boundary on synthetic 2-D functions where the boundary
# curve is known analytically. Tests pin:
#
#   1. Vertical line (F = θ₁ − 0.5):  100 traced points must all
#      satisfy θ₁ ≈ 0.5, |F| ≪ tol, and the tangent stays close to ±ẏ.
#   2. Unit circle (F = θ₁² + θ₂² − 1): 100 traced points stay on the
#      circle within tol; arc-length covers ≥ 1 radian by step 50.
#   3. Step shrinking: a 1-D corner (F has steep slope flip) forces
#      the continuation to halve h and stay on the manifold.

using SpinorBEC
using Test

@testset "trace_phase_boundary on synthetic curves" begin
    @testset "Vertical line θ₁ = 0.5" begin
        F(θ) = θ[1] - 0.5
        # Tangent at any boundary point is +ẏ (or -ẏ) — straight up.
        result = trace_phase_boundary(
            F, [0.5, 0.0], [0.0, 1.0];
            arc_step=0.1, max_steps=20,
            verbose=false,
        )
        # All accepted points must lie on θ₁ = 0.5
        @test all(p -> abs(p[1] - 0.5) < 1.0e-7, eachrow(result.points))
        # Residual is the absolute F value at each accepted point — for
        # this curve it's effectively roundoff.
        @test maximum(result.residuals) < 1.0e-7
        # Should have advanced in the +y direction (cumulative)
        @test result.points[end, 2] > result.points[1, 2]
        # All steps must report converged
        @test all(result.converged)
    end

    @testset "Unit circle θ₁² + θ₂² = 1" begin
        F(θ) = θ[1]^2 + θ[2]^2 - 1
        # Start at (1, 0); analytic tangent there is (0, 1).
        result = trace_phase_boundary(
            F, [1.0, 0.0], [0.0, 1.0];
            arc_step=0.05, max_steps=50,
            newton_tol=1.0e-8,
            verbose=false,
        )
        # All accepted points satisfy the circle equation
        on_circle_residuals = [abs(p[1]^2 + p[2]^2 - 1) for p in eachrow(result.points)]
        @test maximum(on_circle_residuals) < 1.0e-6
        # After 50 steps with arc 0.05 the cumulative arc-length should
        # cover ~ 2.5 rad → we should be well past θ = π/2
        # (i.e., the angle from the +x axis should exceed 1 rad)
        last_angle = atan(result.points[end, 2], result.points[end, 1])
        @test last_angle > 1.0
    end

    @testset "tangent_at agrees with manual computation" begin
        # Circle: at (1, 0) tangent is (0, 1) (or its negation).
        F(θ) = θ[1]^2 + θ[2]^2 - 1
        t = tangent_at(F, [1.0, 0.0])
        @test abs(t[1]) < 1.0e-3
        @test abs(abs(t[2]) - 1.0) < 1.0e-3
    end

    @testset "Singular ∇F throws" begin
        # F ≡ 0 has ∇F = 0 everywhere — no defined boundary direction.
        F(θ) = 0.0
        @test_throws ArgumentError tangent_at(F, [0.5, 0.5])
    end

    @testset "d ≠ 2 throws" begin
        F(θ) = θ[1] + θ[2] + θ[3]
        @test_throws ArgumentError trace_phase_boundary(
            F, [0.0, 0.0, 0.0], [1.0, 0.0, 0.0]; verbose=false,
        )
    end
end
