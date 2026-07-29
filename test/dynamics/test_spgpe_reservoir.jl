using Test
using SpinorBEC

# 0-D evaporation trajectory → SPGPE reservoir (T(t), μ(t)).
#
# The point of this bridge is the TIMESCALE: it must carry the laboratory ramp
# duration into internal simulation units unchanged. The failure this guards
# against is the one that actually happened (2026-07-27): an evaporation run
# whose ramp was ~60× faster than the real process, which is non-adiabatic
# spilling rather than evaporation even though every conservation check passed.
# So the first gate is on seconds, not on physics.

@testset "SPGPE reservoir from 0-D evaporation" begin
    trap = euv3_evap_trap()
    ramp = euv3_evaporation_ramp()
    p = EvapParams(; a_s=Eu151.a_s, tau_bg=15.0, K3=1.61e-40)
    r = run_evaporation_bec(trap, ramp, p; N0=3.5e6, T0=50e-6)

    @testset "the ramp stays seconds long in internal units" begin
        ωref = 2π * 284.0
        out = spgpe_reservoir(r, trap, ramp; omega_ref=ωref, a_s=Eu151.a_s, k_cut=12.0)
        # the physical duration survives the conversion …
        @test out.duration_s > 0.5                       # a real evaporation, not a quench
        @test isapprox(out.duration_internal, out.duration_s * ωref; rtol=1e-9)
        # … and is the thousands of internal units that makes this expensive.
        @test out.duration_internal > 1000
        @test out.t_internal[1] == 0.0
        @test issorted(out.t_internal)
    end

    @testset "reservoir cools and its chemical potential rises" begin
        out = spgpe_reservoir(r, trap, ramp;
            omega_ref=2π * 284.0, a_s=Eu151.a_s, k_cut=12.0)
        @test out.T_int[end] < out.T_int[1]              # evaporation cools
        @test out.mu_int[end] > out.mu_int[1]            # and degenerates
        @test out.mu_int[1] < 0                          # starts non-degenerate (z<1)
        @test all(isfinite, out.T_int)
        @test all(isfinite, out.mu_int)
        # rates track the ramp
        rate0 = spgpe_rates(out.reservoir, out.t_internal[1])
        rate1 = spgpe_rates(out.reservoir, out.t_internal[end])
        @test rate0.gamma > 0 && rate1.gamma > 0
        @test rate0.M > 0 && rate1.M > 0
    end

    @testset "too small a C region is refused, not silently wrong" begin
        # ϵ_cut = ½k_cut² must exceed μ or the reservoir formulas are undefined.
        @test_throws ArgumentError spgpe_reservoir(
            r, trap, ramp; omega_ref=2π * 284.0, a_s=Eu151.a_s, k_cut=0.3)
    end

    @testset "windowing" begin
        full = spgpe_reservoir(r, trap, ramp;
            omega_ref=2π * 284.0, a_s=Eu151.a_s, k_cut=12.0)
        half_start = 0.5 * (r.t[1] + r.t[end])
        win = spgpe_reservoir(r, trap, ramp; omega_ref=2π * 284.0, a_s=Eu151.a_s,
            k_cut=12.0, t_start=half_start)
        @test win.duration_s < full.duration_s
        @test win.t_internal[1] == 0.0                   # window is re-zeroed
        @test length(win.N0_ref) < length(full.N0_ref)
    end
end

@testset "reservoir_chemical_potential branches" begin
    m = Eu151.mass
    ω̄ = 2π * 284.0
    a_s = Eu151.a_s

    # Non-degenerate: μ < 0, and hotter ⇒ more negative.
    μ_hot = reservoir_chemical_potential(1e5, 5e-6, ω̄, m, a_s)
    μ_warm = reservoir_chemical_potential(1e5, 2e-6, ω̄, m, a_s)
    @test μ_hot < 0
    @test μ_hot < μ_warm

    # Degenerate: μ > 0 and grows with the condensate.
    Tc = bec_critical_temperature(1e5, ω̄)
    μ_a = reservoir_chemical_potential(1e5, 0.6 * Tc, ω̄, m, a_s)
    μ_b = reservoir_chemical_potential(1e5, 0.3 * Tc, ω̄, m, a_s)
    @test μ_a > 0
    @test μ_b > μ_a                                    # colder ⇒ bigger N₀ ⇒ bigger μ

    # Continuous through T_c: N₀ → 0 sends both branches to 0. Approach it rather
    # than assert a magic threshold — μ_TF ∝ N₀^{2/5} vanishes slowly, so a fixed
    # tolerance at one temperature says nothing about continuity.
    μ_close = abs(reservoir_chemical_potential(1e5, 0.999 * Tc, ω̄, m, a_s))
    μ_closer = abs(reservoir_chemical_potential(1e5, 0.99999 * Tc, ω̄, m, a_s))
    @test μ_close < 0.1 * Units.KB * Tc
    @test μ_closer < μ_close

    # Li₃ inversion round-trips against its own series.
    for z in (0.1, 0.5, 0.9, 0.999)
        ρ = SpinorBEC._li3(z)
        @test isapprox(SpinorBEC._invert_li3(ρ), z; rtol=1e-8)
    end
    @test SpinorBEC._invert_li3(10.0) == 1.0           # saturated
end
