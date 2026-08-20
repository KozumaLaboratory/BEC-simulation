using Test
using SpinorBEC

# mu determined by the atoms that are NOT in the c-field, rather than prescribed.
#
# In a grand-canonical SPGPE, prescribing mu prescribes N_0: mu < eps_0 forbids a
# condensate and mu > eps_0 fixes the size through mu = eps_0 + c_0 n_0. So a run
# whose mu comes from an assumed equilibrium split cannot answer "how many atoms
# condense" — the answer is in the input. That is why the euv3 evaporation verdict
# was retracted: it tracked a one-parameter K_3 fit and flipped at K_3/fit ~ 0.3.
#
# mu_from_total_number reads N_C from the field and solves N_I(mu,T) = N_total - N_C,
# so what is prescribed is the extensive total and the split is left to the dynamics.
@testset "mu from a total, with N_C read rather than assumed" begin
    T, eps_cut = 2.0, 8.0

    @testset "N_I is strictly increasing in mu and diverges at the cutoff" begin
        # Monotonicity is what makes the inversion well posed; the divergence is what
        # bounds mu from above.
        ns = [incoherent_population(mu, T, eps_cut) for mu in (-20.0, -5.0, 0.0, 4.0, 7.0)]
        @test issorted(ns)
        @test all(isfinite, ns)
        @test incoherent_population(7.99, T, eps_cut) >
            incoherent_population(7.0, T, eps_cut)
        # No I level below the cutoff contributes.
        @test incoherent_population(-1e6, T, eps_cut) < 1e-100
    end

    @testset "the inversion round-trips" begin
        for mu in (-10.0, -2.0, 0.0, 3.0, 6.0)
            n = incoherent_population(mu, T, eps_cut)
            n > 1e-6 || continue
            got = mu_from_total_number(n + 100.0, 100.0, T, eps_cut)
            # atol as well as rtol: mu = 0 is in the list and a relative tolerance is
            # undefined there. The first version failed on -4.4e-9 vs 0.
            @test got≈mu rtol=1e-5 atol=1e-6
        end
    end

    @testset "the feedback is restoring, which is the whole point" begin
        # Same total, different c-field occupancy: a field holding FEWER atoms leaves
        # more for the I region, which at fixed T needs a HIGHER mu, which drives
        # growth. A prescribed mu has no such response — that is the difference
        # between a prediction and an input.
        # The I region has a finite capacity: at T = 2, eps_cut = 8 it holds at most
        # 231 atoms as mu -> eps_cut, so demanding 4000 is unsatisfiable and the
        # first version of this test asked for exactly that and read the correct NaN
        # as a failure. Sized against the measured capacity instead.
        cap = incoherent_population(eps_cut - 1e-9, T, eps_cut)
        @test cap > 200                       # the capacity is what it is
        N_total = 0.5 * cap + 100.0
        mu_empty = mu_from_total_number(N_total, 100.0, T, eps_cut)
        mu_full = mu_from_total_number(N_total, 100.0 + 0.4 * cap, T, eps_cut)
        @test isfinite(mu_empty) && isfinite(mu_full)
        @test mu_empty > mu_full
    end

    @testset "an unsatisfiable demand returns NaN rather than a default" begin
        # Absent is not a default. A trajectory point where the c-field already holds
        # the whole cloud, or where the reservoir cannot hold the remainder below the
        # cutoff, is a fact about that trajectory.
        @test isnan(mu_from_total_number(100.0, 100.0, T, eps_cut))   # nothing left
        @test isnan(mu_from_total_number(50.0, 100.0, T, eps_cut))    # negative
        # Above the I region's capacity, which is finite for any (T, eps_cut).
        @test isnan(mu_from_total_number(1e12, 0.0, T, eps_cut))
        @test isnan(mu_from_total_number(1000.0, 0.0, 0.0, eps_cut))  # T = 0
    end

    @testset "mu stays below the cutoff" begin
        for (Nt, Nc) in ((200.0, 100.0), (150.0, 1.0), (100.0, 0.0))
            mu = mu_from_total_number(Nt, Nc, T, eps_cut)
            isnan(mu) && continue
            @test mu < eps_cut
        end
    end

    @testset "it is NOT reservoir_chemical_potential" begin
        # The two answer different questions and must not be interchangeable: the old
        # one maps a total to mu through an assumed split and ignores N_C entirely.
        cap = incoherent_population(eps_cut - 1e-9, T, eps_cut)
        N_total = 0.5 * cap + 100.0
        a = mu_from_total_number(N_total, 100.0, T, eps_cut)
        b = mu_from_total_number(N_total, 100.0 + 0.4 * cap, T, eps_cut)
        @test isfinite(a) && isfinite(b)
        @test a != b                     # depends on the field, as it must
    end
end
