using Test
using SpinorBEC

# mu for the WHOLE cloud, with every region a function of the same mu.
#
# The previous version solved N_I(mu,T) = N_total - N_C with N_C read from the field.
# That looked like the way to stop prescribing N_0 and instead charges the entire
# field-to-equilibrium discrepancy to the reservoir. Measured on the euv3 ramp at 10%
# — N_total = 8835, field N_C = 6756 — it returned mu = 16.7, whose Thomas-Fermi
# condensate is 2e5, thirty times the atoms present, while the field's N_0 stayed at
# 0.64. A drive demanding thirty times what exists is a mis-stated constraint, not a
# transient.
@testset "mu from the total, all regions at one mu" begin
    T, eps_cut, c0 = 5.5, 18.0, 0.02

    @testset "the total is monotone in mu, so the solve is well posed" begin
        tots = map((-20.0, -5.0, 0.0, 2.0, 5.0, 10.0)) do mu
            N0 = if mu > 1.5
                (R=sqrt(2 * (mu - 1.5));
                    max((4π / c0) * ((mu - 1.5) * R^3 / 3 - R^5 / 10), 0.0))
            else
                0.0
            end
            N0 + coherent_population(mu, T, eps_cut) +
            incoherent_population(mu, T, eps_cut)
        end
        @test issorted(tots)
    end

    @testset "it round-trips" begin
        for mu_want in (-4.0, 0.0, 2.5, 6.0)
            N0 = if mu_want > 1.5
                (R=sqrt(2 * (mu_want - 1.5));
                    max((4π / c0) * ((mu_want - 1.5) * R^3 / 3 - R^5 / 10), 0.0))
            else
                0.0
            end
            N =
                N0 + coherent_population(mu_want, T, eps_cut) +
                incoherent_population(mu_want, T, eps_cut)
            N > 1 || continue
            got = mu_from_total_number_equilibrium(N, T, eps_cut; c0)
            @test got.mu≈mu_want rtol=1e-4 atol=1e-5
        end
    end

    @testset "the euv3 point no longer demands thirty times what exists" begin
        # The measurement that condemned the previous version. At N_total = 8835,
        # T = 5.53 the constraint must return a mu whose OWN condensate plus thermal
        # regions add to 8835 — not one demanding 2e5.
        got = mu_from_total_number_equilibrium(8835.0, 5.53, 18.1; c0)
        @test isfinite(got.mu)
        @test got.N0 < 8835.0                 # cannot exceed the total
        @test got.N0 >= 0
        # and the constraint is actually satisfied
        tot =
            got.N0 + coherent_population(got.mu, 5.53, 18.1) +
            incoherent_population(got.mu, 5.53, 18.1)
        @test tot≈8835.0 rtol=1e-3
    end

    @testset "N_0 is an output: it responds to the total" begin
        a = mu_from_total_number_equilibrium(2000.0, T, eps_cut; c0)
        b = mu_from_total_number_equilibrium(20000.0, T, eps_cut; c0)
        @test b.N0 >= a.N0
        @test b.mu > a.mu
    end

    @testset "a cold enough cloud condenses and a hot one does not" begin
        # Positive and negative control on the thing being predicted. At fixed total,
        # lowering T must move atoms out of the thermal regions and into N_0.
        cold = mu_from_total_number_equilibrium(20000.0, 1.0, eps_cut; c0)
        hot = mu_from_total_number_equilibrium(20000.0, 12.0, eps_cut; c0)
        @test cold.N0 > hot.N0
    end

    @testset "unsatisfiable returns NaN, not a clamp" begin
        @test isnan(mu_from_total_number_equilibrium(1e14, T, eps_cut; c0).mu)
        @test isnan(mu_from_total_number_equilibrium(-1.0, T, eps_cut; c0).mu)
        @test isnan(mu_from_total_number_equilibrium(100.0, 0.0, eps_cut; c0).mu)
    end
end
