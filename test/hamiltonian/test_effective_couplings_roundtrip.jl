# `effective_a_s_over_a_ho` / `effective_eps_dd` invert the pair
# (`compute_c_total`, `compute_c_dd_dimless`). Everything downstream that needs
# a_s or ε_dd when a config OVERRIDES `interactions.c_total` reads them through
# these, so the inverse has to be exact — and it has to keep agreeing with the
# atom's own tabulated pair when nothing is overridden.
#
# Why this gate exists: until 2026-08-19 the scalar-LHY auto-derivation read
# `atom.a_s` regardless of a c_total override, so `runs/saito_li_torus/config.yaml`
# (a_s lowered 110 a₀ → 45.7 a₀ to reach ε_dd = 1.3) got an LHY coefficient
# 3.52× too large — on the single term a quantum droplet's existence depends on.

using Test
using SpinorBEC
using SpinorBEC: compute_c_total, compute_c_dd_dimless, compute_a_dd,
    effective_a_s_over_a_ho, effective_eps_dd, scalar_lhy_coefficient,
    ATOM_REGISTRY, Units

@testset "effective couplings round-trip" begin
    ω = 691.15

    @testset "inverse of the forward formulas, every registry atom" begin
        n_dipolar = 0
        for (name, atom) in ATOM_REGISTRY
            atom.a_s > 0 || continue
            a_ho = sqrt(Units.HBAR / (atom.mass * ω))
            for N in (1000, 15000, 250_000)
                c_total = compute_c_total(atom; N_atoms=N, omega_ref=ω)
                @test effective_a_s_over_a_ho(c_total, N) ≈ atom.a_s / a_ho rtol = 1e-12

                atom.mu_mag > 0 || continue
                n_dipolar += 1
                c_dd = compute_c_dd_dimless(atom; N_atoms=N, omega_ref=ω)
                @test effective_eps_dd(atom.F, c_total, c_dd) ≈
                    compute_a_dd(atom) / atom.a_s rtol = 1e-12
            end
        end
        # Positive control on the loop itself: a filter that silently matched
        # nothing would leave every @test above unexecuted.
        @test n_dipolar >= 6
    end

    @testset "an override is followed, not ignored" begin
        atom = ATOM_REGISTRY[:Eu151]
        N = 15000
        a_ho = sqrt(Units.HBAR / (atom.mass * ω))
        a_dd = compute_a_dd(atom)

        # Li–Saito's cell: keep the atom's moment (so c_dd is natural) and lower
        # a_s until ε_dd = 1.3.
        a_s = a_dd / 1.3
        c_total = compute_c_total(atom; N_atoms=N, omega_ref=ω) * (a_s / atom.a_s)
        c_dd = compute_c_dd_dimless(atom; N_atoms=N, omega_ref=ω)

        @test effective_eps_dd(atom.F, c_total, c_dd) ≈ 1.3 rtol = 1e-12
        @test effective_a_s_over_a_ho(c_total, N) ≈ a_s / a_ho rtol = 1e-12
        # and it is NOT the atom's own value — otherwise the test above would
        # pass for a function that ignored its arguments.
        @test !isapprox(effective_eps_dd(atom.F, c_total, c_dd),
            a_dd / atom.a_s; rtol=0.1)
    end

    @testset "the committed config's old numbers are reproduced" begin
        # `c_total: 583` + `ddi.c_dd: 152` was intended as ε_dd = 1.3; it is not.
        # Pinning the real value keeps the diagnosis reproducible.
        atom = ATOM_REGISTRY[:Eu151]
        @test effective_eps_dd(atom.F, 583.0, 152.0) ≈ 3.1286 atol = 1e-4
    end

    @testset "degenerate inputs do not throw" begin
        @test effective_eps_dd(6, 0.0, 1.0) == 0.0
        @test effective_eps_dd(6, NaN, 1.0) == 0.0
        @test effective_eps_dd(6, 1.0, NaN) == 0.0
        @test isnan(effective_a_s_over_a_ho(100.0, 0))
        # F = 0 uses the F → 1 algebra (compute_c_dd does not divide by F there)
        @test effective_eps_dd(0, 300.0, 3.0) == effective_eps_dd(1, 300.0, 3.0)
    end
end
