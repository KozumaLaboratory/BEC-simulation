using Test
using SpinorBEC

@testset "Lima-Pelster Q5(ε_dd) reference values" begin
    # Q5(0) = ∫₀¹ 1 du = 1 (exact)
    @test SpinorBEC.lima_pelster_Q5(0.0) ≈ 1.0 atol=1e-3

    # Q5(1) = ∫₀¹ (3u²)^(5/2) du = 3^(5/2)/6 ≈ 2.598
    @test SpinorBEC.lima_pelster_Q5(1.0) ≈ 3.0^2.5 / 6.0 atol=1e-3

    # Q5 monotonically increasing on (0, ∞)
    Q5s = [SpinorBEC.lima_pelster_Q5(ε) for ε in 0.0:0.2:2.0]
    for i in 2:length(Q5s)
        @test Q5s[i] > Q5s[i - 1]
    end

    # Q5(2) finite (Re part of complex integrand)
    @test isfinite(SpinorBEC.lima_pelster_Q5(2.0))
    @test SpinorBEC.lima_pelster_Q5(2.0) > SpinorBEC.lima_pelster_Q5(1.5)

    # Above-threshold Q5 follows Wachter's prescription (real part only)
    @test SpinorBEC.lima_pelster_Q5(3.0) > 0
end

@testset "γ_LHY dimensional sanity" begin
    # `scalar_lhy_coefficient` is the single declaration point for the scalar LHY
    # coefficient. This testset used to call a rotating-basis-local
    # `compute_gamma_lhy`, which the engine retirement deleted (leaving the name
    # undefined and this file red) and which carried the pre-PR#108 formula with
    # BOTH exponents low — so the scaling assertions below already contradicted it.
    scalar_lhy = SpinorBEC.scalar_lhy_coefficient

    # Dy164 fast-Larmor regime: γ_LHY ratio to c0 should be O(1) (LHY substantial)
    a0 = 5.291772109e-11
    γ_dy = scalar_lhy(92*a0/1.11e-6, 60000; eps_dd=1.42)
    @test γ_dy > 0
    @test γ_dy < 1e5         # not absurdly large
    @test γ_dy / 3306 > 0.5  # ratio to c0 is sensible (γ/c0 ≈ 1.8 expected)
    @test γ_dy / 3306 < 5.0

    # γ_LHY scales as N^(3/2)
    γ_n1 = scalar_lhy(0.001, 1000; eps_dd=1.0)
    γ_n2 = scalar_lhy(0.001, 8000; eps_dd=1.0)   # 8× atoms
    @test γ_n2 / γ_n1 ≈ 8.0^1.5 atol=1e-6                    # √8³ = 22.63

    # γ_LHY scales as (a_s/a_ho)^(5/2)
    γ_a1 = scalar_lhy(1e-3, 1000; eps_dd=1.0)
    γ_a2 = scalar_lhy(2e-3, 1000; eps_dd=1.0)   # 2× scattering length
    @test γ_a2 / γ_a1 ≈ 2.0^2.5 atol=1e-6
end
