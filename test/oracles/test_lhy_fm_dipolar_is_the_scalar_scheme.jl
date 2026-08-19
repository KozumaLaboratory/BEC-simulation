# The literature scheme for a spinor-dipolar cloud IS `fm_dipolar` — gated.
#
# #337 selects, for a state with |⟨F⟩|/F ≈ 1, the fully-polarised single-component
# dipolar LHY that the spinor-dipolar droplet literature uses (Saito group,
# arXiv:2402.18885; Yan-Li-Saito arXiv:2605.11670): ε = (2/5)γ_QF n^(5/2) with
# γ_QF carrying Re Q₅(ε_dd), applied at the total density.
#
# That selection is only meaningful if this repo's `fm_dipolar` IS that object.
# It is, by algebra: the Eu constraint fixes g_{2F} = c₀ + F²c₁ = c_total for
# EVERY c1_ratio, so the FM single-mode closed form (8/15π²)(g_{2F}n)^(5/2)·Q₅ and
# the SI-anchored scalar coefficient (128√π/3)(a_s/a_ho)^(5/2)N^(3/2)·Q₅ are the
# same number. Two independently written code paths, one identity.
#
# `test_lhy_magnitude_si_anchor.jl` already anchors the tabulated family to SI,
# but only in the UNIFORM-g_S limit (c₁ = 0) and only without the DDI. Neither
# condition holds for production Eu: `c1_ratio = 1/36` on the phase campaign,
# `−0.005` on the k3/verification families, and ε_dd = 0.54 throughout. This file
# covers the gap those two conditions leave, which is where the scheme decision
# actually lives.
#
# NOT a duplicate of `test_stretched_channel_invariance.jl`, which gained a
# dipolar-FM block on 2026-08-19 (#342). That file pins INVARIANCE — that a
# `c1_ratio` sweep at fixed `c_total` cannot move `fm_dipolar`, because the six
# unmeasured channels do not enter it. This file pins MAGNITUDE — that the value
# it is invariant at is the SI one. An implementation off by a constant factor
# satisfies every assertion there and none here.
#
# It also pins the ε_dd CONVERSION. `_build_spinor_lhy(::Val{:fm_dipolar})`
# reaches Lima-Pelster through `eps_dd = c_dd·F²/(3·g_{2F})`, converting from the
# spin-Hamiltonian coupling to the scalar ratio; the claim is that this equals the
# atom's own a_dd/a_s. Nothing asserted that before, and a wrong factor there
# would rescale every dipolar LHY silently — Q₅ is smooth, so the result would
# stay plausible.

using Test
using SpinorBEC
using SpinorBEC: scalar_lhy_coefficient, lima_pelster_Q5, c_to_g,
    build_fm_lhy_coefs, lhy_energy_fm_dipolar, _lhy_V, compute_a_dd

const _F = 6
const _N = 50_000
const _OMEGA = 2π * 110.0
const _A_HO = sqrt(SpinorBEC.Units.HBAR / (Eu151.mass * _OMEGA))
const _A_OVER_AHO = Eu151.a_s / _A_HO
const _C_TOTAL = 4π * _A_OVER_AHO * _N
const _C_DD = _N * compute_c_dd(Eu151) / (SpinorBEC.Units.HBAR * _OMEGA * _A_HO^3)
const _EPS_DD = compute_a_dd(Eu151) / Eu151.a_s

# Both signs, because production uses both: +1/36 on the GS phase campaign and
# −0.005 on the verification_suite / eu_k3_* families. A test at one sign would
# not notice a term that only survives for the other.
const _RATIOS = (-0.005, 0.0, 0.01, 1 / 36, 0.05)

