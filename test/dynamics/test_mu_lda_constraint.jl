using Test
using SpinorBEC

# The number constraint in the semiclassical Hartree-Fock form, which is the standard
# one (Popov / Zaremba-Griffin-Nikuni; Giorgini, Pitaevskii & Stringari
# cond-mat/9704014):
#
#   mu_eff(r) = mu - V(r) - 2 c0 [n_c(r) + n_th(r)]
#   N = N_0 + n_th integrated, with the Bose occupation taken at mu_eff
#
# Two earlier attempts were wrong in ways only a measurement showed. Solving
# N_I = N_total - N_C with N_C read from the field charged the whole
# field-to-equilibrium gap to the reservoir and returned mu = 16.7 on the euv3 ramp,
# demanding 2e5 atoms against 6756 present. Replacing that with a discrete level sum
# that skipped levels below mu made the total NON-MONOTONE — measured, N_C^th fell
# 377 -> 258 across mu = 2.375 -> 2.5 — so a 200-iteration bisection returned 2.34
# for 2.5.
#
# The effective potential removes both. Inside the condensate TF gives
# mu = V + c0 n_c + 2 c0 n_th, so mu_eff = -c0 n_c <= 0: the Bose argument never
# reaches 1, nothing diverges, and there is no level to skip.
@testset "number constraint, semiclassical HF" begin
    T, c0, eps_cut = 5.0, 0.02, 20.0

    @testset "the total is MONOTONE in mu — the property both earlier forms broke" begin
        tots = Float64[]
        for mu in (-10.0, -5.0, 0.0, 2.0, 5.0, 10.0, 15.0)
            eq = classical_field_equilibrium(; T, mu, c0, n_T=(eps_cut - mu) / T)
            push!(tots, eq.N0 + eq.Nth +
                        incoherent_lda(; T, mu, c0, eps_cut))
        end
        @test issorted(tots)
        # and strictly, not by a hair
        @test tots[end] > 10 * tots[1]
    end

    @testset "it round-trips, which the level-sum form could not" begin
        for mu_want in (-2.0, 2.0, 6.0, 12.0)
            eq = classical_field_equilibrium(; T, mu=mu_want, c0,
                n_T=(eps_cut - mu_want) / T)
            N = eq.N0 + eq.Nth + incoherent_lda(; T, mu=mu_want, c0, eps_cut)
            N > 1 || continue
            got = mu_from_total_lda(N; T, c0, eps_cut)
            @test got.mu≈mu_want rtol=2e-3 atol=1e-3
        end
    end

    @testset "mu_eff never makes the Bose occupation diverge" begin
        # The structural reason the constraint is well behaved. At any mu, the
        # effective potential at the cloud centre must be <= 0.
        for mu in (0.0, 5.0, 15.0, 19.0)
            eq = classical_field_equilibrium(; T, mu, c0, n_T=(eps_cut - mu) / T)
            mu_eff0 = mu - 2 * c0 * (eq.n0[1] + eq.nth[1])
            @test mu_eff0 <= 1e-6
        end
    end

    @testset "N_0 is an output and responds the right way" begin
        a = mu_from_total_lda(2.0e4; T, c0, eps_cut)
        b = mu_from_total_lda(2.0e5; T, c0, eps_cut)
        @test isfinite(a.mu) && isfinite(b.mu)
        @test b.N0 > a.N0                      # more atoms, more condensate
        @test b.mu > a.mu
        # colder at fixed total must condense more — positive control on the
        # prediction itself, not on the plumbing
        cold = mu_from_total_lda(2.0e5; T=1.0, c0, eps_cut)
        hot = mu_from_total_lda(2.0e5; T=12.0, c0, eps_cut)
        @test cold.N0 > hot.N0
    end

    @testset "the parts sum to the total that was asked for" begin
        N = 5.0e4
        g = mu_from_total_lda(N; T, c0, eps_cut)
        @test g.N0 + g.Nth_C + g.N_I≈N rtol=5e-3
        @test g.N0 >= 0 && g.Nth_C >= 0 && g.N_I >= 0
    end

    @testset "unsatisfiable returns NaN rather than a clamp" begin
        @test isnan(mu_from_total_lda(1e14; T, c0, eps_cut).mu)
        @test isnan(mu_from_total_lda(-1.0; T, c0, eps_cut).mu)
    end
end
