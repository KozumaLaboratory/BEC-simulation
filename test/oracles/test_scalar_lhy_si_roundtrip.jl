# Oracle: the auto-derived dimensionless scalar LHY coefficient against SI.
#
# `_resolve_lhy_block!` fills `c_lhy` whenever the user writes
# `lhy: {kind: scalar}` without a value. That number has no convention freedom
# — the ratio of the two chemical-potential terms is fixed by SI:
#
#     μ_LHY / μ_contact = (32/3)·√(n_SI·a_s³/π)
#
# and the repo's per-particle dimensionless form must reproduce it:
#
#     μ_LHY / μ_contact = (c_lhy/c₀)·√n_dimless,   c₀ = 4π(a_s/a_ho)N
#
# Gating this closes the gap that let the derivation ship with
# (128/(3√π))·ã^{3/2}·N — short of the correct
# (128√π/3)·ã^{5/2}·N^{3/2} by a factor π·ã·√N (≈12× for ¹⁶⁴Dy at N = 6e4).
# The error is invisible to a units check: both forms are dimensionless.

using Test
using SpinorBEC

const _U = SpinorBEC.Units

# Drive the real code path rather than re-typing the formula under test.
function _derived_c_lhy(atom, N_atoms::Int, a_ho::Float64; eps_dd::Float64=0.0)
    p = Dict{String, Any}("lhy" => Dict{String, Any}("kind" => "scalar"))
    inter = Dict{String, Any}()
    SpinorBEC._resolve_lhy_block!(p, inter, atom, 1.0, eps_dd, N_atoms, a_ho)
    inter["c_lhy"]
end

@testset "Scalar LHY coefficient ↔ SI round-trip" begin
    @testset "μ_LHY/μ_contact matches (32/3)√(n a³/π)" begin
        cases = [
            (Dy164, 60_000, 2π * 600.0),
            (Er168, 20_000, 2π * 200.0),
            (Eu151, 50_000, 2π * 110.0),
        ]
        for (atom, N, omega) in cases
            a_ho = sqrt(_U.HBAR / (atom.mass * omega))
            ah = atom.a_s / a_ho
            c0 = 4π * ah * N
            c_lhy = _derived_c_lhy(atom, N, a_ho)

            for n_d in (5e-3, 2e-2, 8e-2)
                n_si = N * n_d / a_ho^3
                ratio_si = (32 / 3) * sqrt(n_si * atom.a_s^3 / π)
                ratio_code = (c_lhy / c0) * sqrt(n_d)
                @test ratio_code ≈ ratio_si rtol = 1e-12
            end
        end
    end

    @testset "scaling exponents in N and a_s" begin
        # c_lhy ∝ N^{3/2}·(a_s/a_ho)^{5/2}. Getting either exponent wrong is
        # the failure mode that shipped, so pin both directly.
        a_ho = sqrt(_U.HBAR / (Dy164.mass * 2π * 600.0))
        c1 = _derived_c_lhy(Dy164, 10_000, a_ho)
        c8 = _derived_c_lhy(Dy164, 80_000, a_ho)
        @test c8 / c1 ≈ 8.0^1.5 rtol = 1e-12

        # a_s enters only through a_s/a_ho, so scaling a_ho is the clean lever.
        c_half = _derived_c_lhy(Dy164, 10_000, a_ho / 2)
        @test c_half / c1 ≈ 2.0^2.5 rtol = 1e-12
    end

    @testset "Q₅(ε_dd) multiplies the whole coefficient" begin
        a_ho = sqrt(_U.HBAR / (Dy164.mass * 2π * 600.0))
        base = _derived_c_lhy(Dy164, 60_000, a_ho; eps_dd=0.0)
        for eps in (0.5, 1.0, 1.45)
            @test _derived_c_lhy(Dy164, 60_000, a_ho; eps_dd=eps) ≈
                base * lima_pelster_Q5(eps) rtol = 1e-12
        end
        # ε_dd = 0 has to leave the scalar value untouched.
        @test lima_pelster_Q5(0.0) ≈ 1.0 atol = 1e-14
    end

    @testset "explicit c_lhy is never overwritten" begin
        p = Dict{String, Any}(
            "lhy" => Dict{String, Any}("kind" => "scalar", "c_lhy" => 123.0)
        )
        inter = Dict{String, Any}()
        a_ho = sqrt(_U.HBAR / (Dy164.mass * 2π * 600.0))
        SpinorBEC._resolve_lhy_block!(p, inter, Dy164, 1.0, 1.45, 60_000, a_ho)
        @test inter["c_lhy"] == 123.0
    end
end
