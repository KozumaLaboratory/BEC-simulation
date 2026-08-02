using Test
using FFTW
using SpinorBEC

# The classical-field equilibrium and the thermal seed built on it. Both exist
# because an SPGPE run had no independent statement of what its equilibrium was:
# a KZ scan ramped T = 30 -> 2 at mu = 15 asserting the transition was crossed by
# cooling, and it was not (T_c = 49, so the ramp ran entirely inside the
# condensed phase), while the C region was separately never filling at all.
@testset "classical field equilibrium + thermal seed" begin
    @testset "T_c exists at fixed mu and the old ramp sat below it" begin
        # At fixed mu the ONLY thing that removes the condensate is the thermal
        # mean-field shift 2 c0 n_th reaching mu, so n_0(0) -> 0 defines T_c.
        below = classical_field_equilibrium(; T=30.0, mu=15.0, c0=0.19)
        above = classical_field_equilibrium(; T=60.0, mu=15.0, c0=0.19)
        @test below.n0_center > 0
        @test above.n0_center == 0

        lo, hi = 2.0, 400.0
        for _ in 1:40
            mid = 0.5 * (lo + hi)
            if classical_field_equilibrium(; T=mid, mu=15.0, c0=0.19).n0_center > 0
                (lo = mid)
            else
                (hi = mid)
            end
        end
        T_c = 0.5 * (lo + hi)
        @test 45 < T_c < 55                    # 49.0
        @test T_c > 30                         # the retracted ramp never crossed it

        # Deep in the condensed phase the total approaches the Thomas-Fermi number
        # N_TF = (4 pi / c0)[mu R^3/3 - R^5/10], R = sqrt(2 mu) — an independent
        # closed form, so this pins the solver rather than restating it.
        cold = classical_field_equilibrium(; T=2.0, mu=15.0, c0=0.19)
        R = sqrt(2 * 15.0)
        N_TF = (4π / 0.19) * (15.0 * R^3 / 3 - R^5 / 10)
        @test cold.N0≈N_TF rtol=0.05
        @test cold.Nth < 0.01 * cold.N0
    end

    @testset "condensate fraction falls monotonically with T" begin
        f = [
            (e=classical_field_equilibrium(; T, mu=15.0, c0=0.19);
                e.N0 / (e.N0 + e.Nth)) for T in (2.0, 10.0, 20.0, 30.0, 40.0)
        ]
        @test issorted(f; rev=true)
        @test f[1] > 0.99
        @test f[end] < 0.15
    end

    @testset "the seed carries the equilibrium atom number" begin
        # The point of the seed: the number is right BY CONSTRUCTION, because
        # growing it with the reservoir does not converge — a mode relaxes at
        # 2 gamma (eps - mu), which vanishes exactly where the atoms are.
        n, L, mu, T, c0 = 64, 24.0, 15.0, 80.0, 0.19
        grid = make_grid(GridConfig((n, n, n), (L, L, L)))
        plans = make_fft_plans((n, n, n); flags=FFTW.ESTIMATE)
        psi = zeros(ComplexF64, n, n, n, SpinSystem(1).n_components)
        N = thermal_cfield!(psi, grid, plans; T, mu, c0,
            k_cut=sqrt(2 * (mu + T)), seed=7)
        eq = classical_field_equilibrium(; T, mu, c0, rmax=L / 2)
        @test N≈eq.Nth + eq.N0 rtol=0.25       # grid + LDA binning, not a fit
        @test N > 1e4                          # and it is a filled C region

        # Above T_c the seed must be thermal, not coherent: no plateau in g1.
        r, g1 = first_order_correlation(psi, grid, plans)
        @test abs(coherence_length(r, g1).f_inf) < 0.1

        # Only the stretched component is seeded — reservoir noise filling the
        # other spin channels is a separate decision, not a side effect of this.
        @test sum(abs2, view(psi,:,:,:,1)) == 0
    end
end