@testset "fm_dipolar is the fully-polarised dipolar LHY of the literature" begin
    @testset "the Eu constraint pins g_2F = c_total at every c1_ratio" begin
        # This is WHY the identity below holds; without it the two paths would
        # legitimately differ and the test would be asserting a coincidence.
        for r in _RATIOS
            ip = interaction_params_from_constraint(; c_total=_C_TOTAL, c1_ratio=r, F=_F)
            g = c_to_g(_F, ip)
            @test isapprox(g[2 * _F], _C_TOTAL; rtol=1e-12)
        end
    end

    @testset "the c_dd → ε_dd conversion reproduces the atom's a_dd/a_s" begin
        for r in _RATIOS
            ip = interaction_params_from_constraint(; c_total=_C_TOTAL, c1_ratio=r, F=_F)
            g_2F = c_to_g(_F, ip)[2 * _F]
            eps_from_c_dd = abs(_C_DD) * _F^2 / (3 * abs(g_2F))
            @test isapprox(eps_from_c_dd, _EPS_DD; rtol=1e-10)
        end
        # ...and Eu is inside the domain where Q₅ is REAL, which is what makes
        # the "take the real part" prescription vacuous here. If a future atom or
        # a_s pushes ε_dd past 1 this assertion is the place that says so.
        @test _EPS_DD < 1
        @test lima_pelster_Q5(_EPS_DD) > 1
    end

    @testset "ε_fm_dipolar/N == (2/5)·c_lhy(ε_dd)·n^(5/2)" begin
        c_lhy = scalar_lhy_coefficient(_A_OVER_AHO, _N; eps_dd=_EPS_DD)
        for r in _RATIOS, n in (1.0e-3, 3.7e-3, 1.0e-2)
            ip = interaction_params_from_constraint(; c_total=_C_TOTAL, c1_ratio=r, F=_F)
            g = c_to_g(_F, ip)
            got = lhy_energy_fm_dipolar(n, build_fm_lhy_coefs(_F, g), _EPS_DD) / _N
            want = 0.4 * c_lhy * n^2.5
            @test isapprox(got, want; rtol=1e-12)
        end
    end

    @testset "the tabulated V agrees too, so the propagator sees the same thing" begin
        # The energy identity above could hold while the table that the diagonal
        # step actually evaluates carried a different derivative. V = dε/dn, so
        # the prediction is c_lhy·n^(3/2). The table uses central differences,
        # hence the looser tolerance — this is a table-resolution check, not a
        # second algebra check.
        c_lhy = scalar_lhy_coefficient(_A_OVER_AHO, _N; eps_dd=_EPS_DD)
        for r in (-0.005, 1 / 36)
            ip = interaction_params_from_constraint(; c_total=_C_TOTAL, c1_ratio=r, F=_F)
            tbl = compute_spinor_lhy_fm_dipolar(; F=_F, g_dict=c_to_g(_F, ip),
                eps_dd=_EPS_DD, n_max=0.02, n_points=4000, n_atoms=_N)
            n = 3.7e-3
            @test isapprox(_lhy_V(n, tbl), c_lhy * n * sqrt(n); rtol=1e-5)
        end
    end

    @testset "canary: the identity is not tautological" begin
        # Every assertion above would also pass if `fm_dipolar` silently ignored
        # the DDI, because Q₅ would then be missing from BOTH sides. Pin the
        # dipolar enhancement explicitly: the ε_dd = 0 table must be Q₅ times
        # SMALLER, so a build that drops the dipolar factor turns this red.
        ip = interaction_params_from_constraint(; c_total=_C_TOTAL, c1_ratio=1 / 36, F=_F)
        g = c_to_g(_F, ip)
        n = 3.7e-3
        with_ddi = lhy_energy_fm_dipolar(n, build_fm_lhy_coefs(_F, g), _EPS_DD)
        without = lhy_energy_fm_dipolar(n, build_fm_lhy_coefs(_F, g), 0.0)
        @test isapprox(with_ddi / without, lima_pelster_Q5(_EPS_DD); rtol=1e-12)
        @test lima_pelster_Q5(_EPS_DD) > 1.4      # 1.4564 at Eu — a real factor
    end
end
