using Test
using Scattering

@testset "bracket_poles: pure-pole analytic function" begin
    # tan(π λ) has poles at λ = 1/2, 3/2, ... AND zeros at λ = 0, 1, 2.
    # Need min_abs_a to isolate the poles from the zero sign flips.
    a(λ) = tan(π * λ)
    grid = range(0.05, 1.95; length = 20)
    brs = bracket_poles(a, grid; min_abs_a = 1.0)
    @test length(brs) == 2
    @test 0.4 < brs[1].λ_lo < 0.5 < brs[1].λ_hi < 0.6
    @test 1.4 < brs[2].λ_lo < 1.5 < brs[2].λ_hi < 1.6
end

@testset "bracket_poles: single-pole a(λ) = 1/(λ − 0.5)" begin
    # Clean: one pole, no zeros.
    a(λ) = 1.0 / (λ - 0.5)
    grid = range(0.02, 0.98; length = 10)
    brs = bracket_poles(a, grid)
    @test length(brs) == 1
    @test brs[1].λ_lo < 0.5 < brs[1].λ_hi
end

@testset "bracket_poles: excludes zeros of a" begin
    # a(λ) = λ − 0.5 has a zero (not a pole) at λ = 0.5.
    a(λ) = λ - 0.5
    grid = range(0.02, 0.98; length = 10)
    brs = bracket_poles(a, grid; min_abs_a = 0.2)
    @test isempty(brs)                          # |a| small near zero filtered out
    # Without the threshold, the sign flip IS bracketed.
    brs_nofilter = bracket_poles(a, grid)
    @test length(brs_nofilter) == 1
end

@testset "bisect_pole: tan(π λ) converges to machine ε" begin
    a(λ) = tan(π * λ)
    br = PoleBracket(0.3, 0.7, tan(π * 0.3), tan(π * 0.7))
    λ_pole, _, _, iters = bisect_pole(a, br; atol = 1e-14, rtol = 0.0, max_iter = 80)
    @test isapprox(λ_pole, 0.5; atol = 1e-12)
    @test iters < 80
end

@testset "find_poles: end-to-end on analytic pole function" begin
    a(λ) = tan(π * λ)
    grid = range(0.05, 1.95; length = 40)
    poles = find_poles(a, grid; atol = 1e-12, rtol = 0.0,
                       min_abs_a = 1.0, max_iter = 80)
    @test length(poles) == 2
    @test isapprox(poles[1], 0.5; atol = 1e-10)
    @test isapprox(poles[2], 1.5; atol = 1e-10)
end

@testset "find_poles: Fano-shape a(λ) = a_bg + Γ/(λ − λ_0)" begin
    a_bg = 50.0
    Γ = -10.0
    λ_0 = 1.02
    a(λ) = a_bg + Γ / (λ - λ_0)
    grid = range(1.0, 1.05; length = 11)
    poles = find_poles(a, grid; atol = 1e-12, rtol = 0.0, max_iter = 80)
    @test length(poles) == 1
    @test isapprox(poles[1], λ_0; atol = 1e-10)
end

@testset "find_poles with cached avals skips recomputation" begin
    calls = Ref(0)
    a(λ) = (calls[] += 1; tan(π * λ))
    grid = range(0.05, 0.95; length = 10)
    avals = [a(λ) for λ in grid]
    n_initial = calls[]
    @test n_initial == 10
    # With precomputed avals, bracket stage must not call a_fn.
    brs = bracket_poles(a, grid; avals = avals)
    @test calls[] == n_initial
    @test length(brs) == 1
    # Bisect still calls a_fn.
    poles = find_poles(a, grid; avals = avals, atol = 1e-12, rtol = 0.0,
                       max_iter = 80)
    @test calls[] > n_initial
    @test isapprox(poles[1], 0.5; atol = 1e-10)
end

@testset "find_poles: Eu+Eu septet rescaling pole near λ ≈ 0.98 (fast grid)" begin
    # Full Numerov-based scattering length is costly; keep the grid
    # small and bisection loose. Known from prior scan: one pole between
    # λ ≈ 0.978 and 0.981 in this window.
    a_fn(λ) = eueu_stretched_swave_length(; λ = λ, h = 1e-2)
    λ_grid = range(0.975, 0.990; length = 6)
    poles = find_poles(a_fn, λ_grid; atol = 1e-4, rtol = 1e-4, max_iter = 20,
                       min_abs_a = 100.0)
    @test length(poles) == 1
    @test 0.978 <= poles[1] <= 0.981
end
