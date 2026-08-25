# `variational_bound` — grounding: `exact` (a closed form computed in the test)
# plus the one property the method rests on, that the bound is never BELOW the
# true minimum.
#
# The harmonic oscillator is the positive control that can fail: the Gaussian
# trial family CONTAINS the exact ground state, so the bound must equal E0 = 1/2
# and not merely bracket it. The quartic oscillator is the complementary one:
# the Gaussian family does NOT contain the ground state, so the bound must sit
# strictly above the true minimum — a "bound" that dipped below would be the
# defect this whole method would silently hide.

using Test
using SpinorBEC
using SpinorBEC: VariationalBound, variational_bound, exceeds, bound_report
# `eigvals` / `Symmetric` below are LinearAlgebra's, not SpinorBEC's. Without
# this the file passes or fails depending on which OTHER file the on-demand
# queue happened to put in the same worker first — the exact order-dependence
# the parallel-runner contract exists to remove. Observed as a live flake on
# 2026-08-26: `UndefVarError: eigvals not defined in Main`.
using LinearAlgebra

# hbar = m = omega = 1. Trial psi ~ exp(-x^2 / (2 s^2)), parameterised by
# u = log s so the search is unconstrained.
#   <T> = 1 / (4 s^2),  <x^2> = s^2 / 2,  <x^4> = 3 s^4 / 4
e_harmonic(u) = (s=exp(u[1]); 1 / (4s^2) + s^2 / 4)
e_quartic(u) = (s=exp(u[1]); 1 / (4s^2) + 3s^4 / 4)

@testset "variational_bound" begin
    @testset "exact: the family contains the answer, so the bound IS the answer" begin
        b = variational_bound(e_harmonic, [0.3])
        @test b.converged
        @test isapprox(b.bound, 0.5; atol=1e-9)      # E0 = 1/2, exactly
        @test isapprox(exp(b.params[1]), 1.0; atol=1e-5)  # s = 1
        @test b.cross === nothing
        @test b.rel_gap == 0.0
    end

    @testset "the answer does not depend on where the search starts" begin
        # This is what caught the original convergence test. It compared
        # function VALUES only, and a simplex straddling the minimum
        # symmetrically has equal values at both vertices while still being
        # wide -- so the search stopped on the first symmetric pair it found.
        # From x0 = [-1.0] that returned 0.51003 at s = 1.105, `converged =
        # true`, in ten evaluations. Only the start point exposed it: [0.3]
        # happened to shrink the right way and passed.
        for x0 in ([-3.0], [-1.0], [-0.3], [0.0], [0.3], [1.0], [2.5])
            b = variational_bound(e_harmonic, x0)
            @test b.converged
            @test isapprox(b.bound, 0.5; atol=1e-8)
            @test isapprox(exp(b.params[1]), 1.0; atol=1e-4)
        end
    end

    @testset "the bound is never below the true minimum" begin
        # Quartic: the Gaussian family cannot reach the ground state, so the
        # bound must be strictly ABOVE it. E_min is computed here by direct
        # diagonalisation on a grid — an independent statement, not the same
        # closed form.
        n, L = 400, 8.0
        dx = 2L / n
        x = range(-L, L; length=n)
        # -1/2 d2/dx2 + x^4, three-point stencil
        H = zeros(n, n)
        for i in 1:n
            H[i, i] = 1 / dx^2 + x[i]^4
            i > 1 && (H[i, i - 1] = -0.5 / dx^2)
            i < n && (H[i, i + 1] = -0.5 / dx^2)
        end
        e_true = minimum(eigvals(Symmetric(H)))
        b = variational_bound(e_quartic, [0.0])
        @test b.converged
        @test b.bound > e_true                    # one-sided, and it must hold
        @test b.bound < e_true * 1.05             # ...but still a useful bound
    end

    @testset "cross_check: the LEAST BINDING of two is returned" begin
        # a second statement that reads 1 % high: the bound must take it, so a
        # verdict never depends on which statement is the more accurate
        b = variational_bound(e_harmonic, [0.3]; cross_check=u -> 1.01 * e_harmonic(u))
        @test isapprox(b.bound, 0.505; atol=1e-6)      # the HIGHER one
        @test isapprox(b.primary, 0.5; atol=1e-9)
        @test isapprox(b.cross, 0.505; atol=1e-6)
        @test isapprox(b.rel_gap, 0.01; atol=1e-6)
        # and when the second reads LOW, the bound still takes the higher
        b2 = variational_bound(e_harmonic, [0.3]; cross_check=u -> 0.99 * e_harmonic(u))
        @test isapprox(b2.bound, 0.5; atol=1e-9)
    end

    @testset "exceeds: one-sided, and it says so" begin
        b = variational_bound(e_harmonic, [0.3])
        @test exceeds(b, 0.6)          # above the bound  -> refuted
        @test !exceeds(b, 0.4)         # below the bound  -> merely allowed
        @test !exceeds(b, b.bound)     # equal is not above
    end

    @testset "refuses an infeasible start rather than returning a number" begin
        @test_throws ArgumentError variational_bound(_ -> NaN, [0.0])
        @test_throws ArgumentError variational_bound(e_harmonic, Float64[])
    end

    @testset "non-finite trials lose instead of poisoning the search" begin
        # a barrier at u > 0 must not stop the minimizer finding s = 1 from below
        f = u -> u[1] > 0.5 ? Inf : e_harmonic(u)
        b = variational_bound(f, [-1.0])
        @test isapprox(b.bound, 0.5; atol=1e-7)
    end

    @testset "bound_report names the verdict and the slack" begin
        b = variational_bound(e_harmonic, [0.3]; cross_check=u -> 1.01 * e_harmonic(u))
        s = bound_report(b, Dict("theirs" => 0.62, "textbook" => 0.50), 0.48)
        @test occursin("ABOVE the bound", s)
        @test occursin("theirs", s)
        @test occursin("below the bound", s)     # the 0.50 claim
        @test occursin("least binding", s)
        @test occursin("slack", s)
    end

    @testset "a non-converged run says so rather than reporting silently" begin
        b = variational_bound(e_harmonic, [0.3]; maxiter=1)
        @test !b.converged
        @test occursin("did not converge", bound_report(b, Dict("x" => 1.0)))
    end
end
