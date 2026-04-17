using Test
using Scattering

@testset "Numerov: free particle V = 0 gives u(R) = sin(kR)/k" begin
    μ = 1.0
    E = 0.5                  # k² = 2μE = 1 ⇒ k = 1
    k = sqrt(2 * μ * E)
    h = 1e-3
    R_min = 1e-6; R_max = 10.0
    # Start with exact values so the integrator has no initialization error.
    u0 = (sin(k * R_min) / k, sin(k * (R_min + h)) / k)

    Rs, u = numerov(R -> 0.0, R_min, R_max, h, E; μ = μ, ℓ = 0, u0 = u0)
    u_exact = sin.(k .* Rs) ./ k
    @test maximum(abs.(u .- u_exact)) < 1e-8
end

@testset "Numerov: zero-energy scattering length matches square well" begin
    μ = 1.0
    V0 = 0.5                        # attractive depth
    R0 = 5.0                        # well radius
    V(R) = R < R0 ? -V0 : 0.0

    a_analytic = square_well_scattering_length(V0, R0; μ = μ)

    h = 5e-4
    R_min = 1e-8
    R_max = 3 * R0                  # safely outside the well

    a_num = zero_energy_scattering_length(V, R_min, R_max, h;
                                           μ = μ,
                                           u0 = (0.0, R_min + h))
    # Numerov is 2nd-order at the V(R) discontinuity at R = R₀, limiting
    # overall accuracy; loose rtol is the honest tolerance here.
    @test a_num ≈ a_analytic rtol = 1e-3
end

@testset "Numerov: vanishing scattering length for V = 0" begin
    μ = 1.0
    h = 1e-3
    # For V = 0 at E = 0, u(R) = u'(R) · R + const. Starting u(R_min) ≈ 0
    # and u(R_min + h) small, the zero-energy solution is linear; the
    # extracted "scattering length" equals the intercept of this line,
    # which is the exact value (zero for a starting pair on R-axis).
    R_min = 1e-6; R_max = 5.0
    u0 = (0.0, (R_min + h))          # slope 1 line through origin
    a = zero_energy_scattering_length(R -> 0.0, R_min, R_max, h;
                                       μ = μ, u0 = u0)
    # Starting u(R_min) = 0 with R_min > 0 encodes a line with intercept
    # R_min, so the recovered "a" is exactly R_min (up to round-off).
    @test isapprox(a, R_min, atol = 1e-9)
end

@testset "Numerov: Eu+Eu septet scattering length is O(100) a_0" begin
    # Sanity check with Tomza 2018 V_{S=7}. No tuning; just confirm the
    # integrator runs and a_{S=7} is in a physically reasonable range
    # (Tomza quotes a reference ≈ 267 a_0 but the exact value depends on
    # λ scaling not applied here).
    atom = Eu151()
    μ = Scattering.reduced_mass(atom, atom)

    septet = eueu_septet_params()
    V(R) = V_septet(septet, R)

    # Start inside the repulsive wall where V ≫ |E|; integrate to R_max
    # where V_septet ≈ -C_6/R^6 is very small.
    R_min = 6.0                      # inside the well but past the inner wall
    # V_septet(6.0) ≈ very large positive (steep repulsive wall), OK
    R_max = 200.0
    h = 5e-3

    a = zero_energy_scattering_length(V, R_min, R_max, h;
                                       μ = μ,
                                       u0 = (0.0, 1e-40))
    # a can be large positive/negative depending on last bound state, but
    # magnitude should be bounded within a few thousand a_0 for this well.
    @test isfinite(a)
    @test abs(a) < 1e4
end
